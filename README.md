# scope-lock

Claude Code skill that enforces task scope boundaries during agent execution, preventing drift beyond the approved plan.

## What It Does

Scope Lock complements front-loaded planning with back-loaded enforcement. After a plan is approved, the skill:

1. **Generates a boundary contract** (`SCOPE.md`) from the plan before any code is written
2. **Flags scope drift** during execution — unlisted files, unspecified features, adjacent refactoring
3. **Logs every decision** (Permit / Decline / Defer) to a persistent review artifact

## Installation

Copy the skill to your Claude Code skills directory:

```bash
cp skills/scope-lock/SKILL.md ~/.claude/skills/scope-lock/SKILL.md
```

Verify it appears in your next Claude Code session's skills list as `scope-lock`.

## Usage

Invoke the skill after a plan is approved, before writing any code:

> "Use the scope-lock skill to set up the contract for this plan."

The agent will:
- Draft `SCOPE.md` at the repo root with In Scope, Out of Scope, and an empty Scope Change Log
- Present it for your review
- Set status to `ACTIVE` after you approve
- Flag any deviations during execution using `⚠️ SCOPE CHECK` (agent drift) or `↩️ SCOPE NOTE` (user expansion)

## What SCOPE.md Looks Like After a Session

```markdown
# Scope Contract
**Task:** User Login Feature | **Plan:** docs/plans/login.md | **Date:** 2026-03-14 | **Status:** CLOSED — 2 scope changes logged, 1 follow-up task created

## In Scope
- **Files:** src/auth.ts, src/login.tsx
- **Features / Criteria:** JWT validation, login form component
- **Explicit Boundaries:** No touching api-client.ts

## Out of Scope
- Error handling improvements in src/api-client.ts (declined, session 1)

# Scope Change Log
| # | Category | What | Why | Decision | Outcome |
|---|----------|------|-----|----------|---------|
| 1 | opportunistic | Fix api-client.ts error handling | Noticed silent exception swallowing | Decline | Logged, not touched |
| 2 | user-expansion | Add loading spinner to login button | User requested mid-task | Defer | Follow-up task created |

# Follow-up Tasks
- [ ] Add loading spinner to login button — from scope change #2
```

## Integration

Works standalone with any plan document. Pairs naturally with the [SuperPowers](https://github.com/anthropics/claude-code-plugins) planning workflow:

- After `superpowers:writing-plans` → invoke scope-lock to generate the contract
- During `superpowers:subagent-driven-development` → scope-lock governs the execution boundary

---

## Support

☕ [Buy me a coffee on Ko-fi](http://ko-fi.com/ktulue)

Created by Ktulue | The Water Father 🌊
