# harnish

> Claude Code plugin — autonomous implementation engine

**harnish** (harness + ish) = "대충 하네스 비스무리한 것"

작업할수록 똑똑해지는 구현 환경. 실패가 가드레일이 되고, 패턴이 축적되며, 세션이 바뀌어도 맥락이 유실되지 않는다.

[English](./README.md)

## 설치

Claude Code 실행 후:

```
/plugin marketplace add https://github.com/jazz1x/harnish.git
/plugin install harnish
```

## Skills

| Skill | Command | Shortcut | Role |
|-------|---------|----------|------|
| **forki** | `/harnish:forki` | `/har-fork` | 의사결정 강제 (2지선택 + D/E/V/R + trade-off, HITL 전용) |
| **drafti-architect** | `/harnish:drafti-architect` | `/har-arch` | 기술 주도 설계 PRD 생성 |
| **drafti-feature** | `/harnish:drafti-feature` | `/har-feat` | 기획 기반 구현 명세 PRD 생성 |
| **harnish** | `/harnish:harnish` | `/har-ship` | 자율 구현 엔진 (시딩 + ralph 루프 + 앵커링 + 경험축적) |
| **ralphi** | `/harnish:ralphi` | `/har-scan` | 점검 (HITL 보고 또는 자율 수정) |

각 스킬은 **독립 궤도**에서 동작하며, **공유 아티팩트(파일)**로만 연결된다.

```
forki   ──→  2지선택 강제 (D/E/V/R + trade-off, HITL 전용)
                ↓
drafti  ──→  docs/prd-*.md  ──→  harnish  ──→  구현 코드
                                     │
                                     └── .harnish/ (작업 좌표 + 경험 축적, 사용자 프로젝트 CWD)

ralphi  ──→  어떤 아티팩트든 점검 (PRD, SKILL.md, 스크립트, 코드)
              HITL(보고→대기) 또는 자율(즉시 수정)
```

## 사용법

### 0. 의사결정 강제 (forki)

```
사용자: /harnish:forki
→ "어떤 결정이 필요한가요? 고민 중인 상황을 설명해주세요."

사용자: "Postgres와 MongoDB 중 뭐 써야 하지?"
→ forki가 2지선택으로 정리 → A/B 사용자 확정
→ D/E/V/R 표 8칸 사용자에게 채우라고 요청
→ trade-off 도출 → 최종 선택은 사용자 (LLM은 결정 못 함)
→ 선택의 구조적 이유 출력
```

### 1. PRD 생성 (설계)

```
사용자: "Redis 캐시 레이어 설계해줘"
→ drafti-architect가 설계 대안 2~3개 탐색, 트레이드오프 분석
→ docs/prd-redis-cache.md 생성

사용자: "이 기획서로 PRD 만들어" (기획 문서 첨부)
→ drafti-feature가 구현 명세 PRD 생성 (피쳐플래그는 필요 시만)
→ docs/prd-user-profile-edit.md 생성
```

### 2. 자율 구현 (harnish)

```
사용자: /harnish:harnish
→ "무엇을 구현할까요? PRD 파일 경로나 작업 내용을 알려주세요."

사용자: "구현 시작" 또는 "태스크 분해"
→ PRD를 원자적 태스크로 분해 → harnish-current-work.json 생성
→ "Phase 3개, Task 12개 시딩 완료 — 확인 후 '루프 돌려'"

사용자: "루프 돌려"
→ ralph 루프 자동 실행 (Read → Act → Log → Progress → repeat)
→ 매 3액션마다 harnish-current-work.json 갱신, Phase 완료 시 마일스톤 보고

사용자: (새 세션에서) "이어서 진행"
→ harnish-current-work.json에서 좌표 복원, 중단 지점부터 자동 재개
```

### 3. 점검 (ralphi)

```
사용자: "이 PRD 점검해"
→ 타입 감지 (PRD) → 정적 분석 → 이슈 보고 → 사용자 판단 대기 (HITL)

사용자: "src/cache.py 점검하고 고쳐"
→ 타입 감지 (코드) → 분석 → 즉시 수정 → 결과 보고 (자율)
→ 테스트 FAIL 시 롤백, 의도 불명확 시 미수정 분류
```

