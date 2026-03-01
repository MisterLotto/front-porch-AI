"""
Whisper STT helper script for Front Porch AI.
Reads a JSON request from stdin, transcribes audio via faster-whisper, writes result to stdout.

Usage: python3 whisper_stt.py
  Reads one JSON line from stdin:
  {"audio":"/tmp/recording.wav","model_size":"base.en","model_dir":"/optional/path"}
"""

import sys
import json

try:
    from faster_whisper import WhisperModel
except ImportError as e:
    print(json.dumps({"error": f"Missing dependency: {e}"}))
    sys.exit(1)

# Cache the model across invocations (single-shot script, but useful if kept warm)
_model_cache = {}

def main():
    line = sys.stdin.readline().strip()
    if not line:
        print(json.dumps({"error": "No input"}))
        sys.exit(1)

    try:
        req = json.loads(line)
    except json.JSONDecodeError as e:
        print(json.dumps({"error": f"Invalid JSON: {e}"}))
        sys.exit(1)

    audio_path = req.get("audio", "")
    model_size = req.get("model_size", "base.en")
    model_dir = req.get("model_dir", None)  # optional: custom cache directory
    download_only = req.get("download_only", False)

    if not download_only and not audio_path:
        print(json.dumps({"error": "No audio path provided"}))
        sys.exit(1)

    try:
        # Load model (faster-whisper auto-downloads from HuggingFace on first use)
        kwargs = {
            "device": "cpu",
            "compute_type": "int8",
        }
        if model_dir:
            kwargs["download_root"] = model_dir

        model = WhisperModel(model_size, **kwargs)

        # If download_only, just exit after the model is loaded/downloaded
        if download_only:
            print(json.dumps({"status": "ok", "message": f"Model '{model_size}' is ready."}))
            sys.exit(0)

        # Transcribe
        segments, info = model.transcribe(
            audio_path,
            beam_size=5,
            vad_filter=True,  # filter out silence
        )

        # Collect all text
        text_parts = []
        for segment in segments:
            text_parts.append(segment.text.strip())

        result = {
            "text": " ".join(text_parts).strip(),
            "language": info.language,
            "language_probability": round(info.language_probability, 3),
            "duration": round(info.duration, 2),
        }
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.exit(1)

if __name__ == "__main__":
    main()
