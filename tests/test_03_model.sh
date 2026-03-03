#!/usr/bin/env bash
# Test 03 — Model training and prediction
# Verifies that the full ML pipeline runs successfully.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Test 03 — Model Training and Prediction${RESET}"
echo ""

# Ensure dataset exists before running pipeline
log_info "Ensuring dataset exists..."
ssh_vm "python3 /home/labuser/02_dataset.py" >/dev/null 2>&1 || true

# 3.1 Data preparation (module 04)
log_info "Running 04_prepare.py..."
assert_success "04_prepare.py exits with code 0" \
    ssh_vm "python3 /home/labuser/04_prepare.py"

# 3.2 Prepared data files exist
for fname in X_train.npy X_test.npy y_train.npy y_test.npy \
             label_encoder.pkl feature_names.pkl; do
    assert "$fname created by 04_prepare.py" \
        ssh_vm "test -f /home/labuser/data/$fname"
done

# 3.3 Model training (module 05)
log_info "Running 05_train.py..."
assert_success "05_train.py exits with code 0" \
    ssh_vm "python3 /home/labuser/05_train.py"

# 3.4 Model file exists
assert "random_forest.pkl created by 05_train.py" \
    ssh_vm "test -f /home/labuser/data/random_forest.pkl"

# 3.5 Evaluation (module 06)
log_info "Running 06_evaluate.py..."
eval_output=$(ssh_vm "python3 /home/labuser/06_evaluate.py" 2>&1) || true
assert_success "06_evaluate.py exits with code 0" \
    ssh_vm "python3 /home/labuser/06_evaluate.py"

# 3.6 Accuracy is above 85%
# Strip ANSI escape codes, then extract the percentage after "Accuracy:"
acc_val=$(echo "$eval_output" \
    | sed 's/\x1b\[[0-9;]*m//g' \
    | grep -oE "Accuracy: [0-9]+\.[0-9]+" \
    | grep -oE "[0-9]+\.[0-9]+" \
    | head -1) || true
if [[ -n "$acc_val" ]]; then
    if awk "BEGIN { exit ($acc_val < 85.0) ? 0 : 1 }"; then
        log_fail "Model accuracy below 85% (got ${acc_val}%)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    else
        log_ok "Model accuracy >= 85% (${acc_val}%)"
        PASS_COUNT=$((PASS_COUNT + 1))
    fi
else
    log_fail "Could not parse accuracy from 06_evaluate.py output"
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# 3.7 Prediction (module 07)
log_info "Running 07_predict.py..."
assert_success "07_predict.py exits with code 0" \
    ssh_vm "python3 /home/labuser/07_predict.py"

# 3.8 Predictions output contains expected labels
pred_output=$(ssh_vm "python3 /home/labuser/07_predict.py" 2>&1) || true
assert_contains "Predictions contain status labels" "$pred_output" "critical|warning|normal"

report_results "Test 03"
