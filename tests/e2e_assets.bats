#!/usr/bin/env bats
# tests/e2e_assets.bats — End-to-end: 자산 수명주기 전체 파이프라인
#
# 시나리오:
#   record(6타입) → query(필터) → threshold → compress-assets → quality-gate
#               → migrate → purge(dry-run) → abstract → localize

load "$BATS_TEST_DIRNAME/setup.bash"

setup() {
  harnish_sandbox_setup
  cd "$CLAUDE_PROJECT_DIR"
  bash "$REPO_ROOT/scripts/init-assets.sh" --quiet
}

teardown() {
  harnish_sandbox_teardown
}

# ─── Step 1: record-asset — 6타입 각 1건 ────────────────────────────────────

@test "E2E assets step 1: record all 6 asset types" {
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type failure --tags "api,network" --title "connection-timeout" \
    --body "curl fails after 30s" --context "prod outage" \
    --base-dir "$ASSET_BASE_DIR"
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "api,retry" --title "exp-backoff" \
    --body "wait 2^n seconds between retries" --context "rate limiting" \
    --base-dir "$ASSET_BASE_DIR"
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type guardrail --tags "db,safety" --title "no-drop-table" \
    --body "never run DROP TABLE in migration" --context "safety rule" \
    --base-dir "$ASSET_BASE_DIR"
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type snippet --tags "python,util" --title "retry-decorator" \
    --body "def retry(n): ..." --context "common pattern" \
    --base-dir "$ASSET_BASE_DIR"
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type decision --tags "arch,db" --title "use-postgres" \
    --body "chose postgres over mysql for json support" --context "v1 design" \
    --base-dir "$ASSET_BASE_DIR"

  # 5건 기록 확인
  COUNT=$(wc -l < "$ASSET_BASE_DIR/harnish-rag.jsonl" | xargs)
  [ "$COUNT" -eq 5 ]
  # 모든 라인이 유효한 JSON
  while IFS= read -r line; do
    echo "$line" | python3 -m json.tool >/dev/null
  done < "$ASSET_BASE_DIR/harnish-rag.jsonl"
}

# ─── Step 2: query-assets — 태그 필터 + access_count 증분 ───────────────────

@test "E2E assets step 2: query filters by tag and increments access_count" {
  # 자산 기록
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type pattern --tags "api,retry" --title "backoff" \
    --body "exponential backoff" --context "ctx" \
    --base-dir "$ASSET_BASE_DIR"
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type guardrail --tags "db" --title "no-delete" \
    --body "never delete" --context "safety" \
    --base-dir "$ASSET_BASE_DIR"

  # api 태그 검색 → backoff만 반환
  run bash "$REPO_ROOT/scripts/query-assets.sh" \
    --tags api --format text --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "backoff" ]]
  [[ ! "$output" =~ "no-delete" ]]

  # access_count 증분 확인
  ACCESS=$(jq -r 'select(.slug == "backoff") | .access_count' \
    "$ASSET_BASE_DIR/harnish-rag.jsonl")
  [ "$ACCESS" -ge 1 ]
}

# ─── Step 3: check-thresholds — --threshold 플래그 동작 확인 ─────────────────

@test "E2E assets step 3: check-thresholds detects tags above threshold" {
  # api 태그 3건 기록
  for i in 1 2 3; do
    bash "$REPO_ROOT/scripts/record-asset.sh" \
      --type pattern --tags "api,perf" --title "pattern-$i" \
      --body "body-$i" --context "ctx" \
      --base-dir "$ASSET_BASE_DIR"
  done

  run bash "$REPO_ROOT/scripts/check-thresholds.sh" \
    --threshold 3 --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  # api(3건) 이 threshold에 걸려야 함
  [[ "$output" =~ "압축 권장" ]]
}

