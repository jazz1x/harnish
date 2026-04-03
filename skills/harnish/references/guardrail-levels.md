# Guardrail Level Classification Guide

> Criteria for classifying guardrails into soft (warning) and hard (prohibition).
> Prohibiting everything leads to rigidity; warning about everything leads to being ignored.
> Proper balance is key.

---

## Classification Criteria

### Hard (Prohibitions) — Immediate Stop

If any of the following conditions apply, classify as hard:

| Condition | Example |
|-----------|---------|
| **Irreversible outcome** | DROP TABLE, permanent file deletion, production data modification |
| **Security risk** | Hardcoded passwords, authentication bypass |
| **Data integrity risk** | Schema change without migration, reference without FK constraint |
| **Clear scope deviation** | Modifying files completely unrelated to current task |
| **Explicit user prohibition** | "Never do ~", "Don't touch ~" |

### Soft (Guardrails) — Warning Then Correction

If the following conditions apply, classify as soft:

| Condition | Example |
|-----------|---------|
| **Reversible outcome** | Code style violation, unnecessary log addition |
| **Preference matter** | Function length, variable naming, comment style |
| **Optimization related** | N+1 queries, unnecessary rendering |
| **Structural recommendation** | Directory structure, module separation |

### Gray Area — Context-Dependent

| Situation | Classification |
|-----------|---------------|
| Installing new package | OK if specified in PRD, hard if not |
| Modifying existing tests | Soft if due to feature change, hard if unrelated |
| Code refactoring | Soft if within current task scope, hard if outside scope |

---

## Violation Action Flow

### Soft Violation

```
1. Log warning message (record in harnish-current-work.json issue log)
2. Auto-correction action by violation type:

   100+ line file change:
     → Cannot auto-correct. Warning log + suggest task splitting to user.
     → Continue current task until user responds.

   Attempting Done without tests:
     → Cannot auto-correct. Reject Done transition.
     → Escalation: "Task {id} has no tests. Please add acceptance_criteria."

   Task without acceptance_criteria:
     → Cannot auto-correct. Reject Done transition.
     → Escalation: "Task {id}'s acceptance_criteria is empty."

   Referencing out-of-scope file (read only):
     → Auto-correct: Log warning only and continue.

   Modifying out-of-scope file:
     → Cannot auto-correct. Rollback modification.
     → Escalation: "Task {id} is attempting to modify out-of-scope file {path}."

   Code style/optimization/structural recommendations:
     → Auto-correct: If possible, correct immediately and continue.
     → If correction not possible: Log warning only and continue.

3. If the same violation repeats 3+ times: Notify the user.
```

### Hard Violation

```
1. Immediately stop (do not commit in-progress changes)
2. Add to harnish-current-work.json violation records
3. Escalate to user
4. User decision:
   - "Allow exception" → Record reason and continue
   - "Maintain prohibition" → Explore alternative path
   - "Redesign task" → Modify seeding
```

---

## Extracting Guardrails from PRD

When parsing guardrails from PRD §7:

1. "absolutely", "prohibited", "never", "must not" → hard candidate
2. "recommended", "preferred", "if possible", "should" → soft candidate
3. If no explicit level, classify using the criteria table above
4. If uncertain, classify as soft (flexibility is better than rigidity)

## Mapping Existing asset-recorder Guardrails

The `level` field of guardrail assets recorded in asset-recorder:
- `hard` → remains hard
- `soft` → remains soft
- Missing → read the content and classify using the criteria above
