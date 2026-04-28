# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.5] - 2026-04-28

This release combines the asset-store identity correction with the production pipeline closure originally drafted as 0.0.6. Both ship together as 0.0.5.

### Fixed (CRITICAL — closed loop restored)
- **Trigger→Record pipeline closure**: hook이 `/tmp/harnish-pending-*.jsonl`에 적재한 실패 컨텍스트가 세션 종료 시 삭제만 되고 자산으로 영속화되지 않던 버그를 수정. `Stop` 이벤트가 새 `promote-pending.sh`를 호출하여 자동 dedup + `record-asset.sh` 호출 + 영속화. README의 "failures become guardrails" 약속이 처음으로 실제 동작.

### Changed
- **BREAKING (file rename, auto-migrated)**: Asset store renamed `.harnish/harnish-rag.jsonl` → `.harnish/harnish-assets.jsonl`. `init-assets.sh` performs an idempotent atomic `mv` on first run if the legacy file is present and the new file is absent. No data loss.
- Archive file renamed: `harnish-rag-archive.jsonl` → `harnish-assets-archive.jsonl` (`purge-assets.sh --execute` output)
- L0 Contract (`schema.json`) field rename: `rag_record` → `asset_record`, `storage.rag_file` → `storage.asset_file`
- 14 scripts: `RAG_FILE` / `RAG` shell variables → `ASSET_FILE` / `ASSETS`; `harnish-rag.jsonl` literals replaced
- `common.sh`: `resolve_rag_file()` kept as deprecated alias of `resolve_asset_file()`; new `resolve_legacy_asset_file()` for migration paths
- `scripts/skillify.sh` production-grade 업그레이드:
  - description에 `Triggers: ...` 자동 생성 (자산 title에서 빈도 기반 5개 후보 추출)
  - body 구조화: §1 가이드라인 (LLM finalize) / §2 타입별 자산 섹션 (Failures/Patterns/Guardrails/Decisions/Snippets) / §3 메타데이터
  - `references/source-assets.jsonl` 트레이서빌리티 보존
  - 자산 메타 필드 노출: level / confidence / stability / resolved
- `scripts/query-assets.sh --format inject` 출력에 RCA 컨텍스트 포함:
  - guardrail은 `[guardrail/soft]`, decision은 `[decision/medium]`, pattern은 `[pattern/s1]`로 type 머리에 메타 노출
  - 각 자산에 `context:` 라인 추가, failure는 `resolved:` 표시

### Added
- `scripts/promote-pending.sh` — pending JSONL을 `(tool, first_error_line)` 키로 deduplicate 후 자동으로 `failure` 자산 등록. 태그: `auto`, `tool:<name>`, `session:<short>`. context에 occurrences 카운트.
- `tests/e2e_pipeline.bats` — 4개 production E2E (trigger→record, dedup, skillify quality, inject 풍부화).
- `tests/scripts_advanced.bats` +2: legacy `harnish-rag.jsonl` → `harnish-assets.jsonl` migration regression + idempotency test
- README "Memory Model" section: documents the two-tier model (Tier 1 Asset Store + Tier 2 Skills) and clarifies that only `query-assets.sh --format inject` is strict RAG

### Documentation
- README "ralph loop"의 잘못된 약자 풀이 (`Read → Act → Log → Progress`) 제거. 이름은 심슨의 Ralph Wiggum에서 유래한 것이며 약자가 아님을 명시.
- Honest framing of `skillify.sh`: it is a draft generator (asset bundling + TODO scaffold), **not** autonomous skill graduation. Future feature flagged on roadmap.
- README/SKILL.md/thresholds.md path references updated to `harnish-assets.jsonl`

## [0.0.4] - 2026-04-27

