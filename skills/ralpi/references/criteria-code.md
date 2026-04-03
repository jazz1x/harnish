# Code Verification Criteria

> Criteria referenced by ralpi when verifying implementation code.
> Does not assume the existence of other skills. Judges based solely on the given artifact.
> **Language-agnostic.** Detects language by file extension and selects the appropriate tools.

## 0. Language Detection → Tool Mapping

Detect language by file extension, then use the tools for that language.
Project config files take priority. If absent, use the default tools below.

| Extension | Language | Type Check | Lint | Test Runner | Dependency Location |
|-----------|----------|-----------|------|-------------|-------------------|
| `.py` | Python | `mypy`, `pyright` | `ruff`, `flake8` | `pytest` | `venv/`, `.venv/` |
| `.ts`, `.tsx` | TypeScript | `tsc --noEmit` | `eslint`, `biome` | `vitest`, `jest`, `npm test` | `node_modules/` |
| `.js`, `.jsx` | JavaScript | — | `eslint`, `biome` | `vitest`, `jest`, `npm test` | `node_modules/` |
| `.java` | Java | `javac` | `checkstyle`, `spotbugs` | `mvn test`, `gradle test` | `target/`, `build/` |
| `.kt`, `.kts` | Kotlin | `kotlinc` | `ktlint`, `detekt` | `gradle test` | `build/` |
| `.go` | Go | `go vet` | `golangci-lint` | `go test ./...` | `vendor/` (optional) |
| `.rs` | Rust | `cargo check` | `cargo clippy` | `cargo test` | `target/` |
| `.swift` | Swift | `swiftc` | `swiftlint` | `swift test` | `.build/` |
| `.dart` | Dart | `dart analyze` | `dart analyze` | `dart test` | `.dart_tool/` |

**Tool Selection Rules:**

1. Check project config files (`pyproject.toml`, `package.json`, `Cargo.toml`, `go.mod`, `build.gradle`, etc.)
2. Prefer tools specified in config
3. If no config, use default tools from the table above
4. If tool is not installed, SKIP that check + warn

**Test File Patterns:**

| Language | Test File Pattern |
|----------|-----------------|
| Python | `test_*.py`, `*_test.py`, `tests/` |
| TypeScript/JS | `*.test.ts`, `*.spec.ts`, `__tests__/` |
| Java | `*Test.java`, `*Tests.java`, `src/test/` |
| Kotlin | `*Test.kt`, `src/test/` |
| Go | `*_test.go` (same package) |
| Rust | `#[cfg(test)]` modules, `tests/` |
| Swift | `*Tests.swift`, `Tests/` |

## 1. Structural Completeness (Static Analysis)

### 1.1 File Quality

- Type check passes (see §0 tool mapping)
- Lint passes (see §0 tool mapping — when project config exists)
- No hardcoded secrets (grep for API key, password, token patterns)
- No magic numbers (are configurable values separated into config?)
- No dead code (unused imports, uncalled functions)

### 1.2 Error Handling

- Error handling exists for external calls (DB, API, file I/O)
  - Python: `try/except`
  - TypeScript/JavaScript/Java/Kotlin/Swift/Dart: `try/catch`
  - Go: `if err != nil`
  - Rust: `Result<T, E>` / `?` operator
- Proper response/logging on error (empty error handlers prohibited)
- Foreseeable failure paths are handled

### 1.3 Edge Cases

- null/nil/None/zero value input handling (corresponding to each language's null representation)
- Empty collection/empty string handling
- Boundary values (0, negative, maximum) handling
- Concurrency issues (when applicable)

## 2. Functional Completeness (Dynamic Execution)

### 2.1 Test Existence and Passing

- Whether corresponding test file exists (see §0 test file patterns)
- Test execution (see §0 tool mapping)
- Test coverage: core logic paths are tested

### 2.2 Actual Behavior Verification

- Can the entry point of the code be found and executed
- Is the import/require/use/from chain unbroken
- Are all dependencies installed (see §0 dependency location)

## 3. Context Cross-Reference (Optional — only when additional artifacts are provided)

Performed only when the user provides a PRD or harnish-current-work.json along with the code.
If not provided, verify with §1 and §2 only.

### 3.1 When PRD Is Provided

- Do files listed in PRD §4 actually exist
- Are PRD §6 test criteria reflected in test code
- Are PRD §7 prohibitions not violated in code

### 3.2 When harnish-current-work.json Is Provided

- Are acceptance_criteria of Tasks marked Done actually met
- Do the changed file lists match actual changes

## 4. Verification Order

```
1. §0 Language detection + tool check
2. §1.1 File quality → report issues
3. §1.2 Error handling → report issues
4. §1.3 Edge cases → report issues
5. §2.1 Test existence and passing → report on failure
6. §2.2 Actual behavior verification → report on failure
7. (When PRD/harnish-current-work.json provided) §3 Context cross-reference
8. Consolidated issue report → wait for user judgment
```
