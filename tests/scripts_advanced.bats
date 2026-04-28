#!/usr/bin/env bats
# tests/scripts_advanced.bats — smoke tests for scripts not covered by scripts.bats
#
# Covers: validate-progress.sh, loop-step.sh, compress-progress.sh,
#         quality-gate.sh, compress-assets.sh, skillify.sh,
#         abstract-asset.sh, localize-asset.sh, migrate.sh

load "$BATS_TEST_DIRNAME/setup.bash"

# ── minimal valid harnish-current-work.json ──────────────────────────────────
WORK_JSON='{
  "metadata": {
    "prd": "docs/prd-test.md",
    "started_at": "2026-01-01T00:00:00+09:00",
    "last_session": "2026-01-01T00:00:00+09:00",
    "status": {"emoji": "🟢", "phase": 1, "task": "1-1", "label": "ok"}
  },
  "done":  {"phases": []},
  "doing": {"task": null},
  "todo":  {"phases": []},
  "issues": [], "violations": [], "escalations": [],
  "stats": {"total_phases":0,"completed_phases":0,"total_tasks":0,
            "completed_tasks":0,"issues_count":0,"violations_count":0}
}'

setup() {
  harnish_sandbox_setup
  cd "$CLAUDE_PROJECT_DIR"
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_JSON" > "$ASSET_BASE_DIR/harnish-current-work.json"
}

teardown() {
  harnish_sandbox_teardown
}

# ─── validate-progress.sh ────────────────────────────────────────────────────

@test "validate-progress.sh passes on a minimal valid work file" {
  run bash "$REPO_ROOT/scripts/validate-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "정상" ]]
}

@test "validate-progress.sh exits 1 when file is missing" {
  run bash "$REPO_ROOT/scripts/validate-progress.sh" \
    "$ASSET_BASE_DIR/no-such-file.json"
  [ "$status" -eq 1 ]
}

@test "validate-progress.sh exits 1 on invalid JSON" {
  echo 'not json' > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/validate-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 1 ]
}

# ─── loop-step.sh ────────────────────────────────────────────────────────────

@test "loop-step.sh reports ALL_DONE when todo and doing are empty" {
  run bash "$REPO_ROOT/scripts/loop-step.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ALL_DONE" ]]
}

@test "loop-step.sh --format json emits valid JSON" {
  run bash "$REPO_ROOT/scripts/loop-step.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool >/dev/null
}

@test "loop-step.sh exits 1 when file is missing" {
  run bash "$REPO_ROOT/scripts/loop-step.sh" \
    "$ASSET_BASE_DIR/no-such-file.json"
  [ "$status" -eq 1 ]
}

# ─── compress-progress.sh ────────────────────────────────────────────────────

@test "compress-progress.sh --dry-run reports nothing to compress on empty done" {
  run bash "$REPO_ROOT/scripts/compress-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --trigger count --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" =~ "없음" ]]
}

@test "compress-progress.sh milestone compresses target phase" {
  # Inject a done phase to compress
  WORK_WITH_DONE=$(echo "$WORK_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['done']['phases'] = [{
    'phase': 1, 'title': 'Phase One', 'compressed': False,
    'milestone_approved_at': '2026-01-01T00:00:00+09:00',
    'tasks': [{'id':'1-1','title':'t1','result':'done','files_changed':[],'verification':'ok','duration':'1'}]
}]
print(json.dumps(d))
")
  echo "$WORK_WITH_DONE" > "$ASSET_BASE_DIR/harnish-current-work.json"

  run bash "$REPO_ROOT/scripts/compress-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --trigger milestone --phase 1
  [ "$status" -eq 0 ]
  # archive file must be created
  [ -f "$ASSET_BASE_DIR/harnish-progress-archive.jsonl" ]
  # work file phase must now be compressed
  COMPRESSED=$(jq '.done.phases[0].compressed' "$ASSET_BASE_DIR/harnish-current-work.json")
  [ "$COMPRESSED" = "true" ]
}

