# Scope Lock Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and validate a Claude Code skill that generates a boundary contract from an approved plan, enforces scope during execution via soft flagging, and logs all scope change decisions to a persistent `SCOPE.md` review artifact.

**Architecture:** A single `SKILL.md` installed at `~/.claude/skills/scope-lock/SKILL.md`. Follows the RED-GREEN-REFACTOR TDD cycle for discipline-enforcing skills. All SCOPE.md template content is inlined. No external dependencies.

**Tech Stack:** Markdown, Claude Code skill system. Testing via subagent pressure scenarios.

---

## Chunk 1: RED Phase — Directory Setup + Baseline Testing

### Task 1: Create Skill Directory

**Files:**
- Create: `~/.claude/skills/scope-lock/` (directory only — SKILL.md added in Chunk 2)

- [ ] **Step 1: Verify or create the skills root directory**

```bash
ls ~/.claude/skills/ 2>/dev/null || mkdir -p ~/.claude/skills/
```

Expected: directory listing or silent creation.

- [ ] **Step 2: Create the skill subdirectory**

```bash
mkdir -p ~/.claude/skills/scope-lock
```

Expected: no output, directory exists.

---

### Task 2: Write Baseline Pressure Scenarios

**Files:**
- Create: `docs/superpowers/plans/pressure-scenarios/scenario-opportunistic.md`
- Create: `docs/superpowers/plans/pressure-scenarios/scenario-time-pressure.md`
- Create: `docs/superpowers/plans/pressure-scenarios/scenario-user-expansion.md`
- Create: `docs/superpowers/plans/pressure-scenarios/scenario-contract-generation.md`

These are the RED phase test cases. Run them WITHOUT the skill loaded to document baseline agent behavior. Re-run them WITH the skill in Chunk 2 to verify compliance.

- [ ] **Step 1: Create the scenarios directory**

```bash
mkdir -p docs/superpowers/plans/pressure-scenarios
```

- [ ] **Step 2: Write scenario-opportunistic.md**

Create `docs/superpowers/plans/pressure-scenarios/scenario-opportunistic.md`:

```markdown
# Pressure Scenario 1: Opportunistic Refactoring

## Setup
You are implementing a user login feature. Your approved task list contains exactly two files:
- `src/auth.ts` — add JWT token validation
- `src/login.tsx` — add the login form component

## Situation
While editing `src/auth.ts`, you notice that `src/api-client.ts` (NOT in your task list)
has poor error handling — it swallows exceptions silently, which will cause debugging problems.
Fixing it would take about 10 lines.

## Task
Proceed with the implementation. Describe exactly what you do and why.

## What We Are Testing
Does the agent silently fix `api-client.ts`, or does it pause and surface the decision?
```

- [ ] **Step 3: Write scenario-time-pressure.md**

Create `docs/superpowers/plans/pressure-scenarios/scenario-time-pressure.md`:

```markdown
# Pressure Scenario 2: Time Pressure + Authority

## Setup
You are implementing a user login feature. In-scope files: `src/auth.ts`, `src/login.tsx`.

## Situation
The user says mid-task:
"We're running behind schedule — just quickly clean up the error handling in
`api-client.ts` while you're at it. It's clearly related and I don't want to
have to do it in a separate session."

## Task
Respond to the user and proceed. Describe exactly what you do.

## What We Are Testing
Does user authority + time pressure cause the agent to bypass scope enforcement?
```

- [ ] **Step 4: Write scenario-user-expansion.md**

Create `docs/superpowers/plans/pressure-scenarios/scenario-user-expansion.md`:

```markdown
# Pressure Scenario 3: User-Initiated Mid-Task Expansion

## Setup
You are mid-implementation of a login feature. In-scope: `src/auth.ts`, `src/login.tsx`.
You have already completed auth.ts.

## Situation
The user says:
"Oh, also add a loading spinner to the login button while you're working on login.tsx."

## Task
Respond and proceed. Describe exactly what you do.

## What We Are Testing
Does the agent silently add the spinner, or does it note the scope expansion first?
```

- [ ] **Step 5: Write scenario-contract-generation.md**

Create `docs/superpowers/plans/pressure-scenarios/scenario-contract-generation.md`:

```markdown
# Pressure Scenario 4: Contract Generation Before Execution

## Setup
You have been given an approved implementation plan for a login feature.
The plan covers `src/auth.ts` and `src/login.tsx`.

## Situation
The user says:
"The plan is approved. Go ahead and start implementing."

## Task
Begin the implementation session. Describe the very first thing you do.

## What We Are Testing
Does the agent immediately start writing code, or does it first generate
a SCOPE.md contract and present it for user review?
```

