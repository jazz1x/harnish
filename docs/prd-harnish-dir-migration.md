# PRD: `.harnish/` 통합 마이그레이션

## §1 문제 정의

harnish는 Claude Code 스킬(도구)이지만 런타임 데이터가 도구 리포 안에 생성된다:

- `_base/assets/` — 8개 디렉토리 + 개별 MD 파일 + index.json → 파일 폭발
- `PROGRESS.json` — CWD 루트에 범용 이름으로 생성 → 충돌 가능
- SKILL.md가 `--base-dir "$HARNISH_ROOT/_base/assets"`로 하드코딩 → 사용자 프로젝트가 아닌 도구에 자산 축적
- record 파일명에 날짜 프리픽스 → 같은 자산도 날짜별 중복

## §2 목표

1. 런타임 데이터를 사용자 프로젝트의 `.harnish/`로 격리
2. 자산 저장을 JSONL 단일 파일로 단순화 (디렉토리 8개 + index.json → 파일 1개)
3. 파일명에 `harnish-` 프리픽스로 소유권 명확화
4. 모든 경로 하드코딩을 `resolve_*()` 함수에 위임

## §3 변경 후 구조

```
/project/                              ← 사용자 프로젝트 (CWD)
  .harnish/
    harnish-current-work.json          ← 작업 좌표 (구 PROGRESS.json)
    harnish-current-work.json.backup   ← 백업
    harnish-rag.jsonl                  ← 모든 자산 (구 _base/assets/**)

~/.claude/skills/harnish/              ← 도구 (읽기 전용, 런타임 데이터 없음)
  scripts/
  skills/
  hooks/
```

## §4 구현 명세

### Phase 1: 경로 해석 통합 (common.sh)

#### 4.1.1 `scripts/common.sh` — `resolve_base_dir()` 수정 (modify)

before:
```bash
resolve_base_dir() {
    if [[ -n "${ASSET_BASE_DIR:-}" ]]; then
        echo "$ASSET_BASE_DIR"
    elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
        echo "${CLAUDE_PROJECT_DIR}/_base/assets"
    else
        local harnish_root
        harnish_root="$(cd "${SCRIPT_DIR:-$(pwd)}/.." && pwd)"
        local parent
        parent="$(cd "$harnish_root/.." && pwd)"
        echo "$parent/_base/assets"
    fi
}
```

after:
```bash
resolve_base_dir() {
    if [[ -n "${ASSET_BASE_DIR:-}" ]]; then
        echo "$ASSET_BASE_DIR"
    elif [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
        echo "${CLAUDE_PROJECT_DIR}/.harnish"
    else
        echo "$(pwd)/.harnish"
    fi
}
```

#### 4.1.2 `scripts/common.sh` — `resolve_progress_file()` 추가 (create function)

```bash
resolve_progress_file() {
    echo "$(resolve_base_dir)/harnish-current-work.json"
}
```

#### 4.1.3 `scripts/common.sh` — `resolve_rag_file()` 추가 (create function)

```bash
resolve_rag_file() {
    echo "$(resolve_base_dir)/harnish-rag.jsonl"
}
```

#### 4.1.4 `scripts/common.sh` — MD 파싱 함수 삭제 (delete)

Phase 2 완료 후 삭제할 함수 목록:
- `format_yaml_tags()` (line ~80)
- `parse_frontmatter()` (line ~90)
- `parse_body()` (line ~115)
- `get_field()` (line ~130)
- `get_tags()` (line ~140)

삭제 시점: Phase 2의 모든 스크립트 전환이 완료된 후.

#### 4.1.5 `scripts/common.sh` — `slugify()` 유지 (no change)

JSONL의 `slug` 필드 생성에 계속 사용.

---

### Phase 2: 자산 포맷 전환 (JSONL)

#### JSONL 레코드 스키마 (모든 자산 공통)

