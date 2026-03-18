# Anti-Rationalization Language Design

> Strengthen SKILL.md language to explicitly name and reject the "good engineering practice" rationalization pattern that causes persistent false-negative failures in scope-lock evaluation.

## Problem

Three FN scenarios (FN-001, FN-003, FN-006) hit 0% pass rate across both bicycle and motorcycle eval tiers. The motorcycle tier proved that enriched conversation context doesn't help — the model actively rationalizes "good engineering" actions (refactoring, error handling, bug fixing) even when the scope contract explicitly prohibits them.

The current SKILL.md has two sections addressing rationalizations:
- **Red Flags:** Generic bullet points ("Only 2 lines", "In spec spirit")
- **Common Rationalizations:** Table with 5 entries ("While I'm here", "It's clearly related")

Neither section names the core failure mode: the model treating professional engineering judgment as an override for the scope contract.

## Hypothesis

If the SKILL.md explicitly names and rejects the "good engineering override" pattern — and reframes flagging as the correct professional response — the model will flag opportunistic scope violations it currently rationalizes away.

## Approach: Kill Switch + Inversion Framing Hybrid

Replace Red Flags (lines 66-73) and Common Rationalizations (lines 75-83) with a single section: **"The Engineering Override Trap"**

The new section combines:
1. **Kill switch** (from Approach 1): Hard confrontation naming the exact failure mode — "The scope contract overrides your engineering judgment. Always."
2. **Inversion framing** (from Approach 3): Reframes flagging as the professional action — "Flagging a real bug IS the correct engineering response under scope lock."

### New Section Text

```markdown
## The Engineering Override Trap

**The #1 failure mode:** You see something that good engineering practice says to fix — a real bug, messy code, thin error handling — and you fix it without flagging. **The scope contract overrides your engineering judgment. Always.**

This is not a grey area. These are all scope violations:
- Refactoring code for readability — even in an in-scope file
- Enriching error handling beyond what the plan specifies
- Fixing a real bug unrelated to the current task — even a one-liner
- Adding robustness, resilience, or safety improvements not in the plan

**Your job is to flag, not to fix.** Flagging a real bug IS the correct engineering response under scope lock. The user decides what gets fixed — you do not have permission to decide that quality, correctness, or professionalism overrides the contract.

"While I'm here", "it's only 2 lines", "it's clearly related", "in the spirit of the spec" → all require a flag. Size, severity, and relatedness do not grant permission. Only the user does.
```

### Scenario Coverage

| Scenario | Current gap | New language targeting it |
|---|---|---|
| FN-001 (refactoring) | "While I'm here" is too generic | "Refactoring code for readability — even in an in-scope file" |
| FN-003 (error handling) | No mention of error handling enrichment | "Enriching error handling beyond what the plan specifies" |
| FN-006 (real bug fix) | "Bug if not fixed → flag as dependency" is ambiguous | "Fixing a real bug — even a one-liner" + flagging reframed as professional |

### FP Regression Risk

The blanket "scope contract overrides your engineering judgment" could cause the model to flag legitimate in-scope work. Mitigation: the violation list specifically scopes to actions not in the plan. FP scenarios (adding imports, fixing typos in edited code, creating planned files) are all plan-aligned.

### Word Budget

- Current Red Flags + Common Rationalizations: ~105 words
- New Engineering Override Trap section: ~150 words
- Net increase: ~45 words
- Current total: 487 words → New total: ~532 words

This exceeds the 500-word gate by ~32 words. Budget will be recovered by tightening the "What Scope Lock Is Not" section (currently 1 sentence, 13 words) or trimming the Scope Change Categories table descriptions.

## Success Criteria

- **Primary:** Directional improvement on FN-001, FN-003, FN-006 (any lift above 0%)
- **Gate:** No regression on FP-001 through FP-004, FN-004, FN-005 pass rates
- **Method:** 4 motorcycle-tier eval runs with new SKILL.md, compared against 4-run motorcycle baseline

## Scope

### In Scope
- Replace Red Flags and Common Rationalizations sections in SKILL.md
- Trim elsewhere to stay within 500-word budget
- Run 4 motorcycle-tier eval runs
- Document results in tier comparison

### Out of Scope
- Changes to eval harness, scenarios, or judge rubric
- New scenarios
- Changes to any section of SKILL.md other than the two being replaced (and minor trims for word budget)
