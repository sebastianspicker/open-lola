# Simplicity Remediation Status

Date: 2026-05-17

Source of truth: `docs/simplicity-remediation-plan.md`

Overall state: COMPLETE

Current slice: None - all planned slices complete

Last slice: `SRP-029` - Re-Scope Line-Budget Gate Without Losing Policy

## Counts By Status

| Status | Count |
|---|---:|
| NOT_STARTED | 0 |
| IN_PROGRESS | 0 |
| BLOCKED | 0 |
| DEFERRED | 0 |
| IMPLEMENTED | 0 |
| VERIFIED | 0 |
| COMPLETE | 29 |

Highest remaining severity: None

Last commands/result:

- `git diff --check -- docs/external-connector-nmp-active-use-inventory.md docs/python-raw-ethernet-public-export-inventory.md docs/line-budget-gate-policy-inventory.md docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed after rewording the proposed future
  line-budget script path so the docs verifier did not treat it as an existing
  source path.
- `swift test --filter CodeLineBudgetTests`: built and ran, then failed as
  expected on the active line-budget gate:
  `DirectPeerRealtimeAudioGraph.swift` 879/720,
  `AppShellBehaviorTests.swift` 859/720,
  `VideoCaptureAVFoundation.swift` 745/720, and
  `AppExecutionController.swift` 735/720.
- `SRP-029` result: `docs/line-budget-gate-policy-inventory.md` classifies the
  line-budget rule as active hygiene, not behavior coverage. Preferred follow-up
  is a deterministic line-budget verifier wired into release hygiene/readiness
  before removing or narrowing the Swift test.
- `rg -n "ethernet|RawEthernet|lola_connector\\.ethernet|from linux_connector\\.lola_connector import" linux_connector docs scripts Tests Sources`:
  completed for `SRP-028`.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`:
  passed with 103 passed and 2 explicit loopback-alias skips; output included
  `loopback alias 127.0.0.2 is not available`.
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: passed.
- `SRP-028` result: `docs/python-raw-ethernet-public-export-inventory.md`
  classifies `ethernet.py` and its package exports as active public helper
  surface; normal runtime raw Ethernet use is inactive and raw socket
  send/receive API is not implemented.
- `rg -n "NMP|nmp|ExternalConnectorNmp|external connector" Sources Tests docs scripts linux_connector`:
  completed for `SRP-027`; output is noisy because it also matches generated
  fixture content.
- `swift test --filter ExternalConnector`: attempted twice and failed in
  different non-NMP concurrent process/socket fixtures: missing
  `jacktrip-primary.sh.log` in `ExternalConnectorProcessGroupTests`, then
  `bind 127.0.0.1:51001 errno 48` in `ExternalConnectorSessionTests`.
- `swift test --filter jackTripAudioVideoProcessRunReportsRealPrimaryAndAuxiliaryProcesses`:
  passed with 1 Swift Testing test.
- `swift test --no-parallel --filter ExternalConnector`: passed with 62 Swift
  Testing tests.
- `SRP-027` result: `docs/external-connector-nmp-active-use-inventory.md`
  classifies NMP as an active CLI/report verification surface and found no
  accepted NMP option that is safe to delete as unused.
- `rg -n "SourceOwnershipInventory|source ownership|ownership inventory" Sources Tests docs scripts`:
  completed for `SRP-026`.
- `swift test --filter SourceOwnershipInventoryTests`: passed with 4 Swift
  Testing tests.
- `swift test --filter MachineReadableSurfaceContractTests`: passed with 4
  Swift Testing tests.
- `git diff --check -- docs/source-ownership-inventory-classification.md docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `swift test --filter VideoControlDegradeMatrixTests`: passed with 5 Swift
  Testing tests.
- `swift test --filter IntegratedAvDegradeFirstTests`: passed with 3 Swift
  Testing tests.
- `swift test --filter VideoTransportReportPolicyTests`: passed with 1 Swift
  Testing test.
- `swift test --filter VideoCaptureReportTests`: passed with 7 Swift Testing
  tests.
- `swift test --filter BlackmagicReceiveRenderTests`: passed with 3 Swift
  Testing tests.
- `swift test --filter MultiVideoTransportTests`: passed with 4 Swift Testing
  tests.
- `swift test --filter OscCueReportTests`: passed with 6 Swift Testing tests.
- `swift test --filter LightingFixtureGateTests`: passed with 5 Swift Testing
  tests.
- `swift test --filter IntegratedProfileReportTests`: passed with 4 Swift
  Testing tests.
- `git diff --check -- Sources/OpenLolaCore/Support/Inventories/VideoControlDegradeMatrix.swift Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `swift test --filter NetworkRouteCommandMatrixTests`: passed with 6 Swift
  Testing tests.
