#!/usr/bin/env bash
# test-all.sh — harnish 전체 스크립트 흐름 자동 검증 (JSONL 기반)
#
# 사용법: bash scripts/test-all.sh
# 각 테스트는 독립적 — 하나가 FAIL해도 다음 테스트 진행.

set -uo pipefail

# ════════════════════════════════════════
# 0. 환경 설정
# ════════════════════════════════════════
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNISH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR_BASE=$(mktemp -d)
ASSET_DIR="$TMPDIR_BASE/.harnish"

PASS=0
FAIL=0
SKIP=0
RESULTS=()

# 색상 (터미널 지원 시)
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  BOLD='\033[1m'
  NC='\033[0m'
else
  GREEN='' RED='' YELLOW='' BOLD='' NC=''
fi

pass() {
  PASS=$((PASS + 1))
  RESULTS+=("${GREEN}PASS${NC}  $1")
  printf "  ${GREEN}PASS${NC}  %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  RESULTS+=("${RED}FAIL${NC}  $1${2:+ — $2}")
  printf "  ${RED}FAIL${NC}  %s%s\n" "$1" "${2:+ — $2}"
}

skip() {
  SKIP=$((SKIP + 1))
  RESULTS+=("${YELLOW}SKIP${NC}  $1${2:+ — $2}")
  printf "  ${YELLOW}SKIP${NC}  %s%s\n" "$1" "${2:+ — $2}"
}

cleanup() {
  rm -rf "$TMPDIR_BASE"
  rm -f /tmp/harnish-pending-test-*.jsonl 2>/dev/null || true
}
trap cleanup EXIT

echo ""
echo "════════════════════════════════════════"
echo " harnish 전체 스크립트 검증 (JSONL)"
echo "════════════════════════════════════════"
echo ""

# ════════════════════════════════════════
# 1. 환경 체크
# ════════════════════════════════════════
echo "${BOLD}[환경]${NC}"
printf "  bash: %s\n" "$(bash --version | head -1)"
printf "  jq:   %s\n" "$(jq --version 2>/dev/null || echo 'NOT FOUND')"
printf "  tmpdir: %s\n" "$TMPDIR_BASE"
echo ""

if ! command -v jq &>/dev/null; then
  echo "jq가 설치되어 있지 않습니다. brew install jq"
  exit 1
fi

# ════════════════════════════════════════
# 2. init-assets.sh
# ════════════════════════════════════════
echo "${BOLD}[자산 초기화]${NC}"

bash "$HARNISH_ROOT/scripts/init-assets.sh" --base-dir "$ASSET_DIR" >/dev/null 2>&1
if [[ -f "$ASSET_DIR/harnish-rag.jsonl" ]] && [[ -f "$ASSET_DIR/harnish-current-work.json" ]]; then
  pass "init-assets.sh: harnish-rag.jsonl + harnish-current-work.json 생성"
else
  fail "init-assets.sh" "JSONL 또는 work 파일 미생성"
fi

# ════════════════════════════════════════
# 3. record-asset.sh (5가지 타입)
# ════════════════════════════════════════
echo "${BOLD}[자산 기록]${NC}"

for asset_type in failure pattern guardrail snippet decision; do
  before_lines=0
  [[ -f "$ASSET_DIR/harnish-rag.jsonl" ]] && before_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)

  output=$(bash "$HARNISH_ROOT/scripts/record-asset.sh" \
    --type "$asset_type" \
    --tags "test,docker,cache" \
    --context "test-all: $asset_type 테스트" \
    --title "테스트 $asset_type 자산" \
    --body "테스트 본문 내용" \
    --base-dir "$ASSET_DIR" 2>&1)
  rc=$?

  after_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)

  if [[ $rc -eq 0 ]] && [[ "$after_lines" -gt "$before_lines" ]]; then
    # 추가된 줄이 유효한 JSON인지 확인
    last_line=$(tail -1 "$ASSET_DIR/harnish-rag.jsonl")
    if echo "$last_line" | jq empty 2>/dev/null; then
      pass "record-asset.sh --type $asset_type"
    else
      fail "record-asset.sh --type $asset_type" "JSONL 마지막 줄이 유효하지 않은 JSON"
    fi
  else
    fail "record-asset.sh --type $asset_type" "$(echo "$output" | head -3)"
  fi
done

# ════════════════════════════════════════
# 4. JSONL 무결성: 모든 줄이 유효 JSON
# ════════════════════════════════════════
echo "${BOLD}[JSONL 무결성]${NC}"

invalid_lines=0
line_num=0
while IFS= read -r line; do
  line_num=$((line_num + 1))
  if ! echo "$line" | jq empty 2>/dev/null; then
    invalid_lines=$((invalid_lines + 1))
  fi
done < "$ASSET_DIR/harnish-rag.jsonl"

if [[ "$invalid_lines" -eq 0 ]] && [[ "$line_num" -gt 0 ]]; then
  pass "JSONL 무결성: ${line_num}줄 모두 유효한 JSON"
else
  fail "JSONL 무결성" "${invalid_lines}줄 파싱 실패 (총 ${line_num}줄)"
fi

# ════════════════════════════════════════
# 5. record-asset.sh --stdin 모드
# ════════════════════════════════════════
before_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)
echo '{"type":"failure","tags":["stdin-test"],"title":"stdin 테스트","body":"stdin으로 기록"}' \
  | bash "$HARNISH_ROOT/scripts/record-asset.sh" --stdin --base-dir "$ASSET_DIR" >/dev/null 2>&1
after_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)
if [[ "$after_lines" -gt "$before_lines" ]]; then
  pass "record-asset.sh --stdin 모드"
else
  fail "record-asset.sh --stdin 모드" "JSONL 줄 수 변화 없음"
fi

# ════════════════════════════════════════
# 6. query-assets.sh
# ════════════════════════════════════════
echo "${BOLD}[자산 조회]${NC}"

for fmt in text inject json; do
  output=$(bash "$HARNISH_ROOT/scripts/query-assets.sh" \
    --tags "test,docker" --format "$fmt" --base-dir "$ASSET_DIR" 2>&1)
  if [[ $? -eq 0 ]] && [[ -n "$output" ]]; then
    pass "query-assets.sh --format $fmt"
  else
    fail "query-assets.sh --format $fmt" "$(echo "$output" | head -3)"
  fi
done

# ════════════════════════════════════════
# 7. query-assets --types 필터
# ════════════════════════════════════════
echo "${BOLD}[자산 타입 필터]${NC}"

