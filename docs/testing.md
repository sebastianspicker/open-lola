# Testing And Verification

Date: 2026-07-24
Status: active public testing index
Verdict: PARTIAL

This is the active verification index. Local workflow records and transient
status material are intentionally excluded from version control.
Verification authority comes from current source, tests, CI, and the commands
documented here.

Latest toolchain and hygiene refresh, 2026-07-24:

- `scripts/verify-tracked-boundary.sh` confirms that ignored private, archive,
  local-tool, generated, credential, database, and editor-state paths are
  absent from the Git index.
- `scripts/verify-release-hygiene.sh` scans the live checkout for generated or
  private residue in addition to enforcing the repository policy.
- `swift build --disable-sandbox --scratch-path
  /private/tmp/open-lola-final-build` passed with the available Swift
  6.2.4/Xcode 26.3 host. Exact Swift 6.3.3/Xcode 26.6 execution remains a
  pinned CI responsibility.
- The serialized Swift suite ran all 1,094 tests, including socket-backed
  cases, with no failures.
- Focused release-export, live-residue hygiene, line-budget, shared CLI-path,
  proof-bundle, parity-script, CI-policy, and documentation gates passed.
- The source-documentation gate passed for the active first-party source
  boundary and its public Swift and exported Python declarations.
- Python 3.11.14 and pytest 8.4.2 from an existing external environment ran
  all 147 pytest cases. Strict mypy passed across 25 source files with locally
  installed mypy 2.3.0; CI pins Python 3.14.6, pytest 9.1.1, and mypy 1.14.1.
- The exact locked Python environment was not recreated offline because the
  `ruff==0.15.20` wheel was absent from the local cache. Ruff 0.16.0 reported
  50 lint findings in the dirty checkout.
- Repository hygiene and an offline UI render do not establish runtime or
  product readiness.

## Source Gates

Run these after documentation-only changes:

```bash
bash scripts/verify-docs.sh
scripts/macos/generate_brand_assets.sh --check
python3 -m scripts.verify_docs
python3 scripts/verify_source_documentation.py
shellcheck -x scripts/verify-docs.sh scripts/lib/*.sh
git diff --check
bash scripts/verify-release-hygiene.sh
```

Run the broader source/release matrix after source, CLI, verifier, or release
surface changes:

```bash
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env uv lock --check
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env uv run --extra dev --locked ruff check linux_connector scripts/verify_docs scripts/lib/*.py
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env MYPY_CACHE_DIR=/private/tmp/open-lola-mypy-cache uv run --extra dev --locked python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env PYTHONDONTWRITEBYTECODE=1 uv run --extra dev --locked python -m pytest -p no:cacheprovider linux_connector/tests
shellcheck -x scripts/*.sh scripts/lib/*.sh scripts/macos/*.sh linux_connector/deployment/wsl/*.sh
bash scripts/verify-release-hygiene.sh
export OPEN_LOLA_SWIFT_BUILD_PATH=/private/tmp/open-lola-swiftpm-build
export OPEN_LOLA_TEST_OPEN_LOLA_CLI="$OPEN_LOLA_SWIFT_BUILD_PATH/debug/open-lola"
swift build --disable-sandbox --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
swift build --disable-sandbox --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH" --product open-lola
swift test --disable-sandbox --no-parallel --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
bash scripts/macos/build_and_run.sh --verify
bash scripts/verify-release-readiness.sh
```

CI runs the same release wrapper through
`.github/workflows/release-readiness.yml`, resolves Python tooling from the
locked `uv` environment outside the checkout, and does not publish artifacts.
The primary lane asserts Xcode 26.6, Swift 6.3.3, and Python 3.14.6; a separate
Ubuntu lane explicitly passes `--python 3.11` to `uv sync` and every `uv run`,
then asserts the executed interpreter is Python 3.11 so the root
`.python-version` pin cannot silently select 3.14.6.
Python verification bounds remain declared once in
`[project.optional-dependencies].dev` in `pyproject.toml`; `uv.lock` is the
resolved CI input.
The headless workflow explicitly skips the interactive Launch Services,
accessibility, and screen-capture probe; that probe remains a local manual gate.

Release hygiene is the C12 artifact boundary gate. Set
`OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate`
or pass a candidate
path to scan a staged tree. Manual evidence gates remain manual until real
hardware, route, package, and reviewer evidence exists.

On macOS, use SwiftPM's `--disable-sandbox` when its nested `sandbox-exec`
cannot apply a sandbox. Keep scratch paths and tool caches under
`/private/tmp` so verification does not repopulate the public checkout.

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

