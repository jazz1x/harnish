#!/usr/bin/env bash
# init-assets.sh — .harnish/ 디렉토리와 RAG/작업 파일을 초기화한다.
#
# Layer: L1 (Storage)
# 의존: common.sh (L1)
#
# 사용법:
#   init-assets.sh                          # 기본 경로 (CWD/.harnish)
#   init-assets.sh --base-dir /path/to/.harnish
#   init-assets.sh --quiet                  # 출력 없이

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --base-dir) BASE="$2"; shift 2;;
        --quiet)    QUIET=true; shift;;
        *) shift;;
    esac
done

log() { $QUIET || echo "$*"; }

mkdir -p "$BASE"

RAG_FILE="$BASE/harnish-rag.jsonl"
WORK_FILE="$BASE/harnish-current-work.json"

[[ -f "$RAG_FILE" ]]  || touch "$RAG_FILE"
[[ -f "$WORK_FILE" ]] || echo '{}' > "$WORK_FILE"

log "✓ .harnish/ 초기화 완료 ($BASE)"
