# PRD — v0.1.0 jq → Python big-bang migration

> 2026-04-29 · Medium scale · §1~§8 full

## §1. Problem & Goal

### Problem
harnish v0.0.5의 모든 핵심 스크립트(`scripts/*.sh`)는 bash + `jq` 조합으로 JSONL 자산을 다룬다. 두 가지 명시적 한계가 v0.0.5 작업 중 드러남:

1. **`jq` portability**: 사용자 환경에 `jq`가 미설치된 케이스 발생. 설치 의존을 보장하기 어려움.
2. **bash + jq 조합의 가독성/디버그 한계**: retry queue 같은 상태머신성 로직(new → retry → dead-letter)을 jq 파이프로 표현하면 라인이 폭발하고 단위 테스트가 어렵다.

### Goal
- 모든 `jq` 사용을 Python 표준 라이브러리로 대체.
- 외부 호출자(hooks, SKILL.md, 사용자 명령)에서 보이는 인터페이스(파일명/CLI 옵션/stdout JSON/exit code)는 100% 유지.
- 패키지 구조 + 테스트 인프라가 자매 프로젝트 `honne`와 일관성 유지(`scripts/<project>_py/`, `*_test.py`, conftest.py로 sys.path 주입, 표준 라이브러리만).
- Python 3.14+ 환경 가드.

### Success Criteria
| 지표 | 기준 |
|------|------|
| 기존 bats E2E 테스트 | 80건 PASS 유지 |
| 신규 pytest unit 테스트 | ≥ 30건 (각 모듈 핵심 함수 커버) |
| `jq` 의존 | scripts/ 내에서 0회 호출 |
| Python version 가드 | `sys.version_info < (3, 14)` → exit 4 |
| 외부 호환 | hooks.json, 모든 SKILL.md 변경 0 |
| CI | macOS-latest matrix에서 bats + pytest 둘 다 PASS |

## §2. Constraints (재확인)

| 영역 | 제약 |
|------|------|
| **인터페이스 동일성** | `.sh` 파일명, CLI 옵션, stdin/stdout JSON, exit code 모두 v0.0.5와 동일 |
| **외부 의존 제로** | Python 표준 라이브러리만 (`pyproject.toml` / `requirements.txt` 없음) |
| **Python 버전** | 3.14+ (`sys.version_info < (3, 14)` → return 4) |
| **bash wrapper** | 모든 `.sh` 진입점은 1줄 wrapper로 유지: `exec python3 -m harnish_py {subcommand} "$@"` |
| **단일 revert 롤백** | 빅뱅 PR이지만 단일 commit 또는 squashed PR로 revert 가능 |
| **pytest 추가** | 기존 bats 80건은 변경 없음. pytest는 신규 unit만 |
| **CI 변경** | `.github/workflows/tests.yml`에 `setup-python@v5 with python-version: 3.14` 추가 |

## §3. Selection Rationale (forki 산출 + drafti sub-decisions)

### Migration strategy: A. Big-bang (forki Step 6)
- 1번의 큰 결정 + 깔끔한 롤백 vs 점진적 hybrid 상태의 긴 잔존
- harnish는 단일 사용자 도구 → 점진 배포의 절대 가치는 낮음
- honne가 같은 마이그를 이미 했음 → 패턴 학습 부담 낮음

### Entry pattern: Alt A. Bash 1-line wrapper
- hooks.json + SKILL.md 호환성 보존이 최우선
- 유효성 조건: 외부 호환성 우선순위 유지되는 동안. v0.2.0+에서 console_script 도입 시 Alt B로 재방문.

### Test infra: Alt T1. bats 유지 + pytest 신규 unit만
- 기존 80건 = E2E 계약, 신규 pytest = pure module unit
- 두 러너 비용은 단일 PR 내 가치 < 회귀망 안정성

## §4. Implementation Spec

### §4.1 디렉토리 구조

