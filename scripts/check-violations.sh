#!/usr/bin/env bash
# check-violations.sh — harnish-current-work.json 위반/에스컬레이션 확인
# 사용법: bash check-violations.sh [harnish-current-work.json 경로]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROGRESS_FILE="${1:-$(resolve_progress_file)}"

if [[ ! -f "$PROGRESS_FILE" ]]; then
    echo "ERROR: $PROGRESS_FILE not found" >&2
    exit 1
fi

VIOLATIONS=$(jq '.violations | length' "$PROGRESS_FILE" 2>/dev/null || echo "0")
ESCALATIONS=$(jq '.escalations | length' "$PROGRESS_FILE" 2>/dev/null || echo "0")

echo "위반 기록: ${VIOLATIONS}건"
echo "에스컬레이션: ${ESCALATIONS}건"

if [[ "$VIOLATIONS" -gt 0 ]]; then
    echo ""
    echo "── 위반 내역 ──"
    jq -r '.violations[] | "  \(.timestamp) | Task \(.task) | \(.violation) | 판단: \(.user_decision // "미결")"' "$PROGRESS_FILE" 2>/dev/null
fi

if [[ "$ESCALATIONS" -gt 0 ]]; then
    echo ""
    echo "── 에스컬레이션 내역 ──"
    jq -r '.escalations[] | "  \(.timestamp) | Task \(.task) | \(.blocked_at)"' "$PROGRESS_FILE" 2>/dev/null
fi