# ─── quality-gate.sh ─────────────────────────────────────────────────────────

@test "quality-gate.sh passes on empty store" {
  run bash "$REPO_ROOT/scripts/quality-gate.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "없음" ]]
}

@test "quality-gate.sh --format json emits valid JSON" {
  run bash "$REPO_ROOT/scripts/quality-gate.sh" \
    --base-dir "$ASSET_BASE_DIR" --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool >/dev/null
}

@test "quality-gate.sh flags records with empty body" {
  echo '{"type":"pattern","slug":"x","title":"t","tags":["a"],"body":"","context":"","schema_version":"0.0.2","last_accessed_at":"2026-01-01T00:00:00Z","access_count":0}' \
    >> "$ASSET_BASE_DIR/harnish-assets.jsonl"
  run bash "$REPO_ROOT/scripts/quality-gate.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "보완" ]]
}

# ─── compress-assets.sh ──────────────────────────────────────────────────────

@test "compress-assets.sh --all exits cleanly on empty store" {
  run bash "$REPO_ROOT/scripts/compress-assets.sh" \
    --all --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "empty" ]]
}

@test "compress-assets.sh --dry-run does not modify the RAG file" {
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "api" --title "p1" --body "b1" \
    --base-dir "$ASSET_BASE_DIR"
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "api" --title "p2" --body "b2" \
    --base-dir "$ASSET_BASE_DIR"
  BEFORE=$(wc -l < "$ASSET_BASE_DIR/harnish-assets.jsonl" | xargs)
  run bash "$REPO_ROOT/scripts/compress-assets.sh" \
    --tag api --dry-run --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  AFTER=$(wc -l < "$ASSET_BASE_DIR/harnish-assets.jsonl" | xargs)
  [ "$BEFORE" -eq "$AFTER" ]
}

@test "compress-assets.sh body does not contain TODO after compression" {
  for i in 1 2 3 4 5 6; do
    bash "$REPO_ROOT/scripts/record-asset.sh" \
      --type pattern --tags "db" --title "pat-$i" --body "body-$i" \
      --base-dir "$ASSET_BASE_DIR"
  done
  run bash "$REPO_ROOT/scripts/compress-assets.sh" \
    --tag db --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  # compressed summary record must not contain the word TODO
  run grep -c "TODO" "$ASSET_BASE_DIR/harnish-assets.jsonl"
  [ "$output" = "0" ]
}

# ─── abstract-asset.sh ───────────────────────────────────────────────────────

@test "abstract-asset.sh creates a -generic slug record" {
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "docker" --title "my-pattern" --body "detail" \
    --scope project --base-dir "$ASSET_BASE_DIR"
  run bash "$REPO_ROOT/scripts/abstract-asset.sh" \
    --slug "my-pattern" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  grep -q '"slug":"my-pattern-generic"' "$ASSET_BASE_DIR/harnish-assets.jsonl"
}

@test "abstract-asset.sh exits 1 on missing slug" {
  run bash "$REPO_ROOT/scripts/abstract-asset.sh" \
    --slug "nonexistent-slug" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 1 ]
}

# ─── localize-asset.sh ───────────────────────────────────────────────────────

@test "localize-asset.sh creates a -local slug record" {
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type guardrail --tags "api" --title "gen-rule" --body "never do x" \
    --scope generic --base-dir "$ASSET_BASE_DIR"
  run bash "$REPO_ROOT/scripts/localize-asset.sh" \
    --slug "gen-rule" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  grep -q '"slug":"gen-rule-local"' "$ASSET_BASE_DIR/harnish-assets.jsonl"
}

@test "localize-asset.sh exits 1 on missing slug" {
  run bash "$REPO_ROOT/scripts/localize-asset.sh" \
    --slug "nonexistent-slug" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 1 ]
}

# ─── migrate.sh ──────────────────────────────────────────────────────────────

