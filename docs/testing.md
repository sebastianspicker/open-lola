# Testing And Verification

Date: 2026-05-15
Status: condensed active testing index
Verdict: PARTIAL

This is the active verification index. The older verification matrix and
remediation progress ledgers were superseded and archived under
`../archive/2026-05-11-doc-condense/docs/testing/` and
`../archive/2026-05-11-doc-cleanup/docs/testing/`. The completed root
Plan.md remediation ledger is archived under
`../archive/2026-05-11-plan-remediation/root/`. The completed 2026-05-16
source-audit/refactor/remediation bundle, including the test-quality audit, is
archived under
`../archive/2026-05-16-source-audit-refactor-closure/`.
The completed 2026-05-17 refactor-remediation verification baseline and closure
status are archived under
`../archive/2026-05-17-refactor-remediation-closure/`.

There is no active plan, ledger, status, or test-quality audit file under a
docs testing subfolder. Start new test-quality or remediation work from a fresh live
inventory, then create a new scoped plan if needed.

## Source Gates

Run these after documentation-only changes:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
shellcheck -x scripts/verify-docs.sh scripts/lib/*.sh
```

Run the broader source/release matrix after source, CLI, verifier, or release
surface changes:

```bash
RUFF_CACHE_DIR=/tmp/open-lola-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
MYPY_CACHE_DIR=/tmp/open-lola-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
bash scripts/verify-release-hygiene.sh
swift build
swift test --no-parallel
bash scripts/verify-release-readiness.sh
```

CI runs the same release wrapper through
`.github/workflows/release-readiness.yml`; the workflow does not publish
artifacts.
Python verification tool bounds are declared once in `pyproject.toml` under
`[project.optional-dependencies].dev`; CI reads that group instead of carrying a
second copy of the dependency versions.

Release hygiene is the C12 artifact boundary gate. Set
`OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate` or pass a candidate
path to scan a staged tree. Manual evidence gates remain manual until real
hardware, route, package, and reviewer evidence exists.

SwiftPM may need to run outside the sandbox on this Mac when manifest
sandboxing fails.

## Test Categories

Some Swift tests are policy, inventory, or documentation alignment checks. They
are useful source gates, but they are not runtime proof. Do not count tests that
only inspect source text, docs, workflow YAML, or file existence as evidence
that audio, video, networking, release packaging, or hardware behavior works.

When policy or inventory checks guard a high-risk surface, pair them with an
executable behavior gate where practical. Current examples include the release
candidate export/hygiene probe, the release-readiness script dry-run matrix,
Docker/WSL helper command probes, and machine-readable inventory/report JSON
round trips. Runtime readiness still requires the relevant build, test,
validator, smoke, manual hardware, signing, and route evidence listed below.

## Surface Probes

Use focused probes for user-facing surfaces:

```bash
.build/debug/open-lola session-capabilities
.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness.json
.build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness.json
```

Connector and Docker helper procedures live in
[../scripts/README.md](../scripts/README.md). They are local process
evidence only unless paired with physical route and media measurements.

## Windows LoLa Compatibility Probe

The 2026-05-15 Swift Windows LoLa probe used the Swift CLI, not the Python
Linux connector:

```bash
.build/debug/open-lola external-connector-session-run \
  --connector lola --role tx-rx \
  --peer 192.168.178.47 --local-host 192.168.178.46 \
  --output /private/tmp/open-lola-swift-windows-lola-patched-splitloops-12s.json \
  --dry-run false --media audio-video --control-transport udp \
  --duration-seconds 12 --control-port 7000 \
  --audio-port 19788 --video-port 19798 \
  --channels 2 --sample-rate 44100 --frames 64 \
  --video-width 640 --video-height 480 --video-fps 25 --video-bpp 8 \
  --lola-video-payload generated --video-compression 0 --video-bayer 1 \
  --media-packets 300 --session-id 0
```

Observed result: Windows reported the Mac Swift responder as running, generated
AV was visible, and Windows-side audio buffer realignment was reduced by roughly
90%. The Swift report remains `FAIL`/`PARTIAL` for full compatibility because
RX decoded zero Windows-originated media frames before timeout.

## Release Validation Harnesses

The `Sources/OpenLolaCore/Release/` harnesses are active source-level report
and validation surfaces. They are not all invoked directly by
`scripts/verify-release-readiness.sh` because several require human-supplied
hardware, signing, packaged artifact, clean-Mac, or reviewer evidence.

| Source surface | Active command or check | Automation status |
|---|---|---|
| `OpenSourceReleaseReadiness.swift` | `open-source-release-readiness-run` and `validate-open-source-release-readiness-report` | Run by `scripts/verify-release-readiness.sh` and CI. |
| `PackagingFieldTest*.swift` | `packaging-field-run`, `packaging-field-synthetic-smoke`, and `validate-packaging-field-report` | Covered by `PackagingFieldTestTests`; pass verdict remains manual until Developer ID, notarization, Gatekeeper, and clean-Mac evidence exists. |
| `RecordingSession*.swift` | `recording-session-run`, `recording-session-synthetic-smoke`, and `validate-recording-session-artifact-report` | Covered by `RecordingSessionArtifactTests` and `RecordingSessionLiveCaptureTests`; pass verdict remains manual until real capture evidence exists. |
| `ReleaseHardening*.swift` | `release-hardening-run`, `release-hardening-synthetic-smoke`, and `validate-release-hardening-report` | Covered by `ReleaseHardeningTests`; aggregates attached release reports but does not replace manual evidence gates. |
| `FieldReadyRuntimeProof*.swift` and `FasterThanLoLaClosure*.swift` | `field-ready-runtime-proof-run`, `faster-than-lola-closure-run`, and validators | Covered by focused Swift tests; these are closure reports, not publication commands. |
| `CurrentEvidenceStatusMatrix.swift` | `current-evidence-status-matrix` | Covered by `CurrentEvidenceStatusMatrixTests`; summarizes current evidence only. |

No `Release/` Swift harness is archived as dead code while it has an active
CLI command, validator, fixture/schema test, or manual evidence gate.

## Manual Evidence Gates

Real-world closure still requires:

- RME/MADI hardware, loopback, and realtime callback ownership.
- Two-Mac UDP/P2P packet capture, DSCP/PTP, jitter/loss, and fastest-baseline
  comparison.
- Blackmagic/ATEM or reviewed video capture, OSC, sACN/Art-Net, and
  audio-impact evidence.
- Signed/notarized package, Gatekeeper, clean-Mac launch, fixture provenance,
  license/notices, and reviewer signoff.

## Resume Here

Use the narrow docs gate for docs-only cleanup. Use the broader matrix whenever
source, CLI, report schemas, release hygiene, or user-facing behavior changes.

VERDICT: PARTIAL
