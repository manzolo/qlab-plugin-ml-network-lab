#!/usr/bin/env bash
# run_all.sh — Run all ml-network-lab tests in order
#
# Usage:
#   bash tests/run_all.sh
#
# Prerequisites: ml-network-lab VM must be running (qlab run ml-network-lab)

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TESTS_DIR/_common.sh"

echo ""
echo "${BOLD}=========================================${RESET}"
echo "${BOLD}  ml-network-lab — Automated Test Suite${RESET}"
echo "${BOLD}=========================================${RESET}"
echo ""

log_info "Workspace: $WORKSPACE_DIR"
log_info "VM port:   $VM_PORT"

# Verify VM is reachable
log_info "Checking VM connectivity..."
assert "VM is reachable via SSH" ssh_vm "echo ok"

# Verify cloud-init has finished
log_info "Checking cloud-init status..."
ci_status=$(ssh_vm "cloud-init status 2>/dev/null || echo done") || true
assert_contains "cloud-init is done" "$ci_status" "done|status: done"

# ── Run tests ────────────────────────────────────────────────────────
TOTAL_PASS=0
TOTAL_FAIL=0
TESTS_RUN=0
FAILED_TESTS=()

run_test() {
    local num="$1"
    local pattern="$TESTS_DIR/test_${num}_*.sh"
    local files=($pattern)

    if [[ ! -f "${files[0]}" ]]; then
        log_info "Test file not found: $pattern"
        return
    fi

    local test_exit=0
    bash "${files[0]}" || test_exit=$?

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$test_exit" -ne 0 ]]; then
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
        FAILED_TESTS+=("$num")
    else
        TOTAL_PASS=$((TOTAL_PASS + 1))
    fi
}

run_test "01"
run_test "02"
run_test "03"

# ── Final report ─────────────────────────────────────────────────────
echo ""
echo "${BOLD}=========================================${RESET}"
echo "${BOLD}  Final Report${RESET}"
echo "${BOLD}=========================================${RESET}"
echo ""
echo "  Tests run:     $TESTS_RUN"
echo "  Tests passed:  $TOTAL_PASS"
echo "  Tests failed:  $TOTAL_FAIL"

if [[ "$TOTAL_FAIL" -gt 0 ]]; then
    echo ""
    printf "${RED}${BOLD}  FAILED tests: %s${RESET}\n" "${FAILED_TESTS[*]}"
    exit 1
else
    echo ""
    printf "${GREEN}${BOLD}  All tests passed!${RESET}\n"
    exit 0
fi