@test "migrate.sh is no-op on empty RAG file" {
  run bash "$REPO_ROOT/scripts/migrate.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "no-op" ]]
}

@test "migrate.sh backfills schema_version on v0.0.1 records" {
  echo '{"type":"pattern","slug":"old","title":"t","tags":["x"],"body":"b","schema_version":"0.0.1"}' \
    >> "$ASSET_BASE_DIR/harnish-assets.jsonl"
  run bash "$REPO_ROOT/scripts/migrate.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "migrated" ]]
  VERSION=$(jq -r '.schema_version' "$ASSET_BASE_DIR/harnish-assets.jsonl")
  [ "$VERSION" = "0.0.2" ]
}

# ─── skillify.sh ─────────────────────────────────────────────────────────────

@test "skillify.sh generates SKILL.md in --output-dir" {
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "redis" --title "cache-pattern" --body "use LRU" \
    --base-dir "$ASSET_BASE_DIR"
  OUT_DIR="$CLAUDE_PROJECT_DIR/generated-skills"
  run bash "$REPO_ROOT/scripts/skillify.sh" \
    --tag redis --skill-name redis-patterns \
    --output-dir "$OUT_DIR" \
    --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUT_DIR/redis-patterns/SKILL.md" ]
}

@test "skillify.sh exits 1 when tag has no assets" {
  run bash "$REPO_ROOT/scripts/skillify.sh" \
    --tag nonexistent --skill-name x \
    --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 1 ]
}

# ─── init-assets.sh — legacy migration ───────────────────────────────────────

@test "init-assets.sh migrates legacy harnish-rag.jsonl to harnish-assets.jsonl" {
  # Wipe sandbox dir and start fresh, simulating an old-format install.
  rm -rf "$ASSET_BASE_DIR"
  mkdir -p "$ASSET_BASE_DIR"
  echo '{"type":"pattern","slug":"legacy","title":"legacy-record","tags":["x"],"body":"b","date":"2025-01-01","schema_version":"0.0.2"}' \
    > "$ASSET_BASE_DIR/harnish-rag.jsonl"

  run bash "$REPO_ROOT/scripts/init-assets.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  # 새 파일이 생성되어야 함
  [ -f "$ASSET_BASE_DIR/harnish-assets.jsonl" ]
  # 레거시 파일은 사라져야 함
  [ ! -f "$ASSET_BASE_DIR/harnish-rag.jsonl" ]
  # 콘텐츠가 보존되어야 함
  grep -q '"slug":"legacy"' "$ASSET_BASE_DIR/harnish-assets.jsonl"
}

@test "init-assets.sh idempotent migration — leaves new file alone if both exist" {
  rm -rf "$ASSET_BASE_DIR"
  mkdir -p "$ASSET_BASE_DIR"
  # 둘 다 있으면 신규를 보존하고 레거시를 건드리지 않아야 함
  echo '{"slug":"new"}'    > "$ASSET_BASE_DIR/harnish-assets.jsonl"
  echo '{"slug":"legacy"}' > "$ASSET_BASE_DIR/harnish-rag.jsonl"
  bash "$REPO_ROOT/scripts/init-assets.sh" --base-dir "$ASSET_BASE_DIR" --quiet
  grep -q '"slug":"new"' "$ASSET_BASE_DIR/harnish-assets.jsonl"
  # 레거시 파일은 그대로 존재 (사용자가 수동 삭제할 수 있도록)
  [ -f "$ASSET_BASE_DIR/harnish-rag.jsonl" ]
}

# ─── purge-assets.sh --execute ───────────────────────────────────────────────

