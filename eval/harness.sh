#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_PATH="$REPO_ROOT/skills/scope-lock/SKILL.md"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
RESULTS_FILE="$SCRIPT_DIR/results.tsv"
TIMEOUT=120
DRY_RUN=false
MODEL=""
NUM_RUNS=1

# Parse arguments
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

# --- Word count gate ---
WORD_COUNT=$(wc -w < "$SKILL_PATH" | tr -d ' ')
if (( WORD_COUNT > 500 )); then
    echo "FAIL: SKILL.md is $WORD_COUNT words (max 500). Aborting."
    exit 1
fi

SKILL_CONTENT=$(cat "$SKILL_PATH")

# --- Parse frontmatter value ---
parse_fm() {
    local file="$1" key="$2"
    local block
    block=$(sed -n '/^---$/,/^---$/p' "$file")
    echo "$block" | grep "^${key}:" | head -1 | sed "s/^${key}:[[:space:]]*//" | sed 's/[[:space:]]*#.*//' || true
}

# --- Extract markdown section ---
extract_section() {
    local file="$1" heading="$2"
    sed -n "/^## ${heading}$/,/^## /{ /^## ${heading}$/d; /^## /d; p; }" "$file"
}

# --- Build scenario list once ---
SCENARIO_FILES=()
SCENARIO_IDS=()
SCENARIO_TYPES=()
SCENARIO_EXPECTED=()
SCENARIO_CATS=()
SCENARIO_PROMPTS=()

