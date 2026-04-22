# Escalation Protocol

> The procedure for harnish to request user judgment.
> Escalation means "stopping when you should stop." Asking quickly is better than looping infinitely.

---

## Escalation Triggers

### 1. Repeated Task Failure (3 times)

Escalate when the same type of error repeats 3 times on the same task.

Report format:
```
⚠️ Task {id}: Repeated failure on {title} (3 times)

Problem: {specific error message/symptom}

Attempted:
1. {first attempt and result}
2. {second attempt and result}
3. {third attempt and result}

Possible causes:
- {cause A}
- {cause B}

Suggestions:
- {proposed solution, if any}
- Or "PRD section {section} may need to be revised"

How should we proceed?
```

### 2. Prohibition Violation Required

When completing a task appears to unavoidably require an action that falls under a prohibition.

Report format:
```
🔴 An action matching prohibition [{id}] is required

Prohibition: {rule}
Current task: Task {id}: {title}

Reason: {why this action is necessary}
Impact: {what happens if this action is taken}

Alternative: {present another method that does not violate the prohibition, if available}

Should we allow an exception, or try the alternative?
```

### 3. PRD and Reality Mismatch

When a PRD assumption is discovered to be incorrect during implementation.

Report format:
```
⚠️ PRD does not match reality

PRD §{N} assumption: {what the PRD assumed}
Actual situation: {what was actually confirmed}

Impact: {how this discrepancy affects implementation}

Suggestions:
- Revise PRD §{N} to {this}
- Or adjust current implementation to {this}

How should we proceed?
```

### 4. Out-of-Scope Work Required

When files/areas not in the current task's scope need to be modified.

Report format:
```
⚠️ Work outside current task scope is required

Current task: Task {id}: {title}
Scope: {guardrails.scope}

Required changes:
- File: {out-of-scope file}
- Reason: {why this file needs to be modified}

Options:
1. Expand scope in the current task and modify
2. Separate into a new task (add as a prerequisite task)
3. Do not modify and try a different approach

Which direction should we take?
```

---

## Escalation Principles

### Stop When You Should Stop

The biggest failure mode of escalation is "continuing to try without asking."
The 3-failure rule is absolute — do not make a 4th attempt.

### Report Specifically

"An error occurred" is a bad escalation.
"TypeError: Cannot read property 'id' of undefined at src/api.ts:42. The cause is that the id field in the User model is nullable but the API assumes it to be non-null" is a good escalation.

### Include Suggestions

Suggesting solutions is better than only reporting problems.
However, if uncertain, express them as "possible causes" and "things to try."

### Prevent Duplicate Escalations

Do not escalate twice for the same problem.
Record the user's response in the harnish-current-work.json issue log and reference it in the same situation.
