#!/usr/bin/env bash
# Validate externally captured PMR evidence without treating it as local runtime proof.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

# shellcheck disable=SC1091
. "$repo_root/scripts/lib/common.sh"

# Print the external proof-bundle path and supported validation options.
usage() {
  cat <<'USAGE'
Usage: bash scripts/verify-pmr-external-proof-bundle.sh <bundle-dir>

Validates the external proof bundle for the PMR-04, PMR-14, PMR-16, and PMR-23
source-owned evidence contracts. This script does not generate
hardware or live-peer evidence; it only rejects incomplete or non-validating
artifacts.

Expected bundle layout:
  pmr-04/realtime-audio-engine.json
  pmr-04/sanitizer-result.txt
  pmr-14/rx-buffer-benchmark.json
  pmr-14/drift-plc-certification.json
  pmr-14/direct-p2p-session.json
  pmr-14/direct-p2p-evidence/
  pmr-16/madi-full-duplex.json
  pmr-16/hardware-notes.md
  pmr-23/lola-media-session.json
  pmr-23/audio-loopback-run.json
  pmr-23/recording-session.json

Set OPEN_LOLA_CLI=/path/to/open-lola to use a non-default CLI binary.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "$#" -ne 1 ]]; then
  usage >&2
  fail "missing bundle directory"
fi

bundle_dir="$1"
cli_binary="${OPEN_LOLA_CLI:-$(open_lola_default_cli_binary)}"
tmp_dir="$(mktemp -d)"

# Remove only the temporary validator-output directory created for this bundle check.
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

[[ -d "$bundle_dir" ]] || fail "bundle directory does not exist: $bundle_dir"
[[ -x "$cli_binary" ]] || fail "open-lola CLI is not executable: $cli_binary"

# Require an evidence subdirectory before validating files inside it.
require_directory() {
  local path="$1"

  [[ -d "$path" ]] || fail "missing directory: $path"
}

# Require the last validator output line to equal the expected verdict.
expect_last_verdict() {
  local label="$1"
  local output_file="$2"
  local expected="$3"
  local last_line

  last_line="$(tail -n 1 "$output_file")"
  [[ "$last_line" == "VERDICT: $expected" ]] || {
    tail -n 40 "$output_file" >&2 || true
    fail "$label expected VERDICT: $expected, got: $last_line"
  }
}

# Require validator output to contain a regular-expression evidence marker.
require_output_match() {
  local output_file="$1"
  local pattern="$2"
  local label="$3"

  grep -Eq "$pattern" "$output_file" || {
    tail -n 40 "$output_file" >&2 || true
    fail "$label must match: $pattern"
  }
}

# Run one report validator and require its expected final verdict.
validate_report() {
  local slice="$1"
  local relative_path="$2"
  local validator="$3"
  local expected_verdict="$4"
  local artifact_path="$bundle_dir/$relative_path"
  local output_file="$tmp_dir/${slice}-${validator}.out"

  require_file "$artifact_path"
  "$cli_binary" "$validator" "$artifact_path" >"$output_file"
  expect_last_verdict "$slice $relative_path" "$output_file" "$expected_verdict"
  echo "$slice $relative_path -> VERDICT: $expected_verdict"
}

# Validate a report and require an additional evidence line in the output.
validate_report_with_output_match() {
  local slice="$1"
  local relative_path="$2"
  local validator="$3"
  local expected_verdict="$4"
  local pattern="$5"
  local label="$6"
  local artifact_path="$bundle_dir/$relative_path"
  local output_file="$tmp_dir/${slice}-${validator}.out"

  require_file "$artifact_path"
  "$cli_binary" "$validator" "$artifact_path" >"$output_file"
  expect_last_verdict "$slice $relative_path" "$output_file" "$expected_verdict"
  require_output_match "$output_file" "$pattern" "$label"
  echo "$slice $relative_path -> VERDICT: $expected_verdict"
}

