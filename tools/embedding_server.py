#!/usr/bin/env python3
"""
Local ONNX embedding server for Front Porch AI RAG memory.

Loads a small embedding model (nomic-embed-text-v1.5) on CPU via ONNX Runtime
and serves OpenAI-compatible /v1/embeddings requests on localhost.

Usage:
    python embedding_server.py [--port 5055] [--model-dir /path/to/model]
"""

import argparse
import json
import os
import sys
import time
import logging
import numpy as np
from pathlib import Path

logging.basicConfig(level=logging.INFO, format='[EmbedServer] %(message)s')
log = logging.getLogger(__name__)

# ── Model loading ─────────────────────────────────────────────────────────────

def get_default_model_dir():
    """Default model storage location."""
    xdg = os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share'))
    return os.path.join(xdg, 'front_porch_ai', 'embedding_model')


def download_model(model_dir: str):
    """Download nomic-embed-text-v1.5 ONNX files from Hugging Face."""
    from huggingface_hub import hf_hub_download
    
    os.makedirs(model_dir, exist_ok=True)
    
    repo_id = "nomic-ai/nomic-embed-text-v1.5"
    files_to_download = [
        "onnx/model.onnx",
        "tokenizer.json",
        "tokenizer_config.json",
        "special_tokens_map.json",
    ]
    
    for filename in files_to_download:
        local_name = os.path.basename(filename)
        target_path = os.path.join(model_dir, local_name)
        if os.path.exists(target_path):
            log.info(f"  ✓ {local_name} already exists")
            continue
        log.info(f"  ↓ Downloading {filename}...")
        downloaded = hf_hub_download(
            repo_id=repo_id,
            filename=filename,
            local_dir=os.path.join(model_dir, '_hf_cache'),
        )
        # Copy to flat model dir
        import shutil
        shutil.copy2(downloaded, target_path)
        log.info(f"  ✓ {local_name} downloaded ({os.path.getsize(target_path) / 1e6:.1f} MB)")


def load_model(model_dir: str):
    """Load the ONNX model and tokenizer."""
    import onnxruntime as ort
    from tokenizers import Tokenizer
    
    model_path = os.path.join(model_dir, 'model.onnx')
    tokenizer_path = os.path.join(model_dir, 'tokenizer.json')
    
    if not os.path.exists(model_path) or not os.path.exists(tokenizer_path):
        log.info("Model files not found, downloading nomic-embed-text-v1.5...")
        download_model(model_dir)
    
    log.info(f"Loading ONNX model from {model_path}...")
    session = ort.InferenceSession(
        model_path,
        providers=['CPUExecutionProvider'],
    )
    
    log.info(f"Loading tokenizer from {tokenizer_path}...")
    tokenizer = Tokenizer.from_file(tokenizer_path)
    tokenizer.enable_padding(pad_id=0, pad_token='[PAD]')
    tokenizer.enable_truncation(max_length=8192)
    
    # Get model info
    inputs = session.get_inputs()
    outputs = session.get_outputs()
    log.info(f"Model loaded: inputs={[i.name for i in inputs]}, outputs={[o.name for o in outputs]}")
    
    return session, tokenizer


def embed_texts(session, tokenizer, texts: list[str]) -> list[list[float]]:
    """Generate embeddings for a list of texts."""
    # Prefix for nomic — "search_document: " for stored text, "search_query: " for queries
    # For simplicity, use "search_document: " for all
    prefixed = [f"search_document: {t}" for t in texts]
    
    encoded = tokenizer.encode_batch(prefixed)
    
    input_ids = np.array([e.ids for e in encoded], dtype=np.int64)
    attention_mask = np.array([e.attention_mask for e in encoded], dtype=np.int64)
    
    # Some models also need token_type_ids
    token_type_ids = np.zeros_like(input_ids)
    
    feeds = {
        'input_ids': input_ids,
        'attention_mask': attention_mask,
    }
    
    # Only add token_type_ids if the model expects it
    input_names = [i.name for i in session.get_inputs()]
    if 'token_type_ids' in input_names:
        feeds['token_type_ids'] = token_type_ids
    
    start = time.perf_counter()
    outputs = session.run(None, feeds)
    elapsed_ms = (time.perf_counter() - start) * 1000
    
    # Output is typically the last hidden state — mean pool over tokens
    embeddings = outputs[0]  # shape: (batch, seq_len, hidden_dim) or (batch, hidden_dim)
    
    if len(embeddings.shape) == 3:
        # Mean pooling with attention mask
        mask_expanded = attention_mask[:, :, np.newaxis].astype(np.float32)
        pooled = (embeddings * mask_expanded).sum(axis=1) / mask_expanded.sum(axis=1)
    else:
        pooled = embeddings
    
    # L2 normalize
    norms = np.linalg.norm(pooled, axis=1, keepdims=True)
    norms = np.maximum(norms, 1e-12)
    normalized = pooled / norms
    
    log.info(f"Embedded {len(texts)} text(s) in {elapsed_ms:.1f}ms "
             f"({normalized.shape[1]}d vectors)")
    
    return normalized.tolist()

