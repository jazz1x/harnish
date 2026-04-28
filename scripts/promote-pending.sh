#!/usr/bin/env bash
# promote-pending.sh — /tmp/harnish-pending-*.jsonl을 deduplicate 후 자산으로 자동 등록
#
# Layer: L4 (Interface) — hook과 record-asset.sh 사이의 promotion 레이어
# 의존: common.sh, record-asset.sh
#
# 사용법:
#   promote-pending.sh --session SESSION_ID [--base-dir .harnish] [--dry-run]
#   promote-pending.sh                                        # CLAUDE_SESSION_ID 또는 PID 해시
#
# 출력 (JSON):
#   {"status":"promoted","promoted":N,"deduplicated":M,"skipped":K}
#   {"status":"empty"}
#   {"status":"no_pending"}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
SESSION=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --session)  SESSION="$2"; shift 2;;
        --base-dir) BASE="$2";    shift 2;;
        --dry-run)  DRY_RUN=true; shift;;
        *) shift;;
    esac
done

# 세션 해시 결정
if [[ -z "$SESSION" ]]; then
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
        SESSION="$CLAUDE_SESSION_ID"
    else
        SESSION=$(echo "$$" | md5 2>/dev/null | cut -c1-8 || echo "$$" | md5sum 2>/dev/null | cut -c1-8 || echo "unknown")
    fi
fi

PENDING_FILE="/tmp/harnish-pending-${SESSION}.jsonl"

if [[ ! -f "$PENDING_FILE" ]]; then
    echo '{"status":"no_pending","promoted":0,"deduplicated":0,"skipped":0}'
    exit 0
fi

if [[ ! -s "$PENDING_FILE" ]]; then
    echo '{"status":"empty","promoted":0,"deduplicated":0,"skipped":0}'
    exit 0
fi

# 첫 의미있는 라인을 추출하는 jq filter (헬퍼)
# pending JSONL의 각 라인은 {event, tool, output, session, date}
# dedup key = tool + first non-empty line of output (50자 truncate)

# Step 1: dedup
# 각 라인을 key로 그룹화하고 첫 번째 항목 + count 보존
DEDUP_OUT=$(jq -sc '
    map(
        . + {
            __key: ((.tool // "") + "|" + (
                (.output // "") | split("\n") | map(select(length > 0)) | first // "" | .[0:50]
            ))
        }
    )
    | group_by(.__key)
    | map({
        tool: (.[0].tool // ""),
        output: (.[0].output // ""),
        session: (.[0].session // ""),
        date: (.[0].date // ""),
        occurrences: length
    })
' "$PENDING_FILE")

UNIQUE_COUNT=$(echo "$DEDUP_OUT" | jq 'length')
TOTAL_COUNT=$(wc -l < "$PENDING_FILE" | xargs)
DEDUP_COUNT=$((TOTAL_COUNT - UNIQUE_COUNT))

if [[ "$UNIQUE_COUNT" -eq 0 ]]; then
    echo '{"status":"empty","promoted":0,"deduplicated":0,"skipped":0}'
    exit 0
fi

# Step 2: dry-run 처리
if $DRY_RUN; then
    jq -n -c \
        --arg status "dry_run" \
        --argjson promoted "$UNIQUE_COUNT" \
        --argjson dedup "$DEDUP_COUNT" \
        --argjson candidates "$DEDUP_OUT" \
        '{status:$status, promoted:$promoted, deduplicated:$dedup, candidates:$candidates}'
    exit 0
fi

# Step 3: 각 unique entry를 record-asset.sh로 등록
PROMOTED=0
SKIPPED=0
SHORT_SESSION="${SESSION:0:8}"

# echo "$DEDUP_OUT" | jq -c '.[]'를 줄별 처리
while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue

    TOOL=$(echo "$entry" | jq -r '.tool // ""')
    OUTPUT=$(echo "$entry" | jq -r '.output // ""')
    OCCURRENCES=$(echo "$entry" | jq -r '.occurrences // 1')

    # 빈 output skip
    [[ -z "$OUTPUT" ]] && SKIPPED=$((SKIPPED + 1)) && continue

    # 첫 라인을 title로
    FIRST_LINE=$(echo "$OUTPUT" | grep -m1 '[^[:space:]]' || echo "")
    [[ -z "$FIRST_LINE" ]] && SKIPPED=$((SKIPPED + 1)) && continue

    # title은 60자 truncate
    TITLE="${FIRST_LINE:0:60}"

    # tags
    TAGS="auto,tool:${TOOL},session:${SHORT_SESSION}"

    # context
    CONTEXT="auto-promoted from pending (occurrences: ${OCCURRENCES})"

    # record-asset.sh 호출
    if bash "$SCRIPT_DIR/record-asset.sh" \
        --type failure \
        --tags "$TAGS" \
        --title "$TITLE" \
        --body "$OUTPUT" \
        --context "$CONTEXT" \
        --scope project \
        --session-id "$SESSION" \
        --base-dir "$BASE" >/dev/null 2>&1; then
        PROMOTED=$((PROMOTED + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done < <(echo "$DEDUP_OUT" | jq -c '.[]')

# Step 4: 출력
jq -n -c \
    --arg status "promoted" \
    --argjson promoted "$PROMOTED" \
    --argjson dedup "$DEDUP_COUNT" \
    --argjson skipped "$SKIPPED" \
    '{status:$status, promoted:$promoted, deduplicated:$dedup, skipped:$skipped}'
