# harnish

> Claude Code plugin — autonomous implementation engine

![version](https://img.shields.io/badge/version-0.0.3-blue)
![license](https://img.shields.io/badge/license-MIT-green)
![claude-code](https://img.shields.io/badge/claude--code-plugin-purple)

**harnish** (harness + ish) — an implementation environment that gets smarter as you work. Failures become guardrails, patterns accumulate, and context persists across sessions and worktrees.

[한국어](./README.ko.md)

## Skills

| Skill | Command | Role |
|-------|---------|------|
| **forki** | `/harnish:forki` | Decision forcing (binary fork + D/E/V/R + trade-off, HITL only) |
| **drafti-architect** | `/harnish:drafti-architect` | Tech-driven design PRD generation |
| **drafti-feature** | `/harnish:drafti-feature` | Planning-based implementation spec PRD |
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

## Install

### 1. Register the marketplace

Inside a Claude Code session, run:

```
/plugin marketplace add https://github.com/jazz1x/harnish.git
```

Expected output:

```
✓ Marketplace 'harnish' added (1 plugin)
```

### 2. Install the plugin

```
/plugin install harnish
```

Expected output:

```
✓ Installed harnish@0.0.3 — 5 skills registered (forki, drafti-architect, drafti-feature, impl, ralphi)
```

### 3. Verify

```
/plugin list
```

You should see `harnish` in the list. The five slash commands below should be invocable:

```
/harnish:forki
/harnish:drafti-architect
/harnish:drafti-feature
/harnish:impl
/harnish:ralphi
```

### 4. Hooks (auto-registered)

harnish ships hooks in `hooks/hooks.json`, which the plugin loader picks up automatically on install. **No manual setup needed** — see the [Hooks](#hooks) section for what each does.

### 5. Uninstall

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

Sample flow (simplified):

```
user   > /harnish:impl docs/prd-redis-cache.md

step 1 > Reading PRD → 3 phases, 12 atomic tasks identified
step 2 > Seeding → .harnish/harnish-current-work.json created
step 3 > "Phase 1 Task 1.1 ready. Run 'loop' to start ralph loop?"
user   > loop

step 4 > [READ] task 1.1 → [ACT] write code → [LOG] result → [PROGRESS] 1/12
step 5 > Pass → asset recorded (pattern: connection-pool-init)
step 6 > Auto-advance to task 1.2 …
       ⋮
step N > Phase 1 complete → milestone report → continue Phase 2? (y/n)
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
User: "Design a Redis cache layer"
→ drafti-architect explores 2-3 design alternatives with trade-off analysis
→ generates docs/prd-redis-cache.md

User: "Create a PRD from this planning doc" (with planning document attached)
→ drafti-feature generates implementation spec PRD (feature flags only when needed)
→ generates docs/prd-user-profile-edit.md
```

### 2. Autonomous Implementation (harnish)

```
User: /harnish:impl
→ "What would you like to implement? Provide a PRD file path or describe the task."

User: "Start implementation" or "Decompose tasks"
→ Decomposes PRD into atomic tasks → generates harnish-current-work.json
→ "3 Phases, 12 Tasks seeded — review then 'run the loop'"

User: "Run the loop"
→ ralph loop auto-executes (Read → Act → Log → Progress → repeat)
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
→ Generates reusable SKILL.md draft from compressed assets
```

## Hooks

harnish registers the following hooks automatically on install via `hooks/hooks.json`. No configuration needed.

| Event | Trigger | What it does |
|-------|---------|--------------|
| `PostToolUse` | Bash, Edit, Write, NotebookEdit | Scans tool output for failure patterns, guardrails, and reusable snippets → records to `.harnish/` |
| `PostToolUseFailure` | Bash, Edit, Write, NotebookEdit | Captures meaningful failure context (noise patterns filtered) → records as failure asset for future reference |
| `Stop` | Session end | Runs quality gate + threshold check on accumulated assets |

Failures are classified by signal-to-noise: simple errors (`No such file`, `permission denied`, `command not found`, etc.) are filtered out so only meaningful failures become assets.

## Assets

Every accumulated learning is recorded in `.harnish/harnish-rag.jsonl` (one JSON object per line). Six asset types:

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
bash scripts/check-thresholds.sh                       # current count vs. compression threshold
bash scripts/query-assets.sh --tags api,retry --format text   # query by tag
bash scripts/compress-assets.sh --dry-run --all        # preview compression
bash scripts/quality-gate.sh                           # rerun the Stop-event quality check
```

`.harnish/` lives inside your project CWD and persists across sessions. `impl`, `drafti-architect`, and `drafti-feature` reference relevant assets automatically (tag-based query in Step 2 of each skill).

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

The skill is available as `forki` (no plugin namespace). Replace `forki` with any of: `impl`, `ralphi`, `drafti-architect`, `drafti-feature`.

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
- **drafti** = draft + i (PRD generation — drafti-architect + drafti-feature)
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