```
harnish/
├── scripts/
│   ├── harnish_py/                 ← 신규 Python 패키지
│   │   ├── __init__.py             (__version__ = "0.1.0")
│   │   ├── __main__.py             (python -m harnish_py 진입)
│   │   ├── cli.py                  (argparse subcommand 라우터)
│   │   ├── io.py                   (atomic_write, jsonl_read/write, sha256_file)
│   │   ├── asset.py                (asset record dataclass + serialization)
│   │   ├── common.py               (resolve_base_dir, env helpers)
│   │   ├── record.py               (record-asset 로직)
│   │   ├── query.py                (query-assets + format text/json/inject)
│   │   ├── compress.py             (compress-assets)
│   │   ├── promote.py              (promote-pending dedup)
│   │   ├── detect.py               (detect-asset hook 로직)
│   │   ├── init.py                 (init-assets — atomic mv legacy migration)
│   │   ├── skillify.py             (skillify SKILL.md scaffold)
│   │   ├── quality.py              (quality-gate)
│   │   ├── thresholds.py           (check-thresholds)
│   │   ├── purge.py                (purge-assets TTL)
│   │   ├── migrate.py              (migrate schema backfill)
│   │   ├── progress.py             (validate-progress, loop-step, compress-progress)
│   │   └── violations.py           (check-violations)
│   ├── record-asset.sh             ← 1-line wrapper
│   ├── query-assets.sh             ← 1-line wrapper
│   ├── ... (14+ wrappers)
│   └── common.sh                   ← 보존 (resolve_rag_file deprecated alias 유지)
├── tests/
│   ├── conftest.py                 ← 신규 (sys.path 주입)
│   ├── *.bats                      ← 기존 80건 변경 없음
│   ├── unit_io_test.py             ← 신규 pytest unit
│   ├── unit_asset_test.py
│   ├── unit_query_filter_test.py
│   ├── unit_record_test.py
│   ├── unit_promote_dedup_test.py
│   ├── unit_skillify_test.py
│   └── ... (≥30건)
└── .github/workflows/tests.yml     ← Python 3.14 추가
```

### §4.2 진입점 wrapper 패턴

모든 `scripts/*.sh` 진입점은 다음 형태로 통일:

```bash
#!/usr/bin/env bash
# record-asset.sh — Python migration wrapper (v0.1.0+)
# 실제 구현: scripts/harnish_py/record.py
exec python3 -m harnish_py record-asset "$@"
```

`common.sh`는 `resolve_rag_file()` deprecated alias 유지(다음 메이저에서 제거)와 일부 외부 source용 헬퍼만 남기고 나머지 로직 제거.

### §4.3 CLI subcommand 라우팅

`harnish_py/cli.py`:

```python
import argparse
import sys
from . import __version__

class _Parser(argparse.ArgumentParser):
    """Exit code 1 on bad args (vs argparse default 2)."""
    def error(self, message):
        self.print_usage(sys.stderr)
        self.exit(1, f"error: {message}\n")

def main(argv=None):
    if sys.version_info < (3, 14):
        sys.stderr.write("python3>=3.14 required\n")
        return 4

    parser = _Parser(prog="harnish_py", description="harnish — autonomous implementation engine")
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = parser.add_subparsers(dest="command", required=True, parser_class=_Parser)

    # 14개 subcommand 등록 (record-asset, query-assets, …)
    from . import record, query, compress, promote, detect, init, skillify, \
                 quality, thresholds, purge, migrate, progress, violations
    record.register(sub)
    query.register(sub)
    # ...

    args = parser.parse_args(argv)
    return args.func(args)

if __name__ == "__main__":
    sys.exit(main())
```

각 모듈은 `register(sub)` 함수 노출 → 자기 subparser 등록 + `args.func`에 핸들러 바인딩.

### §4.4 핵심 모듈 매핑

