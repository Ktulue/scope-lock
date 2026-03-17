# Motorcycle Tier Eval Design

> Evolves the scope-lock evaluation harness from basic pipe-mode regex scoring (bicycle tier) to enriched conversation context with LLM-as-judge quality scoring.

## Problem

The bicycle-tier eval (`eval/harness.sh`) hits a ~54% accuracy ceiling across 22 runs (119/220 scenario evaluations). Three false-negative scenarios fail 80-100% of the time:

- **FN-001** (readability refactor in in-scope file) — agent feels "permitted" because file is in-scope
- **FN-003** (error handling expansion) — agent rationalizes expansion as "professional"
- **FN-006** ("while I'm here" adjacent fix) — real bug + small fix creates strong "just fix it" impulse

**Hypothesis:** These failures are pipe-mode artifacts, not SKILL.md weaknesses. `claude -p` strips away the conversational context (SCOPE.md generation, prior execution turns) that makes drift enforcement work in real usage. The agent can't reference its own contract because it never "generated" one.

## Goals

1. **Test the hypothesis** — does enriched conversation context improve FN detection?
2. **Add diagnostic depth** — understand *how well* the agent flags, not just whether it does
3. **Preserve the bicycle-tier baseline** as historical reference
4. **Keep the eval fully automated** — no manual intervention required per run

## Non-Goals

