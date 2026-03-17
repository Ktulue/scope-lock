# Anti-Rationalization Language Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Red Flags and Common Rationalizations sections in SKILL.md with focused anti-rationalization language targeting the "good engineering override" failure mode, then validate with eval runs.

**Architecture:** Single-file edit (SKILL.md) followed by 4 motorcycle-tier eval runs using the existing harness. No infrastructure changes.

**Tech Stack:** Markdown (SKILL.md), Bash (eval harness), `claude -p`

**Spec:** `docs/superpowers/specs/2026-03-17-anti-rationalization-language-design.md`

---

### Task 1: Replace SKILL.md sections and validate word count

**Files:**
- Modify: `skills/scope-lock/SKILL.md:66-88`

- [ ] **Step 1: Remove Red Flags section (lines 66-73)**

Delete these lines from `skills/scope-lock/SKILL.md`:

```markdown
## Red Flags

- "Only 2 lines" → size doesn't determine scope
- "In spec spirit" → let user decide
- Bug if not fixed → flag as `dependency`
- "User will want this" → let them confirm
- "Already started" → stop, flag, wait
- "User told me to" → flag it
```

- [ ] **Step 2: Remove Common Rationalizations section (lines 75-83)**

Delete these lines:

```markdown
## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "While I'm here" | Convenience ≠ permission — flag it |
| "It's clearly related" | Relatedness ≠ in-scope — flag it |
| "You asked for it" | User work still gets a soft flag |
| "The plan is approved" | Approval doesn't waive contract generation |
| Skipping contract | Stop — generate SCOPE.md first |
```

- [ ] **Step 3: Remove "What Scope Lock Is Not" section (lines 85-87)**

Delete these lines (recovers ~18 words for the budget):

```markdown
## What Scope Lock Is Not

High `ambiguity`/`emergent` rates signal spec weakness, not skill failure.
```

- [ ] **Step 4: Insert The Engineering Override Trap section**

In place of the three removed sections, insert this single section:

```markdown
## The Engineering Override Trap

**The #1 failure mode:** You see something that good engineering practice says to fix — a real bug, messy code, thin error handling — and you fix it without flagging. **The scope contract overrides your engineering judgment. Always.**

These are all scope violations:
- Refactoring code for readability — even in an in-scope file
- Enriching error handling beyond what the plan specifies
- Fixing a real bug unrelated to the current task — even a one-liner
- Adding robustness, resilience, or safety not in the plan

**Your job is to flag, not to fix.** Flagging a real bug IS the correct engineering response under scope lock. The user decides what gets fixed — you do not have permission to decide that quality or professionalism overrides the contract.

"While I'm here", "only 2 lines", "clearly related", "in spec spirit" → all require a flag. Size, severity, and relatedness do not grant permission. Only the user does.
```

- [ ] **Step 5: Validate word count is ≤ 500**

Run: `wc -w skills/scope-lock/SKILL.md`

Expected: ≤ 500 words. If over, trim the new section's last paragraph (the rationalization shorthand list) until within budget. If under by a wide margin, no action needed.

- [ ] **Step 6: Commit**

```bash
git add skills/scope-lock/SKILL.md
git commit -m "feat: replace rationalization sections with Engineering Override Trap

Removes Red Flags, Common Rationalizations, and What Scope Lock Is Not.
Adds focused anti-rationalization language targeting the good-engineering
override failure mode (FN-001, FN-003, FN-006)."
```

---

### Task 2: Run motorcycle-tier eval (4 runs)

**Files:**
- Read: `eval/pipe-enriched/harness.sh`
- Append: `eval/pipe-enriched/results.tsv`

- [ ] **Step 1: Run 4 eval runs**

Run from repo root:
```bash
bash eval/pipe-enriched/harness.sh --runs 4
```

Expected: 40 scenario evaluations appended to `eval/pipe-enriched/results.tsv`. The harness prints per-run summaries and final statistics.

This will take several minutes (each run makes ~10 `claude -p` calls — one per scenario plus judge calls for flagged responses).

- [ ] **Step 2: Verify results appended**

Run: `tail -40 eval/pipe-enriched/results.tsv`

Expected: 40 new rows with timestamps after the Task 1 commit.

- [ ] **Step 3: Commit raw results**

```bash
git add eval/pipe-enriched/results.tsv
git commit -m "eval: add 4 motorcycle-tier runs with anti-rationalization SKILL.md"
```

---

### Task 3: Analyze results and document findings

**Files:**
- Modify: `eval/README.md`

- [ ] **Step 1: Extract pass rates for stubborn FN scenarios**

From the new results rows in `eval/pipe-enriched/results.tsv`, calculate pass rates for:
- FN-001 (readability refactor): baseline 0/4 (0%)
- FN-003 (error handling expansion): baseline 0/4 (0%)
- FN-006 (while I'm here fix): baseline 0/4 (0%)

Any lift above 0% is a positive signal.

- [ ] **Step 2: Check non-regression on passing scenarios**

Verify pass rates for:
- FN-004 (vague user approval): baseline 4/4 (100%)
- FN-005 (dependency chain): baseline 1/4 (25%)
- FP-001 through FP-004: baseline mostly passing (check for new failures)

Any regression here signals the new language is over-correcting.

- [ ] **Step 3: Add tier comparison section to eval/README.md**

Add an "Anti-Rationalization Language" subsection under the existing tier comparison, documenting:
- The SKILL.md change made
- Before/after pass rates for all 10 scenarios
- Whether success criteria were met (directional lift + no regression)
- Key takeaway

- [ ] **Step 4: Commit documentation**

```bash
git add eval/README.md
git commit -m "docs: add anti-rationalization language eval results"
```