- `swift test --filter DirectPeerSessionCLITests`: passed with 4 Swift Testing
  tests.
- `swift test --filter UdpPcmRouteReportTests`: passed with 5 Swift Testing
  tests.
- `swift test --filter ReportSchemaInventoryTests`: passed with 6 Swift
  Testing tests.
- `swift test --filter ReportFixtureValidationContractTests`: passed with 1
  Swift Testing test.
- `swift test --filter MeasurementReportFixtureTests`: passed with 2 Swift
  Testing tests.
- `swift test --filter VerdictValidationPolicyTests`: passed with 3 Swift
  Testing tests.
- `swift test --filter FixtureSmokeMatrixTests`: passed with 4 Swift Testing
  tests.
- `swift test --filter SourceNamingConventionTests`: passed with 1 Swift
  Testing test.
- `swift test --filter MachineReadableSurfaceContractTests`: passed with 4
  Swift Testing tests and exercised the executable `report-schema-inventory`
  JSON surface.
- `swift build --product open-lola`: failed in the sandbox at SwiftPM manifest
  planning with `sandbox-exec: sandbox_apply: Operation not permitted`;
  focused Swift tests compiled and linked the current `open-lola` executable.
- `rg -n "CLICommandCatalogFamily|CLICommandCatalogEntry" Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`:
  returned no references after `SRP-022`.
- `swift test --filter CLICommandInventoryTests`: passed with 4 Swift Testing
  tests.
- `swift test --filter MachineReadableSurfaceContractTests`: passed with 4
  Swift Testing tests.
- `swift test --filter NetworkRouteCommandMatrixTests`: passed with 3 Swift
  Testing tests.
- `swift test --filter VerificationToolingContractTests`: passed with 5 Swift
  Testing tests.
- `swift build --product open-lola`: failed in the sandbox at SwiftPM manifest
  planning with `sandbox-exec: sandbox_apply: Operation not permitted`;
  focused Swift tests compiled and linked the current `open-lola` executable.
- `git diff --check -- Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `rg -n "semantic.*TestsScenario" Tests/OpenLolaCoreTests`: returned no
  semantic dispatcher wrappers after `SRP-021`.
- `swift test --filter LoLaQuickConnectFallbackTests`: passed with 5 named
  Swift Testing tests; 4 socket-heavy tests were explicitly skipped because
  `127.0.0.2` is unavailable on this machine.
- `swift test --filter AppShellBehaviorTests`: passed with 8 named Swift
  Testing tests.
- `swift test --no-parallel`: built successfully and ran 641 Swift Testing
  tests, but failed with one `CodeLineBudgetTests` issue:
  `DirectPeerRealtimeAudioGraph.swift` 879/720,
  `AppShellBehaviorTests.swift` 859/720, `VideoCaptureAVFoundation.swift`
  745/720, and `AppExecutionController.swift` 735/720. No semantic-wrapper
  registration failures were reported; the line-budget gate remains tracked by
  later remediation.
- `git diff --check -- <SRP-021 test/doc files>`: passed.
- `bash scripts/verify-docs.sh`: passed.
- `rg -n "ReportMetadataArtifact|assertReportMetadataArtifact" Sources Tests`:
  returned no active marker protocol or no-op helper references after
  `SRP-020`.
- `swift test --filter ReportSchemaInventoryTests`: passed with 6 Swift Testing
  tests.
- `swift test --filter MeasurementReportFixtureTests`: passed with 2 Swift
  Testing tests.
- `swift test --filter FieldReadyRuntimeProofTests`: passed with 7 Swift
  Testing tests.
- `swift test --filter PackagingFieldTestTests`: passed with 5 Swift Testing
  tests.
- `swift test --filter HardwareValidationReportTests`: passed with 7 Swift
  Testing tests.
- `swift test --filter ReferenceRigReportTests`: passed with 4 Swift Testing
  tests.
- `swift test --filter OpenSourceReleaseReadinessTests`: passed with 1 Swift
  Testing test.
- `swift test --filter CurrentEvidenceStatusMatrixTests`: passed with 3 Swift
  Testing tests.
- `swift test --filter ValidationPrimitivesTests`: passed with 3 Swift Testing
  tests.
- `rg -n "OpenLolaCLI\\.[A-Za-z0-9]+(Data|JSONString)\\(" Sources Tests`:
  returned no wrapper call sites after `SRP-019`.
- `swift build --product open-lola`: failed in the sandbox at SwiftPM manifest
  planning with `sandbox-exec: sandbox_apply: Operation not permitted`; the
  unsandboxed rerun was not approved.
- `swift test --filter MachineReadableSurfaceContractTests`: passed with 4
  Swift Testing tests and compiled/linked the current `open-lola` executable
  used by the process-output probes.
- `swift test --filter CLICommandInventoryTests`: passed with 1 Swift Testing
  test.
- `swift test --filter SessionProtocolTests`: passed with 5 Swift Testing
  tests.
- `swift test --filter RealtimeAudioPathInventoryTests`: passed with 3 Swift
  Testing tests.
- `rg -n "contains\\(|hasPrefix\\(|hasSuffix\\(|count|isEmpty|exists|readFile" Tests/OpenLolaCoreTests`:
  completed for the `SRP-018` literal-only test inventory.
- `swift test --filter VerificationToolingContractTests`: passed with 1 Swift
  Testing test.
- `swift test --filter ReleaseArtifactHygieneContractTests`: passed with 5
  Swift Testing tests.
- `swift test --filter ReleaseRunConfigurationContractTests`: passed with 3
  Swift Testing tests.
- `swift test --filter OpenSourceReleaseReadinessTests`: passed.
- `git diff --check -- Tests/OpenLolaCoreTests/ReleaseRunConfigurationContractTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py -q -rs`:
  passed with 37 passed and 2 explicit alias skips; output included
  `loopback alias capability: loopback alias 127.0.0.2 is not available`.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector -q -rs`:
  passed with 103 passed and 2 explicit alias skips; output included
  `loopback alias capability: loopback alias 127.0.0.2 is not available`.
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: passed.
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  passed.
- `git diff --check -- linux_connector/lola_connector/selftest.py linux_connector/tests/conftest.py linux_connector/tests/test_process_runtime.py linux_connector/tests/test_codec.py docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `swift test --filter PackagingFieldTestTests`: passed.
- `swift test --filter ReleaseHardeningTests`: passed.
- `swift test --filter OpenSourceReleaseReadinessTests`: passed.
- `git diff --check -- Sources/OpenLolaCore/Release/PackagingFieldTestRun.swift Tests/OpenLolaCoreTests/PackagingFieldTestTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `swift test --filter VideoCaptureReportTests`: first run failed to compile
  because the injected extractor default referenced overloaded
  `rawFrameBytes`; rerun failed on a hardcoded FourCC label; after fixing both,
  the filter passed and passed again after the overflow-safe accounting guard.
