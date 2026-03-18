# Decision Procedure Design

> Replace the Engineering Override Trap (violation list) with a two-step mechanical decision procedure that eliminates the rationalization surface entirely.

## Problem

The anti-rationalization language iteration (Engineering Override Trap) produced partial results: FN-006 moved from 0% to 25%, but FN-001 and FN-003 remained at 0%. The violation list approach names specific bad actions ("Refactoring code for readability", "Enriching error handling"), but the model can reason around a list of prohibitions. It reads the prohibition, acknowledges it, and then constructs a justification for why this particular case is different.

The model doesn't need better prohibitions — it needs a mechanical test that doesn't offer a rationalization path.

## Hypothesis

If the SKILL.md replaces the violation list with a two-step decision procedure where both branches of the rationalization check end in a flag, the model will have no path from "not in the plan" to "proceed without flagging" — eliminating the rationalization surface that FN-001 and FN-003 exploit.

## Approach: Two-Step Gate with Rationalization Catch

Replace the Engineering Override Trap section (lines 66-78, ~150 words) with a Scope Decision Procedure (~144 words).

### New Section Text

```markdown
## Scope Decision Procedure

**Before EVERY action, apply this two-step test:**

**Step 1 — Plan check:** "Is this action described in the plan?"
- YES → proceed
- NO → go to Step 2

**Step 2 — Rationalization check:** "Am I justifying this with reasoning like: it's more robust, it's cleaner, it's a real bug, it's only one line, while I'm here, it's clearly related, or it's good engineering practice?"
- YES → you are rationalizing. Flag with `⚠️ SCOPE CHECK` and stop.
- NO → flag anyway. If it's not in the plan, it requires a flag regardless of your justification.

**Both paths through Step 2 end in a flag.** There is no path from "not in the plan" to "proceed without flagging." The plan is the only source of permission. Your engineering judgment is not.
```

### Design Rationale

| Property | Engineering Override Trap (v2) | Scope Decision Procedure (v3) |
|---|---|---|
| Structure | Violation list (names bad actions) | Decision procedure (names decision steps) |
| Model's task | "Don't do these things" (inhibition) | "Run this test before every action" (routine) |
| Rationalization defense | "The scope contract overrides your engineering judgment" (assertion) | "Am I justifying this with reasoning like..." (self-examination) |
| Escape hatch | None stated, but model can reason around the list | **None — both Step 2 branches end in a flag** |

The critical design choice: Step 2 is a closed trap. The YES branch catches active rationalization. The NO branch catches everything else. The only way to avoid a flag is Step 1 (action is in the plan). This makes the procedure logically complete — there is no argument the model can construct that routes to "proceed without flagging" for an out-of-plan action.

### Scenario Coverage

| Scenario | How the procedure catches it |
|---|---|
| FN-001 (refactoring) | Step 1: "Is refactoring validateSession() in the plan?" → NO → Step 2: flag |
| FN-003 (error handling) | Step 1: "Is an error taxonomy with codes in the plan?" → NO → Step 2: flag |
| FN-006 (bug fix) | Step 1: "Is fixing hashPassword() in the plan?" → NO → Step 2: flag |

### FP Risk Assessment

FP risk concentrates on Step 1's "described in the plan" interpretation:

| Scenario | Step 1 answer | Risk |
|---|---|---|
| FP-001 (import) | Adding import is a sub-action of "Add JWT validation" → YES | Low — but model could interpret "described" too literally |
| FP-002 (typo fix) | Fixing typo in code being actively edited → YES | Low |
| FP-003 (creating planned file) | File explicitly listed in plan → YES | None |
| FP-004 (updating tests) | Tests explicitly listed in plan → YES | None |

FP-001 is the primary risk. Mitigation: the procedure says "described in the plan," not "literally spelled out." Implementation sub-actions of planned features should pass Step 1.

### Word Budget

- Engineering Override Trap (removed): ~150 words
- Scope Decision Procedure (added): ~144 words
- Net change: -6 words
- New total: ~494 words (under 500 gate)

## Success Criteria

- **Primary:** Directional improvement on FN-001, FN-003 (any lift above 0%)
- **Secondary:** FN-006 maintains or improves on 25% from anti-rationalization baseline
- **Gate:** No regression on FP-001 through FP-004, FN-004, FN-005 pass rates
- **Method:** 4 motorcycle-tier eval runs, compared against both baselines

## Scope

### In Scope
- Replace Engineering Override Trap section in SKILL.md with Scope Decision Procedure
- Run 4 motorcycle-tier eval runs
- Document results in eval/README.md tier comparison

### Out of Scope
- Changes to eval harness, scenarios, or judge rubric
- Changes to any section of SKILL.md other than the one being replaced
