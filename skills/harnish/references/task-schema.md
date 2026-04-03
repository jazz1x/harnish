# Task YAML Schema

> Structure definition for the task seeding output.
> Can be recorded inline in harnish-current-work.json or managed as a separate YAML file.

---

## Overall Structure

```yaml
project:
  name: "{project name}"
  prd: "{PRD file path}"
  created: "{YYYY-MM-DD}"

  # Project-level guardrails (derived from PRD §7)
  guardrails:
    architecture:
      - "{rule 1}"
    code_style:
      - "{rule 1}"
    testing:
      - "{rule 1}"

  # Project-level prohibitions
  prohibitions:
    - id: "{NO_SOMETHING}"
      rule: "{rule}"
      on_violation: "{immediately stop, report to user}"

phases:
  - id: 1
    title: "{phase title}"
    objective: "{objective of this phase}"
    completion_condition: "{phase completion condition}"

    tasks:
      - id: "1-1"
        title: "{task title}"
        estimated_effort: "small"  # small | medium | large
        depends_on: []

        guide:
          objective: "{objective of this task}"
          strategy: "{approach method}"
          target_files:
            - path: "{file path}"
              action: "{modify/create/delete}"
          reference: "{PRD section reference}"
          context: "{relationship explanation with adjacent tasks}"

        acceptance_criteria:
          - "{verification condition 1}"
          - "{verification condition 2}"

        guardrails:
          scope:
            - "{modifiable scope}"
          decisions:
            - "{rules to follow}"

        prohibitions:
          - "{prohibition}"

    milestone:
      gate: "{milestone pass condition}"
      requires_approval: true
      report_includes:
        - "completed tasks summary"
        - "changed files list"
        - "issues/decisions log"
        - "next phase overview"
```

## Field Descriptions

### guide

| Field | Required | Description |
|-------|----------|-------------|
| objective | Required | What state should exist when this task is complete |
| strategy | Recommended | What approach to use |
| target_files | Required | Which files to target |
| reference | Recommended | Which PRD section to reference |
| context | Recommended | Relationship with previous/subsequent tasks |

A guide is a "navigation aid." It must be specific and actionable.

Bad example: "Add a model"
Good example: "Add a Post model below the model User {} block in the src/schema.prisma file. Follow the field list from PRD §3.2."

### acceptance_criteria

Express as executable commands whenever possible:
- "Run npm test -- --grep 'User model' and 3 tests pass"
- "Run prisma validate with no errors"
- "curl localhost:3000/api/users responds with 200"

When not executable, use verifiable conditions:
- "User interface is defined in src/models/user.ts"
- "All fields have explicit types"

### guardrails vs prohibitions

| | guardrails (soft) | prohibitions (hard) |
|---|---|---|
| On violation | Warning then correction | Immediate stop |
| Purpose | Direction guidance | Absolute prohibition |
| Example | "Only modify schema.prisma" | "Do not run migrations" |

### estimated_effort

| Value | Meaning | Approximate Time |
|-------|---------|-----------------|
| small | 1 file, simple change | ~15 min |
| medium | 1-3 files, includes logic | ~30 min |
| large | 3+ files, complex logic | ~1 hour |

If it exceeds large, the task must be split.

### depends_on

An array of prerequisite task IDs. All prerequisite tasks must be completed before this task can execute.
If there are no dependencies, use an empty array `[]`.

Dependency rules:
- Dependencies only between tasks within the same phase (cross-phase dependencies use milestones)
- Circular dependencies prohibited
- Tasks without dependencies have free ordering (can execute in parallel)
