# Simplicity Remediation Plan

Date: 2026-05-17

Source audit: `docs/simplicity-test-certainty-audit.md`

Status: planning only. This document turns the consolidated audit findings into
small, independently reviewable remediation slices. It does not change
production code or tests.

## Scope And Rules

This plan is limited to findings in `docs/simplicity-test-certainty-audit.md`.
It does not introduce speculative features and does not treat uncertain
compatibility surfaces as deletion targets. When the audit says active use is
unclear, the slice is marked `INVESTIGATION`.

Prioritization follows the requested order:

1. False success in critical paths.
2. Broken or missing tests for important behavior.
3. Over-engineering that hides correctness problems.
4. Deprecated or stale compatibility paths.
5. Single-use abstractions.
6. Duplication and boilerplate.
7. Cosmetic simplification.

Non-targets unless a future audit changes the evidence:

- `audioCompression` compatibility, because the source audit marks it `KEEP`.
- `ExternalConnectorNMP`, raw Ethernet helpers, and the line-budget gate as
  deletion targets before active-use or policy evidence is collected.
- Files the audit explicitly described as simple enough:
  `CLICommandHelpers.validateReport`, base `ReportValidatorSurface`,
  `linux_connector/lola_connector/media.py`,
  `ExternalConnectorSessionRuntime`, and `ExternalConnectorProcessRunner`.

## Remediation Slices

### SRP-001

- Slice ID: `SRP-001`
- Title: Report Direct Peer Realtime Graph Cleanup Failures
- Findings addressed: `STC-FL-001`
- Problem: `DirectPeerRealtimeAudioGraph.stopUnlocked()` can clear graph state
  after unverified `AudioDeviceStop`, IOProc destroy, sample-rate restore, or
  buffer restore failures.
- Minimal fix strategy: capture stop, destroy, and restore outcomes before
  clearing state. Preserve the current shutdown path, but expose failed or
  unknown cleanup in a typed result or report metadata.
- Files likely affected:
  `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`;
  focused realtime graph tests.
- Behavior affected: realtime graph shutdown no longer implies successful
  device cleanup without evidence.
- Tests to add/update: injected Core Audio stop failure, IOProc destroy
  failure, sample-rate restore failure, and buffer restore failure tests.
- Verification commands:
  `swift test --filter DirectPeerRealtimeAudioGraphTests`;
  `swift test --filter DirectPeerRealtimeAudioGraphRxBufferingTests`.
- Risk level: high.
- Rollback strategy: revert the graph cleanup result plumbing and its focused
  tests in one commit; restore previous shutdown behavior.
- Definition of Done: cleanup failures are visible in results or report
  metadata, and a failed cleanup cannot be reported as fully successful.

### SRP-002

- Slice ID: `SRP-002`
- Title: Report Audio Loopback IOProc Cleanup Failures
- Findings addressed: `STC-FL-002`
- Problem: `AudioLoopbackRunner.runIOProc(...)` can produce a `.completed`
  report while IOProc destroy or device restoration failures are ignored.
- Minimal fix strategy: record destroy and restore outcomes in the loopback
  report. Downgrade or annotate completion when cleanup is failed or unknown.
- Files likely affected:
  `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift`;
  `Tests/OpenLolaCoreTests/AudioLoopbackRunTests.swift`.
- Behavior affected: audio loopback reports distinguish completed media work
  from failed cleanup or restoration.
- Tests to add/update: injected IOProc destroy failure, sample-rate restore
  failure, buffer restore failure, and validator rejection of plain completed
  claims when cleanup failed.
- Verification commands:
  `swift test --filter AudioLoopbackRunTests`;
  `swift test --filter VerdictValidationPolicyTests`.
- Risk level: high.
- Rollback strategy: revert report-field additions and loopback cleanup
  handling together; keep any independent test fixtures only if still useful.
- Definition of Done: a loopback run with cleanup failure cannot produce an
  unqualified completed/success report.

### SRP-003

- Slice ID: `SRP-003`
- Title: Require UDP PCM Loopback Receive-Side Completion
- Findings addressed: `STC-FL-003`
- Problem: `UdpPcmLoopbackSmoke.run(...)` can return sender evidence while the
  looper failed, timed out, or never completed.
- Minimal fix strategy: require an explicit looper result before returning the
  sender report. Propagate looper errors and record timeout or receive-side
  counts.
- Files likely affected:
  `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift`;
  `Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift`;
  `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`.
- Behavior affected: UDP loopback evidence must include both send and receive
  side status.
- Tests to add/update: injected looper failure, looper timeout, zero packets
  received, and successful loopback completion tests.
- Verification commands:
  `swift test --filter UdpPcmLoopbackLatencyTests`;
  `swift test --filter UdpPcmRouteReportTests`;
  `swift test --filter UdpPcmPacketTests`.
- Risk level: high.
- Rollback strategy: revert the looper result requirement and associated report
  fields; keep the failing tests disabled only if the evidence contract is
  explicitly re-scoped.
- Definition of Done: loopback reports cannot be generated from sender-only
  evidence when receive-side work failed or timed out.

### SRP-004

