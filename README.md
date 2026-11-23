# scope-lock

Claude Code skill that enforces task scope boundaries during agent execution, preventing drift beyond the approved plan.

> AI coding agents are great at executing plans — and also great at quietly expanding them. Scope Lock keeps them honest.

## What It Does

Scope Lock complements front-loaded planning with back-loaded enforcement. After a plan is approved, the skill:

1. **Generates a boundary contract** (`SCOPE.md`) from the plan before any code is written
2. **Flags scope drift** during execution — unlisted files, unspecified features, adjacent refactoring
3. **Logs every decision** (Permit / Decline / Defer) to a persistent review artifact

## Installation

Install via the Claude Code plugin system (requires Claude Code with plugin support):
```
/plugin marketplace add Ktulue/scope-lock
/plugin install scope-lock@scope-lock
```

That's it. The `scope-lock` skill will be available in your next Claude Code session.

### Manual install (fallback)

If plugin support isn't available, copy the skill directly:
```bash
cp skills/scope-lock/SKILL.md ~/.claude/skills/scope-lock/SKILL.md
```

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

## Evaluation

scope-lock ships with an eval suite that measures drift-detection accuracy across synthetic scenarios: false negatives (drift it should flag) and false positives (in-scope work it shouldn't).

- **pipe-basic:** runs each scenario through `claude -p` and checks for the expected `⚠️ SCOPE CHECK` / `↩️ SCOPE NOTE` markers.
- **pipe-enriched:** adds realistic conversation history and scores responses with an LLM-as-judge rubric.

See [`eval/README.md`](eval/README.md) to run it.

## Integration

Works standalone with any plan document. Pairs naturally with [Superpowers](https://github.com/obra/superpowers) by Jesse Vincent (install with `/plugin install superpowers@claude-plugins-official`):

- After `superpowers:writing-plans` → invoke scope-lock to generate the contract
- During `superpowers:subagent-driven-development` → scope-lock governs the execution boundary

### Works with

scope-lock fits any workflow with an approved plan followed by a separate execution step: it sits between the two.

| Workflow | When to invoke scope-lock | Contract comes from | Deferred items go to |
|---|---|---|---|
| [Superpowers](https://github.com/obra/superpowers) | After `writing-plans`, before `subagent-driven-development` | The written plan | Follow-up Tasks in `SCOPE.md` |
| [OpenSpec](https://github.com/Fission-AI/OpenSpec) | After `/openspec-propose`, before `/openspec-apply-change` | `proposal.md`, `tasks.md`, and spec deltas in `openspec/changes/<name>/` | A new change proposal; archive the closed `SCOPE.md` with the change at `/openspec-archive-change` |
| [Spec Kit](https://github.com/github/spec-kit) | After the `tasks` step, before `implement` | `plan.md` and `tasks.md` in `specs/<feature>/` | A new feature spec |
| Claude Code [plan mode](https://code.claude.com/docs/en/permission-modes) | Right after you approve the plan, before any edits | The approved plan | Follow-up Tasks in `SCOPE.md` |
| Ticket-driven (Jira, Linear) | When work on a ticket starts | The ticket's acceptance criteria | A linked follow-up ticket |

---

## Support

☕ [Buy me a coffee on Ko-fi](http://ko-fi.com/ktulue)

Created by Ktulue | The Water Father 🌊
