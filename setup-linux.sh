#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if [[ "$(uname -s)" != Linux ]]; then echo 'This launcher is for Linux only.' >&2; exit 1; fi
for tool in ffmpeg ffprobe; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing $tool. Install FFmpeg using your distro package manager (apt, dnf, pacman, zypper) and retry." >&2
    exit 1
  fi
done
if ! ffmpeg -hide_banner -filters 2>/dev/null | grep -Eq '^[[:space:]]*[.A-Z|]+[[:space:]]+ass[[:space:]]'; then
  echo 'Warning: ffmpeg ass/libass filter not found. Clip export may work, but karaoke subtitle burn-in will not.' >&2
fi
if ! command -v ollama >/dev/null 2>&1; then
  echo 'Ollama is missing. Install it from https://ollama.com/download/linux and run setup again.' >&2
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then echo 'curl is required to check the local Ollama API.' >&2; exit 1; fi

if [[ -n "${CLIPFORGE_PYTHON:-}" ]]; then
  interpreter="$CLIPFORGE_PYTHON"
else
  interpreter=''
  for name in python3.12 python3.11 python3.10; do
    if command -v "$name" >/dev/null 2>&1; then interpreter="$name"; break; fi
  done
fi
if [[ -z "$interpreter" ]] || ! command -v "$interpreter" >/dev/null 2>&1; then
  echo 'Install Python 3.12 with venv support (recommended), then retry.' >&2
  echo 'Or set CLIPFORGE_PYTHON=/path/to/python3.12 to choose a specific interpreter.' >&2
  exit 1
fi
if ! "$interpreter" -c 'import sys,venv; assert (3,10) <= sys.version_info[:2] <= (3,12)' >/dev/null 2>&1; then
  echo "The selected Python ($interpreter) must be 3.10-3.12 with venv support. Python 3.12 is recommended." >&2
  exit 1
fi
if ! "$interpreter" -m venv --help >/dev/null 2>&1; then
  echo "The venv module is missing for $interpreter. Install your distro's python venv package." >&2
  exit 1
fi

# Virtual environments are machine-specific and should never be copied between computers.
if [[ -e venv ]]; then
  if [[ ! -x venv/bin/python ]]; then
    echo 'Existing venv is unusable. Rename it (e.g. mv venv venv.old) and rerun setup.' >&2
    exit 1
  fi
  actual="$(venv/bin/python -c 'import sys; print(str(sys.version_info.major)+"."+str(sys.version_info.minor))' 2>/dev/null || true)"
  desired="$($interpreter -c 'import sys; print(str(sys.version_info.major)+"."+str(sys.version_info.minor))')"
  if [[ "$actual" != "$desired" ]]; then
    echo "Existing venv uses Python $actual but selected Python is $desired. Rename venv and rerun setup." >&2
    exit 1
  fi
else
  "$interpreter" -m venv venv || { echo 'Could not create venv. Install python3-venv / python3.12-venv for your distribution.' >&2; exit 1; }
fi
venv/bin/python -m pip --version >/dev/null 2>&1 || { echo 'pip is unavailable in venv. Install python3-pip / python3.12-venv.' >&2; exit 1; }
echo "Installing Python dependencies into $(pwd)/venv..."
venv/bin/python -m pip install --upgrade pip
venv/bin/python -m pip install --only-binary=:all: -r requirements.txt || {
  echo 'No compatible binary wheel was found. Use Python 3.12 and rerun setup; do not compile old PyAV against an incompatible system FFmpeg.' >&2
  exit 1
}
venv/bin/python -c 'import gradio,requests,faster_whisper,scenedetect,cv2,av; print("Python imports OK")'
if curl -fsS --max-time 4 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  if ! ollama list | grep -Fq 'llama3.2:3b'; then
    echo 'Pulling local model llama3.2:3b (approximately 2 GB)...'
    ollama pull llama3.2:3b
  fi
else
  echo 'Ollama is installed but its API is not responding at 127.0.0.1:11434.' >&2
  echo 'Start the service (e.g. sudo systemctl start ollama) or run ollama serve, then: ollama pull llama3.2:3b' >&2
fi
echo 'Setup complete. Run: ./run-linux.sh'
