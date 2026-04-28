#!/usr/bin/env bats
# tests/e2e_workflow.bats — End-to-end: 진행 파이프라인 전체 체인
#
# 시나리오: init → validate → loop-step → compress-progress → progress-report → check-violations
# 각 스텝은 이전 스텝의 출력에 의존한다.

load "$BATS_TEST_DIRNAME/setup.bash"

# ── 공유 픽스처 ──────────────────────────────────────────────────────────────
WORK_MINIMAL='{
  "metadata": {
    "prd": "docs/prd-test.md",
    "started_at": "2026-01-01T00:00:00+09:00",
    "last_session": "2026-01-01T00:00:00+09:00",
    "ceremony_done": false,
    "status": {"emoji":"🟢","phase":1,"task":"1-1","label":"ok"}
  },
  "done":  {"phases": []},
  "doing": {"task": null},
  "todo":  {"phases": []},
  "issues":[], "violations":[], "escalations":[],
  "stats": {"total_phases":0,"completed_phases":0,"total_tasks":0,
            "completed_tasks":0,"issues_count":0,"violations_count":0}
}'

WORK_WITH_DONE='{
  "metadata": {
    "prd": "docs/prd-test.md",
    "started_at": "2026-01-01T00:00:00+09:00",
    "last_session": "2026-01-01T00:00:00+09:00",
    "ceremony_done": false,
    "status": {"emoji":"✅","phase":1,"task":"1-2","label":"done"}
  },
  "done": {"phases": [{
    "phase": 1, "title": "Phase Alpha", "compressed": false,
    "milestone_approved_at": "2026-01-02T00:00:00+09:00",
    "tasks": [
      {"id":"1-1","title":"T1","result":"done","files_changed":["a.py","b.py"],"verification":"pytest pass","duration":"2 turns"},
      {"id":"1-2","title":"T2","result":"done","files_changed":["c.py"],"verification":"ok","duration":"1 turn"}
    ]
  }]},
  "doing": {"task": null},
  "todo":  {"phases": []},
  "issues":[{"timestamp":"2026-01-01","task":"1-1","description":"minor","resolution":"fixed"}],
  "violations":[], "escalations":[],
  "stats": {"total_phases":1,"completed_phases":1,"total_tasks":2,
            "completed_tasks":2,"issues_count":1,"violations_count":0}
}'

setup() {
  harnish_sandbox_setup
  cd "$CLAUDE_PROJECT_DIR"
}

teardown() {
  harnish_sandbox_teardown
}

# ─── Step 1: init-assets.sh ──────────────────────────────────────────────────

@test "E2E step 1: init-assets creates .harnish/" {
  run bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  [ "$status" -eq 0 ]
  [ -d "$ASSET_BASE_DIR" ]
  [ -f "$ASSET_BASE_DIR/harnish-assets.jsonl" ]
  [ -f "$ASSET_BASE_DIR/harnish-current-work.json" ]
}

# ─── Step 2: validate-progress.sh ───────────────────────────────────────────

@test "E2E step 2: validate-progress accepts minimal work file" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_MINIMAL" > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/validate-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "정상" ]]
}

# ─── Step 3: loop-step.sh ────────────────────────────────────────────────────

@test "E2E step 3a: loop-step ALL_DONE on empty todo" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_MINIMAL" > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/loop-step.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ALL_DONE" ]]
}

@test "E2E step 3b: loop-step json format is parseable and contains expected keys" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_MINIMAL" > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/loop-step.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  # status, todo_remaining, done_count must be present
  STATUS=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['status'])")
  [ "$STATUS" = "ALL_DONE" ]
  TODO=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['todo_remaining'])")
  [ "$TODO" = "0" ]
}

# ─── Step 4: compress-progress.sh ───────────────────────────────────────────

@test "E2E step 4a: compress-progress milestone compresses phase and creates archive" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_WITH_DONE" > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/compress-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --trigger milestone --phase 1
  [ "$status" -eq 0 ]
  # archive created
  [ -f "$ASSET_BASE_DIR/harnish-progress-archive.jsonl" ]
  # archive is valid JSON
  python3 -m json.tool "$ASSET_BASE_DIR/harnish-progress-archive.jsonl" > /dev/null
  # work file phase now compressed
  COMPRESSED=$(python3 -c "
import json
d = json.load(open('$ASSET_BASE_DIR/harnish-current-work.json'))
print(d['done']['phases'][0]['compressed'])
")
  [ "$COMPRESSED" = "True" ]
}

@test "E2E step 4b: compress-progress dry-run leaves archive untouched" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_WITH_DONE" > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/compress-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --trigger count --dry-run
  [ "$status" -eq 0 ]
  # no archive should have been created in dry-run
  [ ! -f "$ASSET_BASE_DIR/harnish-progress-archive.jsonl" ]
}

# ─── Step 5: progress-report.sh ─────────────────────────────────────────────

@test "E2E step 5: progress-report renders markdown with expected sections" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_WITH_DONE" > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/progress-report.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "완료 (Done)" ]]
  [[ "$output" =~ "진행 중 (Doing)" ]]
  [[ "$output" =~ "예정 (Todo)" ]]
  [[ "$output" =~ "Phase Alpha" ]]
}

# ─── Step 6: check-violations.sh ─────────────────────────────────────────────

@test "E2E step 6: check-violations reports 0 on clean work file" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  echo "$WORK_WITH_DONE" > "$ASSET_BASE_DIR/harnish-current-work.json"
  run bash "$REPO_ROOT/scripts/check-violations.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0건" ]] || [[ "$output" =~ "위반 기록: 0" ]]
}

# ─── Full chain: init → validate → loop-step → report ───────────────────────

@test "E2E full chain: all steps run sequentially without error" {
  # Step 1
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  # Step 2: seed work file
  echo "$WORK_WITH_DONE" > "$ASSET_BASE_DIR/harnish-current-work.json"
  # Step 3: validate
  bash "$REPO_ROOT/scripts/validate-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  # Step 4: loop-step
  STATUS=$(bash "$REPO_ROOT/scripts/loop-step.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --format json \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
  [ "$STATUS" = "ALL_DONE" ]
  # Step 5: compress
  bash "$REPO_ROOT/scripts/compress-progress.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json" --trigger milestone --phase 1
  # Step 6: report
  REPORT=$(bash "$REPO_ROOT/scripts/progress-report.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json")
  [[ "$REPORT" =~ "압축됨" ]]
  # Step 7: violations
  run bash "$REPO_ROOT/scripts/check-violations.sh" \
    "$ASSET_BASE_DIR/harnish-current-work.json"
  [ "$status" -eq 0 ]
}