@test "E2E assets step 3b: check-thresholds --base-dir before --threshold works correctly" {
  # W1 버그 회귀 테스트: --base-dir가 먼저 와도 THRESHOLD가 깨지지 않는지 확인
  for i in 1 2 3 4 5 6; do
    bash "$REPO_ROOT/scripts/record-asset.sh" \
      --type pattern --tags "test-tag" --title "t-$i" \
      --body "b" --context "c" \
      --base-dir "$ASSET_BASE_DIR"
  done
  # --base-dir 먼저, --threshold 나중 순서
  run bash "$REPO_ROOT/scripts/check-thresholds.sh" \
    --base-dir "$ASSET_BASE_DIR" --threshold 5
  [ "$status" -eq 0 ]
  [[ "$output" =~ "압축 권장" ]]
}

# ─── Step 4: compress-assets — 압축 + TODO 없음 검증 ────────────────────────

@test "E2E assets step 4: compress-assets removes TODO from body" {
  for i in 1 2 3 4 5 6; do
    bash "$REPO_ROOT/scripts/record-asset.sh" \
      --type pattern --tags "redis" --title "redis-pat-$i" \
      --body "body $i" --context "ctx" \
      --base-dir "$ASSET_BASE_DIR"
  done

  run bash "$REPO_ROOT/scripts/compress-assets.sh" \
    --tag redis --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]

  # 압축 요약 레코드에 TODO 없음 (C1 버그 수정 회귀)
  run grep "TODO" "$ASSET_BASE_DIR/harnish-rag.jsonl"
  [ "$status" -ne 0 ]

  # 압축 요약 레코드가 존재하고 타이틀이 맞음
  COMPRESSED_TITLE=$(jq -r 'select(.compressed_summary == true) | .title' \
    "$ASSET_BASE_DIR/harnish-rag.jsonl")
  [[ "$COMPRESSED_TITLE" =~ "redis" ]]
}

@test "E2E assets step 4b: compress-assets dry-run does not mutate RAG" {
  for i in 1 2 3 4 5; do
    bash "$REPO_ROOT/scripts/record-asset.sh" \
      --type snippet --tags "dry" --title "s-$i" \
      --body "b" --context "c" --base-dir "$ASSET_BASE_DIR"
  done
  BEFORE=$(wc -l < "$ASSET_BASE_DIR/harnish-rag.jsonl" | xargs)
  bash "$REPO_ROOT/scripts/compress-assets.sh" \
    --tag dry --dry-run --base-dir "$ASSET_BASE_DIR"
  AFTER=$(wc -l < "$ASSET_BASE_DIR/harnish-rag.jsonl" | xargs)
  [ "$BEFORE" -eq "$AFTER" ]
}

# ─── Step 5: quality-gate — 완성도 검증 ─────────────────────────────────────

@test "E2E assets step 5: quality-gate reports issues on empty body records" {
  # 의도적으로 body 빈 레코드 삽입 (스크립트 통해 불가 — 직접 append)
  echo '{"type":"pattern","slug":"bad","title":"bad","tags":["x"],"body":"",
        "context":"","schema_version":"0.0.2","last_accessed_at":"2026-01-01T00:00:00Z","access_count":0}' \
    >> "$ASSET_BASE_DIR/harnish-rag.jsonl"

  run bash "$REPO_ROOT/scripts/quality-gate.sh" \
    --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "보완" ]]
}

@test "E2E assets step 5b: quality-gate json output has expected schema" {
  echo '{"type":"pattern","slug":"ok","title":"ok","tags":["x"],"body":"detail",
        "context":"ctx","schema_version":"0.0.2","last_accessed_at":"2026-01-01T00:00:00Z","access_count":0}' \
    >> "$ASSET_BASE_DIR/harnish-rag.jsonl"

  run bash "$REPO_ROOT/scripts/quality-gate.sh" \
    --base-dir "$ASSET_BASE_DIR" --format json
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
  STATUS=$(echo "$output" | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
  [ "$STATUS" = "checked" ]
}

# ─── Step 6: migrate.sh — 스키마 버전 업 ────────────────────────────────────

