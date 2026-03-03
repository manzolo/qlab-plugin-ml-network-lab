#!/usr/bin/env bash
# ml-network-lab run script — boots a VM with Python + scikit-learn for ML practice

set -euo pipefail

PLUGIN_NAME="ml-network-lab"

echo "============================================="
echo "  ml-network-lab: Machine Learning for Networks"
echo "============================================="
echo ""
echo "  This lab demonstrates:"
echo "    1. Generating a simulated router dataset with reproducible seed"
echo "    2. Exploring and preparing data with pandas"
echo "    3. Training a Random Forest classifier with scikit-learn"
echo "    4. Evaluating the model with accuracy, confusion matrix, and F1"
echo "    5. Making predictions on new routers"
echo ""

# Source QLab core libraries
if [[ -z "${QLAB_ROOT:-}" ]]; then
    echo "ERROR: QLAB_ROOT not set. Run this plugin via 'qlab run ${PLUGIN_NAME}'."
    exit 1
fi

for lib_file in "$QLAB_ROOT"/lib/*.bash; do
    # shellcheck source=/dev/null
    [[ -f "$lib_file" ]] && source "$lib_file"
done

# Configuration
WORKSPACE_DIR="${WORKSPACE_DIR:-.qlab}"
LAB_DIR="lab"
IMAGE_DIR="$WORKSPACE_DIR/images"
CLOUD_IMAGE_URL=$(get_config CLOUD_IMAGE_URL "https://cloud-images.ubuntu.com/minimal/releases/jammy/release/ubuntu-22.04-minimal-cloudimg-amd64.img")
CLOUD_IMAGE_FILE="$IMAGE_DIR/ubuntu-22.04-minimal-cloudimg-amd64.img"
MEMORY="${QLAB_MEMORY:-$(get_config DEFAULT_MEMORY 1536)}"

# Ensure directories exist
mkdir -p "$LAB_DIR" "$IMAGE_DIR"

# Step 1: Download cloud image if not present
info "Step 1: Cloud image"
if [[ -f "$CLOUD_IMAGE_FILE" ]]; then
    success "Cloud image already downloaded: $CLOUD_IMAGE_FILE"
else
    echo ""
    echo "  Cloud images are pre-built OS images designed for cloud environments."
    echo "  They are minimal and expect cloud-init to configure them on first boot."
    echo ""
    info "Downloading Ubuntu cloud image..."
    echo "  URL: $CLOUD_IMAGE_URL"
    echo "  This may take a few minutes depending on your connection."
    echo ""
    check_dependency curl || exit 1
    curl -L -o "$CLOUD_IMAGE_FILE" "$CLOUD_IMAGE_URL" || {
        error "Failed to download cloud image."
        echo "  Check your internet connection and try again."
        exit 1
    }
    success "Cloud image downloaded: $CLOUD_IMAGE_FILE"
fi
echo ""

# Step 2: Create cloud-init configuration
info "Step 2: Cloud-init configuration"
echo ""
echo "  cloud-init will:"
echo "    - Create a user 'labuser' with SSH access"
echo "    - Install python3, pip, and venv"
echo "    - Install scikit-learn, pandas, numpy, matplotlib via pip"
echo "    - Write all Python course scripts to /home/labuser/"
echo "    - Configure a colorful MOTD"
echo ""

# Write Python course scripts to temp files, then base64-encode them.
# This avoids YAML indentation issues: Python multi-line strings with
# short indentation would break the YAML literal block scalar (requires >=6 spaces).
SCRIPT_DIR=$(mktemp -d)
trap 'rm -rf "$SCRIPT_DIR"' EXIT

# ── menu.py ─────────────────────────────────────────────────────────
cat > "$SCRIPT_DIR/menu.py" << 'PYEOF'
#!/usr/bin/env python3
"""Interactive menu for the ML Network Lab course.
Saves progress to ~/.ml_progress (JSON file).
"""
import json
import os
import subprocess
import sys

PROGRESS_FILE = os.path.expanduser("~/.ml_progress")

MODULES = [
    ("01_intro.py",    "Introduction: ML for networks"),
    ("02_dataset.py",  "Dataset generation (fixed seed)"),
    ("03_explore.py",  "Data exploration with pandas"),
    ("04_prepare.py",  "Data preparation and feature engineering"),
    ("05_train.py",    "Training a Random Forest"),
    ("06_evaluate.py", "Model evaluation"),
    ("07_predict.py",  "Predictions on new routers"),
]

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"
GREY   = "\033[0;37m"

def load_progress():
    if os.path.exists(PROGRESS_FILE):
        try:
            with open(PROGRESS_FILE) as f:
                return json.load(f)
        except Exception:
            pass
    return {"completed": []}

def save_progress(progress):
    with open(PROGRESS_FILE, "w") as f:
        json.dump(progress, f, indent=2)

def print_header():
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {GREEN}ml-network-lab{RESET} — {BOLD}Machine Learning for Networks{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

def print_menu(progress):
    print(f"  {YELLOW}Course modules:{RESET}\n")
    for i, (filename, title) in enumerate(MODULES, 1):
        done = filename in progress["completed"]
        status = f"{GREEN}[✓]{RESET}" if done else f"{GREY}[ ]{RESET}"
        print(f"    {status}  {BOLD}{i}.{RESET} {title}")
    print()
    print(f"    {BOLD}q.{RESET} Quit")
    print()

def run_module(filename):
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)
    if not os.path.exists(script):
        print(f"{RED}  Error: file not found: {script}{RESET}")
        return False
    print(f"\n{CYAN}{'─'*60}{RESET}")
    print(f"  Running: {BOLD}{filename}{RESET}")
    print(f"{CYAN}{'─'*60}{RESET}\n")
    result = subprocess.run([sys.executable, script])
    return result.returncode == 0

def main():
    progress = load_progress()
    while True:
        print_header()
        print_menu(progress)
        choice = input("  Choose a module (1-7) or 'q' to quit: ").strip().lower()
        if choice == "q":
            print(f"\n  {GREEN}See you next time!{RESET}\n")
            break
        if not choice.isdigit() or not (1 <= int(choice) <= len(MODULES)):
            print(f"  {RED}Invalid choice. Enter a number from 1 to {len(MODULES)}.{RESET}")
            input("  Press ENTER to continue...")
            continue
        idx = int(choice) - 1
        filename, title = MODULES[idx]
        ok = run_module(filename)
        if ok:
            if filename not in progress["completed"]:
                progress["completed"].append(filename)
                save_progress(progress)
            print(f"\n  {GREEN}Module completed!{RESET} Progress saved.")
        else:
            print(f"\n  {RED}The module exited with an error.{RESET}")
        input("  Press ENTER to return to the menu...")

if __name__ == "__main__":
    main()
PYEOF

# ── 01_intro.py ─────────────────────────────────────────────────────
cat > "$SCRIPT_DIR/01_intro.py" << 'PYEOF'
#!/usr/bin/env python3
"""Module 01 — Introduction: ML for networks."""

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"

def pause():
    try:
        input(f"\n  {CYAN}[ press ENTER to continue ]{RESET}\n")
    except EOFError:
        pass  # non-interactive mode (tests, pipes)

def section(title):
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {BOLD}{title}{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

section("1. What is Machine Learning?")
print(
    "  Machine Learning (ML) is a branch of artificial intelligence\n"
    "  where computers learn from data, without being explicitly\n"
    "  programmed for every case.\n"
    "\n"
    "  Instead of writing rules like:\n"
    '    "if cpu > 90% then status = critical"\n'
    "\n"
    "  ...we train a model that learns these rules from historical data.\n"
    "  The model sees thousands of labeled examples and figures out\n"
    "  on its own which combinations of values indicate a problem.\n"
)
pause()

section("2. Supervised vs Unsupervised Learning")
print(
    "  SUPERVISED learning:\n"
    "    - Data has labels (e.g. 'critical', 'warning', 'normal')\n"
    "    - The model learns to predict the label for new data\n"
    "    - Example: classify router health status\n"
    "\n"
    "  UNSUPERVISED learning:\n"
    "    - Data has NO labels\n"
    "    - The model finds hidden patterns on its own\n"
    "    - Example: group similar routers (clustering)\n"
    "\n"
    "  In this lab we use SUPERVISED learning: we have a dataset\n"
    "  of routers with pre-labeled status, and we train the model\n"
    "  to classify new routers.\n"
)
pause()

section("3. Why Random Forest for network monitoring?")
print(
    "  Random Forest is particularly well-suited because:\n"
    "\n"
    "  \u2713 Handles mixed data well (numeric and categorical)\n"
    "  \u2713 Resists overfitting thanks to the ensemble of trees\n"
    "  \u2713 Provides feature importances (explains decisions)\n"
    "  \u2713 Works well without normalizing data\n"
    "  \u2713 Fast to train on medium-sized datasets\n"
    "\n"
    "  For network monitoring it is ideal because:\n"
    "  - Data (CPU, traffic, temperature) have different scales\n"
    "  - Relationships between features are non-linear\n"
    "  - We want to understand WHY the model flags a router as critical\n"
)
pause()

section("4. What we will learn in this lab")
print(
    f"  \033[1;33mModule 01\033[0m — Introduction (this module)\n"
    f"  \033[1;33mModule 02\033[0m — Generate a simulated router dataset with a fixed seed\n"
    f"  \033[1;33mModule 03\033[0m — Explore data with pandas (shape, describe, correlations)\n"
    f"  \033[1;33mModule 04\033[0m — Prepare data: feature selection, encoding, train/test split\n"
    f"  \033[1;33mModule 05\033[0m — Train a Random Forest with scikit-learn\n"
    f"  \033[1;33mModule 06\033[0m — Evaluate the model: accuracy, confusion matrix, F1, feature importances\n"
    f"  \033[1;33mModule 07\033[0m — Make predictions on new, unseen routers\n"
    "\n"
    f"  \033[1;32mBy the end you will be able to train an ML classifier on real network data.\033[0m\n"
)
pause()
print(f"  \033[1;32mModule 01 complete!\033[0m Go back to the menu and choose module 02.\n")
PYEOF

# ── 02_dataset.py ───────────────────────────────────────────────────
cat > "$SCRIPT_DIR/02_dataset.py" << 'PYEOF'
#!/usr/bin/env python3
"""Module 02 — Router dataset generation with a fixed seed."""

import numpy as np
import pandas as pd
import os

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"

def pause():
    try:
        input(f"\n  {CYAN}[ press ENTER to continue ]{RESET}\n")
    except EOFError:
        pass

def section(title):
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {BOLD}{title}{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

section("1. Why does a seed guarantee reproducibility?")
print(
    "  Random number generators are not truly random:\n"
    "  they start from an initial number (the 'seed') and produce\n"
    "  a deterministic sequence.\n"
    "\n"
    "  With the same seed we always get the same data:\n"
    "    - Your results will be identical to mine\n"
    "    - We can compare experiments\n"
    "    - Debugging is possible (the problem is reproducible)\n"
    "\n"
    "  In this lab we use seed=42 (a common convention in ML).\n"
)
pause()

section("2. How numpy.random works with a seed")
print(
    "  import numpy as np\n"
    "  rng = np.random.default_rng(seed=42)\n"
    "\n"
    "  # Every call produces the same result with the same seed:\n"
    "  rng.uniform(0, 100, size=5)\n"
    "  # --> [ 7.7 43.8 85.8 69.7 94.8 ]  (always these values)\n"
    "\n"
    "  We use rng.uniform() for float values in a range,\n"
    "  rng.integers() for integer values, and rng.choice() to\n"
    "  pick from a list of values.\n"
)
pause()

section("3. Generating the dataset")
print("  Generating 500 samples for 50 routers (10 samples each)...\n")

N = 500
rng = np.random.default_rng(seed=42)

router_ids = [f"R{i:03d}" for i in range(1, 51)]
router_id  = np.repeat(router_ids, 10)

base_time  = pd.Timestamp("now") - pd.Timedelta(hours=24)
timestamps = [base_time + pd.Timedelta(minutes=int(m))
              for m in rng.uniform(0, 1440, size=N)]

traffic_in   = rng.uniform(0, 1000, N).round(2)
traffic_out  = rng.uniform(0, 800,  N).round(2)
cpu          = rng.uniform(5, 100,  N).round(2)
temperature  = rng.uniform(30, 85,  N).round(2)
packet_loss  = rng.uniform(0, 5,    N).round(3)
error_rate   = rng.uniform(0, 10,   N).round(3)
uptime       = rng.integers(1, 8760, N)

def classify(cpu_v, temp_v, pkt_v, err_v):
    if cpu_v > 90 or temp_v > 80 or pkt_v > 3 or err_v > 7:
        return "critical"
    elif cpu_v > 70 or temp_v > 70 or pkt_v > 1.5 or err_v > 3:
        return "warning"
    return "normal"

status = [classify(c, t, p, e)
          for c, t, p, e in zip(cpu, temperature, packet_loss, error_rate)]

df = pd.DataFrame({
    "router_id":          router_id,
    "timestamp":          timestamps,
    "traffic_in_mbps":    traffic_in,
    "traffic_out_mbps":   traffic_out,
    "cpu_usage_pct":      cpu,
    "temperature_celsius":temperature,
    "packet_loss_pct":    packet_loss,
    "error_rate":         error_rate,
    "uptime_hours":       uptime,
    "status":             status,
})

os.makedirs("/home/labuser/data", exist_ok=True)
CSV_PATH = "/home/labuser/data/router_dataset.csv"
df.to_csv(CSV_PATH, index=False)
print(f"  {GREEN}Dataset saved to:{RESET} {CSV_PATH}")
print(f"  Size: {df.shape[0]} rows x {df.shape[1]} columns\n")

section("4. First rows of the dataset")
print(df.head(10).to_string(index=False))
pause()

section("5. Column descriptions")
print(
    "  router_id           — router identifier (R001...R050)\n"
    "  timestamp           — sample timestamp (last 24 hours)\n"
    "  traffic_in_mbps     — inbound traffic in Mbps (0-1000)\n"
    "  traffic_out_mbps    — outbound traffic in Mbps (0-800)\n"
    "  cpu_usage_pct       — CPU utilization percentage (5-100)\n"
    "  temperature_celsius — temperature in degrees Celsius (30-85)\n"
    "  packet_loss_pct     — packet loss percentage (0-5)\n"
    "  error_rate          — error rate per thousand packets (0-10)\n"
    "  uptime_hours        — continuous uptime in hours (1-8760)\n"
    "\n"
    "  Labeling logic (column 'status'):\n"
    "    critical --> cpu>90 OR temp>80 OR packet_loss>3 OR error_rate>7\n"
    "    warning  --> cpu>70 OR temp>70 OR packet_loss>1.5 OR error_rate>3\n"
    "    normal   --> all values within normal range\n"
)
pause()

section("6. Class distribution")
counts = df["status"].value_counts()
for label, cnt in counts.items():
    bar = "\u2588" * (cnt // 10)
    print(f"  {label:8s}: {cnt:4d}  {bar}")
print()
pause()
print(f"  {GREEN}Module 02 complete!{RESET} Dataset saved to ~/data/router_dataset.csv\n")
PYEOF

# ── 03_explore.py ───────────────────────────────────────────────────
cat > "$SCRIPT_DIR/03_explore.py" << 'PYEOF'
#!/usr/bin/env python3
"""Module 03 — Data exploration with pandas."""

import pandas as pd
import os

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"

CSV_PATH = "/home/labuser/data/router_dataset.csv"

def pause():
    try:
        input(f"\n  {CYAN}[ press ENTER to continue ]{RESET}\n")
    except EOFError:
        pass

def section(title):
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {BOLD}{title}{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

if not os.path.exists(CSV_PATH):
    print(f"  {RED}Error: dataset not found at {CSV_PATH}{RESET}")
    print(f"  Run module 02 first (Dataset generation).")
    exit(1)

df = pd.read_csv(CSV_PATH)

section("1. Shape and data types")
print(f"  df.shape --> {df.shape}  ({df.shape[0]} rows, {df.shape[1]} columns)\n")
print("  Data types (df.dtypes):")
for col, dtype in df.dtypes.items():
    print(f"    {col:25s} {dtype}")
print(
    "\n"
    "  What this tells us:\n"
    "  - Numeric columns (float64, int64) are ready for ML\n"
    "  - Object columns (router_id, timestamp, status) need special\n"
    "    handling: some are excluded, others are encoded\n"
)
pause()

section("2. Descriptive statistics (df.describe())")
print(df.describe().round(2).to_string())
print(
    "\n"
    "  What to look for:\n"
    "  - mean: typical value of the feature\n"
    "  - std: how much values vary\n"
    "  - min/max: extreme values — possible anomalies?\n"
    "  - 25%/50%/75%: distribution (median = 50%)\n"
)
pause()

section("3. Class distribution")
counts = df["status"].value_counts()
total  = len(df)
print(f"  Total samples: {total}\n")
for label, cnt in counts.items():
    pct = cnt / total * 100
    bar = "\u2588" * int(pct / 2)
    print(f"  {label:8s}: {cnt:4d} ({pct:5.1f}%)  {bar}")
print(
    "\n"
    "  An imbalanced dataset (one class much more frequent than others)\n"
    "  can fool the model. With ~500 samples and 3 classes, some\n"
    "  imbalance is normal and manageable.\n"
)
pause()

section("4. Correlations between numeric features")
num_cols = ["cpu_usage_pct", "temperature_celsius",
            "packet_loss_pct", "error_rate",
            "traffic_in_mbps", "traffic_out_mbps", "uptime_hours"]
corr = df[num_cols].corr().round(2)
print(corr.to_string())
print(
    "\n"
    "  How to read the correlation matrix:\n"
    "  - Values near +1: both features grow together\n"
    "  - Values near -1: when one grows, the other shrinks\n"
    "  - Values near 0: no linear relationship\n"
    "\n"
    "  For ML: highly correlated features may be redundant.\n"
    "  Features correlated with the target (status) are useful.\n"
)
pause()

section("5. Mean by status class")
print(df.groupby("status")[num_cols].mean().round(2).to_string())
print(
    "\n"
    "  This shows the average differences between classes.\n"
    "  Notice that cpu, temperature, packet_loss and error_rate\n"
    "  are significantly higher for 'critical' routers:\n"
    "  these are likely the most important features for the model.\n"
)
pause()
print(f"  {GREEN}Module 03 complete!{RESET} Now proceed to module 04.\n")
PYEOF

# ── 04_prepare.py ───────────────────────────────────────────────────
cat > "$SCRIPT_DIR/04_prepare.py" << 'PYEOF'
#!/usr/bin/env python3
"""Module 04 — Data preparation and feature engineering."""

import pandas as pd
import numpy as np
import os
import pickle
from sklearn.preprocessing import LabelEncoder
from sklearn.model_selection import train_test_split

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"

CSV_PATH   = "/home/labuser/data/router_dataset.csv"
MODEL_DIR  = "/home/labuser/data"

def pause():
    try:
        input(f"\n  {CYAN}[ press ENTER to continue ]{RESET}\n")
    except EOFError:
        pass

def section(title):
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {BOLD}{title}{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

if not os.path.exists(CSV_PATH):
    print(f"  {RED}Error: dataset not found. Run module 02 first.{RESET}")
    exit(1)

df = pd.read_csv(CSV_PATH)

section("1. Selecting features and the target")
print(
    "  Not all columns in the dataset are useful to the model:\n"
    "\n"
    "  - router_id: an identifier, not a measurement --> EXCLUDED\n"
    "  - timestamp: could carry info (time of day) but would require\n"
    "    advanced feature engineering --> EXCLUDED for now\n"
    "  - status: this is our label --> TARGET\n"
    "\n"
    "  The remaining columns are our FEATURES (model input):\n"
)
FEATURES = ["traffic_in_mbps", "traffic_out_mbps", "cpu_usage_pct",
            "temperature_celsius", "packet_loss_pct", "error_rate",
            "uptime_hours"]
TARGET = "status"

print(f"  Selected features ({len(FEATURES)}):")
for f in FEATURES:
    print(f"    - {f}")
print(f"\n  Target: {TARGET}")
pause()

section("2. Encoding the target with LabelEncoder")
print(
    "  ML algorithms work with numbers, not strings.\n"
    "  We need to convert 'critical' / 'warning' / 'normal'\n"
    "  into integers (0, 1, 2).\n"
    "\n"
    "  LabelEncoder does exactly that:\n"
    "    le = LabelEncoder()\n"
    "    y_encoded = le.fit_transform(['critical', 'normal', 'warning'])\n"
    "    # --> le.classes_ = ['critical', 'normal', 'warning']  (alphabetical)\n"
    "    # --> y_encoded   = [0, 2, 1]\n"
    "\n"
    "  We save the encoder to decode predictions later.\n"
)
X = df[FEATURES]
le = LabelEncoder()
y = le.fit_transform(df[TARGET])

print(f"  Classes found (in order): {list(le.classes_)}")
print(f"  Numeric mapping:          {list(range(len(le.classes_)))}")
print(f"\n  First 10 values of y: {y[:10]}")
pause()

section("3. Train/Test split 80/20")
print(
    "  A common mistake is evaluating the model on the same data\n"
    "  used to train it: the model might 'memorize' the training\n"
    "  data (overfitting) and give falsely optimistic results.\n"
    "\n"
    "  The solution: split data BEFORE training.\n"
    "  - 80% of data --> training set (model learns from this)\n"
    "  - 20% of data --> test set (evaluated on never-seen data)\n"
    "\n"
    "  train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)\n"
    "  - test_size=0.2: 20% for testing\n"
    "  - random_state=42: reproducible split\n"
    "  - stratify=y: keeps the same class proportions in train and test\n"
)
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)
print(f"  Total samples:   {len(df)}")
print(f"  Training set:    {len(X_train)} ({len(X_train)/len(df)*100:.0f}%)")
print(f"  Test set:        {len(X_test)} ({len(X_test)/len(df)*100:.0f}%)")
print(f"\n  Class distribution in training set:")
for cls, lbl in zip(range(len(le.classes_)), le.classes_):
    cnt = (y_train == cls).sum()
    print(f"    {lbl:8s}: {cnt}")
pause()

os.makedirs(MODEL_DIR, exist_ok=True)
np.save(f"{MODEL_DIR}/X_train.npy", X_train.values)
np.save(f"{MODEL_DIR}/X_test.npy",  X_test.values)
np.save(f"{MODEL_DIR}/y_train.npy", y_train)
np.save(f"{MODEL_DIR}/y_test.npy",  y_test)
with open(f"{MODEL_DIR}/label_encoder.pkl", "wb") as f:
    pickle.dump(le, f)
with open(f"{MODEL_DIR}/feature_names.pkl", "wb") as f:
    pickle.dump(FEATURES, f)
print(f"\n  {GREEN}Prepared data saved to {MODEL_DIR}/{RESET}")
print(f"  {GREEN}Module 04 complete!{RESET} Now proceed to module 05.\n")
PYEOF

# ── 05_train.py ─────────────────────────────────────────────────────
cat > "$SCRIPT_DIR/05_train.py" << 'PYEOF'
#!/usr/bin/env python3
"""Module 05 — Training a Random Forest."""

import numpy as np
import pickle
import os
import time
from sklearn.ensemble import RandomForestClassifier

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"

MODEL_DIR = "/home/labuser/data"

def pause():
    try:
        input(f"\n  {CYAN}[ press ENTER to continue ]{RESET}\n")
    except EOFError:
        pass

def section(title):
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {BOLD}{title}{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

for fname in ["X_train.npy", "y_train.npy"]:
    if not os.path.exists(f"{MODEL_DIR}/{fname}"):
        print(f"  {RED}Error: data not found. Run module 04 first.{RESET}")
        exit(1)

X_train = np.load(f"{MODEL_DIR}/X_train.npy")
y_train = np.load(f"{MODEL_DIR}/y_train.npy")

section("1. Decision Tree --> Ensemble --> Random Forest")
print(
    "  A DECISION TREE is a tree-shaped model that asks questions\n"
    "  about features to reach a decision:\n"
    "    'cpu > 70?' --> yes --> 'packet_loss > 1.5?' --> yes --> 'warning'\n"
    "\n"
    "  The problem: a single tree tends to overfit.\n"
    "  If trees are too deep, they 'memorize' the training data.\n"
    "\n"
    "  ENSEMBLE: instead of one tree, we train many trees and\n"
    "  combine their predictions (majority vote).\n"
    "  Each tree makes its own errors, but different errors --> they cancel.\n"
    "\n"
    "  RANDOM FOREST: each tree sees:\n"
    "  1. A random sample of the data (bootstrap sampling)\n"
    "  2. A random subset of features for each split\n"
    "\n"
    "  This makes trees diverse from each other --> better generalization.\n"
)
pause()

section("2. Random Forest hyperparameters")
print(
    "  n_estimators  -- number of trees (default: 100)\n"
    "                   More trees = more stable, but slower.\n"
    "                   Beyond ~200 the improvement is marginal.\n"
    "\n"
    "  max_depth     -- maximum depth of each tree (default: None)\n"
    "                   None = full trees (possible overfitting)\n"
    "                   10-20 = good trade-off for medium datasets\n"
    "\n"
    "  random_state  -- seed for reproducibility\n"
    "                   Guarantees the same results every run\n"
    "\n"
    "  min_samples_split -- minimum samples required to split a node\n"
    "                       Higher values prevent overfitting\n"
    "\n"
    "  In this lab we use typical values for a first experiment.\n"
)
pause()

section("3. Training the model")
print("  Creating the Random Forest model...")
model = RandomForestClassifier(
    n_estimators=100,
    max_depth=15,
    random_state=42,
    min_samples_split=5,
)
print(f"  Parameters: {model.get_params()}\n")
print(f"  Training set: {X_train.shape[0]} samples, {X_train.shape[1]} features")
print(f"\n  Starting training (model.fit)...")
t0 = time.time()
model.fit(X_train, y_train)
elapsed = time.time() - t0
print(f"\n  {GREEN}Training complete in {elapsed:.2f} seconds!{RESET}")
print(f"  Trees trained: {len(model.estimators_)}")
pause()

with open(f"{MODEL_DIR}/random_forest.pkl", "wb") as f:
    pickle.dump(model, f)
print(f"  {GREEN}Model saved to {MODEL_DIR}/random_forest.pkl{RESET}")
print(f"  {GREEN}Module 05 complete!{RESET} Now proceed to module 06.\n")
PYEOF

# ── 06_evaluate.py ──────────────────────────────────────────────────
cat > "$SCRIPT_DIR/06_evaluate.py" << 'PYEOF'
#!/usr/bin/env python3
"""Module 06 — Model evaluation."""

import numpy as np
import pickle
import os
from sklearn.metrics import (accuracy_score, confusion_matrix,
                             classification_report)

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"

MODEL_DIR = "/home/labuser/data"

def pause():
    try:
        input(f"\n  {CYAN}[ press ENTER to continue ]{RESET}\n")
    except EOFError:
        pass

def section(title):
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {BOLD}{title}{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

for fname in ["random_forest.pkl", "X_test.npy", "y_test.npy",
              "label_encoder.pkl", "feature_names.pkl"]:
    if not os.path.exists(f"{MODEL_DIR}/{fname}"):
        print(f"  {RED}Error: missing file: {fname}. Run modules 04 and 05 first.{RESET}")
        exit(1)

with open(f"{MODEL_DIR}/random_forest.pkl",  "rb") as f: model = pickle.load(f)
with open(f"{MODEL_DIR}/label_encoder.pkl",  "rb") as f: le    = pickle.load(f)
with open(f"{MODEL_DIR}/feature_names.pkl",  "rb") as f: feats = pickle.load(f)
X_test  = np.load(f"{MODEL_DIR}/X_test.npy")
y_test  = np.load(f"{MODEL_DIR}/y_test.npy")

y_pred = model.predict(X_test)

section("1. Accuracy")
acc = accuracy_score(y_test, y_pred)
color = GREEN if acc >= 0.85 else YELLOW
print(f"  Accuracy: {color}{acc*100:.1f}%{RESET}\n")
print(
    "  Accuracy is the percentage of correct predictions on the test set.\n"
    "  Example: 90% accuracy --> the model correctly classifies\n"
    "  9 out of 10 routers it has never seen during training.\n"
    "\n"
    "  Warning: accuracy alone can be misleading on imbalanced datasets.\n"
    "  That is why we also look at precision, recall, and F1.\n"
)
pause()

section("2. Confusion Matrix")
cm    = confusion_matrix(y_test, y_pred)
labels = le.classes_
col_w  = 12
print(f"  {'':15s}", end="")
for lbl in labels:
    print(f"  {lbl:>{col_w}}", end="")
print()
print(f"  {'':15s}" + "  " + "\u2500" * (col_w * len(labels) + 2 * (len(labels)-1)))
for i, row_lbl in enumerate(labels):
    print(f"  {row_lbl:>15s} |", end="")
    for j, val in enumerate(cm[i]):
        color = GREEN if i == j else (RED if val > 0 else RESET)
        print(f"  {color}{val:>{col_w}}{RESET}", end="")
    print()
print(
    "\n"
    "  Rows = actual classes, Columns = predicted classes.\n"
    "  Main diagonal (green) = correct predictions.\n"
    "  Off-diagonal (red) = errors.\n"
    "\n"
    "  Network monitoring interpretation:\n"
    "  - A 'critical' classified as 'normal' is dangerous!\n"
    "    (false negative: critical router not detected)\n"
    "  - A 'normal' classified as 'critical' is a false alarm\n"
    "    (annoying, but less dangerous)\n"
)
pause()

section("3. Classification Report (Precision, Recall, F1)")
report = classification_report(y_test, y_pred, target_names=labels)
print(report)
print(
    "  PRECISION -- of all routers classified as 'critical',\n"
    "  how many were actually critical?\n"
    "  --> High precision = few false alarms\n"
    "\n"
    "  RECALL -- of all routers that were truly 'critical',\n"
    "  how many did the model find?\n"
    "  --> High recall = few missed criticals (important for security!)\n"
    "\n"
    "  F1-SCORE -- harmonic mean of precision and recall.\n"
    "  Balances both: useful when classes are imbalanced.\n"
    "\n"
    "  SUPPORT -- number of actual samples per class in the test set.\n"
)
pause()

section("4. Feature Importances")
importances = model.feature_importances_
sorted_idx  = np.argsort(importances)[::-1]
max_imp     = importances.max()
print(f"  {'Feature':25s}  {'Importance':>10s}  Chart")
print(f"  {'-'*25}  {'-'*10}  {'-'*30}")
for idx in sorted_idx:
    feat = feats[idx]
    imp  = importances[idx]
    bar  = "\u2588" * int(imp / max_imp * 30)
    print(f"  {feat:25s}  {imp:>10.4f}  {bar}")
print(
    "\n"
    "  Feature importances show HOW MUCH each feature contributes\n"
    "  to the model's decisions (sum = 1.0).\n"
    "\n"
    "  High importance --> the model relies heavily on this feature.\n"
    "  Low importance  --> could be removed with little accuracy loss\n"
    "                      (feature selection).\n"
    "\n"
    "  For network monitoring: confirms which metrics to watch most.\n"
)
pause()
print(f"  {GREEN}Module 06 complete!{RESET} Now proceed to module 07.\n")
PYEOF

# ── 07_predict.py ───────────────────────────────────────────────────
cat > "$SCRIPT_DIR/07_predict.py" << 'PYEOF'
#!/usr/bin/env python3
"""Module 07 — Predictions on new routers."""

import numpy as np
import pandas as pd
import pickle
import os

RESET  = "\033[0m"
BOLD   = "\033[1m"
CYAN   = "\033[1;36m"
GREEN  = "\033[1;32m"
YELLOW = "\033[1;33m"
RED    = "\033[0;31m"

MODEL_DIR = "/home/labuser/data"

def pause():
    try:
        input(f"\n  {CYAN}[ press ENTER to continue ]{RESET}\n")
    except EOFError:
        pass

def section(title):
    print(f"\n{CYAN}{'━'*60}{RESET}")
    print(f"  {BOLD}{title}{RESET}")
    print(f"{CYAN}{'━'*60}{RESET}\n")

for fname in ["random_forest.pkl", "label_encoder.pkl", "feature_names.pkl"]:
    if not os.path.exists(f"{MODEL_DIR}/{fname}"):
        print(f"  {RED}Error: missing file: {fname}. Run modules 04 and 05 first.{RESET}")
        exit(1)

with open(f"{MODEL_DIR}/random_forest.pkl",  "rb") as f: model = pickle.load(f)
with open(f"{MODEL_DIR}/label_encoder.pkl",  "rb") as f: le    = pickle.load(f)
with open(f"{MODEL_DIR}/feature_names.pkl",  "rb") as f: feats = pickle.load(f)

section("1. New routers to classify")
print(
    "  The model was trained on historical data.\n"
    "  We now simulate 5 new routers with data the model\n"
    "  has never seen during training.\n"
    "\n"
    "  This is the real-world scenario: the monitoring system\n"
    "  collects current metrics and asks the model to classify\n"
    "  the status of each router.\n"
)

new_routers = pd.DataFrame({
    "traffic_in_mbps":    [850.0, 120.0,  450.0, 980.0,  30.0],
    "traffic_out_mbps":   [700.0,  80.0,  380.0, 750.0,  20.0],
    "cpu_usage_pct":      [ 92.0,  35.0,   75.0,  88.0,  15.0],
    "temperature_celsius":[ 78.0,  42.0,   72.0,  83.0,  38.0],
    "packet_loss_pct":    [  3.5,   0.1,    1.8,   0.5,   0.0],
    "error_rate":         [  8.2,   0.5,    3.5,   2.1,   0.1],
    "uptime_hours":       [  200,  4380,    730,    48,   8700],
})
router_names = ["Router-A", "Router-B", "Router-C", "Router-D", "Router-E"]

print(f"  {'Router':10s}", end="")
for f in feats:
    print(f"  {f[:12]:>12s}", end="")
print()
print(f"  {'-'*10}" + "  " + "  ".join(["-"*12]*len(feats)))
for name, (_, row) in zip(router_names, new_routers.iterrows()):
    print(f"  {name:10s}", end="")
    for f in feats:
        v = row[f]
        print(f"  {v:>12.1f}", end="")
    print()
pause()

section("2. Model predictions")
X_new  = new_routers[feats].values
preds  = model.predict(X_new)
labels = le.inverse_transform(preds)
probas = model.predict_proba(X_new)

status_colors = {"critical": RED, "warning": YELLOW, "normal": GREEN}
print(f"  {'Router':10s}  {'Prediction':10s}  {'Confidence':>10s}  Probability per class")
print(f"  {'-'*10}  {'-'*10}  {'-'*10}  {'-'*35}")
for name, label, proba in zip(router_names, labels, probas):
    color = status_colors.get(label, RESET)
    conf  = proba.max() * 100
    prob_str = "  ".join(f"{le.classes_[i]}:{p*100:4.1f}%" for i, p in enumerate(proba))
    print(f"  {name:10s}  {color}{label:10s}{RESET}  {conf:>9.1f}%  {prob_str}")
pause()

section("3. What is predict_proba?")
print(
    "  model.predict(X) returns only the class with maximum probability.\n"
    "  model.predict_proba(X) returns the probabilities for EVERY class.\n"
    "\n"
    "  Example for one router:\n"
    "    critical: 0.72   warning: 0.21   normal: 0.07\n"
    "    --> the model is fairly confident it is 'critical' (72%)\n"
    "    --> but there is a 21% chance it is just 'warning'\n"
    "\n"
    "  Very useful in production:\n"
    "  - High confidence --> act immediately\n"
    "  - Low confidence  --> request further verification\n"
    "  - Set thresholds: e.g. alert if P(critical) > 0.60\n"
)
pause()

section("4. Conclusions and next steps")
print(
    f"  \033[1;32mYou completed the ML Network Lab!\033[0m\n"
    "\n"
    "  You have learned to:\n"
    "  \u2713 Generate a simulated router dataset with a reproducible seed\n"
    "  \u2713 Explore data with pandas (shape, describe, correlations)\n"
    "  \u2713 Prepare features and target, encode labels, do train/test split\n"
    "  \u2713 Train a Random Forest with scikit-learn\n"
    "  \u2713 Evaluate the model: accuracy, confusion matrix, F1, feature importances\n"
    "  \u2713 Make predictions on new data with confidence (predict_proba)\n"
    "\n"
    f"  \033[1;33mAdvanced challenges:\033[0m\n"
    "  - Try changing n_estimators or max_depth and observe the effect\n"
    "  - Add time features (hour of day extracted from timestamp)\n"
    "  - Use GridSearchCV to find the best hyperparameters automatically\n"
    "  - Serve the model as a REST API with Flask\n"
    "  - Visualize feature importances with matplotlib (already installed!)\n"
    "\n"
    f"  \033[1;33mResources:\033[0m\n"
    "  - scikit-learn docs: https://scikit-learn.org/stable/\n"
    "  - pandas docs:       https://pandas.pydata.org/docs/\n"
    "  - Python Data Science Handbook (free online)\n"
)
print(f"  \033[1;32mModule 07 complete!\033[0m Great work!\n")
PYEOF

# ── Inject base64-encoded scripts into user-data via Python ─────────
cat > "$LAB_DIR/user-data" <<'USERDATA'
#cloud-config
hostname: ml-network-lab
package_update: true
users:
  - name: labuser
    plain_text_passwd: labpass
    lock_passwd: false
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - "__QLAB_SSH_PUB_KEY__"
ssh_pwauth: true
packages:
  - python3
  - python3-pip
  - python3-venv
  - curl
write_files:
  - path: /etc/profile.d/cloud-init-status.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      if command -v cloud-init >/dev/null 2>&1; then
        status=$(cloud-init status 2>/dev/null)
        if echo "$status" | grep -q "running"; then
          printf '\033[1;33m'
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Cloud-init is still running..."
          echo "  Some packages and services may not be ready yet."
          echo "  Run 'cloud-init status --wait' to wait for completion."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          printf '\033[0m\n'
        fi
      fi
  - path: /etc/motd.raw
    content: |
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m
        \033[1;32mml-network-lab\033[0m — \033[1mMachine Learning for Networks\033[0m
      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

        \033[1;33mLab objectives:\033[0m
          • generate a simulated router dataset with a reproducible seed
          • explore data with pandas and understand the features
          • train a Random Forest with scikit-learn
          • evaluate the model with accuracy, confusion matrix, and F1
          • make predictions on new, unseen routers

        \033[1;33mGetting started:\033[0m
          \033[0;32mpython3 menu.py\033[0m          interactive course menu
          \033[0;32mpython3 01_intro.py\033[0m      run a module directly

        \033[1;33mAvailable modules:\033[0m
          01_intro.py     Introduction: ML for networks
          02_dataset.py   Router dataset generation
          03_explore.py   Data exploration with pandas
          04_prepare.py   Data preparation and feature engineering
          05_train.py     Training a Random Forest
          06_evaluate.py  Model evaluation
          07_predict.py   Predictions on new routers

        \033[1;33mCredentials:\033[0m  \033[1;36mlabuser\033[0m / \033[1;36mlabpass\033[0m
        \033[1;33mExit:\033[0m          type '\033[1;31mexit\033[0m'

      \033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m

  - path: /home/labuser/menu.py
    encoding: b64
    permissions: '0755'
    content: __MENU_PY_B64__
  - path: /home/labuser/01_intro.py
    encoding: b64
    permissions: '0755'
    content: __01_INTRO_B64__
  - path: /home/labuser/02_dataset.py
    encoding: b64
    permissions: '0755'
    content: __02_DATASET_B64__
  - path: /home/labuser/03_explore.py
    encoding: b64
    permissions: '0755'
    content: __03_EXPLORE_B64__
  - path: /home/labuser/04_prepare.py
    encoding: b64
    permissions: '0755'
    content: __04_PREPARE_B64__
  - path: /home/labuser/05_train.py
    encoding: b64
    permissions: '0755'
    content: __05_TRAIN_B64__
  - path: /home/labuser/06_evaluate.py
    encoding: b64
    permissions: '0755'
    content: __06_EVALUATE_B64__
  - path: /home/labuser/07_predict.py
    encoding: b64
    permissions: '0755'
    content: __07_PREDICT_B64__
runcmd:
  - chmod -x /etc/update-motd.d/*
  - sed -i 's/^#\?PrintMotd.*/PrintMotd yes/' /etc/ssh/sshd_config
  - sed -i 's/^session.*pam_motd.*/# &/' /etc/pam.d/sshd
  - printf '%b\n' "$(cat /etc/motd.raw)" > /etc/motd
  - rm -f /etc/motd.raw
  - systemctl restart sshd
  - mkdir -p /home/labuser/data
  - pip3 install --quiet scikit-learn pandas numpy matplotlib
  - chown -R labuser:labuser /home/labuser
  - echo "=== ml-network-lab VM is ready! ==="