- Slice ID: `SRP-004`
- Title: Prevent Native App Launch PASS Without Required Labels
- Findings addressed: `STC-FL-004`, `STC-TI-004`
- Problem: native app release readiness can print launch `PASS` when required
  UI label capture is unavailable and fallback evidence files exist.
- Minimal fix strategy: make label capture mandatory for `--verify`, or emit an
  explicit `PARTIAL`/`UNCERTAIN` state that release readiness does not print as
  `PASS`.
- Files likely affected:
  `script/build_and_run.sh`;
  `scripts/verify-release-readiness.sh`;
  `Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift`.
- Behavior affected: release readiness no longer treats fallback UI evidence as
  verified app launch proof.
- Tests to add/update: `osascript` failure with screenshot present, visible
  window without labels, missing screenshot, blank screenshot, and release
  readiness output assertions.
- Verification commands:
  `swift test --filter AppBundleScriptSourcePolicyTests`;
  `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`;
  `bash scripts/verify-release-readiness.sh`.
- Risk level: high.
- Rollback strategy: revert script policy and tests together; keep the previous
  fallback wording only if the release verdict is explicitly downgraded.
- Definition of Done: app launch readiness cannot print `PASS` unless required
  labels were actually captured.

### SRP-005

- Slice ID: `SRP-005`
- Title: Make Swift LoLa Fallback Tests Fail Or Skip Explicitly
- Findings addressed: `STC-TI-001`
- Problem: Swift LoLa fallback tests can return early when the `127.0.0.2`
  loopback alias is unavailable, making critical fallback behavior look green.
- Minimal fix strategy: replace early returns with explicit skip or failure
  semantics for the relevant verification profile, and add socket-free state
  transition tests where possible.
- Files likely affected:
  `Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift`;
  LoLa compatibility media/control test helpers if needed.
- Behavior affected: local and CI runs expose whether LoLa fallback behavior was
  exercised, skipped, or failed.
- Tests to add/update: alias unavailable case, alias available with peer bind
  timeout, status ACK timeout followed by QuickConn success, and control socket
  retry behavior.
- Verification commands:
  `swift test --filter LoLaQuickConnectFallbackTests`;
  `swift test --filter LoLaCompatibilityMediaSessionTests`.
- Risk level: medium.
- Rollback strategy: revert the skip/failure contract and socket-free tests in
  one commit if CI environment constraints make the gate impractical.
- Definition of Done: fallback tests never silently pass without exercising or
  explicitly reporting the unavailable capability.

### SRP-006

- Slice ID: `SRP-006`
- Title: Add Rendered App UI Runtime-State Coverage
- Findings addressed: `STC-TI-004`, `STC-MC-001`
- Problem: app UI truth is mostly protected by model and script-text tests, not
  a rendered runtime-state test that proves status text follows report evidence.
- Minimal fix strategy: add the smallest launch or rendered-view smoke that can
  drive no-report, malformed-report, partial-report, stale-pass, and valid
  report states. Avoid broad app-controller refactors in this slice.
- Files likely affected:
  app shell/view tests;
  `Sources/open-lola-app/AppExecutionController.swift` only if dependency
  injection is required for the test seam.
- Behavior affected: UI status for connected, live, validated, healthy, and
  PASS-like states must reflect report evidence.
- Tests to add/update: rendered no-report, malformed report, partial report,
  stale passing report, and valid report state tests.
- Verification commands:
  `swift test --filter AppShellBehaviorTests`;
  `swift test --filter NativeAppShellTests`;
  `bash script/build_and_run.sh --verify`.
- Risk level: high.
- Rollback strategy: revert the UI smoke test and any minimal test seam; leave
  production UI behavior unchanged if the test harness proves too unstable.
- Definition of Done: at least one rendered or launch-level test fails when UI
  status claims success without matching runtime/report evidence.

### SRP-007

- Slice ID: `SRP-007`
- Title: Reject Synthetic Smoke False-PASS Mutations
- Findings addressed: `STC-TI-005`
- Problem: synthetic smoke report tests assert valuable partial behavior, but
  do not mutate every synthetic report toward forbidden `PASS` claims.
- Minimal fix strategy: add per-report negative mutation coverage for `PASS`,
  measured mode, real-world readiness, and missing evidence-boundary notes.
- Files likely affected:
  `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift`;
  report validators only if a real validator gap is exposed.
- Behavior affected: synthetic evidence cannot drift into product `PASS`
  without validator rejection.
- Tests to add/update: one false-pass mutation test per synthetic report family.
- Verification commands:
  `swift test --filter SyntheticSmokeReportContractTests`;
  `swift test --filter VerdictValidationPolicyTests`.
- Risk level: medium.
- Rollback strategy: revert mutation tests and validator changes as one slice;
  preserve fixture data unless it caused the regression.
- Definition of Done: every synthetic smoke report variant has at least one
  negative test proving false `PASS` is rejected.

### SRP-008

- Slice ID: `SRP-008`
- Title: Map AppExecutionController Before Extraction
- Findings addressed: `STC-MC-001`
- Problem: `AppExecutionController` mixes command construction, process
  lifecycle, validation, report loading, artifact state, and UI-facing state.
  The audit proves risk, but the safest first extraction depends on live state
  transitions and existing tests.
