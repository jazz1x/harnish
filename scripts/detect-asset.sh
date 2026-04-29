#!/usr/bin/env bash
# detect-asset.sh — Python migration wrapper (v0.1.0+)
# 실제 구현: scripts/harnish_py/detect.py
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHONPATH="$SCRIPT_DIR" exec python3 -m harnish_py detect-asset "$@"