USERDATA

# Inject SSH public key
sed -i "s|__QLAB_SSH_PUB_KEY__|${QLAB_SSH_PUB_KEY:-}|g" "$LAB_DIR/user-data"

# Inject base64-encoded Python scripts
python3 - <<PYEOF
import base64

def b64(path):
    with open(path, 'rb') as f:
        return base64.b64encode(f.read()).decode()

ud_path = '${LAB_DIR}/user-data'
sd      = '${SCRIPT_DIR}'

with open(ud_path) as f:
    content = f.read()

replacements = {
    '__MENU_PY_B64__':      b64(f'{sd}/menu.py'),
    '__01_INTRO_B64__':     b64(f'{sd}/01_intro.py'),
    '__02_DATASET_B64__':   b64(f'{sd}/02_dataset.py'),
    '__03_EXPLORE_B64__':   b64(f'{sd}/03_explore.py'),
    '__04_PREPARE_B64__':   b64(f'{sd}/04_prepare.py'),
    '__05_TRAIN_B64__':     b64(f'{sd}/05_train.py'),
    '__06_EVALUATE_B64__':  b64(f'{sd}/06_evaluate.py'),
    '__07_PREDICT_B64__':   b64(f'{sd}/07_predict.py'),
}

for placeholder, value in replacements.items():
    content = content.replace(placeholder, value)

