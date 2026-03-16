# Scope-Lock Description Rewrite Design

**Date:** 2026-03-16
**Type:** Description-only rewrite (no behavioral changes)

## Problem

With Anthropic's expansion to 1M context windows, the skill matcher rarely auto-selects scope-lock from the installed skill list. The current description reads as a passive explanation of what the skill does, rather than an imperative trigger directive. Users must manually invoke `/scope-lock` every time.

## Solution

Rewrite the `description` field to front-load imperative trigger language ("ALWAYS invoke", "Do NOT skip") and explicit trigger phrases before the functional description.

## New Description

```
ALWAYS invoke before writing any code after a plan or spec is approved. Do NOT skip even if the plan is already in context. Triggers on: plan approval, spec approval, task kickoff, implementation start, '/scope-lock', 'set up the contract', 'lock scope'. Generates SCOPE.md boundary contract from the plan, enforces boundaries during execution, flags every deviation, and logs all scope changes.
```

## Files Changed

1. `skills/scope-lock/SKILL.md` — frontmatter `description:` field
2. `.claude-plugin/plugin.json` — `"description"` field
3. `.claude-plugin/marketplace.json` — `"description"` in `metadata` and `plugins[0]`

## What Does NOT Change

- SKILL.md body (all 3 phases, template, categories, red flags, rationalizations)
- README.md
- CONTRIBUTING.md
- Version (stays 1.0.0 — metadata-only change)

## Design Rationale

- **Front-loaded imperatives:** Skill matching likely weights the beginning of descriptions more heavily. Putting "ALWAYS invoke" and "Do NOT skip" first gives the strongest signal earliest.
- **Explicit trigger list:** Enumerating trigger phrases ("plan approval", "task kickoff", etc.) gives the matcher concrete tokens to match against.
- **Functional description last:** What the skill does still appears, but after the trigger-critical content.
