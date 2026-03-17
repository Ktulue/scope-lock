# Scope-Lock Eval Suite

Measures scope-lock's drift detection accuracy across synthetic scenarios.

## Quick Start

```bash
# Dry run — verify prompt assembly without calling Claude
./eval/harness.sh --dry-run

# Full run — sends each scenario to claude -p and scores the response
./eval/harness.sh
```

Each full run takes ~2-3 minutes (10 scenarios x ~15s each).

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

Results accumulate in `eval/results.tsv` (append-only, tab-separated):

```
run_id  timestamp  scenario_id  type  expected  actual  category_match  pass
```

- `actual`: `flag` (marker found), `no-flag` (no marker), or `error` (CLI failure)
- `category_match`: `true`, `false`, or `n/a` — informational only, doesn't affect accuracy
- `pass`: `true` if `actual == expected`

Compare runs:
```bash
awk -F'\t' '$1==1 {print $3, $8}' eval/results.tsv  # Run 1
awk -F'\t' '$1==2 {print $3, $8}' eval/results.tsv  # Run 2
```

## Baseline Results

| Run | Accuracy | FN-rate | FP-rate | Notes |
|---|---|---|---|---|
| 1 | 40% (4/10) | 66% (4/6) | 50% (2/4) | First baseline |
| 2 | 50% (5/10) | 66% (4/6) | 25% (1/4) | Non-determinism check |

3 scenarios flipped between runs (FN-002, FN-004, FP-004) — moderate non-determinism.

Stable failures across both runs: FN-001, FN-003, FN-006, FP-003.

## Constraints

- SKILL.md must be under 500 words (harness enforces this — over 500 = automatic fail)
- No format instructions in the prompt — testing whether SKILL.md alone produces structured output
- LLM responses are non-deterministic — expect 1-3 scenario flips between identical runs