with open(ud_path, 'w') as f:
    f.write(content)

print('  Base64 injection complete.')
PYEOF

cat > "$LAB_DIR/meta-data" <<METADATA
instance-id: ${PLUGIN_NAME}-001
local-hostname: ${PLUGIN_NAME}
METADATA

success "Created cloud-init files in $LAB_DIR/"
echo ""

# Step 3: Generate cloud-init ISO
info "Step 3: Cloud-init ISO"
echo ""
echo "  QEMU reads cloud-init data from a small ISO image (CD-ROM)."
echo "  We use genisoimage to create it with the 'cidata' volume label."
echo ""

CIDATA_ISO="$LAB_DIR/cidata.iso"
check_dependency genisoimage || {
    warn "genisoimage not found. Install it with: sudo apt install genisoimage"
    exit 1
}
genisoimage -output "$CIDATA_ISO" -volid cidata -joliet -rock \
    "$LAB_DIR/user-data" "$LAB_DIR/meta-data" 2>/dev/null
success "Created cloud-init ISO: $CIDATA_ISO"
echo ""

# Step 4: Create overlay disk
info "Step 4: Overlay disk"
echo ""
echo "  An overlay disk uses copy-on-write (COW) on top of the base image."
echo "  This means:"
echo "    - The original cloud image stays untouched"
echo "    - All writes go to the overlay file"
echo "    - You can reset the lab by deleting the overlay"
echo ""