# ── HTTP Server ───────────────────────────────────────────────────────────────

def create_app(session, tokenizer):
    """Create a Flask app with OpenAI-compatible /v1/embeddings endpoint."""
    from flask import Flask, request, jsonify
    
    app = Flask(__name__)
    
    @app.route('/v1/embeddings', methods=['POST'])
    def embeddings():
        data = request.get_json()
        if not data:
            return jsonify({'error': 'Missing JSON body'}), 400
        
        input_text = data.get('input', '')
        if isinstance(input_text, str):
            texts = [input_text]
        elif isinstance(input_text, list):
            texts = input_text
        else:
            return jsonify({'error': 'input must be a string or list of strings'}), 400
        
        if not texts or all(not t.strip() for t in texts):
            return jsonify({'error': 'Empty input'}), 400
        
        try:
            vectors = embed_texts(session, tokenizer, texts)
        except Exception as e:
            log.error(f"Embedding failed: {e}")
            return jsonify({'error': str(e)}), 500
        
        response = {
            'object': 'list',
            'model': 'nomic-embed-text-v1.5',
            'data': [
                {
                    'object': 'embedding',
                    'index': i,
                    'embedding': vec,
                }
                for i, vec in enumerate(vectors)
            ],
            'usage': {
                'prompt_tokens': sum(len(t.split()) for t in texts),
                'total_tokens': sum(len(t.split()) for t in texts),
            },
        }
        return jsonify(response)
    
    @app.route('/v1/extract-text', methods=['POST'])
    def extract_text():
        """Extract text from uploaded files (PDF, etc.)."""
        if 'file' not in request.files:
            return jsonify({'error': 'No file uploaded'}), 400
        
        uploaded = request.files['file']
        filename = uploaded.filename or 'unknown'
        ext = os.path.splitext(filename)[1].lower()
        
        try:
            if ext == '.pdf':
                try:
                    from pypdf import PdfReader
                except ImportError:
                    return jsonify({'error': 'pypdf not installed. Run: pip install pypdf'}), 500
                
                reader = PdfReader(uploaded)
                pages = []
                for i, page in enumerate(reader.pages):
                    text = page.extract_text()
                    if text and text.strip():
                        pages.append(text.strip())
                
                full_text = '\n\n'.join(pages)
                log.info(f"Extracted {len(pages)} pages from PDF ({len(full_text)} chars)")
                
                return jsonify({
                    'text': full_text,
                    'pages': len(pages),
                    'characters': len(full_text),
                    'filename': filename,
                })
            else:
                # Plain text files — just read
                content = uploaded.read().decode('utf-8', errors='replace')
                return jsonify({
                    'text': content,
                    'pages': 1,
                    'characters': len(content),
                    'filename': filename,
                })
        except Exception as e:
            log.error(f"Text extraction failed: {e}")
            return jsonify({'error': str(e)}), 500
    
    @app.route('/health', methods=['GET'])
    def health():
        return jsonify({'status': 'ok', 'model': 'nomic-embed-text-v1.5'})
    
    return app


def main():
    parser = argparse.ArgumentParser(description='Local ONNX embedding server')
    parser.add_argument('--port', type=int, default=5055, help='Port to listen on')
    parser.add_argument('--model-dir', type=str, default=get_default_model_dir(),
                        help='Directory containing the ONNX model files')
    args = parser.parse_args()
    
    log.info(f"═══════════════════════════════════════════")
    log.info(f"  Front Porch AI — Local Embedding Server")
    log.info(f"  Model dir: {args.model_dir}")
    log.info(f"  Port: {args.port}")
    log.info(f"═══════════════════════════════════════════")
    
    session, tokenizer = load_model(args.model_dir)
    
    # Quick self-test
    log.info("Running self-test...")
    test_result = embed_texts(session, tokenizer, ["hello world"])
    log.info(f"Self-test passed: {len(test_result[0])}d vector")
    
    app = create_app(session, tokenizer)
    
    log.info(f"")
    log.info(f"✅ Embedding server ready at http://localhost:{args.port}")
    log.info(f"   Endpoint: POST http://localhost:{args.port}/v1/embeddings")
    log.info(f"")
    
    app.run(host='127.0.0.1', port=args.port, debug=False)


if __name__ == '__main__':
    main()
