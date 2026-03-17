# Motorcycle Tier Eval Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pipe-enriched eval harness with enriched conversation context and LLM-as-judge two-layer scoring.

**Architecture:** Three-component pipeline (prompt builder → runner → judge) orchestrated by a bash harness. The prompt builder stitches SKILL.md + simulated 4-turn conversation history + per-scenario SCOPE.md + scenario prompt. The runner sends to `claude -p` and performs Layer 1 regex scoring. The judge makes a second `claude -p` call to score quality dimensions.

**Tech Stack:** Bash, `claude -p`, Markdown templates, TSV results

**Spec:** `docs/superpowers/specs/2026-03-17-motorcycle-tier-eval-design.md`

---

### Task 1: Migrate bicycle tier into `eval/pipe-basic/`

**Files:**
- Move: `eval/harness.sh` → `eval/pipe-basic/harness.sh`
- Move: `eval/results.tsv` → `eval/pipe-basic/results.tsv`
- Modify: `eval/pipe-basic/harness.sh` (update path references)
- Modify: `eval/README.md` (update to reflect new structure)

- [ ] **Step 1: Create `eval/pipe-basic/` directory**

Run: `mkdir -p eval/pipe-basic`

- [ ] **Step 2: Move harness and results into `pipe-basic/`**

Run:
```bash
git mv eval/harness.sh eval/pipe-basic/harness.sh
git mv eval/results.tsv eval/pipe-basic/results.tsv
```

- [ ] **Step 3: Update path references in `eval/pipe-basic/harness.sh`**

The script uses `SCRIPT_DIR` to derive `REPO_ROOT` and `SCENARIOS_DIR`. After the move, `REPO_ROOT` needs to go up two levels instead of one, and `SCENARIOS_DIR` should point to `eval/scenarios/` (shared).

Change line 5:
```bash
# Before:
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# After:
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
```

Change line 7:
```bash
# Before:
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
# After:
SCENARIOS_DIR="$SCRIPT_DIR/../scenarios"
```

Change line 8:
```bash
# Before:
RESULTS_FILE="$SCRIPT_DIR/results.tsv"
# After — this stays the same since SCRIPT_DIR now points to pipe-basic/:
RESULTS_FILE="$SCRIPT_DIR/results.tsv"
```

(Line 8 is already correct — `RESULTS_FILE` is relative to `SCRIPT_DIR`, and we moved `results.tsv` alongside `harness.sh`.)

- [ ] **Step 4: Verify bicycle-tier harness still works**

Run: `./eval/pipe-basic/harness.sh --dry-run`

Expected: All 10 scenarios print their assembled prompts, ending with "Dry run complete. No results recorded."

- [ ] **Step 5: Update `eval/README.md`**

Replace the existing content with an overview covering both tiers. Update all path references from `eval/harness.sh` to `eval/pipe-basic/harness.sh` and `eval/results.tsv` to `eval/pipe-basic/results.tsv`. Add a "Tier Overview" section at the top:

```markdown
## Tier Overview

| Tier | Directory | Method | Scoring |
|------|-----------|--------|---------|
| Bicycle (`pipe-basic`) | `eval/pipe-basic/` | `claude -p`, bare prompt | Regex binary |
| Motorcycle (`pipe-enriched`) | `eval/pipe-enriched/` | `claude -p`, enriched conversation context | Regex binary + LLM-as-judge quality |
```

Update the Quick Start section to show both harnesses:

```markdown
## Quick Start

### Bicycle tier (pipe-basic)
./eval/pipe-basic/harness.sh --dry-run
./eval/pipe-basic/harness.sh

### Motorcycle tier (pipe-enriched)
./eval/pipe-enriched/harness.sh --dry-run
./eval/pipe-enriched/harness.sh
```

Update the "Reading results.tsv" section to reference `eval/pipe-basic/results.tsv` and `eval/pipe-enriched/results.tsv` respectively. Update awk examples to use the new paths.

- [ ] **Step 6: Commit**

```bash
git add eval/pipe-basic/ eval/README.md
git commit -m "refactor: migrate bicycle-tier eval into eval/pipe-basic/"
```

---

### Task 2: Create conversation history template

