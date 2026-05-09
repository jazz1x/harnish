# Changelog

이 프로젝트의 모든 주요 변경 사항이 이 파일에 기록된다.

포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)를 따르고,
[Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html)을 준수한다.

[English](./CHANGELOG.md)

## [Unreleased]

## [0.2.0] - 2026-05-09

Frontmatter SSL `logical` block 도입. 5개 스킬 (en+ko = 10개 SKILL.md) 의 frontmatter 에 destructive surface / idempotency / rollback 을 정적으로 노출하는 메타필드 추가. 본문 / 명령 / skill 동작 무변경 — backwards-compatible additive.

### Added
- **`ssl.logical` block** — 모든 `SKILL.md` 와 `SKILL.ko.md` (5 × 2 = 10개 파일):
  - `writes` — 파괴적 쓰기 surface (예: `docs/prd-{slug}.md`, `.harnish/assets/*.jsonl`, `harnish-current-work.json`, `docs/session-*.md`, autonomous 모드의 타깃 소스 파일).
  - `deletes` — 존재하는 곳만 선언 (ralphi 의 autonomous subtraction-preferred 정책).
  - `idempotent` — forki 만 `true` (append-only, Step 8 opt-out); 나머지 4개 mutation 스킬은 `false`.
  - `resumable` — impl 만 `true` (`harnish-current-work.json` 으로 진짜 영속 체크포인트를 가진 유일한 스킬).
  - `rollback` — 복구 메커니즘으로 작동하는 HITL gate / hard guardrail / test-FAIL rollback 을 텍스트로 명시.
- `.galmuri/audit-skills-2026-05-09.md` — slim 적용 후 audit 보고서 (5 스킬, logical-only frame).

### 왜 logical 한 층만 남겼나
정적 auditor 가 YAML head 만 읽었을 때 *destructive / idempotency / rollback* 시그널이 본문 grep 으로는 추출 안 되는 부분이다. `scenes` / `branches` / `tools` / `triggers` 는 본문(`## Step N:` 헤더, 조건 표, bash 블록, description) 에 이미 있으므로 frontmatter 에 중복 선언하면 동기화 부담만 남는다.

### 왜 MINOR 인가
SemVer 의 additive change. 제거 / 이름 변경 / 동작 변경 없음 — 본문 / 명령 / skill description 무변경. unknown frontmatter 키를 무시하는 consumer (Claude Code 의 기본 동작) 는 영향 없음. `ssl.*` 를 opt-in 으로 활용하는 consumer 는 새 capability 를 얻는다.

## [0.1.1] - 2026-05-07

Audit-driven 본문 prose 패치. Frontmatter 스키마 변경 / 스크립트 변경 없음. SSL audit 프레임이 드러낸 문서화된-동작 갭 3건을 닫는다 (`docs/prd-audit-driven-fixes.md` 참조).

### Fixed
- **ralphi Step 3B (en+ko)**: orphan reference `references/criteria-project.md` 가 이제 로드된다 — Step 3B 가 Step 3A 의 "정확히 **1** criteria file" 패턴을 미러. Directory-scope 검사가 criteria reference 없이 도는 일이 사라짐.
- **drafti-architect Step 5 (en+ko) + drafti-feature Step 7 (en+ko)**: `docs/prd-{slug}.md` 의 silent overwrite 차단. HITL 프롬프트가 사전 존재를 감지하면 `(y / n / edit-slug)` 대신 `(overwrite / n / new-slug)` 제시. 각 스킬 `Prohibited` 에 대칭 항목 추가. Save-guard 가 `(only after y or overwrite)` 로 갱신 — 새 분기가 save 단계에서 막히지 않게 함.
- **impl Step 5 (en+ko)**: orphan reference `references/retention-policy.md` 를 의도적으로 다룸 — manual-trigger 행 (`자산 보존 정책` / `asset retention policy`) 추가, Mode Detection 노트가 retention/purge 를 어떤 발화로도 자동 로드되지 않는 out-of-band 운영으로 명시.