- Minimal fix strategy: `INVESTIGATION`: map current responsibilities, state
  transitions, and tests. Pick one behavior-first extraction only after the map
  shows the smallest seam.
- Files likely affected:
  `Sources/open-lola-app/AppExecutionController.swift`;
  app-shell tests and a short implementation note in the follow-up PR.
- Behavior affected: none in the investigation slice.
- Tests to add/update: none for the investigation itself; follow-up
  implementation must add tests around the selected seam before extraction.
- Verification commands:
  `rg -n "AppExecutionController|ExecutionState|report|validation|artifact" Sources/open-lola-app Tests/OpenLolaCoreTests`;
  `swift test --filter AppShellBehaviorTests`;
  `swift test --filter AppShellSlice05Tests`;
  `swift test --filter NativeAppShellSurfaceActionTests`.
- Risk level: high if implemented without investigation; low for the
  investigation slice.
- Rollback strategy: discard the responsibility map; no runtime rollback
  needed.
- Definition of Done: the follow-up extraction target is named with existing
  callers, current tests, missing tests, and one concrete behavior it will
  protect.

### SRP-009

- Slice ID: `SRP-009`
- Title: Count Malformed NAT Rendezvous And Relay Datagrams
- Findings addressed: `STC-FL-005`
- Problem: NAT rendezvous and relay loops can skip malformed, wrong-session, or
  wrong-peer datagrams without counters.
- Minimal fix strategy: add explicit skipped/malformed/wrong-session/wrong-peer
  counters to the existing report path without changing happy-path routing.
- Files likely affected:
  `Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift`;
  `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift`;
  `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift`.
- Behavior affected: NAT reports distinguish idle timeout from malformed or
  wrong-peer traffic.
- Tests to add/update: malformed datagram, wrong-session datagram, wrong-peer
  datagram, and clean route behavior.
- Verification commands:
  `swift test --filter NatFriendlyRouteTests`;
  `swift test --filter NetworkDiagnosticsTests`.
- Risk level: medium.
- Rollback strategy: revert counters/report fields and related tests together.
- Definition of Done: NAT report output exposes skipped traffic reasons without
  changing successful routing behavior.

### SRP-010

- Slice ID: `SRP-010`
- Title: Preserve Python LoLa Control Receive Reasons
- Findings addressed: `STC-FL-005`
- Problem: Python QuickConn and status handling can skip malformed control
  datagrams without returning counts, and `check_status(...)` collapses rich
  status reasons to a Boolean.
- Minimal fix strategy: add a rich internal result for control receive/status
  paths, keep any public Boolean convenience only as a thin compatibility layer,
  and expose malformed/wrong-peer counts to callers that need evidence.
- Files likely affected:
  `linux_connector/lola_connector/connector.py`;
  `linux_connector/tests/test_runtime_contracts.py`;
  `linux_connector/tests/test_process_runtime.py`.
- Behavior affected: Python LoLa compatibility reports can distinguish success,
  timeout, malformed input, and wrong-peer input.
- Tests to add/update: malformed QuickConn ACK, wrong-peer control datagram,
  timeout without QuickConn, and current Boolean compatibility behavior.
