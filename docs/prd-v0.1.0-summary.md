# v0.1.0 — Python migration · 1-page summary

> distilled from `docs/prd-v0.1.0-python-migration.md` (audience: reviewers + external contributors)

## Why

`jq`가 없는 환경이 실제로 존재했고, bash + jq로 상태머신성 로직(retry queue 등)을 표현하기 어려움이 v0.0.5에서 드러났다. Python 표준 라이브러리로 옮기면 두 문제 모두 사라진다. honne가 이미 같은 마이그를 했고 패턴이 검증됨.

## What changes (외부 시점)

**아무것도 변하지 않는다.** `.sh` 파일명, CLI 옵션, stdin/stdout JSON, exit code, hooks.json 경로, 모든 SKILL.md 호출 — 전부 동일. 외부 호출자 변경 0.

## What changes (내부)

| 영역 | Before | After |
|------|--------|-------|
| 핵심 로직 | `scripts/*.sh` + `jq` | `scripts/harnish_py/*.py` (표준 라이브러리만) |
| `.sh` 파일 | 14+ 실제 구현체 | 14+ 1-line wrapper (`exec python3 -m harnish_py {sub} "$@"`) |
| 의존성 | `jq` (hard) | Python 3.14+ (`sys.version_info` 가드, exit 4) |
| Unit 테스트 | 없음 | pytest ≥30건 (pure module) |
| E2E 테스트 | bats 80건 | bats 80건 **그대로** (회귀망 보존) |
| CI | macOS + Python 3.12 | macOS + Python 3.14 + pytest step 추가 |

## How (single PR, 5 internal phases)

| Phase | 산출 | Acceptance |
|-------|------|------------|
| 1. Foundation | `harnish_py/` 패키지 + `io.py` + `cli.py` skeleton + `conftest.py` + CI 갱신 | `--version` 동작, unit_io PASS |
| 2. Storage | `record/query/init` + 3 wrappers | 기존 storage bats PASS |
| 3. Pipeline | `promote/detect/compress` + 3 wrappers (hook stdin JSON 정확 보존) | `e2e_pipeline.bats` 4건 PASS |
| 4. Skill / quality / progress | `skillify/quality/thresholds/purge/migrate/progress/violations` + 7 wrappers | `scripts_advanced.bats` 29건 PASS |
| 5. Cleanup | `common.sh`에서 jq 제거, README/CHANGELOG/VERSION/plugin.json/SKILL.md 10개 0.0.5 → 0.1.0 | grep -r "jq " scripts/ → 0 (wrapper 외) |

빅뱅 PR이지만 작업 순서는 의존 그래프상 분해. 단일 squash → 단일 revert 가능.

## Decision rationale (forki + drafti)

- **빅뱅 vs 점진**: forki에서 빅뱅 선택 (단일 사용자 도구, 점진의 절대 가치 낮음, honne 패턴으로 첫 작성 부담 낮음)
- **Wrapper vs Python-only 진입**: Wrapper 선택 — hooks.json + SKILL.md 호환성 보존이 최우선. 유효성 조건: 외부 호환 우선순위 유지되는 동안. v0.2.0+에서 console_script 도입 시 재방문.
- **bats 마이그**: 안 함 (별도 PR). 회귀망 = E2E 계약. pytest = 신규 unit만.

## Top risks

1. **bats stdout 정확 매치** — 한 글자 차이로 회귀 fail. 한글 메시지/JSON 출력 byte 단위 보존, `json.dumps(sort_keys=True)`로 jq `-S` 동작 모방.
2. **hook startup 오버헤드** — 1-line wrapper의 Python 시작 비용 (~50ms × hook 호출 수). 측정 후 임계 초과 시 `python -X frozen_modules` 등 가속 별도 평가.

## Non-goals (이번 PR 외)

- bats 80건 → pytest 마이그
- `pyproject.toml` / `pip install -e .` 진입
- mypy / ruff
- 한글 메시지 → 영문 (인터페이스 보존 원칙상 한글 그대로)

## Rollback

단일 squash commit → `git revert` 1회로 v0.0.5 100% 복귀.

## Read full PRD

`docs/prd-v0.1.0-python-migration.md` — §4.1 디렉토리 구조, §4.4 14개 모듈 매핑 표, §6 35건 unit 테스트 목록, §7 가드레일 8건, §8 Phase별 상세 acceptance.
