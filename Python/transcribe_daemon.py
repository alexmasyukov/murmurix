#!/usr/bin/env python3
"""
Murmurix Transcription Daemon

Keeps the Whisper model loaded in memory for fast transcription.
Communicates via Unix socket.

Usage: python transcribe_daemon.py [--socket-path PATH] [--model NAME] [--language LANG]
       python transcribe_daemon.py --list-models
       python transcribe_daemon.py --download MODEL_NAME
"""

import sys
import os
import socket
import json
import argparse
import signal
import threading
from pathlib import Path

# Supported models
MODELS = ["tiny", "base", "small", "medium", "large-v2", "large-v3"]

# Global model instance
model = None
model_lock = threading.Lock()


def get_hf_cache_path():
    """Get Hugging Face cache directory."""
    return Path(os.environ.get("HF_HOME", Path.home() / ".cache" / "huggingface")) / "hub"


def is_model_installed(model_name: str) -> bool:
    """Check if model is installed in HF cache."""
    cache_path = get_hf_cache_path()
    model_dir = cache_path / f"models--Systran--faster-whisper-{model_name}"
    if not model_dir.exists():
        return False
    # Check if snapshots exist (model actually downloaded)
    snapshots = model_dir / "snapshots"
    if not snapshots.exists():
        return False
    # Check if any snapshot has model files
    for snapshot in snapshots.iterdir():
        if (snapshot / "model.bin").exists() or (snapshot / "config.json").exists():
            return True
    return False


def get_installed_models() -> list:
    """Get list of installed models."""
    return [m for m in MODELS if is_model_installed(m)]


def download_model(model_name: str, progress_callback=None):
    """Download model from Hugging Face."""
    from huggingface_hub import snapshot_download

    repo_id = f"Systran/faster-whisper-{model_name}"
    print(f"Downloading {repo_id}...", file=sys.stderr)

    try:
        snapshot_download(
            repo_id=repo_id,
            local_dir=None,  # Use default cache
            local_dir_use_symlinks=True
        )
        print(f"Model {model_name} downloaded successfully!", file=sys.stderr)
        return True
    except Exception as e:
        print(f"Error downloading model: {e}", file=sys.stderr)
        return False


def load_model(model_name: str):
    """Load Whisper model into memory."""
    global model
    from faster_whisper import WhisperModel

    # Check if model is installed
    if not is_model_installed(model_name):
        print(f"Error: Model '{model_name}' not installed.", file=sys.stderr)
        print(f"Run: python transcribe_daemon.py --download {model_name}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading model {model_name}...", file=sys.stderr)
    # Use model name directly - faster_whisper will find it in HF cache
    model = WhisperModel(f"Systran/faster-whisper-{model_name}", device="cpu", compute_type="int8")
    print("Model loaded!", file=sys.stderr)


def transcribe(audio_path: str, language: str) -> str:
    """Transcribe audio file."""
    global model

    if model is None:
        return json.dumps({"error": "Model not loaded"})

    try:
        with model_lock:
            segments, info = model.transcribe(
                audio_path,
                language=language,
                vad_filter=False
            )

            text_parts = []
            for segment in segments:
                text_parts.append(segment.text.strip())

            result = " ".join(text_parts)
            return json.dumps({"text": result if result else "(no speech detected)"})

    except Exception as e:
        return json.dumps({"error": str(e)})


def handle_client(conn, language: str):
    """Handle a single client connection."""
    try:
        data = conn.recv(4096).decode('utf-8').strip()
        if not data:
            return

        request = json.loads(data)
        command = request.get("command")

        if command == "transcribe":
            audio_path = request.get("audio_path")
            lang = request.get("language", language)
            response = transcribe(audio_path, lang)
        elif command == "ping":
            response = json.dumps({"status": "ok"})
        elif command == "list_models":
            installed = get_installed_models()
            response = json.dumps({
                "models": [{"name": m, "installed": m in installed} for m in MODELS]
            })
        elif command == "download_model":
            model_name = request.get("model")
            if model_name not in MODELS:
                response = json.dumps({"error": f"Unknown model: {model_name}"})
            elif is_model_installed(model_name):
                response = json.dumps({"status": "already_installed"})
            else:
                success = download_model(model_name)
                response = json.dumps({"status": "ok" if success else "error"})
        elif command == "shutdown":
            response = json.dumps({"status": "shutting_down"})
            conn.sendall(response.encode('utf-8'))
            conn.close()
            os._exit(0)
        else:
            response = json.dumps({"error": f"Unknown command: {command}"})

        conn.sendall(response.encode('utf-8'))

    except Exception as e:
        try:
            conn.sendall(json.dumps({"error": str(e)}).encode('utf-8'))
        except:
            pass
    finally:
        conn.close()


def run_server(socket_path: str, model_name: str, language: str):
    """Run the daemon server."""
    # Remove existing socket
    if os.path.exists(socket_path):
        os.remove(socket_path)

    # Load model
    load_model(model_name)

    # Create Unix socket
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(socket_path)
    server.listen(5)

    # Make socket accessible
    os.chmod(socket_path, 0o666)

    print(f"Daemon listening on {socket_path}", file=sys.stderr)

    # Write PID file
    pid_path = socket_path + ".pid"
    with open(pid_path, 'w') as f:
        f.write(str(os.getpid()))

    def cleanup(signum, frame):
        print("Shutting down...", file=sys.stderr)
        server.close()
        if os.path.exists(socket_path):
            os.remove(socket_path)
        if os.path.exists(pid_path):
            os.remove(pid_path)
        sys.exit(0)

    signal.signal(signal.SIGTERM, cleanup)
    signal.signal(signal.SIGINT, cleanup)

    try:
        while True:
            conn, addr = server.accept()
            thread = threading.Thread(target=handle_client, args=(conn, language))
            thread.daemon = True
            thread.start()
    except Exception as e:
        print(f"Server error: {e}", file=sys.stderr)
    finally:
        cleanup(None, None)


def main():
    parser = argparse.ArgumentParser(description="Murmurix Transcription Daemon")
    parser.add_argument("--socket-path",
                        default=os.path.expanduser("~/Library/Application Support/Murmurix/daemon.sock"),
                        help="Unix socket path")
    parser.add_argument("--model", default="small", help="Whisper model name (tiny, base, small, medium, large-v2, large-v3)")
    parser.add_argument("--language", default="ru", help="Default language")
    parser.add_argument("--list-models", action="store_true", help="List available models and exit")
    parser.add_argument("--download", metavar="MODEL", help="Download a model and exit")
    args = parser.parse_args()

    # Handle --list-models
    if args.list_models:
        installed = get_installed_models()
        print("Available models:")
        for m in MODELS:
            status = "✓ installed" if m in installed else "✗ not installed"
            print(f"  {m}: {status}")
        sys.exit(0)

    # Handle --download
    if args.download:
        if args.download not in MODELS:
            print(f"Error: Unknown model '{args.download}'", file=sys.stderr)
            print(f"Available: {', '.join(MODELS)}", file=sys.stderr)
            sys.exit(1)
        success = download_model(args.download)
        sys.exit(0 if success else 1)

    # Ensure directory exists
    socket_dir = os.path.dirname(args.socket_path)
    os.makedirs(socket_dir, exist_ok=True)

    run_server(args.socket_path, args.model, args.language)


if __name__ == "__main__":
    main()