### Test source layout

- `Tests/OpenLolaCoreTests/` is the single SwiftPM test target. It contains 218
  active Swift Testing source files, 58 compiled support files, and 62 versioned
  JSON or HEX fixtures under `Fixtures/`.
- `linux_connector/tests/` contains seven collected pytest modules,
  `conftest.py`, and shared assertions in `support.py`.
- `Sources/opus-1.5.2/` contains upstream Opus tests and test tooling that are
  not selected by `Package.swift` or repository CI. They remain inside the
  vendored source boundary and are excluded from release candidates.
- Files in `Sources/OpenLolaCore/Release/` whose names contain `Test` model
  release or field-test reports. They are production source, not test-target
  files.

Keep first-party active test source and deterministic fixtures under version
control. Coverage, test reports, caches, local environments, temporary
databases, and failure artifacts remain local.

## Surface Probes

Use focused probes for user-facing surfaces:

```bash
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" session-capabilities
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight.json
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight.json
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit.json
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit.json
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness.json
"$OPEN_LOLA_TEST_OPEN_LOLA_CLI" validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness.json
```

Connector and Docker helper procedures live in
[../scripts/README.md](../scripts/README.md). They are local process
evidence only unless paired with physical route and media measurements.

App source and executable smoke:

```bash
swift build --product open-lola-app
bash scripts/macos/build_and_run.sh --verify
```

The bundle verifier stages `dist/OpenLoLa.app`. Treat app verification failures
as user-visible caveats. Do not claim app smoke success if the verifier reports
an accessibility-label, launch, signing, or bundle mismatch.

Fixed-scenario documentation screenshots are a separate, offline lane:

```bash
bash scripts/macos/render_docs_screenshots.sh
```

The renderer mounts the real `AppShellRootView` at a fixed 1586×992 size with
fixed in-memory source/synthetic state and writes the selected light and dark
PNGs under `.github/assets/`. It does not use Launch Services, attached
hardware, network peers, prior user defaults, or live reports. A successful
render proves only that this SwiftUI hierarchy can be documented in that fixed
scenario; captions must not call it a live session or measured evidence.

Local bundle-launch visual/accessibility evidence remains distinct:

```bash
OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola-app-uiux-evidence \
  bash scripts/macos/build_and_run.sh --verify
```

Required generated artifacts:

- `/private/tmp/open-lola-app-uiux-evidence/manifest.txt`
- `/private/tmp/open-lola-app-uiux-evidence/process.pid`
- `/private/tmp/open-lola-app-uiux-evidence/window-list.txt`
- `/private/tmp/open-lola-app-uiux-evidence/accessibility-ui.txt`
- `/private/tmp/open-lola-app-uiux-evidence/screenshot.png`
- `/private/tmp/open-lola-app-uiux-evidence/os-log.txt`

Only a successful run proves that this bundle launched in the current GUI
session, exposed one visible app window, produced a window-scoped screenshot,
and exposed the required accessibility/menu labels. It does not prove media
health, every route, focus state, VoiceOver announcement, contrast pair,
long-value layout, or minimum-window state. Pair it with the manual UI/UX gate
below before closing visual/accessibility findings.

### App UI/UX Manual Acceptance Gate

Run this gate before claiming minimum-window, long-text, focus, contrast, or
visual accessibility closure. It is manual evidence, not a substitute for the
source tests above.

Preparation:

```bash
bash scripts/macos/build_and_run.sh --verify
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

- Main window at 1024x720: Session, Connection, Routing, Media, Packets, Review,
  and Diagnostics sidebar workspaces; Settings remains a native Settings scene.
- Native Settings window at its minimum width with Execution, Preview, Snapshot,
  and any visible mode-specific tabs.
- Local Preview window with preview inactive, starting, failed, and active-local
  metering states when hardware permissions allow it.
- Packets with no capture report, empty filtered result, and long packet
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
- Focus remains visible during keyboard traversal through the sidebar, toolbar,
  persistent transport, Packets actions, settings controls, copy buttons, and
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

The external-proof bundle has a dedicated validator:

```bash
export OPEN_LOLA_SWIFT_BUILD_PATH=/private/tmp/open-lola-swiftpm-build
swift build --disable-sandbox --product open-lola --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
bash scripts/verify-pmr-external-proof-bundle.sh /path/to/pmr-external-proof-bundle
```

That source-owned gate covers the PMR-04, PMR-14, PMR-16, and PMR-23 evidence
contracts. PMR-04 requires a measured RME MADI
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

VERDICT: PARTIAL
