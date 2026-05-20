# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

[한국어](./CHANGELOG.ko.md)

## [Unreleased]

## [0.3.0] - 2026-05-21

The `ralphi` inspection skill graduates out of harnish into the sibling plugin **galmuri** (`galmuri:ralphi`). harnish keeps the implementation-engine concern (forki + drafti + impl); inspection/audit moves next to galmuri's existing `audit` + `distill` skills under a shared Socratic frame. This is a public-API breaking change.

### Removed
- **`ralphi` skill** — moved to [galmuri](https://github.com/jazz1x/galmuri) as `galmuri:ralphi`.
  - Deleted `skills/ralphi/` (SKILL.md + SKILL.ko.md + 5 criteria references × en/ko = 12 files).
  - Deleted `tests/skills_ralphi.bats`.
- **`/harnish:ralphi` slash command** — no longer registered. Use `/galmuri:ralphi` after installing galmuri.

### Changed
- **`impl` Step 6.1 (Post-Done inspection)** now calls `galmuri:ralphi` as a sibling-plugin invocation. If galmuri is not installed, impl skips the step with a one-line note instead of failing — no hard dependency.
- **`drafti-architect` / `drafti-feature` follow-up hint** updated from `/ralphi` to `/galmuri:ralphi`.
- **README / README.ko** — ralphi table row, §3 Inspection example, slash-command list, and footnote tribute removed; Naming section retains the etymology pointer with a link to galmuri; flow diagram now shows `galmuri:ralphi` as an external post-Done node.
- **plugin.json / marketplace.json** description updated to reflect the move.
- **VERSIONING.md** changelog example switched from `ralphi` to `impl`.

### Migration
For consumers who previously relied on `/harnish:ralphi`:
1. Install galmuri: `npx skills add jazz1x/galmuri` (or `/plugin marketplace add https://github.com/jazz1x/galmuri.git && /plugin install galmuri`).
2. Replace any references to `/harnish:ralphi` with `/galmuri:ralphi`.
3. The ralphi skill body is preserved verbatim in galmuri — no behavior change, only namespace.

### Why MINOR, not MAJOR
SemVer policy in `VERSIONING.md` lists "호환 불가 변경" as MAJOR. Pre-1.0 convention bends this: until the project crosses 1.0, MINOR is used for breaking changes and the "leaving unstable" decision is reserved for the eventual `1.0.0` cut. The breaking surface (one removed skill + one renamed slash command) is documented above with a migration path.

## [0.2.0] - 2026-05-09

Frontmatter SSL `logical` block introduced. The 5 skills (en+ko = 10 SKILL.md files) gain a frontmatter metafield that exposes the destructive surface, idempotency, and rollback contract for static auditors. Body, commands, and skill behavior are unchanged — backwards-compatible additive.

### Added
- **`ssl.logical` block** on every `SKILL.md` and `SKILL.ko.md` (5 × 2 = 10 files):
  - `writes` — destructive write surface (e.g. `docs/prd-{slug}.md`, `.harnish/assets/*.jsonl`, `harnish-current-work.json`, `docs/session-*.md`, target source files in autonomous mode).
  - `deletes` — only declared where present (ralphi's autonomous subtraction-preferred policy).
  - `idempotent` — `true` for forki (append-only, opt-out at Step 8); `false` for the four mutation skills.
  - `resumable` — `true` only on impl (the sole skill with a real persistence checkpoint via `harnish-current-work.json`).
  - `rollback` — text describing the HITL gate / hard guardrail / test-FAIL rollback that acts as recovery.
- `.galmuri/audit-skills-2026-05-09.md` — slim-state audit report (5 skills, logical-only frame).

### Why these fields, not the full SSL frame
A static auditor reading only the YAML head needs the *destructive / idempotency / rollback* signal — that's the part not derivable from body grep. `scenes` / `branches` / `tools` / `triggers` already live in the body (`## Step N:` headers, condition tables, bash blocks, description) and would be a synchronization burden if duplicated in frontmatter.

### Why MINOR
SemVer additive change. No removal, no renaming, no behavior change — body / commands / skill description unchanged. Consumers that ignore unknown frontmatter keys (Claude Code's default) are unaffected; consumers that opt in to `ssl.*` get a new capability.

## [0.1.1] - 2026-05-07

Audit-driven body-prose patches. No frontmatter schema change, no script change. Closes 3 documented-behavior gaps surfaced by the SSL audit framework (see `docs/prd-audit-driven-fixes.md`).

### Fixed
- **ralphi Step 3B (en+ko)**: orphan reference `references/criteria-project.md` is now loaded — Step 3B mirrors Step 3A's "exactly **1** criteria file" pattern. Directory-scope inspection no longer runs without a criteria reference.
- **drafti-architect Step 5 (en+ko) + drafti-feature Step 7 (en+ko)**: silent overwrite of `docs/prd-{slug}.md` is closed. HITL prompt now detects pre-existence and offers `(overwrite / n / new-slug)` instead of `(y / n / edit-slug)`. `Prohibited` section gains a symmetric bullet on each skill. Save-guard updated to `(only after y or overwrite)` so the new branch doesn't dead-end at the save step.
- **impl Step 5 (en+ko)**: orphan reference `references/retention-policy.md` is now intentionally addressed — added a manual-trigger row (`자산 보존 정책` / `asset retention policy`) and a Mode Detection note explicitly framing retention/purge as out-of-band ops, not auto-loaded by any utterance.

### Added
- `docs/prd-audit-driven-fixes.md` — PRD covering this release, generated under the v0.0.3 mid-loop guard precedent (prose+bats pattern).
- `tests/skills_drafti.bats` — overwrite-gate regression on drafti-architect Step 5 + drafti-feature Step 7 (en+ko).
- `tests/skills_ralphi.bats` — `criteria-project.md` mapping regression (en+ko).
- `tests/skills_impl.bats` (extension) — `retention-policy.md` reference regression (en+ko).
- `tests/skills_orphan_refs.bats` — **general orphan-reference guard**: every `skills/*/references/*.md` (en + ko) must be mentioned in the corresponding `SKILL.md` body. Prevents the class of bug fixed in this release (orphan reference). Currently 34/34 references wired.

### Changed
- `impl` Step 5 manual triggers table header (en+ko): `Script` / `스크립트` → `Action` / `동작`. The new retention-policy row points to a `.md` reference doc, not a `.sh` script — header generalized to keep table semantics consistent.

### Versioning
- `VERSION`, `.claude-plugin/plugin.json`, 5 SKILL × (md + ko.md) = 10 frontmatters, `README.md` + `README.ko.md` badges — all bumped `0.1.0` → `0.1.1` in lockstep (deep-tier check at `scripts/test-all.sh:1037-1053`).

## [0.1.0] - 2026-04-29

Big-bang migration: all `jq` usage replaced with Python standard library. External interface (CLI flags, stdin/stdout JSON, exit codes, hooks.json, SKILL.md) is 100% preserved.

### Changed
- **All 18 scripts**: bash+jq logic replaced with `scripts/harnish_py/` Python package; `.sh` files are now 2-line wrappers (`PYTHONPATH + exec python3 -m harnish_py <sub> "$@"`)
- `common.sh`: `require_cmd jq` removed; only `resolve_*` helpers and `slugify` remain
- `scripts/skillify.sh`: `skillify_version` bumped `0.0.5` → `0.1.0`
- CI: Python `3.12` → `3.14`; `pytest` unit step added before bats; `jq` install retained for test infrastructure (`test-all.sh` + bats files use jq for assertions; production scripts no longer depend on jq)
- VERSION + 10 SKILL.md frontmatters: `0.0.5` → `0.1.0`
- `.claude-plugin/plugin.json`: `0.0.4` → `0.1.0` (catches up the missed bump from v0.0.5 release; was a pre-existing inconsistency)

### Added
- `scripts/harnish_py/` — 18-module Python package (cli, io, common, asset, record, query, init, compress, promote, detect, skillify, quality, thresholds, purge, migrate, progress, violations)
- `tests/conftest.py` — pytest sys.path injection (honne pattern)
- 11 pytest unit test files (35+ tests): io, cli, asset, record, query, compress, promote, skillify, purge, progress, init
- Python 3.14+ version guard (`sys.version_info < (3, 14)` → exit 4)
- `_Parser` class (argparse exit code 1 instead of 2, honne pattern)

### Removed
- `jq` runtime dependency — `scripts/` no longer calls `jq` anywhere (wrappers are pure delegation)

## [0.0.5] - 2026-04-28

This release combines the asset-store identity correction with the production pipeline closure originally drafted as 0.0.6. Both ship together as 0.0.5.

### Fixed (CRITICAL — closed loop restored)
- **Trigger→Record pipeline closure**: failure context that the hook had pushed into `/tmp/harnish-pending-*.jsonl` was being deleted at session end without ever being persisted as an asset. The `Stop` event now invokes the new `promote-pending.sh` to dedup and forward into `record-asset.sh`. The README's "failures become guardrails" promise actually executes for the first time.

### Changed
- **BREAKING (file rename, auto-migrated)**: Asset store renamed `.harnish/harnish-rag.jsonl` → `.harnish/harnish-assets.jsonl`. `init-assets.sh` performs an idempotent atomic `mv` on first run if the legacy file is present and the new file is absent. No data loss.
- Archive file renamed: `harnish-rag-archive.jsonl` → `harnish-assets-archive.jsonl` (`purge-assets.sh --execute` output)
- L0 Contract (`schema.json`) field rename: `rag_record` → `asset_record`, `storage.rag_file` → `storage.asset_file`
- 14 scripts: `RAG_FILE` / `RAG` shell variables → `ASSET_FILE` / `ASSETS`; `harnish-rag.jsonl` literals replaced
- `common.sh`: `resolve_rag_file()` kept as a deprecated alias of `resolve_asset_file()`; new `resolve_legacy_asset_file()` for migration paths
- `scripts/skillify.sh` upgraded to production grade:
  - description gains an auto-generated `Triggers: ...` line (top-5 candidates extracted by frequency from asset titles)
  - body structured: §1 guidelines (LLM finalize) / §2 type-grouped sections (Failures/Patterns/Guardrails/Decisions/Snippets) / §3 metadata
  - `references/source-assets.jsonl` preserves traceability to the source records
  - asset metadata exposed: level / confidence / stability / resolved
- `scripts/query-assets.sh --format inject` output now carries RCA context:
  - guardrails render as `[guardrail/soft]`, decisions as `[decision/medium]`, patterns as `[pattern/s1]` — type metadata in the head
  - each asset gets a `context:` line; failure types add a `resolved:` flag

### Added
- `scripts/promote-pending.sh` — deduplicates pending JSONL by `(tool, first_error_line)` and auto-registers as a `failure` asset. Tags: `auto`, `tool:<name>`, `session:<short>`. The occurrence count is captured in `context`.
- `tests/e2e_pipeline.bats` — 4 production E2E checks (trigger→record, dedup, skillify quality, inject enrichment).
- `tests/scripts_advanced.bats` +2: legacy `harnish-rag.jsonl` → `harnish-assets.jsonl` migration regression + idempotency test
- README "Memory Model" section: documents the two-tier model (Tier 1 Asset Store + Tier 2 Skills) and clarifies that only `query-assets.sh --format inject` is strict RAG

### Documentation
- README: removed the misleading ralph-loop acronym (`Read → Act → Log → Progress`). The name comes from Ralph Wiggum (The Simpsons) and is not an acronym.
- Honest framing of `skillify.sh`: it is a draft generator (asset bundling + TODO scaffold), **not** autonomous skill graduation. Future feature flagged on the roadmap.
- README/SKILL.md/thresholds.md path references updated to `harnish-assets.jsonl`

## [0.0.4] - 2026-04-27

### Fixed
- `check-thresholds.sh` W1: `--threshold` flag now parsed correctly regardless of argument order; `--base-dir` first no longer silently corrupts the threshold value
- `compress-assets.sh` C1: compressed summary body no longer contains `TODO` placeholder — titles are extracted before source records are marked compressed
- `skills/impl/references/schema.json` L0 Contract: `script_io` entries for 6 scripts updated to match actual CLIs (purge-assets, compress-assets, quality-gate, localize-asset, abstract-asset, skillify)
- `record-asset.sh`: duplicate slug auto-suffix (`-2`, `-3` ...) — prevents `query-assets.sh` write-back from incrementing `access_count` on unrelated records with the same title
- `loop-step.sh`: proper while-loop arg parsing — `--format json` without explicit file path now resolves correctly via `resolve_progress_file()`
- `validate-progress.sh`: added `🔵` to the valid status-emoji set — eliminates false WARNING on in-progress work files
- `compress-progress.sh`: replaced deterministic `.tmp` path with `mktemp` — eliminates concurrent-run conflict
- `detect-asset.sh`: Stop event now deletes the session pending file and prunes stale pending files older than 7 days from `/tmp`
- `migrate.sh`: keeps only the 3 most recent `.bak.*` files — prevents unbounded backup accumulation

### Added
- `tests/e2e_workflow.bats` — 9 E2E tests covering the full progress pipeline: `init-assets → validate-progress → loop-step → compress-progress → progress-report → check-violations`
- `tests/e2e_assets.bats` — 11 E2E tests covering the full asset lifecycle: `record(6 types) → query → check-thresholds → compress-assets → quality-gate → migrate → purge`
- `tests/scripts_advanced.bats` +5: `purge --execute`, `loop-step --format without path`, `detect-asset meaningful error → pending`, `detect-asset Stop → pending deleted`
- `scripts/skillify.sh`: `--output-dir` flag for configurable skill output directory

## [0.0.3] - 2026-04-23

### Fixed
- impl skill: Mid-loop interruption guard — explicit prose prohibition on stopping outside milestone HITL, 3-failure escalation, or hard-guardrail violation (see docs/prd-impl-midloop-guard.md)

## [0.0.2] - 2026-04-22

### Added
- Test suite + GitHub Actions CI — 25 bats tests (manifest schema + script smoke + sandboxing) and a deep tier wrapping `scripts/test-all.sh`. Matrix runs on `ubuntu-latest` + `macos-latest`.
- Self-name triggers on every skill description — `"forki"`, `"impl"`, `"harnish"` (and variants), `"drafti-architect"`, `"drafti"`, `"drafti-feature"` are now first-class triggers, so natural-language calls auto-invoke without the slash form.

### Changed
- **BREAKING:** Main implementation skill renamed `harnish` → `impl` (`/harnish:harnish` → `/harnish:impl`). The "harnish" engine concept is preserved — `impl` keeps `"harnish"`, `"harnish 시작"`, `"harnish 돌려"`, `"harnish 이어서"` in its trigger list, so existing natural-language calls keep working.
- `scripts/test-all.sh` — dropped the obsolete `har-*` shortcut parity section (those skills were removed in the v0.0.1 cycle); SKILL version check now derives the expected version from `plugin.json` instead of hard-coding it (no more drift on bumps).
- `scripts/test-all.sh` — brace-wrapped variable refs adjacent to Korean characters (`${var}개` instead of `$var개`) to fix CI macOS bash 3.2 + C locale parsing under `set -u`.
- `scripts/common.sh` — `resolve_skill_dir()` now points to `skills/impl`.

## [0.0.1] - 2026-04-22

First public release. 5 skills + shared script suite + asset infrastructure + auto-registered hooks.

### Added

#### forki `0.0.1`
- Decision-forcing skill (binary fork + D/E/V/R + trade-off, HITL only)
- Counter semantics — abort on attempt 3/3 (2 back-jumps)
- Decision asset recording (Step 0/8)
- Router + references separation

#### drafti-architect `0.0.1`
- Tech-driven design PRD generation skill
- Sequential 10-step checklist
- 2-3 design alternatives + trade-off matrix
- HARNISH_ROOT detection: monorepo / standalone mode auto-discrimination
- references: design-decision.md, prd-template.md

#### drafti-feature `0.0.1`
- Planning-based feature PRD generation skill
- Feature flag design (boolean / percentage / segment + kill switch) — conditional application
- Language-agnostic codebase exploration (§4 Step 0 language detection)
- HARNISH_ROOT detection: monorepo / standalone mode auto-discrimination
- references: feature-flag-patterns.md, prd-template.md

#### impl `0.0.1` (the "harnish" engine)
- Autonomous implementation engine (seeding + ralph loop + anchoring + experience accumulation)
- Mode A: PRD → atomic task decomposition → `harnish-current-work.json`
- Mode B: ralph loop (one task at a time, auto-execute → record result → update progress, repeat)
- Mode C: session restoration (anchoring) + asset detection / recording / compression / skillification
- §B.9 acceptance_criteria execution: bash / condition / mixed / none — 4 branches
- Multi-language type checker (Python / TS / Go / Java / Rust)
- **Step 6: Post-Completion Ceremony** — automatic post-task inspection (ralphi) + asset compression suggestion + summary + HITL save
- Entry prompt when invoked without arguments
- references: task-schema.md, progress-template.md, escalation-protocol.md, guardrail-levels.md, thresholds.md, retention-policy.md

#### ralphi `0.0.1`
- Artifact integrity verification skill (self-check + self-fix loop, up to 7 iterations)
- 4 artifact types: PRD, SKILL.md, scripts, code
- HITL + autonomous fix modes (utterance-based mode selection: "점검해" → HITL, "고쳐" → autonomous)
- Necessity check (Socratic) + Context Budget + subtraction principle
- criteria-code.md: 9-language tooling map
- criteria-project.md: project / directory scope inspection criteria
- references: criteria-code.md, criteria-prd.md, criteria-skill.md, criteria-script.md, criteria-project.md

#### Shared scripts
- validate-progress.sh, loop-step.sh, compress-progress.sh, check-violations.sh
- query-assets.sh (write-back: auto-increments access_count)
- record-asset.sh (`schema_version`, `last_accessed_at`, `access_count` fields)
- detect-asset.sh, init-assets.sh
- compress-assets.sh (`--dry-run` non-destructive compression candidate listing)
- check-thresholds.sh, quality-gate.sh, skillify.sh
- abstract-asset.sh, localize-asset.sh, common.sh, pre-commit.sh
- migrate.sh (schema backfill)
- POSIX compatible (macOS BSD grep handled, no GNU-only flags)

#### Asset infrastructure
- `.harnish/harnish-rag.jsonl` — 6 asset types (failure, pattern, guardrail, snippet, decision, compressed)
- Asset TTL & Purge — retention-policy-driven auto-cleanup (per-type retention period)
- Worktree isolation (CWD-scoped independent `.harnish/`)

#### Hooks (auto-registered via `hooks/hooks.json`)
- `PostToolUse` (Bash/Edit/Write/NotebookEdit) → detect failure patterns / guardrails / reusable snippets
- `PostToolUseFailure` → capture meaningful failure context (noise filter)
- `Stop` → quality gate + threshold check on accumulated assets

#### Plugin manifest
- `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`
- `/plugin marketplace add https://github.com/jazz1x/harnish.git` + `/plugin install harnish` install path
- i18n: English default + separate Korean files (`SKILL.ko.md`, `README.ko.md`)

#### Documentation
- README structure aligned with galmuri tone: badges, install steps, quickstart, usage, hooks, assets, worktrees, fork & customize, naming, triad
- VERSIONING.md, references/* guides

[Unreleased]: https://github.com/jazz1x/harnish/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/jazz1x/harnish/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/jazz1x/harnish/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/jazz1x/harnish/compare/v0.0.5...v0.1.0
[0.0.5]: https://github.com/jazz1x/harnish/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/jazz1x/harnish/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/jazz1x/harnish/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/jazz1x/harnish/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/jazz1x/harnish/releases/tag/v0.0.1
