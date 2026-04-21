#!/usr/bin/env bash
# migrate.sh — schema migration with backfill
# Layer: L3 (Aggregate)
# Usage: migrate.sh [--base-dir .harnish] [--target 0.0.2]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
TARGET="0.0.2"

while [[ $# -gt 0 ]]; do
    case $1 in
        --base-dir) BASE="$2"; shift 2;;
        --target)   TARGET="$2"; shift 2;;
        *) shift;;
    esac
done

RAG="$BASE/harnish-rag.jsonl"
LOG="$BASE/harnish-migration-log.jsonl"

[[ -f "$RAG" ]] || { echo '{"status":"no-op","reason":"rag file absent"}'; exit 0; }
[[ -s "$RAG" ]] || { echo '{"status":"no-op","reason":"rag file empty"}'; exit 0; }

# Backup
NOW_EPOCH=$(date +%s)
BAK="${RAG}.bak.${NOW_EPOCH}"
cp "$RAG" "$BAK"

# Migrate: backfill 3 fields if schema_version missing or older
NOW_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TMP=$(mktemp "${RAG}.XXXXXX")
trap 'rm -f "$TMP"' EXIT

MIGRATED=0
SKIPPED=0
while IFS= read -r line; do
    current=$(echo "$line" | jq -r '.schema_version // "0.0.1"')
    if [[ "$current" == "0.0.1" ]]; then
        # 백필: last_accessed_at = created_at(.date 값), access_count = 0
        echo "$line" | jq -c --arg v "$TARGET" --argjson ac 0 '
          . + {
            schema_version: $v,
            last_accessed_at: (.last_accessed_at // .date),
            access_count: (.access_count // $ac)
          }' >> "$TMP"
        MIGRATED=$((MIGRATED+1))
    else
        echo "$line" >> "$TMP"
        SKIPPED=$((SKIPPED+1))
    fi
done < "$RAG"

mv "$TMP" "$RAG"

# Log
jq -n -c \
  --arg ts "$NOW_UTC" \
  --arg from "0.0.1" \
  --arg to "$TARGET" \
  --argjson migrated "$MIGRATED" \
  --argjson skipped "$SKIPPED" \
  --arg backup "$BAK" \
  '{ts:$ts, from:$from, to:$to, migrated:$migrated, skipped:$skipped, backup:$backup}' \
  >> "$LOG"

echo "{\"status\":\"migrated\",\"migrated\":$MIGRATED,\"skipped\":$SKIPPED,\"backup\":\"$BAK\"}"
