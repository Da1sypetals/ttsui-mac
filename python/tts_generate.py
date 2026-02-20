#!/usr/bin/env python3
"""
TTS Generation Script for TTSUI-mac

This script is invoked as a subprocess by the SwiftUI app.
It passes parameters via command-line arguments, writes progress to stderr,
and outputs the result path to stdout.

Usage examples:
    python tts_generate.py clone --model "mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16" \
        --text "Hello from Sesame." --ref-audio "/path/to/ref.wav" \
        --ref-text "Reference transcript." --output "/path/to/output.wav"

    python tts_generate.py control --model "mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16" \
        --text "I'm so excited!" --speaker "Vivian" --language "English" \
        --instruct "Very happy and excited." --output "/path/to/output.wav"

    python tts_generate.py design \
        --text "Big brother, you're back!" --language "English" \
        --instruct "A cheerful young female voice..." --output "/path/to/output.wav"

Output Protocol:
    stdout: Output file path on success, or ERROR: <message> on failure
    stderr: Progress lines in format PROGRESS: <percent> <status_message>
"""

import os

# Set HF endpoint for faster downloads in China
os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"

import argparse
import sys
import numpy as np
import soundfile as sf
from pathlib import Path

from mlx_audio.tts.utils import load_model


def report_progress(percent: int, message: str):
    """Write progress update to stderr."""
    print(f"PROGRESS: {percent} {message}", file=sys.stderr, flush=True)


def save_audio(audio, sample_rate: int, output_path: str):
    """Save audio numpy array to WAV file."""
    audio_np = np.array(audio)
    # Ensure output directory exists
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    sf.write(output_path, audio_np, sample_rate)


def run_clone(args):
    """Run voice cloning mode."""
    report_progress(5, "Loading model...")

    model = load_model(args.model)
    sample_rate = model.sample_rate

    report_progress(20, "Processing reference audio...")

    kwargs = {
        "text": args.text,
        "ref_audio": args.ref_audio,
    }

    if args.ref_text:
        kwargs["ref_text"] = args.ref_text

    report_progress(30, "Generating audio...")

    results = list(model.generate(**kwargs))

    if not results:
        raise RuntimeError("No audio generated")

    report_progress(80, "Saving output...")

    audio = results[0].audio
    save_audio(audio, sample_rate, args.output)

    report_progress(100, "Complete!")
    print(args.output, flush=True)


def run_control(args):
    """Run custom voice control mode."""
    report_progress(5, "Loading model...")

    model = load_model(args.model)
    sample_rate = model.sample_rate

    report_progress(20, "Preparing generation parameters...")

    kwargs = {
        "text": args.text,
        "speaker": args.speaker,
        "language": args.language,
    }

    if args.instruct:
        kwargs["instruct"] = args.instruct

    report_progress(30, "Generating audio...")

    results = list(model.generate_custom_voice(**kwargs))

    if not results:
        raise RuntimeError("No audio generated")

    report_progress(80, "Saving output...")

    audio = results[0].audio
    save_audio(audio, sample_rate, args.output)

    report_progress(100, "Complete!")
    print(args.output, flush=True)


def run_design(args):
    """Run voice design mode."""
    report_progress(5, "Loading model...")

    # Design mode uses only the VoiceDesign model
    model = load_model("mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16")
    sample_rate = model.sample_rate

    report_progress(20, "Preparing voice design parameters...")

    kwargs = {
        "text": args.text,
        "language": args.language,
        "instruct": args.instruct,
    }

    report_progress(30, "Generating audio with custom voice design...")

    results = list(model.generate_voice_design(**kwargs))

    if not results:
        raise RuntimeError("No audio generated")

    report_progress(80, "Saving output...")

    audio = results[0].audio
    save_audio(audio, sample_rate, args.output)

    report_progress(100, "Complete!")
    print(args.output, flush=True)


def main():
    parser = argparse.ArgumentParser(description="TTS Generation Script for TTSUI-mac")
    subparsers = parser.add_subparsers(dest="mode", required=True, help="TTS mode")

    # Clone mode
    clone_parser = subparsers.add_parser("clone", help="Voice cloning mode")
    clone_parser.add_argument(
        "--model", required=True, help="Model name (e.g., mlx-community/Qwen3-TTS-12Hz-1.7B-Base-bf16)"
    )
    clone_parser.add_argument("--text", required=True, help="Target text to synthesize")
    clone_parser.add_argument("--ref-audio", required=True, help="Path to reference audio file")
    clone_parser.add_argument("--ref-text", default="", help="Transcript of reference audio")
    clone_parser.add_argument("--output", required=True, help="Output WAV file path")

    # Control mode
    control_parser = subparsers.add_parser("control", help="Custom voice control mode")
    control_parser.add_argument(
        "--model", required=True, help="Model name (e.g., mlx-community/Qwen3-TTS-12Hz-1.7B-CustomVoice-bf16)"
    )
    control_parser.add_argument("--text", required=True, help="Target text to synthesize")
    control_parser.add_argument(
        "--speaker",
        required=True,
        choices=["Vivian", "Serena", "Uncle_Fu", "Dylan", "Eric", "Ryan", "Aiden"],
        help="Speaker name",
    )
    control_parser.add_argument("--language", required=True, choices=["Chinese", "English"], help="Language")
    control_parser.add_argument("--instruct", default="", help="Emotion/style instructions")
    control_parser.add_argument("--output", required=True, help="Output WAV file path")

    # Design mode
    design_parser = subparsers.add_parser("design", help="Voice design mode")
    design_parser.add_argument("--text", required=True, help="Target text to synthesize")
    design_parser.add_argument("--language", required=True, choices=["Chinese", "English"], help="Language")
    design_parser.add_argument(
        "--instruct", required=True, help="Voice description (e.g., 'A cheerful young female voice...')"
    )
    design_parser.add_argument("--output", required=True, help="Output WAV file path")

    args = parser.parse_args()

    try:
        if args.mode == "clone":
            run_clone(args)
        elif args.mode == "control":
            run_control(args)
        elif args.mode == "design":
            run_design(args)
        else:
            print(f"ERROR: Unknown mode: {args.mode}", flush=True)
            sys.exit(1)
    except Exception as e:
        print(f"ERROR: {str(e)}", flush=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
