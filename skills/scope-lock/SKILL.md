---
name: scope-lock
description: Use when starting execution after an approved plan — before writing any code — to establish a boundary contract, flag scope drift during implementation, and log all scope change decisions for post-task review
---

# Scope Lock

Generates a boundary contract from an approved plan. Every scope deviation is flagged, decided, and logged to `SCOPE.md`.

**Violating the letter of these rules IS violating the spirit of these rules.**

## Phase 1: Contract (BEFORE any code)

Do NOT write implementation until SCOPE.md is ACTIVE: read plan → draft SCOPE.md → present to user → wait for approval → set ACTIVE → begin.

## Phase 2: Drift Enforcement

Flag before touching unlisted files, adding features, refactoring adjacent code, or hitting ambiguity.

**Agent drift:** `⚠️ SCOPE CHECK — Category: [dependency|emergent|opportunistic|ambiguity] | What: [action] | Why: [reason] | Decision: Permit/Decline/Defer`

**User expansion:** `↩️ SCOPE NOTE: "[request]" wasn't in contract. Proceeding if confirmed — or log as follow-up?`

Write log entry only after user response.

## Phase 3: Close

Triggered ONLY by explicit user signal. Update: `**Status:** CLOSED — N changes logged`

## SCOPE.md Template

````markdown
# Scope Contract
**Task:** [plan title]
**Plan:** [path to plan document]
**Date:** [YYYY-MM-DD]
**Status:** DRAFT | ACTIVE | CLOSED — [summary]

## In Scope
- **Files:** [from plan]
- **Features / Acceptance Criteria:** [from plan]
- **Explicit Boundaries:** [constraints from brainstorming]

## Out of Scope (Explicit)
- [Consciously excluded at planning time]
- [Items added via Decline decisions — NOT Deferred items]

---

# Scope Change Log

| # | Category | What | Why | Decision | Outcome |
|---|----------|------|-----|----------|---------|

---

# Follow-up Tasks
- [ ] [Description] — from scope change #N
````

## Categories

`dependency` · `emergent` · `opportunistic` · `ambiguity` · `user-expansion`

Permit → log + continue. Decline → log. Defer → log + add Follow-up Task.

## Common Rationalizations

| Phrase | Pattern | What it actually means |
|--------|---------|------------------------|
| "While I'm here anyway" / "since I'm already in this area" | Opportunistic proximity | Convenience is not permission — flag it |
| "It's clearly related" | Relatedness as implicit permission | Relatedness does not equal in-scope — flag it |
| "It's only [small thing]" | Minimization to bypass review | Size does not determine scope — flag it |
| "You asked for it" / user authority invoked | Authority as automatic override | User-initiated work still gets a soft flag |
| "The plan is already approved" | Prior approval as license to skip contract | Plan approval does not waive contract generation |
| Immediate execution without surfacing scope decisions | Skipping the contract phase entirely | Stop — generate SCOPE.md before writing any code |

## What Scope Lock Is Not

Not a hard gate (behavioral, not mechanical). High `ambiguity`/`emergent` rates signal spec weakness — not skill failure. The log is a decision record, not a scorecard.