```json
{
  "type": "failure|pattern|guardrail|snippet|decision",
  "slug": "docker-build-cache",
  "title": "Docker 빌드 캐시 미스",
  "tags": ["docker", "cache"],
  "date": "2026-04-01",
  "scope": "generic|project",
  "body": "본문 내용 (한 줄로 escape)",
  "context": "기록 배경",
  "session": "세션 해시",
  "compressed": false
}
```

타입별 선택 필드:
- `failure`: `"resolved": true`
- `pattern|snippet`: `"stability": 1`
- `guardrail`: `"level": "soft|hard"`
- `decision`: `"confidence": "low|medium|high"`

#### 4.2.1 `scripts/init-assets.sh` 재작성 (modify)

현재: 77줄 (8개 디렉토리 + index.json 생성)
변경: ~20줄

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

BASE="$(resolve_base_dir)"
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --base-dir) BASE="$2"; shift 2;;
        --quiet)    QUIET=true; shift;;
        *) shift;;
    esac
done

log() { $QUIET || echo "$*"; }

mkdir -p "$BASE"

RAG_FILE="$BASE/harnish-rag.jsonl"
WORK_FILE="$BASE/harnish-current-work.json"

[[ -f "$RAG_FILE" ]]  || touch "$RAG_FILE"
[[ -f "$WORK_FILE" ]] || echo '{}' > "$WORK_FILE"

log "✓ .harnish/ 초기화 완료 ($BASE)"
```

#### 4.2.2 `scripts/record-asset.sh` 재작성 (modify)

현재: 383줄 (MD frontmatter + 디렉토리 + index.json 갱신 + RCA)
변경: ~100줄

핵심 변경:
- MD frontmatter 생성 → JSON 객체 구성
- 타입별 디렉토리 + 파일 쓰기 → `harnish-rag.jsonl`에 1줄 append
- index.json 갱신 → 삭제 (JSONL이 곧 인덱스)
- 날짜 파일명 → 삭제 (파일 자체가 없음)
- RCA 셀프힐링 → JSON 필드 존재 검증으로 단순화

인터페이스:
```
bash record-asset.sh --type failure --title "제목" --tags "a,b" --body "본문" [--context "배경"] [--scope generic] [--base-dir .harnish]
```

`--body-file`, `--stdin` 모드 유지.
`--base-dir` 미지정 시 `resolve_base_dir()` 사용.

구현 핵심부:
```bash
SLUG="$(slugify "$TITLE")"
RAG_FILE="${BASE}/harnish-rag.jsonl"

# JSON 레코드 구성
RECORD=$(jq -n -c \
  --arg type "$TYPE" \
  --arg slug "$SLUG" \
  --arg title "$TITLE" \
  --argjson tags "$(printf '%s\n' "${TAG_ARRAY[@]}" | jq -R . | jq -s .)" \
  --arg date "$DATE" \
  --arg scope "$SCOPE" \
  --arg body "$BODY_CONTENT" \
  --arg context "$CONTEXT" \
  --arg session "$SESSION_ID" \
  '{type:$type, slug:$slug, title:$title, tags:$tags, date:$date, scope:$scope, body:$body, context:$context, session:$session}')

# 타입별 선택 필드 추가
case "$TYPE" in
  failure)   RECORD=$(echo "$RECORD" | jq -c '. + {resolved: true}');;
  pattern|snippet) RECORD=$(echo "$RECORD" | jq -c '. + {stability: 1}');;
  guardrail) RECORD=$(echo "$RECORD" | jq -c '. + {level: "soft"}');;
  decision)  RECORD=$(echo "$RECORD" | jq -c '. + {confidence: "medium"}');;
esac

