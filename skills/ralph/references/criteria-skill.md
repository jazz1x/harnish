# SKILL.md Verification Criteria

> Detailed criteria referenced by ralph when verifying SKILL.md artifacts.
> To be enhanced after harnish M5.

## frontmatter

- `name`: Required. Kebab case.
- `version`: Required. SemVer format (`X.Y.Z`). Validated by pre-commit hook.
- `description`: Required. At least 1 line.

## Ambiguous Expressions

If SKILL.md contains ambiguous expressions, low-level models will start making judgments. This is dangerous.
All conditionals must be explicit in if/then form.

## bash Path Verification

Verify that paths based on `${CLAUDE_PLUGIN_ROOT}` actually exist.

## Context Budget

A context budget section must exist. Specify which references are read and when.