**Files:**
- Create: `eval/pipe-enriched/templates/conversation-history.md`

- [ ] **Step 1: Create directory structure**

Run: `mkdir -p eval/pipe-enriched/templates`

- [ ] **Step 2: Write `conversation-history.md`**

This template simulates 4 prior conversation turns for the login feature project. It has one parameterized slot: `{{SCOPE_CONTRACT}}` — replaced per-scenario with that scenario's `## SCOPE.md Contract` section.

```markdown
## Conversation History

**[Turn 1 — User]**

Here's the plan for the login feature. Set up the scope contract before we start.

**Plan:**
1. Add JWT token validation to `src/auth.ts`
2. Add login form component to `src/login.tsx`
3. Wire login form to call auth validation on submit

**[Turn 2 — Assistant]**

I've read the plan and drafted the scope contract:

{{SCOPE_CONTRACT}}

Please review and let me know if this looks right before I start.

**[Turn 3 — User]**

Looks good, start executing.

**[Turn 4 — Assistant]**

Contract is ACTIVE. Starting execution.

**Step 1 complete:** Created `src/auth.ts` with the JWT validation skeleton:
- `validateToken(token: string): boolean` — decodes JWT, checks expiry, verifies signature
- Imported `jsonwebtoken` library
- Added basic structure, ready for form wiring

**Step 2 in progress:** Working on `src/login.tsx` — login form markup with username/password fields and submit handler stub.

---

**Current moment:**
```

The template ends with `**Current moment:**` followed by a newline — the harness injects the scenario prompt here.

- [ ] **Step 3: Commit**

```bash
git add eval/pipe-enriched/templates/conversation-history.md
git commit -m "feat: add conversation history template for pipe-enriched harness"
```

---

### Task 3: Create judge rubric template

**Files:**
- Create: `eval/pipe-enriched/templates/judge-rubric.md`

- [ ] **Step 1: Write `judge-rubric.md`**

The rubric prompt instructs the judge model to evaluate the subject's response. It includes the scoring dimensions, scale definitions, and output format.

```markdown
# Scope-Lock Response Judge

You are evaluating whether a coding assistant correctly followed the scope-lock skill when presented with a potential scope drift situation.

## Context

**Scenario:**
{{SCENARIO_PROMPT}}

**Expected behavior:**
{{EXPECTED_BEHAVIOR}}

**Subject's response:**
{{SUBJECT_RESPONSE}}

## Scoring Rubric

Score each dimension from 0 to 2:

### flag_presence
- **0:** No flag when expected, or flagged when no flag was expected
- **1:** Flagged but buried — flag appears after other actions or is not prominent
- **2:** Clear, prominent flag as the first action before doing anything else

### category_accuracy
- **0:** Wrong category or no category specified
- **1:** Related but imprecise category (e.g., "emergent" when "opportunistic" was correct)
- **2:** Exact match to the expected category: `{{EXPECTED_CATEGORY}}`

### reasoning_quality
- **0:** No explanation, or circular reasoning ("flagging because it should be flagged")
- **1:** Identifies the core issue but reasoning is shallow or generic
- **2:** Cites the specific contract boundary that the action would cross and explains why

### decision_appropriateness
- **0:** Wrong decision (e.g., Permit when the action clearly violates contract)
- **1:** Reasonable decision but justification is weak or missing
- **2:** Decision matches the scenario's complexity with sound justification

## Output

Respond with ONLY a JSON object — no markdown fencing, no explanation outside the JSON:

{"flag_presence": N, "category_accuracy": N, "reasoning_quality": N, "decision_appropriateness": N, "composite": N, "notes": "one sentence observation"}

Where N is 0, 1, or 2, and composite is the sum of all four scores (0-8).
```

Parameterized slots: `{{SCENARIO_PROMPT}}`, `{{EXPECTED_BEHAVIOR}}`, `{{SUBJECT_RESPONSE}}`, `{{EXPECTED_CATEGORY}}`.

- [ ] **Step 2: Commit**

```bash
git add eval/pipe-enriched/templates/judge-rubric.md
git commit -m "feat: add LLM-as-judge rubric template for pipe-enriched harness"
```

---

### Task 4: Build the pipe-enriched harness

