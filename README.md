# harnish

> Claude Code plugin — autonomous implementation engine

**harnish** (harness + ish) — an implementation environment that gets smarter as you work. Failures become guardrails, patterns accumulate, and context persists across sessions.

[한국어](./README.ko.md)

## Install

Run Claude Code, then:

```
/plugin marketplace add https://github.com/jazz1x/harnish.git
/plugin install harnish
```

## Skills

| Skill | Command | Role |
|-------|---------|------|
| **forki** | `/harnish:forki` | Decision forcing (binary fork + D/E/V/R + trade-off, HITL only) |
| **drafti-architect** | `/harnish:drafti-architect` | Tech-driven design PRD generation |
| **drafti-feature** | `/harnish:drafti-feature` | Planning-based implementation spec PRD |
| **harnish** | `/harnish:harnish` | Autonomous implementation engine (seeding + RALP loop + anchoring + experience) |
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
User: /harnish:harnish
→ "What would you like to implement? Provide a PRD file path or describe the task."

User: "Start implementation" or "Decompose tasks"
→ Decomposes PRD into atomic tasks → generates harnish-current-work.json
→ "3 Phases, 12 Tasks seeded — review then 'run the loop'"

User: "Run the loop"
→ RALP loop auto-executes (Read → Act → Log → Progress → repeat)
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

harnish registers the following hooks automatically on install. No configuration needed.

| Event | Trigger | What it does |
|-------|---------|--------------|
| `PostToolUse` | Bash, Edit, Write, NotebookEdit | Scans tool output for failure patterns, guardrails, and reusable snippets → records to `.harnish/` |
| `PostToolUseFailure` | Bash, Edit, Write, NotebookEdit | Captures failure context → records as failure asset for future reference |
| `Stop` | Session end | Runs quality gate + threshold check on accumulated assets |

Assets accumulate in `.harnish/` inside your project directory and persist across sessions. They are automatically referenced by `harnish`, `drafti-architect`, and `drafti-feature` when relevant.

## Fork & Customize

Three ways to use this repo as a base:

### A. Cherry-pick a single skill into your project

Copy one skill directly into your own project — no plugin install needed.

```bash
mkdir -p .claude/skills
cp -r /path/to/harnish/skills/forki .claude/skills/
```

The skill is now available in this project as `forki` (no plugin namespace).
Replace `forki` with any of: `harnish`, `ralphi`, `drafti-architect`, `drafti-feature`.

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

### C. Use this repo as a read-only upstream

```bash
git clone https://github.com/jazz1x/harnish.git
cd your-project
claude --plugin-dir /path/to/harnish
git -C /path/to/harnish pull   # update later
```

## Worktrees

Each worktree gets its own `.harnish/` directory based on CWD. Work coordinates and experience are fully isolated per worktree — no shared state, no write conflicts.

```
/project/.harnish/                      ← main tree
/project/.claude/worktrees/A/.harnish/  ← worktree A
/other/path/worktree-B/.harnish/        ← worktree B (physical separation)
```

## Naming

- **harnish** = harness + ish (autonomous implementation engine)
- **ralphi** = RALP (Recursive Autonomous Loop Process) + i (inspection)
- **drafti** = draft + i (PRD generation — drafti-architect + drafti-feature)
- **forki** = fork + i (decision forcing — binary fork + D/E/V/R + trade-off, HITL only)

## Footnote

> *"If `ralphi` already does it, a new skill is just noise —
> and distill becomes its own first victim."*

A skill called `distill` was proposed, and erased by the very principle it stood for.
That was ralphi, working.

## License

MIT
