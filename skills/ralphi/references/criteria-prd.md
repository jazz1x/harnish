# PRD Verification Criteria

> Detailed criteria referenced by ralphi when verifying PRD artifacts.
> To be enhanced after harnish M5. Currently only minimum criteria are defined.

## Required Sections

- §4 Implementation Spec: file paths, function names, change types must exist
- §6 Test Criteria: bash commands or condition lists must exist
- §7 Guardrails: hard/soft distinction must exist

## Prohibited Ambiguous Expressions

"appropriately", "if needed", "later", "etc.", "other", "sufficiently", "if possible"
→ Report as issue when found (must be replaced with specific expressions)

## Section Number Consistency

§1 → §2 → ... → §N in order. No gaps allowed.

## File Path Existence

File paths specified in §4 must:
- Already exist (modify/delete)
- Be explicitly marked as create
- Warn if path cannot be verified