# Check the direct peer-to-peer report and its externally captured evidence files.
validate_direct_p2p_bundle() {
  local report_path="$bundle_dir/pmr-14/direct-p2p-session.json"
  local evidence_root="$bundle_dir/pmr-14/direct-p2p-evidence"
  local output_file="$tmp_dir/pmr-14-direct-p2p-evidence.out"

  require_file "$report_path"
  require_directory "$evidence_root"
  "$cli_binary" verify-direct-p2p-session-evidence-bundle "$report_path" "$evidence_root" >"$output_file"
  expect_last_verdict "pmr-14 direct P2P evidence bundle" "$output_file" "PASS"
  echo "PMR-14 direct-p2p-evidence -> VERDICT: PASS"
}

# Check PMR-14 runtime, packet, timing, and validator evidence as one bundle.
validate_pmr14_runtime_contract() {
  local rx_report="$bundle_dir/pmr-14/rx-buffer-benchmark.json"
  local drift_report="$bundle_dir/pmr-14/drift-plc-certification.json"
  local p2p_report="$bundle_dir/pmr-14/direct-p2p-session.json"

  python3 - "$rx_report" "$drift_report" "$p2p_report" <<'PY'
import json
import sys


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def require_positive(value, label):
    if not isinstance(value, int) or value <= 0:
        fail(f"{label} must be > 0")


def require_zero(value, label):
    if not isinstance(value, int) or value != 0:
        fail(f"{label} must be 0")


def require_non_empty(value, label):
    if not isinstance(value, str) or not value:
        fail(f"{label} must be non-empty")


def require_artifact(artifact, label):
    if not isinstance(artifact, dict):
        fail(f"{label} must be present")
    require_non_empty(artifact.get("path"), f"{label}.path")
    if artifact.get("captured") is not True:
        fail(f"{label}.captured must be true")


rx_report = load(sys.argv[1])
drift_report = load(sys.argv[2])
p2p_report = load(sys.argv[3])

if rx_report.get("verdict") != "pass":
    fail("pmr-14/rx-buffer-benchmark.json verdict must be pass")
if rx_report.get("evidenceKind") != "physicalReferenceRig":
    fail("pmr-14/rx-buffer-benchmark.json evidenceKind must be physicalReferenceRig")
rx_rows = rx_report.get("rows")
if not isinstance(rx_rows, list) or not rx_rows:
    fail("pmr-14/rx-buffer-benchmark.json rows must be non-empty")
if any(row.get("physicalEvidence") is not True for row in rx_rows):
    fail("pmr-14/rx-buffer-benchmark.json rows must all have physicalEvidence: true")
direct_rows = [row for row in rx_rows if row.get("profile") == "direct"]
if not direct_rows:
    fail("pmr-14/rx-buffer-benchmark.json must include a direct RX profile row")
if direct_rows[0].get("fastestPassEligible") is not True:
    fail("pmr-14/rx-buffer-benchmark.json direct row fastestPassEligible must be true")

if drift_report.get("verdict") != "pass":
    fail("pmr-14/drift-plc-certification.json verdict must be pass")
if drift_report.get("runMode") != "measured":
    fail("pmr-14/drift-plc-certification.json runMode must be measured")
if not drift_report.get("runArtifactPath"):
    fail("pmr-14/drift-plc-certification.json runArtifactPath must be non-empty")
lola_baseline = drift_report.get("lolaBaselineComparison") or {}
if lola_baseline.get("availability") != "measured":
    fail("pmr-14/drift-plc-certification.json lolaBaselineComparison.availability must be measured")
if lola_baseline.get("measuredOnSameHardwareAndRoute") is not True:
    fail("pmr-14/drift-plc-certification.json lolaBaselineComparison.measuredOnSameHardwareAndRoute must be true")
if lola_baseline.get("result") not in {"openLolaFaster", "openLolaEquivalent"}:
    fail("pmr-14/drift-plc-certification.json lolaBaselineComparison.result must be openLolaFaster or openLolaEquivalent")

if p2p_report.get("verdict") != "pass":
    fail("pmr-14/direct-p2p-session.json verdict must be pass")
measured_evidence = p2p_report.get("measuredEvidence") or {}
if measured_evidence.get("kind") != "physicalTwoPeerMacs":
    fail("pmr-14/direct-p2p-session.json measuredEvidence.kind must be physicalTwoPeerMacs")
require_non_empty(
    measured_evidence.get("packetCapturePath"),
    "pmr-14/direct-p2p-session.json measuredEvidence.packetCapturePath",
)
require_artifact(
    measured_evidence.get("packetCapture"),
    "pmr-14/direct-p2p-session.json measuredEvidence.packetCapture",
)
dscp = measured_evidence.get("dscp") or {}
require_artifact(
    dscp.get("artifact"),
    "pmr-14/direct-p2p-session.json measuredEvidence.dscp.artifact",
)
clock = measured_evidence.get("clock") or {}
require_artifact(
    clock.get("artifact"),
    "pmr-14/direct-p2p-session.json measuredEvidence.clock.artifact",
)
metrics = p2p_report.get("metrics") or {}
require_positive(metrics.get("packetsSent"), "pmr-14/direct-p2p-session.json metrics.packetsSent")
require_positive(metrics.get("packetsReceived"), "pmr-14/direct-p2p-session.json metrics.packetsReceived")
require_positive(metrics.get("audioPacketsRouted"), "pmr-14/direct-p2p-session.json metrics.audioPacketsRouted")
for field in ("packetsLost", "recoveryEvents", "audioPayloadsSentOnControlChannel"):
    require_zero(metrics.get(field), f"pmr-14/direct-p2p-session.json metrics.{field}")
for field in ("remotePacketsLost", "remoteLatePackets", "remoteUnderruns", "remoteOverruns"):
    if metrics.get(field) is not None:
        require_zero(metrics.get(field), f"pmr-14/direct-p2p-session.json metrics.{field}")
runtime_metrics = ((p2p_report.get("avRuntime") or {}).get("runtimeMetrics") or {})
require_positive(
    runtime_metrics.get("audioPayloadsSent"),
    "pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsSent",
)
require_positive(
    runtime_metrics.get("audioPayloadsQueuedForPlayout"),
    "pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.audioPayloadsQueuedForPlayout",
)
for field in (
    "audioPayloadsDroppedBeforeSend",
    "audioPayloadsDroppedBeforePlayout",
    "audioPayloadsDroppedByPlayoutQueue",
    "audioPlayoutUnderruns",
    "audioCallbackDeadlineMisses",
    "audioCallbackOverruns",
):
    require_zero(runtime_metrics.get(field), f"pmr-14/direct-p2p-session.json avRuntime.runtimeMetrics.{field}")
PY
  echo "PMR-14 runtime proof fields -> present"
}

