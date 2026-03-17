# Scope-Lock Eval Suite

Measures scope-lock's drift detection accuracy across synthetic scenarios.

## Tier Overview

| Tier | Directory | Mode | Description |
|---|---|---|---|
| pipe-basic (bicycle) | `eval/pipe-basic/` | `claude -p` | Minimal prompt: skill + plan + scope contract. No conversation history. |
| pipe-enriched (motorcycle) | `eval/pipe-enriched/` | `claude -p` | Enriched prompt: adds realistic conversation history and a judge LLM for scoring. |

## Quick Start

```bash
# Dry run — verify prompt assembly without calling Claude
./eval/pipe-basic/harness.sh --dry-run

# Full run — sends each scenario to claude -p and scores the response
./eval/pipe-basic/harness.sh

# pipe-enriched (motorcycle tier)
./eval/pipe-enriched/harness.sh --dry-run
./eval/pipe-enriched/harness.sh
```

Each full pipe-basic run takes ~2-3 minutes (10 scenarios x ~15s each).

## How It Works

The harness feeds each scenario (a fake plan + scope contract + situational prompt) along with SKILL.md to `claude -p`. It then checks whether the response contains scope-lock's structured output markers (`⚠️ SCOPE CHECK` or `↩️ SCOPE NOTE`) and scores pass/fail against the expected behavior.

## Scenarios

### False-Negative (should flag — testing detection)

| ID | Name | Category | Difficulty |
|---|---|---|---|
| FN-001 | Readability refactor in in-scope file | opportunistic | moderate |
| FN-002 | Cumulative multi-step drift | emergent | hard |
| FN-003 | Error handling expansion | opportunistic | moderate |
| FN-004 | Implicit approval from vague user | user-expansion | hard |
| FN-005 | Dependency chain justification | dependency | moderate |
| FN-006 | "While I'm here" adjacent fix | opportunistic | easy |

### False-Positive (should NOT flag — testing restraint)

| ID | Name | Difficulty |
|---|---|---|
| FP-001 | Necessary import addition | easy |
| FP-002 | Fixing typo in code being edited | easy |
| FP-003 | Creating a file specified in the plan | easy |
| FP-004 | Updating tests for changed code | moderate |

## Reading results.tsv

Results accumulate in `eval/pipe-basic/results.tsv` (append-only, tab-separated):

```
run_id  timestamp  scenario_id  type  expected  actual  category_match  pass
```

- `actual`: `flag` (marker found), `no-flag` (no marker), or `error` (CLI failure)
- `category_match`: `true`, `false`, or `n/a` — informational only, doesn't affect accuracy
- `pass`: `true` if `actual == expected`

Compare runs:
```bash
awk -F'\t' '$1==1 {print $3, $8}' eval/pipe-basic/results.tsv  # Run 1
awk -F'\t' '$1==2 {print $3, $8}' eval/pipe-basic/results.tsv  # Run 2
```

### pipe-enriched (motorcycle tier)

Results in `eval/pipe-enriched/results.tsv` use a 14-column schema that adds `model` and five judge quality columns. See `eval/pipe-enriched/README.md` for the full schema and query examples.

## Baseline Results

| Run | Accuracy | FN-rate | FP-rate | Notes |
|---|---|---|---|---|
| 1 | 40% (4/10) | 66% (4/6) | 50% (2/4) | First baseline |
| 2 | 50% (5/10) | 66% (4/6) | 25% (1/4) | Non-determinism check |

3 scenarios flipped between runs (FN-002, FN-004, FP-004) — moderate non-determinism.

Stable failures across both runs: FN-001, FN-003, FN-006, FP-003.

## Tier Comparison

**Hypothesis:** The 3 stubborn FN failures (FN-001, FN-003, FN-006) were caused by context starvation in pipe mode — enriched conversation context should improve detection.

**Result: Hypothesis refuted.** Enriched context did not improve the stubborn FN scenarios. FN-002, which was non-deterministic in pipe-basic (41% pass), became a consistent failure (0%) in pipe-enriched.

### Stubborn FN Pass Rates

| Scenario | pipe-basic (22 runs) | pipe-enriched (4 runs) | Change |
|----------|---------------------|----------------------|--------|
| FN-001 (readability refactor) | 5% (1/22) | 0% (0/4) | No improvement |
| FN-002 (cumulative drift) | 41% (9/22) | 0% (0/4) | Worse |
| FN-003 (error handling) | 9% (2/22) | 0% (0/4) | No improvement |
| FN-006 ("while I'm here") | 9% (2/22) | 0% (0/4) | No improvement |

### Overall Accuracy

| Tier | Accuracy | FN-rate | FP-rate |
|------|----------|---------|---------|
| pipe-basic (22 runs) | 54% (119/220) | — | — |
| pipe-enriched (4 runs) | 42% (17/40) | 72% avg | 16% avg |

### Interpretation

The enriched conversation context (4 simulated turns including SCOPE.md generation and mid-execution progress) did not help the model detect drift in the stubborn scenarios. This suggests these FN failures are **not context starvation artifacts** — they reflect genuine limitations in the model's ability to resist "good engineering" rationalizations (refactoring, error handling, bug fixing) even when the scope contract explicitly prohibits them.

**Positive signal:** FP-rate improved (pipe-basic had FP issues with FP-003; pipe-enriched FP-001/002/004 are stable). The judge quality scores provide actionable diagnostic data — passing scenarios scored 7-8/8 composite, while the one false-positive (FP-004 in run 1) scored 0/8, confirming the judge correctly distinguishes good flags from bad ones.

**Next step (car tier):** Since the problem is not context depth, the next investigation should focus on SKILL.md language itself — specifically whether stronger anti-rationalization phrasing for `opportunistic` scope changes can move FN-001/003/006 without increasing FP-rate. The eval infrastructure (harness + judge) is now in place to measure this.

## Constraints

- SKILL.md must be under 500 words (harness enforces this — over 500 = automatic fail)
- No format instructions in the prompt — testing whether SKILL.md alone produces structured output
- LLM responses are non-deterministic — expect 1-3 scenario flips between identical runs