- `swift test --filter DirectPeerSessionReportAVPassTests`: passed.
- `swift test --filter VideoTransportReportPolicyTests`: passed.
- `swift test --filter RecordingSessionLiveCaptureTests`: passed.
- `swift test --filter ReportFixtureValidationContractTests`: passed.
- `git diff --check -- Sources/OpenLolaCore/Video/VideoCaptureProbe.swift Sources/OpenLolaCore/Video/VideoCaptureRunner.swift Sources/OpenLolaCore/Video/VideoCaptureReport.swift Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift Tests/OpenLolaCoreTests/VideoCaptureReportTests.swift Tests/OpenLolaCoreTests/DirectPeerSessionReportAVPassTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.

- `swift test --filter AudioLoopbackRunTests`: first run failed on missing
  `CoreAudio` import in the new test helper; rerun passed after adding the
  import.
- `swift test --filter VerdictValidationPolicyTests`: passed.
- `swift test --filter UdpPcmLoopbackLatencyTests`: passed.
- `swift test --filter UdpPcmRouteReportTests`: passed.
- `swift test --filter UdpPcmPacketTests`: passed.
- `swift test --filter AppBundleScriptSourcePolicyTests`: passed.
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`:
  passed.
- `git diff --check -- script/build_and_run.sh Tests/OpenLolaCoreTests/AppBundleScriptSourcePolicyTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSmokes.swift Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift`:
  passed.
- `swift test --filter LoLaQuickConnectFallbackTests`: first run failed loudly
  because `127.0.0.2` is unavailable on this machine; after converting the
  alias-dependent scenario to Swift Testing `.enabled(if:)`, rerun passed with
  one skipped socket-heavy scenario and one passing alias-unavailable contract
  test.
- `swift test --filter LoLaCompatibilityMediaSessionTests`: passed.
- `git diff --check -- Tests/OpenLolaCoreTests/LoLaQuickConnectFallbackTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `swift test --filter AppShellBehaviorTests`: first run failed to compile on
  direct `NSAccessibilityElementProtocol` label access; second run failed
  because bare `NSHostingView` did not expose child accessibility labels; final
  run passed after switching to a hosted footer render smoke with status-title
  assertions.
- `swift test --filter NativeAppShellTests`: passed.
- `git diff --check -- Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `swift test --filter SyntheticSmokeReportContractTests`: initial run failed
  because the external connector synthetic report accepted top-level `PASS`
  while real-world verdict stayed partial; rerun passed after the validator fix.