| 기존 .sh | 신규 Python 모듈 | 핵심 함수 | 입출력 계약 |
|----------|----------------|----------|-----------|
| `record-asset.sh` | `record.py` | `record_asset(type, tags, title, body, …) -> str (id)` | stdout: `{"status":"recorded","id":"..."}` |
| `query-assets.sh` | `query.py` | `query(filter) -> Iterator[Asset]`, `format_text/json/inject` | stdout: 형식별 출력 |
| `compress-assets.sh` | `compress.py` | `compress(threshold, dry_run) -> CompressionReport` | stdout: 보고서 JSON |
| `promote-pending.sh` | `promote.py` | `dedup(pending_path) -> List[UniqueEntry]`, `promote(entries)` | stdout: `{"status":"promoted","promoted":N,...}` |
| `detect-asset.sh` | `detect.py` | hook event router (PostToolUse, PostToolUseFailure, Stop) | stdin: hook JSON, stdout: 한글 메시지 |
| `init-assets.sh` | `init.py` | `init_base_dir()` (legacy mv 포함) | stdout: 초기화 메시지 |
| `skillify.sh` | `skillify.py` | `skillify(tag, output_dir) -> SkillScaffold` | stdout: SKILL.md 경로 |
| `quality-gate.sh` | `quality.py` | `quality_check(threshold) -> QualityReport` | exit code: 0/1/2 |
| `check-thresholds.sh` | `thresholds.py` | `check_thresholds() -> Dict[str, int]` | stdout: tag별 카운트 |
| `purge-assets.sh` | `purge.py` | `purge(ttl_days, dry_run) -> PurgeReport` | stdout: 보고서 |
| `migrate.sh` | `migrate.py` | `migrate(target_version) -> MigrationReport` | stdout: 보고서 |
| `validate-progress.sh` | `progress.py` (`validate`) | `validate_progress(path) -> ValidationReport` | exit 0/1 |
| `loop-step.sh` | `progress.py` (`loop_step`) | `loop_step(path) -> LoopStatus` | stdout: `STATUS=...` |
| `compress-progress.sh` | `progress.py` (`compress`) | `compress_progress(path, trigger)` | stdout: 보고서 |
| `check-violations.sh` | `violations.py` | `check_violations(path) -> List[Violation]` | stdout: 보고서 |

### §4.5 io.py — 공통 헬퍼

```python
import json
import tempfile
from pathlib import Path
from typing import Iterator, Any

def atomic_write(path: Path | str, data: bytes | str) -> None:
    """Tempfile + atomic replace. honne 패턴 그대로."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        data = data.encode("utf-8")
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False, suffix=".tmp") as f:
        temp_path = Path(f.name)
        f.write(data)
    temp_path.replace(path)

def jsonl_read(path: Path | str) -> Iterator[dict]:
    """Iterate JSONL records. Yield empty if file missing."""
    p = Path(path)
    if not p.exists():
        return
    with open(p, "r") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            yield json.loads(line)

def jsonl_append(path: Path | str, record: dict) -> None:
    """Append single JSONL record. Atomic per-line via append+fsync."""
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "a") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")
        f.flush()
```

### §4.6 hook 인터페이스 보존 검증

`hooks/hooks.json`은 변경 없음 (여전히 `scripts/detect-asset.sh` 호출). detect-asset.sh wrapper가 `python3 -m harnish_py detect-asset "$@"`로 라우팅. stdin JSON 파싱은 Python에서 `sys.stdin.read()` + `json.loads()`로 동일 처리.

## §5. Risks & Mitigations