- Verification commands:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`;
  `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`;
  `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`.
- Risk level: medium.
- Rollback strategy: revert rich result additions and tests; preserve the old
  Boolean API if external compatibility breaks.
- Definition of Done: control receive callers can report why no valid status or
  QuickConn response was accepted.

### SRP-011

- Slice ID: `SRP-011`
- Title: Surface Unverified App Executable Paths
- Findings addressed: `STC-FL-006`, `STC-MC-001`
- Problem: the app can return an unverified executable path after warning,
  allowing UI or command preview state to look runnable without proof.
- Minimal fix strategy: return a typed verified/unverified/unavailable path
  result and prevent unverified paths from driving success-like UI state.
- Files likely affected:
  `Sources/open-lola-app/AppExecutablePathResolver.swift`;
  `Sources/open-lola-app/AppExecutionController.swift`;
  app execution tests.
- Behavior affected: missing or unverified executables show unavailable or
  warning state instead of a plausible runnable command.
- Tests to add/update: nonexistent executable path, non-executable file path,
  verified bundled path, and UI command preview state.
- Verification commands:
  `swift test --filter AppShellBehaviorTests`;
  `swift test --filter NativeAppShellTests`.
- Risk level: medium.
- Rollback strategy: revert typed path resolution and associated UI status
  changes together.
- Definition of Done: no app status or preview reports a path as runnable until
  executable verification succeeds.

### SRP-012

- Slice ID: `SRP-012`
- Title: Verify Pasteboard Copy Before Showing Copied Status
- Findings addressed: `STC-FL-006`
- Problem: pasteboard `setString` Boolean results are ignored while UI status
  can say copied.
- Minimal fix strategy: check pasteboard write results before setting copied
  status. Use a tiny injectable pasteboard boundary only if existing tests
  cannot simulate failure.
- Files likely affected:
  `Sources/open-lola-app/AppOperatorArtifactViews.swift`;
  `Sources/open-lola-app/AppExecutionView.swift`;
  `Sources/open-lola-app/AppPacketMonitorView.swift`;
  `Sources/open-lola-app/AppShellSupportViews.swift`;
  focused app UI tests.
- Behavior affected: copy actions report failure when the pasteboard write is
  not accepted.
- Tests to add/update: successful pasteboard write and failed pasteboard write
  for each copied artifact/action group.
- Verification commands:
  `swift test --filter AppShellBehaviorTests`;
  `swift test --filter AppShellSlice05Tests`.
- Risk level: low to medium.
- Rollback strategy: revert pasteboard result checks and injection seam if it
  adds too much UI complexity.
- Definition of Done: a failed pasteboard write cannot display copied/success
  status.

### SRP-013

- Slice ID: `SRP-013`
- Title: Preserve Managed Process Cleanup Warnings
- Findings addressed: `STC-FL-007`
- Problem: `kill(..., SIGKILL)` and output-handle close failures can be hidden
  from `ManagedProcessTerminationResult`.
- Minimal fix strategy: add cleanup warning/error fields to termination result
  and populate them from kill and handle-close outcomes.
- Files likely affected:
  `Sources/OpenLolaCore/Support/ManagedProcessRunner.swift`;
  `Tests/OpenLolaCoreTests/ManagedProcessRunnerTests.swift`;
  process-group tests if termination result shape is shared.
- Behavior affected: process cleanup and log flush failures are visible to app
  and report callers.
- Tests to add/update: injected kill failure, stdout close failure, stderr close
  failure, and clean termination.
- Verification commands:
  `swift test --filter ManagedProcessRunnerTests`;
  `swift test --filter ExternalConnectorProcessGroupTests`.
- Risk level: medium.
- Rollback strategy: revert termination result fields and tests together.
- Definition of Done: termination result consumers can see kill and close
  failures instead of losing them.

### SRP-014

- Slice ID: `SRP-014`
- Title: Distinguish Raw Video Capture Failure From Disabled Raw Capture
- Findings addressed: `STC-FL-008`
- Problem: AVFoundation raw frame extraction uses `try?`, frames can still be
  counted, saved raw payloads are optional, and pixel-buffer lock status can be
  ignored.
- Minimal fix strategy: count raw extraction attempts and failures. Distinguish
  raw capture disabled from raw capture requested but failed.
- Files likely affected:
  `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`;
  video capture and direct P2P AV validation tests.
- Behavior affected: video evidence no longer implies raw payload capture when
  raw extraction failed.
- Tests to add/update: unsupported pixel buffer, lock failure or invalid buffer,
  raw capture disabled, raw capture requested and successful, and validation of
  missing raw evidence.
- Verification commands:
  `swift test --filter VideoCaptureReportTests`;
  `swift test --filter DirectPeerSessionReportAVPassTests`;
  `swift test --filter VideoTransportReportPolicyTests`.
- Risk level: medium to high.
- Rollback strategy: revert raw extraction accounting and validator/report
  changes together.
- Definition of Done: requested raw capture failures are visible and prevent
  raw-evidence success claims.

### SRP-015

- Slice ID: `SRP-015`
- Title: Name Packaging Field Test Validation Blockers
- Findings addressed: `STC-FL-009`
- Problem: `packagingFieldRunVerdict(...)` downgrades pass-candidate validation
  failures to `PARTIAL` while discarding the validation error.
- Minimal fix strategy: preserve validation error text as a blocked-gate note or
  validation summary when downgrading to partial.
- Files likely affected:
  `Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift`;
  `Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift`;
  release report validator tests if needed.
- Behavior affected: release operators can see why a pass candidate became
  partial.
- Tests to add/update: one forced pass-candidate validation error per relevant
  gate, asserting the generated partial report names the blocker.
- Verification commands:
  `swift test --filter PackagingFieldTestTests`;
  `swift test --filter ReleaseHardeningTests`;
  `swift test --filter OpenSourceReleaseReadinessTests`.
- Risk level: medium.
- Rollback strategy: revert blocker-note additions and tests together.
- Definition of Done: every validation downgrade from pass candidate to partial
  includes a concrete blocker reason.

### SRP-016

- Slice ID: `SRP-016`
- Title: Make Python Loopback Alias Coverage Visible
- Findings addressed: `STC-TI-007`
- Problem: Python connector loopback tests explicitly skip when `127.0.0.2` is
  unavailable, so routine runs may miss important behavior.
- Minimal fix strategy: report skipped loopback capability separately and add
  socket-free parser/state tests for timeout and malformed input paths.
- Files likely affected:
  `linux_connector/tests/test_codec.py`;
  `linux_connector/tests/test_process_runtime.py`;
  `linux_connector/tests/test_runtime_contracts.py`.
- Behavior affected: Python verification distinguishes skipped environment
  capability from behavior coverage.
- Tests to add/update: socket-free malformed control/media payload tests,
  timeout state tests, and explicit alias-skip reporting.
- Verification commands:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`;
  `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`;
  `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`.