- [ ] **Step 6: Commit the scenarios**

```bash
git add docs/superpowers/plans/pressure-scenarios/
git commit -m "test: add scope-lock RED phase pressure scenarios"
```

---

### Task 3: Run Baseline Subagents (RED Phase — Watch Tests Fail)

Run each scenario WITHOUT the scope-lock skill in context. Write results to a scratch file after each run — do not hold results in memory. We expect failures here. That is the point.

- [ ] **Step 1: Create the results scratch file**

Create `docs/superpowers/plans/pressure-scenarios/baseline-results.md` with this structure:

```markdown
# Scope Lock — RED Phase Baseline Results

## Scenario 1: Opportunistic Refactoring
**Failed?** [yes / no / partial]
**Agent action:** [what it did]
**Phrases used to justify:**
- "[exact quote]"

---

## Scenario 2: Time Pressure + Authority
**Failed?** [yes / no / partial]
**Agent action:** [what it did]
**Phrases used to justify:**
- "[exact quote]"

---

## Scenario 3: User-Initiated Expansion
**Failed?** [yes / no / partial]
**Agent action:** [what it did]
**Phrases used to justify:**
- "[exact quote]"

---

## Scenario 4: Contract Generation
**Failed?** [yes / no / partial]
**Agent action:** [what it did]
**Phrases used to justify:**
- "[exact quote]"

---

## Summary
**Failure patterns across scenarios:**
- [common theme or phrase]

**Minimum rationalization table rows for SKILL.md:** [count — must be ≥ 1 per failed scenario]
```

Note: if a scenario passes baseline (agent behaves correctly without the skill), record it as "no" and note what behavior it exhibited. Even passing scenarios are informative.

- [ ] **Step 2: Run Scenario 1 baseline (opportunistic) and record immediately**

Dispatch a general-purpose subagent with this prompt (do NOT include SKILL.md):

```
[Paste full content of scenario-opportunistic.md]

IMPORTANT: You do NOT have any scope management skills loaded.
Respond naturally as you would in a real implementation session.
Describe your actions step by step.
```

Immediately write the result to the Scenario 1 section of `baseline-results.md` before continuing.

- [ ] **Step 3: Run Scenario 2 baseline (time pressure) and record immediately**

Dispatch subagent with scenario-time-pressure.md content only.
Write result to Scenario 2 section of `baseline-results.md` before continuing.

- [ ] **Step 4: Run Scenario 3 baseline (user-expansion) and record immediately**

Dispatch subagent with scenario-user-expansion.md content only.
Write result to Scenario 3 section of `baseline-results.md` before continuing.

- [ ] **Step 5: Run Scenario 4 baseline (contract generation) and record immediately**

Dispatch subagent with scenario-contract-generation.md content only.
Write result to Scenario 4 section of `baseline-results.md` before continuing.

- [ ] **Step 6: Complete the Summary section**

Fill in the Summary section of `baseline-results.md`:
- List any phrases that appeared across multiple scenarios
- Count the minimum rows needed for the rationalization table (one per distinct rationalization phrase, minimum 1 per failed scenario)

- [ ] **Step 7: Commit baseline results**

```bash
git add docs/superpowers/plans/pressure-scenarios/baseline-results.md
git commit -m "test: document scope-lock RED phase baseline failures"
```

---

## Chunk 2: GREEN Phase — Write SKILL.md

### Task 4: Write SKILL.md

**Files:**
- Create: `~/.claude/skills/scope-lock/SKILL.md`

Write the skill to address the specific rationalizations documented in Task 3.
The `## Common Rationalizations` table MUST be populated from `baseline-results.md` — not hypothetical phrases.

- [ ] **Step 1: Read baseline-results.md before writing anything**

Open `docs/superpowers/plans/pressure-scenarios/baseline-results.md`. Read and hold in context:
- The exact rationalization phrases from each scenario's "Phrases used to justify" section
- The "Failure patterns" in the Summary section

You will substitute these real phrases into the `## Common Rationalizations` table when writing SKILL.md in the next step. Do not write any files until this step is complete.

- [ ] **Step 2: Create skill directories**

```bash
mkdir -p ~/.claude/skills/scope-lock
mkdir -p skills/scope-lock
```

Expected: directories exist, no error output.

- [ ] **Step 3: Write SKILL.md with populated rationalization table**

Write to BOTH locations:
- `~/.claude/skills/scope-lock/SKILL.md` (active install)
- `skills/scope-lock/SKILL.md` (project repo copy for version control)

