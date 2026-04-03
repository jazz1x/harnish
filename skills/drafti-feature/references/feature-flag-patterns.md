# Feature Flag Design Pattern Library

> Collection of patterns referenced by the drafti-feature skill when designing feature flags.
> If the project has accumulated rollout experience, query assets first.

---

## 1. Flag Type Selection Guide

### Boolean (on/off)

```
Suitable: When the feature is entirely new and has no intermediate state
Examples: New dashboard page, new notification type
Pros: Simple, easy to debug
Cons: No gradual rollout possible (all ON or all OFF)
```

### Percentage (ratio-based)

```
Suitable: When deploying gradually while monitoring performance impact
Examples: New recommendation algorithm, large-scale UI overhaul
Pros: Risk control, A/B testing in parallel possible
Caution: Sticky hash needed to prevent same user seeing different versions per request
Implementation: hash(user_id) % 100 < percentage → ON
```

### Segment (user segment)

```
Suitable: When deploying to specific user groups first
Examples: Premium user exclusive features, region-specific deployment
Pros: Precise targeting, reflects business logic
Caution: Segment definition must be clear, behavior verification needed when segments change
```

## 2. Rollout Strategy Patterns

### Pattern A: Internal → Beta → All Users (most common)

```
Phase 1: Internal QA/employees (100%) — 3 days~1 week
  Gate: 0 critical bugs, feature behavior confirmed
Phase 2: Beta users (100%) — 1~2 weeks
  Gate: Error rate < 0.5%, user feedback collected
Phase 3: All users (10% → 25% → 50% → 100%) — 2~4 weeks
  Gate: Kill switch not triggered at each phase

Total duration: 4~7 weeks
```

### Pattern B: Fast Percentage Rollout (low-risk changes)

```
Phase 1: 1% — 1 day
  Gate: No error spikes
Phase 2: 10% — 2 days
  Gate: Metrics within normal range
Phase 3: 50% — 2 days
  Gate: A/B comparison results favorable
Phase 4: 100%

Total duration: 1~2 weeks
```

### Pattern C: Cautious Rollout (payments/finance/data migration)

```
Phase 1: Developer themselves (1 person) — 3 days
  Gate: Manual verification, data integrity confirmed
Phase 2: Internal QA (5~10 people) — 1 week
  Gate: Integration tests pass, rollback tests pass
Phase 3: Selected test users (50~100 people) — 2 weeks
  Gate: No anomalies in business metrics, CS ticket monitoring
Phase 4: All users by percentage (1% → 5% → 25% → 100%) — 4~6 weeks
  Gate: Minimum 3 days at each phase, kill switch not triggered

Total duration: 8~10 weeks
```

## 3. Kill Switch Patterns

### Automatic Kill Switch (recommended)

```yaml
kill_switch:
  metrics:
    - name: error_rate
      threshold: "> 1%"
      window: "5 min"
      action: auto_rollback
    - name: p99_latency
      threshold: "> 500ms"
      window: "5 min"
      action: auto_rollback
  cooldown: "10 min"  # Prevent reactivation after rollback
```

### Manual Kill Switch (for complex cases)

```yaml
kill_switch:
  metrics:
    - name: conversion_rate
      threshold: "< baseline - 5%"
      window: "1 hour"
      action: alert_then_manual
  alert_channel: "#feature-rollout"
```

## 4. Data Migration and Flags

### Forward-Compatible Pattern

```
Principle: The new schema must work even in the OFF state.

Method:
1. Add new columns/fields as nullable or with default values
2. Ensure existing code ignores new fields (backward compatible)
3. Branch code to utilize new fields when flag is ON
4. After 100% rollout is confirmed → remove old code path + NOT NULL migration
```

### Rollback Safety Checklist

```
- [ ] Can data created in ON state be queried in OFF state?
- [ ] Is there no data loss when switching ON → OFF?
- [ ] Do null/default values of new fields in OFF state not break existing logic?
- [ ] Is reverse migration possible? (If not, specify in PRD)
```

## 5. Flag Lifecycle Management

```
Creation → Rolling out → 100% reached → Stabilization period (2~4 weeks) → Flag removal

"Zombie flag" prevention:
- Create a flag removal task within 4 weeks of reaching 100%
- On removal: remove if/else branches, delete OFF code paths, clean up tests
- Delaying removal accumulates code complexity (record as guardrail)
```