# append
echo "$RECORD" >> "$RAG_FILE"
```

RCA 검증 (기존 RCA 셀프힐링 대체):
```bash
RCA_WARNINGS=()
[[ -z "$CONTEXT" ]] && RCA_WARNINGS+=("context가 비어있습니다")
[[ -z "$BODY_CONTENT" ]] && RCA_WARNINGS+=("body가 비어있습니다")
```

출력: 기존과 동일한 JSON status 형식 유지.
```json
{"status": "recorded", "type": "failure", "slug": "...", "tags": [...], "alerts": [], "rca": {"warnings": [], "quality": "good"}}
```

#### 4.2.3 `scripts/query-assets.sh` 재작성 (modify)

현재: 314줄 (디렉토리 스캔 + MD frontmatter 파싱 + 관련도 점수)
변경: ~80줄

핵심 변경:
- 디렉토리 스캔 → `jq` JSONL 필터
- frontmatter 파싱 → 불필요 (이미 JSON)
- index.json 의존 → 삭제

인터페이스 유지:
```
bash query-assets.sh --tags "docker,build" [--types "failure,pattern"] [--format json|text|inject] [--limit 5] [--base-dir .harnish]
```

구현 핵심부:
```bash
RAG_FILE="${BASE}/harnish-rag.jsonl"

if [[ ! -f "$RAG_FILE" ]] || [[ ! -s "$RAG_FILE" ]]; then
    # 빈 결과 처리 (포맷별)
    ...
    exit 0
fi

# 태그 매칭 + 타입 필터 + 정렬 + limit
QUERY_JQ='select(.compressed != true)'

# 타입 필터
if [[ -n "$TYPES" ]]; then
    TYPE_JQ=$(printf '%s\n' "${QUERY_TYPES[@]}" | jq -R . | jq -s '.')
    QUERY_JQ="${QUERY_JQ} | select(.type as \$t | ${TYPE_JQ} | any(. == \$t))"
fi

# 태그 매칭 (OR: 하나라도 매칭)
TAG_JQ=$(printf '%s\n' "${QUERY_TAGS[@]}" | jq -R . | jq -s '.')
RESULTS=$(jq -c "${QUERY_JQ} | select(.tags as \$t | ${TAG_JQ} | any(. as \$q | \$t | any(. == \$q)))" "$RAG_FILE" \
  | head -n "$LIMIT")
```

3개 출력 포맷 (json/text/inject):
- `json`: JSONL 결과를 `jq -s '.'`로 배열화
- `text`: `[type] title (date) — body 첫 50자\n  tags: tag1 | scope: scope`
- `inject`: `### 관련 자산 (asset-recorder)\n\n- **[type] title**: body 첫 100자`

#### 4.2.4 `scripts/compress-assets.sh` 재작성 (modify)

현재: 256줄
변경: ~50줄

핵심: 같은 태그 N건 이상 → 원본에 `compressed: true` 추가, 요약 1건 append.

```bash
# 1. 태그별 카운트
THRESHOLD="${THRESHOLD:-5}"
OVER_TAGS=$(jq -c '[.tags[]] ' "$RAG_FILE" | sort | uniq -c | sort -rn \
  | awk -v t="$THRESHOLD" '$1 >= t {print $2}' | tr -d '"')

# 2. 각 태그에 대해: 해당 레코드들의 body를 요약 → 요약본 1건 추가
# 3. 원본 레코드에 compressed:true 추가
```

구현: 임시파일에 새 JSONL 쓰고 `mv`로 교체 (atomic write).

#### 4.2.5 `scripts/check-thresholds.sh` 재작성 (modify)

현재: ~50줄
변경: ~25줄

```bash
RAG_FILE="$(resolve_rag_file)"
THRESHOLD="${1:-5}"

jq -c 'select(.compressed != true) | .tags[]' "$RAG_FILE" \
  | sort | uniq -c | sort -rn \
  | awk -v t="$THRESHOLD" '$1 >= t {printf "%s(%d건)\n", $2, $1}'
```

#### 4.2.6 `scripts/quality-gate.sh` 재작성 (modify)

현재: 229줄
변경: ~40줄

JSONL 레코드의 필수 필드 존재 여부 체크:
- `type`, `slug`, `title`, `tags`, `body` 중 빈 값 → poor
- `context` 빈 값 → fair
- 전부 채워짐 → good

#### 4.2.7 `scripts/detect-asset.sh` 수정 (modify)

