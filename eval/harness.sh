#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_PATH="$REPO_ROOT/skills/scope-lock/SKILL.md"
SCENARIOS_DIR="$SCRIPT_DIR/scenarios"
RESULTS_FILE="$SCRIPT_DIR/results.tsv"
TIMEOUT=120
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# --- Word count gate ---
WORD_COUNT=$(wc -w < "$SKILL_PATH" | tr -d ' ')
if (( WORD_COUNT > 500 )); then
    echo "FAIL: SKILL.md is $WORD_COUNT words (max 500). Aborting."
    exit 1
fi

# --- Determine run_id ---
if [[ -f "$RESULTS_FILE" ]] && [[ $(wc -l < "$RESULTS_FILE") -gt 1 ]]; then
    LAST_RUN=$(tail -1 "$RESULTS_FILE" | cut -f1)
    RUN_ID=$((LAST_RUN + 1))
else
    RUN_ID=1
fi

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S")
SKILL_CONTENT=$(cat "$SKILL_PATH")

# --- Counters ---
TOTAL=0
PASSED=0
FAILED_IDS=()
FN_TOTAL=0
FN_FAILED=0
FP_TOTAL=0
FP_FAILED=0

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

# --- Main loop ---
for scenario_file in "$SCENARIOS_DIR"/*.md; do
    [[ -f "$scenario_file" ]] || continue

    SCENARIO_ID=$(parse_fm "$scenario_file" "id")
    TYPE=$(parse_fm "$scenario_file" "type")
    EXPECTED=$(parse_fm "$scenario_file" "expected")
    EXPECTED_CAT=$(parse_fm "$scenario_file" "expected_category")

    PLAN=$(extract_section "$scenario_file" "Plan Context")
    CONTRACT=$(extract_section "$scenario_file" "SCOPE.md Contract")
    PROMPT=$(extract_section "$scenario_file" "Scenario Prompt")

    # NOTE: No "respond in this format" instruction is included. This is intentional —
    # we are testing whether SKILL.md alone is sufficient to produce structured output.
    FULL_PROMPT="You are a coding assistant working on a task. You have the following skill loaded:

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

${PROMPT}"

    TOTAL=$((TOTAL + 1))

    if [[ "$TYPE" == "false-negative" ]]; then
        FN_TOTAL=$((FN_TOTAL + 1))
    else
        FP_TOTAL=$((FP_TOTAL + 1))
    fi

    if $DRY_RUN; then
        echo "=== $SCENARIO_ID ($TYPE, expected: $EXPECTED) ==="
        echo "$FULL_PROMPT"
        echo ""
        continue
    fi

    # Call Claude with timeout
    RESPONSE=""
    ACTUAL="error"
    if RESPONSE=$(timeout "$TIMEOUT" claude -p "$FULL_PROMPT" 2>/dev/null); then
        if [[ -n "$RESPONSE" ]]; then
            if echo "$RESPONSE" | grep -q "⚠️ SCOPE CHECK\|↩️ SCOPE NOTE"; then
                ACTUAL="flag"
            else
                ACTUAL="no-flag"
            fi
        fi
    else
        echo "  [$SCENARIO_ID] ERROR: claude -p failed or timed out" >&2
    fi

    # Score pass/fail
    if [[ "$ACTUAL" == "$EXPECTED" ]]; then
        PASS="true"
        PASSED=$((PASSED + 1))
    else
        PASS="false"
        FAILED_IDS+=("$SCENARIO_ID")
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
        "$RUN_ID" "$TIMESTAMP" "$SCENARIO_ID" "$TYPE" "$EXPECTED" "$ACTUAL" "$CAT_MATCH" "$PASS" \
        >> "$RESULTS_FILE"

    # Per-scenario output
    if [[ "$PASS" == "true" ]]; then
        echo "  ✓ $SCENARIO_ID ($TYPE) — PASS"
    else
        echo "  ✗ $SCENARIO_ID ($TYPE) — FAIL (expected: $EXPECTED, actual: $ACTUAL)"
    fi
done

if $DRY_RUN; then
    echo "Dry run complete. No results recorded."
    exit 0
fi

# --- Summary ---
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
echo "Run #$(printf '%03d' $RUN_ID) | $TIMESTAMP"
echo "Total: $TOTAL | Passed: $PASSED | Failed: $FAILED_COUNT"
echo "Accuracy: ${ACCURACY}% | FN-rate: ${FN_RATE}% (${FN_FAILED}/${FN_TOTAL}) | FP-rate: ${FP_RATE}% (${FP_FAILED}/${FP_TOTAL})"

if (( ${#FAILED_IDS[@]} > 0 )); then
    echo "Failed: $(IFS=', '; echo "${FAILED_IDS[*]}")"
fi
