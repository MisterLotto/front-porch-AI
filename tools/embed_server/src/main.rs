// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Lightweight ONNX embedding server for Front Porch AI RAG.
// Serves an OpenAI-compatible /v1/embeddings endpoint on port 5055.
// Uses fastembed (nomic-embed-text-v1.5) with ONNX Runtime — no Python needed.

use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    routing::{get, post},
};
use fastembed::{TextEmbedding, InitOptions, EmbeddingModel};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tokio::sync::RwLock;

// ── JSON event protocol (stdout for Dart sidecar) ─────────────────────

fn emit(event: &str, message: &str) {
    let payload = serde_json::json!({ "event": event, "message": message });
    println!("{}", payload);
}

fn emit_with_port(event: &str, port: u16) {
    let payload = serde_json::json!({ "event": event, "port": port });
    println!("{}", payload);
}

// ── Application state ─────────────────────────────────────────────────

struct AppState {
    model: Option<TextEmbedding>,
    model_ready: bool,
    model_error: Option<String>,
}

type SharedState = Arc<RwLock<AppState>>;

// ── Request / Response types ──────────────────────────────────────────

#[derive(Deserialize)]
struct EmbedRequest {
    input: EmbedInput,
}

#[derive(Deserialize)]
#[serde(untagged)]
enum EmbedInput {
    Single(String),
    Multiple(Vec<String>),
}

#[derive(Serialize)]
struct EmbedResponse {
    object: String,
    data: Vec<EmbedData>,
    model: String,
    usage: EmbedUsage,
}

#[derive(Serialize)]
struct EmbedData {
    object: String,
    index: usize,
    embedding: Vec<f32>,
}

#[derive(Serialize)]
struct EmbedUsage {
    prompt_tokens: u32,
    total_tokens: u32,
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    model_ready: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    model_error: Option<String>,
}

#[derive(Serialize)]
struct ModelHealthResponse {
    status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

// ── Handlers ──────────────────────────────────────────────────────────

async fn health(State(state): State<SharedState>) -> Json<HealthResponse> {
    let s = state.read().await;
    Json(HealthResponse {
        status: "ok".into(),
        model_ready: s.model_ready,
        model_error: s.model_error.clone(),
    })
}

async fn health_model(State(state): State<SharedState>) -> (StatusCode, Json<ModelHealthResponse>) {
    let s = state.read().await;
    if s.model_ready {
        (StatusCode::OK, Json(ModelHealthResponse {
            status: "ready".into(),
            error: None,
        }))
    } else if let Some(err) = &s.model_error {
        (StatusCode::SERVICE_UNAVAILABLE, Json(ModelHealthResponse {
            status: "error".into(),
            error: Some(err.clone()),
        }))
    } else {
        (StatusCode::SERVICE_UNAVAILABLE, Json(ModelHealthResponse {
            status: "loading".into(),
            error: None,
        }))
    }
}

async fn embed(
    State(state): State<SharedState>,
    Json(req): Json<EmbedRequest>,
) -> Result<Json<EmbedResponse>, (StatusCode, Json<serde_json::Value>)> {
    let s = state.read().await;

    if !s.model_ready {
        let msg = s.model_error.as_deref().unwrap_or("Model is still loading");
        return Err((
            StatusCode::SERVICE_UNAVAILABLE,
            Json(serde_json::json!({ "error": msg })),
        ));
    }

    let model = s.model.as_ref().unwrap();

    let texts: Vec<String> = match req.input {
        EmbedInput::Single(s) => vec![s],
        EmbedInput::Multiple(v) => v,
    };

    // Add nomic task prefix for search documents
    let prefixed: Vec<String> = texts
        .iter()
        .map(|t| format!("search_document: {}", t))
        .collect();

    let embeddings = model.embed(prefixed, None).map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({ "error": format!("Embedding failed: {}", e) })),
        )
    })?;

    let data: Vec<EmbedData> = embeddings
        .into_iter()
        .enumerate()
        .map(|(i, emb)| EmbedData {
            object: "embedding".into(),
            index: i,
            embedding: emb,
        })
        .collect();

    Ok(Json(EmbedResponse {
        object: "list".into(),
        data,
        model: "nomic-ai/nomic-embed-text-v1.5".into(),
        usage: EmbedUsage {
            prompt_tokens: 0,
            total_tokens: 0,
        },
    }))
}

// ── Model loading ─────────────────────────────────────────────────────

fn cache_dir() -> String {
    if let Some(cache) = dirs::cache_dir() {
        cache
            .join("front-porch-ai")
            .join("embeddings")
            .to_string_lossy()
            .to_string()
    } else {
        "./embed_cache".to_string()
    }
}

async fn load_model(state: SharedState) {
    emit("status", "Loading embedding model (downloading if first run)...");

    let cache = cache_dir();
    std::fs::create_dir_all(&cache).ok();

    let opts = InitOptions::new(EmbeddingModel::NomicEmbedTextV15)
        .with_cache_dir(cache.into())
        .with_show_download_progress(true);

    match TextEmbedding::try_new(opts) {
        Ok(model) => {
            // Warm up
            emit("status", "Warming up model...");
            if let Err(e) = model.embed(vec!["test".to_string()], None) {
                let mut s = state.write().await;
                s.model_error = Some(format!("Warmup failed: {}", e));
                emit("error", &format!("Warmup failed: {}", e));
                return;
            }

            let mut s = state.write().await;
            s.model = Some(model);
            s.model_ready = true;
            emit("ready", &format!("Embedding server ready on port 5055"));
        }
        Err(e) => {
            let mut s = state.write().await;
            s.model_error = Some(format!("{}", e));
            emit("error", &format!("Model load failed: {}", e));
        }
    }
}

// ── Main ──────────────────────────────────────────────────────────────

#[tokio::main]
async fn main() {
    emit("status", "Starting embedding server on port 5055...");

    let state: SharedState = Arc::new(RwLock::new(AppState {
        model: None,
        model_ready: false,
        model_error: None,
    }));

    // Start model loading in background
    let loader_state = state.clone();
    tokio::spawn(async move {
        load_model(loader_state).await;
    });

    let app = Router::new()
        .route("/health", get(health))
        .route("/health/model", get(health_model))
        .route("/v1/embeddings", post(embed))
        .with_state(state);

    let listener = match tokio::net::TcpListener::bind("127.0.0.1:5055").await {
        Ok(l) => l,
        Err(e) => {
            emit("error", &format!("Failed to bind to port 5055: {}", e));
            std::process::exit(1);
        }
    };

    // Only emit 'listening' after we've successfully bound the port
    emit_with_port("listening", 5055);

    axum::serve(listener, app)
        .await
        .expect("Server error");
}