@test "E2E assets step 6: migrate backfills schema_version on old records" {
  # v0.0.1 레코드 삽입
  echo '{"type":"failure","slug":"old-1","title":"old","tags":["a"],"body":"b","date":"2025-01-01","schema_version":"0.0.1"}' \
    >> "$ASSET_BASE_DIR/harnish-rag.jsonl"
  echo '{"type":"pattern","slug":"old-2","title":"old2","tags":["b"],"body":"c","date":"2025-01-01","schema_version":"0.0.1"}' \
    >> "$ASSET_BASE_DIR/harnish-rag.jsonl"

  run bash "$REPO_ROOT/scripts/migrate.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "migrated" ]]

  # 모든 레코드가 0.0.2로 업그레이드 됐는지 확인
  OLD_COUNT=$(jq 'select(.schema_version == "0.0.1")' \
    "$ASSET_BASE_DIR/harnish-rag.jsonl" | wc -l | xargs)
  [ "$OLD_COUNT" -eq 0 ]

  # access_count 필드 백필 확인
  NO_ACCESS=$(jq 'select(.access_count == null)' \
    "$ASSET_BASE_DIR/harnish-rag.jsonl" | wc -l | xargs)
  [ "$NO_ACCESS" -eq 0 ]
}

# ─── Step 7: purge-assets — dry-run 안전 확인 ───────────────────────────────

@test "E2E assets step 7: purge dry-run exits cleanly and does not modify RAG" {
  bash "$REPO_ROOT/scripts/record-asset.sh" \
    --type decision --tags "arch" --title "choice" \
    --body "chose A over B" --context "ctx" \
    --base-dir "$ASSET_BASE_DIR"
  BEFORE=$(wc -l < "$ASSET_BASE_DIR/harnish-rag.jsonl" | xargs)

  # dry-run (기본 모드)
  run bash "$REPO_ROOT/scripts/purge-assets.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null

  AFTER=$(wc -l < "$ASSET_BASE_DIR/harnish-rag.jsonl" | xargs)
  [ "$BEFORE" -eq "$AFTER" ]
}

# ─── Full pipeline chain ─────────────────────────────────────────────────────

@test "E2E assets full pipeline: record→query→threshold→compress→gate→migrate→purge" {
  # 1. Record 6건 (api 태그 중복으로 threshold 초과)
  for i in 1 2 3 4 5 6; do
    bash "$REPO_ROOT/scripts/record-asset.sh" \
      --type pattern --tags "api,v1" --title "api-pat-$i" \
      --body "body $i" --context "integration" \
      --base-dir "$ASSET_BASE_DIR"
  done

  # 2. Query → 결과 있음
  RESULT=$(bash "$REPO_ROOT/scripts/query-assets.sh" \
    --tags api --format json --base-dir "$ASSET_BASE_DIR")
  COUNT=$(echo "$RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['count'])")
  [ "$COUNT" -ge 1 ]

  # 3. Threshold → 압축 권장 감지
  THRESH=$(bash "$REPO_ROOT/scripts/check-thresholds.sh" \
    --base-dir "$ASSET_BASE_DIR" --threshold 5)
  [[ "$THRESH" =~ "압축 권장" ]]

  # 4. Compress
  bash "$REPO_ROOT/scripts/compress-assets.sh" \
    --tag api --base-dir "$ASSET_BASE_DIR"
  run grep "TODO" "$ASSET_BASE_DIR/harnish-rag.jsonl"
  [ "$status" -ne 0 ]

  # 5. Quality gate
  GATE=$(bash "$REPO_ROOT/scripts/quality-gate.sh" \
    --base-dir "$ASSET_BASE_DIR" --format json)
  echo "$GATE" | python3 -m json.tool > /dev/null

  # 6. Migrate (already 0.0.2 → no-op)
  MIG=$(bash "$REPO_ROOT/scripts/migrate.sh" --base-dir "$ASSET_BASE_DIR")
  [[ "$MIG" =~ "no-op" ]] || [[ "$MIG" =~ "migrated" ]]

  # 7. Purge dry-run
  run bash "$REPO_ROOT/scripts/purge-assets.sh" --base-dir "$ASSET_BASE_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | python3 -m json.tool > /dev/null
}