현재: 234줄
변경: ~180줄 (구조 유지, 경로만 변경)

pending 처리:
- 현재: `.meta/pending/failures-s{hash}.jsonl`
- 변경: `/tmp/harnish-pending-{hash}.jsonl` (임시파일)
- 이유: pending은 세션 내 임시 데이터. RAG에 넣으면 오염.

경로 변경:
- `ASSET_BASE` → `resolve_base_dir()`
- `_default_base()` 삭제 → `resolve_base_dir()` 사용
- index.json 참조 → `harnish-rag.jsonl` 기반 카운트
- 디렉토리 스캔 → JSONL 스캔

#### 4.2.8 `scripts/abstract-asset.sh` 수정 (modify)

MD 파일 복사 + 수정 → JSONL에서 해당 레코드의 `scope` 필드를 `generic`으로 변경.
새 레코드를 append (원본 유지, scope 변경본 추가).

`_default_base()` 삭제 → `resolve_base_dir()` 사용.

#### 4.2.9 `scripts/localize-asset.sh` 수정 (modify)

abstract의 역방향. `scope: generic` → `scope: project` 변환.

#### 4.2.10 `scripts/skillify.sh` 수정 (modify)

JSONL의 `compressed: true` 레코드에서 SKILL.md 프레임 생성.
`--source` 인자: MD 파일 경로 → JSONL의 slug 또는 tag 지정으로 변경.

#### 4.2.11 `scripts/common.sh` — MD 파싱 함수 삭제 (delete)

Phase 2 모든 스크립트 전환 완료 확인 후:
```
format_yaml_tags()
parse_frontmatter()
parse_body()
get_field()
get_tags()
```

5개 함수 삭제. `schema.json`의 exports 목록에서도 제거.

---

### Phase 3: PROGRESS → harnish-current-work.json

#### 4.3.1 `scripts/validate-progress.sh` 수정 (modify)

line 17: `PROGRESS_FILE="${1:-./PROGRESS.json}"`
→ `PROGRESS_FILE="${1:-$(resolve_progress_file)}"`

common.sh source 추가 (현재 없으면):
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
```

에러 메시지: `PROGRESS.json` → `harnish-current-work.json`

#### 4.3.2 `scripts/loop-step.sh` 수정 (modify)

line 8: `PROGRESS_FILE="${1:-./PROGRESS.json}"`
→ `PROGRESS_FILE="${1:-$(resolve_progress_file)}"`

common.sh source 추가.
에러 메시지 변경.

#### 4.3.3 `scripts/compress-progress.sh` 수정 (modify)

line 22: `PROGRESS_FILE="${1:-./PROGRESS.json}"`
→ `PROGRESS_FILE="${1:-$(resolve_progress_file)}"`

archive 경로: `.progress-archive/phases.jsonl`
→ `.harnish/harnish-progress-archive.jsonl`

backup 경로: `${PROGRESS_FILE}.backup` (자동으로 `.harnish/harnish-current-work.json.backup`)

archive_ref 값: `.progress-archive/phases.jsonl#phase=N`
→ `harnish-progress-archive.jsonl#phase=N`

#### 4.3.4 `scripts/check-violations.sh` 수정 (modify)

기본 경로 변경. common.sh source 추가.

#### 4.3.5 `scripts/progress-report.sh` 수정 (modify)

line 9: `PROGRESS_FILE="${1:-./PROGRESS.json}"`
→ `PROGRESS_FILE="${1:-$(resolve_progress_file)}"`

common.sh source 추가.
에러 메시지 + 출력 텍스트에서 `PROGRESS.json` → `harnish-current-work.json`.

---

### Phase 4: SKILL.md + references 업데이트

#### 4.4.1 `skills/harnish/SKILL.md` 수정 (modify)