### 4. 경험 축적

```
사용자: "이 패턴 기억해"
→ pattern 자산으로 기록 → 이후 작업에서 자동 참조

사용자: "자산 현황"
→ 축적된 failure/pattern/guardrail/snippet/decision 현황 조회

사용자: "스킬로 만들어"
→ 압축된 자산에서 재사용 가능한 SKILL.md 초안 생성
```

## Hooks

설치 시 자동으로 등록되는 훅 목록. 별도 설정 불필요.

| 이벤트 | 트리거 | 동작 |
|--------|--------|------|
| `PostToolUse` | Bash, Edit, Write, NotebookEdit | 툴 결과에서 실패 패턴·가드레일·재사용 스니펫 감지 → `.harnish/`에 자산으로 기록 |
| `PostToolUseFailure` | Bash, Edit, Write, NotebookEdit | 실패 컨텍스트 캡처 → failure 자산으로 기록, 향후 유사 작업 시 참조 |
| `Stop` | 세션 종료 | 누적 자산 품질 게이트 + 임계치 확인 |

자산은 프로젝트 디렉토리의 `.harnish/`에 누적되며 세션 간 유지됩니다. `harnish`, `drafti-architect`, `drafti-feature` 스킬이 관련 자산을 자동으로 참조합니다.

## Fork & 커스터마이즈

이 리포를 가져다 쓰는 3가지 방법:

### A. 단일 스킬만 프로젝트에 가져오기

플러그인 설치 없이 스킬 하나만 직접 복사.

```bash
mkdir -p .claude/skills
cp -r /path/to/harnish/skills/forki .claude/skills/
```

해당 스킬이 이 프로젝트에서 `forki`로 사용 가능 (플러그인 네임스페이스 없음).
`forki` 대신 `harnish`, `ralphi`, `drafti-architect`, `drafti-feature` 중 어느 것도 가능.

### B. 자기만의 플러그인 마켓플레이스로 fork

```bash
gh repo fork jazz1x/harnish --clone
cd harnish
# .claude-plugin/plugin.json 수정 (name, author, repository)
# .claude-plugin/marketplace.json 수정 (owner, plugin entries)
# skills/ 아래 스킬 추가/제거/수정
git commit -am "fork: rebrand"
git push
```

### C. 이 리포를 read-only upstream으로 사용

```bash
git clone https://github.com/jazz1x/harnish.git
cd your-project
claude --plugin-dir /path/to/harnish
git -C /path/to/harnish pull   # 나중에 업데이트
```

Fork 불필요. 업데이트는 pull로.

## 워크트리

워크트리마다 CWD 기준으로 독립된 `.harnish/` 디렉토리가 생성됩니다. 작업 좌표와 경험 자산 모두 워크트리별로 완전 격리되어, 공유 상태나 쓰기 충돌이 없습니다.

```
/project/.harnish/                      ← 메인 트리
/project/.claude/worktrees/A/.harnish/  ← 워크트리 A
/other/path/worktree-B/.harnish/        ← 워크트리 B (물리적 분리)
```

## Naming

- **harnish** = harness + ish (자율 구현 엔진)
- **ralphi** = ralph + i (점검)
  - 유래: 심슨 가족의 캐릭터 '랄프 위검'처럼 포기하지 않고 끈질기게 시도한다는 의미에서 붙여진 이름
- **drafti** = draft + i (PRD 생성 — drafti-architect + drafti-feature)
- **forki** = fork + i (의사결정 강제 — 2지선택 + D/E/V/R + trade-off, HITL 전용)

## Footnote

> *"`ralphi`가 이미 하는 일이라면, 새 스킬은 노이즈일 뿐이다 —
> distill은 자기 자신의 첫 희생자가 된다."*

`distill`이라는 스킬이 제안됐고, 자신이 내세운 원리에 의해 지워졌다.
그게 바로 ralphi가 작동한 순간이었다.

## License

MIT
