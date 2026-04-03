# 스크립트 검증 기준

> ralpi가 shell script를 검증할 때 참조하는 상세 기준.

## 필수 요소

- shebang: `#!/usr/bin/env bash`
- `set -euo pipefail` 또는 동등한 에러 핸들링
- 인자 없이 실행 시 usage 출력

## 크로스플랫폼 호환성

bash 3.2+ 대상. macOS(BSD)와 Linux(GNU) 모두 동작해야 한다.

**플랫폼별 차이 주의 목록:**

| 명령 | GNU (Linux) | BSD (macOS) | 권장 |
|------|------------|-------------|------|
| `date` 상대시간 | `date -d "2024-01-01"` | 지원 안 함 | `python3 -c` 또는 fallback 분기 |
| `sed -i` | `sed -i 's/...'` | `sed -i '' 's/...'` | 플랫폼 감지 후 분기, 또는 임시파일 + mv |
| `grep -P` | Perl regex 지원 | 지원 안 함 | `grep -E` 사용 |
| `readarray`/`mapfile` | bash 4+ | bash 3.2에 없음 | `while IFS= read -r` 루프 |
| `paste -sd,` | 동작 | 동작 | `-d` 와 구분자를 별도 인자로: `paste -s -d , -` |

**검증 방법:**
- `date -d` 사용 시 → `|| echo "0"` 같은 fallback이 있는가?
- `sed -i` 사용 시 → 플랫폼 분기가 있는가?
- `grep -P` → `grep -E`로 대체 가능한가?

## 출력 포맷

소비자(SKILL.md 또는 다른 스크립트)가 파싱 가능한 형태:
- JSON (`--format json`)
- 텍스트 (`--format text`)
- 주입용 (`--format inject`)