35개 참조를 일괄 변경:
- `$HARNISH_ROOT/_base/assets` → 제거 (인자 자체를 삭제, resolve 함수에 위임)
- `--base-dir "$HARNISH_ROOT/_base/assets"` → 삭제
- `./PROGRESS.json` → `./.harnish/harnish-current-work.json`
- `PROGRESS.json` (텍스트 참조) → `harnish-current-work.json`
- `_base/assets/` → `.harnish/`
- 환경 설정 섹션에 `bash "$HARNISH_ROOT/scripts/init-assets.sh"` 추가

§1.28 줄: `bash 3.2+, python3, POSIX 유틸리티` → `bash 3.2+, jq, python3` (실제 의존)

#### 4.4.2 `skills/drafti-architect/SKILL.md` 수정 (modify)

3곳의 `--base-dir "$HARNISH_ROOT/_base/assets"` 삭제.
`_base/assets` 텍스트 참조 → `.harnish/` 변경.

#### 4.4.3 `skills/drafti-feature/SKILL.md` 수정 (modify)

6곳의 `--base-dir "$HARNISH_ROOT/_base/assets"` 삭제.
`_base/assets` 텍스트 참조 → `.harnish/` 변경.

#### 4.4.4 `skills/ralphi/references/criteria-code.md` 수정 (modify)

`PROGRESS.json` 3곳 → `harnish-current-work.json`

#### 4.4.5 `skills/harnish/references/progress-template.md` 수정 (modify)

파일명 참조 변경.

#### 4.4.6 `skills/harnish/references/task-schema.md` 수정 (modify)

`PROGRESS.json` → `harnish-current-work.json`

#### 4.4.7 `skills/harnish/references/guardrail-levels.md` 수정 (modify)

`PROGRESS.json` 2곳 변경.

#### 4.4.8 `skills/harnish/references/escalation-protocol.md` 수정 (modify)

1곳 변경.

#### 4.4.9 `skills/harnish/references/thresholds.md` 수정 (modify)

`_base/assets` 2곳 → `.harnish/`

#### 4.4.10 `skills/harnish/references/schema.json` 수정 (modify)

- exports 목록에서 삭제된 함수 제거: `format_yaml_tags`, `parse_frontmatter`, `parse_body`, `get_field`, `get_tags`
- 추가된 함수 등록: `resolve_progress_file`, `resolve_rag_file`

---

### Phase 5: 정리 + 테스트

#### 4.5.1 `.gitignore` 수정 (modify)

before:
```
_base/assets/failures/
_base/assets/patterns/
_base/assets/guardrails/
_base/assets/snippets/
_base/assets/decisions/
_base/assets/compressed/
_base/assets/index.json
PROGRESS.json
PROGRESS.json.backup
PROGRESS.md
work-current-rag.md
state.json
```

after:
```
.harnish/
```

#### 4.5.2 `_base/` 디렉토리 삭제 (delete)

`rm -rf _base/`

#### 4.5.3 `scripts/test-all.sh` 재작성 (modify)

변경 대상 섹션:
- 환경 설정: `ASSET_DIR="$TMPDIR_BASE/assets"` → `ASSET_DIR="$TMPDIR_BASE/.harnish"`
- `PROGRESS_FILE="$TMPDIR_BASE/PROGRESS.json"` → `PROGRESS_FILE="$TMPDIR_BASE/.harnish/harnish-current-work.json"`
- init 테스트: 디렉토리 8개 확인 → `harnish-rag.jsonl` + `harnish-current-work.json` 존재 확인
- record 테스트: MD 파일 존재 → JSONL에 1줄 추가 확인 (`wc -l`)
- query 테스트: frontmatter 기반 → JSONL jq 기반
- compress 테스트: `.compressed/` 확인 → JSONL 내 `compressed: true` 확인
- 왕복 테스트: record → query → 결과 매칭
- schema.json 테스트: export 함수 목록 업데이트 반영
- SKILL.md 정합성 테스트: 기존 유지 (4개 스킬)
- references 존재 테스트: 기존 유지
- 환경변수: `ASSET_BASE_DIR` 테스트 경로 변경

#### 4.5.4 전체 테스트 실행

```bash
bash scripts/test-all.sh
```

