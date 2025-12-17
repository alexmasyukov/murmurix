#!/usr/bin/env python3
"""
Murmurix Transcription Script

Usage: python transcribe.py <audio_path> [--language ru] [--model-path PATH]
Outputs recognized text to stdout.
"""

import sys
import argparse
from faster_whisper import WhisperModel


def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using faster-whisper")
    parser.add_argument("audio_path", help="Path to the audio file")
    parser.add_argument("--language", default="ru", help="Language for recognition (default: ru)")
    parser.add_argument("--model-path", help="Path to the Whisper model directory")
    args = parser.parse_args()

    # Load model
    model_path = args.model_path if args.model_path else "small"

    try:
        model = WhisperModel(model_path, device="cpu", compute_type="int8")
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
