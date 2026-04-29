# harnish

> Claude Code 플러그인 — 자율 구현 엔진

![version](https://img.shields.io/badge/version-0.1.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![claude-code](https://img.shields.io/badge/claude--code-plugin-purple)
![tests](https://img.shields.io/badge/tests-123%20passing-brightgreen)
![python](https://img.shields.io/badge/python-3.14%2B-blue)

**harnish** (harness + ish) = "대충 하네스 비스무리한 것" — 작업할수록 똑똑해지는 구현 환경. 실패가 가드레일이 되고, 패턴이 축적되며, 세션과 워크트리가 바뀌어도 맥락이 유실되지 않는다.

[English](./README.md)

## Skills

| Skill | Command | Role |
|-------|---------|------|
| **forki** | `/harnish:forki` | 의사결정 강제 (2지선택 + D/E/V/R + trade-off, HITL 전용) |
| **drafti-feature** | `/harnish:drafti-feature` | 기획 기반 구현 명세 PRD 생성 |
| **drafti-architect** | `/harnish:drafti-architect` | 기술 주도 설계 PRD 생성 |
| **impl** | `/harnish:impl` | 자율 구현 엔진 — "harnish" 엔진 (시딩 + ralph 루프 + 앵커링 + 경험축적) |
| **ralphi** | `/harnish:ralphi` | 점검 (HITL 보고 또는 자율 수정) |

각 스킬은 **독립 궤도**에서 동작하며, 오직 **공유 아티팩트(파일)** 로만 연결된다.

```
forki   ──→  2지선택 강제 (D/E/V/R + trade-off, HITL 전용)
                ↓
drafti  ──→  docs/prd-*.md  ──→  harnish  ──→  구현 코드
                                     │
                                     └── .harnish/ (작업 좌표 + 경험 축적, 사용자 프로젝트 CWD)

ralphi  ──→  어떤 아티팩트든 점검 (PRD, SKILL.md, 스크립트, 코드)
              HITL(보고→대기) 또는 자율(즉시 수정)
```

## 요구 사항

- **Python 3.14+** — 모든 `scripts/*.sh` 의 런타임 (1-line wrapper로 `scripts/harnish_py/` 에 위임; `sys.version_info < (3, 14)` 가드가 하위 버전에서 exit 4 로 거부).
- **Claude Code** — 플러그인 호스트.
- **`jq` 의존성 없음** (v0.1.0 부터).

## 설치

### 1. 마켓플레이스 등록

Claude Code 세션 안에서 실행:

```
/plugin marketplace add https://github.com/jazz1x/harnish.git
```

예상 출력:

```
✓ Marketplace 'harnish' added (1 plugin)
```

### 2. 플러그인 설치

```
/plugin install harnish
```

예상 출력:

```
✓ Installed harnish@0.1.0 — 5 skills registered (forki, drafti-feature, drafti-architect, impl, ralphi)
```

### 3. 확인

```
/plugin list
```

목록에 `harnish` 가 보이면 성공. 아래 슬래시 명령들이 호출 가능해야 함:

```
/harnish:forki
/harnish:drafti-feature
/harnish:drafti-architect
/harnish:impl
/harnish:ralphi
```

### 4. 훅 (자동 등록)

harnish 의 훅은 `hooks/hooks.json` 에 정의되어 있고, 플러그인 로더가 설치 시 자동으로 인식한다. **별도 설정 불필요** — 각 훅의 역할은 아래 [Hooks](#hooks) 섹션 참고.

### 5. 제거

```
/plugin uninstall harnish
/plugin marketplace remove harnish
```

프로젝트 안의 `.harnish/` 디렉토리는 자동으로 제거되지 **않음** — 축적된 자산을 완전히 지우려면 수동으로 삭제.

---

## 빠른 시작

설치 후 가장 빠른 end-to-end 경로:

```
# Claude Code 세션 안, PRD 또는 기획 문서가 있는 프로젝트에서
/harnish:impl
```

예시 흐름:

```
user > /harnish:impl docs/prd-redis-cache.md
       → 3 phase, 12개 원자적 태스크가 .harnish/harnish-current-work.json 에 시딩됨
user > loop
       → task 1.1 → 코드 → 기록 → 자산 등록 → 1.2 자동 진행 → … → Phase 1 완료
       → 마일스톤 보고 → Phase 2 계속? (y/n)
```

PRD 경로나 작업 설명 없이 호출하면 harnish 가 먼저 묻는다:

```
무엇을 구현할까요? PRD 파일 경로나 작업 내용을 알려주세요.
```

새 세션에서 "이어서 진행" 만 입력하면 → `harnish-current-work.json` 에서 좌표를 복원해 중단 지점부터 재개한다.

## Usage

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
사용자: "이 기획서로 PRD 만들어" (기획 문서 첨부)
→ drafti-feature가 구현 명세 PRD 생성 (피쳐플래그는 필요 시만)
→ docs/prd-user-profile-edit.md 생성

사용자: "Redis 캐시 레이어 설계해줘"
→ drafti-architect가 설계 대안 2~3개 탐색, 트레이드오프 분석
→ docs/prd-redis-cache.md 생성
```

### 2. 자율 구현 (harnish)

```
사용자: /harnish:impl
→ "무엇을 구현할까요? PRD 파일 경로나 작업 내용을 알려주세요."

사용자: "구현 시작" 또는 "태스크 분해"
→ PRD를 원자적 태스크로 분해 → harnish-current-work.json 생성
→ "Phase 3개, Task 12개 시딩 완료 — 확인 후 '루프 돌려'"

사용자: "루프 돌려"
→ ralph 루프가 한 태스크씩 자동 실행 (Phase 끝까지 반복)
  ("ralph"는 심슨의 랄프 위검에서 따온 이름 — 약자 풀이 아님)
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
→ 압축된 자산을 SKILL.md scaffold로 묶음 (원본 자산 본문 + TODO 마커).
  본문은 LLM이 마무리해야 함 — draft generator일 뿐 자율 graduating은
  아니다. 진짜 자율 승격은 향후 기능.
```

## Hooks

harnish 의 훅은 `hooks/hooks.json` 으로 설치 시 자동 등록된다. 별도 설정 불필요.

| Event | Trigger | What it does |
|-------|---------|--------------|
| `PostToolUse` | Bash, Edit, Write, NotebookEdit | 툴 결과에서 실패 패턴·가드레일·재사용 스니펫 감지 → `.harnish/` 에 자산으로 기록 |
| `PostToolUseFailure` | Bash, Edit, Write, NotebookEdit | 의미 있는 실패 컨텍스트 캡처 (노이즈 패턴 필터링) → failure 자산으로 기록 |
| `Stop` | 세션 종료 | 누적 자산 품질 게이트 + 임계치 확인, 세션 pending 파일 정리 |

실패는 신호/노이즈로 분류된다 — 단순 에러(`No such file`, `permission denied`, `command not found` 등)는 필터되고 의미 있는 실패만 자산이 된다.

## Memory Model

harnish는 **2단 기억 구조** (two-tier memory)로 동작한다. 각 tier의 역할이 다르며, 둘을 잇는 다리는 현재 반자동 상태.

| Tier | 저장 위치 | 수명 | 역할 | 로딩 방식 |
|------|----------|------|------|----------|
| **Tier 1 — Asset Store** (episodic) | `.harnish/harnish-assets.jsonl` | 프로젝트별, 세션 간 누적, TTL purge | 일어난 일을 기록 (failure, pattern, guardrail, snippet, decision) | `query-assets.sh --format inject` 로 컨텍스트 주입 (실제 RAG 경로) |
| **Tier 2 — Skills** (procedural) | `skills/*/SKILL.md` | 영구 (소스 트리 버전 관리) | 안정화된 행동 양식 | Claude Code가 자동 로드, 트리거 시 발동 |

`skillify.sh`가 그 다리 — 압축된 Tier-1 자산을 Tier-2 SKILL.md scaffold로 묶는다. scaffold는 **production-grade** (v0.0.5 도입, v0.1.0에서 Python으로 재구현):

- frontmatter `Triggers:` 가 자산 title에서 자동 추출됨
- body는 자산 타입별 섹션 + 메타 (level / confidence / stability / resolved)
- `references/source-assets.jsonl` 로 원본 트레이서빌리티 보존
- §1은 여전히 LLM finalize 필요 (1-3개 가이드라인 도출) — draft generator일 뿐, 자율 graduating 아님

**Trigger → Record → Skillify 파이프라인** (v0.0.5에서 닫힘, v0.1.0에서 Python 구현 — `.sh` 는 1-line wrapper):

```
PostToolUseFailure  →  detect-asset.sh (노이즈 필터)  →  /tmp/harnish-pending-*.jsonl
Stop                →  promote-pending.sh (dedup)    →  harnish-assets.jsonl
"스킬로 만들어"      →  skillify.sh                   →  SKILL.md draft + references/
```

> **왜 "RAG"가 아니라 "assets"인가?** 엄밀한 의미의 RAG는 `query-assets.sh --format inject` 한 경로뿐. 나머지는 캡처 / 요약 / 노화 / 스킬 초안 공급 — 즉 자산 CRUD + 라이프사이클.

## Assets

모든 학습 결과는 `.harnish/harnish-assets.jsonl` 에 한 줄당 한 JSON 객체로 기록된다. 6가지 자산 타입:

| Type | 기록 시점 |
|------|---------|
| `failure` | 의미 있는 도구 실패 발생 (신호 필터 통과) |
| `pattern` | 사용자가 "이 패턴 기억해" 라고 했거나 반복 성공 구조 감지 |
| `guardrail` | 반복 실패에서 규칙이 도출됐을 때 (예: "503 시 항상 backoff 재시도") |
| `snippet` | 그대로 인용할 가치가 있는 재사용 코드 조각 |
| `decision` | 이후로 가져갈 만한 forki 결과 |
| `compressed` | 관련 자산 여러 개를 하나로 머지 (임계치 도달 시 자동 제안) |

자산 조회 / 관리:

```bash
bash scripts/check-thresholds.sh [--threshold N]              # 현재 자산 수 vs 압축 임계치
bash scripts/query-assets.sh --tags api,retry --format text   # 태그로 조회
bash scripts/compress-assets.sh --dry-run --all               # 압축 dry-run
bash scripts/quality-gate.sh                                  # Stop 이벤트 품질 게이트 재실행
bash scripts/purge-assets.sh                                  # dry-run purge (--execute로 실제 적용)
bash scripts/migrate.sh                                       # 스키마 최신 버전으로 백필
```

`.harnish/` 는 프로젝트 CWD 안에 위치하며 세션 간 유지된다. `impl`, `drafti-feature`, `drafti-architect` 가 각 스킬의 Step 2에서 태그 기반으로 관련 자산을 자동 참조한다.

## 워크트리

워크트리마다 CWD 기준으로 독립된 `.harnish/` 디렉토리가 생성된다. 작업 좌표와 경험 자산 모두 워크트리별로 완전 격리되어, 공유 상태나 쓰기 충돌이 없다.

```
/project/.harnish/                      ← 메인 트리
/project/.claude/worktrees/A/.harnish/  ← 워크트리 A
/other/path/worktree-B/.harnish/        ← 워크트리 B (물리적 분리)
```

## Fork & Customize

이 리포를 베이스로 쓰는 3가지 방법:

### A. 스킬 하나만 프로젝트에 직접 복사

```bash
mkdir -p .claude/skills
cp -r /path/to/harnish/skills/forki .claude/skills/
```

해당 스킬이 `forki` 로 호출 가능 (플러그인 네임스페이스 없음). `forki` 대신 `impl`, `ralphi`, `drafti-feature`, `drafti-architect` 중 어느 것도 가능.

### B. 자체 플러그인 마켓으로 포크

```bash
gh repo fork jazz1x/harnish --clone
cd harnish
# .claude-plugin/plugin.json 편집 (name, author, repository)
# .claude-plugin/marketplace.json 편집 (owner, plugin entries)
# skills/ 아래 스킬 추가/제거/수정
git commit -am "fork: rebrand"
git push
```

### C. 읽기 전용 upstream 으로 사용

```bash
git clone https://github.com/jazz1x/harnish.git
cd your-project
claude --plugin-dir /path/to/harnish
git -C /path/to/harnish pull   # 업데이트
```

## Naming

- **harnish** = harness + ish (자율 구현 엔진)
- **ralphi** = ralph + i (점검)
  - 유래: 심슨 가족의 캐릭터 '랄프 위검'처럼 포기하지 않고 끈질기게 시도한다는 의미
- **drafti** = draft + i (PRD 생성 — drafti-feature + drafti-architect)
- **forki** = fork + i (의사결정 강제 — 2지선택 + D/E/V/R + trade-off, HITL 전용)

## Triad

harnish 는 sibling 플러그인 두 개와 한 묶음을 이룬다 — 독립적이되 공유 아티팩트로만 연결:

```
harnish (make)  ──→  honne (know)  ──→  galmuri (keep)
  실행              성찰                갈무리
```

- [harnish](https://github.com/jazz1x/harnish) — 자율 구현 엔진
- [honne](https://github.com/jazz1x/honne) — 증거 기반 자기 성찰 (6축 persona)
- [galmuri](https://github.com/jazz1x/galmuri) — 요약 · 의사결정 덱 · 문서화

## Footnote

> *"`ralphi`가 이미 하는 일이라면, 새 스킬은 노이즈일 뿐이다 —
> distill은 자기 자신의 첫 희생자가 된다."*

`distill`이라는 스킬이 제안됐고, 자신이 내세운 원리에 의해 지워졌다.
그게 바로 ralphi가 작동한 순간이었다.

## License

MIT — [LICENSE](./LICENSE) 참조.