| 위험 | 가능성 | 영향 | 대응 |
|------|--------|------|------|
| Python 3.14 미설치 사용자 | 중 | 사용자 시작 못 함 | wrapper 첫 줄에서 `command -v python3` 검사 + 친절한 에러 |
| 1-line wrapper의 startup 오버헤드 | 중 | hook 빈번 호출 시 누적 (~50ms × 회) | 측정 후 임계 초과 시 `python -X frozen_modules` 등으로 가속 (별도 평가) |
| 기존 bats가 stdout 정확 매치 의존 | 높 | 한 글자 변경도 회귀 fail | 기존 출력 byte 단위 보존, 한글 메시지 100% 동일 복사 |
| jq 키 정렬 vs Python dict 정렬 | 중 | JSON 비교 테스트 fail | `json.dumps(sort_keys=True)` 사용, jq의 `-S` 동작 모방 |
| Python <3.14 환경 (CI 등) | 중 | tests.yml 깨짐 | `setup-python@v5` 버전 갱신 + matrix 검증 |
| 외부 호출자 (다른 plugin) 가 .sh 파일을 직접 source | 낮 | source 호환 깨짐 | wrapper는 exec만 함 (source 안 함). 명시적 비공개 API 표시 |

## §6. Test Strategy

### §6.1 bats E2E (기존 80건 — 회귀 보호)
변경 없음. 모든 인터페이스 계약 검증을 그대로 유지.
- `tests/e2e_pipeline.bats` (4건)
- `tests/scripts_*.bats` (29 + 12건)
- `tests/manifest.bats` (13건)
- 외 기타 22건

### §6.2 pytest unit (신규 ≥30건)

| 모듈 | 신규 unit 테스트 (예시) |
|------|-----------------------|
| `unit_io_test.py` | atomic_write 동시성 / jsonl_read 빈 파일 / jsonl_append 권한 (3건) |
| `unit_asset_test.py` | Asset dataclass round-trip / required field validation (4건) |
| `unit_query_filter_test.py` | 태그 AND/OR / type 필터 / since-until 윈도우 / inject format 메타 노출 (5건) |
| `unit_record_test.py` | 중복 id 충돌 회피 / scope project vs global / session-id 옵션 (3건) |
| `unit_promote_dedup_test.py` | dedup 키 (tool, error_line[0:50]) / occurrences 카운트 / 빈 파일 (3건) |
| `unit_skillify_test.py` | trigger 추출 빈도 / 타입별 섹션 emit / references 보존 (3건) |
| `unit_compress_test.py` | threshold 미달 시 no-op / 그룹화 logic / dry-run 보고서 (3건) |
| `unit_init_test.py` | legacy 자동 mv idempotency / 부재 시 빈 파일 생성 (2건) |
| `unit_purge_test.py` | TTL 경계 / dry-run vs --execute / 분리 dead-letter 유지 (3건) |
| `unit_progress_test.py` | validate schema / loop-step coordinates / compress milestone (3건) |
| `unit_cli_test.py` | --version / 알 수 없는 subcommand → exit 1 / Python <3.14 → exit 4 (3건) |
| **합계** | **35건** |

### §6.3 pytest 진입

`tests/conftest.py`:
```python
import sys
from pathlib import Path
REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
```

실행: `python3 -m pytest tests/`

### §6.4 CI

`.github/workflows/tests.yml`:
- `setup-python@v5` with `python-version: "3.14"` (기존 3.12에서 갱신)
- 신규 step: `python3 -m pytest tests/ -v`
- 기존 step `bash tests/run.sh` 유지

## §7. Guardrails

| 규칙 | 위반 시 결과 |
|------|------------|
| **wrapper 외 어떤 .sh도 jq 호출 금지** | jq 의존 잔존 → 마이그 미완료 |
| **Python 3.14 가드 항상 cli.main()의 첫 검사** | 하위 버전에서 cryptic ImportError로 실패 |
| **표준 라이브러리만 사용** | pyproject.toml / requirements.txt 추가 시 즉시 revert |
| **외부 호환 인터페이스 변경 절대 금지** | hooks/hooks.json, SKILL.md 변경 = 호환성 깨짐 |
| **bats 회귀 80건은 1건도 fail 불가** | E2E 계약 깨짐 = 외부 호출자 영향 |
| **JSON 출력은 정렬 키 일관성 (`sort_keys=True`)** | jq 출력 차이로 외부 파서 깨짐 가능 |
| **wrapper 자체는 pure delegation** | 로직이 wrapper에 누설되면 마이그 의의 상실 |
| **단일 PR/단일 squash → 단일 revert로 롤백 가능** | 부분 commit이 본선에 들어가면 롤백 복잡 |

