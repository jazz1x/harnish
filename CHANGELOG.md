# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- 모드 B: ralph 루프 (Read → Act → Log → Progress → repeat)
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

[Unreleased]: https://github.com/jazz1x/harnish/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/jazz1x/harnish/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/jazz1x/harnish/releases/tag/v0.0.1
