#!/usr/bin/env bash
# query-assets.sh — JSONL 자산 검색
#
# Layer: L2 (Operation)
# 의존: common.sh (L1)
#
# 사용법:
#   query-assets.sh --tags "docker,build" [--types "guardrail,pattern"] [--format json|text|inject] [--limit 5] [--base-dir .harnish]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

TAGS="" TYPES="" FORMAT="json" LIMIT=5 BASE_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tags)     TAGS="$2"; shift 2;;
        --types)    TYPES="$2"; shift 2;;
        --format)   FORMAT="$2"; shift 2;;
        --limit)    LIMIT="$2"; shift 2;;
        --base-dir) BASE_DIR="$2"; shift 2;;
        *) echo "알 수 없는 옵션: $1" >&2; exit 1;;
    esac
done

if [[ -z "$TAGS" ]]; then
    echo "오류: --tags 필수" >&2
    exit 1
fi

[[ -z "$BASE_DIR" ]] && BASE_DIR="$(resolve_base_dir)"

RAG_FILE="${BASE_DIR}/harnish-rag.jsonl"

# --- 빈 결과 처리 ---
empty_result() {
    local tag_json
    tag_json=$(echo "$TAGS" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)
    case "$FORMAT" in
        json)   echo "{\"query\":{\"tags\":$tag_json,\"types\":[],\"limit\":$LIMIT},\"results\":[],\"count\":0}";;
        text)   echo "(검색 결과 없음)";;
        inject) echo -e "### 관련 자산 (asset-recorder)\n\n(관련 자산 없음)";;
    esac
    exit 0
}

if [[ ! -f "$RAG_FILE" ]] || [[ ! -s "$RAG_FILE" ]]; then
    empty_result
fi

# --- 태그/타입 배열 ---
IFS=',' read -ra QUERY_TAGS <<< "$TAGS"
for i in "${!QUERY_TAGS[@]}"; do
    QUERY_TAGS[$i]=$(echo "${QUERY_TAGS[$i]}" | xargs)
done

TAG_JSON=$(printf '%s\n' "${QUERY_TAGS[@]}" | jq -R . | jq -s .)

TYPE_JSON="[]"
if [[ -n "$TYPES" ]]; then
    TYPE_JSON=$(echo "$TYPES" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)
fi

# --- jq 필터 구성 ---
JQ_FILTER="select(.compressed != true)"

# 타입 필터
if [[ -n "$TYPES" ]]; then
    JQ_FILTER="${JQ_FILTER} | select([.type] | inside(${TYPE_JSON}))"
fi

# 태그 매칭 (OR: 하나라도 매칭)
JQ_FILTER="${JQ_FILTER} | select(.tags as \$t | ${TAG_JSON} | any(. as \$q | \$t | any(. == \$q)))"

# --- 검색 실행 ---
RESULTS=$(jq -c "${JQ_FILTER}" "$RAG_FILE" 2>/dev/null | head -n "$LIMIT" | jq -s '.' 2>/dev/null || echo "[]")
RESULT_COUNT=$(echo "$RESULTS" | jq 'length')

if [[ "$RESULT_COUNT" -eq 0 ]]; then
    empty_result
fi

# --- write-back: 매칭 레코드의 access_count 증분 + last_accessed_at 갱신 ---
# 출력 전에 실행 (empty_result 분기 시 skip됨 = OK, 매칭 0이면 갱신 불필요)
NOW_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
MATCHED_SLUGS=$(echo "$RESULTS" | jq -c '[.[].slug]')
TMP_RAG=$(mktemp "${RAG_FILE}.XXXXXX")
trap 'rm -f "$TMP_RAG"' EXIT
jq -c --arg now "$NOW_UTC" --argjson slugs "$MATCHED_SLUGS" \
  'if (.slug as $s | $slugs | any(. == $s))
   then . + {last_accessed_at: $now, access_count: ((.access_count // 0) + 1)}
   else . end' "$RAG_FILE" > "$TMP_RAG"
mv "$TMP_RAG" "$RAG_FILE"

# --- 출력 ---
case "$FORMAT" in
    json)
        jq -n \
            --argjson tags "$TAG_JSON" \
            --argjson types "$TYPE_JSON" \
            --argjson limit "$LIMIT" \
            --argjson results "$RESULTS" \
            --argjson count "$RESULT_COUNT" \
            '{query:{tags:$tags,types:$types,limit:$limit},results:$results,count:$count}'
        ;;
    text)
        echo "$RESULTS" | jq -r '.[] |
            "[\(.type)] \(.title) (\(.date)) — \(.body[0:50])" +
            "\n  tags: \(.tags | join(",")) | scope: \(.scope)\n"'
        ;;
    inject)
        echo "### 관련 자산 (asset-recorder)"
        echo ""
        echo "$RESULTS" | jq -r '.[] |
            "- **[\(.type)] \(.title)**: \(.body[0:100])"'
        ;;
    *)
        echo "오류: 알 수 없는 포맷 '$FORMAT'" >&2; exit 1;;
esac