- `swift test --filter VerdictValidationPolicyTests`: passed.
- `swift test --filter ExternalConnectorReportTests`: passed.
- `git diff --check -- Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `rg -n "AppExecutionController|ExecutionState|report|validation|artifact" Sources/open-lola-app Tests/OpenLolaCoreTests`:
  completed for the `SRP-008` responsibility/caller/test inventory.
- `swift test --filter AppShellBehaviorTests`: passed.
- `swift test --filter AppShellSlice05Tests`: passed.
- `swift test --filter NativeAppShellSurfaceActionTests`: passed.
- `bash scripts/verify-docs.sh`: passed.
- `swift test --filter ManagedProcessRunnerTests`: first run failed because
  the new close-warning tests used `/bin/true`, which is unavailable on this
  macOS environment; rerun passed after switching those fixtures to
  `/usr/bin/env true`.
- `swift test --filter ExternalConnectorProcessGroupTests`: passed.
- `git diff --check -- Sources/OpenLolaCore/Support/ManagedProcessRunner.swift Tests/OpenLolaCoreTests/ManagedProcessRunnerTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `rg -n "NSPasteboard\\.general\\.setString|setString\\([^\\n]+forType: \\.string\\)|clearContents\\(\\)" Sources/open-lola-app Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`:
  showed raw pasteboard writes are isolated to `AppPasteboard`.
- `swift test --filter AppShellSlice05Tests`: first run failed to compile
  because `copyReadableValueToPasteboard` needed `@MainActor`; rerun passed.
- `swift test --filter AppShellBehaviorTests`: passed.
- `git diff --check -- Sources/open-lola-app/AppPasteboard.swift Sources/open-lola-app/AppOperatorArtifactViews.swift Sources/open-lola-app/AppExecutionView.swift Sources/open-lola-app/AppPacketMonitorView.swift Sources/open-lola-app/AppShellSupportViews.swift Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `swift test --filter AppShellBehaviorTests`: first run failed because blocked
  validation retained stale `lastValidationExitCode == 0`; rerun passed after
  clearing validation state before executable verification.
- `swift test --filter NativeAppShellTests`: passed.
- `swift test --filter AppShellSlice05Tests`: passed.
- `git diff --check -- Sources/open-lola-app/AppExecutablePathResolver.swift Sources/open-lola-app/AppExecutionController.swift Sources/open-lola-app/AppExecutionView.swift Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `bash scripts/verify-docs.sh`: passed.
- `git diff --check -- docs/app-execution-controller-remediation-map.md docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md`:
  passed.