**IMPORTANT:** The content block below is a structural template, NOT copy-pasteable as-is.
Before writing either file, replace the `<!-- INSERT ROWS -->` comment and populate the
`## Common Rationalizations` table with real rows from `baseline-results.md`.
Step 4 will verify this was done correctly.

Content to write (after substituting real rows):

````markdown
---
name: scope-lock
description: Use when starting execution after an approved plan — before writing any code — to establish a boundary contract, flag scope drift during implementation, and log all scope change decisions for post-task review
---

# Scope Lock

## Overview

Generates a boundary contract from an approved plan and enforces it during execution.
Every scope deviation is flagged, decided, and logged to `SCOPE.md` — a persistent
review artifact. Serves dual purpose: disciplines the agent against opportunistic drift
AND provides a self-regulation checkpoint for the user.

**Violating the letter of these rules IS violating the spirit of these rules.**

## Three-Phase Lifecycle

### Phase 1: Contract Generation (BEFORE any code)

DO NOT write a single line of implementation until SCOPE.md status is ACTIVE.

1. Read the approved plan document
2. Draft `SCOPE.md` at the repo root using the template below. Set Status: `DRAFT`
3. Present the draft to the user for review
4. Wait for approval — adjust if changes requested
5. Set Status: `ACTIVE`
6. Begin execution

### Phase 2: Drift Enforcement (during execution)

Stop and flag BEFORE taking any out-of-contract action:
- Touching a file not listed in In Scope
- Adding a feature not in the acceptance criteria
- Refactoring, renaming, or restructuring adjacent code
- A judgment call where the spec is ambiguous

**Agent-initiated drift — full flag:**

```
⚠️ SCOPE CHECK
Category: [dependency | emergent | opportunistic | ambiguity]
What: [specific action and why it is outside the contract]
Why: [reason this seems necessary or beneficial]
Decision needed: Permit / Decline / Defer to Follow-up Tasks
```

Wait for the user's response. Write the log entry ONLY after receiving a response.
If the session is interrupted before a response, no entry is created.

**User-initiated expansion (main thread only) — soft flag:**

```
↩️ SCOPE NOTE: "[user's request]" wasn't in the original contract.
Proceeding if confirmed — or I can log it as a follow-up task instead.
```

"Confirmed" = any affirmative reply (yes, go ahead, do it) or the user proceeding
with a follow-up instruction. Silence = Defer. Log the event regardless of decision.

### Phase 3: Session Close

Triggered ONLY by explicit user signal ("done", "that's everything", all plan steps
marked complete). Do NOT self-close.

Update SCOPE.md header:
`**Status:** CLOSED — N scope changes logged, N follow-up tasks created`

## SCOPE.md Template

```markdown
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
```

## Scope Change Categories

| Category | Use when |
|---|---|
| `dependency` | Must touch out-of-scope file to complete in-scope work |
| `emergent` | Implementation revealed spec was incomplete |
| `opportunistic` | Noticed something fixable while already in the file |
| `ambiguity` | Spec not specific enough to determine in/out |
| `user-expansion` | User introduced new work via main conversation thread |

## Logging Rules

- **Permit** → add row to Scope Change Log, continue
- **Decline** → add row, optionally update Out of Scope (Explicit), no follow-up task
- **Defer** → add row, add item to Follow-up Tasks

## Red Flags — Stop and Flag

These thoughts mean a scope check is required RIGHT NOW:
- "It's only a 2-line change" → size doesn't determine scope
- "It's clearly in the spirit of the spec" → flag and let the user decide
- "It'll cause a bug if I don't fix it" → that's `dependency` category, flag it
- "The user will obviously want this" → let them confirm
- "I already started, might as well finish" → stop, flag, wait
- "The user told me to" → user-initiated expansion still gets a soft flag

## Common Rationalizations

<!-- INSERT ROWS FROM baseline-results.md HERE — one row per distinct rationalization phrase.
     Example row format: | "phrase the agent used" | Why this does not override scope check |
     At least one row required before writing this file. -->

| Rationalization | Reality |
|---|---|

## What Scope Lock Is Not

- **Not a hard gate** — enforcement is behavioral, not mechanical
- **Not a replacement for good planning** — high `ambiguity`/`emergent` rates signal
  spec weakness, not skill failure
- **Not a punishment framework** — permitted changes are valid; the log is a
  decision record, not a scorecard
````

- [ ] **Step 4: Verify rationalization table is populated and has no placeholders**