### Added
- `docs/prd-audit-driven-fixes.md` — 본 릴리스를 다루는 PRD. v0.0.3 mid-loop guard 선례 (prose+bats 패턴) 에 따라 작성.
- `tests/skills_drafti.bats` — drafti-architect Step 5 + drafti-feature Step 7 의 overwrite-gate 회귀 테스트 (en+ko).
- `tests/skills_ralphi.bats` — `criteria-project.md` 매핑 회귀 (en+ko).
- `tests/skills_impl.bats` (확장) — `retention-policy.md` reference 회귀 (en+ko).
- `tests/skills_orphan_refs.bats` — **일반 orphan-reference 가드**: 모든 `skills/*/references/*.md` (en + ko) 가 대응 `SKILL.md` 본문에서 mention 되어야 한다. 본 릴리스에서 수정한 클래스의 버그(orphan reference) 를 예방. 현재 34/34 references 연결됨.

### Changed
- `impl` Step 5 manual triggers 표 헤더 (en+ko): `Script` / `스크립트` → `Action` / `동작`. 새 retention-policy 행이 `.sh` 스크립트가 아니라 `.md` reference 문서를 가리키므로 표 의미를 일관되게 유지하기 위한 일반화.

### Versioning
- `VERSION`, `.claude-plugin/plugin.json`, 5 SKILL × (md + ko.md) = 10 frontmatters, `README.md` + `README.ko.md` 배지 — 모두 `0.1.0` → `0.1.1` 로 lockstep bump (deep-tier 검사: `scripts/test-all.sh:1037-1053`).

## [0.1.0] - 2026-04-29

Big-bang 마이그레이션: 모든 `jq` 사용을 Python 표준 라이브러리로 교체. 외부 인터페이스 (CLI 플래그, stdin/stdout JSON, exit codes, hooks.json, SKILL.md) 는 100% 보존.

### Changed
- **18개 스크립트 전부**: bash+jq 로직을 `scripts/harnish_py/` 파이썬 패키지로 교체; `.sh` 파일은 이제 2-라인 wrapper (`PYTHONPATH + exec python3 -m harnish_py <sub> "$@"`)
- `common.sh`: `require_cmd jq` 제거; `resolve_*` 헬퍼와 `slugify` 만 남음
- `scripts/skillify.sh`: `skillify_version` `0.0.5` → `0.1.0`
- CI: Python `3.12` → `3.14`; `pytest` 단위 단계가 bats 앞에 추가됨; `jq` 설치는 테스트 인프라용으로 유지 (`test-all.sh` + bats 파일이 단언용으로 jq 사용; 프로덕션 스크립트는 더 이상 jq 의존성 없음)
- VERSION + 10 SKILL.md frontmatter: `0.0.5` → `0.1.0`
- `.claude-plugin/plugin.json`: `0.0.4` → `0.1.0` (v0.0.5 릴리스에서 누락된 bump 를 따라잡음 — 사전 존재하던 불일치)

### Added
- `scripts/harnish_py/` — 18-모듈 파이썬 패키지 (cli, io, common, asset, record, query, init, compress, promote, detect, skillify, quality, thresholds, purge, migrate, progress, violations)
- `tests/conftest.py` — pytest sys.path 주입 (honne 패턴)
- 11개 pytest 단위 테스트 파일 (35+ 테스트): io, cli, asset, record, query, compress, promote, skillify, purge, progress, init
- Python 3.14+ 버전 가드 (`sys.version_info < (3, 14)` → exit 4)
- `_Parser` 클래스 (argparse exit code 1 instead of 2, honne 패턴)

### Removed
- `jq` 런타임 의존성 — `scripts/` 가 이제 어디서도 `jq` 를 호출하지 않음 (wrapper 는 순수 위임)

## [0.0.5] - 2026-04-28

이 릴리스는 자산 스토어 정체성 정정과 0.0.6 으로 초안잡혔던 프로덕션 파이프라인 클로저를 함께 묶음. 둘 다 0.0.5 로 출시.

### Fixed (CRITICAL — closed loop 복구)
- **Trigger→Record 파이프라인 클로저**: hook 이 `/tmp/harnish-pending-*.jsonl` 에 적재한 실패 컨텍스트가 세션 종료 시 삭제만 되고 자산으로 영속화되지 않던 버그를 수정. `Stop` 이벤트가 새 `promote-pending.sh` 를 호출하여 자동 dedup + `record-asset.sh` 호출 + 영속화. README 의 "failures become guardrails" 약속이 처음으로 실제 동작.

