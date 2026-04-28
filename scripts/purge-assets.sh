#!/usr/bin/env bash
# purge-assets.sh — TTL 기반 자산 purge (dry-run 기본)
# Layer: L3 (Aggregate)
# Usage: purge-assets.sh [--execute] [--base-dir .harnish]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
EXECUTE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --execute)  EXECUTE=true; shift;;
        --base-dir) BASE="$2"; shift 2;;
        *) shift;;
    esac
done

ASSETS="$BASE/harnish-assets.jsonl"
ARCHIVE="$BASE/harnish-assets-archive.jsonl"

[[ -f "$ASSETS" ]] || { echo '{"status":"no-op","reason":"asset file absent"}'; exit 0; }

# Hardcoded defaults (retention-policy.md 참조; 향후 파싱 확장 가능)
# ttl_days: decision=365, failure=90, pattern=never, guardrail=never, snippet=180
# safety_window_hours = 24
# min_access_count = 1 (decision only)

NOW_EPOCH=$(date +%s)
SAFETY_SEC=$((24 * 3600))

# jq filter: purge 대상 판정
PURGE_FILTER='
  def ttl_days:
    if .type == "decision" then 365
    elif .type == "failure" then 90
    elif .type == "snippet" then 180
    elif .type == "pattern" or .type == "guardrail" then -1
    else 180 end;
  def created_epoch:
    (.date // "1970-01-01") | strptime("%Y-%m-%d") | mktime;
  def is_purge_candidate:
    ttl_days as $ttl
    | if $ttl < 0 then false
      else
        (($now_epoch - created_epoch) > ($ttl * 86400))
        and (($now_epoch - created_epoch) > $safety_sec)
        and (if .type == "decision" then (.access_count // 0) < 1 else true end)
      end;
  is_purge_candidate
'

CANDIDATES=$(jq -c --argjson now_epoch "$NOW_EPOCH" --argjson safety_sec "$SAFETY_SEC" \
    "select($PURGE_FILTER)" "$ASSETS" 2>/dev/null || echo "")
CANDIDATE_COUNT=$(echo "$CANDIDATES" | awk 'NF' | wc -l | xargs)

if ! $EXECUTE; then
    # Dry-run: 출력만
    C_JSON=$(echo "$CANDIDATES" | awk 'NF' | jq -s '.')
    jq -n -c --argjson c "$C_JSON" --argjson count "$CANDIDATE_COUNT" \
        '{status:"dry_run",candidates:$c,count:$count}'
    exit 0
fi

# Execute: 아카이브 + 원본 재작성
[[ "$CANDIDATE_COUNT" -eq 0 ]] && { echo '{"status":"no_candidates","purged":0}'; exit 0; }

# Append candidates to archive
echo "$CANDIDATES" >> "$ARCHIVE"

# Rewrite asset file with non-candidates
TMP=$(mktemp "${ASSETS}.XXXXXX")
trap 'rm -f "$TMP"' EXIT
jq -c --argjson now_epoch "$NOW_EPOCH" --argjson safety_sec "$SAFETY_SEC" \
    "select($PURGE_FILTER | not)" "$ASSETS" > "$TMP"
mv "$TMP" "$ASSETS"

echo "{\"status\":\"purged\",\"purged\":$CANDIDATE_COUNT,\"archive\":\"$ARCHIVE\"}"