- `swift test --filter NatFriendlyRouteTests`: passed.
- `swift test --filter NetworkDiagnosticsTests`: passed.
- `swift test --filter NetworkRouteCommandMatrixTests`: passed.
- `git diff --check -- Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteReports.swift Sources/OpenLolaCore/Network/NAT/NatRendezvousRelayRunners.swift Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift docs/simplicity-remediation-ledger.md docs/simplicity-remediation-status.md docs/app-execution-controller-remediation-map.md`:
  passed.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py -q`:
  passed.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`:
  passed with 101 passed and 2 skipped.
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: passed.
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`:
  passed.
- `bash scripts/verify-docs.sh`: passed.

Current uncertainty:

- Many source and test files are already modified in the worktree. Each slice
  must inspect current diffs before editing and avoid reverting unrelated work.
- `docs/simplicity-remediation-plan.md` and source audit files are currently
  untracked in this checkout.
- Full `swift test --no-parallel` was run for `SRP-021` and remains red only
  because `CodeLineBudgetTests` reports files over the current line budget; no
  semantic-wrapper registration failure was reported. Full
  `bash scripts/verify-release-readiness.sh`, real Core Audio hardware cleanup,
  real GUI launch/accessibility capture, alias-dependent LoLa fallback socket
  flow, and two-host/network hardware smoke were not run after the first six
  slices; targeted behavior was verified with injected cleanup failures,
  localhost UDP loopback tests, a fake-tool app launch evidence harness, and an
  always-run alias-unavailable contract test. SRP-006 used an in-process
  hosted SwiftUI footer smoke, not a real launched app window inspection.
  SRP-007 added top-level false-`PASS` mutation coverage; measured-mode and
  evidence-boundary-specific mutations remain report-specific follow-up work.
- `SRP-008` was investigation-only. It identified validation-evidence loading
  and verdict projection as the smallest follow-up extraction target, with a
  required pre-extraction stale-evidence mode-switch test.
- `SRP-009` added `skippedDatagrams` accounting to NAT rendezvous and relay
  reports. Older report JSON without the new field decodes with zero counts.
  Broad `swift test --no-parallel` was not run for this slice.
- `SRP-010` added QuickConn receive reasons and counts for injected malformed,
  wrong-peer, and timeout paths. Real peer QuickConn handshakes were not run.
- `SRP-011` added typed executable path resolution and command/start validation
  gates. Real bundled app sibling resolution was not exercised by launching a
  packaged app; verified path behavior used a temporary executable.
- `SRP-012` added a checked pasteboard write boundary. Direct button/UI clicking
  was not exercised; pasteboard failure was verified through the injected
  writer and shared status formatter.
- `SRP-013` added `ManagedProcessTerminationResult.cleanupWarnings` for
  SIGKILL and stdout/stderr close failures. App termination-handler call sites
  still ignore direct `closeOutputHandles()` return values unless separately
  wired.
- `SRP-022` deliberately did not rewrite Core inventory generation to import
  executable command closures; that would cross target boundaries. It instead
  added deterministic router-source coverage and removed the local one-off
  catalog wrapper layer.
- `SRP-014` added raw AVFoundation extraction accounting and video-capture
  `PASS` raw-evidence validation. Real AVFoundation camera hardware was not
  exercised; raw success/failure paths were verified with injected sample
  buffers and extractor failures.
- `SRP-015` records the first fail-fast packaging pass-candidate validation
  blocker in generated notes. The generated local ad-hoc package still remains
  intentionally partial without Developer ID signing, notarization, Gatekeeper,
  and clean-Mac evidence.
- `SRP-016` made missing `127.0.0.2` visible in pytest output, but this machine
  still skipped the socket-heavy bidirectional and control-handshake self-tests;
  socket-free parser/state tests covered timeout, malformed, wrong-peer, and
  unexpected control paths.
- `SRP-017` replaced docs/count/literal checks with representative release
  harness behavior. Malformed report-input coverage uses the recording runner
  file-read path; other harness-specific malformed-input paths remain covered by
  their own suites or future slices.
- `SRP-018` was investigation-only. The inventory classifies literal-heavy tests
  as public contract, behavior proxy, replace-with-behavior, or removable
  trivia. Follow-up replacement work remains intentionally split across later
  slices so valuable public-contract assertions are not deleted before behavior
  coverage exists.
- `SRP-019` removed the forwarding `OpenLolaCLI.*Data()` and `*JSONString()`
  wrappers and moved machine-readable surface coverage to executable CLI output.
  Standalone `swift build --product open-lola` could not be completed under the
  sandbox, but the focused Swift test build compiled and linked `open-lola`
  before running the executable probes.
- `SRP-020` removed the no-op `ReportMetadataArtifact` marker surface and added
  real metadata behavior coverage. Former metadata reports now validate
  ISO-8601 `capturedAt`; tests decode representative metadata, reject empty
  title, malformed capture time, and missing notes, and assert validator output
  can include metadata lines.
- `SRP-025` retained all video/control degrade matrix rows because each row
  mapped to active source, command, docs, and named behavior tests. The new
  proof reads behavior test source to bind rows to policy tests, while real
  hardware evidence for Blackmagic, ATEM, lighting, and multi-host routes was
  not executed.
- `SRP-026` classified `SourceOwnershipInventory` as an active release
  contract because it has a CLI command, release-readiness probe, executable
  JSON coverage, and full `Sources/` coverage tests. Planning fields remain
  candidates for a later field-splitting implementation slice.
- `SRP-027` classified the external connector NMP stack as an active CLI/report
  verification surface. No accepted NMP option was classified unused; direct
  NMP-specific coverage should be added before narrowing remote-only, media
  alias, TCP control, or standalone endpoint preflight behavior.
- `SRP-028` classified the Python raw Ethernet builder and package exports as
  active public helper surface for optional exact outer-header fallback work,
  while confirming normal runtime raw Ethernet use is inactive and raw socket
  send/receive APIs are not implemented.
- `SRP-029` classified the line-budget rule as active hygiene, not behavior
  coverage. The current Swift test still enforces the policy and remains red on
  four oversized files; the preferred follow-up is to move repository-wide
  scanning to a deterministic release hygiene/readiness verifier before
  removing or narrowing the Swift test.

Next slice:

- None. All planned remediation slices are complete.
