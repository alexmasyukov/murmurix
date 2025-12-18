#!/usr/bin/env python3
"""
Murmurix Transcription Script

Usage: python transcribe.py <audio_path> [--language ru] [--model NAME]
Outputs recognized text to stdout.
"""

import sys
import os
import argparse
from pathlib import Path
from faster_whisper import WhisperModel

# Supported models
MODELS = ["tiny", "base", "small", "medium", "large-v2", "large-v3"]


def get_hf_cache_path():
    """Get Hugging Face cache directory."""
    return Path(os.environ.get("HF_HOME", Path.home() / ".cache" / "huggingface")) / "hub"


def is_model_installed(model_name: str) -> bool:
    """Check if model is installed in HF cache."""
    cache_path = get_hf_cache_path()
    model_dir = cache_path / f"models--Systran--faster-whisper-{model_name}"
    if not model_dir.exists():
        return False
    snapshots = model_dir / "snapshots"
    if not snapshots.exists():
        return False
    for snapshot in snapshots.iterdir():
        if (snapshot / "model.bin").exists() or (snapshot / "config.json").exists():
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using faster-whisper")
    parser.add_argument("audio_path", help="Path to the audio file")
    parser.add_argument("--language", default="ru", help="Language for recognition (default: ru)")
    parser.add_argument("--model", default="small", help="Whisper model name")
    args = parser.parse_args()

    model_name = args.model

    # Check if model is installed
    if not is_model_installed(model_name):
        print(f"Error: Model '{model_name}' not installed.", file=sys.stderr)
        print(f"Run: python transcribe_daemon.py --download {model_name}", file=sys.stderr)
        sys.exit(1)

    try:
        model = WhisperModel(f"Systran/faster-whisper-{model_name}", device="cpu", compute_type="int8")
    except Exception as e:
        print(f"Error loading model: {e}", file=sys.stderr)
        sys.exit(1)

    # Transcribe
    try:
        print(f"DEBUG: Transcribing {args.audio_path}", file=sys.stderr)

        segments, info = model.transcribe(
            args.audio_path,
            language=args.language,
            vad_filter=False  # Disable VAD to get all audio
        )

        # Collect all text
        text_parts = []
        for segment in segments:
            print(f"DEBUG: segment [{segment.start:.2f}s - {segment.end:.2f}s]: {segment.text}", file=sys.stderr)
            text_parts.append(segment.text.strip())

        result = " ".join(text_parts)
        print(f"DEBUG: Final result: '{result}'", file=sys.stderr)
        print(result if result else "(no speech detected)")

    except Exception as e:
        print(f"Error during transcription: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
