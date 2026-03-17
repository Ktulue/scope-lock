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
CONVERSATION_TEMPLATE=$(cat "$TEMPLATES_DIR/conversation-history.md")
JUDGE_TEMPLATE=$(cat "$TEMPLATES_DIR/judge-rubric.md")

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

# --- Build enriched prompt ---
build_prompt() {
    local scenario_file="$1"
    local contract prompt interpolated

    contract=$(extract_section "$scenario_file" "SCOPE.md Contract")
    prompt=$(extract_section "$scenario_file" "Scenario Prompt")

    # Interpolate contract into conversation history template
    interpolated="${CONVERSATION_TEMPLATE//\{\{SCOPE_CONTRACT\}\}/$contract}"

    printf '%s' "You are a coding assistant working on a task. The following skill is active and you MUST follow its instructions before taking any action:

---BEGIN SKILL---
${SKILL_CONTENT}
---END SKILL---

The following is your conversation history with the user:

---BEGIN CONVERSATION---
${interpolated}
---END CONVERSATION---

${prompt}"
}

# --- Run judge ---
run_judge() {
    local scenario_file="$1" response="$2"
    local scenario_prompt expected_behavior expected_category judge_prompt

    scenario_prompt=$(extract_section "$scenario_file" "Scenario Prompt")
    expected_behavior=$(extract_section "$scenario_file" "Expected Behavior")
    expected_category=$(parse_fm "$scenario_file" "expected_category")

    # Interpolate into judge rubric
    judge_prompt="${JUDGE_TEMPLATE//\{\{SCENARIO_PROMPT\}\}/$scenario_prompt}"
    judge_prompt="${judge_prompt//\{\{EXPECTED_BEHAVIOR\}\}/$expected_behavior}"
    judge_prompt="${judge_prompt//\{\{SUBJECT_RESPONSE\}\}/$response}"
    judge_prompt="${judge_prompt//\{\{EXPECTED_CATEGORY\}\}/$expected_category}"

    local judge_response=""
    if judge_response=$(timeout "$TIMEOUT" claude $CLAUDE_ARGS "$judge_prompt" 2>/dev/null); then
        echo "$judge_response"
    else
        echo ""
    fi
}

