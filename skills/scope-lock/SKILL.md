---
name: scope-lock
description: Before writing any code after an approved plan — establish a boundary contract, flag drift, and log scope decisions to SCOPE.md
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

Permit → log + continue. Decline → log. Defer → log + Follow-up Task.

## Red Flags — Stop and Flag

- "It's only a 2-line change" → size doesn't determine scope
- "It's clearly in the spirit of the spec" → let the user decide
- "It'll cause a bug if I don't fix it" → `dependency` category, flag it
- "The user will obviously want this" → let them confirm
- "I already started, might as well finish" → stop, flag, wait
- "The user told me to" → still gets a soft flag

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "While I'm here anyway" | Convenience is not permission — flag it |
| "It's clearly related" | Relatedness ≠ in-scope — flag it |
| "It's only [small thing]" | Size doesn't determine scope — flag it |
| "You asked for it" | User-initiated work still gets a soft flag |
| "The plan is already approved" | Plan approval doesn't waive contract generation |
| Skipping contract phase entirely | Stop — generate SCOPE.md before writing any code |

## What Scope Lock Is Not

Not a hard gate. High `ambiguity`/`emergent` rates signal spec weakness, not skill failure.