for scenario_file in "$SCENARIOS_DIR"/*.md; do
    [[ -f "$scenario_file" ]] || continue
    idx=${#SCENARIO_FILES[@]}
    SCENARIO_FILES+=("$scenario_file")
    SCENARIO_IDS+=($(parse_fm "$scenario_file" "id"))
    SCENARIO_TYPES+=($(parse_fm "$scenario_file" "type"))
    SCENARIO_EXPECTED+=($(parse_fm "$scenario_file" "expected"))
    SCENARIO_CATS+=("$(parse_fm "$scenario_file" "expected_category")")

    PLAN=$(extract_section "$scenario_file" "Plan Context")
    CONTRACT=$(extract_section "$scenario_file" "SCOPE.md Contract")
    PROMPT=$(extract_section "$scenario_file" "Scenario Prompt")

    # Framing simulates how Claude Code presents skills to the model — as active
    # behavioral instructions, not passive context. No format instructions added.
    SCENARIO_PROMPTS+=("You are a coding assistant working on a task. The following skill is active and you MUST follow its instructions before taking any action:

---BEGIN SKILL---
${SKILL_CONTENT}
---END SKILL---

You are currently working on the following plan:

---BEGIN PLAN---
${PLAN}
---END PLAN---

The following scope contract is ACTIVE:

---BEGIN SCOPE.md---
${CONTRACT}
---END SCOPE.md---

${PROMPT}")
done

NUM_SCENARIOS=${#SCENARIO_FILES[@]}

if $DRY_RUN; then
    for ((i=0; i<NUM_SCENARIOS; i++)); do
        echo "=== ${SCENARIO_IDS[$i]} (${SCENARIO_TYPES[$i]}, expected: ${SCENARIO_EXPECTED[$i]}) ==="
        echo "${SCENARIO_PROMPTS[$i]}"
        echo ""
    done
    echo "Dry run complete. No results recorded."
    exit 0
fi

# --- Determine starting run_id ---
if [[ -f "$RESULTS_FILE" ]] && [[ $(wc -l < "$RESULTS_FILE") -gt 1 ]]; then
    LAST_RUN=$(tail -1 "$RESULTS_FILE" | cut -f1)
    RUN_ID=$((LAST_RUN + 1))
else
    RUN_ID=1
fi

# --- Track pass counts per scenario across runs (for averaging) ---
declare -A PASS_COUNTS
for ((i=0; i<NUM_SCENARIOS; i++)); do
    PASS_COUNTS[${SCENARIO_IDS[$i]}]=0
done

# --- Run loop ---
for ((run=0; run<NUM_RUNS; run++)); do
    TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
    CURRENT_RUN=$((RUN_ID + run))

    TOTAL=0
    PASSED=0
    FAILED_IDS=()
    FN_TOTAL=0
    FN_FAILED=0
    FP_TOTAL=0
    FP_FAILED=0

    if (( NUM_RUNS > 1 )); then
        echo "--- Run $((run + 1)) of $NUM_RUNS (ID: $CURRENT_RUN) ---"
    fi

    for ((i=0; i<NUM_SCENARIOS; i++)); do
        SID="${SCENARIO_IDS[$i]}"
        TYPE="${SCENARIO_TYPES[$i]}"
        EXPECTED="${SCENARIO_EXPECTED[$i]}"
        EXPECTED_CAT="${SCENARIO_CATS[$i]}"

        TOTAL=$((TOTAL + 1))
        if [[ "$TYPE" == "false-negative" ]]; then
            FN_TOTAL=$((FN_TOTAL + 1))
        else
            FP_TOTAL=$((FP_TOTAL + 1))
        fi

        # Call Claude with timeout
        RESPONSE=""
        ACTUAL="error"
        if RESPONSE=$(timeout "$TIMEOUT" claude $CLAUDE_ARGS "${SCENARIO_PROMPTS[$i]}" 2>/dev/null); then
            if [[ -n "$RESPONSE" ]]; then
                if echo "$RESPONSE" | grep -q "⚠️ SCOPE CHECK\|↩️ SCOPE NOTE"; then
                    ACTUAL="flag"
                else
                    ACTUAL="no-flag"
                fi
            fi
        else
            echo "  [$SID] ERROR: claude -p failed or timed out" >&2
        fi

        # Score pass/fail
        if [[ "$ACTUAL" == "$EXPECTED" ]]; then
            PASS="true"
            PASSED=$((PASSED + 1))
            PASS_COUNTS[$SID]=$(( ${PASS_COUNTS[$SID]} + 1 ))
        else
            PASS="false"
            FAILED_IDS+=("$SID")
            if [[ "$TYPE" == "false-negative" ]]; then
                FN_FAILED=$((FN_FAILED + 1))
            else
                FP_FAILED=$((FP_FAILED + 1))
            fi
        fi

        # Category match
        CAT_MATCH="n/a"
        if [[ -n "$EXPECTED_CAT" ]] && [[ "$ACTUAL" == "flag" ]]; then
            if echo "$RESPONSE" | grep -qi "$EXPECTED_CAT"; then
                CAT_MATCH="true"
            else
                CAT_MATCH="false"
            fi
        fi

        # Append to results
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$CURRENT_RUN" "$TIMESTAMP" "$SID" "$TYPE" "$EXPECTED" "$ACTUAL" "$CAT_MATCH" "$PASS" \
            >> "$RESULTS_FILE"

        # Per-scenario output
        if [[ "$PASS" == "true" ]]; then
            echo "  ✓ $SID ($TYPE) — PASS"
        else
            echo "  ✗ $SID ($TYPE) — FAIL (expected: $EXPECTED, actual: $ACTUAL)"
        fi
    done

    # --- Per-run summary ---
    FAILED_COUNT=$((TOTAL - PASSED))
    if (( TOTAL > 0 )); then
        ACCURACY=$(( (PASSED * 100) / TOTAL ))
    else
        ACCURACY=0
    fi
    if (( FN_TOTAL > 0 )); then
        FN_RATE=$(( (FN_FAILED * 100) / FN_TOTAL ))
    else
        FN_RATE=0
    fi
    if (( FP_TOTAL > 0 )); then
        FP_RATE=$(( (FP_FAILED * 100) / FP_TOTAL ))
    else
        FP_RATE=0
    fi

    echo ""
    echo "Run #$(printf '%03d' $CURRENT_RUN) | $TIMESTAMP"
    echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED_COUNT"
    echo "Accuracy: ${ACCURACY}% | FN-rate: ${FN_RATE}% (${FN_FAILED}/${FN_TOTAL}) | FP-rate: ${FP_RATE}% (${FP_FAILED}/${FP_TOTAL})"
    if (( ${#FAILED_IDS[@]} > 0 )); then
        echo "Failed: $(IFS=', '; echo "${FAILED_IDS[*]}")"
    fi
    echo ""
done

# --- Multi-run average summary ---
if (( NUM_RUNS > 1 )); then
    echo "==============================="
    echo "AVERAGE ACROSS $NUM_RUNS RUNS"
    echo "==============================="

    TOTAL_PASSES=0
    TOTAL_POSSIBLE=$((NUM_SCENARIOS * NUM_RUNS))
    FN_PASSES=0
    FN_POSSIBLE=0
    FP_PASSES=0
    FP_POSSIBLE=0

    for ((i=0; i<NUM_SCENARIOS; i++)); do
        SID="${SCENARIO_IDS[$i]}"
        TYPE="${SCENARIO_TYPES[$i]}"
        PASSES=${PASS_COUNTS[$SID]}
        TOTAL_PASSES=$((TOTAL_PASSES + PASSES))
        RATE=$(( (PASSES * 100) / NUM_RUNS ))

        if [[ "$TYPE" == "false-negative" ]]; then
            FN_PASSES=$((FN_PASSES + PASSES))
            FN_POSSIBLE=$((FN_POSSIBLE + NUM_RUNS))
        else
            FP_PASSES=$((FP_PASSES + PASSES))
            FP_POSSIBLE=$((FP_POSSIBLE + NUM_RUNS))
        fi

        echo "  $SID: $PASSES/$NUM_RUNS passed (${RATE}%)"
    done

    AVG_ACCURACY=$(( (TOTAL_PASSES * 100) / TOTAL_POSSIBLE ))
    if (( FN_POSSIBLE > 0 )); then
        FN_AVG_FAIL=$(( ((FN_POSSIBLE - FN_PASSES) * 100) / FN_POSSIBLE ))
    else
        FN_AVG_FAIL=0
    fi
    if (( FP_POSSIBLE > 0 )); then
        FP_AVG_FAIL=$(( ((FP_POSSIBLE - FP_PASSES) * 100) / FP_POSSIBLE ))
    else
        FP_AVG_FAIL=0
    fi

    echo ""
    echo "Avg Accuracy: ${AVG_ACCURACY}% | Avg FN-rate: ${FN_AVG_FAIL}% | Avg FP-rate: ${FP_AVG_FAIL}%"
fi
