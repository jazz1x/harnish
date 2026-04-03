# Design Decision Writing Guide

> Guide referenced by the drafti-architect skill when writing the §2 Design Decision section of a PRD.

## Why Design Decisions Matter

The most expensive cost in technical work is "changing the design midway."
The design decision section exists to reduce this cost:

1. **Explore alternatives in advance** to prevent "we should have tried this too" later
2. **Record selection rationale** to be able to answer "why did we do it this way?" later
3. **Specify validity conditions** to identify when to revisit if circumstances change

## How to Explore Alternatives

### Minimum 2 Alternatives Required

Even if there appears to be an "obvious right answer," always explore at least one more alternative.
Explaining why the obvious answer is correct is also a valuable design decision.

### Alternative Discovery Checklist

- **Existing tools/libraries**: Can this be solved with something that already exists?
- **Build from scratch**: What if we build it without external dependencies?
- **Architecture change**: Is there a fundamentally different approach?
- **Status quo**: How bad is it really if we leave it as is?
- **Phased approach**: What if we keep it simple now and extend later?

### Required Analysis Items Per Alternative

| Item | Description |
|------|------|
| Approach | How it works (3~5 lines) |
| Pros | Why this is good |
| Cons | Cost, risk, limitations |
| Suitable situation | Under what conditions is this the best choice |

## Trade-off Analysis Patterns

### Pattern 1: Quantitative Comparison (when possible)

```
Alternative A: Implementation ~2 days, maintenance ~10 hrs/year, dependencies +1
Alternative B: Implementation ~4 days, maintenance ~2 hrs/year, dependencies +0
→ If maintained for 6+ months, B is advantageous (break-even ~4 months)
```

### Pattern 2: Value Axis Comparison (when quantification is difficult)

```
              Simplicity  Scalability  Performance  Maintenance
Alternative A:   ★★★         ★            ★★          ★★★
Alternative B:   ★           ★★★          ★★★         ★★
→ Within current requirements scope, prioritize simplicity → select A
→ Revisit B if requirements expand significantly
```

### Pattern 3: Risk-Based

```
Alternative A: Proven method, low risk, but accumulates tech debt
Alternative B: New approach, medium risk, cleaner long-term
→ Rollback feasibility: A is immediate, B requires migration
→ Judgment: Tech debt level is still manageable so A; switch to B when debt reaches threshold
```

## Selection Rationale Writing Principles

1. **Instead of "~is better," use "given ~situation, we select ~"**
   - Bad example: "Alternative A is better"
   - Good example: "Considering the current team size (2 people) and project lifespan (6 months), A's simplicity matters more"

2. **Specify validity conditions**
   - "This decision is valid under {condition}"
   - "Revisiting is needed if {condition} changes"

3. **Respect rejected alternatives**
   - Rejected alternatives are not bad, just "not fitting the current situation"
   - Specify under what circumstances the rejected alternative could be a better choice

## Asset Integration

Once a design decision is finalized, record it as a decision asset.
Decisions recorded this way are utilized as reference assets for similar problems in the future.

Include when recording:
- The decision (one sentence)
- Considered alternatives (briefly)
- Selection rationale
- Validity conditions

If a previously recorded decision asset is related to the current problem,
mention it in PRD §2 as "prior decision reference."
This avoids repeating the same judgment and provides an opportunity to review whether the prior judgment is still valid.