# Require a passing sanitizer report with the expected executable identity.
validate_sanitizer_result() {
  local sanitizer_result="$bundle_dir/pmr-04/sanitizer-result.txt"

  require_file "$sanitizer_result"
  if grep -Eq '^SANITIZER_RUNTIME_BLOCKED: .+$' "$sanitizer_result"; then
    echo "PMR-04 sanitizer-result.txt -> runtime blocked"
    return
  fi

  require_file_contains "$sanitizer_result" "ASAN: PASS"
  require_file_contains "$sanitizer_result" "TSAN: PASS"
  echo "PMR-04 sanitizer-result.txt -> present"
}

# Check PMR-04 sanitizer and runtime evidence against the published contract.
validate_pmr04_runtime_contract() {
  local realtime_report="$bundle_dir/pmr-04/realtime-audio-engine.json"

  python3 - "$realtime_report" <<'PY'
import json
import sys


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def require_positive(value, label):
    if not isinstance(value, int) or value <= 0:
        fail(f"{label} must be > 0")


with open(sys.argv[1], "r", encoding="utf-8") as handle:
    report = json.load(handle)

if report.get("runMode") != "measured":
    fail("pmr-04/realtime-audio-engine.json runMode must be measured")
if report.get("hardwarePath") != "rmeMadi":
    fail("pmr-04/realtime-audio-engine.json hardwarePath must be rmeMadi")
if not report.get("runArtifactPath"):
    fail("pmr-04/realtime-audio-engine.json runArtifactPath must be non-empty")
runtime = report.get("runtime") or {}
if runtime.get("callbackOwner") != "audioDeviceIOProc":
    fail("pmr-04/realtime-audio-engine.json runtime.callbackOwner must be audioDeviceIOProc")
if runtime.get("udpSocketsPreparedBeforeStart") is not True:
    fail("pmr-04/realtime-audio-engine.json runtime.udpSocketsPreparedBeforeStart must be true")
if runtime.get("reportWrittenAfterStop") is not True:
    fail("pmr-04/realtime-audio-engine.json runtime.reportWrittenAfterStop must be true")
handoff = runtime.get("handoff") or {}
if handoff.get("shutdownCompleted") is not True:
    fail("pmr-04/realtime-audio-engine.json runtime.handoff.shutdownCompleted must be true")
for field in ("inputBlocks", "outputBlocks", "networkSendBlocks", "networkReceiveBlocks"):
    require_positive(
        handoff.get(field),
        f"pmr-04/realtime-audio-engine.json runtime.handoff.{field}",
    )
PY
  echo "PMR-04 runtime proof fields -> present"
}