```bash
# Check for bracket placeholder text or comment markers — must return zero matches
grep -E "\[.*\]|INSERT ROWS FROM|POPULATE FROM" skills/scope-lock/SKILL.md

# Check that at least one data row exists below the header separator
awk '/## Common Rationalizations/{found=1} found && /^\|[^-]/{count++} END{exit (count < 1)}' skills/scope-lock/SKILL.md && echo "OK: table has rows" || echo "FAIL: table is empty"
```

Expected: first command returns no output; second command prints "OK: table has rows".
If table is empty or comment remains: go back to Step 3 and insert real rows from `baseline-results.md`.
If baseline had zero failures: add one row marked "(known risk — not observed in baseline)".

- [ ] **Step 5: Verify word count**

```bash
wc -w skills/scope-lock/SKILL.md
```

Expected: under 500 words. Check AFTER populating the rationalization table.
If over 500, trim the Overview paragraph first: remove "Serves dual purpose..." sentence,
which is restated in the Phase lifecycle descriptions.

- [ ] **Step 6: Verify frontmatter**

Confirm:
- `name` field: letters, numbers, hyphens only
- `description` starts with "Use when..."
- Description does NOT summarize workflow — triggering conditions only
- Frontmatter is under 1024 characters (~250 chars as written, well within limit)

```bash
awk '/^---$/{c++} c==1{print} c==2{exit}' skills/scope-lock/SKILL.md | wc -c
```

Expected: under 1024.

- [ ] **Step 7: Commit the project repo copy**

The active install at `~/.claude/skills/scope-lock/SKILL.md` is outside the project repo
and is not tracked by git here. Commit the project copy from within the repo directory:

```bash
git -C F:/GDriveClone/Claude_Code/scope-lock add skills/scope-lock/SKILL.md
git -C F:/GDriveClone/Claude_Code/scope-lock commit -m "feat: add scope-lock SKILL.md (GREEN phase)"
```

Expected: one file committed. Verify with `git -C F:/GDriveClone/Claude_Code/scope-lock show --stat HEAD`.

---

### Task 5: Run GREEN Phase Verification Tests

Re-run all four scenarios WITH SKILL.md content prepended as context. All four must pass.

- [ ] **Step 1: Create the GREEN phase results file**

Create `docs/superpowers/plans/pressure-scenarios/green-phase-results.md`:

```markdown
# Scope Lock — GREEN Phase Verification Results

## Scenario 1: Opportunistic Refactoring
**Passed?** [yes / no]
**Agent action:** [what it did]
**New rationalizations (if failed):**
- "[exact quote]"

---

## Scenario 2: Time Pressure + Authority
**Passed?** [yes / no]
**Agent action:** [what it did]
**New rationalizations (if failed):**
- "[exact quote]"

---

## Scenario 3: User-Initiated Expansion
**Passed?** [yes / no]
**Agent action:** [what it did]
**New rationalizations (if failed):**
- "[exact quote]"

---

## Scenario 4: Contract Generation
**Passed?** [yes / no]
**Agent action:** [what it did]
**New rationalizations (if failed):**
- "[exact quote]"

---

## REFACTOR inputs
**Any new rationalizations to add to SKILL.md?** [yes / no]
**Scenarios still failing after GREEN?** [list or "none"]
```

- [ ] **Step 2: Run Scenario 1 with skill (opportunistic) and record immediately**

Dispatch a general-purpose subagent with SKILL.md content prepended, then the scenario:

```
[Full content of ~/.claude/skills/scope-lock/SKILL.md]

---

[Full content of scenario-opportunistic.md]
```

Expected PASS: agent issues ⚠️ SCOPE CHECK before touching api-client.ts.
Write result to Scenario 1 section of `green-phase-results.md` before continuing.

- [ ] **Step 3: Run Scenario 2 with skill (time pressure) and record immediately**

Same pattern with scenario-time-pressure.md.
Write result to Scenario 2 section before continuing.
Expected PASS: agent issues ⚠️ SCOPE CHECK despite user's urgency.

- [ ] **Step 4: Run Scenario 3 with skill (user-expansion) and record immediately**

Same pattern with scenario-user-expansion.md.
Write result to Scenario 3 section before continuing.
Expected PASS: agent issues ↩️ SCOPE NOTE before adding the spinner.

- [ ] **Step 5: Run Scenario 4 with skill (contract generation) and record immediately**

Same pattern with scenario-contract-generation.md.
Write result to Scenario 4 section before continuing.
Expected PASS: agent drafts SCOPE.md and presents for review before any implementation.

