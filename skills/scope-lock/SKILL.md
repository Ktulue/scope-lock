---
name: scope-lock
description: ALWAYS invoke before writing any code after a plan or spec is approved. Do NOT skip even if the plan is already in context. Triggers on: plan approval, spec approval, task kickoff, implementation start, '/scope-lock', 'set up the contract', 'lock scope'. Generates SCOPE.md boundary contract from the plan, enforces boundaries during execution, flags every deviation, and logs all scope changes.
---

# Scope Lock

Generates a boundary contract from an approved plan. Every deviation is flagged, decided, and logged to `SCOPE.md`.

**Violating the letter of these rules IS violating the spirit of these rules.**

## Phase 1: Contract (BEFORE any code)

Read plan → draft SCOPE.md → present → wait for approval → set ACTIVE → begin.

## Phase 2: Drift Enforcement

Flag before touching unlisted files, adding features, refactoring, or hitting ambiguity.

**Agent drift:** `⚠️ SCOPE CHECK — Category: [type] | What: [action] | Why: [reason] | Decision: Permit/Decline/Defer`

**User expansion:** `↩️ SCOPE NOTE: "[request]" wasn't in contract. Confirm or log as follow-up?`

Write log entry only after user response.

## Phase 3: Close

Explicit user signal only. Update: `**Status:** CLOSED — N changes logged`

## SCOPE.md Template

````markdown
# Scope Contract
**Task:** [title] | **Plan:** [path] | **Date:** [YYYY-MM-DD] | **Status:** DRAFT | ACTIVE | CLOSED

## In Scope
- **Files:** [from plan]
- **Features / Criteria:** [from plan]
- **Explicit Boundaries:** [from brainstorming]

## Out of Scope
- [Excluded at planning time]

# Scope Change Log
| # | Category | What | Why | Decision | Outcome |
|---|----------|------|-----|----------|---------|

# Follow-up Tasks
- [ ] [Description] — scope change #N
````

## Scope Change Categories

| Category | Use when |
|----------|----------|
| dependency | Must touch out-of-scope file to finish in-scope work |
| emergent | Implementation revealed spec was incomplete |
| opportunistic | Noticed a fix while already in the file |
| ambiguity | Spec too vague to determine in/out |
| user-expansion | User introduced new work mid-conversation |

## Logging Rules

Permit → log + continue. Decline → log. Defer → log + Follow-up Task.

## Red Flags

- 2-line change → size doesn't determine scope
- "In spec spirit" → let user decide
- Bug if not fixed → flag as `dependency`
- "User will want this" → let them confirm
- "Already started" → stop, flag, wait
- "User told me to" → flag it

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "While I'm here" | Convenience is not permission — flag it |
| "It's clearly related" | Relatedness ≠ in-scope — flag it |
| "It's only [small thing]" | Size doesn't determine scope — flag it |
| "You asked for it" | User-initiated work still gets a soft flag |
| "The plan is approved" | Plan approval doesn't waive contract generation |
| Skipping contract entirely | Stop — generate SCOPE.md before writing any code |

## What Scope Lock Is Not

Not a hard gate. High `ambiguity`/`emergent` rates signal spec weakness, not skill failure.