# Require hardware notes to identify the measured rig and evidence boundary.
validate_hardware_notes() {
  local notes_path="$bundle_dir/pmr-16/hardware-notes.md"
  local input_uid
  local output_uid

  require_file "$notes_path"
  [[ -s "$notes_path" ]] || fail "pmr-16/hardware-notes.md is empty"
  require_file_contains "$notes_path" "input UID:"
  require_file_contains "$notes_path" "output UID:"
  require_file_contains "$notes_path" "RME MADI"
  require_file_contains "$notes_path" "peer readiness: exchanged"
  require_file_contains "$notes_path" "teardown: completed"
  require_file_contains "$notes_path" "packet capture:"
  input_uid="$(awk -F':[[:space:]]*' '/^input UID:[[:space:]]*[^[:space:]]/ { print $2; exit }' "$notes_path")"
  output_uid="$(awk -F':[[:space:]]*' '/^output UID:[[:space:]]*[^[:space:]]/ { print $2; exit }' "$notes_path")"
  [[ -n "$input_uid" ]] || fail "pmr-16/hardware-notes.md must include a non-empty input UID"
  [[ -n "$output_uid" ]] || fail "pmr-16/hardware-notes.md must include a non-empty output UID"
  [[ "$input_uid" != "$output_uid" ]] || fail "pmr-16/hardware-notes.md input UID and output UID must be distinct"
  echo "PMR-16 hardware-notes.md -> present"
}

# Check PMR-16 hardware runtime, notes, and validator outputs together.
validate_pmr16_runtime_contract() {
  local madi_report="$bundle_dir/pmr-16/madi-full-duplex.json"

  python3 - "$madi_report" <<'PY'
import json
import sys


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def require_non_empty(value, label):
    if not isinstance(value, str) or not value:
        fail(f"{label} must be non-empty")


def require_positive(value, label):
    if not isinstance(value, int) or value <= 0:
        fail(f"{label} must be > 0")


with open(sys.argv[1], "r", encoding="utf-8") as handle:
    report = json.load(handle)

if report.get("runMode") != "measuredPhysical":
    fail("pmr-16/madi-full-duplex.json runMode must be measuredPhysical")
if report.get("verdict") != "pass":
    fail("pmr-16/madi-full-duplex.json verdict must be pass")

local_peer_id = report.get("localPeerID")
remote_peer_id = report.get("remotePeerID")
require_non_empty(local_peer_id, "pmr-16/madi-full-duplex.json localPeerID")
require_non_empty(remote_peer_id, "pmr-16/madi-full-duplex.json remotePeerID")
if local_peer_id == remote_peer_id:
    fail("pmr-16/madi-full-duplex.json localPeerID and remotePeerID must be distinct")

local_endpoint = report.get("localEndpoint") or {}
remote_endpoint = report.get("remoteEndpoint") or {}
local_host = local_endpoint.get("host")
remote_host = remote_endpoint.get("host")
require_non_empty(local_host, "pmr-16/madi-full-duplex.json localEndpoint.host")
require_non_empty(remote_host, "pmr-16/madi-full-duplex.json remoteEndpoint.host")
if local_host == remote_host:
    fail("pmr-16/madi-full-duplex.json localEndpoint.host and remoteEndpoint.host must be distinct")

metrics = report.get("metrics") or {}
for field in (
    "transmittedBlocks",
    "transmittedFragments",
    "receivedFragments",
    "completedReceiveBlocks",
    "renderedReceiveBlocks",
    "txSenderFrameEnd",
    "rxPlayoutFrameEnd",
):
    require_positive(metrics.get(field), f"pmr-16/madi-full-duplex.json metrics.{field}")
PY
  echo "PMR-16 runtime proof fields -> present"
}