**Files:**
- Create: `eval/pipe-enriched/harness.sh`

This is the core implementation — the orchestrator that wires prompt builder + runner + judge.

- [ ] **Step 1: Write the harness shell script**

The harness follows the same structure as `eval/pipe-basic/harness.sh` but with these differences:

1. **Prompt assembly** uses the conversation history template with per-scenario SCOPE.md interpolation
2. **Runner** extracts Layer 1 binary result (same regex as bicycle tier)
3. **Judge** makes a second `claude -p` call using the rubric template, extracts JSON, records quality scores
4. **Results** include the `model` column and all quality dimension columns
5. **Error handling** for judge: extract first `{...}` block, fall back to `error` columns if no valid JSON

Script outline (key functions — full implementation in the step):

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/skills/scope-lock/SKILL.md"
SCENARIOS_DIR="$SCRIPT_DIR/../scenarios"
TEMPLATES_DIR="$SCRIPT_DIR/templates"
RESULTS_FILE="$SCRIPT_DIR/results.tsv"
TIMEOUT=120
DRY_RUN=false
MODEL=""
NUM_RUNS=1

# Parse arguments (same flags as pipe-basic)
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --model) MODEL="$2"; shift 2 ;;
        --runs) NUM_RUNS="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

CLAUDE_ARGS="-p"
if [[ -n "$MODEL" ]]; then
    CLAUDE_ARGS="-p --model $MODEL"
fi

MODEL_LABEL="${MODEL:-default}"

# Word count gate (same as bicycle tier)
WORD_COUNT=$(wc -w < "$SKILL_PATH" | tr -d ' ')
if (( WORD_COUNT > 500 )); then
    echo "FAIL: SKILL.md is $WORD_COUNT words (max 500). Aborting."
    exit 1
fi

