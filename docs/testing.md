# Testing And Verification

Date: 2026-05-22
Status: active testing index after audit archive cleanup
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
The completed 2026-05-20 to 2026-05-21 audit/refactor/remediation packet and
latest remediation status are archived under
`../archive/2026-05-21-audit-remediation-closure/`.

There is no active plan, ledger, status, or test-quality audit file under a
docs testing subfolder. Start new test-quality or remediation work from a fresh live
inventory, then create a new scoped plan if needed.

Latest doc-refresh evidence, 2026-05-21:

- `swift build --product open-lola --build-path /private/tmp/open-lola2-doc-refresh-build`
  passed outside the sandbox after the known SwiftPM manifest sandbox failure.
- `goal-runtime-preflight-run`, `goal-completion-audit-run`, and
  `open-source-release-readiness-run` passed as report-generation commands and
  their validators passed; all remained `VERDICT: PARTIAL`.
- The unsandboxed completion audit reported 93 mapped items, 77 pass,
  16 partial, 16 blocked items, 21 blockers, and 21 next actions.
- The full Swift suite was not rerun for this docs refresh. Do not infer
  "all tests pass" from the source build and report validators.

## Source Gates

Run these after documentation-only changes:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
shellcheck -x scripts/verify-docs.sh scripts/lib/*.sh
git diff --check
bash scripts/verify-release-hygiene.sh
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
swift build --product open-lola
swift test --no-parallel
bash script/build_and_run.sh --verify
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

App surface smoke:

```bash
swift build --product open-lola-app
bash script/build_and_run.sh --verify
```

The bundle verifier stages `dist/OpenLoLa.app`. Treat app verification failures
as user-visible caveats. Do not claim app smoke success if the verifier reports
an accessibility-label, launch, signing, or bundle mismatch.

Repeatable app-shell visual/accessibility smoke evidence:

```bash
OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola-app-uiux-evidence \
  bash script/build_and_run.sh --verify
```

Required generated artifacts:

- `/private/tmp/open-lola-app-uiux-evidence/manifest.txt`
- `/private/tmp/open-lola-app-uiux-evidence/process.pid`
- `/private/tmp/open-lola-app-uiux-evidence/window.txt`
- `/private/tmp/open-lola-app-uiux-evidence/accessibility-ui.txt`
- `/private/tmp/open-lola-app-uiux-evidence/screenshot.png`
- `/private/tmp/open-lola-app-uiux-evidence/os-log.txt`

This smoke evidence proves launch, one visible app window, a captured screenshot,
and required accessibility/menu labels for the default operator surface. It does
not prove every route, focus state, VoiceOver announcement, contrast pair,
long-value layout, or minimum-window state. Pair it with the manual UI/UX gate
below before closing visual/accessibility findings.

### App UI/UX Manual Acceptance Gate

Run this gate before claiming minimum-window, long-text, focus, contrast, or
visual accessibility closure. It is manual evidence, not a substitute for the
source tests above.

Preparation:

```bash
bash script/build_and_run.sh --verify
```

Use the staged `dist/OpenLoLa.app` bundle from the verifier. Set the main
operator window to the tested minimum, 1024x720. Repeat the pass in light, dark,
and increased-contrast appearances. Capture screenshots for every failed and
passed state named below; store them outside the repo unless a release/audit
task explicitly asks to commit image evidence.

Long-value fixture values:

- Report path:
  `/private/tmp/open-lola-uiux-long-values/reports/2026-05-20/direct-peer-supervisor-report-with-very-long-generated-name-and-peer-session-token.json`
- Executable path:
  `/Applications/Open LoLa Research Builds/OpenLoLa Experimental Runtime With Long Name.app/Contents/MacOS/open-lola`
- Local host:
  `macbook-pro-open-lola-stage-with-very-long-hostname.local`
- Remote host:
  `windows-lola-peer-with-long-hostname.example.local`
- Audio UID:
  `AppleUSBAudioEngine:OpenLoLa:LongAggregateDevice:Input:UID:With:Many:Segments:0001`
- Video UID:
  `AVCaptureDevice:ContinuityCamera:OpenLoLa:VeryLongVideoDeviceIdentifier:0001`
- Packet row source:
  `udp://macbook-pro-open-lola-stage-with-very-long-hostname.local:19788`
- Packet row destination:
  `udp://windows-lola-peer-with-long-hostname.example.local:19798`
- Error text:
  `Validation evidence incomplete: supervisor report path exists but does not match the current session token; re-run validation after saving runtime-affecting settings.`

Minimum-window screenshot checklist:

- Main window at 1024x720: Overview, Devices, Routing, Session, Streams, Packet
  Monitor, Diagnostics, Validation, and Settings sidebar sections.
- Native Settings window at its minimum width with Execution, Preview, Snapshot,
  and any visible mode-specific tabs.
- Local Preview window with preview inactive, starting, failed, and active-local
  metering states when hardware permissions allow it.
- Packet Monitor with no capture report, empty filtered result, and long packet
  rows/details.
- Dialogs/sheets: Stop confirmation, Quit confirmation, Settings stale-draft
  warning, artifact import/write failure, and validation blocker recovery.

Acceptance criteria:

- No task label, status badge, button label, dialog title, or warning copy is
  clipped at 1024x720.
- Long paths, UIDs, hostnames, generated commands, packet rows, and errors have
  a visible route to the full value through selection, copy, details, or help.
- Disabled controls show a visible reason or an accessible recovery path.
- Status meaning is available through text or icon shape, not color alone.
- Focus remains visible during keyboard traversal through sidebar, topbar,
  transport, Packet Monitor actions, settings controls, copy buttons, and
  dialogs.
- Light, dark, and increased-contrast appearances keep warning, error, success,
  disabled, selected, and empty states readable.
- Any failed screenshot becomes a targeted follow-up slice naming the exact
  section, control, fixture value, appearance, and window size.

## External Connector Parity Gates

The macOS app can launch LoLa, JackTrip, and UltraGrid/MVTP connector sessions
through the native Open LoLa `external-connector-session-run` command and can
validate their generated reports with
`validate-external-connector-session-report`. That app path verifies Open LoLa
runner/report wiring; it does not invoke bundled reference connector binaries
and is not reference-peer interoperability evidence.

UltraGrid/MVTP and JackTrip source-level runtime support is implemented, but
reference-peer parity remains an external evidence gate:

```bash
bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-ultragrid ultragrid
bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-jacktrip jacktrip
```

Current known skip-loud prerequisites:

- UltraGrid/MVTP needs `OPEN_LOLA_REFERENCE_PEER_HOST`.
- JackTrip needs `OPEN_LOLA_REFERENCE_PEER_HOST` and a local `jacktrip`
  executable.

An exit 77 readiness report is not interoperability evidence and must not be
counted as `PASS`.

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

The archived `plan.md` external-remediation bundle has a dedicated validator:

```bash
swift build --product open-lola
bash scripts/verify-pmr-external-proof-bundle.sh /path/to/pmr-external-proof-bundle
```

That bundle gate covers PMR-04, PMR-14, PMR-16, and PMR-23 from
`archive/2026-05-22-plan-md-external-proof-closure/root/plan-missed-remediation-ledger.md`.
PMR-04 requires a measured RME MADI
realtime run with `audioDeviceIOProc` callback ownership, UDP setup before
start, report writing after stop, completed shutdown, nonzero handoff counters,
and either `ASAN: PASS` plus `TSAN: PASS` or
`SANITIZER_RUNTIME_BLOCKED: <reason>`. PMR-14 requires a physical-reference RX
benchmark with a direct fastest-eligible row, measured drift certification with
a measured LoLa baseline on the same hardware/route and an `openLolaFaster` or
`openLolaEquivalent` result, physical two-peer P2P evidence with packet-capture,
DSCP, and clock artifacts, nonzero sent/received/routed/queued audio payloads,
and zero explicit loss/drop/underrun/deadline counters. The PMR-23 CoreAudio
artifact is the `audio-loopback-run` JSON validated by
`validate-audio-loopback-run-report`; a valid closure bundle must show
`state: completed`, `can-start-ioproc: true`, and zero preflight blockers plus
`audioDeviceIOProc`, callback samples, nonzero handoff counters, completed
handoff shutdown, and empty cleanup failures. The LoLa media artifact must be a
`tx-rx` run with `real-link-transmitted: true`, a non-loopback peer, distinct
local/peer hosts, sent bytes, expected datagrams, audio frames, wire
bytes, and envelope validation. The PMR-16 hardware notes must include
non-empty, distinct `input UID:` and `output UID:` values for the RME MADI
setup, peer-readiness exchange, teardown completion, and packet-capture notes;
the MADI report must show distinct two-peer hosts and nonzero TX/RX/rendered
packet-block metrics. It must not be treated as passing until the real
hardware, sanitizer/runtime, RX/drift, MADI, LoLa peer, CoreAudio, and recording
artifacts exist and validate.

## Resume Here

Use the narrow docs gate for docs-only cleanup. Use the broader matrix whenever
source, CLI, report schemas, release hygiene, or user-facing behavior changes.

VERDICT: PARTIAL