# Check PMR-23 benchmark artifacts, hardware notes, and report verdicts together.
validate_pmr23_runtime_contract() {
  local lola_report="$bundle_dir/pmr-23/lola-media-session.json"
  local loopback_report="$bundle_dir/pmr-23/audio-loopback-run.json"

  python3 - "$lola_report" "$loopback_report" <<'PY'
import json
import sys


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def require_non_empty(value, label):
    if not isinstance(value, str) or not value:
        fail(f"{label} must be non-empty")


def require_positive(value, label):
    if not isinstance(value, int) or value <= 0:
        fail(f"{label} must be > 0")


def require_true(value, label):
    if value is not True:
        fail(f"{label} must be true")


def is_loopback_or_unspecified(host):
    normalized = host.strip().lower()
    return (
        normalized in {"localhost", "0.0.0.0", "::", "::1"}
        or normalized.startswith("127.")
    )


lola_report = load(sys.argv[1])
loopback_report = load(sys.argv[2])

if lola_report.get("role") != "tx-rx":
    fail("pmr-23/lola-media-session.json role must be tx-rx")
require_true(lola_report.get("realLinkTransmitted"), "pmr-23/lola-media-session.json realLinkTransmitted")
if lola_report.get("runtimeError"):
    fail("pmr-23/lola-media-session.json runtimeError must be empty")
lola_frames = lola_report.get("frames")
if not isinstance(lola_frames, list) or not lola_frames:
    fail("pmr-23/lola-media-session.json frames must be non-empty")
for field in (
    "audioFrameCount",
    "totalWireBytes",
    "envelopeValidatedFrameCount",
    "expectedDatagramCount",
    "sentBytesTotal",
):
    require_positive(lola_report.get(field), f"pmr-23/lola-media-session.json {field}")
local_host = lola_report.get("localHost")
peer = lola_report.get("peer")
require_non_empty(local_host, "pmr-23/lola-media-session.json localHost")
require_non_empty(peer, "pmr-23/lola-media-session.json peer")
if local_host == peer:
    fail("pmr-23/lola-media-session.json localHost and peer must be distinct")
if is_loopback_or_unspecified(local_host):
    fail("pmr-23/lola-media-session.json localHost must be a live non-loopback host")
if is_loopback_or_unspecified(peer):
    fail("pmr-23/lola-media-session.json peer must be a live non-loopback peer")

if loopback_report.get("runnerKind") != "audioDeviceIOProc":
    fail("pmr-23/audio-loopback-run.json runnerKind must be audioDeviceIOProc")
if loopback_report.get("state") != "completed":
    fail("pmr-23/audio-loopback-run.json state must be completed")
configuration = loopback_report.get("configuration") or {}
preflight = loopback_report.get("preflight") or {}
input_device = preflight.get("inputDevice") or {}
output_device = preflight.get("outputDevice") or {}
require_true(preflight.get("rmeMadiVisible"), "pmr-23/audio-loopback-run.json preflight.rmeMadiVisible")
require_true(preflight.get("sampleRateSupported"), "pmr-23/audio-loopback-run.json preflight.sampleRateSupported")
require_true(preflight.get("frameSizeInReportedRange"), "pmr-23/audio-loopback-run.json preflight.frameSizeInReportedRange")
require_true(preflight.get("canStartIOProc"), "pmr-23/audio-loopback-run.json preflight.canStartIOProc")
if preflight.get("blockers") != []:
    fail("pmr-23/audio-loopback-run.json preflight.blockers must be empty")
input_uid = configuration.get("inputUID")
output_uid = configuration.get("outputUID")
require_non_empty(input_uid, "pmr-23/audio-loopback-run.json configuration.inputUID")
require_non_empty(output_uid, "pmr-23/audio-loopback-run.json configuration.outputUID")
if input_device.get("uid") != input_uid:
    fail("pmr-23/audio-loopback-run.json preflight.inputDevice.uid must match configuration.inputUID")
if output_device.get("uid") != output_uid:
    fail("pmr-23/audio-loopback-run.json preflight.outputDevice.uid must match configuration.outputUID")
for field in ("sampleRateHertz", "framesPerBuffer", "channelCount", "durationSeconds"):
    require_positive(configuration.get(field), f"pmr-23/audio-loopback-run.json configuration.{field}")
callback = loopback_report.get("callback") or {}
require_positive(
    callback.get("recordedIntervalSamples"),
    "pmr-23/audio-loopback-run.json callback.recordedIntervalSamples",
)
handoff = loopback_report.get("handoff") or {}
for field in ("inputBlocks", "outputBlocks", "networkSendBlocks", "networkReceiveBlocks"):
    require_positive(handoff.get(field), f"pmr-23/audio-loopback-run.json handoff.{field}")
require_true(handoff.get("shutdownCompleted"), "pmr-23/audio-loopback-run.json handoff.shutdownCompleted")
cleanup = loopback_report.get("cleanup") or {}
if cleanup.get("failures") != []:
    fail("pmr-23/audio-loopback-run.json cleanup.failures must be empty")
PY
  echo "PMR-23 runtime proof fields -> present"
}

