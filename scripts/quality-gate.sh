#!/usr/bin/env bash
# quality-gate.sh — JSONL 자산의 필수 필드 완성도 확인
#
# 사용법:
#   quality-gate.sh [--base-dir .harnish] [--format json|text]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
FORMAT="text"

while [[ $# -gt 0 ]]; do
    case $1 in
        --base-dir) BASE="$2"; shift 2;;
        --format)   FORMAT="$2"; shift 2;;
        *) shift;;
    esac
done

ASSET_FILE="$BASE/harnish-assets.jsonl"

if [[ ! -f "$ASSET_FILE" ]] || [[ ! -s "$ASSET_FILE" ]]; then
    [[ "$FORMAT" == "json" ]] && echo '{"status":"empty","issues":[]}' || echo "자산 없음"
    exit 0
fi

# 각 레코드의 필수 필드 검증
ISSUES=$(jq -c 'select(.compressed != true) |
    . as $r |
    [
        (if (.type | length) == 0 then "type 누락" else empty end),
        (if (.slug | length) == 0 then "slug 누락" else empty end),
        (if (.title | length) == 0 then "title 누락" else empty end),
        (if (.tags | length) == 0 then "tags 비어있음" else empty end),
        (if (.body | length) == 0 then "body 비어있음" else empty end),
        (if (.context | length) == 0 then "context 비어있음" else empty end)
    ] | if length > 0 then {slug: $r.slug, title: $r.title, quality: (if length > 2 then "poor" elif length > 0 then "fair" else "good" end), issues: .} else empty end
' "$ASSET_FILE" 2>/dev/null | jq -s '.' 2>/dev/null || echo "[]")

ISSUE_COUNT=$(echo "$ISSUES" | jq 'length')

if [[ "$FORMAT" == "json" ]]; then
    jq -n --argjson issues "$ISSUES" --argjson count "$ISSUE_COUNT" \
        '{status: "checked", issue_count: $count, issues: $issues}'
else
    if [[ "$ISSUE_COUNT" -eq 0 ]]; then
        echo "품질 게이트 PASS — 모든 자산 완성도 양호"
    else
        echo "품질 게이트: ${ISSUE_COUNT}건 보완 필요"
        echo "$ISSUES" | jq -r '.[] | "  [\(.quality)] \(.slug // .title) — \(.issues | join(", "))"'
    fi
fi