### Changed
- **BREAKING (파일 rename, 자동 마이그레이션)**: 자산 스토어 rename `.harnish/harnish-rag.jsonl` → `.harnish/harnish-assets.jsonl`. `init-assets.sh` 가 첫 실행 시 legacy 파일이 있고 새 파일이 없으면 idempotent atomic `mv` 수행. 데이터 손실 없음.
- 아카이브 파일 rename: `harnish-rag-archive.jsonl` → `harnish-assets-archive.jsonl` (`purge-assets.sh --execute` 출력)
- L0 Contract (`schema.json`) 필드 rename: `rag_record` → `asset_record`, `storage.rag_file` → `storage.asset_file`
- 14개 스크립트: `RAG_FILE` / `RAG` shell 변수 → `ASSET_FILE` / `ASSETS`; `harnish-rag.jsonl` 리터럴 교체
- `common.sh`: `resolve_rag_file()` 를 `resolve_asset_file()` 의 deprecated alias 로 유지; 마이그레이션 경로용 `resolve_legacy_asset_file()` 신설
- `scripts/skillify.sh` 프로덕션-등급 업그레이드:
  - description 에 `Triggers: ...` 자동 생성 (자산 title 에서 빈도 기반 5개 후보 추출)
  - body 구조화: §1 가이드라인 (LLM finalize) / §2 타입별 자산 섹션 (Failures/Patterns/Guardrails/Decisions/Snippets) / §3 메타데이터
  - `references/source-assets.jsonl` 트레이서빌리티 보존
  - 자산 메타 필드 노출: level / confidence / stability / resolved
- `scripts/query-assets.sh --format inject` 출력에 RCA 컨텍스트 포함:
  - guardrail 은 `[guardrail/soft]`, decision 은 `[decision/medium]`, pattern 은 `[pattern/s1]` 로 type 머리에 메타 노출
  - 각 자산에 `context:` 라인 추가, failure 는 `resolved:` 표시

### Added
- `scripts/promote-pending.sh` — pending JSONL 을 `(tool, first_error_line)` 키로 deduplicate 후 자동으로 `failure` 자산 등록. 태그: `auto`, `tool:<name>`, `session:<short>`. context 에 occurrences 카운트.
- `tests/e2e_pipeline.bats` — 4개 production E2E (trigger→record, dedup, skillify quality, inject 풍부화).
- `tests/scripts_advanced.bats` +2: legacy `harnish-rag.jsonl` → `harnish-assets.jsonl` 마이그레이션 회귀 + idempotency 테스트
- README "Memory Model" 섹션: 2-tier 모델 (Tier 1 Asset Store + Tier 2 Skills) 을 문서화하고 strict RAG 는 `query-assets.sh --format inject` 만임을 명확화

### Documentation
- README "ralph loop" 의 잘못된 약자 풀이 (`Read → Act → Log → Progress`) 제거. 이름은 심슨의 Ralph Wiggum 에서 유래한 것이며 약자가 아님을 명시.
- `skillify.sh` 의 솔직한 framing: 그것은 draft generator (자산 묶기 + TODO scaffold) 이며, autonomous skill graduation 이 **아니다**. 미래 기능은 로드맵에 플래그.
- README/SKILL.md/thresholds.md path references 가 `harnish-assets.jsonl` 로 갱신됨

## [0.0.4] - 2026-04-27

### Fixed
- `check-thresholds.sh` W1: `--threshold` 플래그가 인자 순서와 무관하게 올바르게 파싱; `--base-dir` 가 먼저 오면 threshold 값이 silent 하게 망가지던 버그 해결
- `compress-assets.sh` C1: 압축된 요약 본문에 `TODO` placeholder 가 더 이상 들어가지 않음 — 소스 레코드를 compressed 로 표시하기 전에 title 추출
- `skills/impl/references/schema.json` L0 Contract: 6개 스크립트의 `script_io` 항목을 실제 CLI 와 일치하도록 갱신 (purge-assets, compress-assets, quality-gate, localize-asset, abstract-asset, skillify)
- `record-asset.sh`: 중복 slug 자동 suffix (`-2`, `-3` ...) — `query-assets.sh` write-back 이 같은 title 의 무관한 레코드의 `access_count` 를 올리는 것을 방지
- `loop-step.sh`: while-loop 인자 파싱 정확화 — 명시적 파일 경로 없는 `--format json` 이 이제 `resolve_progress_file()` 로 올바르게 해석
- `validate-progress.sh`: 유효 status-emoji 집합에 `🔵` 추가 — 진행 중 작업 파일에 대한 false WARNING 제거
- `compress-progress.sh`: deterministic `.tmp` 경로를 `mktemp` 로 교체 — 동시 실행 충돌 제거
- `detect-asset.sh`: Stop 이벤트에서 세션 pending 파일 삭제 + `/tmp` 의 7일 이상 묵은 stale pending 파일 정리
- `migrate.sh`: 가장 최근 3개의 `.bak.*` 파일만 유지 — 무한 backup 누적 방지

