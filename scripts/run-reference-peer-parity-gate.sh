#!/usr/bin/env bash
set -euo pipefail

output_dir="${1:-${OPEN_LOLA_OUTPUT_DIR:-${TMPDIR:-/tmp}/open-lola-reference-peer-parity-$$}}"
connector="${2:-${OPEN_LOLA_REFERENCE_PARITY_CONNECTOR:-all}}"
open_lola_bin="${OPEN_LOLA_BIN:-.build/debug/open-lola}"
peer_host="${OPEN_LOLA_REFERENCE_PEER_HOST:-}"
jacktrip_executable="${OPEN_LOLA_JACKTRIP_EXECUTABLE:-jacktrip}"
report="$output_dir/reference-peer-parity-gate.json"

mkdir -p "$output_dir"

missing=()
if [[ -z "$peer_host" ]]; then
  missing+=("OPEN_LOLA_REFERENCE_PEER_HOST")
fi
if [[ ! -x "$open_lola_bin" ]]; then
  missing+=("OPEN_LOLA_BIN executable: $open_lola_bin")
fi
case "$connector" in
  all | jacktrip)
    if ! command -v "$jacktrip_executable" >/dev/null 2>&1 && [[ ! -x "$jacktrip_executable" ]]; then
      missing+=("JackTrip executable: $jacktrip_executable")
    fi
    ;;
esac

set +u
python3 - "$report" "$connector" "$peer_host" "$open_lola_bin" "$jacktrip_executable" "${missing[@]}" <<'PY'
import json
import sys
from pathlib import Path

report, connector, peer, open_lola, jacktrip, *missing = sys.argv[1:]
configured = not missing
directions = []
if connector in ("all", "ultragrid", "mvtp-ultragrid"):
    directions.extend([
        {
            "connector": "mvtp-ultragrid",
            "direction": "swift-native-tx-to-reference-rx",
            "plannedCommand": [
                open_lola, "external-connector-session-run",
                "--connector", "mvtp-ultragrid",
                "--role", "tx",
                "--peer", peer or "<OPEN_LOLA_REFERENCE_PEER_HOST>",
                "--dry-run", "false",
                "--output", str(Path(report).with_name("ultragrid-swift-tx-reference-rx.json")),
            ],
        },
        {
            "connector": "mvtp-ultragrid",
            "direction": "reference-tx-to-swift-native-rx",
            "plannedCommand": [
                open_lola, "external-connector-session-run",
                "--connector", "mvtp-ultragrid",
                "--role", "rx",
                "--peer", peer or "<OPEN_LOLA_REFERENCE_PEER_HOST>",
                "--dry-run", "false",
                "--output", str(Path(report).with_name("ultragrid-reference-tx-swift-rx.json")),
            ],
        },
    ])
if connector in ("all", "jacktrip"):
    directions.extend([
        {
            "connector": "jacktrip",
            "direction": "swift-native-tx-to-reference-rx",
            "plannedCommand": [
                open_lola, "external-connector-session-run",
                "--connector", "jacktrip",
                "--role", "tx",
                "--peer", peer or "<OPEN_LOLA_REFERENCE_PEER_HOST>",
                "--dry-run", "false",
                "--output", str(Path(report).with_name("jacktrip-swift-tx-reference-rx.json")),
            ],
        },
        {
            "connector": "jacktrip",
            "direction": "reference-tx-to-swift-native-rx",
            "referenceExecutable": jacktrip,
            "plannedCommand": [
                open_lola, "external-connector-session-run",
                "--connector", "jacktrip",
                "--role", "rx",
                "--peer", peer or "<OPEN_LOLA_REFERENCE_PEER_HOST>",
                "--dry-run", "false",
                "--output", str(Path(report).with_name("jacktrip-reference-tx-swift-rx.json")),
            ],
        },
    ])
payload = {
    "schema": "open-lola-reference-peer-parity-gate-v1",
    "verdict": "partial",
    "hostReady": configured,
    "connector": connector,
    "peerHost": peer or None,
    "missingPrerequisites": missing,
    "directions": directions,
    "evidenceBoundary": (
        "Opt-in reference-peer readiness and command plan only. PASS remains blocked "
        "until measured external peers provide route, packet capture, live media, "
        "validator, timing, and teardown evidence."
    ),
}
Path(report).write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
set -u

if ((${#missing[@]})); then
  echo "Reference-peer parity gate skipped: $report" >&2
  echo "VERDICT: PARTIAL"
  exit 77
fi

echo "Reference-peer parity gate ready: $report"
echo "VERDICT: PARTIAL"