@test "purge-assets.sh --execute purges old records and creates archive" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  # Insert a very old decision record (> 365 days, access_count 0)
  echo '{"type":"decision","slug":"stale-dec","title":"old decision","tags":["arch"],"body":"body","context":"ctx","date":"2020-01-01","scope":"generic","session":"manual","schema_version":"0.0.2","last_accessed_at":"2020-01-01T00:00:00Z","access_count":0,"confidence":"medium"}' \
    >> "$ASSET_BASE_DIR/harnish-assets.jsonl"
  BEFORE=$(wc -l < "$ASSET_BASE_DIR/harnish-assets.jsonl" | xargs)

  run bash "$REPO_ROOT/scripts/purge-assets.sh" --execute \
    --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  STATUS=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
  [ "$STATUS" = "purged" ]

  AFTER=$(wc -l < "$ASSET_BASE_DIR/harnish-assets.jsonl" | xargs)
  [ "$AFTER" -lt "$BEFORE" ]
  [ -f "$ASSET_BASE_DIR/harnish-assets-archive.jsonl" ]
}

@test "purge-assets.sh --execute no-op when no candidates" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  # Insert a fresh pattern (never purged)
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "api" --title "recent" --body "b" \
    --base-dir "$ASSET_BASE_DIR"
  run bash "$REPO_ROOT/scripts/purge-assets.sh" --execute \
    --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  STATUS=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
  [ "$STATUS" = "no_candidates" ]
}

# ─── loop-step.sh --format without explicit path ─────────────────────────────

@test "loop-step.sh --format json without explicit path parses correctly" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  # Put a minimal valid work file in place
  echo '{"metadata":{"prd":"p","started_at":"2026-01-01","last_session":"2026-01-01","ceremony_done":false,"status":{"emoji":"🟢","phase":1,"task":"1-1","label":"ok"}},"done":{"phases":[]},"doing":{"task":null},"todo":{"phases":[]},"issues":[],"violations":[],"escalations":[],"stats":{"total_phases":0,"completed_phases":0,"total_tasks":0,"completed_tasks":0,"issues_count":0,"violations_count":0}}' \
    > "$ASSET_BASE_DIR/harnish-current-work.json"
  # Call loop-step with --format json but NO explicit file path
  # It should resolve the file via ASSET_BASE_DIR
  run bash -c "ASSET_BASE_DIR='$ASSET_BASE_DIR' bash '$REPO_ROOT/scripts/loop-step.sh' --format json"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  STATUS=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
  [ "$STATUS" = "ALL_DONE" ]
}

# ─── detect-asset.sh — meaningful error → pending ────────────────────────────

@test "detect-asset.sh meaningful error creates pending file" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  SESSION_ID="bats-test-session-$$"
  run bash -c "
    echo '{
      \"hook_event_name\":\"PostToolUseFailure\",
      \"tool_name\":\"Bash\",
      \"tool_output\":\"ImportError: cannot import name xyz\",
      \"session_id\":\"$SESSION_ID\"
    }' | ASSET_BASE_DIR='$ASSET_BASE_DIR' CLAUDE_SESSION_ID='$SESSION_ID' \
        bash '$REPO_ROOT/scripts/detect-asset.sh'
  "
  [ "$status" -eq 0 ]
  # pending file must exist and contain the error
  [ -f "/tmp/harnish-pending-${SESSION_ID}.jsonl" ]
  grep -q "ImportError" "/tmp/harnish-pending-${SESSION_ID}.jsonl"
  rm -f "/tmp/harnish-pending-${SESSION_ID}.jsonl"
}

@test "detect-asset.sh Stop event deletes pending file" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  SESSION_ID="bats-stop-session-$$"
  PF="/tmp/harnish-pending-${SESSION_ID}.jsonl"
  echo '{"event":"test","output":"some error"}' > "$PF"

  run bash -c "
    echo '{
      \"hook_event_name\":\"Stop\",
      \"tool_name\":\"Bash\",
      \"session_id\":\"$SESSION_ID\"
    }' | ASSET_BASE_DIR='$ASSET_BASE_DIR' CLAUDE_SESSION_ID='$SESSION_ID' \
        bash '$REPO_ROOT/scripts/detect-asset.sh'
  "
  [ "$status" -eq 0 ]
  [ ! -f "$PF" ]
}
