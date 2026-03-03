#!/usr/bin/env bash
# ml-network-lab install script

set -euo pipefail

echo ""
echo "  [ml-network-lab] Installing..."
echo ""
echo "  This plugin teaches Machine Learning applied to network monitoring."
echo "  You will train a Random Forest to classify router health status."
echo ""
echo "  What you will learn:"
echo "    - How to generate and explore a network dataset with pandas"
echo "    - How to prepare features and split train/test data"
echo "    - How to train a Random Forest with scikit-learn"
echo "    - How to evaluate a model with accuracy, confusion matrix, and F1"
echo "    - How to make predictions on new, unseen routers"
echo ""

# Create lab working directory
mkdir -p lab

# Check for required tools
echo "  Checking dependencies..."
local_ok=true
for cmd in qemu-system-x86_64 qemu-img genisoimage curl; do
    if command -v "$cmd" &>/dev/null; then
        echo "    [OK] $cmd"
    else
        echo "    [!!] $cmd — not found (install before running)"
        local_ok=false
    fi
done

if [[ "$local_ok" == true ]]; then
    echo ""
    echo "  All dependencies are available."
else
    echo ""
    echo "  Some dependencies are missing. Install them with:"
    echo "    sudo apt install qemu-kvm qemu-utils genisoimage curl"
fi

echo ""
echo "  [ml-network-lab] Installation complete."
echo "  Run with: qlab run ml-network-lab"
