# Project Inspection Criteria

> Criteria referenced by ralph when operating in directory scope.
> Targets files within the scope specified by the user.

## 0. Inspection Order

```
1. Run tests (before reading code)
2. Test failure analysis
3. Changed code scenario walkthrough
4. Coverage gap exploration
5. Cross-platform compatibility
```

Tests must run first. Failures are the most accurate guide.

## 1. Test Failure Analysis

Run tests → if FAILs exist:

- Extract **file:line** from failure messages
- Read only the **function/block** at that point (not the entire file)
- Identify root cause in one line

## 2. Intent vs Implementation (Hypothetical Scenarios)

Mentally execute the diff of each changed file:

- **Happy path**: expected input → trace each branch → does it reach expected output?
- **Edge path**: empty values, special characters, large input → does defensive code catch it?
- **Error path**: external failure (file not found, network error) → is it properly handled?

Report as issue if behavior differs from intent.

## 3. Coverage Gaps

Find paths in changed code that have no tests.

Priority:

1. **Error branches** — exit 1, throw, return error with no test
2. **Platform branches** — OS-specific conditionals (`uname`, `OSTYPE`) where only one side is tested
3. **Input boundaries** — empty values, special characters, boundary value tests missing
4. **New options/modes** — flags added but not tested

How to find: extract branch statements (`if`, `case`, `||`, `&&`, `try/catch`) from diff.
→ Is there a corresponding test?

## 4. Cross-Platform Compatibility

When shell scripts are included in the changes:

- `date -d` (GNU only) → does it work on macOS?
- `sed -i ''` (BSD only) → does it work on Linux?
- `grep -P` (Perl regex) → can it be replaced with POSIX `grep -E`?
- `readarray`/`mapfile` → replaced with `while read` loop?

## 5. Read Scope Limitation

- Do not read unchanged files
- Do not read entire files — diff and relevant function/block only
- Project structure, README, config files are assumed to be already known
- Do not read entire test files either — only the relevant test cases
