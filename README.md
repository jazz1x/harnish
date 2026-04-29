# harnish

> Claude Code plugin — autonomous implementation engine

![version](https://img.shields.io/badge/version-0.1.0-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![claude-code](https://img.shields.io/badge/claude--code-plugin-purple)
![tests](https://img.shields.io/badge/tests-123%20passing-brightgreen)
![python](https://img.shields.io/badge/python-3.14%2B-blue)

**harnish** (harness + ish) — an implementation environment that gets smarter as you work. Failures become guardrails, patterns accumulate, and context persists across sessions and worktrees.

[한국어](./README.ko.md)

## Skills

| Skill | Command | Role |
|-------|---------|------|
| **forki** | `/harnish:forki` | Decision forcing (binary fork + D/E/V/R + trade-off, HITL only) |
| **drafti-feature** | `/harnish:drafti-feature` | Planning-based implementation spec PRD |
| **drafti-architect** | `/harnish:drafti-architect` | Tech-driven design PRD generation |
| **impl** | `/harnish:impl` | Autonomous implementation engine — the "harnish" engine (seeding + ralph loop + anchoring + experience) |
| **ralphi** | `/harnish:ralphi` | Inspection (HITL reporting or autonomous fix) |

Each skill operates in an **independent orbit**, connected only through **shared artifacts (files)**.

```
forki   ──→  forces a binary decision (D/E/V/R + trade-off, HITL only)
                ↓
drafti  ──→  docs/prd-*.md  ──→  harnish  ──→  implementation code
                                     │
                                     └── .harnish/ (work coordinates + experience, in user project CWD)

ralphi  ──→  inspects any artifact (PRD, SKILL.md, scripts, code)
              HITL (report → wait) or autonomous (fix immediately)
```

## Requirements

- **Python 3.14+** — runtime for all `scripts/*.sh` (they delegate to `scripts/harnish_py/` via 1-line wrappers; the `sys.version_info < (3, 14)` guard exits with code 4 on older interpreters).
- **Claude Code** — plugin host.
- **No `jq` dependency** as of v0.1.0.

## Install

### Option 1 — `npx skills add` (recommended)

Works with Claude Code, Cursor, Codex, Windsurf, and other skills.sh-compatible agents.

```bash
npx skills add jazz1x/harnish               # install into ./.claude/skills/ (project)
npx skills add jazz1x/harnish -g            # install into ~/.claude/skills/ (global)
npx skills add jazz1x/harnish --list        # list skills before installing
npx skills add jazz1x/harnish --skill impl  # install a single skill
```

Expected output:

```
✓ Installed jazz1x/harnish — 5 skills (forki, drafti-feature, drafti-architect, impl, ralphi)
```

### Option 2 — Claude Code native plugin

Inside a Claude Code session:

```
/plugin marketplace add https://github.com/jazz1x/harnish.git
/plugin install harnish
```

Expected output:

```
✓ Installed harnish@0.1.0 — 5 skills registered (forki, drafti-feature, drafti-architect, impl, ralphi)
```

Verify with `/plugin list`. The five slash commands below should be invocable:

```
/harnish:forki
/harnish:drafti-feature
/harnish:drafti-architect
/harnish:impl
/harnish:ralphi
```

Hooks are auto-registered via `hooks/hooks.json` — see the [Hooks](#hooks) section.

### Uninstall

```
/plugin uninstall harnish
/plugin marketplace remove harnish
```

The `.harnish/` directory inside your project is **not** removed automatically — delete it manually if you want to wipe the accumulated assets.

---

## Quickstart

Once installed, the fastest path end-to-end:

```
# Inside a Claude Code session, in any project that has a PRD or planning doc
/harnish:impl
```

Sample flow:

```
user > /harnish:impl docs/prd-redis-cache.md
       → 3 phases, 12 atomic tasks seeded into .harnish/harnish-current-work.json
user > loop
       → task 1.1 → code → log → asset recorded → auto-advance 1.2 → … → Phase 1 done
       → milestone report → continue Phase 2? (y/n)
```

If invoked with no PRD path or task description, harnish will ask:

```
What would you like to implement? Provide a PRD file path or describe the task.
```

In a new session, simply say "continue where I left off" — harnish restores coordinates from `harnish-current-work.json` and resumes from the break point.

## Usage

### 0. Decision Forcing (forki)

```
User: /harnish:forki
→ "What decision do you need to make? Describe the situation."

User: "Should we use Postgres or MongoDB for this?"
→ forki frames as binary → asks user to confirm A/B
→ asks user to fill the D/E/V/R table (8 cells)
→ surfaces trade-off → asks user to commit (LLM cannot decide)
→ outputs the structural reason for the choice
```

### 1. PRD Generation (Design)

```
User: "Create a PRD from this planning doc" (with planning document attached)
→ drafti-feature generates implementation spec PRD (feature flags only when needed)
→ generates docs/prd-user-profile-edit.md

User: "Design a Redis cache layer"
→ drafti-architect explores 2-3 design alternatives with trade-off analysis
→ generates docs/prd-redis-cache.md
```

### 2. Autonomous Implementation (harnish)

```
User: /harnish:impl
→ "What would you like to implement? Provide a PRD file path or describe the task."

User: "Start implementation" or "Decompose tasks"
→ Decomposes PRD into atomic tasks → generates harnish-current-work.json
→ "3 Phases, 12 Tasks seeded — review then 'run the loop'"

User: "Run the loop"
→ The ralph loop runs one task at a time until the phase is done
  (named after Ralph Wiggum — keep trying, don't give up; not an acronym)
→ Updates harnish-current-work.json every 3 actions, milestone report on phase completion

User: (in a new session) "Continue where I left off"
→ Restores coordinates from harnish-current-work.json, auto-resumes from break point
```

### 3. Inspection (ralphi)

```
User: "Inspect this PRD"
→ Type detection (PRD) → static analysis → issue report → waits for user judgment (HITL)

User: "Inspect and fix src/cache.py"
→ Type detection (code) → analysis → immediate fix → result report (autonomous)
→ Rolls back on test failure, classifies as unfixed when intent is unclear
```

### 4. Experience Accumulation

```
User: "Remember this pattern"
→ Records as pattern asset → auto-referenced in future work

User: "Asset status"
→ Shows accumulated failure/pattern/guardrail/snippet/decision assets

User: "Make this a skill"
→ Bundles compressed assets into a SKILL.md scaffold (with raw asset
  bodies + a TODO marker). The LLM must finalize the body — this is a
  draft generator, not autonomous skill graduation. Truly autonomous
  promotion is a planned future feature.
```

## Hooks

harnish registers the following hooks automatically on install via `hooks/hooks.json`. No configuration needed.

| Event | Trigger | What it does |
|-------|---------|--------------|
| `PostToolUse` | Bash, Edit, Write, NotebookEdit | Scans tool output for failure patterns, guardrails, and reusable snippets → records to `.harnish/` |
| `PostToolUseFailure` | Bash, Edit, Write, NotebookEdit | Captures meaningful failure context (noise patterns filtered) → records as failure asset for future reference |
| `Stop` | Session end | Runs quality gate + threshold check on accumulated assets, then cleans up session pending files |

Failures are classified by signal-to-noise: simple errors (`No such file`, `permission denied`, `command not found`, etc.) are filtered out so only meaningful failures become assets.

## Memory Model

harnish runs a **two-tier memory** system. Each tier serves a different role; the bridge between them is currently semi-manual.

| Tier | Storage | Lifetime | Role | Loaded as |
|------|---------|----------|------|-----------|
| **Tier 1 — Asset Store** (episodic) | `.harnish/harnish-assets.jsonl` | Per-project, accumulates across sessions, TTL-purged | Records what happened (failures, patterns, guardrails, snippets, decisions) | Injected into context on demand via `query-assets.sh --format inject` (this is the actual RAG path) |
| **Tier 2 — Skills** (procedural) | `skills/*/SKILL.md` | Permanent (versioned in source tree) | Codifies stable behavior | Auto-loaded by Claude Code as triggerable skills |

`skillify.sh` is the bridge — it bundles compressed Tier-1 assets into a Tier-2 SKILL.md scaffold. The scaffold is **production-grade** (since v0.0.5; reimplemented in Python in v0.1.0):

- Frontmatter `Triggers:` auto-extracted from asset titles
- Body sectioned by asset type, with metadata (level / confidence / stability / resolved)
- `references/source-assets.jsonl` preserves originals for traceability
- §1 still needs LLM finalization of 1-3 actionable guidelines — draft generator, not autonomous graduation

**Trigger → Record → Skillify pipeline** (closed in v0.0.5; pure-Python implementation in v0.1.0, `.sh` files are 1-line wrappers):

```
PostToolUseFailure  →  detect-asset.sh (noise filter)  →  /tmp/harnish-pending-*.jsonl
Stop                →  promote-pending.sh (dedup)      →  harnish-assets.jsonl
"make it a skill"   →  skillify.sh                     →  SKILL.md draft + references/
```

> **Why "assets" not "RAG"?** Only `query-assets.sh --format inject` is RAG in the strict sense. The rest is capture / summarize / age-out / feed-into-skill — i.e. asset CRUD + lifecycle.

## Assets

Every accumulated learning is recorded in `.harnish/harnish-assets.jsonl` (one JSON object per line). Six asset types:

| Type | Captured when |
|------|---------------|
| `failure` | A meaningful tool failure occurs (filtered for signal) |
| `pattern` | User says "remember this pattern" or recurring success structure detected |
| `guardrail` | A rule emerges from repeated failures (e.g. "always retry with backoff on 503") |
| `snippet` | Reusable code fragment worth quoting verbatim |
| `decision` | A forki output worth carrying forward |
| `compressed` | Multiple related assets merged into one summary (auto-suggested at threshold) |

Inspect / manage assets:

```bash
bash scripts/check-thresholds.sh [--threshold N]              # current count vs. compression threshold
bash scripts/query-assets.sh --tags api,retry --format text   # query by tag
bash scripts/compress-assets.sh --dry-run --all               # preview compression
bash scripts/quality-gate.sh                                  # rerun the Stop-event quality check
bash scripts/purge-assets.sh                                  # dry-run purge (--execute to apply)
bash scripts/migrate.sh                                       # backfill schema to latest version
```

`.harnish/` lives inside your project CWD and persists across sessions. `impl`, `drafti-feature`, and `drafti-architect` reference relevant assets automatically (tag-based query in Step 2 of each skill).

## Worktrees

Each worktree gets its own `.harnish/` directory based on CWD. Work coordinates and experience are fully isolated per worktree — no shared state, no write conflicts.

```
/project/.harnish/                      ← main tree
/project/.claude/worktrees/A/.harnish/  ← worktree A
/other/path/worktree-B/.harnish/        ← worktree B (physical separation)
```

## Fork & Customize

Three ways to use this repo as a base:

### A. Cherry-pick a single skill into your project

```bash
mkdir -p .claude/skills
cp -r /path/to/harnish/skills/forki .claude/skills/
```

The skill is available as `forki` (no plugin namespace). Replace `forki` with any of: `impl`, `ralphi`, `drafti-feature`, `drafti-architect`.

### B. Fork as your own plugin marketplace

```bash
gh repo fork jazz1x/harnish --clone
cd harnish
# edit .claude-plugin/plugin.json (name, author, repository)
# edit .claude-plugin/marketplace.json (owner, plugin entries)
# add/remove/modify skills under skills/
git commit -am "fork: rebrand"
git push
```

### C. Use as read-only upstream

```bash
git clone https://github.com/jazz1x/harnish.git
cd your-project
claude --plugin-dir /path/to/harnish
git -C /path/to/harnish pull   # update later
```

## Naming

- **harnish** = harness + ish (autonomous implementation engine)
- **ralphi** = ralph + i (inspection)
  - Origin: named after Ralph Wiggum from The Simpsons — keep trying, don't give up
- **drafti** = draft + i (PRD generation — drafti-feature + drafti-architect)
- **forki** = fork + i (decision forcing — binary fork + D/E/V/R + trade-off, HITL only)

## Triad

harnish sits in a triad of sibling plugins — independent, connected by shared artifacts only:

```
harnish (make)  ──→  honne (know)  ──→  galmuri (keep)
  execution         reflection          refinement
```

- [harnish](https://github.com/jazz1x/harnish) — autonomous implementation engine
- [honne](https://github.com/jazz1x/honne) — evidence-backed self-reflection (6-axis persona)
- [galmuri](https://github.com/jazz1x/galmuri) — summary · decision-deck · documentation

## Footnote

> *"If `ralphi` already does it, a new skill is just noise —
> and distill becomes its own first victim."*

A skill called `distill` was proposed, and erased by the very principle it stood for.
That was ralphi, working.

## License

MIT — See [LICENSE](./LICENSE).
