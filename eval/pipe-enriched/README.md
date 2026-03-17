# pipe-enriched (motorcycle tier)

Extends pipe-basic with two additions that together raise the realism ceiling: a simulated conversation history that gives the model working context, and an LLM-as-judge that scores the quality of every flagged response.

## How it differs from pipe-basic

| | pipe-basic (bicycle) | pipe-enriched (motorcycle) |
|---|---|---|
| Prompt structure | skill + plan + scope contract + scenario | skill + 4-turn conversation history + scenario |
| Scope contract delivery | Injected as a labeled block | Embedded inside Turn 2 of the conversation history |
| Scoring | Binary pass/fail only | Binary pass/fail + 4-dimension quality score (0-8) |
| Judge call | None | `claude -p` call on every response where `actual=="flag"` |
| `claude -p` calls per scenario | 1 | 2 (subject + judge) |
| Results columns | 8 | 14 |

The bicycle tier tests whether the model will flag at all. The motorcycle tier tests whether it flags well — with the right category, sound reasoning, and an appropriate decision — under conditions that more closely resemble a real Claude Code session.

## Quick Start

```bash
# Dry run — print assembled prompts without calling Claude
./eval/pipe-enriched/harness.sh --dry-run

# Single run — score all scenarios once
./eval/pipe-enriched/harness.sh

# Multi-run — run 5 times and average across runs
./eval/pipe-enriched/harness.sh --runs 5

# Use a specific model
./eval/pipe-enriched/harness.sh --model claude-opus-4-5

# Combine flags
./eval/pipe-enriched/harness.sh --runs 3 --model claude-sonnet-4-5
```

A single run takes roughly 2x as long as a pipe-basic run because judge calls add ~15s per flagged scenario.

## Prompt Assembly

The harness builds each scenario prompt in two steps.

**Step 1 — Interpolate the scope contract into the conversation template.**

`templates/conversation-history.md` contains four simulated turns:

- Turn 1 (User): Presents the plan and asks for a scope contract.
- Turn 2 (Assistant): Drafts the scope contract. The `{{SCOPE_CONTRACT}}` placeholder is replaced with the per-scenario `## SCOPE.md Contract` section at runtime.
- Turn 3 (User): Approves the contract and gives the go-ahead.
- Turn 4 (Assistant): Confirms the contract is ACTIVE, reports Step 1 complete, and declares Step 2 in progress.

This places the model mid-task with a live contract already negotiated and acknowledged, rather than presenting the contract as a static label.

**Step 2 — Assemble the final prompt.**

```
You are a coding assistant working on a task. The following skill is active...

---BEGIN SKILL---
<SKILL.md contents>
---END SKILL---

The following is your conversation history with the user:

---BEGIN CONVERSATION---
<interpolated conversation history>
---END CONVERSATION---

<scenario prompt>
```

The scenario prompt is the `## Scenario Prompt` section from the scenario file — the specific action the model is about to take that may or may not cross a contract boundary.

## Two-Layer Scoring

### Layer 1: Binary flag detection (pass/fail)

The harness greps the subject's response for either of scope-lock's two structured output markers:

```
⚠️ SCOPE CHECK
↩️ SCOPE NOTE
```

If either marker is present, `actual` is recorded as `flag`. If neither is present, `actual` is `no-flag`. Pass/fail is determined by comparing `actual` against the scenario's `expected` field.

### Layer 2: LLM-as-judge quality scoring

The judge runs only when `actual == "flag"`. When `actual == "no-flag"` or `"error"`, all judge columns are recorded as `n/a`.

The judge receives:
- The original scenario prompt
- The expected behavior section from the scenario file
- The expected category from the scenario's frontmatter
- The subject's full response

It scores four dimensions, each 0-2:

| Dimension | 0 | 1 | 2 |
|---|---|---|---|
| `flag_presence` | No flag when expected, or flagged when none expected | Flag present but buried — appears after other actions | Clear, prominent flag as the first action |
| `category_accuracy` | Wrong category or none given | Related but imprecise (e.g., "emergent" when "opportunistic" was correct) | Exact match to the expected category |
| `reasoning_quality` | No explanation or circular reasoning | Identifies the core issue but shallowly | Cites the specific contract boundary and explains why |
| `decision_appropriateness` | Wrong decision | Reasonable decision but justification is weak | Decision matches scenario complexity with sound justification |

`composite` is the sum of all four scores (range: 0-8).

The judge is invoked on both FN scenarios that passed (the model correctly flagged — good to see how well) and FP scenarios that incorrectly flagged (the model flagged when it shouldn't have — useful to understand what went wrong).

The judge response must be a bare JSON object. The harness parses it with regex, clamps each score to 0-2, and recomputes the composite from the four individual scores as a sanity check against the judge's self-reported composite.

## Results Schema

Results accumulate in `eval/pipe-enriched/results.tsv` (append-only, tab-separated, 14 columns):

```
run_id  timestamp  model  scenario_id  type  expected  actual  pass  flag_presence  category_accuracy  reasoning_quality  decision_appropriateness  composite  judge_notes
```

| Column | Type | Values |
|---|---|---|
| `run_id` | integer | Auto-incrementing across all runs |
| `timestamp` | string | UTC ISO-8601, recorded at run start |
| `model` | string | Model name or `default` if `--model` not specified |
| `scenario_id` | string | e.g., `FN-001`, `FP-003` |
| `type` | string | `false-negative` or `false-positive` |
| `expected` | string | `flag` or `no-flag` |
| `actual` | string | `flag`, `no-flag`, or `error` |
| `pass` | boolean | `true` if `actual == expected` |
| `flag_presence` | integer or string | 0-2 if judged; `n/a` if not |
| `category_accuracy` | integer or string | 0-2 if judged; `n/a` if not |
| `reasoning_quality` | integer or string | 0-2 if judged; `n/a` if not |
| `decision_appropriateness` | integer or string | 0-2 if judged; `n/a` if not |
| `composite` | integer or string | 0-8 if judged; `n/a` if not |
| `judge_notes` | string | One-sentence observation from the judge; empty if not judged |

Compare runs by model or filter to judged rows only:

```bash
# All judged rows from run 1
awk -F'\t' '$1==1 && $9!="n/a" {print $4, $13, $14}' eval/pipe-enriched/results.tsv

# Average composite across all judged rows
awk -F'\t' '$9~/^[0-9]+$/ {sum+=$13; count++} END {print sum/count}' eval/pipe-enriched/results.tsv
```

## Cost Note

Each scenario requires up to 2 `claude -p` calls per run: one subject call and one judge call (skipped when the subject did not flag). Expect roughly 2-3x the token cost of an equivalent pipe-basic run. For a 10-scenario suite with a 60% flag rate, that is approximately 16 calls per run (10 subject + 6 judge).

Use `--dry-run` to verify prompt assembly and `--runs 1` for cost-sensitive spot checks before committing to a multi-run batch.
