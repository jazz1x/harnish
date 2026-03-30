---
name: harnish
description: >
  PRD를 태스크로 분해하고 자율 구현 루프를 실행하는 오케스트레이터.
  시딩(PRD→태스크), 앵커링(세션 간 맥락 유지), 경험 축적(자산 감지·기록·압축·스킬화)의
  3개 축으로 동작한다. PROGRESS.md를 세션 간 영속 상태로 유지하여 세션이 바뀌어도
  작업 맥락을 잃지 않는다. 모든 종류의 PRD(drafti-architect/drafti-feature/수동 작성)에 대응한다.
  트리거: "구현 시작", "태스크 분해", "이 PRD로 작업해", "구현 루프 실행",
  "다음 태스크", "이어서 진행", "진행 상태", "마일스톤 보고",
  "자산 현황", "자산 압축", "이 패턴 기억해", "스킬로 만들어",
  PROGRESS.md가 존재하고 사용자가 작업 재개를 요청할 때.
---

# harnish — 자율 구현 엔진

```
drafti (설계) → harnish (분해+구현) → ralphi (실행 루프)
```

## 진입점 (START HERE)

```bash
HARNISH_ROOT="${CLAUDE_SKILL_DIR}/../.."
```

### 1. 상태 확인

- PROGRESS.md 존재? → 모드 B (구현 루프) 또는 세션 복원
- PRD만 존재? → 모드 A (시딩)
- 자산 관련 요청? → 모드 C (경험 축적)

### 2. 모드 라우팅

| 모드 | 트리거 | 읽을 reference | 동작 |
|------|--------|---------------|------|
| **A: 시딩** | "구현 시작", "태스크 분해", PRD 제공 | `references/task-schema.md` + `references/progress-template.md` | PRD → 태스크 분해 → PROGRESS.md 생성 |
| **B: 구현 루프** | "이어서 진행", "다음 태스크", PROGRESS.md 존재 | `references/escalation-protocol.md` + `references/guardrail-levels.md` | 태스크 실행 → 검증 → 다음 태스크 |
| **C: 경험** | "자산 현황", "압축", "기억해", "스킬로" | `references/thresholds.md` | 자산 기록/조회/압축/스킬화 |

**규칙**: reference는 동시에 2개까지만 로드. 모드 전환 시 새 reference로 교체.

---

## 모드 A: 시딩 (PRD → 태스크)

1. PRD 파일 경로 확인: `docs/prd-{name}.md`
2. PRD §4, §6, §7 존재 여부 확인
3. 기존 자산 조회:
   ```bash
   bash "$HARNISH_ROOT/scripts/query-assets.sh" \
     --tags "{키}" --types guardrail --format text \
     --base-dir "$HARNISH_ROOT/_base/assets"
   ```
4. 페이즈 분할: 데이터 → 비즈니스 로직 → UI → 통합 테스트
5. 원자적 태스크 분해: **1 태스크 = 1파일 | 1함수 | 1테스트 | 1설정**
6. PROGRESS.md 생성 → 검증:
   ```bash
   bash "$HARNISH_ROOT/scripts/validate-progress.sh" ./PROGRESS.md
   ```
7. 사용자 검토 요청

상세: `references/task-schema.md`, `references/progress-template.md`

---

## 모드 B: 구현 루프

### 메인 루프 (Task 단위)

1. **Task 로드**: PROGRESS.md Doing/Todo에서 현재 Task
2. **자산 조회**: 이전 경험 주입 (guardrail, pattern, failure)
   ```bash
   bash "$HARNISH_ROOT/scripts/query-assets.sh" \
     --tags "{task-id},{phase}" --types guardrail,pattern,failure \
     --format inject --base-dir "$HARNISH_ROOT/_base/assets"
   ```
3. **액션 실행**: strategy 따라 target_files 수정. **매 3액션마다 PROGRESS.md 갱신**
4. **금지사항 체크**: 데이터 파괴 / 범위 이탈 / 보안 위반 / 미승인 의존성 / 무관한 리팩토링
5. **검증**: acceptance_criteria 실행
6. **분기**:
   - 통과 → Done 이동 → 다음 Task
   - 실패 1-2회 → 수정 후 재검증. 2회 실패 후 해결 시 failure 자산 기록
   - 실패 3회 → failure 자산 기록 → 에스컬레이션
