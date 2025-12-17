#!/usr/bin/env python3
"""
Murmurix Transcription Daemon

Keeps the Whisper model loaded in memory for fast transcription.
Communicates via Unix socket.

Usage: python transcribe_daemon.py [--socket-path PATH] [--model-path PATH] [--language LANG]
"""

import sys
import os
import socket
import json
import argparse
import signal
import threading
from pathlib import Path

# Global model instance
model = None
model_lock = threading.Lock()


def load_model(model_path: str):
    """Load Whisper model into memory."""
    global model
    from faster_whisper import WhisperModel

    print(f"Loading model from {model_path}...", file=sys.stderr)
    model = WhisperModel(model_path, device="cpu", compute_type="int8")
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


def run_server(socket_path: str, model_path: str, language: str):
    """Run the daemon server."""
    # Remove existing socket
    if os.path.exists(socket_path):
        os.remove(socket_path)

    # Load model
    load_model(model_path)

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
    parser.add_argument("--model-path", default="small", help="Path to Whisper model")
    parser.add_argument("--language", default="ru", help="Default language")
    args = parser.parse_args()

    # Ensure directory exists
    socket_dir = os.path.dirname(args.socket_path)
    os.makedirs(socket_dir, exist_ok=True)

    run_server(args.socket_path, args.model_path, args.language)


if __name__ == "__main__":
    main()
