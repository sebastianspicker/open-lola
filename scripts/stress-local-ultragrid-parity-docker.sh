#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:-${OPEN_LOLA_OUTPUT_DIR:-${TMPDIR:-/tmp}/open-lola-ultragrid-parity-stability-$$}}"
trials="${OPEN_LOLA_ULTRAGRID_PARITY_TRIALS:-3}"
summary_report="$output_dir/ultragrid-parity-stability-summary.json"
trial_statuses="$output_dir/trial-status.tsv"

mkdir -p "$output_dir"
: >"$trial_statuses"

for ((trial = 1; trial <= trials; trial++)); do
  trial_dir="$output_dir/trial-$trial"
  if bash scripts/compare-local-ultragrid-parity-docker.sh "$trial_dir"; then
    status=0
  else
    status=$?
  fi
  printf '%s\t%s\t%s\n' "$trial" "$status" "$trial_dir" >>"$trial_statuses"
done

python3 - "$summary_report" "$trial_statuses" "$trials" <<'PY'
import json
import sys
from pathlib import Path

summary_path = Path(sys.argv[1])
status_path = Path(sys.argv[2])
requested_trials = int(sys.argv[3])

trials: list[dict[str, object]] = []
all_trials_passed = True
all_direct_baselines_clean = True
all_managed_endpoints_clean = True

for line in status_path.read_text(encoding="utf-8").splitlines():
    trial, status, trial_dir = line.split("\t", maxsplit=2)
    metrics_path = Path(trial_dir) / "ultragrid-parity-metrics.json"
    metrics = None
    errors: list[str] = []
    comparisons: dict[str, object] = {}
    connection_setup: dict[str, object] = {}
    display_smoothness: dict[str, object] = {}
    endpoint_health: dict[str, object] = {}

    if metrics_path.exists():
        metrics = json.loads(metrics_path.read_text(encoding="utf-8"))
        errors = list(metrics.get("errors", []))
        comparisons = dict(metrics.get("comparisons", {}))
        connection_setup = dict(metrics.get("connectionSetup", {}))
        display_smoothness = dict(metrics.get("displaySmoothness", {}))
        endpoint_health = dict(metrics.get("endpointHealth", {}))
    else:
        errors = ["missing ultragrid-parity-metrics.json"]

    trial_passed = int(status) == 0 and not errors and all(comparisons.values())
    all_trials_passed = all_trials_passed and trial_passed
    all_direct_baselines_clean = (
        all_direct_baselines_clean and endpoint_health.get("directBaselineClean") is True
    )
    all_managed_endpoints_clean = (
        all_managed_endpoints_clean and endpoint_health.get("managedEndpointClean") is True
    )

    trials.append(
        {
            "trial": int(trial),
            "exitStatus": int(status),
            "passed": trial_passed,
            "trialDir": trial_dir,
            "metricsPath": str(metrics_path),
            "comparisons": comparisons,
            "connectionSetup": connection_setup,
            "displaySmoothness": display_smoothness,
            "endpointHealth": endpoint_health,
            "errors": errors,
        }
    )

report = {
    "schema": "open-lola-ultragrid-local-parity-stability-summary-v1",
    "verdict": "PARTIAL",
    "requestedTrials": requested_trials,
    "completedTrials": len(trials),
    "allTrialsPassed": all_trials_passed,
    "allDirectBaselinesClean": all_direct_baselines_clean,
    "allManagedEndpointsClean": all_managed_endpoints_clean,
    "evidenceBoundary": (
        "Repeated same-host Docker direct UltraGrid RX/TX versus Open LoLa-managed "
        "UltraGrid RX/TX parity only; not physical route, native device, latency, "
        "jitter, or long-run field parity evidence."
    ),
    "trials": trials,
}
summary_path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

if not all_trials_passed:
    sys.exit(1)
PY

echo "UltraGrid parity stability summary: $summary_report"
echo "trials: $trials"
echo "VERDICT: PARTIAL"