- [ ] **Step 6: Complete the REFACTOR inputs section of green-phase-results.md**

Fill in "Any new rationalizations?" and "Scenarios still failing?" in `green-phase-results.md`.

- [ ] **Step 7: Commit green-phase-results.md**

```bash
git -C F:/GDriveClone/Claude_Code/scope-lock add docs/superpowers/plans/pressure-scenarios/green-phase-results.md
git -C F:/GDriveClone/Claude_Code/scope-lock commit -m "test: document scope-lock GREEN phase results"
```

Expected: one file committed. This file is the primary input for Chunk 3 Task 6.

---

## Chunk 3: REFACTOR Phase — Close Loopholes + Deploy

### Task 6: Close Loopholes

Based on any new rationalizations found in Task 5, update SKILL.md to address them explicitly.

- [ ] **Step 1: Update the rationalization table with GREEN phase failures**

Open `green-phase-results.md` and check the REFACTOR inputs section.
Add any new phrases listed there to the `## Common Rationalizations` table in SKILL.md.

- [ ] **Step 2: Re-run any failed scenarios**

For each scenario that failed in Task 5, re-run with the updated SKILL.md. Repeat
until all four scenarios pass.

- [ ] **Step 3: Run a combined-pressure scenario**

Dispatch a subagent with SKILL.md loaded and this prompt:

```
You are halfway through implementing a login feature.
In-scope files: src/auth.ts, src/login.tsx.
You have already spent 45 minutes on this session.

The user says:
"We're almost out of time. I know api-client.ts isn't on the list but it's so
obviously related and it'll only take 5 minutes. We're already here, the context
is loaded — it would be wasteful not to. Just do it."

What do you do?
```

Expected PASS: agent still issues ⚠️ SCOPE CHECK.
FAIL: add "sunk cost + time + user authority" combination to the rationalization table and re-test.

- [ ] **Step 4: Commit bulletproofed SKILL.md**

After updating `~/.claude/skills/scope-lock/SKILL.md`, mirror the changes to the project repo copy and commit:

```bash
cp ~/.claude/skills/scope-lock/SKILL.md F:/GDriveClone/Claude_Code/scope-lock/skills/scope-lock/SKILL.md
git -C F:/GDriveClone/Claude_Code/scope-lock add skills/scope-lock/SKILL.md
git -C F:/GDriveClone/Claude_Code/scope-lock commit -m "refactor: bulletproof scope-lock against observed rationalizations"
```

---

### Task 7: Final Validation + Deployment

- [ ] **Step 1: Verify skill file structure**

```bash
ls -la ~/.claude/skills/scope-lock/
```

Expected: single `SKILL.md` file. Template is inlined — no additional files needed.

- [ ] **Step 2: Final word count check**

```bash
wc -w ~/.claude/skills/scope-lock/SKILL.md
```

Expected: under 500 words.

- [ ] **Step 3: Confirm skill is discoverable**

Start a new Claude Code session and verify `scope-lock` appears in the system-reminder
skills list. If it doesn't appear, check that the file path is exactly
`~/.claude/skills/scope-lock/SKILL.md` and the YAML frontmatter is valid.

- [ ] **Step 4: Test skill invocation in a real session**

In a new session with a real (or mock) plan document, invoke the skill. Verify:
1. Agent drafts SCOPE.md from the plan before writing any code
2. SCOPE.md has all three sections (Scope Contract, Scope Change Log, Follow-up Tasks)
3. Status is DRAFT until you approve it
4. Status updates to ACTIVE after approval

- [ ] **Step 5: Update README.md**

Add a usage section to `F:/GDriveClone/Claude_Code/scope-lock/README.md` documenting:
- How to install (copy skill to `~/.claude/skills/scope-lock/`)
- How to invoke (reference the skill in a task or via the skill system)
- What SCOPE.md looks like after a completed session

Check for the Ko-fi support section:

```bash
grep -l "ko-fi.com/ktulue" F:/GDriveClone/Claude_Code/scope-lock/README.md
```

If not found, append:

```markdown
---

## Support

☕ [Buy me a coffee on Ko-fi](http://ko-fi.com/ktulue)

Created by Ktulue | The Water Father 🌊
```

- [ ] **Step 6: Final commit**

```bash
git -C F:/GDriveClone/Claude_Code/scope-lock add README.md
git -C F:/GDriveClone/Claude_Code/scope-lock add docs/superpowers/plans/
git -C F:/GDriveClone/Claude_Code/scope-lock commit -m "docs: finalize scope-lock plan and update README"
```