## §8. Migration Phases (단일 PR 내부)

빅뱅이지만 작업 순서는 의존 그래프상 분해 가능. 각 Phase 끝에 부분 동작 가능 — 단 PR은 끝까지 가서 squash.

### Phase 1 — Foundation (의존 그래프 root)
1. `scripts/harnish_py/` 패키지 생성 (`__init__.py`, `__main__.py`, `cli.py` skeleton)
2. `io.py` (atomic_write, jsonl_read/write, sha256_file)
3. `common.py` (resolve_base_dir, env helpers — bash common.sh 미러)
4. `tests/conftest.py` (sys.path 주입)
5. CI: `setup-python@v5 with 3.14` 추가
6. **Acceptance**: `python3 -m harnish_py --version` 동작 + `pytest tests/unit_io_test.py` PASS

### Phase 2 — Storage layer (asset CRUD)
1. `asset.py` (dataclass + serialization)
2. `record.py` + wrapper `scripts/record-asset.sh` 1-liner 교체
3. `query.py` (text/json/inject 형식) + wrapper
4. `init.py` (legacy mv) + wrapper
5. **Acceptance**: `bats tests/scripts_*.bats` storage 관련 테스트 PASS + 신규 pytest 8건 PASS

### Phase 3 — Pipeline layer
1. `promote.py` (dedup) + wrapper
2. `detect.py` (hook event router) + wrapper — **stdin JSON 정확 보존 검증 필수**
3. `compress.py` + wrapper
4. **Acceptance**: `bats tests/e2e_pipeline.bats` 4건 PASS + 신규 pytest 9건 PASS

### Phase 4 — Skill / quality / progress layer
1. `skillify.py` + wrapper
2. `quality.py`, `thresholds.py`, `purge.py`, `migrate.py` + wrappers
3. `progress.py` (validate / loop-step / compress) + wrappers
4. `violations.py` + wrapper
5. **Acceptance**: `bats tests/scripts_advanced.bats` 29건 + 기타 PASS + 신규 pytest 13건 PASS

### Phase 5 — Cleanup + 문서
1. `common.sh`에서 jq 호출 제거 (`resolve_rag_file` alias 등 헬퍼만 잔존)
2. `README.md` / `README.ko.md` Memory Model 섹션에 Python 마이그 한 줄 (인터페이스 동일 강조)
3. `CHANGELOG.md` [0.1.0] 추가
4. `VERSION` 0.0.5 → 0.1.0
5. `.claude-plugin/plugin.json` 0.0.5 → 0.1.0
6. 모든 SKILL.md frontmatter `version: 0.0.5` → `0.1.0` (10개)
7. **Acceptance**: 전체 bats 80 PASS + pytest ≥30 PASS + grep -r "jq " scripts/ → wrapper 외 결과 0

## §9. Rollback Plan

- 단일 PR → 단일 squash commit. 문제 시 `git revert <merge-commit>`로 v0.0.5 동작 100% 복귀.
- v0.0.5 사용자는 `/plugin update harnish` 후 문제 발견 시 `/plugin install harnish@0.0.5`로 다운그레이드 가능 (marketplace.json 버전 핀 필요 — 별도 평가).

---

## §10. Out of Scope (이번 PR)

- bats 80건 → pytest 마이그 (별도 PR)
- Python `console_script` 진입 (`pip install -e .` 같은 entry point) — 외부 호환 위해 보류
- pyproject.toml / 패키징 (별도 평가)
- type checking (mypy) / linting (ruff) — 별도 PR
- 한글 → 영문 메시지 변환 (인터페이스 보존 원칙상 한글 그대로 유지)

---

다음 단계: `/galmuri:doc`으로 PRD 압축/퇴고 → `/harnish:impl`로 자율 구현 시작.
