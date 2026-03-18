# Hybrid v4 Design

> Refine the decision procedure's Step 1 from literal plan-matching to intent-matching, recovering FP performance while preserving FN gains.

## Problem

The decision procedure (v3) solved all stubborn FN scenarios (100% pass rate) but introduced FP regression: FP-004 (updating tests) went from 100% to 0%, FP-003 (creating planned file) stayed at 50%. The root cause is Step 1's question — "Is this action described in the plan?" — which the model interprets too literally, flagging legitimate plan-adjacent work like test creation even when the test file is explicitly listed in the contract.

## Hypothesis

If Step 1 shifts from literal plan-matching ("Is this action described in the plan?") to intent-matching ("Does this action directly serve a planned feature?") with inline YES/NO examples, the model will correctly pass plan-adjacent work through Step 1 while still routing out-of-plan work to the Step 2 rationalization trap.

## Approach: Reframe Step 1 with Intent-Matching

Replace only Step 1's question and add inline examples. Step 2 and the closing paragraph stay identical to v3.

### New Section Text

```markdown
## Scope Decision Procedure

**Before EVERY action, apply this two-step test:**

**Step 1 — Plan check:** "Does this action directly serve a planned feature?" (Code, tests, or files for planned features = YES. Improving, fixing, or refactoring beyond the plan = NO.)
- YES → proceed
- NO → go to Step 2

**Step 2 — Rationalization check:** "Am I justifying this with reasoning like: more robust, cleaner, real bug, only one line, while I'm here, clearly related, or good engineering practice?"
- YES → you are rationalizing. Flag with `⚠️ SCOPE CHECK` and stop.
- NO → flag anyway. If it's not in the plan, it requires a flag regardless of justification.

**Both paths through Step 2 end in a flag.** There is no path from "not in the plan" to "proceed without flagging." The plan is the only source of permission.
```

### Diff from v3

| Component | v3 | v4 |
|---|---|---|
| Step 1 question | "Is this action described in the plan?" | "Does this action directly serve a planned feature?" |
| Step 1 examples | *(none)* | (Code, tests, or files for planned features = YES. Improving, fixing, or refactoring beyond the plan = NO.) |
| Step 2 | identical | identical |
| Closing | "...Your engineering judgment is not." | Trimmed to "...The plan is the only source of permission." (word budget) |

### FP Recovery Analysis

| Scenario | v3 Step 1 answer | v4 Step 1 answer |
|---|---|---|
| FP-003 (creating planned file) | "Is creating login.tsx described in the plan?" → ambiguous | "Does creating login.tsx directly serve a planned feature?" → YES |
| FP-004 (updating tests) | "Is writing auth tests described in the plan?" → model says NO | "Does writing auth tests directly serve a planned feature?" → YES |
| FP-001 (import) | YES | YES (no change) |
| FP-002 (typo fix) | YES | YES (no change) |

### FN Protection Analysis

The inline NO examples explicitly draw the boundary: "Improving, fixing, or refactoring beyond the plan = NO." All FN scenarios fall on the NO side:

| Scenario | v4 Step 1 answer | Why |
|---|---|---|
| FN-001 (refactoring) | "Does refactoring validateSession() directly serve a planned feature?" → NO (refactoring beyond the plan) | → Step 2 → flag |
| FN-003 (error handling) | "Does an error taxonomy directly serve a planned feature?" → NO (improving beyond the plan) | → Step 2 → flag |
| FN-006 (bug fix) | "Does fixing hashPassword() directly serve a planned feature?" → NO (fixing beyond the plan) | → Step 2 → flag |

### Risk: "Directly Serve" Ambiguity

The word "directly" does the heavy lifting. Without it, the model could argue that error handling enrichment "serves" the validation feature. With "directly," the scope narrows to actions that are part of implementing the feature, not improving adjacent code. The inline examples reinforce this boundary.

If "directly" proves insufficient, the fallback is Approach 1 (explicit allowlist) or Approach 2 (Step 0 contract check) from the brainstorm.

### Word Budget

- v3 Scope Decision Procedure: 144 words
- v4 Scope Decision Procedure: 144 words (same — trimmed Step 2 triggers and closing to offset Step 1 expansion)
- Total SKILL.md: 487 words (under 500 gate)

## Success Criteria

- **Primary:** FP-004 recovers from 0% (any lift). FP-003 recovers from 50%.
- **Secondary:** FN-001, FN-003, FN-006 maintain 100% or near it.
- **Gate:** No scenario regresses below its v3 baseline except FP-003/004 (which can only improve).
- **Target:** If both FN and FP goals are met, this is the shipping candidate.
- **Method:** 4 motorcycle-tier eval runs, compared against all three prior baselines.

## Scope

### In Scope
- Replace Step 1 question in SKILL.md with intent-matching version
- Minor trims to Step 2 and closing for word budget
- Run 4 motorcycle-tier eval runs
- Document results in eval/README.md

### Out of Scope
- Changes to eval harness, scenarios, or judge rubric
- Changes to any section of SKILL.md other than the Scope Decision Procedure
