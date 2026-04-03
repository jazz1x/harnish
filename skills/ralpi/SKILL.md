---
name: ralpi
version: 0.0.1
description: >
  Inspection skill. Triggers: "점검해", "확인해", "검증해", "ralpi",
  "셀프점검", "커버리지 확인", "테스트 갭",
  "고쳐", "수정해", "점검하고 고쳐", "자동으로 처리해",
  "inspect", "check", "verify", "self-check",
  "coverage check", "test gap",
  "fix", "repair", "inspect and fix", "handle automatically"
---

# ralpi — Inspection

## Step 1: Mode Determination

Utterance contains "고쳐", "수정해", "fix", "처리해" → **Autonomous** (proceeds to fix)
Otherwise → **HITL** (report only and wait)

## Step 2: Scope Determination

- File path given → **File scope** → Step 3A
- Directory given → **Directory scope** → Step 3B
- Nothing given → **Ask the user for scope. No guessing.** Do not run git diff on your own.

## Step 3A: File Inspection

1. Detect type → determine criteria file:
   - `docs/prd-*.md` (check §section structure) → `criteria-prd.md`
   - `*/SKILL.md` (check frontmatter name:) → `criteria-skill.md`
   - `*.sh` (check shebang #!/) → `criteria-script.md`
   - `.py .ts .js .go` etc. source code → `criteria-code.md`
   - Unclear → **Ask the user. No guessing.**
2. Load only **1** criteria from `references/`. Do not read other criteria.
3. Static analysis (structure, format, contract violations)
4. Dynamic execution (if script/code)
5. → Proceed to Step 4

## Step 3B: Project/Directory Inspection

1. Run tests. Tests before reading code. If test runner is unknown, **ask the user. No guessing.** Tool not installed (command not found) → SKIP that check + warn. **Do not attempt installation.**
2. List changed files (git diff)
3. Analyze **only the diff** of each file. **Do not read entire files.**
4. Scenario walkthrough (intent vs implementation). Read only the relevant function. No call graph tracing.
5. Coverage gap exploration
6. → Proceed to Step 4

## Step 4: Mode Branch

### HITL Case

Report in Step 5 format → wait for user judgment.

#### User Response Interpretation Rules

Clear instructions (execute immediately):
- "Fix #1" → fix that issue only → test → report.
- "Fix 1, 3" → fix those issues sequentially, test after each.
- "Fix all" → fix all sequentially, test after each.
- "Ignore" / "Skip" → record the issue and end.

Ambiguous responses (must re-ask):
- "Yeah", "Got it", "Sure", "OK" → **Do not interpret as permission to fix.**
  → Re-ask: "Which issues should I fix? Specify numbers or say 'fix all'."
- Response unrelated to issues → re-ask.

### Autonomous Case

Fix immediately in critical→warning→coverage order → test after each fix → report results in Step 5 format when all done.
- Test FAIL → rollback that fix, unfixed "test failure"
- Intent unclear (code deletion, logic change) → unfixed "intent unclear"
- Structural change needed (file move, interface change) → unfixed "structural change needed"

If there are unfixed items, hand off to user judgment.

## Step 5: Report

Severity: `critical` (behavioral error) / `warning` (potential issue) / `coverage` (test gap)

HITL:
```
## ralpi Inspection Results
Target: {path | "user-specified scope"}
### Findings ({N} items)
1. [{severity}] {file:line} — {one-line cause}
Which issues should I fix first?
```

Autonomous:
```
## ralpi Inspection + Fix Results
Target: {path | "user-specified scope"}
### Fixed ({M}/{N} items)
1. [fixed] {file:line} — {one-line fix description}
### Unfixed ({K} items) ← only when present
1. [{severity}] {file:line} — {cause} → {reason unfixed}
Tests: {PASS | FAIL (details)}
```

No issues found → `ralpi inspection complete, no issues found.` Single line. No enumeration.

## Prohibited

- Reading unchanged files
- Loading 2 or more criteria simultaneously
- Fixing without instructions in HITL mode
- Reading entire files in project scope (diff only)
- "FYI..." style supplementary information
- Verbose reports