types_result=$(bash "$HARNISH_ROOT/scripts/query-assets.sh" --tags "test" --types "failure" --format text --base-dir "$ASSET_DIR" 2>&1)
if echo "$types_result" | grep -q "\[failure\]"; then
  if echo "$types_result" | grep -q "\[pattern\]\|\[guardrail\]\|\[snippet\]\|\[decision\]"; then
    fail "query-assets --types: failure만 반환" "다른 타입이 섞여 있음"
  else
    pass "query-assets --types: failure 필터 정상"
  fi
else
  fail "query-assets --types: failure 필터 정상" "failure 결과 없음"
fi

# ════════════════════════════════════════
# 8. check-thresholds.sh
# ════════════════════════════════════════
echo "${BOLD}[임계치 확인]${NC}"

output=$(bash "$HARNISH_ROOT/scripts/check-thresholds.sh" --base-dir "$ASSET_DIR" 2>&1)
if [[ $? -eq 0 ]]; then
  pass "check-thresholds.sh"
else
  fail "check-thresholds.sh" "$(echo "$output" | head -3)"
fi

# ════════════════════════════════════════
# 9. quality-gate.sh
# ════════════════════════════════════════
echo "${BOLD}[품질 게이트]${NC}"

output=$(bash "$HARNISH_ROOT/scripts/quality-gate.sh" --base-dir "$ASSET_DIR" 2>&1)
if [[ $? -eq 0 ]]; then
  pass "quality-gate.sh"
else
  fail "quality-gate.sh" "$(echo "$output" | head -3)"
fi

# ════════════════════════════════════════
# 10. compress-assets.sh (동일 태그 5건+ 생성)
# ════════════════════════════════════════
echo "${BOLD}[자산 압축]${NC}"

# compress-test 태그로 5건 추가 (기존 test,docker,cache와 별도)
for i in $(seq 1 5); do
  bash "$HARNISH_ROOT/scripts/record-asset.sh" \
    --type failure --tags "compress-test,bulk" \
    --title "압축 테스트 $i" --body "압축 대상 본문 $i" \
    --base-dir "$ASSET_DIR" >/dev/null 2>&1
done

output=$(bash "$HARNISH_ROOT/scripts/compress-assets.sh" --tag compress-test --base-dir "$ASSET_DIR" 2>&1)
rc=$?

if [[ $rc -eq 0 ]]; then
  # JSONL에서 compressed:true 레코드 확인
  compressed_count=$(jq -c 'select(.compressed == true)' "$ASSET_DIR/harnish-rag.jsonl" 2>/dev/null | wc -l | xargs)
  if [[ "$compressed_count" -gt 0 ]]; then
    pass "compress-assets.sh: compressed:true 마킹 (${compressed_count}건)"
  else
    fail "compress-assets.sh" "compressed:true 레코드 없음"
  fi
else
  fail "compress-assets.sh" "$(echo "$output" | head -3)"
fi

# 압축 후 query에서 compressed 제외 확인
uncompressed_results=$(bash "$HARNISH_ROOT/scripts/query-assets.sh" \
  --tags "compress-test" --format json --base-dir "$ASSET_DIR" 2>&1)
uncompressed_count=$(echo "$uncompressed_results" | jq '.results | length' 2>/dev/null || echo "0")
if [[ "$uncompressed_count" -le 1 ]]; then
  pass "compress 후 query: compressed 자산 제외됨"
else
  fail "compress 후 query: compressed 자산 제외됨" "uncompressed 결과 ${uncompressed_count}건"
fi

# ════════════════════════════════════════
# 11. abstract-asset.sh (JSONL --slug)
# ════════════════════════════════════════
echo "${BOLD}[자산 추상화/로컬라이즈/스킬화]${NC}"

# project scope 자산 기록
bash "$HARNISH_ROOT/scripts/record-asset.sh" \
  --type failure --scope project \
  --tags "abstract-test,docker" \
  --title "프로젝트 특정 failure" \
  --body "프로젝트 특정 본문" \
  --base-dir "$ASSET_DIR" >/dev/null 2>&1

# slug 추출
src_slug=$(jq -r 'select(.scope == "project") | .slug' "$ASSET_DIR/harnish-rag.jsonl" 2>/dev/null | head -1)

abstract_slug=""
if [[ -n "$src_slug" ]]; then
  before_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)
  output=$(bash "$HARNISH_ROOT/scripts/abstract-asset.sh" --slug "$src_slug" --base-dir "$ASSET_DIR" 2>&1)
  rc=$?
  after_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)

  if [[ $rc -eq 0 ]] && [[ "$after_lines" -gt "$before_lines" ]]; then
    abstract_slug=$(echo "$output" | jq -r '.slug // ""' 2>/dev/null)
    pass "abstract-asset.sh --slug"
  else
    fail "abstract-asset.sh" "$(echo "$output" | head -3)"
  fi
else
  skip "abstract-asset.sh" "project scope 자산 없음"
fi

# ════════════════════════════════════════
# 12. localize-asset.sh (JSONL --slug)
# ════════════════════════════════════════
if [[ -n "$abstract_slug" ]]; then
  before_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)
  output=$(bash "$HARNISH_ROOT/scripts/localize-asset.sh" --slug "$abstract_slug" --base-dir "$ASSET_DIR" 2>&1)
  after_lines=$(wc -l < "$ASSET_DIR/harnish-rag.jsonl" | xargs)
  if [[ $? -eq 0 ]] && [[ "$after_lines" -gt "$before_lines" ]]; then
    pass "localize-asset.sh --slug"
  else
    fail "localize-asset.sh" "$(echo "$output" | head -3)"
  fi
else
  skip "localize-asset.sh" "generic scope 자산 없음 (abstract-asset 실패 시)"
fi

# ════════════════════════════════════════
# 13. skillify.sh (JSONL --tag)
# ════════════════════════════════════════
SKILLIFY_DIR="$TMPDIR_BASE/skills-out"
output=$(bash "$HARNISH_ROOT/scripts/skillify.sh" --tag "test" --skill-name "test-skill" --base-dir "$ASSET_DIR" 2>&1)
if [[ $? -eq 0 ]] && [[ -f "skills/test-skill/SKILL.md" ]]; then
  # frontmatter 필드 확인
  fm_ok=true
  for field in name version description; do
    if ! grep -qE "^${field}:" "skills/test-skill/SKILL.md"; then
      fail "skillify SKILL.md: $field 필드 누락"
      fm_ok=false
    fi
  done
  $fm_ok && pass "skillify.sh: SKILL.md 생성 + frontmatter 정상"
  # 정리
  rm -rf "skills/test-skill" 2>/dev/null || true