7. **마일스톤**: Phase 완료 시 체크포인트 보고, 자산 압축 판단, 사용자 승인 대기

상세: `references/escalation-protocol.md`, `references/guardrail-levels.md`

### 자산 기록 (구현 중 자동)

```bash
# 2회 실패 후 해결 시
bash "$HARNISH_ROOT/scripts/record-asset.sh" \
  --type failure --tags "{task-id},{phase}" \
  --context "harnish: {Task 제목}" \
  --title "2회 실패 후 해결: {에러 요약}" \
  --content $'## 표면 증상\n{에러}\n## 실제 원인\n{원인}\n## 해결 과정\n{과정}\n## 일반화된 패턴\n{패턴}' \
  --base-dir "$HARNISH_ROOT/_base/assets"
```

### 앵커링 (세션 간 맥락 유지)

세션 시작 시:
1. `validate-progress.sh PROGRESS.md` → 구조 정상 확인
2. Doing 있으면 "다음 액션"부터 재개 / 없으면 Todo 첫 Task
3. 상태 보고 → 사용자 승인 → 계속

---

## 모드 C: 경험 축적

### 자산 유형

| 유형 | 폴더 | 감지 기준 |
|------|------|---------|
| failure | failures/ | 동일 에러 2회+ 발생 후 해결 |
| pattern | patterns/ | 첫 시도 성공 + 재사용 가능 |
| guardrail | guardrails/ | 명시적 제약 선언 또는 부작용 발견 |
| snippet | snippets/ | 동일 코드 구조 2회+ 작성 |
| decision | decisions/ | A vs B 선택 + 근거 존재 |

### 기록 판단 규칙

```
IF 동일 에러 2회+ AND 해결됨 → failure 기록 (필수)
IF 사용자 "기억해/패턴 기록" → 해당 유형 기록 (필수)
IF 사용자 "절대 ~하지 마" → guardrail 기록 (필수)
IF 첫 시도 성공 AND 범용적 → pattern 기록 (권장)
IF A vs B 선택 AND 근거 명확 → decision 기록 (권장)
IF 동일 코드 구조 2회+ → snippet 기록 (권장)
ELSE → 기록하지 않음
```

### 조회/압축/스킬화

```bash
# 조회
bash "$HARNISH_ROOT/scripts/query-assets.sh" --tags "docker,cache" --format inject --base-dir "$HARNISH_ROOT/_base/assets"

# 현황
bash "$HARNISH_ROOT/scripts/check-thresholds.sh" --base-dir "$HARNISH_ROOT/_base/assets"

# 압축 (동일 태그 5건+)
bash "$HARNISH_ROOT/scripts/compress-assets.sh" --tag docker --base-dir "$HARNISH_ROOT/_base/assets"

# 스킬 초안
bash "$HARNISH_ROOT/scripts/skillify.sh" --source "$HARNISH_ROOT/_base/assets/.compressed/{file}.md" --skill-name docker-patterns

# 품질 게이트
bash "$HARNISH_ROOT/scripts/quality-gate.sh" --base-dir "$HARNISH_ROOT/_base/assets"
```

### 수동 트리거

| 발화 | 동작 |
|------|------|
| "자산 현황" | check-thresholds.sh |
| "자산 압축" | compress-assets.sh |
| "이 패턴 기억해" | record-asset.sh (pattern) |
| "스킬로 만들어" | skillify.sh |
| "자산 품질" | quality-gate.sh |

---

## 체크포인트 규칙

- **매 3액션**: PROGRESS.md 갱신 (현재/마지막/다음)
- **Task 완료**: Doing → Done, 완료 시간, 변경 파일, 검증 결과
- **Phase 완료**: 마일스톤 보고, 자산 압축 판단, 사용자 승인
- **세션 종료**: 품질 게이트 (오늘 자산 완성도 1회 스캔)

## 종료 조건

- Todo 비어있고 Doing 비어있음 → STOP
- 사용자 "중단" → PROGRESS.md에 현재 상태 기록 후 STOP

## 맥락 예산

| 모드 | 읽는 reference | 예상 토큰 |
|------|---------------|----------|
| 시딩 | task-schema.md + progress-template.md | ~8K |
| 구현 | escalation-protocol.md + guardrail-levels.md | ~6K |
| 경험 | thresholds.md | ~3K |

동시 로드 최대 2개. 이전 reference가 컨텍스트에 남는 것은 감수.