validate_report "PMR-04" "pmr-04/realtime-audio-engine.json" "validate-realtime-audio-engine-report" "PASS"
validate_sanitizer_result
validate_pmr04_runtime_contract

validate_report "PMR-14" "pmr-14/rx-buffer-benchmark.json" "validate-rx-buffer-benchmark-report" "PASS"
validate_report "PMR-14" "pmr-14/drift-plc-certification.json" "validate-drift-plc-certification-report" "PASS"
validate_report "PMR-14" "pmr-14/direct-p2p-session.json" "validate-direct-p2p-session-report" "PASS"
validate_direct_p2p_bundle
validate_pmr14_runtime_contract

validate_report "PMR-16" "pmr-16/madi-full-duplex.json" "validate-madi-full-duplex-report" "PASS"
validate_hardware_notes
validate_pmr16_runtime_contract

validate_report_with_output_match \
  "PMR-23" \
  "pmr-23/lola-media-session.json" \
  "validate-lola-media-session-report" \
  "PARTIAL" \
  "^role: tx-rx$" \
  "PMR-23 LoLa media session"
validate_report_with_output_match \
  "PMR-23" \
  "pmr-23/lola-media-session.json" \
  "validate-lola-media-session-report" \
  "PARTIAL" \
  "^real-link-transmitted: true$" \
  "PMR-23 LoLa media session"
validate_report_with_output_match \
  "PMR-23" \
  "pmr-23/lola-media-session.json" \
  "validate-lola-media-session-report" \
  "PARTIAL" \
  "^frames: [1-9][0-9]*$" \
  "PMR-23 LoLa media session"
validate_report_with_output_match \
  "PMR-23" \
  "pmr-23/audio-loopback-run.json" \
  "validate-audio-loopback-run-report" \
  "PARTIAL" \
  "^state: completed$" \
  "PMR-23 audio loopback run"
validate_report_with_output_match \
  "PMR-23" \
  "pmr-23/audio-loopback-run.json" \
  "validate-audio-loopback-run-report" \
  "PARTIAL" \
  "^can-start-ioproc: true$" \
  "PMR-23 audio loopback run"
validate_report_with_output_match \
  "PMR-23" \
  "pmr-23/audio-loopback-run.json" \
  "validate-audio-loopback-run-report" \
  "PARTIAL" \
  "^blockers: 0$" \
  "PMR-23 audio loopback run"
validate_report "PMR-23" "pmr-23/recording-session.json" "validate-recording-session-report" "PASS"
validate_pmr23_runtime_contract

echo "PMR external proof bundle verified"
echo "VERDICT: PASS"