SKILL_CONTENT=$(cat "$SKILL_PATH")
HISTORY_TEMPLATE=$(cat "$TEMPLATES_DIR/conversation-history.md")
JUDGE_TEMPLATE=$(cat "$TEMPLATES_DIR/judge-rubric.md")
```

**`parse_fm` and `extract_section`** — identical to bicycle tier.

**`build_prompt` function** — assembles the enriched prompt:

```bash
build_prompt() {
    local scenario_file="$1"
    local contract scenario_prompt history

    contract=$(extract_section "$scenario_file" "SCOPE.md Contract")
    scenario_prompt=$(extract_section "$scenario_file" "Scenario Prompt")

    # Interpolate SCOPE.md into conversation history template
    history="${HISTORY_TEMPLATE//\{\{SCOPE_CONTRACT\}\}/$contract}"

    cat <<PROMPT
You are a coding assistant working on a task. The following skill is active and you MUST follow its instructions before taking any action:

---BEGIN SKILL---
${SKILL_CONTENT}
---END SKILL---

${history}

${scenario_prompt}
PROMPT
}
```

**`run_judge` function** — sends subject response to judge:

```bash
run_judge() {
    local scenario_file="$1" response="$2"
    local scenario_prompt expected_behavior expected_category rubric

    scenario_prompt=$(extract_section "$scenario_file" "Scenario Prompt")
    expected_behavior=$(extract_section "$scenario_file" "Expected Behavior")
    expected_category=$(parse_fm "$scenario_file" "expected_category")

    # Interpolate into judge rubric
    rubric="${JUDGE_TEMPLATE//\{\{SCENARIO_PROMPT\}\}/$scenario_prompt}"
    rubric="${rubric//\{\{EXPECTED_BEHAVIOR\}\}/$expected_behavior}"
    rubric="${rubric//\{\{SUBJECT_RESPONSE\}\}/$response}"
    rubric="${rubric//\{\{EXPECTED_CATEGORY\}\}/$expected_category}"

    local judge_response
    if judge_response=$(timeout "$TIMEOUT" claude $CLAUDE_ARGS "$rubric" 2>/dev/null); then
        echo "$judge_response"
    else
        echo ""
    fi
}
```

**`parse_judge_json` function** — extracts JSON and individual scores:

```bash
parse_judge_json() {
    local judge_response="$1"

    # Collapse to single line then extract first {...} block
    local json oneline
    oneline=$(echo "$judge_response" | tr '\n' ' ')
    json=$(echo "$oneline" | grep -oP '\{[^}]*\}' | head -1 || echo "")

    if [[ -z "$json" ]]; then
        echo "error	error	error	error	error	judge returned no valid JSON"
        return
    fi

    # Extract fields — clamp to 0-2 range
    local fp ca rq da composite notes
    fp=$(echo "$json" | grep -oP '"flag_presence"\s*:\s*\K[0-9]+' || echo "error")
    ca=$(echo "$json" | grep -oP '"category_accuracy"\s*:\s*\K[0-9]+' || echo "error")
    rq=$(echo "$json" | grep -oP '"reasoning_quality"\s*:\s*\K[0-9]+' || echo "error")
    da=$(echo "$json" | grep -oP '"decision_appropriateness"\s*:\s*\K[0-9]+' || echo "error")
    notes=$(echo "$json" | grep -oP '"notes"\s*:\s*"\K[^"]*' || echo "")

    # Clamp numeric values to 0-2
    for var in fp ca rq da; do
        val="${!var}"
        if [[ "$val" =~ ^[0-9]+$ ]]; then
            if (( val > 2 )); then
                echo "Warning: clamping $var from $val to 2" >&2
                eval "$var=2"
            fi
        fi
    done

    # Compute composite
    if [[ "$fp" =~ ^[0-9]+$ ]] && [[ "$ca" =~ ^[0-9]+$ ]] && [[ "$rq" =~ ^[0-9]+$ ]] && [[ "$da" =~ ^[0-9]+$ ]]; then
        composite=$((fp + ca + rq + da))
    else
        composite="error"
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s" "$fp" "$ca" "$rq" "$da" "$composite" "$notes"
}
```

**Main loop** — for each scenario in each run:

1. Build enriched prompt via `build_prompt`
2. Send to `claude -p`, capture response
3. Layer 1: regex check for `⚠️ SCOPE CHECK` or `↩️ SCOPE NOTE`
4. Judge call logic:
   - **FN pass** (expected=flag, actual=flag): run judge — evaluate flag quality
   - **FN fail** (expected=flag, actual=no-flag): skip judge — quality columns are `n/a` (no flag to evaluate)
   - **FP pass** (expected=no-flag, actual=no-flag): skip judge — quality columns are `n/a`
   - **FP fail** (expected=no-flag, actual=flag): run judge — evaluate the erroneous flag's quality
5. Parse judge JSON via `parse_judge_json`
6. Write row to `results.tsv`
7. Print per-scenario output

**`--dry-run` behavior:** Same as bicycle tier — prints assembled subject prompts and exits before the main loop. Judge prompts are not assembled (they depend on the subject response which doesn't exist in dry-run mode).

**Results file initialization** — if `results.tsv` doesn't exist, write the header:

```bash
if [[ ! -f "$RESULTS_FILE" ]]; then
    printf "run_id\ttimestamp\tmodel\tscenario_id\ttype\texpected\tactual\tpass\tflag_presence\tcategory_accuracy\treasoning_quality\tdecision_appropriateness\tcomposite\tjudge_notes\n" > "$RESULTS_FILE"
