# Script Verification Criteria

> Detailed criteria referenced by ralphi when verifying shell scripts.

## Required Elements

- shebang: `#!/usr/bin/env bash`
- `set -euo pipefail` or equivalent error handling
- Print usage when run without arguments

## Cross-Platform Compatibility

Target bash 3.2+. Must work on both macOS (BSD) and Linux (GNU).

**Platform-specific difference checklist:**

| Command | GNU (Linux) | BSD (macOS) | Recommended |
|---------|------------|-------------|-------------|
| `date` relative time | `date -d "2024-01-01"` | Not supported | `python3 -c` or fallback branch |
| `sed -i` | `sed -i 's/...'` | `sed -i '' 's/...'` | Detect platform then branch, or temp file + mv |
| `grep -P` | Perl regex supported | Not supported | Use `grep -E` |
| `readarray`/`mapfile` | bash 4+ | Not in bash 3.2 | `while IFS= read -r` loop |
| `paste -sd,` | Works | Works | Pass `-d` and delimiter as separate args: `paste -s -d , -` |

**Verification methods:**
- When `date -d` is used → is there a fallback like `|| echo "0"`?
- When `sed -i` is used → is there platform branching?
- `grep -P` → can it be replaced with `grep -E`?

## Output Format

Must be parsable by consumers (SKILL.md or other scripts):
- JSON (`--format json`)
- Text (`--format text`)
- Injection (`--format inject`)