else
  fail "skillify.sh" "$(echo "$output" | head -3)"
fi

# ════════════════════════════════════════
# 14. 자산 축적 왕복: record → query → compress → query(compressed 제외)
# ════════════════════════════════════════
echo "${BOLD}[왕복 검증]${NC}"

query_result=$(bash "$HARNISH_ROOT/scripts/query-assets.sh" --tags "test" --format text --base-dir "$ASSET_DIR" 2>&1)
if echo "$query_result" | grep -q "테스트.*자산"; then
  pass "record→query 왕복: 기록한 자산 조회됨"
else
  fail "record→query 왕복" "결과에 '테스트 자산' 없음"
fi

# ════════════════════════════════════════
# 15. PROGRESS.json 생성 + 검증
# ════════════════════════════════════════
echo "${BOLD}[harnish-current-work.json]${NC}"

PROGRESS_FILE="$ASSET_DIR/harnish-current-work.json"
cat > "$PROGRESS_FILE" << 'PJSON'
{
  "metadata": {
    "prd": "docs/prd-test.md",
    "started_at": "2026-03-31T10:00:00+09:00",
    "last_session": "2026-03-31T14:30:00+09:00",
    "status": { "emoji": "🟢", "phase": 1, "task": "1-1", "label": "정상 진행 중" }
  },
  "done": {
    "phases": []
  },
  "doing": {
    "task": {
      "id": "1-1",
      "title": "테스트 모델 생성",
      "started_at": "2026-03-31T10:00:00+09:00",
      "current": "모델 파일 작성 중",
      "last_action": "파일 구조 확인",
      "next_action": "src/model.py 생성",
      "blocker": null,
      "retry_count": 0,
      "context": {
        "guide": "User 모델을 생성한다",
        "scope": "src/models/ 디렉토리만 수정",
        "prd_reference": "§4.1"
      }
    }
  },
  "todo": {
    "phases": [
      {
        "phase": 1,
        "title": "데이터 모델",
        "tasks": [
          { "id": "1-2", "title": "API 엔드포인트 생성", "depends_on": ["1-1"] }
        ]
      },
      {
        "phase": 2,
        "title": "테스트",
        "tasks": [
          { "id": "2-1", "title": "유닛 테스트 작성", "depends_on": [] }
        ]
      }
    ]
  },
  "issues": [],
  "violations": [],
  "escalations": [],
  "stats": {
    "total_phases": 2,
    "completed_phases": 0,
    "total_tasks": 3,
    "completed_tasks": 0,
    "issues_count": 0,
    "violations_count": 0
  }
}
PJSON