- Risk level: medium.
- Rollback strategy: revert socket-free tests and skip-reporting changes if
  pytest output policy conflicts with CI.
- Definition of Done: a run without `127.0.0.2` still exercises parser/state
  failure behavior and clearly reports any skipped loopback socket coverage.

### SRP-017

- Slice ID: `SRP-017`
- Title: Replace Release Run Count Tests With Harness Behavior
- Findings addressed: `STC-TI-002`
- Problem: release-run configuration tests assert row counts and docs
  substrings instead of proving harnesses execute or reject false `PASS`.
- Minimal fix strategy: replace count/literal assertions with executable
  harness checks and false-PASS rejection tests.
- Files likely affected:
  `Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift`;
  release harness tests and docs if command names are updated.
- Behavior affected: release harness drift is caught by behavior, not count or
  substring checks.
- Tests to add/update: missing output path, malformed report input, synthetic
  evidence trying to produce `PASS`, and removed command with stale docs.
- Verification commands:
  `swift test --filter ReleaseRunConfigurationContractTests`;
  `swift test --filter OpenSourceReleaseReadinessTests`;
  `bash scripts/verify-docs.sh`.
- Risk level: low to medium.
- Rollback strategy: restore the old count test temporarily only if the
  behavior checks cannot be made deterministic in the same PR.
- Definition of Done: a broken release harness or false-PASS acceptance fails a
  test even if docs strings and row counts still match.

### SRP-018

- Slice ID: `SRP-018`
- Title: Inventory Literal-Only Tests Before Replacement
- Findings addressed: `STC-TI-003`
- Problem: the audit identifies a family of tests that check paths, literals,
  YAML/doc substrings, command substrings, exact output lines, or stubbed script
  output, but some tests in the same area are valuable behavior checks.
- Minimal fix strategy: `INVESTIGATION`: list each literal-only assertion,
  classify it as public contract, behavior proxy, or removable trivia, then
  open follow-up implementation slices by file family.
- Files likely affected: inventory tests, release hygiene tests, verification
  tooling tests, and runtime evidence template tests.
- Behavior affected: none in the investigation slice.
- Tests to add/update: none in the investigation slice; each follow-up must add
  an executable command, validator, or synthetic-broken-input test before
  deleting trivia assertions.
- Verification commands:
  `rg -n "contains\\(|hasPrefix\\(|hasSuffix\\(|count|isEmpty|exists|readFile" Tests/OpenLolaCoreTests`;
  `swift test --filter VerificationToolingContractTests`;
  `swift test --filter ReleaseArtifactHygieneContractTests`.
- Risk level: low for investigation; medium for follow-up replacements.
- Rollback strategy: discard the classification if it is too broad; no runtime
  rollback needed.
- Definition of Done: every candidate literal assertion is assigned to a
  concrete follow-up action: keep as public contract, replace with behavior, or
  delete after coverage.

### SRP-019

- Slice ID: `SRP-019`
- Title: Prove CLI JSON Surfaces Before Inlining Wrappers
- Findings addressed: `STC-MC-005`
- Problem: `OpenLolaCLI.*Data()` and `*JSONString()` wrappers mostly forward
  machine-readable factories, while wrapper tests can pass if executable CLI
  output is wrong.
- Minimal fix strategy: add CLI-level JSON parsing and verdict-line tests first.
  Then inline single-use wrappers or keep one shared encode helper only where
  it reduces duplication.
- Files likely affected:
  `Sources/open-lola/main.swift`;
  `Tests/OpenLolaCoreTests/MachineReadableSurfaceContractTests.swift`;
  command-specific tests for affected surfaces.
- Behavior affected: machine-readable surfaces are proven at the executable CLI
  boundary.
- Tests to add/update: command emits parseable JSON, missing `VERDICT:` is
  rejected where required, validator rejects false success, and router rejects
  unknown commands.
- Verification commands:
  `swift test --filter MachineReadableSurfaceContractTests`;
  `swift test --filter CLICommandInventoryTests`;
  `swift build --product open-lola`.
- Risk level: medium.
- Rollback strategy: revert wrapper inlining while keeping CLI behavior tests if
  they reveal a real contract.
- Definition of Done: wrapper deletion or inlining happens only after the same
  behavior is covered through executable CLI output.

### SRP-020

- Slice ID: `SRP-020`
- Title: Replace Metadata Marker Helpers With Metadata Behavior
- Findings addressed: `STC-MC-006`
- Problem: `ReportMetadataArtifact` marker/no-op helpers prove compile
  conformance but not decoded metadata semantics or validator output.
- Minimal fix strategy: remove or inline the no-op helper if no runtime
  consumer needs it; replace it with decoded metadata and validator-output
  assertions.