### Added
- `tests/e2e_workflow.bats` — 9개 E2E 테스트가 진행 파이프라인 전체를 커버: `init-assets → validate-progress → loop-step → compress-progress → progress-report → check-violations`
- `tests/e2e_assets.bats` — 11개 E2E 테스트가 자산 라이프사이클 전체를 커버: `record(6 types) → query → check-thresholds → compress-assets → quality-gate → migrate → purge`
- `tests/scripts_advanced.bats` +5: `purge --execute`, `loop-step --format without path`, `detect-asset meaningful error → pending`, `detect-asset Stop → pending deleted`
- `scripts/skillify.sh`: 구성 가능한 skill 출력 디렉토리용 `--output-dir` 플래그

## [0.0.3] - 2026-04-23

### Fixed
- impl 스킬: Mid-loop interruption 가드 — milestone HITL, 3-failure escalation, hard-guardrail 위반이 아닌 어떤 중단도 명시적으로 prose 에서 금지 (docs/prd-impl-midloop-guard.md 참조)

## [0.0.2] - 2026-04-22

### Added
- 테스트 스위트 + GitHub Actions CI — 25개 bats 테스트 (manifest schema + script smoke + sandboxing) 와 `scripts/test-all.sh` 를 감싸는 deep tier. 매트릭스는 `ubuntu-latest` + `macos-latest`.
- 모든 스킬 description 에 self-name 트리거 추가 — `"forki"`, `"impl"`, `"harnish"` (와 변형), `"drafti-architect"`, `"drafti"`, `"drafti-feature"` 가 이제 first-class 트리거. 자연어 호출이 슬래시 없이도 자동 invoke.

### Changed
- **BREAKING:** 메인 구현 스킬 rename `harnish` → `impl` (`/harnish:harnish` → `/harnish:impl`). "harnish" 엔진 컨셉은 보존 — `impl` 이 trigger 리스트에 `"harnish"`, `"harnish 시작"`, `"harnish 돌려"`, `"harnish 이어서"` 를 유지하므로 기존 자연어 호출은 그대로 작동.
- `scripts/test-all.sh` — obsolete 한 `har-*` shortcut parity 섹션 제거 (해당 스킬들은 v0.0.1 사이클에서 제거됨); SKILL 버전 검사가 하드코딩 대신 `plugin.json` 으로부터 expected version 을 derive (bump 시 drift 없음).
- `scripts/test-all.sh` — 한국어 문자에 인접한 변수 ref 를 brace-wrap (`${var}개` 대신 `$var개`) — `set -u` 하의 CI macOS bash 3.2 + C locale 파싱 문제 해결.
- `scripts/common.sh` — `resolve_skill_dir()` 가 `skills/impl` 을 가리키도록 갱신.

## [0.0.1] - 2026-04-22

첫 공개 릴리스. 5개 스킬 + 공유 스크립트 스위트 + 자산 인프라 + 자동 등록 hooks.

### Added

#### forki `0.0.1`
- 의사결정 강제 스킬 (binary fork + D/E/V/R + trade-off, HITL only)
- counter semantics — abort on attempt 3/3 (2 back-jumps)
- decision asset recording (Step 0/8)
- router + references 분리 구조

#### drafti-architect `0.0.1`
- 기술 주도 설계 PRD 생성 스킬
- 10단계 체크리스트 기반 순차 실행
- 설계 대안 2~3개 + 트레이드오프 매트릭스
- HARNISH_ROOT 감지: 모노리포/독립 모드 자동 판별
- references: design-decision.md, prd-template.md

