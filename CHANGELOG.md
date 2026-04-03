# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- 플러그인 매니페스트 (`.claude-plugin/plugin.json`) — `claude plugin add github:jazz1x/harnish`로 설치 가능
- ralph: HITL + 자율 수정 모드 (발화 기반 판별: "점검해"→HITL, "고쳐"→자율)
- ralph: `criteria-project.md` 추가 (프로젝트/디렉토리 스코프 점검 기준)
- `.harnish/` 통합 마이그레이션 PRD (`docs/prd-harnish-dir-migration.md`)

### Changed
- 전체 SKILL.md 저수준 모델 대응 압축 (1,208줄→587줄, -51%)
  - harnish: Step 선형화, ASCII 다이어그램 제거 (387→213줄)
  - drafti-architect: Mermaid 제거, 3중 반복 통합 (294→131줄)
  - drafti-feature: 피쳐플래그 필수→선택 전환 (308→148줄)
  - ralph: Step 선형화, criteria 파일명 직접 매핑 (219→95줄)
- drafti-feature: 피쳐플래그를 모든 기능에 강제하지 않고 조건부 적용
- ralph: `criteria-script.md` 크로스플랫폼 호환성 주의 목록 현실화
- `test-all.sh`: 스킬 카운트 동적화, references 존재 검증 추가

## [0.0.1] - 2026-03-31

First release. 4 skills + 16 shared scripts + asset infrastructure.

### Added

#### drafti-architect `0.0.1`
- 기술 주도 설계 PRD 생성 스킬
- 10단계 체크리스트 기반 순차 실행
- 설계 대안 2~3개 + 트레이드오프 매트릭스
- HARNISH_ROOT 감지: 모노리포/독립 모드 자동 판별
- references: design-decision.md, prd-template.md

#### drafti-feature `0.0.1`
- 기획 요구사항 기반 피쳐 PRD 생성 스킬
- 피쳐플래그 설계 (boolean/percentage/segment + 킬스위치)
- 언어 비종속 코드베이스 탐색 (§4 Step 0 언어 감지)
- HARNISH_ROOT 감지: 모노리포/독립 모드 자동 판별
- references: feature-flag-patterns.md, prd-template.md

#### harnish `0.0.1`
- 자율 구현 엔진 (시딩 + RALP 루프 + 앵커링 + 경험 축적)
- 모드 A: PRD → 원자적 태스크 분해 → PROGRESS.json 생성
- 모드 B: RALP 루프 (Read → Act → Log → Progress → repeat)
- 모드 C: 세션 복원 (앵커링) + 자산 감지/기록/압축/스킬화
- §B.9 acceptance_criteria 실행: bash/조건/혼합/없음 4가지 분기
- 다언어 타입 체커 (Python/TS/Go/Java/Rust)
- references: task-schema.md, progress-template.md, escalation-protocol.md, guardrail-levels.md, thresholds.md

#### ralph `0.0.1`
- 아티팩트 정합성 검증 스킬 (자가검증 + 자가수정 루프, 최대 7회)
- 4개 아티팩트 타입: PRD, SKILL.md, 스크립트, 코드
- criteria-code.md: 9개 언어 도구 매핑 테이블
- references: criteria-code.md, criteria-prd.md, criteria-skill.md, criteria-script.md

#### Shared scripts (16)
- validate-progress.sh, loop-step.sh, compress-progress.sh, check-violations.sh
- query-assets.sh, record-asset.sh, detect-asset.sh, init-assets.sh
- compress-assets.sh, check-thresholds.sh, quality-gate.sh, skillify.sh
- abstract-asset.sh, localize-asset.sh, common.sh, pre-commit.sh
- POSIX 호환 (macOS BSD grep 대응, GNU 전용 플래그 미사용)

#### Infrastructure
- Claude Code hooks (PostToolUse → detect-asset.sh)
- Git pre-commit hook (shellcheck, JSON 검증, SKILL.md frontmatter 검증)
- _base/assets/ 자산 저장소 구조

[Unreleased]: https://github.com/jazz1x/harnish/compare/v0.0.1...HEAD
[0.0.1]: https://github.com/jazz1x/harnish/releases/tag/v0.0.1
