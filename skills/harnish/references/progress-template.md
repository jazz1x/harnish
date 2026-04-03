# harnish-current-work.json Schema

> Structure referenced when the harnish skill creates/updates harnish-current-work.json.
> This file is the core of cross-session context preservation.

---

## JSON Schema

```json
{
  "metadata": {
    "prd": "docs/prd-{slug}.md",
    "started_at": "YYYY-MM-DDTHH:MM:SS+09:00",
    "last_session": "YYYY-MM-DDTHH:MM:SS+09:00",
    "status": {
      "emoji": "🟢",
      "phase": 1,
      "task": "1-1",
      "label": "Progressing normally"
    }
  },
  "done": {
    "phases": [
      {
        "phase": 1,
        "title": "Phase title",
        "compressed": false,
        "milestone_approved_at": "YYYY-MM-DDTHH:MM:SS+09:00",
        "tasks": [
          {
            "id": "1-1",
            "title": "Task title",
            "result": "What was done — one line",
            "files_changed": ["file1", "file2"],
            "verification": "How it was verified — command or condition",
            "duration": "Approximate number of turns or time"
          }
        ]
      }
    ]
  },
  "doing": {
    "task": null
  },
  "todo": {
    "phases": [
      {
        "phase": 2,
        "title": "Phase title",
        "tasks": [
          {
            "id": "2-1",
            "title": "Task title",
            "depends_on": []
          }
        ]
      }
    ]
  },
  "issues": [],
  "violations": [],
  "escalations": [],
  "stats": {
    "total_phases": 0,
    "completed_phases": 0,
    "total_tasks": 0,
    "completed_tasks": 0,
    "issues_count": 0,
    "violations_count": 0
  }
}
```

## Field Descriptions

### metadata.status

| emoji | Meaning |
|-------|---------|
| 🟢 | Progressing normally |
| 🟡 | In progress but has issues |
| 🔴 | Blocker occurred, escalation needed |
| ✅ | Fully complete |

### doing.task

An object if there is an active task, `null` otherwise.

```json
{
  "id": "1-2",
  "title": "Create API endpoint",
  "started_at": "YYYY-MM-DDTHH:MM:SS+09:00",
  "current": "What is being done right now",
  "last_action": "Most recently performed action",
  "next_action": "What to do immediately next",
  "blocker": null,
  "retry_count": 0,
  "context": {
    "guide": "guide.objective summary",
    "scope": "guardrails.scope summary",
    "prd_reference": "PRD §4.1"
  }
}
```

### done.phases[] — Compressed Phase

```json
{
  "phase": 1,
  "title": "Data model",
  "compressed": true,
  "compressed_summary": "tasks:4 | files:src/models/*.ts",
  "archive_ref": ".progress-archive/phases.jsonl#phase=1"
}
```

---

## Update Rules

### On Task Start

1. Remove the task from `todo.phases[].tasks[]`
2. Set the task object in `doing.task` (including started_at, context)
3. Update `metadata.status`

### Every 3 Actions

Update `current`, `last_action`, `next_action` in `doing.task`.
This update serves as a restore point in case of session interruption.

### On Task Completion

1. Add `doing.task` to `done.phases[].tasks[]` (including result, files_changed, verification, duration)
2. Set `doing.task` to `null`
3. Increment `stats.completed_tasks`
4. If milestone, generate checkpoint report

### On Error

1. Add to `issues[]`
2. Set `doing.task.blocker`
3. Increment `doing.task.retry_count`

### On Milestone Reached

1. Update `stats`
2. Generate checkpoint report (progress-report.sh)
3. Request user approval
4. Record `done.phases[].milestone_approved_at`

### On Session Start

1. Read harnish-current-work.json
2. If `doing.task` is non-null, resume from `next_action`
3. If `doing.task` is null, select next task from `todo.phases`
4. Brief report to user
