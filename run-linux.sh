#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ ! -x venv/bin/python ]]; then
  echo 'Missing virtual environment; run ./setup-linux.sh first.' >&2
  exit 1
fi
if ! command -v ffmpeg >/dev/null 2>&1 || ! command -v ffprobe >/dev/null 2>&1; then
  echo 'FFmpeg and ffprobe are required. Run ./setup-linux.sh for checks.' >&2
  exit 1
fi
if ! venv/bin/python -c 'import gradio, requests, faster_whisper' >/dev/null 2>&1; then
  echo 'Python packages are missing. Run ./setup-linux.sh again.' >&2
  exit 1
fi
exec venv/bin/python -u app.py