# --- Parse judge JSON response ---
parse_judge_json() {
    local judge_response="$1"

    if [[ -z "$judge_response" ]]; then
        printf 'error\terror\terror\terror\terror\tjudge returned no valid JSON'
        return
    fi

    # Collapse to single line and extract first {...} block
    local single_line json_block
    single_line=$(echo "$judge_response" | tr '\n' ' ')
    json_block=$(echo "$single_line" | grep -oP '\{[^}]*\}' | head -1) || true

    if [[ -z "$json_block" ]]; then
        printf 'error\terror\terror\terror\terror\tjudge returned no valid JSON'
        return
    fi

    # Extract individual scores
    local fp ca rq da composite notes

    fp=$(echo "$json_block" | grep -oP '"flag_presence"\s*:\s*\K[0-9]+' | head -1) || true
    ca=$(echo "$json_block" | grep -oP '"category_accuracy"\s*:\s*\K[0-9]+' | head -1) || true
    rq=$(echo "$json_block" | grep -oP '"reasoning_quality"\s*:\s*\K[0-9]+' | head -1) || true
    da=$(echo "$json_block" | grep -oP '"decision_appropriateness"\s*:\s*\K[0-9]+' | head -1) || true
    notes=$(echo "$json_block" | grep -oP '"notes"\s*:\s*"\K[^"]*' | head -1) || true

    # Clamp each score to 0-2 range
    for var_name in fp ca rq da; do
        local val
        eval "val=\$$var_name"
        if [[ -n "$val" ]] && [[ "$val" =~ ^[0-9]+$ ]]; then
            if (( val > 2 )); then
                echo "Warning: clamping $var_name from $val to 2" >&2
                eval "$var_name=2"
            fi
        fi
    done

    # Compute composite
    if [[ -n "$fp" ]] && [[ "$fp" =~ ^[0-9]+$ ]] && \
       [[ -n "$ca" ]] && [[ "$ca" =~ ^[0-9]+$ ]] && \
       [[ -n "$rq" ]] && [[ "$rq" =~ ^[0-9]+$ ]] && \
       [[ -n "$da" ]] && [[ "$da" =~ ^[0-9]+$ ]]; then
        composite=$(( fp + ca + rq + da ))
    else
        composite="error"
    fi

    [[ -z "$fp" ]] && fp="error"
    [[ -z "$ca" ]] && ca="error"
    [[ -z "$rq" ]] && rq="error"
    [[ -z "$da" ]] && da="error"
    [[ -z "$notes" ]] && notes=""

    printf '%s\t%s\t%s\t%s\t%s\t%s' "$fp" "$ca" "$rq" "$da" "$composite" "$notes"
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
    SCENARIO_FILES+=("$scenario_file")
    SCENARIO_IDS+=($(parse_fm "$scenario_file" "id"))
    SCENARIO_TYPES+=($(parse_fm "$scenario_file" "type"))
    SCENARIO_EXPECTED+=($(parse_fm "$scenario_file" "expected"))
    SCENARIO_CATS+=("$(parse_fm "$scenario_file" "expected_category")")
    SCENARIO_PROMPTS+=("$(build_prompt "$scenario_file")")
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

# --- Initialize results file ---
if [[ ! -f "$RESULTS_FILE" ]]; then
    printf "run_id\ttimestamp\tmodel\tscenario_id\ttype\texpected\tactual\tpass\tflag_presence\tcategory_accuracy\treasoning_quality\tdecision_appropriateness\tcomposite\tjudge_notes\n" > "$RESULTS_FILE"
fi

# --- Determine model label ---
MODEL_LABEL="${MODEL:-default}"

# --- Determine starting run_id ---
if [[ -f "$RESULTS_FILE" ]] && [[ $(wc -l < "$RESULTS_FILE") -gt 1 ]]; then
    LAST_RUN=$(tail -1 "$RESULTS_FILE" | cut -f1)
    RUN_ID=$((LAST_RUN + 1))
else
    RUN_ID=1
fi

# --- Track pass counts and composite scores per scenario across runs ---
declare -A PASS_COUNTS
declare -A COMPOSITE_SUMS
declare -A COMPOSITE_COUNTS
for ((i=0; i<NUM_SCENARIOS; i++)); do
    PASS_COUNTS[${SCENARIO_IDS[$i]}]=0
    COMPOSITE_SUMS[${SCENARIO_IDS[$i]}]=0
    COMPOSITE_COUNTS[${SCENARIO_IDS[$i]}]=0
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
    RUN_COMPOSITE_SUM=0
    RUN_COMPOSITE_COUNT=0

    if (( NUM_RUNS > 1 )); then
        echo "--- Run $((run + 1)) of $NUM_RUNS (ID: $CURRENT_RUN) ---"
    fi

    for ((i=0; i<NUM_SCENARIOS; i++)); do
        SID="${SCENARIO_IDS[$i]}"
        TYPE="${SCENARIO_TYPES[$i]}"
        EXPECTED="${SCENARIO_EXPECTED[$i]}"

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

        # Judge call: run whenever actual=="flag", skip when actual=="no-flag" or "error"
        JUDGE_SCORES=""
        if [[ "$ACTUAL" == "flag" ]]; then
            echo "  [$SID] Running judge..." >&2
            JUDGE_RESPONSE=$(run_judge "${SCENARIO_FILES[$i]}" "$RESPONSE")
            JUDGE_SCORES=$(parse_judge_json "$JUDGE_RESPONSE")
        else
            JUDGE_SCORES="n/a\tn/a\tn/a\tn/a\tn/a\t"
        fi

        # Extract composite for averaging
        JUDGE_COMPOSITE=$(echo -e "$JUDGE_SCORES" | cut -f5)
        if [[ "$JUDGE_COMPOSITE" =~ ^[0-9]+$ ]]; then
            RUN_COMPOSITE_SUM=$((RUN_COMPOSITE_SUM + JUDGE_COMPOSITE))
            RUN_COMPOSITE_COUNT=$((RUN_COMPOSITE_COUNT + 1))
            COMPOSITE_SUMS[$SID]=$(( ${COMPOSITE_SUMS[$SID]} + JUDGE_COMPOSITE ))
            COMPOSITE_COUNTS[$SID]=$(( ${COMPOSITE_COUNTS[$SID]} + 1 ))
        fi

        # Append to results (14 columns)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$CURRENT_RUN" "$TIMESTAMP" "$MODEL_LABEL" "$SID" "$TYPE" "$EXPECTED" "$ACTUAL" "$PASS" \
            "$(echo -e "$JUDGE_SCORES")" \
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

    AVG_COMPOSITE="n/a"
    if (( RUN_COMPOSITE_COUNT > 0 )); then
        AVG_COMPOSITE=$(( RUN_COMPOSITE_SUM / RUN_COMPOSITE_COUNT ))
    fi

    echo ""
    echo "Run #$(printf '%03d' $CURRENT_RUN) | $TIMESTAMP | Model: $MODEL_LABEL"
    echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED_COUNT"
    echo "Accuracy: ${ACCURACY}% | FN-rate: ${FN_RATE}% (${FN_FAILED}/${FN_TOTAL}) | FP-rate: ${FP_RATE}% (${FP_FAILED}/${FP_TOTAL})"
    echo "Avg composite (judged scenarios): $AVG_COMPOSITE"
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
    GRAND_COMPOSITE_SUM=0
    GRAND_COMPOSITE_COUNT=0

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

        SC_COMPOSITE_COUNT=${COMPOSITE_COUNTS[$SID]}
        if (( SC_COMPOSITE_COUNT > 0 )); then
            SC_COMPOSITE_AVG=$(( ${COMPOSITE_SUMS[$SID]} / SC_COMPOSITE_COUNT ))
            echo "  $SID: $PASSES/$NUM_RUNS passed (${RATE}%) | avg composite: $SC_COMPOSITE_AVG"
            GRAND_COMPOSITE_SUM=$((GRAND_COMPOSITE_SUM + ${COMPOSITE_SUMS[$SID]}))
            GRAND_COMPOSITE_COUNT=$((GRAND_COMPOSITE_COUNT + SC_COMPOSITE_COUNT))
        else
            echo "  $SID: $PASSES/$NUM_RUNS passed (${RATE}%)"
        fi
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

    GRAND_AVG_COMPOSITE="n/a"
    if (( GRAND_COMPOSITE_COUNT > 0 )); then
        GRAND_AVG_COMPOSITE=$(( GRAND_COMPOSITE_SUM / GRAND_COMPOSITE_COUNT ))
    fi

    echo ""
    echo "Avg Accuracy: ${AVG_ACCURACY}% | Avg FN-rate: ${FN_AVG_FAIL}% | Avg FP-rate: ${FP_AVG_FAIL}%"
    echo "Avg composite (judged scenarios): $GRAND_AVG_COMPOSITE"
fi