- Files likely affected:
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`;
  report metadata protocol code if no consumers remain.
- Behavior affected: report metadata tests become semantic rather than marker
  conformance checks.
- Tests to add/update: empty title, malformed capture time, missing notes, and
  validator output naming metadata problems.
- Verification commands:
  `swift test --filter ReportSchemaInventoryTests`;
  `swift test --filter MeasurementReportFixtureTests`.
- Risk level: low to medium.
- Rollback strategy: restore the helper if public protocol conformance is a
  required compatibility surface.
- Definition of Done: metadata tests fail on malformed or missing metadata, not
  only on missing marker conformance.

### SRP-021

- Slice ID: `SRP-021`
- Title: Register Semantic Scenario Helpers As Named Tests
- Findings addressed: `STC-TI-006`
- Problem: `semantic...TestsScenario` helper wrappers weaken reporting,
  filtering, and intent clarity even when helper assertions still run.
- Minimal fix strategy: convert risk-bearing helpers into individually named
  Swift tests without changing assertion logic.
- Files likely affected: Swift test files containing
  `semantic...TestsScenario` helpers.
- Behavior affected: no product behavior; test reporting and filtering improve.
- Tests to add/update: no new behavior assertions required, but every existing
  helper assertion must still run under a named test.
- Verification commands:
  `rg -n "semantic.*TestsScenario" Tests/OpenLolaCoreTests`;
  `swift test --no-parallel`.
- Risk level: low.
- Rollback strategy: revert test registration changes if discovery becomes
  noisy or unstable.
- Definition of Done: each risk-bearing scenario appears as a named test and no
  helper assertions are dropped.

### SRP-022

- Slice ID: `SRP-022`
- Title: Deduplicate CLI Command Inventory After Router Coverage
- Findings addressed: `STC-MC-002`
- Problem: command facts are duplicated between the executable CLI router and a
  static inventory, creating drift risk.
- Minimal fix strategy: prove advertised commands route through the executable
  CLI. Then derive inventory from the router or remove duplicated rows that
  have no active consumer.
- Files likely affected:
  `Sources/open-lola/main.swift`;
  `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`;
  `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift`;
  docs consuming the inventory if any.
- Behavior affected: advertised command inventory tracks executable routing.
- Tests to add/update: every advertised command routes, unknown commands fail,
  JSON commands emit parseable JSON, and verdict commands expose correct
  verdict lines.
- Verification commands:
  `swift test --filter CLICommandInventoryTests`;
  `swift test --filter MachineReadableSurfaceContractTests`;
  `swift build --product open-lola`;
  `bash scripts/verify-docs.sh`.
- Risk level: medium.
- Rollback strategy: restore the static inventory rows if a documented public
  machine-readable consumer requires them.
- Definition of Done: command availability has one active source of truth or a
  generated/derived inventory with executable router coverage.

### SRP-023

- Slice ID: `SRP-023`
- Title: Replace Report Schema Inventory Duplication With Validator Proof
- Findings addressed: `STC-MC-003`
- Problem: `ReportSchemaInventory` duplicates facts already present in report
  types, fixtures, validators, tests, and docs.
- Minimal fix strategy: audit current consumers of the inventory. Keep only a
  needed public manifest, and move coverage to fixture decode, validator, and
  false-PASS mutation tests.
- Files likely affected:
  `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`;
  `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`;
  fixture and validator tests.
- Behavior affected: schema trust moves from duplicated rows to decoded
  fixtures and validators.
- Tests to add/update: decode every report fixture, validate every fixture,
  mutate false `PASS`, and assert required schema fields.
- Verification commands:
  `swift test --filter ReportSchemaInventoryTests`;
  `swift test --filter MeasurementReportFixtureTests`;
  `swift test --filter VerdictValidationPolicyTests`.
- Risk level: medium.
- Rollback strategy: restore inventory rows if public report tooling depends on
  them; keep validator tests.
- Definition of Done: schema coverage would fail if fixtures or validators
  drift, regardless of static inventory row content.

### SRP-024

- Slice ID: `SRP-024`
- Title: Back Network Route Matrix Rows With Executable Behavior
- Findings addressed: `STC-MC-004`
- Problem: `NetworkRouteCommandMatrix` embeds static route/command crosswalks
  that can drift from executable route behavior.
- Minimal fix strategy: prove each retained row with route command tests. Remove
  or derive rows that only restate router facts and have no independent runtime
  policy.
- Files likely affected:
  `Sources/OpenLolaCore/Support/Inventories/NetworkRouteCommandMatrix.swift`;
  route command tests and docs that consume the matrix.
- Behavior affected: route docs/matrix output matches executable command
  behavior and verdict boundaries.
- Tests to add/update: command exists, accepts/ rejects required flags, emits
  expected report shape, and refuses false success for each retained route row.
- Verification commands:
  `swift test --filter NetworkRouteCommandMatrixTests`;
  `swift test --filter DirectPeerSessionCLITests`;
  `swift test --filter UdpPcmRouteReportTests`;
  `bash scripts/verify-docs.sh`.
- Risk level: medium to high.
- Rollback strategy: restore removed matrix rows if docs or release reports
  lose required public inventory output.
- Definition of Done: every retained network route row is either derived from
  executable routing or protected by a behavior test.

### SRP-025

- Slice ID: `SRP-025`
- Title: Back Video Control Degrade Matrix With Policy Tests
- Findings addressed: `STC-MC-004`
- Problem: `VideoControlDegradeMatrix` can encode release policy as static
  production rows rather than behavior-backed degrade-first tests.
- Minimal fix strategy: retain only rows that are active public policy and
  prove them with video/control degradation tests. Remove planning-only rows or
  move them to docs if they have no runtime consumer.
- Files likely affected:
  `Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift`;
  video/control report policy tests;
  docs if planning-only rows move.
- Behavior affected: video/control evidence policy is enforced by tests, not
  only by matrix rows.
- Tests to add/update: video missing/partial/degraded states, control degraded
  states, and false `PASS` rejection for each retained policy row.
- Verification commands:
  `swift test --filter VideoControlDegradeMatrixTests`;
  `swift test --filter IntegratedAvDegradeFirstTests`;
  `swift test --filter VideoTransportReportPolicyTests`;
  `bash scripts/verify-docs.sh`.
- Risk level: medium.
- Rollback strategy: restore static rows if public release reports depend on
  their shape; keep behavior tests.
- Definition of Done: each active degrade policy row has a behavior test that
  would fail if the policy drifted.

### SRP-026

- Slice ID: `SRP-026`
- Title: Classify Source Ownership Inventory As Contract Or Docs
- Findings addressed: `STC-MC-004`
- Problem: source ownership inventory appears to embed planning/release ledger
  data in production Swift, and related tests may assert file paths instead of
  behavior.
- Minimal fix strategy: `INVESTIGATION`: identify every current consumer and
  decide whether source ownership is an active release contract or docs-only
  planning data.
- Files likely affected:
  `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`;
  source ownership tests;
  docs if the inventory moves out of production.
- Behavior affected: none in the investigation slice.
- Tests to add/update: none for investigation. If retained as contract, add a
  test that proves release tooling consumes the ownership data. If moved to
  docs, update docs verification.
- Verification commands:
  `rg -n "SourceOwnershipInventory|source ownership|ownership inventory" Sources Tests docs scripts`;
  `swift test --filter SourceOwnershipInventoryTests`;
  `bash scripts/verify-docs.sh`.
- Risk level: low to medium.
- Rollback strategy: no runtime rollback for investigation; restore production
  inventory if follow-up movement breaks release tooling.
- Definition of Done: the inventory has one assigned role: active release
  contract with behavior coverage, or docs-only data outside production code.

### SRP-027

- Slice ID: `SRP-027`
- Title: Audit External Connector NMP Active Use Before Simplifying
- Findings addressed: `STC-MC-007`
- Problem: the NMP plan/preflight/endpoint/workflow stack looks broad, but the
  audit found docs and tests referencing it as active.
- Minimal fix strategy: `INVESTIGATION`: inventory CLI, app, docs, tests,
  reports, and external compatibility consumers before deleting or narrowing
  any NMP options.
- Files likely affected: external connector NMP source files, connector tests,
  docs, CLI/app callers if active use is found.
- Behavior affected: none in the investigation slice.
- Tests to add/update: none for investigation. Any follow-up implementation
  must keep or add focused external connector tests for each retained option.
- Verification commands:
  `rg -n "NMP|nmp|ExternalConnectorNmp|external connector" Sources Tests docs scripts linux_connector`;
  `swift test --filter ExternalConnector`;
  `bash scripts/verify-docs.sh`.
- Risk level: medium for follow-up deletion; low for investigation.
- Rollback strategy: discard the use inventory if stale; no runtime rollback
  needed.
- Definition of Done: every NMP option is classified as active runtime,
  active public contract, test-only, docs-only, or unused, with evidence.

### SRP-028

- Slice ID: `SRP-028`
- Title: Audit Python Raw Ethernet Public Export Before Simplifying
- Findings addressed: `STC-MC-008`
- Problem: raw Ethernet helpers appear outside normal UDP runtime use, but
  public Python exports may have downstream users.
- Minimal fix strategy: `INVESTIGATION`: audit internal source, tests, docs,
  scripts, and package exports. Only remove or privatize helpers after active
  use is disproven.
- Files likely affected:
  `linux_connector/lola_connector/ethernet.py`;
  `linux_connector/lola_connector/__init__.py`;
  Python tests and docs.
- Behavior affected: none in the investigation slice.
- Tests to add/update: none for investigation. If helpers remain public, add
  focused tests for the retained API. If removed, add import/export regression
  tests for the supported public surface.
- Verification commands:
  `rg -n "ethernet|RawEthernet|lola_connector\\.ethernet|from linux_connector\\.lola_connector import" linux_connector docs scripts Tests Sources`;
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`;
  `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`.