# ════════════════════════════════════════
# 16. validate-progress.sh
# ════════════════════════════════════════
output=$(bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$PROGRESS_FILE" 2>&1)
if [[ $? -eq 0 ]]; then
  pass "validate-progress.sh"
else
  fail "validate-progress.sh" "$(echo "$output" | head -3)"
fi

# ════════════════════════════════════════
# 17. loop-step.sh
# ════════════════════════════════════════
for fmt in text json; do
  output=$(bash "$HARNISH_ROOT/scripts/loop-step.sh" "$PROGRESS_FILE" --format "$fmt" 2>&1)
  rc=$?
  if [[ $rc -eq 0 ]]; then
    if [[ "$fmt" == "text" ]]; then
      if echo "$output" | grep -q "미설정"; then
        fail "loop-step.sh --format $fmt" "다음 액션 파싱 실패 (미설정)"
      else
        pass "loop-step.sh --format $fmt"
      fi
    else
      next=$(echo "$output" | jq -r '.next_action // ""' 2>/dev/null)
      if [[ -z "$next" ]] || [[ "$next" == "null" ]]; then
        fail "loop-step.sh --format $fmt" "next_action 빈 값"
      else
        pass "loop-step.sh --format $fmt"
      fi
    fi
  else
    fail "loop-step.sh --format $fmt" "$(echo "$output" | head -3)"
  fi
done

# ════════════════════════════════════════
# 18. 세션 앵커링: doing 상태에서 loop-step 복원 정확성
# ════════════════════════════════════════
echo "${BOLD}[세션 앵커링]${NC}"

anchor_out=$(bash "$HARNISH_ROOT/scripts/loop-step.sh" "$PROGRESS_FILE" --format json 2>&1)
anchor_status=$(echo "$anchor_out" | jq -r '.status' 2>/dev/null)
anchor_task=$(echo "$anchor_out" | jq -r '.current_task' 2>/dev/null)
anchor_next=$(echo "$anchor_out" | jq -r '.next_action' 2>/dev/null)

if [[ "$anchor_status" == "ACTIVE" ]] && [[ "$anchor_task" == "1-1" ]] && [[ "$anchor_next" == "src/model.py 생성" ]]; then
  pass "세션 앵커링: doing 상태에서 정확한 좌표 복원"
else
  fail "세션 앵커링" "status=$anchor_status task=$anchor_task next=$anchor_next"
fi

# ════════════════════════════════════════
# 19. ralph 상태 전이: Todo→Doing→Done 무결성
# ════════════════════════════════════════
echo "${BOLD}[ralph 상태 전이]${NC}"

TRANSITION_FILE="$TMPDIR_BASE/transition.json"
# 1-1 완료, 1-2 진행 중 상태
cat > "$TRANSITION_FILE" << 'TJSON'
{
  "metadata": {
    "prd": "docs/prd-test.md",
    "started_at": "2026-03-31T10:00:00+09:00",
    "last_session": "2026-03-31T15:00:00+09:00",
    "status": { "emoji": "🟢", "phase": 1, "task": "1-2", "label": "정상 진행 중" }
  },
  "done": {
    "phases": [
      {
        "phase": 1,
        "title": "데이터 모델",
        "compressed": false,
        "tasks": [
          {
            "id": "1-1",
            "title": "테스트 모델 생성",
            "result": "User 모델 생성 완료",
            "files_changed": ["src/models/user.py"],
            "verification": "pytest test_user.py — 3 passed",
            "duration": "2턴"
          }
        ]
      }
    ]
  },
  "doing": {
    "task": {
      "id": "1-2",
      "title": "API 엔드포인트 생성",
      "started_at": "2026-03-31T14:00:00+09:00",
      "current": "라우터 작성 중",
      "last_action": "모델 import 확인",
      "next_action": "GET /users 엔드포인트 구현",
      "blocker": null,
      "retry_count": 0,
      "context": {
        "guide": "REST API 엔드포인트 추가",
        "scope": "src/api/ 디렉토리",
        "prd_reference": "§4.2"
      }
    }
  },
  "todo": {
    "phases": [
      {
        "phase": 2,
        "title": "테스트",
        "tasks": [
          { "id": "2-1", "title": "유닛 테스트 작성", "depends_on": [] }
        ]
      }
    ]
  },
  "issues": [],
  "violations": [],
  "escalations": [],
  "stats": {
    "total_phases": 2,
    "completed_phases": 0,
    "total_tasks": 3,
    "completed_tasks": 1,
    "issues_count": 0,
    "violations_count": 0
  }
}
TJSON

# validate 통과해야 함
if bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$TRANSITION_FILE" >/dev/null 2>&1; then
  pass "ralph 상태 전이: Todo→Doing→Done JSON 무결성"
else
  fail "ralph 상태 전이" "validate-progress 실패"
fi

# done에 result 필드 존재
done_result=$(jq -r '.done.phases[0].tasks[0].result' "$TRANSITION_FILE")
if [[ -n "$done_result" ]] && [[ "$done_result" != "null" ]]; then
  pass "ralph 상태 전이: Done 태스크에 result 존재"
else
  fail "ralph 상태 전이: Done 태스크에 result 존재" "result=$done_result"
fi

# ════════════════════════════════════════
# 20. compress-progress.sh
# ════════════════════════════════════════
echo "${BOLD}[progress 압축]${NC}"

PROGRESS_WITH_DONE="$TMPDIR_BASE/progress_done.json"
cp "$TRANSITION_FILE" "$PROGRESS_WITH_DONE"
# doing을 null로, Phase 1 완료 상태로
jq '.doing.task = null | .done.phases[0].milestone_approved_at = "2026-03-31T15:00:00+09:00"' \
  "$PROGRESS_WITH_DONE" > "${PROGRESS_WITH_DONE}.tmp" && mv "${PROGRESS_WITH_DONE}.tmp" "$PROGRESS_WITH_DONE"

output=$(bash "$HARNISH_ROOT/scripts/compress-progress.sh" "$PROGRESS_WITH_DONE" --trigger milestone --phase 1 2>&1)
if [[ $? -eq 0 ]]; then
  pass "compress-progress.sh --trigger milestone"
else
  fail "compress-progress.sh" "$(echo "$output" | head -3)"
fi

is_compressed=$(jq '.done.phases[0].compressed' "$PROGRESS_WITH_DONE" 2>/dev/null)
if [[ "$is_compressed" == "true" ]]; then
  pass "compress-progress: 압축 후 compressed=true"
else
  fail "compress-progress: 압축 후 compressed=true" "compressed=$is_compressed"
fi

has_archive=$(jq -r '.done.phases[0].archive_ref // ""' "$PROGRESS_WITH_DONE" 2>/dev/null)
if [[ -n "$has_archive" ]]; then
  pass "compress-progress: archive_ref 존재"
else
  fail "compress-progress: archive_ref 존재" "빈 값"
fi

# ════════════════════════════════════════
# 21. 이중 압축 방어
# ════════════════════════════════════════
echo "${BOLD}[이중 압축 방어]${NC}"

DOUBLE_COMPRESS_JSON="$TMPDIR_BASE/double_compress.json"
cat > "$DOUBLE_COMPRESS_JSON" << 'DCEOF'
{
  "metadata": {"prd": "x", "started_at": "x", "last_session": "x", "status": {"emoji": "🟢", "phase": 1, "task": "", "label": "ok"}},
  "done": {"phases": [{"phase": 1, "title": "이미 압축됨", "compressed": true, "compressed_summary": "tasks:3", "archive_ref": ".a"}]},
  "doing": {"task": null}, "todo": {"phases": []},
  "issues": [], "violations": [], "escalations": [], "stats": {}
}
DCEOF
bash "$HARNISH_ROOT/scripts/compress-progress.sh" "$DOUBLE_COMPRESS_JSON" --trigger milestone --phase 1 >/dev/null 2>&1
after_compressed=$(jq -r '.done.phases[0].compressed_summary' "$DOUBLE_COMPRESS_JSON")
if [[ "$after_compressed" == "tasks:3" ]]; then
  pass "이중 압축 방어: compressed phase 변경 없음"
else
  fail "이중 압축 방어" "summary=$after_compressed"
fi

# ════════════════════════════════════════
# 22. compress-progress --trigger count (다중 Phase)
# ════════════════════════════════════════
COUNT_COMPRESS="$TMPDIR_BASE/count_compress.json"
cat > "$COUNT_COMPRESS" << 'CCEOF'
{
  "metadata": {"prd": "x", "started_at": "x", "last_session": "x", "status": {"emoji": "🟢", "phase": 3, "task": "", "label": "ok"}},
  "done": {"phases": [
    {"phase": 1, "title": "A", "compressed": false, "tasks": [{"id": "1-1", "title": "t", "result": "ok", "files_changed": ["a.ts"], "verification": "ok", "duration": "1"}]},
    {"phase": 2, "title": "B", "compressed": false, "tasks": [{"id": "2-1", "title": "t", "result": "ok", "files_changed": ["b.ts"], "verification": "ok", "duration": "1"}]}
  ]},
  "doing": {"task": null}, "todo": {"phases": []},
  "issues": [], "violations": [], "escalations": [], "stats": {}
}
CCEOF
bash "$HARNISH_ROOT/scripts/compress-progress.sh" "$COUNT_COMPRESS" --trigger count >/dev/null 2>&1
count_compressed=$(jq '[.done.phases[] | select(.compressed == true)] | length' "$COUNT_COMPRESS")
if [[ "$count_compressed" -eq 2 ]]; then
  pass "compress-progress --trigger count: 2개 Phase 일괄 압축"
else
  fail "compress-progress --trigger count" "compressed=$count_compressed"
fi

# ════════════════════════════════════════
# 23. check-violations.sh
# ════════════════════════════════════════
output=$(bash "$HARNISH_ROOT/scripts/check-violations.sh" "$PROGRESS_FILE" 2>&1)
if [[ $? -eq 0 ]]; then
  pass "check-violations.sh"
else
  fail "check-violations.sh" "$(echo "$output" | head -3)"
fi

# ════════════════════════════════════════
# 24. progress-report.sh
# ════════════════════════════════════════
output=$(bash "$HARNISH_ROOT/scripts/progress-report.sh" "$PROGRESS_FILE" 2>&1)
if [[ $? -eq 0 ]] && [[ -n "$output" ]]; then
  report_ok=true
  for section in "메타데이터" "완료 (Done)" "진행 중 (Doing)" "예정 (Todo)" "요약 통계"; do
    if ! echo "$output" | grep -q "$section"; then
      fail "progress-report: 섹션 '$section' 누락"
      report_ok=false
    fi
  done
  $report_ok && pass "progress-report.sh: 필수 5개 섹션 포함"
else
  fail "progress-report.sh" "출력 없음"
fi

# ════════════════════════════════════════
# 25. progress-report: issues + violations 렌더링
# ════════════════════════════════════════
PROGRESS_COMPLEX="$TMPDIR_BASE/complex.json"
cat > "$PROGRESS_COMPLEX" << 'CEOF'
{
  "metadata": {"prd": "x", "started_at": "x", "last_session": "x", "status": {"emoji": "🟡", "phase": 1, "task": "1-1", "label": "이슈"}},
  "done": {"phases": []},
  "doing": {"task": null},
  "todo": {"phases": []},
  "issues": [{"timestamp": "2026-03-31T14:00:00", "task": "1-1", "description": "타입 에러", "resolution": "수정함"}],
  "violations": [{"timestamp": "2026-03-31T14:20:00", "task": "1-1", "violation": "scope 이탈", "user_decision": "허용"}],
  "escalations": [{"timestamp": "2026-03-31T14:45:00", "task": "1-1", "blocked_at": "api.ts:45", "attempts": [], "suggested_options": []}],
  "stats": {"total_phases": 1, "completed_phases": 0, "total_tasks": 1, "completed_tasks": 0, "issues_count": 1, "violations_count": 1}
}
CEOF

complex_report=$(bash "$HARNISH_ROOT/scripts/progress-report.sh" "$PROGRESS_COMPLEX" 2>&1)
report_checks=true
if ! echo "$complex_report" | grep -q "타입 에러"; then
  fail "progress-report: issues 렌더링" "이슈 내용 없음"
  report_checks=false
fi
if ! echo "$complex_report" | grep -q "scope 이탈"; then
  fail "progress-report: violations 렌더링" "위반 내용 없음"
  report_checks=false
fi
$report_checks && pass "progress-report: issues + violations 렌더링 정상"

# ════════════════════════════════════════
# 26. 에지케이스: validate-progress
# ════════════════════════════════════════
echo "${BOLD}[에지케이스]${NC}"

# 깨진 JSON
echo '{bad' > "$TMPDIR_BASE/broken.json"
bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$TMPDIR_BASE/broken.json" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  pass "validate-progress: 깨진 JSON 거부"
else
  fail "validate-progress: 깨진 JSON 거부" "exit 0을 반환함"
fi

# 빈 JSON
echo '{}' > "$TMPDIR_BASE/empty.json"
bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$TMPDIR_BASE/empty.json" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  pass "validate-progress: 빈 JSON 오류 감지"
else
  fail "validate-progress: 빈 JSON 오류 감지" "exit 0을 반환함"
fi

# 존재하지 않는 파일
bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$TMPDIR_BASE/nonexistent.json" >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  pass "validate-progress: 파일 미존재 거부"
else
  fail "validate-progress: 파일 미존재 거부" "exit 0을 반환함"
fi

# ════════════════════════════════════════
# 27. 에지케이스: loop-step 3상태
# ════════════════════════════════════════
# ALL_DONE
ALL_DONE_JSON='{"metadata":{"prd":"x","started_at":"x","last_session":"x","status":{"emoji":"✅","phase":1,"task":"","label":"완료"}},"done":{"phases":[{"phase":1,"title":"done","compressed":false,"tasks":[{"id":"1-1","title":"t","result":"ok","files_changed":[],"verification":"ok","duration":"1"}]}]},"doing":{"task":null},"todo":{"phases":[]},"issues":[],"violations":[],"escalations":[],"stats":{}}'
echo "$ALL_DONE_JSON" > "$TMPDIR_BASE/all_done.json"
status=$(bash "$HARNISH_ROOT/scripts/loop-step.sh" "$TMPDIR_BASE/all_done.json" --format json 2>&1 | jq -r '.status')
if [[ "$status" == "ALL_DONE" ]]; then
  pass "loop-step: ALL_DONE 상태 감지"
else
  fail "loop-step: ALL_DONE 상태 감지" "status=$status"
fi

# NO_DOING with milestone
MILESTONE_JSON='{"metadata":{"prd":"x","started_at":"x","last_session":"x","status":{"emoji":"🟢","phase":1,"task":"","label":"ok"}},"done":{"phases":[{"phase":1,"title":"done","compressed":false,"tasks":[{"id":"1-1","title":"t","result":"ok","files_changed":[],"verification":"ok","duration":"1"}]}]},"doing":{"task":null},"todo":{"phases":[{"phase":2,"title":"next","tasks":[{"id":"2-1","title":"t","depends_on":[]}]}]},"issues":[],"violations":[],"escalations":[],"stats":{}}'
echo "$MILESTONE_JSON" > "$TMPDIR_BASE/milestone.json"
milestone=$(bash "$HARNISH_ROOT/scripts/loop-step.sh" "$TMPDIR_BASE/milestone.json" --format json 2>&1 | jq -r '.phase_milestone')
if [[ "$milestone" == "true" ]]; then
  pass "loop-step: 마일스톤 HITL 게이트 감지"
else
  fail "loop-step: 마일스톤 HITL 게이트 감지" "phase_milestone=$milestone"
fi

# ════════════════════════════════════════
# 28. 에스컬레이션 3회 실패: escalations 구조 검증
# ════════════════════════════════════════
echo "${BOLD}[에스컬레이션]${NC}"

ESCALATION_JSON="$TMPDIR_BASE/escalation.json"
cat > "$ESCALATION_JSON" << 'EEOF'
{
  "metadata": {"prd": "x", "started_at": "x", "last_session": "x", "status": {"emoji": "🔴", "phase": 1, "task": "1-1", "label": "에스컬레이션"}},
  "done": {"phases": []},
  "doing": {
    "task": {
      "id": "1-1", "title": "실패 태스크",
      "started_at": "x", "current": "blocked", "last_action": "3차 시도 실패",
      "next_action": "에스컬레이션 대기", "blocker": "TypeError at api.ts:42",
      "retry_count": 3,
      "context": {"guide": "x", "scope": "x", "prd_reference": "§4.1"}
    }
  },
  "todo": {"phases": []},
  "issues": [
    {"timestamp": "x", "task": "1-1", "description": "1차 시도 실패"},
    {"timestamp": "x", "task": "1-1", "description": "2차 시도 실패"},
    {"timestamp": "x", "task": "1-1", "description": "3차 시도 실패"}
  ],
  "violations": [],
  "escalations": [
    {
      "timestamp": "x", "task": "1-1",
      "blocked_at": "api.ts:42",
      "attempts": ["방법A: 실패", "방법B: 실패", "방법C: 실패"],
      "suggested_options": ["PRD §4.1 수정", "대안 접근법"]
    }
  ],
  "stats": {"total_phases": 1, "completed_phases": 0, "total_tasks": 1, "completed_tasks": 0, "issues_count": 3, "violations_count": 0}
}
EEOF

# validate 통과해야 함
if bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$ESCALATION_JSON" >/dev/null 2>&1; then
  pass "에스컬레이션: retry_count=3 + escalations 배열 구조 유효"
else
  fail "에스컬레이션: 구조 유효성" "validate-progress 실패"
fi

# retry_count=3 확인
retry=$(jq '.doing.task.retry_count' "$ESCALATION_JSON")
esc_count=$(jq '.escalations | length' "$ESCALATION_JSON")
if [[ "$retry" -eq 3 ]] && [[ "$esc_count" -gt 0 ]]; then
  pass "에스컬레이션: retry_count=3 + escalations 기록됨"
else
  fail "에스컬레이션" "retry=$retry esc=$esc_count"
fi

# check-violations가 에스컬레이션 감지
esc_output=$(bash "$HARNISH_ROOT/scripts/check-violations.sh" "$ESCALATION_JSON" 2>&1)
if echo "$esc_output" | grep -q "에스컬레이션\|escalation\|1건"; then
  pass "check-violations: 에스컬레이션 감지"
else
  fail "check-violations: 에스컬레이션 감지" "$(echo "$esc_output" | head -3)"
fi

# ════════════════════════════════════════
# 29. detect-asset.sh hook 테스트
# ════════════════════════════════════════
echo "${BOLD}[hook]${NC}"

# 의미 있는 에러 → pending에 기록
echo '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","session_id":"test-hook","tool_input":"docker build .","tool_output":"Error: insufficient memory"}' \
  | ASSET_BASE_DIR="$ASSET_DIR" CLAUDE_SESSION_ID="test-hook-detect" bash "$HARNISH_ROOT/scripts/detect-asset.sh" 2>/dev/null
PENDING_FILE_CHECK="/tmp/harnish-pending-test-hook-detect.jsonl"
if [[ -f "$PENDING_FILE_CHECK" ]] && [[ -s "$PENDING_FILE_CHECK" ]]; then
  pass "detect-asset: 의미 있는 에러 → pending 기록"
else
  fail "detect-asset: 의미 있는 에러 → pending 기록" "pending 파일 없음"
fi

# 노이즈 → 필터링 (pending 증가하면 안 됨)
pre_count=0
[[ -f "$PENDING_FILE_CHECK" ]] && pre_count=$(wc -l < "$PENDING_FILE_CHECK" | xargs)
echo '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","session_id":"test-hook-noise","tool_input":"cat x","tool_output":"No such file or directory"}' \
  | ASSET_BASE_DIR="$ASSET_DIR" CLAUDE_SESSION_ID="test-hook-detect" bash "$HARNISH_ROOT/scripts/detect-asset.sh" 2>/dev/null
post_count=$(wc -l < "$PENDING_FILE_CHECK" | xargs)
if [[ "$post_count" -eq "$pre_count" ]]; then
  pass "detect-asset: 노이즈 에러 필터링"
else
  fail "detect-asset: 노이즈 에러 필터링" "pending이 ${pre_count} → ${post_count}로 증가"
fi

# Stop 이벤트
stop_out=$(echo '{"hook_event_name":"Stop","session_id":"test-stop"}' \
  | ASSET_BASE_DIR="$ASSET_DIR" bash "$HARNISH_ROOT/scripts/detect-asset.sh" 2>/dev/null)
if [[ $? -eq 0 ]]; then
  pass "detect-asset Stop: 종료 정상"
else
  fail "detect-asset Stop" "비정상 종료"
fi

# ════════════════════════════════════════
# 30. resolve 함수 우선순위
# ════════════════════════════════════════
echo "${BOLD}[resolve 함수]${NC}"

# ASSET_BASE_DIR 최우선
resolved=$(ASSET_BASE_DIR="/custom/path" bash -c "source '$HARNISH_ROOT/scripts/common.sh'; resolve_base_dir" 2>/dev/null)
if [[ "$resolved" == "/custom/path" ]]; then
  pass "resolve_base_dir: ASSET_BASE_DIR 최우선"
else
  fail "resolve_base_dir: ASSET_BASE_DIR 최우선" "resolved=$resolved"
fi

# CWD 기준 (CLAUDE_PROJECT_DIR 무시 — 워크트리 격리)
resolved=$(CLAUDE_PROJECT_DIR="/project" bash -c "cd /tmp && source '$HARNISH_ROOT/scripts/common.sh'; resolve_base_dir" 2>/dev/null)
if [[ "$resolved" == "/tmp/.harnish" ]]; then
  pass "resolve_base_dir: CWD 기준 (CLAUDE_PROJECT_DIR 무시)"
else
  fail "resolve_base_dir: CWD 기준 (CLAUDE_PROJECT_DIR 무시)" "resolved=$resolved"
fi

# CWD 기본
resolved=$(bash -c "cd /tmp && source '$HARNISH_ROOT/scripts/common.sh'; resolve_base_dir" 2>/dev/null)
if [[ "$resolved" == "/tmp/.harnish" ]]; then
  pass "resolve_base_dir: CWD 기본"
else
  fail "resolve_base_dir: CWD 기본" "resolved=$resolved"
fi

# ════════════════════════════════════════
# 31. SKILL.md 정합성
# ════════════════════════════════════════
echo "${BOLD}[SKILL.md 정합성]${NC}"

skill_ok=true
skill_count=0
for skill_dir in "$HARNISH_ROOT"/skills/*/; do
  skill_md="$skill_dir/SKILL.md"
  [[ -f "$skill_md" ]] || continue
  skill_count=$((skill_count + 1))
  skill_name=$(basename "$skill_dir")
  for field in name description version; do
    if ! head -20 "$skill_md" | grep -qE "^${field}:"; then
      fail "SKILL.md frontmatter: $skill_name.$field 누락"
      skill_ok=false
    fi
  done
done
if [[ $skill_count -eq 0 ]]; then
  fail "SKILL.md frontmatter" "skills/ 디렉토리에 스킬 없음"
elif $skill_ok; then
  pass "SKILL.md frontmatter: ${skill_count}개 스킬 모두 name/description/version 정상"
fi

# ════════════════════════════════════════
# 32. references/ 파일 존재 검증
# ════════════════════════════════════════
ref_ok=true
for skill_dir in "$HARNISH_ROOT"/skills/*/; do
  skill_md="$skill_dir/SKILL.md"
  [[ -f "$skill_md" ]] || continue
  skill_name=$(basename "$skill_dir")
  refs=$(grep -oE 'references/[a-zA-Z0-9_-]+\.(md|json)' "$skill_md" | sort -u)
  for ref in $refs; do
    if [[ ! -f "$skill_dir/$ref" ]]; then
      fail "references 존재: $skill_name/$ref 누락"
      ref_ok=false
    fi
  done
done
$ref_ok && pass "references 존재: SKILL.md에서 참조하는 모든 references/ 파일 존재"

# ════════════════════════════════════════
# 33. 문서 정합성: PROGRESS.md 잔여 참조 없음
# ════════════════════════════════════════
stale_refs=$(grep -rl 'PROGRESS\.md' "$HARNISH_ROOT" --include="*.md" --include="*.json" --include="*.sh" \
  --exclude-dir=".git" --exclude-dir=".claude" --exclude-dir="docs" 2>/dev/null \
  | grep -v '.gitignore' | grep -v 'test-all.sh' | grep -v 'plans/' || true)
if [[ -z "$stale_refs" ]]; then
  pass "문서 정합성: PROGRESS.md 잔여 참조 없음 (docs/ 제외)"
else
  fail "문서 정합성: PROGRESS.md 잔여 참조 없음" "$stale_refs"
fi

# ════════════════════════════════════════
# 34. schema.json 정합성
# ════════════════════════════════════════
echo "${BOLD}[schema.json]${NC}"

schema_file="$HARNISH_ROOT/skills/harnish/references/schema.json"
if jq empty "$schema_file" 2>/dev/null; then
  pass "schema.json: 유효한 JSON"
else
  fail "schema.json: 유효한 JSON" "파싱 에러"
fi

# L1 exports에 실제 common.sh 함수가 있는지
schema_exports=$(jq -r '.layers.L1_Storage.exports[]' "$schema_file" 2>/dev/null | sed 's/()$//')
schema_ok=true
while IFS= read -r fn; do
  [[ -z "$fn" ]] && continue
  if ! grep -q "$fn" "$HARNISH_ROOT/scripts/common.sh" 2>/dev/null; then
    fail "schema.json L1 exports: $fn()이 common.sh에 없음"
    schema_ok=false
  fi
done <<< "$schema_exports"
$schema_ok && pass "schema.json: L1 exports가 common.sh 함수와 일치"

# ════════════════════════════════════════
# 35. acceptance_criteria 분기 검증 (harnish-current-work.json 구조)
# ════════════════════════════════════════
echo "${BOLD}[acceptance_criteria 분기]${NC}"

# bash 명령 타입
AC_BASH='{"metadata":{"prd":"x","started_at":"x","last_session":"x","status":{"emoji":"🟢","phase":1,"task":"1-1","label":"ok"}},"done":{"phases":[]},"doing":{"task":{"id":"1-1","title":"t","started_at":"x","current":"x","last_action":"x","next_action":"x","blocker":null,"retry_count":0,"context":{"guide":"x","scope":"x","prd_reference":"x"}}},"todo":{"phases":[{"phase":1,"title":"t","tasks":[]}]},"issues":[],"violations":[],"escalations":[],"stats":{}}'
echo "$AC_BASH" | jq empty 2>/dev/null && pass "acceptance_criteria: bash 명령 타입 JSON 유효" || fail "acceptance_criteria: bash 명령 타입"

# 조건 리스트 타입 (tasks에 acceptance_criteria 배열)
AC_COND_JSON="$TMPDIR_BASE/ac_cond.json"
cat > "$AC_COND_JSON" << 'ACEOF'
{
  "metadata":{"prd":"x","started_at":"x","last_session":"x","status":{"emoji":"🟢","phase":1,"task":"1-1","label":"ok"}},
  "done":{"phases":[]},
  "doing":{"task":{"id":"1-1","title":"t","started_at":"x","current":"x","last_action":"x","next_action":"acceptance_criteria 실행","blocker":null,"retry_count":0,"context":{"guide":"x","scope":"x","prd_reference":"x"}}},
  "todo":{"phases":[{"phase":1,"title":"t","tasks":[{"id":"1-2","title":"next","depends_on":["1-1"],"acceptance_criteria":["src/models/user.ts 파일 존재","User interface에 id, name, email 필드 포함","export default 사용"]}]}]},
  "issues":[],"violations":[],"escalations":[],"stats":{}
}
ACEOF
if bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$AC_COND_JSON" >/dev/null 2>&1; then
  pass "acceptance_criteria: 조건 리스트 타입 구조 유효"
else
  fail "acceptance_criteria: 조건 리스트 타입" "validate 실패"
fi

# none 타입 → escalation 필요 (acceptance_criteria 없는 태스크)
AC_NONE_JSON="$TMPDIR_BASE/ac_none.json"
cat > "$AC_NONE_JSON" << 'ANEOF'
{
  "metadata":{"prd":"x","started_at":"x","last_session":"x","status":{"emoji":"🟢","phase":1,"task":"1-1","label":"ok"}},
  "done":{"phases":[]},
  "doing":{"task":{"id":"1-1","title":"criteria 없는 태스크","started_at":"x","current":"x","last_action":"x","next_action":"x","blocker":null,"retry_count":0,"context":{"guide":"x","scope":"x","prd_reference":"x"}}},
  "todo":{"phases":[{"phase":1,"title":"t","tasks":[{"id":"1-2","title":"next","depends_on":[]}]}]},
  "issues":[],"violations":[],"escalations":[],"stats":{}
}
ANEOF
if bash "$HARNISH_ROOT/scripts/validate-progress.sh" "$AC_NONE_JSON" >/dev/null 2>&1; then
  pass "acceptance_criteria: none 타입 (에스컬레이션 대상) 구조 유효"
else
  fail "acceptance_criteria: none 타입" "validate 실패"
fi

# ════════════════════════════════════════
# v0.0.2: compress-assets --dry-run 비파괴
# ════════════════════════════════════════
echo "${BOLD}[v0.0.2: compress-assets --dry-run]${NC}"

DRY_FIXTURE="$TMPDIR_BASE/dry-fixture/.harnish"
mkdir -p "$DRY_FIXTURE"
for i in 1 2 3 4 5 6; do
  jq -n -c --arg t "dry-test-tag" --argjson i "$i" \
    '{schema_version:"0.0.2",type:"pattern",slug:"p\($i)",title:"t\($i)",tags:[$t],date:"2026-01-01",scope:"generic",body:"b",context:"c",session:"s",last_accessed_at:"2026-01-01T00:00:00Z",access_count:0}' \
    >> "$DRY_FIXTURE/harnish-rag.jsonl"
done
HASH_BEFORE=$(shasum "$DRY_FIXTURE/harnish-rag.jsonl" | awk '{print $1}')
DRY_OUT=$(bash "$HARNISH_ROOT/scripts/compress-assets.sh" --all --dry-run --base-dir "$DRY_FIXTURE" 2>&1)
HASH_AFTER=$(shasum "$DRY_FIXTURE/harnish-rag.jsonl" | awk '{print $1}')
if [[ "$HASH_BEFORE" == "$HASH_AFTER" ]] && echo "$DRY_OUT" | grep -q '"status":"dry_run"'; then
  pass "compress-assets --dry-run 비파괴 + dry_run status"
else
  fail "compress-assets --dry-run 비파괴" "hash 변경 또는 status 누락: $DRY_OUT"
fi

# ════════════════════════════════════════
# v0.0.2: migrate.sh 백필 정책
# ════════════════════════════════════════
echo "${BOLD}[v0.0.2: migrate.sh 백필]${NC}"

MIG_FIX="$TMPDIR_BASE/mig-fix/.harnish"
mkdir -p "$MIG_FIX"
jq -n -c '{type:"pattern",slug:"legacy",title:"legacy","tags":["l"],"date":"2026-01-15",scope:"generic",body:"b",context:"c",session:"s"}' \
  > "$MIG_FIX/harnish-rag.jsonl"
bash "$HARNISH_ROOT/scripts/migrate.sh" --base-dir "$MIG_FIX" >/dev/null 2>&1 || true
MIG_VER=$(jq -r '.schema_version' "$MIG_FIX/harnish-rag.jsonl")
MIG_LA=$(jq -r '.last_accessed_at' "$MIG_FIX/harnish-rag.jsonl")
MIG_AC=$(jq -r '.access_count' "$MIG_FIX/harnish-rag.jsonl")
BAK_EXISTS=$(ls "$MIG_FIX"/harnish-rag.jsonl.bak* 2>/dev/null | wc -l | xargs)
if [[ "$MIG_VER" == "0.0.2" ]] && [[ "$MIG_LA" == "2026-01-15" ]] && [[ "$MIG_AC" == "0" ]] && [[ "$BAK_EXISTS" -ge 1 ]]; then
  pass "migrate.sh 백필: schema_version=0.0.2, last_accessed_at=date, access_count=0, .bak 생성"
else
  fail "migrate.sh 백필" "ver=$MIG_VER la=$MIG_LA ac=$MIG_AC bak=$BAK_EXISTS"
fi

# ════════════════════════════════════════
# v0.0.2: purge-assets 기본 dry-run
# ════════════════════════════════════════
echo "${BOLD}[v0.0.2: purge-assets 기본 dry-run]${NC}"

PURGE_FIX="$TMPDIR_BASE/purge-fix/.harnish"
mkdir -p "$PURGE_FIX"
OLD_DATE=$(date -u -v-400d +"%Y-%m-%d" 2>/dev/null || date -u -d "-400 days" +"%Y-%m-%d" 2>/dev/null || echo "2024-01-01")
jq -n -c --arg d "$OLD_DATE" \
  '{schema_version:"0.0.2",type:"decision",slug:"old-dec",title:"old",tags:["x"],date:$d,scope:"generic",body:"b",context:"c",session:"s",last_accessed_at:$d,access_count:0}' \
  > "$PURGE_FIX/harnish-rag.jsonl"
HASH_BEFORE=$(shasum "$PURGE_FIX/harnish-rag.jsonl" | awk '{print $1}')
PURGE_OUT=$(bash "$HARNISH_ROOT/scripts/purge-assets.sh" --base-dir "$PURGE_FIX" 2>&1)
HASH_AFTER=$(shasum "$PURGE_FIX/harnish-rag.jsonl" | awk '{print $1}')
if [[ "$HASH_BEFORE" == "$HASH_AFTER" ]] && echo "$PURGE_OUT" | grep -q '"status":"dry_run"'; then
  pass "purge-assets 기본 dry-run 비파괴 + status"
else
  fail "purge-assets 기본 dry-run" "hash 변경 또는 status 누락: $PURGE_OUT"
fi

# ════════════════════════════════════════
# SKILL frontmatter version 일관성 (plugin.json 기준 자동 동기화)
# ════════════════════════════════════════
echo "${BOLD}[SKILL version 일관성]${NC}"

EXPECTED_V=$(jq -r .version "$HARNISH_ROOT/.claude-plugin/plugin.json" 2>/dev/null || echo missing)
VERSION_OK=true
for skill in harnish ralphi forki drafti-architect drafti-feature; do
  for ext in md ko.md; do
    V=$(awk '/^version:/ {print $2; exit}' "$HARNISH_ROOT/skills/$skill/SKILL.$ext" 2>/dev/null || echo "missing")
    if [[ "$V" != "$EXPECTED_V" ]]; then
      fail "$skill/SKILL.$ext version" "expected $EXPECTED_V (from plugin.json), got $V"
      VERSION_OK=false
    fi
  done
done
if $VERSION_OK; then
  pass "5개 SKILL × (md + ko.md) frontmatter version == $EXPECTED_V"
fi

# ════════════════════════════════════════
# 결과 요약
# ════════════════════════════════════════
echo ""
echo "════════════════════════════════════════"
TOTAL=$((PASS + FAIL + SKIP))
printf " 결과: ${GREEN}PASS %d${NC} / ${RED}FAIL %d${NC} / ${YELLOW}SKIP %d${NC} (총 %d)\n" "$PASS" "$FAIL" "$SKIP" "$TOTAL"
echo "════════════════════════════════════════"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "실패 항목:"
  for r in "${RESULTS[@]}"; do
    if echo "$r" | grep -q "FAIL"; then
      printf "  %b\n" "$r"
    fi
  done
fi

echo ""
exit "$FAIL"
