# harnish

> Claude Code skill-based autonomous implementation engine

**harnish** (harness + ish) = "대충 하네스 비스무리한 것"

작업할수록 똑똑해지는 구현 환경. 실패가 가드레일이 되고, 패턴이 축적되며, 세션이 바뀌어도 맥락이 유실되지 않는다.

## Pipeline

```
drafti (설계) → harnish (분해) → ralphi (실행)
```

| Skill | Command | Role |
|-------|---------|------|
| **drafti-architect** | `/drafti-architect` | 기술 주도 설계 PRD 생성 |
| **drafti-feature** | `/drafti-feature` | 기획 기반 명세 PRD 생성 |
| **harnish** | `/harnish` | PRD를 태스크로 분해 + 오케스트레이션 |
| **ralphi** | `/ralphi` | 자율 실행 루프 (Read → Act → Log → Progress) |

## Structure

```
harnish/
├── skills/
│   ├── drafti-architect/     # 기술 설계 PRD
│   ├── drafti-feature/       # 기획 명세 PRD
│   ├── harnish/              # 오케스트레이터 (seeding / anchor / experience)
│   └── ralphi/               # 자율 실행 루프
├── hooks/hooks.json          # Claude Code hooks
├── scripts/                  # 공용 스크립트
└── _base/assets/             # 공유 자산 저장소
```

## Install

```bash
# sh (plugin)
claude plugin install https://github.com/plz-salad-not-here/harnish

# mcpmarket
# drafti-architect, drafti-feature, harnish, ralphi 개별 설치
```

## Development

```bash
git clone https://github.com/plz-salad-not-here/harnish.git
cd harnish
git config core.hooksPath .githooks
```

Pre-commit hook이 자동으로 검증합니다:
- `shellcheck` — shell script lint
- JSON syntax — `hooks.json` 등
- SKILL.md frontmatter — `name`, `description` 필수 필드
- Script permissions — `.sh` 파일 실행 권한

## Naming

- **harnish** = harness + ish
- **ralphi** = RALP (Recursive Autonomous Loop Process) + i
- **drafti** = draft + i (drafti-architect + drafti-feature의 프리픽스)

## License

MIT
