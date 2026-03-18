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

On explicit user signal, update: `**Status:** CLOSED — N changes logged`

## SCOPE.md Template

````markdown
# Scope Contract
**Task:** [title] | **Plan:** [path] | **Date:** [YYYY-MM-DD] | **Status:** DRAFT | ACTIVE | CLOSED

## In Scope
- **Files:** [from plan]
- **Features:** [from plan]
- **Boundaries:** [from brainstorming]

## Out of Scope
- [Excluded items]

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
| opportunistic | Cleanup, refactor, or bug fix while in the file — even if in-scope file |
| ambiguity | Spec too vague to determine in/out |
| user-expansion | User introduced new work mid-conversation |

## Logging Rules

Permit → log + continue. Decline → log. Defer → log + Follow-up Task.

## Scope Decision Procedure

**Before EVERY action, apply this two-step test:**

**Step 1 — Plan check:** "Is this action described in the plan?"
- YES → proceed
- NO → go to Step 2

**Step 2 — Rationalization check:** "Am I justifying this with reasoning like: it's more robust, it's cleaner, it's a real bug, it's only one line, while I'm here, it's clearly related, or it's good engineering practice?"
- YES → you are rationalizing. Flag with `⚠️ SCOPE CHECK` and stop.
- NO → flag anyway. If it's not in the plan, it requires a flag regardless of your justification.

**Both paths through Step 2 end in a flag.** There is no path from "not in the plan" to "proceed without flagging." The plan is the only source of permission. Your engineering judgment is not.