전체 PASS.

#### 4.5.5 E2E 검증

```bash
TMPDIR=$(mktemp -d)
export ASSET_BASE_DIR="$TMPDIR/.harnish"

bash scripts/init-assets.sh --base-dir "$ASSET_BASE_DIR"
# → .harnish/harnish-rag.jsonl 존재
# → .harnish/harnish-current-work.json 존재

bash scripts/record-asset.sh --type failure --title "e2e-test" --tags "e2e,test" --body "E2E 검증" --base-dir "$ASSET_BASE_DIR"
# → harnish-rag.jsonl에 1줄

bash scripts/query-assets.sh --tags "e2e" --format text --base-dir "$ASSET_BASE_DIR"
# → "e2e-test" 포함 출력

rm -rf "$TMPDIR"
```

## §5 의존 관계

```
Phase 1 (common.sh)
    ↓
Phase 2 (자산 전환)  ←→  Phase 3 (PROGRESS 전환)   [병렬 가능]
    ↓                        ↓
         Phase 4 (문서 업데이트)
              ↓
         Phase 5 (정리 + 테스트)
```

## §6 테스트 기준

| ID | 검증 내용 | 방법 |
|----|----------|------|
| T1 | init 후 `.harnish/harnish-rag.jsonl` 존재 | `bash init-assets.sh && test -f .harnish/harnish-rag.jsonl` |
| T2 | init 후 `.harnish/harnish-current-work.json` 존재 | `test -f .harnish/harnish-current-work.json` |
| T3 | record 후 JSONL에 1줄 추가 | `wc -l < harnish-rag.jsonl` 값 증가 |
| T4 | record 결과가 유효한 JSON | `tail -1 harnish-rag.jsonl \| jq .` exit 0 |
| T5 | record 후 query에서 조회됨 | `query-assets.sh --tags "..." \| grep "제목"` |
| T6 | 타입 필터 동작 | `query-assets.sh --tags "..." --types "failure"` |
| T7 | 3개 출력 포맷 (json/text/inject) | 각 포맷 실행, 비어있지 않음 확인 |
| T8 | compress 후 compressed 플래그 | `jq 'select(.compressed==true)' harnish-rag.jsonl` |
| T9 | validate-progress 기본 경로 | 인자 없이 실행 시 `.harnish/harnish-current-work.json` 참조 |
| T10 | loop-step 기본 경로 | 인자 없이 실행 시 `.harnish/harnish-current-work.json` 참조 |
| T11 | SKILL.md frontmatter 정합성 | 4개 스킬 name/version/description |
| T12 | references 파일 존재 | SKILL.md 참조 references 전부 존재 |
| T13 | `_base/` 디렉토리 부재 | `test ! -d _base` |
| T14 | `.gitignore`에 `.harnish/` 포함 | `grep '.harnish/' .gitignore` |
| T15 | `--base-dir` 없이 resolve 동작 | `ASSET_BASE_DIR` 미설정 + `--base-dir` 미지정 시 CWD/.harnish 사용 |
| T16 | 전체 test-all.sh PASS | `bash scripts/test-all.sh` exit 0 |

## §7 가드레일

### Hard (즉시 중단)

- JSONL 레코드에 개행 문자 포함 금지 (1줄 = 1레코드 위반)
- `harnish-rag.jsonl`에 pending 데이터 기록 금지 (확정된 자산만)
- 기존 `--base-dir` CLI 인터페이스 삭제 금지 (하위 호환 유지, 테스트용)
- `resolve_base_dir()`의 `ASSET_BASE_DIR` 환경변수 우선순위 변경 금지

### Soft (경고 + 자동 수정)

- `_base/assets` 문자열이 코드에 남아있으면 경고
- `PROGRESS.json` 문자열이 코드에 남아있으면 경고 (test-all.sh 제외)
- JSONL body 필드에 escape 안 된 따옴표 → `jq` 자동 escape
- record-asset.sh 출력 JSON 형식 변경 시 경고 (하위 호환)
