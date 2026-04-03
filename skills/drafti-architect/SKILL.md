---
name: drafti-architect
version: 0.0.1
description: >
  Technical design PRD generator. Creates an implementation-ready PRD from a technical problem definition alone, without a planning document.
  Triggers: "설계해", "design this", "아키텍처 PRD", "architecture PRD", "이 문제 어떻게 해결할지", "how to solve this problem",
  "기술적으로 어떻게", "how to technically", "PRD 만들어", "create PRD" (when no planning doc is provided).
  Distinction from drafti-feature: no planning document → architect, has planning document → feature.
---

# drafti-architect — Technical Design PRD

> Makes design decisions from technical problems and produces an implementation-ready PRD, without a planning document.

## Environment Setup

```bash
HARNISH_ROOT="${CLAUDE_PLUGIN_ROOT}"
```

## Skill Chain

Can be invoked independently. Follow-up: "start implementation after review" → harnish, or "/ralpi to verify PRD consistency" → ralpi.

## Step 1: Problem Clarification

Inspect 5 items from the user input. Skip items that already have answers.

| # | Item | Inspection Criteria |
|---|------|----------|
| 1 | Problem Definition | Is there a "what is the problem" + specific pain point? |
| 2 | Urgency | Is there a "why must this be solved now"? |
| 3 | Technical Constraints | Are there stack/compatibility requirements? (If none, proceed with "no constraints") |
| 4 | Scope | Is there a distinction between "what to do now" vs "what to do later"? |
| 5 | Success Criteria | Is there a method to determine completion? |

- Only ask about items marked ❌. Skip items marked ✅.
- **Ask 1~2 items at a time, complete within 2 rounds total.** Mark unanswered items as "[unconfirmed]" and proceed.

## Step 2: Existing Asset Query

Extract 3~5 tags from the problem (tech stack → problem domain → task type order).

```bash
if [[ -n "${CLAUDE_PLUGIN_ROOT}" ]]; then
  bash "${HARNISH_ROOT}/scripts/query-assets.sh" \
    --tags "{extracted tags}" --format inject \
    --base-dir "$(pwd)/.harnish"
fi
```

- Assets found → reflect guardrails in §7, decisions in §2 reinforcement, failures in §5
- Empty result → proceed without assets

## Step 3: Design Alternative Exploration

**Generate at least 2 alternatives.** Create alternatives even if there is an "obvious right answer."

Alternative discovery: Existing tools? Build from scratch? Architecture change? Status quo? Phased approach?

For each alternative:
```
## Alternative {A/B/C}: {name}
| Aspect | Evaluation |
|------|------|
| Pros | (quantify if possible) |
| Cons | (cost, risk, limitations) |
| Implementation difficulty | Low/Medium/High + reason |
| Suitable situation | When is this the best choice |
| Rejection condition | When should this NOT be used |
```

Details: `references/design-decision.md`

## Step 4: Selection + PRD Writing

### Selection Rationale — must be conditional:

Bad example: "A is better"
Good example: "Team has 2 years React experience + 80% existing code → zero learning cost. Vue requires 3 weeks of learning. Therefore React."

Required: State current situation → what the selection gains → **validity conditions** ("revisit if this condition changes")

### PRD Scale Assessment → Section Decision

| Scale | Criteria | Required Sections | Optional |
|------|------|----------|------|
| Small (1~2 days) | <500 lines | §1, §2, §4, §6, §7 | §3, §5 |
| Medium (1~2 weeks) | 500~2000 lines | §1~§8 full | §9 |
| Large (1 month+) | 2000+ lines | §1~§8 + phase splitting | Schedule |

If unclear, assume **medium scale**. Read `references/prd-template.md` and write accordingly.

## Step 5: Save + Asset Recording

```bash
mkdir -p docs/
# PRD save: docs/prd-{slug}.md
```

Asset recording (harnish ecosystem mode):
```bash
if [[ -n "${CLAUDE_PLUGIN_ROOT}" ]]; then
  # Decision recording
  bash "${HARNISH_ROOT}/scripts/record-asset.sh" \
    --type decision --tags "{tags}" \
    --title "{one-line decision}" --content "{selection rationale}" \
    --base-dir "$(pwd)/.harnish"

  # Guardrail recording (when derived constraints exist)
  bash "${HARNISH_ROOT}/scripts/record-asset.sh" \
    --type guardrail --tags "{tags}" \
    --title "{one-line rule}" --content "{consequence of violation}" \
    --base-dir "$(pwd)/.harnish"
fi
```

## Step 6: Completion

```
✅ PRD complete: docs/prd-{slug}.md
Includes: §4 Implementation spec / §6 Test criteria / §7 Guardrails
Next: "start implementation" after review, or /ralpi for consistency check.
```

## Distinction from drafti-feature

| User Request | Judgment | Skill |
|-----------|------|------|
| "Create PRD based on this planning doc" | Planning document exists | → drafti-feature |
| "How should I design this problem" | No planning doc, design decision needed | → drafti-architect |

Decide based on presence/absence of a planning document. If uncertain, ask the user "Do you have a planning document?"

## Prohibited

- Finishing with only 1 alternative (minimum 2)
- Groundless selection like "~is better"
- Finalizing a decision without validity conditions
- Loading 2 references simultaneously (load 1 at a time, switch per phase)