- Risk level: medium for follow-up API removal; low for investigation.
- Rollback strategy: restore public exports if downstream or documented use is
  found after removal.
- Definition of Done: raw Ethernet helpers are classified as active public API,
  internal test helper, docs-only artifact, or unused with evidence.

### SRP-029

- Slice ID: `SRP-029`
- Title: Re-Scope Line-Budget Gate Without Losing Policy
- Findings addressed: `STC-MC-009`
- Problem: `CodeLineBudgetTests` may be an intentional hygiene gate, but as a
  Swift unit test it fails on file size rather than runtime behavior.
- Minimal fix strategy: `INVESTIGATION` first: confirm whether line-budget
  enforcement belongs in Swift tests or docs/hygiene verification. Then either
  narrow the Swift test to owned source files or move the policy to a dedicated
  script while preserving stale-exception detection.
- Files likely affected:
  `Tests/OpenLolaCoreTests/CodeLineBudgetTests.swift`;
  verification scripts and docs if the gate moves.
- Behavior affected: no product runtime behavior; verification failure surface
  may change.
- Tests to add/update: stale exception detection, oversized owned-source
  detection, and behavior tests for any oversized high-risk files named by the
  gate.
- Verification commands:
  `swift test --filter CodeLineBudgetTests`;
  `bash scripts/verify-docs.sh`;
  replacement hygiene command if the gate moves.
