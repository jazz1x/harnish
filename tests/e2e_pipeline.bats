#!/usr/bin/env bats
# tests/e2e_pipeline.bats — v0.0.5 production pipeline E2E
#
# 시나리오:
#   1. hook trigger → pending → Stop → assets 자동 승격 (CRITICAL gap 회귀)
#   2. 동일 에러 N회 → dedup 1건 + occurrences:N 메타
#   3. skillify → Triggers + 타입별 섹션 + references/source-assets.jsonl
#   4. query --format inject → context + level + confidence + resolved 포함

load "$BATS_TEST_DIRNAME/setup.bash"

setup() {
  harnish_sandbox_setup
  cd "$CLAUDE_PROJECT_DIR"
}

teardown() {
  # pending 파일이 leak되지 않도록 정리
  find /tmp -maxdepth 1 -name 'harnish-pending-pipeline-*.jsonl' -delete 2>/dev/null || true
  harnish_sandbox_teardown
}

# ─── 시나리오 1 — hook → pending → Stop → assets 자동 승격 ─────────────────

@test "E2E pipeline 1: hook trigger promotes pending to assets on Stop" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  SESSION="pipeline-promote-$$"
  PF="/tmp/harnish-pending-${SESSION}.jsonl"
  rm -f "$PF"

  # 의미있는 실패 1건 — pending 적재
  echo '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_output":"ImportError: requests module","session_id":"'"$SESSION"'"}' \
    | ASSET_BASE_DIR="$ASSET_BASE_DIR" CLAUDE_SESSION_ID="$SESSION" \
      bash "$REPO_ROOT/scripts/detect-asset.sh"
  [ -s "$PF" ]

  # 자산 파일은 아직 비어있음
  [ ! -s "$ASSET_BASE_DIR/harnish-assets.jsonl" ]

  # Stop event → 자동 승격
  run bash -c "
    echo '{\"hook_event_name\":\"Stop\",\"session_id\":\"$SESSION\"}' \
      | ASSET_BASE_DIR='$ASSET_BASE_DIR' CLAUDE_SESSION_ID='$SESSION' \
        bash '$REPO_ROOT/scripts/detect-asset.sh'
  "
  [ "$status" -eq 0 ]
  [[ "$output" =~ "자산 승격" ]]

  # pending은 삭제
  [ ! -f "$PF" ]
  # 자산 파일에 기록 존재
  [ -s "$ASSET_BASE_DIR/harnish-assets.jsonl" ]
  # 자동 태그 검증
  jq -e '.tags[] | select(.=="auto")'  "$ASSET_BASE_DIR/harnish-assets.jsonl" >/dev/null
  jq -e '.tags[] | select(.=="tool:Bash")' "$ASSET_BASE_DIR/harnish-assets.jsonl" >/dev/null
}

# ─── 시나리오 2 — 동일 에러 N회 dedup ──────────────────────────────────────

@test "E2E pipeline 2: duplicate errors are dedup'd with occurrences metadata" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  SESSION="pipeline-dedup-$$"
  PF="/tmp/harnish-pending-${SESSION}.jsonl"
  rm -f "$PF"

  # 동일 에러 5회
  for i in 1 2 3 4 5; do
    echo '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_output":"E_DUP","session_id":"'"$SESSION"'"}' \
      | ASSET_BASE_DIR="$ASSET_BASE_DIR" CLAUDE_SESSION_ID="$SESSION" \
        bash "$REPO_ROOT/scripts/detect-asset.sh" >/dev/null
  done

  # promote-pending 직접 호출 (Stop 우회)
  run bash "$REPO_ROOT/scripts/promote-pending.sh" \
    --session "$SESSION" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  PROMOTED=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['promoted'])")
  DEDUP=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['deduplicated'])")
  [ "$PROMOTED" = "1" ]
  [ "$DEDUP" = "4" ]

  # context에 occurrences: 5
  CTX=$(jq -r '.context' "$ASSET_BASE_DIR/harnish-assets.jsonl")
  [[ "$CTX" =~ "occurrences: 5" ]]
}

# ─── 시나리오 3 — skillify production 산출물 ───────────────────────────────

@test "E2E pipeline 3: skillify generates Triggers + sectioned body + references trail" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  # 다양한 타입의 redis 자산
  bash "$REPO_ROOT/scripts/record-asset.sh" --type pattern --tags redis \
    --title "redis-pat-1" --body "set/get pattern" --context "ctx" \
    --base-dir "$ASSET_BASE_DIR" >/dev/null
  bash "$REPO_ROOT/scripts/record-asset.sh" --type guardrail --tags redis \
    --title "no-flushall" --body "never FLUSHALL in prod" --context "safety" \
    --base-dir "$ASSET_BASE_DIR" >/dev/null
  bash "$REPO_ROOT/scripts/record-asset.sh" --type failure --tags redis \
    --title "redis-down" --body "connection refused" --context "outage" \
    --base-dir "$ASSET_BASE_DIR" >/dev/null

  OUT_DIR="$CLAUDE_PROJECT_DIR/skills-out"
  run bash "$REPO_ROOT/scripts/skillify.sh" \
    --tag redis --skill-name redis-skill \
    --output-dir "$OUT_DIR" \
    --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]

  SKILL_FILE="$OUT_DIR/redis-skill/SKILL.md"
  REFS_FILE="$OUT_DIR/redis-skill/references/source-assets.jsonl"

  [ -f "$SKILL_FILE" ]
  [ -f "$REFS_FILE" ]

  # Triggers 단어 + 타입별 섹션 + 메타
  grep -q "Triggers:" "$SKILL_FILE"
  grep -q "## .*Patterns" "$SKILL_FILE"
  grep -q "## .*Guardrails" "$SKILL_FILE"
  grep -q "## .*Failures" "$SKILL_FILE"
  grep -q "skillify_version: 0.1.0" "$SKILL_FILE"

  # references에 3건 자산 보존
  REFS_COUNT=$(wc -l < "$REFS_FILE" | xargs)
  [ "$REFS_COUNT" -eq 3 ]
}

# ─── 시나리오 4 — inject 컨텍스트 풍부화 ──────────────────────────────────

@test "E2E pipeline 4: query --format inject includes context + level + confidence" {
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
  bash "$REPO_ROOT/scripts/record-asset.sh" --type guardrail --tags arch \
    --title "no-direct-prod" --body "never deploy directly" --context "safety" \
    --base-dir "$ASSET_BASE_DIR" >/dev/null
  bash "$REPO_ROOT/scripts/record-asset.sh" --type decision --tags arch \
    --title "use-event-bus" --body "event-driven over RPC" --context "scaling design" \
    --base-dir "$ASSET_BASE_DIR" >/dev/null
  bash "$REPO_ROOT/scripts/record-asset.sh" --type failure --tags arch \
    --title "deploy-rollback" --body "manual rollback fail" --context "post-mortem" \
    --base-dir "$ASSET_BASE_DIR" >/dev/null

  run bash "$REPO_ROOT/scripts/query-assets.sh" \
    --tags arch --format inject --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]

  # guardrail에 level, decision에 confidence, failure에 resolved 표시
  [[ "$output" =~ "soft" ]]
  [[ "$output" =~ "medium" ]]
  [[ "$output" =~ "context:" ]]
  [[ "$output" =~ "resolved:" ]]
}