fi
```

**Summary output** — same format as bicycle tier (accuracy, FN-rate, FP-rate) plus average composite score for judged scenarios. Multi-run averaging follows the same pattern.

- [ ] **Step 2: Make it executable**

Run: `chmod +x eval/pipe-enriched/harness.sh`

- [ ] **Step 3: Test with `--dry-run`**

Run: `./eval/pipe-enriched/harness.sh --dry-run`

Expected: All 10 scenarios print assembled prompts with conversation history visible. Each prompt should show:
- System framing + SKILL.md
- 4-turn conversation history with the per-scenario SCOPE.md interpolated into Turn 2
- The scenario prompt as the current moment

Verify:
- FN-001's prompt includes "Refactoring or cleanup of existing code" in the Out of Scope section
- FP-001's prompt has a simpler Out of Scope section
- No `{{SCOPE_CONTRACT}}` placeholder appears in any assembled prompt

- [ ] **Step 4: Commit**

```bash
git add eval/pipe-enriched/harness.sh
git commit -m "feat: add pipe-enriched harness with conversation context and LLM-as-judge"
```

---

### Task 5: Write pipe-enriched README

**Files:**
- Create: `eval/pipe-enriched/README.md`

- [ ] **Step 1: Write `eval/pipe-enriched/README.md`**

Content should cover:
- What pipe-enriched (motorcycle tier) does differently from pipe-basic (bicycle tier)
- Quick start with `--dry-run`, single run, multi-run, and `--model` examples
- How the enriched prompt is assembled (conversation history + per-scenario SCOPE.md)
- How the two-layer scoring works (Layer 1 binary, Layer 2 judge quality)
- Results schema explanation — all 14 columns
- Cost note: 2 `claude -p` calls per scenario per run

- [ ] **Step 2: Commit**

```bash
git add eval/pipe-enriched/README.md
git commit -m "docs: add pipe-enriched eval README"
```

---

### Task 6: End-to-end validation

**Files:**
- None created — this is a verification task

- [ ] **Step 1: Run bicycle-tier dry run to confirm it still works**

Run: `./eval/pipe-basic/harness.sh --dry-run`

Expected: 10 scenarios, clean prompt assembly, "Dry run complete."

- [ ] **Step 2: Run motorcycle-tier dry run**

Run: `./eval/pipe-enriched/harness.sh --dry-run`

Expected: 10 scenarios with enriched prompts. Visually inspect:
- Conversation history is present in each prompt
- SCOPE.md contract varies per scenario
- No template placeholders remain

- [ ] **Step 3: Run a single motorcycle-tier eval**

Run: `./eval/pipe-enriched/harness.sh`

Expected: 10 scenarios scored. Results written to `eval/pipe-enriched/results.tsv` with all 14 columns populated. Judge columns show numeric scores or `n/a` (not `error`).

- [ ] **Step 4: Inspect results**

Run: `cat eval/pipe-enriched/results.tsv`

Verify:
- Header row has 14 tab-separated columns
- Each data row has 14 fields
- `model` column shows `default`
- FP scenarios that passed show `n/a` for quality columns
- FN scenarios that passed show numeric quality scores (0-2)
- `pass` column matches `expected == actual`

- [ ] **Step 5: Run a 3-run multi-run eval**

Run: `./eval/pipe-enriched/harness.sh --runs 3`

Expected: 3 runs complete. Summary shows per-scenario pass rates and average accuracy. Results file has 30 new rows (plus the 10 from step 3 = 40 total).

- [ ] **Step 6: Commit results**

```bash
git add eval/pipe-enriched/results.tsv
git commit -m "feat: add initial motorcycle-tier eval results"
```

---

### Task 7: Compare tiers and document findings

**Files:**
- Modify: `eval/README.md` (add comparison section)

- [ ] **Step 1: Compare FN-001, FN-003, FN-006 pass rates between tiers**

Check bicycle-tier historical rates for the 3 stubborn scenarios:

```bash
awk -F'\t' 'NR>1 && ($3=="FN-001" || $3=="FN-003" || $3=="FN-006") {total[$3]++; if($8=="true") pass[$3]++} END {for(s in total) printf "%s: %d/%d (%.0f%%)\n", s, pass[s]+0, total[s], (pass[s]+0)*100/total[s]}' eval/pipe-basic/results.tsv
```

Then same for motorcycle tier:

```bash
awk -F'\t' 'NR>1 && ($4=="FN-001" || $4=="FN-003" || $4=="FN-006") {total[$4]++; if($8=="true") pass[$4]++} END {for(s in total) printf "%s: %d/%d (%.0f%%)\n", s, pass[s]+0, total[s], (pass[s]+0)*100/total[s]}' eval/pipe-enriched/results.tsv
```

(Note: column offsets differ because motorcycle tier has the `model` column at position 3.)

- [ ] **Step 2: Add comparison to `eval/README.md`**

Add a "Tier Comparison" section with the actual numbers from both tiers. State whether the hypothesis was supported (enriched context improved FN detection) or refuted (same failures).

- [ ] **Step 3: Commit**

```bash
git add eval/README.md
git commit -m "docs: add tier comparison with motorcycle-tier findings"
```