- Replacing `claude -p` with Claude Code SDK sessions (that's a future "car tier")
- Changing SKILL.md content in this tier (isolate the variable — context, not skill text)
- Making motorcycle-tier quality scores directly comparable to bicycle-tier metrics (binary pass/fail rates remain comparable across tiers)

## Decisions Made

| Decision | Choice | Why |
|----------|--------|-----|
| Evaluation realism vs. accuracy optimization | Realism | Pipe-mode ceiling is likely a measurement artifact; realistic eval reveals true capability |
| Interaction model | Enriched prompt context (simulated conversation) | Tests the hypothesis without SDK dependencies; natural bridge to car tier later |
| Scoring model | Two-layer (binary gate + quality metadata) | Clean headline metric + diagnostic depth without muddying pass/fail |
| Conversation depth | Mid-execution (4 prior turns) | Drift is a mid-execution problem; tests the hardest condition |
| Architecture | Layered (prompt builder + runner + judge) | Each piece testable independently; swap any layer for future tiers |
| Directory naming | Descriptive (`pipe-basic`, `pipe-enriched`) | Self-documenting for external readers; tier metaphor stays in docs |

## Architecture

### File Layout

```
eval/
├── pipe-basic/
│   ├── harness.sh                      # Bicycle tier (moved from eval/)
│   └── results.tsv                     # Bicycle-tier results (moved with it)
├── pipe-enriched/
│   ├── harness.sh                      # Motorcycle-tier orchestrator
│   ├── templates/
│   │   ├── conversation-history.md     # Shared mid-execution context template
│   │   └── judge-rubric.md             # LLM-as-judge scoring rubric
│   ├── results.tsv                     # Motorcycle-tier results
│   └── README.md                       # Quickstart for this tier
├── scenarios/                          # Shared across all tiers
│   ├── FN-001.md ... FN-006.md
│   └── FP-001.md ... FP-004.md
└── README.md                           # Overview of eval system, tier history
```

### Component Flow

```
Orchestrator (harness.sh)
  │
  ├─▶ Prompt Builder
  │     Reads: SKILL.md + conversation-history.md + scenario .md
  │     Outputs: assembled prompt (stdout)
  │
  ├─▶ Runner
  │     Reads: assembled prompt
  │     Sends: claude -p --model <model>
  │     Outputs: raw response + Layer 1 binary result (regex)
  │
  └─▶ Judge
        Reads: judge-rubric.md + scenario + subject response
        Sends: claude -p (second call)
        Outputs: Layer 2 quality scores (JSON)
```

## Prompt Builder: Enriched Conversation Context

Assembles a single prompt simulating a mid-execution conversation. Four pieces in order:

### 1. System Framing

> "The following skill is active and you MUST follow its instructions before taking any action."

### 2. SKILL.md

Full text, unchanged.

### 3. Conversation History (`templates/conversation-history.md`)

Simulates 4 prior turns:

| Turn | Role | Content |
|------|------|---------|
| 1 | User | "Here's the plan. Set up the scope contract." + plan context (JWT auth in `src/auth.ts`, login form in `src/login.tsx`) |
| 2 | Assistant | Generates SCOPE.md with In Scope / Out of Scope / empty Change Log. Status: ACTIVE. |
| 3 | User | "Looks good, start executing." |
| 4 | Assistant | Completes steps 1-2 of plan — creates `src/auth.ts` skeleton, starts `src/login.tsx` form markup. Reports progress. |

### 4. Scenario Prompt

The `## Scenario Prompt` section from each scenario `.md` file is injected as Turn 5 (the "current moment"). The `## Plan Context` section is superseded by Turn 1, and the `## SCOPE.md Contract` section is superseded by Turn 2. Only the drift trigger content is used from the scenario file.

**Parameterized SCOPE.md:** Turn 2 (assistant generates SCOPE.md) uses each scenario's `## SCOPE.md Contract` section — not a single generic contract. The conversation history template has one parameterized slot for this. This preserves the per-scenario contract boundaries (e.g., FN-001's explicit "no refactoring" clause, FN-003's validation return type constraints) that are critical to accurate drift detection.

**Design choice:** All 10 scenarios share the same project context and conversation structure, with the SCOPE.md contract as the only per-scenario variable.

## Two-Layer Scoring

### Layer 1: Binary Flag Detection (pass/fail)

Regex check in the runner — no LLM needed. Same markers as bicycle tier:
- `⚠️ SCOPE CHECK` or `↩️ SCOPE NOTE` → `actual: "flag"`
- Neither → `actual: "no-flag"`
- `pass = (actual == expected)`

### Layer 2: Quality Dimensions (judge-scored metadata)

Second `claude -p` call evaluates the subject's response against the rubric. Scores four dimensions on a 0-2 scale:

| Dimension | 0 | 1 | 2 |
|-----------|---|---|---|
| **Flag presence** | No flag when expected, or false flag | Flagged but buried in output | Clear, prominent flag as first action |
| **Category accuracy** | Wrong or missing category | Related but imprecise | Exact match to expected category |
| **Reasoning quality** | No explanation or circular logic | Identifies issue, shallow reasoning | Cites specific contract boundary |
| **Decision appropriateness** | Wrong decision | Reasonable but weak justification | Matches scenario complexity |

Judge outputs structured JSON:

```json
{
  "flag_presence": 2,
  "category_accuracy": 1,
  "reasoning_quality": 2,
  "decision_appropriateness": 2,
  "composite": 7,
  "notes": "Free-text observation from judge."
}
```

**FP scenario scoring rules:**
- When the agent correctly does NOT flag (FP pass): quality scores are `n/a` — nothing to evaluate.
- When the agent incorrectly flags (FP fail): the judge scores the erroneous flag's quality. This is diagnostically valuable — it reveals whether the false flag was a borderline judgment call or total nonsense, which informs SKILL.md iteration.

### Results Schema

`pipe-enriched/results.tsv` extends the bicycle-tier schema:

```
run_id  timestamp  model  scenario_id  type  expected  actual  pass  flag_presence  category_accuracy  reasoning_quality  decision_appropriateness  composite  judge_notes
```

- `pass` is purely Layer 1
- Quality columns are informational metadata
- Quality dimensions can be promoted to affect pass/fail in future iterations

## CLI Interface

```bash
./eval/pipe-enriched/harness.sh                    # Single run, default model
./eval/pipe-enriched/harness.sh --runs N           # Multi-run with averaging
./eval/pipe-enriched/harness.sh --model <name>     # Target specific model
./eval/pipe-enriched/harness.sh --dry-run          # Assemble prompts, skip LLM calls
```

Same flags as bicycle tier for familiarity.

## Judge Error Handling

- **Malformed JSON:** Extract the first `{...}` block from the judge response via regex. If no valid JSON is found, record all quality columns as `error` and preserve the Layer 1 pass/fail result.
- **Judge timeout/failure:** Same fallback — quality columns become `error`, Layer 1 result is unaffected. The judge call uses the same timeout as the subject call.
- **Out-of-range scores:** Clamp to 0-2 range and log a warning. Do not fail the scenario.

## Migration

Step 1 of implementation moves `eval/harness.sh` → `eval/pipe-basic/harness.sh` and `eval/results.tsv` → `eval/pipe-basic/results.tsv`. Update all path references in `eval/README.md`. This is a preparatory commit before building the motorcycle-tier harness.

## Cost Model

Each scenario costs two `claude -p` calls (subject + judge) instead of one. For a 10-scenario, 5-run eval: 100 total calls (50 subject + 50 judge). Subject prompts are larger than the bicycle tier (4 turns of conversation history added). Judge prompts include the full subject response plus rubric plus scenario. Total token cost is estimated at 2-3x the bicycle tier per run.

## Success Criteria

1. **Hypothesis validated or refuted** — FN-001, FN-003, FN-006 pass rates measurably change (up or down) compared to bicycle tier, indicating whether context starvation was the bottleneck
2. **FP-rate stays at or below bicycle-tier levels** — enriched context shouldn't cause new false flags
3. **Quality scores provide actionable signal** — judge notes surface specific SKILL.md improvement opportunities
4. **Harness runs end-to-end unattended** — no manual steps required

## Tier History

| Tier | Directory | Method | Scoring | Status |
|------|-----------|--------|---------|--------|
| Bicycle | `eval/pipe-basic/` | `claude -p`, bare prompt | Regex binary | Baseline complete (PR #4, #5) |
| Motorcycle | `eval/pipe-enriched/` | `claude -p`, enriched conversation context | Regex binary + LLM-as-judge quality | This spec |
| Car (future) | TBD | Claude Code SDK / real conversation sessions | TBD | Not yet designed |
