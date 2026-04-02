#!/usr/bin/env bash
# check-thresholds.sh — JSONL 자산의 태그별 카운트를 확인하고 임계치 도달 여부를 보고한다.
#
# 사용법:
#   check-thresholds.sh [THRESHOLD]          # 기본 5
#   check-thresholds.sh --base-dir .harnish

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
THRESHOLD="${1:-5}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --base-dir) BASE="$2"; shift 2;;
        *) shift;;
    esac
done

RAG_FILE="$BASE/harnish-rag.jsonl"

if [[ ! -f "$RAG_FILE" ]] || [[ ! -s "$RAG_FILE" ]]; then
    echo "자산 없음"
    exit 0
fi

jq -c 'select(.compressed != true) | .tags[]' "$RAG_FILE" 2>/dev/null \
  | sort | uniq -c | sort -rn \
  | awk -v t="$THRESHOLD" '{
      count=$1; tag=$2;
      if (count >= t) printf "%s(%d건) ⚠ 압축 권장\n", tag, count;
      else printf "%s(%d건)\n", tag, count;
  }'