OVERLAY_DISK="$LAB_DIR/${PLUGIN_NAME}-disk.qcow2"
if [[ -f "$OVERLAY_DISK" ]]; then
    info "Removing previous overlay disk..."
    rm -f "$OVERLAY_DISK"
fi
create_overlay "$CLOUD_IMAGE_FILE" "$OVERLAY_DISK" "${QLAB_DISK_SIZE:-6G}" || {
    error "Failed to create overlay disk."
    exit 1
}
echo ""

# Step 5: Boot the VM in background
info "Step 5: Starting VM in background"
echo ""
echo "  The VM will run in background with:"
echo "    - Serial output logged to .qlab/logs/$PLUGIN_NAME.log"
echo "    - SSH access on a dynamically allocated port"
echo "    - pip install (scikit-learn, pandas, numpy, matplotlib) runs at first boot"
echo ""

start_vm "$OVERLAY_DISK" "$CIDATA_ISO" "$MEMORY" "$PLUGIN_NAME" auto

echo ""
echo "============================================="
echo "  ml-network-lab: VM is booting"
echo "============================================="
echo ""
echo "  Credentials: labuser / labpass"
echo ""
echo "  SSH (wait ~2-3 min for boot + pip install):"
echo "    qlab shell ${PLUGIN_NAME}"
echo ""
echo "  Then start the interactive menu:"
echo "    python3 menu.py"
echo ""
echo "  Or run a module directly:"
echo "    python3 01_intro.py"
echo ""
echo "  View boot log:"
echo "    qlab log ${PLUGIN_NAME}"
echo ""
echo "  Stop VM:"
echo "    qlab stop ${PLUGIN_NAME}"
echo ""
echo "  Tip: QLAB_MEMORY=2048 QLAB_DISK_SIZE=8G qlab run ${PLUGIN_NAME}"
echo "============================================="