- Risk level: low to medium.
- Rollback strategy: restore the current Swift test if the replacement gate is
  less visible or misses stale exceptions.
- Definition of Done: line-budget policy remains enforced, but behavior test
  results are not the only signal for broad repository size hygiene.

## Recommended Execution Order

1. `SRP-001`, `SRP-002`, `SRP-003`, `SRP-004`: fix highest-risk false-success
   paths first.
2. `SRP-005`, `SRP-006`, `SRP-007`: make important missing/broken behavior
   tests fail when success is false.
3. `SRP-008`: map the app controller before any broad extraction.
4. `SRP-009` through `SRP-016`: close remaining false-success and skipped
   coverage gaps in NAT, Python connector, app UI actions, process cleanup,
   video capture, packaging, and Python loopback tests.
5. `SRP-017` through `SRP-021`: replace weak tests and single-use/no-op test
   helpers after behavior coverage exists.
6. `SRP-022` through `SRP-026`: deduplicate command, schema, route, video, and
   ownership inventories only after consumers and behavior tests are known.
7. `SRP-027`, `SRP-028`, `SRP-029`: run uncertain compatibility and policy
   investigations before any deletion or relocation.

## P0/P1 Slices

No P0 finding is present in the source audit.

P1 or P1-backed slices:

- `SRP-001`: Direct peer realtime graph cleanup failure reporting.
- `SRP-002`: audio loopback IOProc cleanup failure reporting.
- `SRP-003`: UDP PCM loopback receive-side completion.
- `SRP-004`: native app launch cannot PASS without required labels.
- `SRP-005`: Swift LoLa fallback tests cannot silently return green.
- `SRP-006`: rendered app UI runtime-state coverage.
- `SRP-007`: synthetic smoke false-PASS mutation coverage.
- `SRP-008`: AppExecutionController investigation before extraction.

## Low-Risk Quick Wins

These are low risk only when kept narrow and verified:

- `SRP-012`: pasteboard copy result checks.
- `SRP-017`: replace release-run count/literal checks with harness behavior.
- `SRP-020`: replace metadata marker helper with metadata behavior tests.
- `SRP-021`: register semantic scenario helpers as named tests.
- `SRP-026`: classify source ownership inventory before moving it.
- `SRP-029`: investigate line-budget gate placement before changing policy.

## Blocked Or Uncertain Items

- `SRP-008` is blocked on a current state-transition map before any app
  controller extraction.
- `SRP-018` is blocked on classifying literal-only tests so valuable public
  contract tests are not deleted.
- `SRP-026` is blocked on proving whether source ownership inventory is an
  active release contract or docs-only planning data.
- `SRP-027` is blocked on active-use evidence for external connector NMP.
- `SRP-028` is blocked on downstream/public-use evidence for raw Ethernet
  Python exports.
- `SRP-029` is blocked on deciding whether the line-budget policy belongs in
  Swift tests or a dedicated hygiene gate.

## Final Verification Plan

Per slice:

- Run the focused filter or command listed in that slice.
- Include a negative/failure test for any false-success fix before accepting
  the implementation.
- Do not delete or inline code until replacement behavior coverage exists, or
  until an investigation slice proves the surface is unused.

Broader gates by touched area:

- Swift source or shared report contract changes:
  `swift test --no-parallel`.
- Swift CLI changes:
  `swift build --product open-lola` and the focused CLI tests named in the
  slice.
- macOS app or script launch evidence changes:
  `swift test --filter AppShellBehaviorTests`,
  `swift test --filter AppBundleScriptSourcePolicyTests`,
  `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`,
  and `bash script/build_and_run.sh --verify` when local app-launch permissions
  allow it.
- Python connector changes:
  `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`,
  `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`, and
  `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`.
- Docs, inventory, or public command/report surface changes:
  `bash scripts/verify-docs.sh` and any relevant report validator tests.
- Release evidence changes:
  `bash scripts/verify-release-readiness.sh` and
  `bash scripts/verify-release-hygiene.sh`, with skipped hardware, signing,
  Accessibility, or manual gates reported explicitly.

Completion standard:

- A slice is complete only when its focused failure mode is reproduced by a
  test or deterministic probe, the minimal fix passes that check, and the
  broader gates relevant to touched files are run or explicitly reported as
  unavailable.
