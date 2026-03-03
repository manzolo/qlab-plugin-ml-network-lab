#!/usr/bin/env bash
# Test 02 — Dataset generation
# Verifies that running 02_dataset.py produces a valid CSV.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Test 02 — Dataset Generation${RESET}"
echo ""

# 2.1 Run the dataset generation script
log_info "Running 02_dataset.py on the VM..."
assert_success "02_dataset.py exits with code 0" \
    ssh_vm "python3 /home/labuser/02_dataset.py"

# 2.2 CSV file was created
assert "router_dataset.csv exists" \
    ssh_vm "test -f /home/labuser/data/router_dataset.csv"

# 2.3 CSV has the expected number of rows (500 data + 1 header = 501 lines)
line_count=$(ssh_vm "wc -l < /home/labuser/data/router_dataset.csv" 2>/dev/null) || true
assert_contains "CSV has ~500 data rows" "$line_count" "^50[0-9]$"

# 2.4 CSV has expected columns
header=$(ssh_vm "head -1 /home/labuser/data/router_dataset.csv" 2>/dev/null) || true
assert_contains "CSV has router_id column"           "$header" "router_id"
assert_contains "CSV has cpu_usage_pct column"       "$header" "cpu_usage_pct"
assert_contains "CSV has temperature_celsius column"  "$header" "temperature_celsius"
assert_contains "CSV has packet_loss_pct column"     "$header" "packet_loss_pct"
assert_contains "CSV has error_rate column"          "$header" "error_rate"
assert_contains "CSV has status column"              "$header" "status"

# 2.5 All three status labels are present (grep directly on VM — avoids shell variable truncation)
assert "CSV contains 'critical' entries" \
    ssh_vm "grep -q 'critical' /home/labuser/data/router_dataset.csv"
assert "CSV contains 'warning' entries" \
    ssh_vm "grep -q 'warning'  /home/labuser/data/router_dataset.csv"
assert "CSV contains 'normal' entries" \
    ssh_vm "grep -q 'normal'   /home/labuser/data/router_dataset.csv"

# 2.6 Dataset is reproducible (seed=42 → same row count every run)
assert_success "Second run of 02_dataset.py also succeeds" \
    ssh_vm "python3 /home/labuser/02_dataset.py"
line_count2=$(ssh_vm "wc -l < /home/labuser/data/router_dataset.csv" 2>/dev/null) || true
assert_contains "Dataset row count is reproducible" "$line_count2" "^50[0-9]$"

report_results "Test 02"
