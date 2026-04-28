# Thresholds, Compression, and Skillification Rules

## Compression Triggers

| Condition | Action |
|-----------|--------|
| 5+ assets with the same tag | Compression recommended (deduplicate, extract essentials only) |
| 10+ assets of the same type (total) | Type-based cleanup recommended |
| 3+ guardrails in the same domain | Domain-specific guardrail consolidated document creation recommended |

## Skillification Triggers

| Condition | Action |
|-----------|--------|
| Same pattern with stability >= 3 | Skillification recommended |
| Compressed asset group forms a complete workflow | Skillification recommended |
| User requests "make this a skill" | Start skillification immediately |

## Stability Update Rules

- If a pattern/snippet with the same tag is reused in a different session, stability +1
- If a pattern is applied after a failure and succeeds, stability +1
- If a pattern variation occurs (same problem, different solution), reset stability to 1 and record as a new asset

## Compression Process

1. Select target asset group (by tag or type)
2. Identify and merge duplicate assets
3. Extract only essential content into a single summary document
4. Add `compressed: true` to original records
5. Append 1 summary entry to harnish-assets.jsonl

## Skillification Process

1. Select compressed assets or patterns with stability >= 3
2. Draft SKILL.md following the skill-creator skill pattern
3. Map asset guardrails → skill precautions
4. Map asset snippets → skill scripts/
5. Map asset decision rationales → skill design principles
6. User review and approval
7. Place in `.claude/skills/` (or package as .skill)