#### drafti-feature `0.0.1`
- 기획 요구사항 기반 피쳐 PRD 생성 스킬
- 피쳐플래그 설계 (boolean/percentage/segment + 킬스위치) — 조건부 적용
- 언어 비종속 코드베이스 탐색 (§4 Step 0 언어 감지)
- HARNISH_ROOT 감지: 모노리포/독립 모드 자동 판별
- references: feature-flag-patterns.md, prd-template.md

#### impl `0.0.1` (the "harnish" engine)
- 자율 구현 엔진 (시딩 + ralph 루프 + 앵커링 + 경험 축적)
- 모드 A: PRD → 원자적 태스크 분해 → `harnish-current-work.json` 생성
- 모드 B: ralph 루프 (한 태스크씩 자동 실행 → 결과 기록 → 진행률 갱신 반복)
- 모드 C: 세션 복원 (앵커링) + 자산 감지/기록/압축/스킬화
- §B.9 acceptance_criteria 실행: bash/조건/혼합/없음 4가지 분기
- 다언어 타입 체커 (Python/TS/Go/Java/Rust)
- **Step 6: Post-Completion Ceremony** — 작업 완료 후 자동 점검(ralphi) + 자산 압축 제안 + 요약 + HITL 저장
- 인자 없이 호출 시 입력 안내 (entry prompt)
- references: task-schema.md, progress-template.md, escalation-protocol.md, guardrail-levels.md, thresholds.md, retention-policy.md

#### ralphi `0.0.1`
- 아티팩트 정합성 검증 스킬 (자가검증 + 자가수정 루프, 최대 7회)
- 4개 아티팩트 타입: PRD, SKILL.md, 스크립트, 코드
- HITL + 자율 수정 모드 (발화 기반 판별: "점검해"→HITL, "고쳐"→자율)
- 필요성 검증 (소크라테스식) + Context Budget + subtraction 원칙
- criteria-code.md: 9개 언어 도구 매핑 테이블
- criteria-project.md: 프로젝트/디렉토리 스코프 점검 기준
- references: criteria-code.md, criteria-prd.md, criteria-skill.md, criteria-script.md, criteria-project.md

#### Shared scripts
- validate-progress.sh, loop-step.sh, compress-progress.sh, check-violations.sh
- query-assets.sh (write-back: access_count 자동 증가)
- record-asset.sh (`schema_version`, `last_accessed_at`, `access_count` 필드)
- detect-asset.sh, init-assets.sh
- compress-assets.sh (`--dry-run` 비파괴 압축 후보 조회)
- check-thresholds.sh, quality-gate.sh, skillify.sh
- abstract-asset.sh, localize-asset.sh, common.sh, pre-commit.sh
- migrate.sh (스키마 백필)
- POSIX 호환 (macOS BSD grep 대응, GNU 전용 플래그 미사용)

#### Asset infrastructure
- `.harnish/harnish-rag.jsonl` — 6 자산 타입 (failure, pattern, guardrail, snippet, decision, compressed)
- Asset TTL & Purge — retention-policy 기반 자산 자동 정리 (타입별 보존 기간)
- 워크트리 격리 (CWD 기준 독립 `.harnish/`)

#### Hooks (auto-registered via `hooks/hooks.json`)
- `PostToolUse` (Bash/Edit/Write/NotebookEdit) → 실패 패턴·가드레일·재사용 스니펫 감지
- `PostToolUseFailure` → 의미 있는 실패 컨텍스트 캡처 (노이즈 필터)
- `Stop` → 누적 자산 품질 게이트 + 임계치 확인

#### Plugin manifest
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`
- `/plugin marketplace add https://github.com/jazz1x/harnish.git` + `/plugin install harnish` 설치 경로
- i18n: 영문 기본 + 한국어 별도 파일 (`SKILL.ko.md`, `README.ko.md`)

#### Documentation
- README 구조 정리 (galmuri 동일 톤): badges, install steps, quickstart, usage, hooks, assets, worktrees, fork & customize, naming, triad
- VERSIONING.md, references/* 가이드

[Unreleased]: https://github.com/jazz1x/harnish/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/jazz1x/harnish/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/jazz1x/harnish/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jazz1x/harnish/compare/v0.0.5...v0.1.0
[0.0.5]: https://github.com/jazz1x/harnish/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/jazz1x/harnish/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/jazz1x/harnish/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/jazz1x/harnish/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/jazz1x/harnish/releases/tag/v0.0.1
