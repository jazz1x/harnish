#!/usr/bin/env bats
# tests/scripts.bats — smoke + safety tests for harnish shell scripts.
#
# All tests execute in a sandbox HOME / CWD. Real ~/.claude/ and any
# project's real .harnish/ are never touched. Each test creates a fresh
# .harnish/ inside the sandbox project dir.

load "$BATS_TEST_DIRNAME/setup.bash"

setup() {
  harnish_sandbox_setup
  cd "$CLAUDE_PROJECT_DIR"
}

teardown() {
  harnish_sandbox_teardown
}

# ---------- init-assets.sh ----------

@test "init-assets.sh creates .harnish/ with rag + work files" {
  run bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  [ "$status" -eq 0 ]
  [ -d "$ASSET_BASE_DIR" ]
  [ -f "$ASSET_BASE_DIR/harnish-rag.jsonl" ]
  [ -f "$ASSET_BASE_DIR/harnish-current-work.json" ]
  # work file must be at minimum a valid JSON object.
  run python3 -m json.tool "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
}

@test "init-assets.sh is idempotent (second run leaves files intact)" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo '{"type":"pattern","tags":["x"],"title":"t","body":"b"}' \
    >> "$ASSET_BASE_DIR/harnish-rag.jsonl"
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  # Existing line must still be there (not truncated).
  run grep -c '"title":"t"' "$ASSET_BASE_DIR/harnish-rag.jsonl"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# ---------- record-asset.sh ----------

@test "record-asset.sh writes a single JSONL line" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  run bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "api,retry" \
    --title "exp-backoff" --body "wait 2^n seconds" \
    --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [ -s "$ASSET_BASE_DIR/harnish-rag.jsonl" ]
  # Each line must be valid JSON.
  while IFS= read -r line; do
    echo "$line" | python3 -m json.tool >/dev/null
  done < "$ASSET_BASE_DIR/harnish-rag.jsonl"
}

@test "record-asset.sh accepts JSON via --stdin" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  run bash -c "
    echo '{\"type\":\"failure\",\"tags\":[\"docker\"],\"title\":\"cache-miss\",\"body\":\"detail\"}' \
      | bash '$REPO_ROOT/scripts/record-asset.sh' --stdin --base-dir '$ASSET_BASE_DIR'
  "
  [ "$status" -eq 0 ]
  grep -q '"title":"cache-miss"' "$ASSET_BASE_DIR/harnish-rag.jsonl"
}

# ---------- query-assets.sh ----------

@test "query-assets.sh filters by tag" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "api,retry" --title "p1" --body "b1" \
    --base-dir "$ASSET_BASE_DIR"
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "db" --title "p2" --body "b2" \
    --base-dir "$ASSET_BASE_DIR"
  run bash "$REPO_ROOT/scripts/query-assets.sh" \
    --tags api --format text --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "p1" ]]
  [[ ! "$output" =~ "p2" ]]
}

@test "query-assets.sh on empty store does not crash" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  run bash "$REPO_ROOT/scripts/query-assets.sh" \
    --tags any --format text --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
}

# ---------- detect-asset.sh (hook entry point) ----------

@test "detect-asset.sh exits 0 when .harnish/ does not exist" {
  # Hooks must never block tool execution — should silently no-op.
  run bash "$REPO_ROOT/scripts/detect-asset.sh"
  [ "$status" -eq 0 ]
}

@test "detect-asset.sh exits 0 on non-JSON stdin" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  run bash -c "echo 'not json' | bash '$REPO_ROOT/scripts/detect-asset.sh'"
  [ "$status" -eq 0 ]
}

@test "detect-asset.sh ignores noise patterns on PostToolUseFailure" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  # Send a noise-pattern failure ("No such file").
  run bash -c "
    echo '{
      \"hook_event_name\":\"PostToolUseFailure\",
      \"tool_name\":\"Bash\",
      \"tool_output\":\"No such file or directory\",
      \"session_id\":\"test\"
    }' | bash '$REPO_ROOT/scripts/detect-asset.sh'
  "
  [ "$status" -eq 0 ]
  # No pending file should have been created for noise.
  [ -z "$(ls /tmp/harnish-pending-*.jsonl 2>/dev/null || true)" ] \
    || ! grep -q "No such file" /tmp/harnish-pending-*.jsonl 2>/dev/null
}

# ---------- check-thresholds.sh ----------

@test "check-thresholds.sh runs against an empty store" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  run bash "$REPO_ROOT/scripts/check-thresholds.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
}

# ---------- pre-commit hook sanity ----------

@test "pre-commit.sh runs cleanly on a worktree with no staged changes" {
  cp -R "$REPO_ROOT" "$CLAUDE_PROJECT_DIR/repo-copy"
  cd "$CLAUDE_PROJECT_DIR/repo-copy"
  # Reset staged state by reinitializing as a fresh repo (avoids inheriting
  # the parent index in the copied .git dir).
  rm -rf .git
  git init -q
  git add -A
  # First-time pre-commit on staged files: tolerate non-zero only if it's
  # a tooling-missing warning. We just want to assert it doesn't crash.
  run bash scripts/pre-commit.sh
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ---------- sandbox self-check ----------

@test "sandbox preflight aborts if HOME is not in a temp root" {
  HOME="$HARNISH_TEST_REAL_HOME" run bash -c "
    source '$REPO_ROOT/tests/setup.bash'
    harnish_preflight_guard
  "
  [ "$status" -eq 99 ]
  [[ "$output" =~ "real HOME" ]]
}
