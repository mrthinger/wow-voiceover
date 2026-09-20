#!/usr/bin/env bash
# Runs a command inside the TTS virtualenv with the libraries that pip wheels
# expect on NixOS (libstdc++ from nixpkgs, libcuda from the system driver), and
# with ffmpeg on PATH.
#
#   ./forever/run.sh python forever/tts_smoke.py
#   ./forever/run.sh python forever/ingest.py
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$ROOT/.venv-tts"

if [ ! -x "$VENV/bin/python" ]; then
    echo "virtualenv missing; create it with:" >&2
    echo "  nix shell nixpkgs#python312 nixpkgs#uv -c sh -c 'uv venv --python \$(which python3) $VENV && VIRTUAL_ENV=$VENV uv pip install -r $ROOT/forever/requirements.txt'" >&2
    exit 1
fi

# Shared libraries that manylinux wheels (numpy, torch, ...) expect to find on the system.
LIBS=""
for pkg in stdenv.cc.cc.lib zlib; do
    out="$(nix build --no-link --print-out-paths "nixpkgs#$pkg")"
    LIBS="${LIBS:+$LIBS:}$out/lib"
done
export LD_LIBRARY_PATH="$LIBS:/run/opengl-driver/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export VIRTUAL_ENV="$VENV"
export PYTHONUNBUFFERED=1
export TQDM_DISABLE=1   # chatterbox prints a sampling bar per chunk otherwise

cd "$ROOT"
# nix shell prepends its own bin dirs, so re-prepend the venv inside the shell
# (the PATH expansion must happen inside, after nix has added ffmpeg).
exec nix shell nixpkgs#ffmpeg -c sh -c 'export PATH="$0:$PATH"; exec "$@"' "$VENV/bin" "$@"