### Fixed
- `check-thresholds.sh` W1: `--threshold` flag now parsed correctly regardless of argument order; `--base-dir` first no longer silently corrupts the threshold value
- `compress-assets.sh` C1: compressed summary body no longer contains `TODO` placeholder — titles are extracted before source records are marked compressed
- `skills/impl/references/schema.json` L0 Contract: `script_io` entries for 6 scripts updated to match actual CLIs (purge-assets, compress-assets, quality-gate, localize-asset, abstract-asset, skillify)
- `record-asset.sh`: duplicate slug auto-suffix (`-2`, `-3` ...) — prevents `query-assets.sh` write-back from incrementing `access_count` on unrelated records with the same title
- `loop-step.sh`: proper while-loop arg parsing — `--format json` without explicit file path now resolves correctly via `resolve_progress_file()`
- `validate-progress.sh`: added `🔵` to the valid status-emoji set — eliminates false WARNING on in-progress work files
- `compress-progress.sh`: replaced deterministic `.tmp` path with `mktemp` — eliminates concurrent-run conflict
- `detect-asset.sh`: Stop event now deletes the session pending file and prunes stale pending files older than 7 days from `/tmp`
- `migrate.sh`: keeps only the 3 most recent `.bak.*` files — prevents unbounded backup accumulation

### Added
- `tests/e2e_workflow.bats` — 9 E2E tests covering the full progress pipeline: `init-assets → validate-progress → loop-step → compress-progress → progress-report → check-violations`
- `tests/e2e_assets.bats` — 11 E2E tests covering the full asset lifecycle: `record(6 types) → query → check-thresholds → compress-assets → quality-gate → migrate → purge`
- `tests/scripts_advanced.bats` +5: `purge --execute`, `loop-step --format without path`, `detect-asset meaningful error → pending`, `detect-asset Stop → pending deleted`
- `scripts/skillify.sh`: `--output-dir` flag for configurable skill output directory

## [0.0.3] - 2026-04-23

### Fixed
- impl skill: Mid-loop interruption guard — explicit prose prohibition on stopping outside milestone HITL, 3-failure escalation, or hard-guardrail violation (see docs/prd-impl-midloop-guard.md)

## [0.0.2] - 2026-04-22

### Added
- Test suite + GitHub Actions CI — 25 bats tests (manifest schema + script smoke + sandboxing) and a deep tier wrapping `scripts/test-all.sh`. Matrix runs on `ubuntu-latest` + `macos-latest`.
- Self-name triggers on every skill description — `"forki"`, `"impl"`, `"harnish"` (and variants), `"drafti-architect"`, `"drafti"`, `"drafti-feature"` are now first-class triggers, so natural-language calls auto-invoke without the slash form.

### Changed
- **BREAKING:** Main implementation skill renamed `harnish` → `impl` (`/harnish:harnish` → `/harnish:impl`). The "harnish" engine concept is preserved — `impl` keeps `"harnish"`, `"harnish 시작"`, `"harnish 돌려"`, `"harnish 이어서"` in its trigger list, so existing natural-language calls keep working.
- `scripts/test-all.sh` — dropped obsolete `har-*` shortcut parity section (those skills were removed in v0.0.1 cycle); SKILL version check now derives the expected version from `plugin.json` instead of hard-coding it (no more drift on bumps).
- `scripts/test-all.sh` — brace-wrapped variable refs adjacent to Korean characters (`${var}개` instead of `$var개`) to fix CI macOS bash 3.2 + C locale parsing under `set -u`.
- `scripts/common.sh` — `resolve_skill_dir()` now points to `skills/impl`.

## [0.0.1] - 2026-04-22

First public release. 5 skills + shared script suite + asset infrastructure + auto-registered hooks.

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

[Unreleased]: https://github.com/jazz1x/harnish/compare/v0.0.5...HEAD
[0.0.5]: https://github.com/jazz1x/harnish/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/jazz1x/harnish/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/jazz1x/harnish/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/jazz1x/harnish/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/jazz1x/harnish/releases/tag/v0.0.1
