#!/usr/bin/env bash
# Test 01 — Python environment
# Verifies Python3, pip, and required ML packages are installed.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

echo ""
echo "${BOLD}Test 01 — Python Environment${RESET}"
echo ""

# 1.1 Python3 is available
assert "python3 is installed" ssh_vm "which python3"

# 1.2 pip3 is available
assert "pip3 is installed" ssh_vm "which pip3"

# 1.3 Required packages are importable
out=$(ssh_vm "python3 -c 'import sklearn; print(sklearn.__version__)'" 2>&1) || true
assert_contains "scikit-learn is importable" "$out" "[0-9]+\.[0-9]+"

out=$(ssh_vm "python3 -c 'import pandas; print(pandas.__version__)'" 2>&1) || true
assert_contains "pandas is importable" "$out" "[0-9]+\.[0-9]+"

out=$(ssh_vm "python3 -c 'import numpy; print(numpy.__version__)'" 2>&1) || true
assert_contains "numpy is importable" "$out" "[0-9]+\.[0-9]+"

out=$(ssh_vm "python3 -c 'import matplotlib; print(matplotlib.__version__)'" 2>&1) || true
assert_contains "matplotlib is importable" "$out" "[0-9]+\.[0-9]+"

# 1.4 Course scripts exist
for script in menu.py 01_intro.py 02_dataset.py 03_explore.py \
              04_prepare.py 05_train.py 06_evaluate.py 07_predict.py; do
    assert "$script exists in /home/labuser/" \
        ssh_vm "test -f /home/labuser/$script"
done

# 1.5 Data directory exists
assert "data/ directory exists" ssh_vm "test -d /home/labuser/data"

report_results "Test 01"
