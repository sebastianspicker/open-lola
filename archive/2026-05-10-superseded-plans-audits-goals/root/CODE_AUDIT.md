# Code Audit Report — open-lola2

**Date**: 2026-05-09  
**Auditor**: GitHub Copilot (fleet of 5 parallel explore agents)  
**Scope**: Full codebase — Swift (OpenLolaCore, open-lola-app, open-lola), Python (linux_connector), Bash scripts, CI/CD, test coverage  

This file preserves the original audit text for traceability. Current status is
defined by the remediation and completion-audit tables below; some original
finding sections intentionally still contain historical wording such as
"zero tests" or "no tests" after later re-triage disproved or narrowed those
claims against the live tree.

| Surface | Files |
|---|---|
| Sources/OpenLolaCore | 228 Swift files |
| Sources/open-lola-app + open-lola | 42 Swift files |
| Tests/OpenLolaCoreTests | 120 Swift files |
| linux_connector | 13 Python files |
| scripts/ | 19 Bash scripts |

---

## Severity Legend

| Level | Meaning |
|---|---|
| 🔴 CRITICAL | Data corruption, crash, or security breach likely |
| 🟠 HIGH | Correctness bug, security risk, or resource leak under realistic conditions |
| 🟡 MEDIUM | Fragile code, silent failure, or maintainability hazard |
| 🔵 LOW | Style, minor inefficiency, or informational |

---

## Original Finding Summary

| # | Severity | Layer | File / Module | Issue |
|---|---|---|---|---|
| 1 | 🔴 CRITICAL | Swift Core | `UdpMediaTransport.swift` | Data race on `@unchecked Sendable` mutable state |
| 2 | 🔴 CRITICAL | Tests | Benchmarks / Integration / Platform / Support / Timing | 45 source files with zero tests |
| 3 | 🔴 CRITICAL | Tests | Connectors | JackTrip & UltraGrid connectors have zero unit tests |
| 4 | 🟠 HIGH | Swift Core | `VideoCaptureAVFoundation.swift` | Indefinite blocking semaphore wait on async callback |
| 5 | 🟠 HIGH | Swift App | `AppExecutionController.swift` | Hardcoded `/tmp/` paths (world-writable, macOS security) |
| 6 | 🟠 HIGH | Swift App | `AppExecutionController.swift` | Missing `[weak self]` in `runOneShot` closure |
| 7 | 🟠 HIGH | Python | `backends.py` | Subprocess stdout/stdin writes lack error handling |
| 8 | 🟠 HIGH | Python | `backends.py` | Process not cleaned up on exception |
| 9 | 🟠 HIGH | Python | `media.py` | Fragment validation logic incomplete (silent data loss) |
| 10 | 🟠 HIGH | Python | `protocol.py` | Invalid numeric input silently converted to `0` |
| 11 | 🟠 HIGH | Python | `selftest.py` | Port offset arithmetic can overflow valid port range |
| 12 | 🟠 HIGH | Scripts | `export-release-candidate.sh` | Release artifacts default to world-writable `/tmp` |
| 13 | 🟠 HIGH | Scripts | `run-local-ultragrid-rxtx-*.sh` | Race condition: RX readiness checked before process starts |
| 14 | 🟠 HIGH | Tests | Network module | Only ~7% coverage; no tests for malformed packets, timeouts |
| 15 | 🟠 HIGH | Tests | All | 626+ "validate()-only" tests with no property assertions |

---

## Remediation Progress — 2026-05-09

Scope of this pass: close the highest-risk concrete defects that were still
present in the live tree, add focused regression coverage where the code path
is testable without real hardware, and keep broad coverage/architecture backlog
items open instead of pretending synthetic tests prove field readiness.

| Audit item | Status | Evidence |
|---|---|---|
| 1.1 `UdpMediaTransport` data race | Fixed | `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift` now protects metrics, sequence tracking, jitter state, and close state with `NSLock`; focused `swift test --filter UdpMediaTransportTests` passed with 11 tests. |
| 1.2 AVFoundation permission wait can hang | Fixed | `resolveAVFoundationVideoPermission()` now uses a five-second semaphore timeout and returns `.unknown` instead of blocking forever. |
| 1.3 lock sites without `defer` | Fixed | Added `defer` unlock guards in the audited live LoLa payload collectors, NMP endpoint result store, UDP PCM route result box, and NAT smoke result box. A follow-up scan found remaining non-defer lock usage only in test/support-style code that does not match the original production lock-site list. |
| 2.1 hardcoded app `/tmp` logs | Fixed | `AppExecutionController` now defaults execution logs to the user cache directory under the bundle identifier, with `/tmp` only as the Foundation-provided fallback if caches lookup fails. |
| 2.2 `runOneShot` strong capture | Fixed | `runOneShot` termination handler now captures `[weak self]`. |
| 3.1 subprocess playback write handling | Fixed + tested | `ProcessAudioPlayback.write_block()` now wraps `stdin.write()`/`drain()` failures, closes the process, and raises `RuntimeError`; `python -m pytest linux_connector/tests/test_codec.py` passed with 19 passed, 2 skipped. |
| 3.2 subprocess capture cleanup | Fixed | `ProcessAudioCapture.start()` now kills and awaits a child if post-spawn setup fails. |
| 3.3 fragment validation diagnostics | Fixed + tested | `MediaReassembler.add()` now logs out-of-range and duplicate fragments without mutating state; regression tests cover both cases. |
| 3.4 invalid numeric media fields | Fixed + tested | `MediaSettings.from_fields()` now raises `ValueError` for malformed numeric fields instead of coercing to `0`. |
| 3.5 self-test port overflow | Fixed + tested | Both self-test paths now share `default_port_offset()` with a bounded offset that keeps the default video port below the IANA ephemeral range. |
| 3.7 event-loop CPU spin | Fixed + tested | `_wait_until()` now yields during the final sub-millisecond wait instead of busy-spinning the asyncio loop. |
| 3.8 runtime `assert` validation | Fixed + tested | `_video_tx_loop()` now raises `RuntimeError` if called without a video capture backend, so optimized Python cannot remove the guard. |
| 3.9 ASCII decode drops data | Fixed + tested | ASCII control and OSC string parsing now use strict decode and reject non-ASCII datagrams instead of silently dropping bytes. |
| 3.10 `self.session` TOCTOU snapshots | Fixed | Runtime and connector send/receive loops now snapshot `self.session` before comparing peer IPs or sending media packets. |
| 4.1/4.3 UltraGrid RX startup race/PID check | Fixed | Docker and native RX/TX scripts now validate the RX PID with `kill -0` and pause briefly before readiness polling; `shellcheck` passed for touched scripts. |
| 4.2 release export `/tmp` default | Fixed + tested | `scripts/export-release-candidate.sh` now requires an explicit output parent; release hygiene contract test passed. |
| 4.7 CI workflow shell | Fixed + tested | `.github/workflows/release-readiness.yml` now sets `defaults.run.shell: bash`; verification tooling contract test passed. |
| Release verifier parallel Swift test flake | Fixed + tested | `scripts/verify-release-readiness.sh` now uses `swift test --no-parallel`, matching the socket-heavy test runbook; full release-readiness verifier passed with `VERDICT: PASS`. |

Verification commands run in this pass:

```bash
python -m pytest linux_connector/tests/test_codec.py
swift test --filter UdpMediaTransportTests
shellcheck scripts/export-release-candidate.sh scripts/run-local-ultragrid-rxtx-docker.sh scripts/run-local-ultragrid-rxtx-native.sh
swift test --filter ReleaseArtifactHygieneContractTests
swift test --filter VerificationToolingContractTests
ruff check linux_connector/lola_connector linux_connector/tests/test_codec.py
swift test --no-parallel
bash scripts/verify-docs.sh
bash scripts/verify-release-readiness.sh
```

## Remediation Progress — 2026-05-09 Follow-up

This follow-up exists because the previous closure status was too broad. The
project must not be reported as complete while Run 1 concrete defects, Run 2
dedup/refactor work, or field-evidence gates remain open.

| Audit item | Status | Evidence |
|---|---|---|
| 1.4 Raw BGRA preview `@unchecked Sendable` | Fixed | `RawBGRAAppKitPreviewWindow` now holds immutable outer state and isolates mutable `NSWindow` / `NSImageView` fields in a `@MainActor` state object; `swift test --filter DebugTraceTests` compiled the touched target. |
| 1.5 silent `try?` drops | Fixed for audited sites | `DebugTrace.jsonLines()` emits an explicit encoding-failure line instead of dropping events; LoLa MJPEG capture records `.jpegEncodingFailed`; UDP PCM loopback records decode errors in `DebugTrace`. |
| 1.6 per-call `ISO8601DateFormatter` in `DebugTrace` | Fixed | `DebugTrace` now uses a reusable `Date.ISO8601FormatStyle`, avoiding a non-`Sendable` shared formatter while removing per-event formatter construction. |
| 2.3 `@State` reference controller | Disproved against current SwiftUI Observation model | `AppExecutionController` is an `@Observable @MainActor` reference type. In the current Observation API, `@State` is the supported owner for observable reference state; converting to `@StateObject` would be wrong without `ObservableObject`. |
| 2.4 silent validator command failure | Fixed | `finishReport()` now catches `validatorArguments()` errors and surfaces `lastError` instead of silently using an empty array. |
| 2.5 meter timer lifecycle | Fixed | `AppChannelMeterView` replaced the inline autoconnect timer with a cancellable `Task` that is stopped on disappear. |
| 2.6 app storage key sprawl / missing positive validation | Fixed + tested | Added `AppStorageKeys`, routed stored defaults through those keys, and added `NativeAppShellDirectPeerCommandFields.validateAppSettings()` for non-empty text fields, positive numeric command settings, non-zero ports, and duplicate-port rejection. `NativeAppShellTests` and `AppShell` passed. |
| 2.7 CLI `exit(EXIT_FAILURE)` | Fixed for top-level failure path | `Sources/open-lola/main.swift` now lets top-level `try` propagate command errors instead of explicitly calling `exit(EXIT_FAILURE)`. |
| 3.6 per-packet media sockets | Fixed + tested | `LolaConnector` now reuses persistent audio/video send sockets per session and closes them on disconnect; `test_connector_reuses_media_send_sockets` covers reuse. |
| 3.11 Python type hints | Fixed + tested | Added the missing runtime/socket/OSC typing needed for strict checking. `python3 -m mypy --strict linux_connector/lola_connector`, `ruff check linux_connector`, and `python3 -m pytest linux_connector/tests` pass. |
| 4.4 JackTrip timestamp parsing diagnostics | Fixed | `compare-local-jacktrip-parity-docker.sh` now fails with explicit direct/managed timestamp parse messages. |
| 4.5 UltraGrid heredoc interpolation | Already fixed in live tree | `compare-local-ultragrid-parity-native.sh` already uses quoted heredocs and passes shell values as Python argv. |
| 4.6 JackTrip array bounds | Fixed | `open-lola-jacktrip-docker-client.sh` now fails if `-B`/`-P` lacks a port argument. |
| 4.8 hardcoded parity `/private/tmp` defaults | Fixed beyond the named script | JackTrip/UltraGrid parity and local run scripts now default to `${OPEN_LOLA_OUTPUT_DIR:-${TMPDIR:-/tmp}/...}` instead of `/private/tmp`. |
| 5.1 module zero-test claim | Disproved against current tree | Benchmarks, Integration, Platform, Support, and Timing all have live tests including `E2EBenchmarkReportTests`, `IntegratedAvReportTests`, `NativeAppShellTests`, `SPSCAtomicRingTests`, `RxBufferingTests`, `DriftPlc*Tests`, and `LatencyTuningReportTests`. |
| 5.2 JackTrip/UltraGrid zero-test claim | Disproved against current tree | External connector tests now cover JackTrip and UltraGrid launch/session/planning paths: `ExternalConnectorAvMatrixTests`, `ExternalConnectorConnectionPlanTests`, `ExternalConnectorExecutablePreflightTests`, and `ExternalConnectorSessionTests`. |
| 5.4 Network malformed/timeout coverage claim | Disproved as absolute, still expandable | Swift and Python tests cover malformed fragments, duplicates, timeouts, UDP packet validation, NAT route reports, and LoLa media session timeout failures; additional coverage depth remains useful but the "no tests" claim is stale. |
| 5.5 helper-only test files | Fixed + tested | Helper-only Swift files in `Tests/OpenLolaCoreTests/` now use the `+TestSupport.swift` suffix, and active source inventories point to the renamed fixture-support files. Focused inventory and fixture-matrix tests passed. |
| 5.6 Release verdict logic under-test claim | Disproved as absolute, still expandable | Release tests include `ReleaseArtifactHygieneContractTests`, `ReleaseHardeningTests`, `PackagingFieldTestTests`, `FieldReadyRuntimeProofTests`, and `OpenSourceReleaseReadinessTests` with PASS/PARTIAL/invalid-pass assertions. |
| 5.7 validate-only assertion sweep | Fixed + tested against current tree | Re-triaged all `Tests/OpenLolaCoreTests/*.swift` test functions with report `.validate(...)` calls. The stale "626+" count is no longer true in the live tree; the only assertion-free validate test was `directPeerSessionAVPassAcceptsBGRAPixelFormatAlias`, which now asserts the accepted alias fields after validation. Added `ValidateAssertionContractTests` to fail on future validate-bearing tests without `#expect`, `#require`, `withKnownIssue`, or `confirmation`. Focused DirectPeer and contract tests passed; the current inventory reports 613 validate-bearing tests and 0 assertion-free offenders. |
| 6 message size upper bound | Fixed + tested | `parse_control_datagram()` rejects control datagrams larger than `CONTROL_DATAGRAM_SIZE`; Python test coverage added. |
| 6 subprocess command validation | Re-scoped | The CLI flags intentionally accept explicit operator-supplied subprocess commands. Current mitigation is command splitting without shell execution in backend launch paths; this is not shell injection unless callers pass untrusted command strings as policy. |
| 7 dead-code/slop findings | Fixed/re-scoped + tested | Re-triage found the app transport binding covered by `NativeAppShellTests`, `ProcessJpegVideoCapture` buffer trimming covered by codec tests, Ethernet byte-length checks still needed for raw `bytes` callers, `verify-docs.sh` using `python3 -m scripts.verify_docs`, and NAT result capture already idiomatic enough after defer-lock cleanup. `ruff`, Python tests, Swift app/native-shell tests, docs verification, and release-readiness checks cover the affected surfaces. |
| 9.1 duplicated Swift argument helpers | Fixed + tested | Added shared `CommandLineArguments` support and routed audio loopback, UDP route, and NAT route required/optional integer/string/bool parsing through it; focused audio loopback, UDP route, and NAT tests passed. |
| 9.2 boilerplate initializers | Re-scoped + safe cleanup tested | The named examples are public structs whose explicit public initializers preserve external construction; deleting them would make the memberwise initializers internal. Removed a safe internal initializer from `VideoTransportStreamRunState` by using stored-property defaults; video transport tests passed with 48 tests. |
| 9.3 LoLa control-exchange function split | Fixed + tested | UDP TX control exchange now uses `LoLaExchangeState` plus named status, quick-connect, receive, parse, and validation helpers split into `LoLaControlExchangeOutgoing.swift`; LoLa control/session tests passed with 43 tests and the LOC budget test passed. |
| 9.4 direct peer AV runner split | Fixed + tested | `runManualAddressAudioVideo` now delegates report construction to `buildAVReport(...)` in `DirectPeerSessionAVReportBuilder.swift`; validation was already separated in the live tree. Direct peer AV/runner tests passed with 60 tests and the LOC budget test passed. |
| 10.1 app device card duplication | Fixed | Audio/video cards now share `AppSelectableDeviceCard`. |
| 10.2 preview binding duplication | Fixed | Preview bindings were extracted to `AppPreviewBindings.swift` and reused by settings and receiver views. |
| 10.3 local device selection duplication | Fixed | Audio input, audio output, and video selection sections were extracted in `AppLocalOperatorSurfaceView`. |
| 10.4 app storage string keys | Fixed | Raw `@AppStorage` key literals were moved to `AppStorageKeys`. |
| 10.5/10.6 UI magic constants | Fixed + tested | Latency thresholds, channel-meter constants, topology flow layout/animation constants, packet monitor column widths, and session banner animation/layout constants are centralized in local enums; `AppShell` and `NativeAppShellTests` passed. |
| 10.7 legacy console design aliases | Fixed + tested | Removed `fixedSidebarWidth`, `operatorConsoleBackground`, `operatorConsolePanel`, and `operatorConsoleBorder`; console chrome now uses `AppWindowSize.sidebarWidth`, `appBackground`, `panelBackground`, and `panelBorder` directly. `AppShell` and `NativeAppShellTests` passed. |
| 10.8 settings view body size | Fixed + tested | `AppShellSettingsView.body` now composes dedicated settings tab views for execution, peers, audio, video, preview, and snapshot sections; `NativeAppShellTests` and `AppShell` passed. |
| 11.1 subprocess `aclose()` duplication | Fixed + tested | `ProcessLifecycleMixin` now owns terminate/kill/wait cleanup for process-backed media classes. |
| 11.2 connector UDP socket cleanup duplication | Fixed + tested | `LolaConnector.udp_socket()` now owns socket close semantics for control and receive sockets; connector tests and ruff passed. |
| 11.3 duplicated `_message_ip()` | Fixed | Shared `message_ip()` moved to `protocol.py` and is used by connector/runtime. |
| 11.4 duplicated handshake receive loops | Fixed + tested | `LolaConnector._receive_control_until()` now owns UDP control receive, timeout, parse, and handler dispatch mechanics for `initiate()`, `check_status()`, and `accept_once()`; ruff and the Python connector/selftest suite passed. |
| 11.5 duplicated `--test-media` args | Fixed | `add_test_media_args()` now configures both `listen` and `connect`. |
| 11.6 connector/runtime relay logging | Fixed where production-facing | Connector receive/handshake diagnostics and Npcap relay status now use `logging`; CLI self-test/status prints remain intentional user-facing command output. |
| 12.1 duplicated shell helper functions | Fixed + tested | Added `scripts/lib/common.sh` and sourced it from the three live scripts that still defined `fail()`, `require_file()`, or `require_file_contains()`; `rg` now finds those helpers only in the shared library. The release verifier now shellchecks `scripts/lib/*.sh` too. |
| 12.2 duplicated release verifier goal probes | Fixed + tested | `verify-release-readiness.sh` now uses shared verdict/line assertions and a generic `run_goal_report_probe()` for the repeated goal report/run/validate flow; the verifier contract test and full release-readiness script passed. |
| 12.3 parity script common core | Fixed + tested | Added `scripts/lib/parity.sh` for shared parity timing, text assertions, log waiting, Docker log capture/stop helpers, and JackTrip connection-delay comparison. Extracted the duplicated UltraGrid parity metric parser/report writer to `scripts/lib/write-ultragrid-parity-metrics.py` and routed Docker/native comparators through it. Shellcheck, helper `py_compile`, and `VerificationToolingContractTests` passed. |
| 12.4 inline Python in native UltraGrid RX/TX script | Fixed + tested | Extracted native UltraGrid preflight executable selection and connection-metrics JSON writing into `scripts/lib/extract-preflight-executable.py` and `scripts/lib/write-connection-metrics.py`; helper py_compile, direct synthetic behavior probe, shellcheck, and `VerificationToolingContractTests` passed. |
| 13.1 duplicated validation primitives | Fixed + tested | Added `Sources/OpenLolaCore/Core/ValidationPrimitives.swift` and routed the repeated Release/Evidence/Control empty, positive, non-negative, and finite validation wrappers through it while preserving domain-specific error enums. The broad touched report-family filter passed with 220 tests, and `SourceOwnershipInventoryTests` passed with 7 tests. |
| 13.2 shared report structure | Fixed/re-scoped + tested | Added `ReportMetadataArtifact` for the shared `id`, `title`, `capturedAt`, `verdict`, and `notes` surface across the named release/evidence reports. The existing concrete `MeasurementReport` type keeps its public name, and domain-specific validation stays in each report. `ReportSchemaInventoryTests` includes a compile-time conformance check for the five named report types. |
| 13.3 duplicated placeholder detection | Fixed + tested | Added shared `PlaceholderDetection` support and routed the repeated placeholder predicates through it while preserving each report's sentinel vocabulary; the affected Swift report/validation test filter passed with 352 tests. |
| 13.4 marker protocol cleanup | Fixed + tested | Added `JSONReportCoder` and made `PrettyJSONCodable` declare its decode/pretty-JSON behavior as an explicit protocol contract instead of an empty marker. `ReportValidatingArtifact` is no longer marker-only in the live tree because it requires `id`, `verdict`, `decode`, and `validate`; `ReportSchemaInventoryTests` passed with 11 tests. |
| 13.5/13.9 pass-verdict policy and naming schema | Fixed/re-scoped + tested | Added `VerdictValidationPolicy` with explicit `validatePass`, `passRequires`, and `passForbids` semantics, then routed `OpenSourceReleaseReadinessReport`, `GoalCompletionAuditReport`, `ReleaseHardeningReport`, `LoLaParityDeferredLedgerReport`, `FieldReadyRuntimeProofReport`, `FasterThanLoLaClosureReport`, `ReferenceRigReport`, `HardwareValidationReport`, `PackagingFieldTestReport`, and `RecordingSessionArtifactReport` pass-gate entry points through it without renaming public error cases. The policy now owns the named HardwareValidation 30-minute and Faster-than-LoLa 60-minute pass-duration thresholds plus an `InvalidPassValidationRule` taxonomy that classifies all Evidence/Release `pass*` domain error cases as `requires` or `forbids`. Public domain error names are preserved for compatibility; `VerdictValidationPolicyTests` passed with the source contract. |
| 13.6 single-user RunConfiguration types | Re-scoped + tested | The four named release run configurations are retained as public CLI/programmatic runner input contracts rather than collapsed into runner methods. Added source documentation for that intent and `ReleaseRunConfigurationContractTests`; the focused test passed. |
| 13.7 Release `RunConfiguration.parse()` duplication | Fixed + tested | Release-layer run configuration parsers now delegate option scanning, unknown/duplicate/missing-value handling, and simple required-string extraction to `CommandLineArguments`; targeted Release parser/runner tests passed and `rg` found no remaining hand-rolled parse loops under `Sources/OpenLolaCore/Release`. |
| 13.8 measurement-mode naming | Fixed/re-scoped + tested | Added shared `MeasurementMethodology` and aliased the Evidence/Release synthetic/measured run-mode names (`HardwareValidationRunMode`, `ReleaseHardeningRunMode`, `FieldReadyRuntimeRunMode`, `PackagingFieldTestRunMode`, `RecordingSessionRunMode`, `LoLaParityLedgerRunMode`, `FasterThanLoLaClosureRunMode`) to it, preserving JSON values and existing public names. HardwareValidation's `measured`/`synthetic` booleans remain per-evidence-row gates, not report run modes; ReferenceRig still has no run-mode field to rename without a schema migration. `MeasurementMethodologyTests` plus affected report/source-ownership filters passed with 136 tests. |
| 13.10 protocol/domain decoupling | Fixed/re-scoped + tested | Added `SessionCapabilityValidating`, `SessionAudioCapabilityNegotiating`, and `SessionVideoCapabilityNegotiating`; `CapabilitySet` validation and `SessionNegotiation` audio/video checks now depend on protocol contracts instead of concrete capability structs. `RxBufferProfile` now lives in the Protocol layer instead of UDP transport. The public wire DTO names remain stable to avoid a JSON schema break; `SessionProtocolTests` includes a source contract for the abstraction and the focused protocol/ownership/LOC filter passed with 51 tests. |

Verification commands run after this follow-up:

```bash
swift test --filter DebugTraceTests
swift test --filter AppShell
swift test --filter NativeAppShellTests
swift test --filter 'nativeAppShellCommandSettings|NativeAppShellTests'
swift test --filter CLICommandInventoryTests
swift test --filter AudioLoopbackRunTests
swift test --filter UdpPcmRouteReportTests
swift test --filter NatFriendlyRouteTests
python -m pytest linux_connector/tests/test_codec.py
ruff check linux_connector/lola_connector linux_connector/env/npcap_udp_relay.py linux_connector/tests/test_codec.py
shellcheck -x scripts/compare-local-jacktrip-parity-docker.sh scripts/open-lola-jacktrip-docker-client.sh scripts/open-lola-jacktrip-docker-policy.sh scripts/compare-local-ultragrid-parity-docker.sh scripts/compare-local-ultragrid-parity-native.sh scripts/run-local-jacktrip-rxtx-docker.sh scripts/run-local-ultragrid-rxtx-docker.sh scripts/run-local-ultragrid-rxtx-native.sh scripts/stress-local-ultragrid-parity-docker.sh scripts/stress-local-ultragrid-parity-native.sh
swift test --filter VerificationToolingContractTests
shellcheck scripts/verify-release-readiness.sh
bash scripts/verify-release-readiness.sh
swift test --filter ReleaseHardeningTests
swift test --filter OpenSourceReleaseReadinessTests
swift test --filter RecordingSessionArtifactTests
swift test --filter PackagingFieldTestTests
swift test --filter FieldReadyRuntimeProofTests
swift test --filter FasterThanLoLaClosureTests
shellcheck -x scripts/*.sh scripts/lib/*.sh
swift test --filter ReleaseArtifactHygieneContractTests
swift test --filter VerificationToolingContractTests
python3 -m py_compile scripts/lib/extract-preflight-executable.py scripts/lib/write-connection-metrics.py
ruff check linux_connector/lola_connector/connector.py linux_connector/tests/test_codec.py
python -m pytest linux_connector/tests/test_codec.py
swift test --filter AppShell
swift test --filter NativeAppShellTests
swift test --filter 'AoipEvaluation|Atem|Lighting|E2E|ReleaseHardening|PackagingField|RmeFastest|Drift|NetworkAoip|DirectPeerSession|MacToMac|Realtime|ReferenceRig|HardwareValidation|Integrated|UdpPcmRoute'
swift test --filter 'LoLaQuickConnectFallback|LoLaControlHandshakeValidation|LoLaCompatibilityTcpControl|ExternalConnectorSession'
swift test --filter 'PeerSessionRunner|PeerSessionAVFastest|DirectPeerSessionAVRXBufferProfile|DirectPeerSessionReportAVPass|DirectPeerTwoPeerRunPlan'
swift test --filter 'VideoTransport|MultiVideoStream'
shellcheck -x scripts/compare-local-jacktrip-parity-docker.sh scripts/compare-local-ultragrid-parity-docker.sh scripts/compare-local-ultragrid-parity-native.sh scripts/lib/common.sh scripts/lib/parity.sh
python3 -m py_compile scripts/lib/extract-preflight-executable.py scripts/lib/write-connection-metrics.py scripts/lib/write-ultragrid-parity-metrics.py
swift test --filter VerificationToolingContractTests
swift test --filter scopedCodeFilesStayWithinLineBudget
swift test --filter 'LoLaQuickConnectFallback|LoLaControlHandshakeValidation|LoLaCompatibilityTcpControl|ExternalConnectorSession'
swift test --filter 'PeerSessionRunner|PeerSessionAVFastest|DirectPeerSessionAVRXBufferProfile|DirectPeerSessionReportAVPass|DirectPeerTwoPeerRunPlan'
bash scripts/verify-release-readiness.sh
swift test --filter ReportSchemaInventoryTests
swift test --filter 'OscCue|Lighting|ReferenceRig|RecordingSession|FasterThanLoLa|FieldReady|ReleaseHardening|OpenSourceReleaseReadiness|Goal|HardwareValidation|MeasurementReportFixture|PackagingField|Atem'
swift test --filter SourceOwnershipInventoryTests
swift test --filter ReleaseRunConfigurationContractTests
swift test --filter 'VerdictValidationPolicyTests|OpenSourceReleaseReadinessTests|GoalCompletionAuditTests|SourceOwnershipInventoryTests'
swift test --filter 'SessionProtocolTests|SessionNegotiationTests|SourceOwnershipInventoryTests'
swift test --filter DirectPeerSessionReportAVPassTests
swift test --filter ValidateAssertionContractTests
swift test --filter 'VerdictValidationPolicyTests|ReleaseHardeningTests|LoLaParityDeferredFeaturesTests|FieldReadyRuntimeProofTests|FasterThanLoLaClosureTests'
swift test --filter 'VerdictValidationPolicyTests|ReferenceRig|HardwareValidation|PackagingField|RecordingSession'
swift test --filter 'VerdictValidationPolicyTests|HardwareValidation|FasterThanLoLaClosureTests'
swift test --filter 'MeasurementMethodologyTests|HardwareValidation|ReleaseHardeningTests|FieldReadyRuntimeProofTests|PackagingFieldTestTests|RecordingSessionArtifactTests|LoLaParityDeferredFeaturesTests|FasterThanLoLaClosureTests|SourceOwnershipInventoryTests'
swift test --filter VerdictValidationPolicyTests
bash scripts/verify-docs.sh
swift test --filter scopedCodeFilesStayWithinLineBudget
bash scripts/verify-release-readiness.sh
python3 -m mypy --strict linux_connector/lola_connector
ruff check linux_connector
python3 -m pytest linux_connector/tests
swift test --filter 'SessionProtocolTests|SessionNegotiationTests|MultiVideoStreamNegotiationTests|MultichannelTransportTests|SourceOwnershipInventoryTests|scopedCodeFilesStayWithinLineBudget'
```

Latest full rerun after the LoLa/direct-peer, parity-common-core,
settings-validation, validation-primitive, JSON/report-surface,
run-configuration contract, verdict-policy, methodology-unification, and
protocol-capability validation fixes passed with final `VERDICT: PASS`;
user-facing CLI probes still report `PARTIAL` where they depend on manual
hardware, release, or real-world evidence gates. A non-escalated verifier run
failed at `swift build` due SwiftPM's own sandbox (`sandbox_apply: Operation
not permitted`); the escalated rerun completed.

### Completion Audit — 2026-05-09

Concrete objective for this audit thread: address the `CODE_AUDIT.md` findings,
deduplicate/refactor the named slop surfaces, update the durable audit record,
and prove whether the repository is actually complete or still blocked.

| Requirement / gate | Current evidence | Completion status |
|---|---|---|
| Run 1 critical/high concrete defects | The remediation tables above list each fixed item and the focused Swift, Python, shell, docs, and release-verifier commands that passed. | Source-level closed. |
| Run 2 dedup/refactor/reface items | Items 9-13 above now have either fixed/tested entries or explicit re-scope entries where public contracts should not be collapsed. | Source-level closed. |
| Stale coverage and validate-only claims | Items 5.1, 5.2, 5.4, 5.6, and 5.7 were re-triaged against the live tree; `ValidateAssertionContractTests` now guards validate-bearing tests from assertion-free drift. | Source-level closed, broader coverage can still grow. |
| Python strict typing follow-up | `python3 -m mypy --strict linux_connector/lola_connector`, `ruff check linux_connector`, and `python3 -m pytest linux_connector/tests` passed. | Source-level closed. |
| Protocol/domain decoupling follow-up | `SessionAudioCapabilityNegotiating` and `SessionVideoCapabilityNegotiating` now carry the negotiation contracts, with focused protocol/source-ownership tests passing. | Source-level closed. |
| Durable audit record | This file now records the fixed, disproved, re-scoped, and still-open surfaces instead of reporting a blanket complete state. | Closed for audit handoff. |
| Release readiness verifier | `bash scripts/verify-release-readiness.sh` completed after an unsandboxed rerun and printed final `VERDICT: PASS`; its user-facing probes still report `PARTIAL` where manual release/runtime evidence is required. | Useful verifier pass, not goal completion proof. |
| Full GOAL.md completion audit | `goal-completion-audit-run` and `validate-goal-completion-audit-report` report 92 mapped items: 76 pass, 16 partial, 26 blockers, `real-world-verdict: partial`. | Blocked on runtime/release evidence. |
| Runtime preflight | `goal-runtime-preflight-run` and `validate-goal-runtime-preflight-report` report 10 deliverables, all partial. Current host evidence: 0 captured Core Audio devices, 0 RME MADI candidates, 0 video devices, 0 Blackmagic/ATEM candidates, denied camera permission, 1 codesigning identity, and 0 Developer ID Application identities. | Blocked on hardware, permissions, two-Mac route evidence, and signing/notarization/clean-Mac evidence. |
| Open-source release readiness | `open-source-release-readiness-run` reports `VERDICT: PARTIAL` with six blockers: final source license, documentation license, final third-party notices, fixture provenance, reviewer signoff, and public release approval. | Blocked on human/legal/reviewer decisions. |
| Physical/runtime release evidence | The release verifier explicitly leaves Developer ID, notarization, Gatekeeper, clean-Mac, hardware, and benchmark evidence as manual gates. | Blocked on real-world evidence. |

Completion verdict for the full goal: **PARTIAL**. The source-level audit
remediation is closed, but the full repository/release goal is not complete
until the human/legal/publication decisions and real hardware/signing evidence
above are supplied and re-verified.

---

# Historical Finding Detail

The sections below preserve the original audit findings and original suggested
fixes for traceability. Treat `**Fix**` blocks in this historical detail as the
auditors' initial recommendations, not as the current source of open work.
Current status is defined only by the remediation, resolution, and completion
audit tables above.

---

## 1. Swift — OpenLolaCore

### 1.1 🔴 CRITICAL — Data Race on `@unchecked Sendable`

**File**: `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`  
**Lines**: 246, 249–251, 307–309, 355–379

`UdpMediaTransport` is marked `@unchecked Sendable` while mutating `metrics`, `nextSequenceByStream`, `previousTransitByStream`, and `isClosed` from multiple threads without any synchronization. This is a classic data race: the `@unchecked` annotation silences the Swift compiler but does not add any actual safety.

**Fix**: Wrap shared mutable state in an `actor`, or guard every mutation behind a `NSLock`/`os_unfair_lock` with `defer { lock.unlock() }`. The cleanest Swift 6 approach is to convert the class to an `actor`.

```swift
// Before
final class UdpMediaTransport: @unchecked Sendable {
    var metrics: UdpMediaTransportMetrics = .init()  // accessed from multiple threads

// After
actor UdpMediaTransport {
    var metrics: UdpMediaTransportMetrics = .init()  // actor-isolated, safe
```

---

### 1.2 🟠 HIGH — Blocking Semaphore on Async AVFoundation Callback

**File**: `Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift`  
**Lines**: 309–313

`semaphore.wait()` blocks the calling thread indefinitely waiting for an `AVCaptureDevice` completion callback. If the system is under load or the device is unavailable, this hangs forever with no timeout.

**Fix**: Use `semaphore.wait(timeout: .now() + 5.0)` and handle `.timedOut`:

```swift
let result = semaphore.wait(timeout: .now() + 5.0)
guard result == .success else {
    throw CaptureError.authorizationTimeout
}
```

---

### 1.3 🟡 MEDIUM — Lock Management Without `defer` (Multiple Files)

**Files**:
- `Sources/OpenLolaCore/Connectors/LoLa/LoLaVideoPayloadProvider.swift` (lines 235–239, 263–268, 284–292, 317–321)
- `Sources/OpenLolaCore/Connectors/NMP/ExternalConnectorNmpEndpointRun.swift` (lines 295–297, 302–304)
- `Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift` (lines 140–142)
- `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift` (lines 66–68, 72–74)

All these sites call `lock.lock()` / `stateCondition.lock()` without a `defer { lock.unlock() }` guard. An early `return`, `throw`, or uncaught exception will leave the lock permanently acquired → deadlock.

**Fix** (apply uniformly):
```swift
lock.lock()
defer { lock.unlock() }
// ... critical section ...
```

**Status**: Fixed in the current follow-up. The audited production lock sites
now use `defer` unlock guards. A follow-up scan found remaining non-defer lock
usage only outside the original production site list.

---

### 1.4 🟡 MEDIUM — Unsafe `@unchecked Sendable` with Mutable State

**File**: `Sources/OpenLolaCore/Video/RawBGRAAppKitPreviewWindow.swift`  
**Lines**: 56–59

`window` and `imageView` are mutable properties on a class marked `@unchecked Sendable`. Mutations happen via `Task { @MainActor in ... }` (safe), but the `@unchecked` annotation hides any future accidental cross-thread access from the compiler.

**Fix**: Annotate the class `@MainActor` instead of `@unchecked Sendable`:
```swift
@MainActor
final class RawBGRAAppKitPreviewWindow { ... }
```

---

### 1.5 🟡 MEDIUM — Silent Error Drops via `try?`

**Files**:
- `Sources/OpenLolaCore/Core/DebugTrace.swift` line 44–46 — encoding failure silently drops events
- `Sources/OpenLolaCore/Connectors/LoLa/LoLaVideoPayloadProvider.swift` lines 259–261 — JPEG encoding failure silently drops frames
- `Sources/OpenLolaCore/Network/UDP/UdpPcmLoopbackSocketRunners.swift` line 77 — decode error discarded without logging

**Fix**: Replace `try?` with explicit do-catch and at minimum log failures:
```swift
// Before
let encoded = try? encoder.encode(event)

// After
do {
    let encoded = try encoder.encode(event)
    ...
} catch {
    debug.record(event: "encode-failed", fields: ["error": error.localizedDescription])
}
```

---

### 1.6 🔵 LOW — `ISO8601DateFormatter` Recreated on Every Call

**File**: `Sources/OpenLolaCore/Core/DebugTrace.swift`  
**Line**: 34

`ISO8601DateFormatter()` is expensive to construct. Creating one per `record()` call adds unnecessary overhead on a hot path.

**Fix**:
```swift
private static let iso8601 = ISO8601DateFormatter()
```

---

## 2. Swift — open-lola-app & open-lola

### 2.1 🟠 HIGH — Hardcoded `/tmp/` Log Paths

**File**: `Sources/open-lola-app/AppExecutionController.swift`  
**Lines**: 12–13

Log files are written to `/tmp/`, which is world-writable on macOS. Other processes can read, overwrite, or replace logs (symlink attack).

**Fix**: Use the app's sandboxed cache directory:
```swift
let logDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    .appendingPathComponent(Bundle.main.bundleIdentifier ?? "open-lola")
```

---

### 2.2 🟠 HIGH — Retain Cycle Risk in `runOneShot`

**File**: `Sources/open-lola-app/AppExecutionController.swift`  
**Lines**: 129–130

`process.terminationHandler` captures `self` strongly. If the completion closure passed into `runOneShot` itself holds a reference to `AppExecutionController`, this creates a retain cycle and leaks the controller.

**Fix**:
```swift
process.terminationHandler = { [weak self] finished in
    guard let self else { return }
    ...
}
```

---

### 2.3 🟡 MEDIUM — `@State` Used for Reference-Type Controller (`OpenLolaApp.swift`)

**File**: `Sources/open-lola-app/OpenLolaApp.swift`  
**Lines**: 8, 17

`AppExecutionController` is stored as `@State` but is a class. SwiftUI's `@State` is designed for value types. Using it with a class means SwiftUI won't observe mutations, and the instance may be recreated on body updates.

**Fix**: Use `@StateObject` if `AppExecutionController` conforms to `ObservableObject`, or `@State` with a proper value-type wrapper. The `@unchecked Sendable` conformance on the controller also bypasses Swift Concurrency safety — this should be addressed alongside.

---

### 2.4 🟡 MEDIUM — Silent Failure on `validatorArguments()` in `finishReport`

**File**: `Sources/open-lola-app/AppExecutionController.swift`  
**Line**: 156

`try?` silently drops any error thrown by `settings.validatorArguments()`. If the settings are invalid, validation silently runs with an empty command array.

**Fix**: Use do-catch, surface the error to the UI, or at minimum log it.

---

### 2.5 🟡 MEDIUM — Timer Not Cancelled on View Disappear

**File**: `Sources/open-lola-app/AppChannelMeterView.swift`  
**Lines**: 41–43

`Timer.publish().autoconnect()` is started but never explicitly cancelled. While SwiftUI often handles this, without an explicit `onDisappear` cancel, background timer fire can cause state updates to a non-visible view.

**Fix**:
```swift
.onDisappear { timerCancellable?.cancel() }
```

---

### 2.6 🟡 MEDIUM — 37 Separate `@AppStorage` Properties Without Validation

**File**: `Sources/open-lola-app/AppShellSettingsView.swift`  
**Lines**: 9–45

37 individual `@AppStorage` properties create a sprawling surface with no centralized validation. Invalid port numbers, missing paths, and out-of-range values are silently accepted.

**Fix**: Consolidate into a settings model with validation:
```swift
struct AppSettings {
    var port: UInt16 { didSet { guard (1024...65535).contains(Int(port)) else { port = oldValue } } }
}
```

---

### 2.7 🟡 MEDIUM — `exit(EXIT_FAILURE)` Without Cleanup

**File**: `Sources/open-lola/main.swift`  
**Line**: 11

Hard `exit()` bypasses Swift's automatic cleanup, `defer` blocks, and any open file/socket handles.

**Fix**: Propagate errors via `throws` and let the top-level Swift entry point handle failure, or register cleanup with `atexit()`.

---

## 3. Python — linux_connector

### 3.1 🟠 HIGH — No Error Handling on Process Write (`backends.py`)

**Lines**: 300–304 (`ProcessAudioPlayback.write_block`)

`process.stdin.write()` and `drain()` raise `BrokenPipeError` / `OSError` when the subprocess dies. No exception handling exists. A dead audio process will crash the entire asyncio event loop with an unhandled exception.

**Fix**:
```python
try:
    self.process.stdin.write(pcm)
    await self.process.stdin.drain()
except (BrokenPipeError, OSError) as e:
    raise RuntimeError(f"Audio playback process died: {e}") from e
```

---

### 3.2 🟠 HIGH — Process Not Cleaned Up on Exception (`backends.py`)

**Lines**: 263–271 (`ProcessAudioCapture.start`)

If `asyncio.create_subprocess_exec()` succeeds but a subsequent setup step raises, the child process is orphaned — never terminated, never awaited, consuming system resources until the parent exits.

**Fix**: Use try/except with explicit cleanup:
```python
try:
    self._process = await asyncio.create_subprocess_exec(...)
    # setup ...
except Exception:
    if self._process:
        self._process.kill()
        await self._process.wait()
    raise
```

---

### 3.3 🟠 HIGH — Fragment Validation Incomplete (`media.py`)

**Lines**: 184–206 (`MediaReassembler.add`)

When `fragment.fragment_index >= self.fragment_count` the method silently returns `None` — no log, no metric, no drop counter. A fragment arriving with `index == fragment_count` (off-by-one from sender) is permanently lost with no diagnostic signal.

Additionally, duplicate fragments (same index arriving twice) silently overwrite via `setdefault()` — which actually does *not* overwrite. This is correct by accident; the intent is unclear.

**Fix**:
```python
if fragment.fragment_index >= self.fragment_count:
    logger.warning("fragment index %d out of range (count=%d)", fragment.fragment_index, self.fragment_count)
    return None
if fragment.fragment_index in self.parts:
    logger.debug("duplicate fragment %d ignored", fragment.fragment_index)
    return None
```

---

### 3.4 🟠 HIGH — Silent Numeric Coercion in `protocol.py`

**Lines**: 63–70 (`MediaSettings.from_fields` — `number()` helper)

Invalid field values (e.g. `"garbage"`, empty string) are silently converted to `0`. A malformed or adversarial OSC packet therefore produces a `MediaSettings` object with all-zero fields that passes subsequent validation.

**Fix**:
```python
def number(text: str) -> int:
    try:
        return int(text)
    except ValueError:
        raise ValueError(f"Invalid numeric field: {text!r}")
```

---

### 3.5 🟠 HIGH — Port Overflow in `selftest.py`

**Lines**: 42, 21

`port_offset = 10000 + (os.getpid() % 20000)` gives offsets up to 29999. Combined with `DEFAULT_VIDEO_PORT` (19798), the resulting port can be 49797 — inside the ephemeral port range and potentially colliding with OS-assigned sockets. Line 21 uses a different modulus (15000) creating an inconsistency between audio and video port selection.

**Fix**:
```python
port_offset = os.getpid() % 5000  # max resulting port ~24798, well below 49152
```
Use the same formula for both audio and video.

---

### 3.6 🟡 MEDIUM — UDP Socket Created Per Packet (`connector.py`)

**Lines**: 301–317 (`send_audio`, `send_video`)

A new UDP socket is created and closed for every single audio block and video frame. On a 1ms audio cycle this means ~1000 socket open/close syscalls per second — unnecessary overhead and file descriptor churn.

**Fix**: Create one persistent socket per stream direction at session start and reuse it throughout the session lifetime.

---

### 3.7 🟡 MEDIUM — CPU Spin in `runtime.py` (`_wait_until`)

**Lines**: 285–286

The final sub-millisecond busy-wait loop runs with no `asyncio.sleep()` at all, consuming 100% of a CPU core for the duration of the spin. For a real-time audio application this is acceptable in a dedicated thread but is dangerous in the asyncio event loop where it blocks all other coroutines.

**Fix**: If this runs in the event loop, add minimal yielding:
```python
await asyncio.sleep(0)  # yield to event loop each iteration
```
If sub-ms precision is required, move to a dedicated thread with `loop.run_in_executor`.

---

### 3.8 🟡 MEDIUM — `assert` Used for Runtime Validation (`runtime.py`)

**Line**: 158

```python
assert self.video_capture is not None
```

Python `-O` (optimise) flag silently disables all `assert` statements. In production this becomes a silent `None` dereference.

**Fix**:
```python
if self.video_capture is None:
    raise RuntimeError("video_capture must be set before starting video TX loop")
```

---

### 3.9 🟡 MEDIUM — `decode("ascii", errors="ignore")` Silently Drops Data (`protocol.py`)

**Line**: 136

Non-ASCII bytes are silently dropped. A packet with unexpected encoding will parse differently than expected, potentially matching unrelated OSC paths.

**Fix**: Use `errors="strict"` and catch `UnicodeDecodeError`, or `errors="replace"` to preserve information for logging.

---

### 3.10 🟡 MEDIUM — TOCTOU Race on `self.session` (`connector.py`)

**Lines**: 352, 179

`self.session` is checked and then accessed in a later expression without synchronization. Another coroutine can clear `self.session` between the check and the use.

**Fix**: Snapshot at the start of each loop iteration:
```python
session = self.session
if session is None:
    continue
if addr[0] != session.remote_ip:
    ...
```

---

### 3.11 🔵 LOW — Missing Type Hints Throughout

**Files**: `backends.py`, `cli.py`, `runtime.py`

Many async methods lack return type annotations. This reduces `mypy` coverage and IDE assistance.

**Fix**: Run `mypy --strict linux_connector/` and add annotations incrementally. Key missing hints:
- `build_audio_capture() -> AudioCapture`
- `build_video_capture() -> VideoCapture | None`
- `_rx_socket_loop(self, sock: socket.socket, ...) -> None`

**Status**: Fixed in the current follow-up. Added the missing runtime/socket
and OSC typing needed for strict checking; `python3 -m mypy --strict
linux_connector/lola_connector`, `ruff check linux_connector`, and `python3 -m
pytest linux_connector/tests` pass.

---

## 4. Bash Scripts

### 4.1 🟠 HIGH — Race Condition: RX Readiness Checked Before Process Starts

**Files**: `scripts/run-local-ultragrid-rxtx-docker.sh` (lines 146–150), `scripts/run-local-ultragrid-rxtx-native.sh` (lines 165–171)

The RX process is started with `&` and immediately a readiness check is performed — no sleep, no startup synchronisation. On a loaded machine the process may not have started by the time the check runs.

**Fix**: Add a small initial wait or poll with backoff:
```bash
sleep 0.5
# then enter retry loop
```

---

### 4.2 🟠 HIGH — Release Artifacts Written to World-Writable `/tmp`

**File**: `scripts/export-release-candidate.sh`  
**Line**: 48

Default output falls back to `${TMPDIR:-/tmp}`. Release candidates placed in `/tmp` are readable by all local users and vulnerable to symlink attacks.

**Fix**: Default to the repository's `.build/` directory or require an explicit argument:
```bash
output_parent="${1:?output-parent-dir is required}"
```

---

### 4.3 🟠 HIGH — Background PID Not Validated After Fork

**File**: `scripts/run-local-ultragrid-rxtx-docker.sh`  
**Lines**: 146–147

`rx_pid=$!` is captured but not validated. If the background command fails to start, `$!` may be stale or empty, and subsequent `kill $rx_pid` operates on the wrong process.

**Fix**:
```bash
some_cmd &
rx_pid=$!
kill -0 "$rx_pid" 2>/dev/null || fail "RX process failed to start"
```

---

### 4.4 🟡 MEDIUM — AWK Timestamp Parsing Fails Silently on Log Format Change

**File**: `scripts/compare-local-jacktrip-parity-docker.sh`  
**Lines**: 124–143 (`connection_delay_seconds`)

The function parses timestamps with `awk` assuming a fixed log format. If the format changes, `start`/`stop` remain empty and arithmetic produces `0` or `nan` without any error.

**Fix**: Validate that `start` and `stop` were captured before computing:
```bash
[[ -n "$start" && -n "$stop" ]] || fail "Could not parse connection timestamps from log"
```

---

### 4.5 🟡 MEDIUM — Python Script Path Interpolated Into Heredoc Without Escaping

**File**: `scripts/compare-local-ultragrid-parity-native.sh`  
**Lines**: 53–64

Shell variables are expanded inside a Python heredoc (`<<PY` not `<<'PY'`). A path containing a backtick or `$` character would corrupt the embedded Python script.

**Fix**: Either use `<<'PY'` (no expansion) and pass variables as Python arguments, or validate that paths contain no special characters before interpolation.

---

### 4.6 🟡 MEDIUM — Array Index Access Without Bounds Check

**File**: `scripts/open-lola-jacktrip-docker-client.sh`  
**Line**: 66

`next_index=$((index + 1))` is used to read `${jacktrip_args[$next_index]}` without verifying `next_index < ${#jacktrip_args[@]}`. Accessing out-of-bounds produces an empty string, silently passing a blank argument to jacktrip.

**Fix**:
```bash
if ((next_index < ${#jacktrip_args[@]})); then
    val="${jacktrip_args[$next_index]}"
else
    fail "Flag requires an argument but none provided"
fi
```

---

### 4.7 🟡 MEDIUM — CI Workflow Missing `shell: bash`

**File**: `.github/workflows/release-readiness.yml`  
**Line**: 31

No `shell: bash` is specified. On macOS runners the default shell is `zsh`, which has different behaviour for unset variables, array syntax, and `set -e` semantics.

**Fix**: Add to job or step level:
```yaml
defaults:
  run:
    shell: bash
```

---

### 4.8 🔵 LOW — Hardcoded `/private/tmp/` (macOS-only)

**File**: `scripts/compare-local-jacktrip-parity-docker.sh`  
**Line**: 9

**Fix**: `output_dir="${OPEN_LOLA_OUTPUT_DIR:-${TMPDIR:-/tmp}/open-lola-jacktrip-parity}"`

---

## 5. Test Coverage

### 5.1 🔴 CRITICAL — 5 Entire Modules Have Zero Tests

| Module | Files | Notes |
|---|---|---|
| Benchmarks | 11 | Core release quality signal — LatencyBenchmarkReport, E2EBenchmarkReport |
| Integration | 8 | IntegratedAvRun, IntegratedProfileRun workflows |
| Platform | 5 | NativeAppShell state transitions, artifact generation |
| Support | 8 | Inventory operations, SPSCAtomicRing |
| Timing | 13 | RxBuffering, DriftPlc, LatencyTuning — critical path |

**Fix**: Add at minimum one round-trip construction + validate test per report type in each module. Timing and Benchmarks merit deeper edge-case coverage given their role in release verdicts.

---

### 5.2 🔴 CRITICAL — JackTrip & UltraGrid Connectors Have Zero Unit Tests

The Connectors module (36 files) has 11 tests covering ExternalConnector/LoLa paths. `JackTripLaunchPlan`, `JackTripAuxiliaryVideoPlan`, `UltraGridLaunchPlan`, and `UltraGridAuxiliaryVideoPlan` have **no tests**.

**Fix**: Add tests for:
- Launch plan construction from valid / invalid settings
- Argument generation (verify specific flags are emitted)
- Error handling when required fields are missing

---

### 5.3 🟠 HIGH — 626+ "Validate-Only" Tests With No Property Assertions

The dominant test pattern across the suite is:
```swift
func testFooDecodesAndValidates() throws {
    let report = try FooReport.load(fixture: "foo")
    try report.validate()
    // no further assertions
}
```

This pattern proves that fixture JSON is schema-valid but does **not** verify:
- Correct field values are decoded
- Business logic produces expected outputs
- Edge cases are handled

**Fix**: After `validate()`, assert key properties:
```swift
try report.validate()
#expect(report.verdict == .pass)
#expect(report.audio.sampleRate == 48000)
#expect(report.latency.p99Microseconds < 5000)
```

**Status**: Fixed/re-scoped in the current follow-up. The original 626+ count
is stale against the live tree. `ValidateAssertionContractTests` now scans
validate-bearing tests and fails future cases that lack `#expect`, `#require`,
`withKnownIssue`, or `confirmation`; the current inventory is 613
validate-bearing tests and 0 assertion-free offenders.

---

### 5.4 🟠 HIGH — Network Module ~7% Test Coverage

The Network module (42 files) has only 3 test files. Key untested paths:
- Malformed UDP packet handling
- Buffer overflow / underflow in reassembly
- Timeout and retry logic
- NAT traversal state machine transitions

**Fix**: Add tests modelled on `linux_connector/tests/test_codec.py` (which already tests reassembly edge cases). Port the most critical Python tests to Swift equivalents.

---

### 5.5 🟡 MEDIUM — Test Helper Files Mixed Into Test Target

8 files in `Tests/OpenLolaCoreTests/` contain no test cases — only helpers, fixtures, and shared state (e.g. `LoopbackUdpPort`, `ReservedLocalUdpPorts`, `SharedMeasuredFixtureBuilders`). This inflates the apparent test count and makes coverage metrics misleading.

**Fix**: Move non-test support files to a dedicated `TestUtilities` target or clearly suffix them `+TestSupport.swift`.

---

### 5.6 🟡 MEDIUM — Release Module Under-Tested (14% Coverage)

The Release module (22 files, 3 test files) contains release verdict determination logic — arguably the highest-value decision surface in the codebase. The existing tests are fixture-round-trip only.

**Fix**: Add verdict logic tests with parameterized inputs: passing inputs → `PASS` verdict, failing inputs → `FAIL` verdict, boundary inputs → correct partial verdict.

---

## 6. Security Summary Resolution

| Original issue | File | Current status |
|---|---|---|
| Log files in world-writable `/tmp/` | `AppExecutionController.swift` | Fixed; app execution logs now default to the user cache directory. |
| Release artifacts in `/tmp` | `export-release-candidate.sh` | Fixed; release export now requires an explicit output parent and release hygiene scans staged candidates. |
| Silent `0` coercion from invalid OSC field | `protocol.py` | Fixed + tested; malformed numeric fields now raise `ValueError`. |
| Missing message size upper bound | `protocol.py` | Fixed + tested; oversized control datagrams are rejected. |
| `decode(errors="ignore")` | `protocol.py` | Fixed + tested; ASCII parsing is strict. |
| No subprocess command validation | `cli.py` | Re-scoped; operator-supplied commands are split and launched without a shell, and are not treated as shell injection unless untrusted policy inputs are passed as commands. |

---

## 7. Dead Code / Unused Symbols Resolution

| Location | Original concern | Current status |
|---|---|---|
| `AppTransportView.swift` line 53–54 | `operatorSurface.commandIntent = .runRequested` write | Re-triaged; app transport binding is covered by `NativeAppShellTests`. |
| `ethernet.py` lines 72–73 | Length check after `parse_mac()` | Re-scoped; byte-length checks are still useful for raw `bytes` callers. |
| `backends.py` lines 390–394 | Convoluted buffer trim logic | Re-triaged; `ProcessJpegVideoCapture` buffer trimming is covered by codec tests. |
| `scripts/verify-docs.sh` | Python module import not validated before execution | Re-triaged; script already executes `python3 -m scripts.verify_docs`. |
| `NatFriendlyRouteSmokes.swift` line 73 | `let result = result` shadow capture | Re-scoped; result capture is safe after defer-lock cleanup. |

**Status**: Fixed/re-scoped in the current follow-up. Re-triage found the app
transport binding covered by `NativeAppShellTests`, `ProcessJpegVideoCapture`
buffer trimming covered by codec tests, Ethernet byte-length checks still
needed for raw `bytes` callers, `verify-docs.sh` already using `python3 -m
scripts.verify_docs`, and NAT result capture already safe after defer-lock
cleanup.

---

## 8. Recommended Fix Priority Resolution

This list preserves the original Run-1 priority order, but the current status
is no longer a future-work recommendation list.

### Original immediate list

| Priority | Original recommendation | Current status |
|---|---|---|
| 1 | Fix data race in `UdpMediaTransport`. | Fixed + tested. |
| 2 | Fix `/tmp` log path. | Fixed; app execution logs now default to the user cache directory. |
| 3 | Add error handling to `ProcessAudioPlayback.write_block`. | Fixed + tested. |
| 4 | Fix port overflow in `selftest.py`. | Fixed + tested. |

### Original short-term list

| Priority | Original recommendation | Current status |
|---|---|---|
| 5 | Add `defer { lock.unlock() }` to audited Core lock sites. | Fixed for audited production sites. |
| 6 | Fix `semaphore.wait()` timeout in `VideoCaptureAVFoundation`. | Fixed. |
| 7 | Replace silent `number()` coercion with `ValueError` in `protocol.py`. | Fixed + tested. |
| 8 | Fix race conditions in `run-local-ultragrid-rxtx-*.sh`. | Fixed + shellchecked. |
| 9 | Fix `@StateObject` / `@unchecked Sendable` in app surfaces. | Re-scoped for `@State` under SwiftUI Observation; fixed the audited mutable `@unchecked Sendable` preview state. |

### Original medium-term list

| Priority | Original recommendation | Current status |
|---|---|---|
| 10 | Re-triage validate-only tests. | Fixed + guarded by `ValidateAssertionContractTests`. |
| 11 | Write tests for Benchmarks, Timing, Platform, Support modules. | Disproved as a zero-test claim against the live tree; broader coverage remains expandable. |
| 12 | Write tests for JackTrip and UltraGrid launch plan construction. | Disproved as a zero-test claim against the live tree. |
| 13 | Refactor per-packet socket creation in `connector.py`. | Fixed + tested. |
| 14 | Add type hints and run strict typing on `linux_connector/`. | Fixed + tested for `linux_connector/lola_connector`. |
| 15 | Move test helpers out of `OpenLolaCoreTests` target. | Fixed/re-scoped with `+TestSupport.swift` helper suffixes and inventory updates. |

---

*Run 1 generated by GitHub Copilot fleet audit — 5 agents, 219 Swift + 13 Python + 19 Bash files reviewed.*

---

---

# Audit Run 2 — Code Quality, Unused Code, Slop, Deduplication & Refactoring

**Date**: 2026-05-09  
**Focus**: Dead code · duplicated logic · slop (magic numbers, boilerplate) · refactoring opportunities · architectural consistency  
**Method**: 4 parallel explore agents — Swift Core, Swift App, Python+Scripts, Cross-cutting Architecture

---

## Run-2 Severity Legend

| Tag | Meaning |
|---|---|
| DEDUP | Two or more sites contain near-identical code that should be unified |
| SLOP | Low-signal code: magic numbers, trivial boilerplate, copy-paste diff |
| REFACTOR | Code that works but has structural problems (god function, too many params, wrong abstraction) |
| UNUSED | Symbol defined but never called |
| ARCHITECTURE | Module-level design concern (coupling, YAGNI, marker protocols) |
| NAMING | Inconsistent names for the same concept across files |
| QUALITY | PEP 8 violations, missing docstrings, logging hygiene |

---

## 9. Swift — OpenLolaCore (Run 2)

### 9.1 DEDUP — Triplicated Argument-Parsing Helpers

**Files**:
- `Sources/OpenLolaCore/Audio/Routing/AudioLoopbackHelpers.swift` (lines 34–110)
- `Sources/OpenLolaCore/Network/UDP/UdpPcmRouteHelpers.swift` (lines 42–151)
- `Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteHelpers.swift` (lines 28–78)

All three files define functionally identical families of functions — `requiredString`, `requiredPositiveInteger`, `optionalPositiveInteger`, `optionalBoolean` — differing only in name prefix (`requiredAudioLoopback*`, `requiredRouteRun*`, `requiredNat*`). This is ~250 lines of copy-pasted code across three files.

**Fix**: Create a single `CommandLineArguments.swift` in `Sources/OpenLolaCore/Support/` with generic implementations:
```swift
enum CommandLineArguments {
    static func required<T>(_ key: String, in args: [String], convert: (String) throws -> T) throws -> T
    static func optional<T>(_ key: String, in args: [String], convert: (String) throws -> T) throws -> T?
}
```
All three helper files collapse to thin wrappers or are deleted entirely.

---

### 9.2 SLOP — ~100+ Lines of Unnecessary Boilerplate Initializers

**Files** (partial list):
- `Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift` (lines 29–224, 13+ structs)
- `Sources/OpenLolaCore/Release/RecordingSessionArtifacts.swift` (lines 124–224, 13 structs)
- `Sources/OpenLolaCore/Platform/NativeAppShellSurface.swift` (lines 56–145)
- `Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift` (lines 34–54)
- `Sources/OpenLolaCore/Video/VideoTransportPacket.swift` (lines 16–113)

Every struct has an explicit memberwise initializer that does nothing but `self.x = x` for every parameter. Swift generates these for free on `internal` structs. These initializers add noise, inflate file size, and must be manually kept in sync when fields are added.

**Fix**: Delete all trivial explicit initializers. They are only necessary when:
1. A struct is `public` and you need to guarantee a stable public ABI — in that case, mark them clearly.
2. Default values are set — but these belong as property defaults, not in the init body.

Estimated reduction: **~100–150 lines** across the module.

**Status**: Re-scoped in the current follow-up. The named files expose public
structs, so their explicit public initializers are required for external module
construction; synthesized memberwise initializers would be internal. One safe
internal case was removed from `VideoTransportStreamRunState` by moving counter
defaults onto stored properties.

---

### 9.3 REFACTOR — `sendLoLaControlAttempt` Is a 112-Line God Function

**File**: `Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift`  
**Lines**: 36–147

Single function that creates a UDP socket, runs a multi-step handshake (status-check → quick-connect), parses responses, handles fallback logic, and accumulates metrics. It also passes the same 5-value tuple (`socket, sentMessages, receivedMessages, bytesTransferred, destinationPort`) repeatedly as separate parameters.

**Fix**:
1. Extract state into a `LoLaExchangeState` struct.
2. Split into `sendStatusCheck()`, `receiveStatusAck()`, `sendQuickConnect()`, `receiveQuickConnectAck()`.
3. Return early with typed errors at each step instead of accumulating mixed state.

**Status**: Fixed in the current follow-up. The outgoing UDP control path now
uses `LoLaExchangeState` and named send/receive/parse/validation helpers while
preserving the existing fallback and handshake validation behavior.

---

### 9.4 REFACTOR — `runManualAddressAudioVideo` Is 79 Lines Mixing 4 Concerns

**File**: `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`  
**Lines**: 200–278

Combines: configuration validation, socket binding, AV runtime setup, metrics collection, and report building. Has 8+ consecutive `guard` statements (lines 319–356) all checking configuration properties with different thrown errors.

**Fix**: 
- Extract `validateAVConfiguration() throws` — the guard chain.
- Extract `buildAVReport()` — the metrics/report accumulation.
- `runManualAddressAudioVideo` becomes an orchestrator calling these.

**Status**: Fixed in the current follow-up. The live tree already had
`validateAVConfiguration()`; report construction is now isolated in
`buildAVReport(...)`, leaving the runner as socket setup plus AV orchestration.

---

## 10. Swift — open-lola-app (Run 2)

### 10.1 DEDUP — `AppAudioDeviceCard` and `AppVideoDeviceCard` Are Near-Identical

**File**: `Sources/open-lola-app/AppDeviceCard.swift`  
**Lines**: 7–93 (audio), 97–167 (video)

Two views with identical layout, styling, and structure. Differences: the device type, channel-count display logic, and two string labels.

**Fix**: Merge into a generic `AppDeviceCard<Device>` parameterised on device type with a configuration closure:
```swift
struct AppDeviceCard<Device: Identifiable>: View {
    let device: Device
    let label: String
    let detail: (Device) -> String
    ...
}
```

---

### 10.2 DEDUP — Binding Helper Pattern Duplicated Across Two Files

**Files**:
- `Sources/open-lola-app/AppShellSettingsView.swift` (lines 199–288) — 6 binding helpers
- `Sources/open-lola-app/AppPreviewReceiverView.swift` (lines 89–108) — 3 of the same helpers

`previewBoolBinding`, `previewDoubleBinding`, `previewIntBinding` exist in both files with identical implementations (get from `@AppStorage`, set to storage + update observable model).

**Fix**: Extract to a `StorageBindings` utility or a shared `ViewExtensions.swift` extension. Both views import from the same source.

---

### 10.3 DEDUP — Audio Input / Output / Video Device Selection Are Structurally Identical

**File**: `Sources/open-lola-app/AppLocalOperatorSurfaceView.swift`  
**Lines**: 32–51, 55–72, 76–91

Three consecutive sections with identical layout, empty-state messaging pattern, and binding wiring — differing only by filter predicate (`supportsInput` / `supportsOutput`) and section label.

**Fix**: Extract `DeviceSelectionSection(label:predicate:binding:)` view and call it three times.

---

### 10.4 SLOP — `@AppStorage` String Keys Not Centralised

**File**: `Sources/open-lola-app/AppShellSettingsView.swift`  
**Lines**: 9–45

37 `@AppStorage("openLola.xyz")` properties embed string keys as raw literals. If any key is mistyped or duplicated with a different default in another file (e.g. `AppShellStoredDefaults.swift` or `AppOperatorArtifactViews.swift`), user settings silently read the wrong value or reset on every launch.

**Fix**:
```swift
enum AppStorageKeys {
    static let executablePath  = "openLola.executablePath"
    static let planPath        = "openLola.planPath"
    // ...
}
@AppStorage(AppStorageKeys.executablePath) private var executablePath = ".build/debug/open-lola"
```
Centralise in one file and reference everywhere.

---

### 10.5 SLOP — Magic Number Thresholds in `AppLatencyHeroView`

**File**: `Sources/open-lola-app/AppLatencyHeroView.swift`  
**Lines**: 92–132

Six latency/jitter/loss threshold values (`5`, `15`, `0.01`, `1.0`, `1`, `5`) are hard-coded inline across 6 functions. No documentation of why these specific values are chosen or what they map to in the product spec.

**Fix**:
```swift
private enum Thresholds {
    static let latencyTargetMs: Double        = 5
    static let latencyAcceptableMs: Double    = 15
    static let packetLossTargetPct: Double    = 0.01
    static let packetLossAcceptablePct: Double = 1.0
    static let jitterTargetMs: Double         = 1
    static let jitterAcceptableMs: Double     = 5
}
```

---

### 10.6 SLOP — Magic Numbers Throughout UI Views

| File | Lines | Constants |
|---|---|---|
| `AppChannelMeterView.swift` | 16–19 | `meterWidth: 6`, `meterGap: 2`, `peakHoldDuration: 2.0`, `peakFallRate: 0.008` |
| `AppConnectionTopologyView.swift` | 112–113 | `flowOffset = 200`, `duration: 1.8` |
| `AppPacketMonitorView.swift` | 151–156 | Column widths: `52`, `72`, `160`, `160`, `80` |
| `AppSessionStateBanner.swift` | 25 | Animation `duration: 1.1` |

**Fix**: Define layout/animation constants at the top of each struct in a private `enum Layout` or `enum Animation`. Future design changes become single-line edits.

---

### 10.7 SLOP — Legacy Color/Width Aliases in `AppConsoleChromeView`

**File**: `Sources/open-lola-app/AppConsoleChromeView.swift`  
**Lines**: 5–8

Module-level `let` constants (`operatorConsoleBackground`, `panelBackground`, etc.) shadow tokens already defined in `AppDesignSystem.swift`. Code inconsistently uses both the old and new names.

**Fix**: Delete the legacy aliases. Update all call sites to use `AppDesignSystem` tokens directly.

---

### 10.8 REFACTOR — `AppShellSettingsView.body` Is ~150 Lines

**File**: `Sources/open-lola-app/AppShellSettingsView.swift`  
**Lines**: 48–134

Five `Form` sections in a single `body`. Hard to read, test, or modify individual tabs without scrolling through unrelated UI code.

**Fix**: Extract each section into a dedicated view: `AppExecutionSettingsTab`, `AppPeersSettingsTab`, `AppAudioSettingsTab`, `AppVideoSettingsTab`, `AppPreviewSettingsTab`.

**Status**: Fixed in the current follow-up. `AppShellSettingsView.body` now
delegates to dedicated tab views and keeps storage/binding ownership in the
parent view.

---

## 11. Python — linux_connector (Run 2)

### 11.1 DEDUP — 5× Identical Subprocess `aclose()` Pattern

**File**: `linux_connector/lola_connector/backends.py`  
**Lines**: 273–282, 306–316, 344–353, 408–417, 437–447

`ProcessAudioCapture`, `ProcessAudioPlayback`, `ProcessRawVideoCapture`, `ProcessJpegVideoCapture`, `ProcessVideoDisplay` all implement `aclose()` with the same structure: terminate with timeout → kill on timeout → await → set `None`. Differences are superficial (whether stdin is closed first).

**Fix**: Extract a `ProcessBase` mixin:
```python
class ProcessBase:
    _process: asyncio.subprocess.Process | None = None

    async def _close_process(self, *, close_stdin: bool = False) -> None:
        if self._process is None:
            return
        if close_stdin and self._process.stdin:
            self._process.stdin.close()
        try:
            self._process.terminate()
            await asyncio.wait_for(self._process.wait(), timeout=1.0)
        except (asyncio.TimeoutError, ProcessLookupError):
            self._process.kill()
            await self._process.wait()
        finally:
            self._process = None
```
All 5 classes inherit and call `await self._close_process()`.

---

### 11.2 DEDUP — Socket Creation Pattern Repeated 5× in `connector.py`

**File**: `linux_connector/lola_connector/connector.py`  
**Lines**: 95–111 and 4 other sites

`socket.socket(AF_INET, SOCK_DGRAM)` + `SO_REUSEADDR` + optional `SO_REUSEPORT` + `setblocking(False)` + bind is repeated with manual try/finally cleanup at every call site.

**Fix**:
```python
from contextlib import asynccontextmanager

@asynccontextmanager
async def udp_socket(port: int, reuse_port: bool = False):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if reuse_port:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    sock.setblocking(False)
    sock.bind(("", port))
    try:
        yield sock
    finally:
        sock.close()
```

---

### 11.3 DEDUP — `_message_ip()` Duplicated in `connector.py` and `runtime.py`

**Files**: `connector.py` lines 294–299, `runtime.py` lines 289–294

Identical IP-extraction logic copy-pasted into two files.

**Fix**: Move to `protocol.py` (or a new `utils.py`) and import from both.

---

### 11.4 DEDUP — Three Identical Handshake Receive Loops

**File**: `linux_connector/lola_connector/connector.py`  
**Lines**: 113–134 (`initiate`), 136–158 (`check_status`), 160–214 (`accept_once`)

All three implement: create socket → loop receiving UDP messages → parse → act on message type → finally close socket. The retry/timeout mechanics are identical, only the response-handling callback differs.

**Fix**: Extract `_handshake_loop(sock, handler: Callable[[ControlMessage], bool]) -> None` where `handler` returns `True` to break the loop.

---

### 11.5 DEDUP — `--test-media` Argument Defined Twice in `cli.py`

**File**: `linux_connector/lola_connector/cli.py`  
**Lines**: 56, 65

Both `listen` and `connect` subparsers define identical `--test-media`, `--tone-frequency`, `--tone-amplitude` arguments.

**Fix**: Extract `add_test_media_args(parser: argparse.ArgumentParser) -> None` and call it for both subparsers.

---

### 11.6 QUALITY — `print(..., flush=True)` Instead of `logging`

**Files**: `runtime.py` lines 179–183, 205–210; `env/npcap_udp_relay.py` lines 70, 92–95

Scattered `print()` calls cannot be suppressed, filtered by level, or redirected to structured log sinks. In a long-running daemon this is production-unfriendly.

**Fix**: Replace with `import logging; logger = logging.getLogger(__name__)`. Use `logger.info()`, `logger.debug()`, `logger.error()`. Configure level at the CLI entry point.

---

## 12. Bash Scripts (Run 2)

### 12.1 DEDUP — `fail()` Redefined in Every Script

**Files**: `export-release-candidate.sh:7`, `verify-release-readiness.sh:60`, `verify-release-hygiene.sh:7`, and 6+ others

Every script defines its own `fail()`, `require_file()`, `require_file_contains()`, `log()` functions from scratch. Minor differences (whether they prefix the script name) cause inconsistent error output across the suite.

**Fix**: Create `scripts/lib/common.sh`:
```bash
#!/usr/bin/env bash
fail() { echo "ERROR: $*" >&2; exit 1; }
require_file() { [[ -f "$1" ]] || fail "missing file: $1"; }
require_file_contains() { grep -qF "$2" "$1" || fail "$1 must contain: $2"; }
```
Each script sources it: `. "$(dirname "$0")/lib/common.sh"`.

---

### 12.2 DEDUP — 5 Probe Runner Functions Repeat 150+ Lines

**File**: `scripts/verify-release-readiness.sh`  
**Lines**: 87–237

`run_goal_codewise_closure_probe`, `run_goal_runtime_evidence_template_probe`, `run_goal_runtime_preflight_probe`, `run_goal_completion_audit_probe`, `run_open_source_release_readiness_probe` all follow the same pattern: run a command → capture output file → extract verdict → validate → print summary. Only the command name and expected verdict string differ.

**Fix**: Extract one generic function:
```bash
run_probe() {
    local name="$1" command="$2" expected_verdict="$3"
    local output_file
    output_file=$(run_timed_step "$name" "$command")
    local verdict
    verdict=$(extract_verdict "$output_file")
    [[ "$verdict" == "$expected_verdict" ]] || fail "$name: expected $expected_verdict, got $verdict"
    echo "PASS: $name"
}
```
The 5 probe functions collapse to 5 single-line `run_probe` calls.

---

### 12.3 DEDUP — `compare-local-*-parity-*.sh` Share a 300+ Line Core

**Files**: `scripts/compare-local-ultragrid-parity-docker.sh` (545 lines), `scripts/compare-local-ultragrid-parity-native.sh` (461 lines), `scripts/compare-local-jacktrip-parity-docker.sh`

Docker and native variants of the same parity test implement preflight, connection probing, metrics collection, AWK timestamp parsing, and report generation near-identically. Divergence is limited to the process/container startup sections.

**Fix**: Extract `scripts/lib/parity-test-common.sh` with shared functions (`require_direct_connection`, `connection_delay_seconds`, `write_parity_report`). Each driver script sources it and provides only the startup/teardown hook.

---

### 12.4 SLOP — Inline Python Heredocs in Bash Scripts

**File**: `scripts/run-local-ultragrid-rxtx-native.sh`  
**Lines**: 43–58, 75–104

Two multi-line Python scripts are embedded in bash heredocs for JSON parsing and report generation. This makes the scripts hard to test, syntax-highlight, or lint independently.

**Fix**: Extract to dedicated helper scripts:
- `scripts/lib/extract-preflight-executable.py`
- `scripts/lib/write-connection-metrics.py`

Call with `python3 scripts/lib/extract-preflight-executable.py "$preflight_report"`.

---

## 13. Architecture & Cross-Cutting Patterns (Run 2)

### 13.1 DEDUP — 104+ Private Validation Functions Across Release / Evidence / Control

**Modules**: `Release/`, `Evidence/`, `Control/` (24 + 40 + 24+ functions)

Every module defines its own `requireNonEmpty()`, `requirePositive()`, `requireNonNegative()` with a module-specific prefix (`requireFieldRuntime*`, `requirePackaging*`, `requireReferenceRig*`, `requireAtem*`). All implementations are identical; only the name changes.

**Fix**: One file in `Sources/OpenLolaCore/Core/` — `ValidationPrimitives.swift`:
```swift
enum Validation {
    static func requireNonEmpty(_ value: String, field: String) throws { ... }
    static func requirePositive(_ value: Int, field: String) throws { ... }
    static func requireNonNegative(_ value: Double, field: String) throws { ... }
}
```
Estimated reduction: **~90 functions deleted**, ~400 lines eliminated.

**Status**: Fixed in the current follow-up. The repeated domain helpers now
delegate their common empty, positive, non-negative, and finite checks to
`Sources/OpenLolaCore/Core/ValidationPrimitives.swift` while preserving each
module's existing error enum and call-site vocabulary. The remaining
module-prefixed functions are thin adapters for domain-specific errors rather
than separate validation implementations. The touched report-family filter
passed with 220 tests, and `SourceOwnershipInventoryTests` passed with 7 tests.

---

### 13.2 DEDUP — 70%+ Shared Structure Across 5 Report Types

**Files**:
- `Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift`
- `Sources/OpenLolaCore/Evidence/ReferenceRigReport.swift`
- `Sources/OpenLolaCore/Release/PackagingFieldTest.swift`
- `Sources/OpenLolaCore/Release/FieldReadyRuntimeProof.swift`
- `Sources/OpenLolaCore/Release/OpenSourceReleaseReadiness.swift`

All share: `id: String`, `title: String`, `capturedAt: String`, `verdict: MeasurementVerdict`, `notes: String`, `validate() throws`, and a `PrettyJSONCodable` + `Codable` conformance.

**Fix**: Extract `MeasurementReport` base protocol with a default `validate()` template method:
```swift
protocol MeasurementReport: PrettyJSONCodable {
    var id: String { get }
    var title: String { get }
    var capturedAt: String { get }
    var verdict: MeasurementVerdict { get }
    var notes: String { get }
    func validateEvidence() throws  // domain-specific hook
}
extension MeasurementReport {
    func validate() throws {
        try Validation.requireNonEmpty(id, field: "id")
        try Validation.requireNonEmpty(title, field: "title")
        try validateEvidence()
    }
}
```

---

### 13.3 DEDUP — Placeholder Detection Duplicated 3× Across Modules

**Files**:
- `Control/AtemReadOnlyControl.swift` line 388: `isAtemPlaceholder(_ value: String)`
- `Evidence/HardwareValidationReport.swift` line 457: `isHardwareValidationPlaceholder(_ value: String)`
- `Evidence/ReferenceRigReport.swift`: similar inline logic

All check for the same sentinel strings (`"todo(human)"`, `"placeholder"`, `"unknown"`, `"tbd"`, etc.).

**Fix**: Single utility in `Core/`:
```swift
enum PlaceholderDetector {
    static func isPlaceholder(_ value: String) -> Bool {
        let lower = value.lowercased().trimmingCharacters(in: .whitespaces)
        return lower.isEmpty || ["todo(human)", "placeholder", "tbd", "unknown", "n/a"].contains(lower)
    }
}
```

**Status**: Fixed in the current follow-up with `Sources/OpenLolaCore/Support/PlaceholderDetection.swift`.
The repeated report-specific predicates now share normalization and exact/substring
matching while keeping their original per-report placeholder vocabularies.

---

### 13.4 ARCHITECTURE — `ReportValidatingArtifact` and `PrettyJSONCodable` Are Marker Protocols With 60 Conformers

**Files**:
- `Sources/OpenLolaCore/Core/PrettyJSONCodable.swift` — `protocol PrettyJSONCodable: Codable {}`
- `Sources/OpenLolaCore/Evidence/ReportValidatorSurface.swift` — `protocol ReportValidatingArtifact` with 60 conformers listed

`PrettyJSONCodable` previously added no behavioral contract — it was `Codable` plus a default extension. 60 types conformed to it purely to inherit two methods they could access via a generic utility function.

`ReportValidatingArtifact` was reported as marker-only, but the current tree now gives it a validator-surface contract: `id`, `verdict`, `decode`, and `validate`.

**Fix**:
- Replace `PrettyJSONCodable` with a `JSONReportCoder` utility struct. Reports use it directly, no conformance needed.
- Replace `ReportValidatingArtifact` with a direct generic constraint: `func validate<T: Codable & MeasurementReport>(_ value: T)`.

**Status**: Fixed/re-scoped in the current follow-up. `PrettyJSONCodable`
now declares explicit decode and pretty-JSON requirements backed by
`JSONReportCoder`, preserving existing call sites while removing the empty
marker shape. `ReportValidatingArtifact` is no longer marker-only in the live
tree because its protocol requirements define the report validator contract.
`swift test --filter ReportSchemaInventoryTests` passed with 11 tests.

---

### 13.5 ARCHITECTURE — Verdict/Scoring Logic Is Scattered With No Policy Abstraction

**Files**: All `validate()` implementations in `Release/` and `Evidence/`

Pass/fail thresholds (`1_800` seconds minimum, `blockers.isEmpty`, `measured && physicalEvidence && !synthetic`) are hardcoded inside individual report validators. Changing a release threshold requires finding every affected file, and there is no single place to inspect "what does a passing release require?"

**Fix**: Extract a `VerdictPolicy` protocol:
```swift
protocol VerdictPolicy {
    func evaluate(blockers: [String], warnings: [String]) -> MeasurementVerdict
    var minimumRunDurationSeconds: Int { get }
    var requiresMeasuredEvidence: Bool { get }
}
struct ProductionVerdictPolicy: VerdictPolicy { ... }
```
Pass `policy` into `report.validate(policy:)`. Thresholds live in one file, are reviewable, and can be overridden in tests without monkey-patching.

**Status**: Fixed/re-scoped in the current follow-up. Added
`Sources/OpenLolaCore/Evidence/VerdictValidationPolicy.swift` with explicit
`validatePass`, `passRequires`, and `passForbids` semantics. Routed
`OpenSourceReleaseReadinessReport`, `GoalCompletionAuditReport`,
`ReleaseHardeningReport`, `LoLaParityDeferredLedgerReport`,
`FieldReadyRuntimeProofReport`, `FasterThanLoLaClosureReport`,
`ReferenceRigReport`, `HardwareValidationReport`,
`PackagingFieldTestReport`, and `RecordingSessionArtifactReport` pass
validation entry points through it without renaming public error cases or
changing exact test assertions. The policy also centralises the named
HardwareValidation 30-minute and Faster-than-LoLa 60-minute pass-duration
thresholds. Public domain error names are intentionally preserved for
compatibility, while `InvalidPassValidationRule` / descriptors classify every
Evidence/Release `pass*` error case as either `requires` or `forbids`;
`swift test --filter VerdictValidationPolicyTests` passed with this source
contract.

---

### 13.6 ARCHITECTURE — YAGNI: RunConfiguration Types With a Single Concrete User

**Files** (all in `Sources/OpenLolaCore/Release/`):
- `FieldReadinessRunConfiguration` → used by exactly one runner
- `PackagingFieldRunConfiguration` → used by exactly one runner
- `RecordingSessionRunConfiguration` → used by exactly one runner
- `FasterThanLoLaClosureRunConfiguration` → used by exactly one runner

Each configuration struct has a `parse()` static method (which itself duplicates argument-parsing boilerplate — see §13.7) and is passed to exactly one run function. The abstraction adds a type and a `.parse()` method without enabling any composition or reuse.

**Fix**: Inline the parameters directly into each runner function, or fold the `parse()` logic into the runner's `run([String]) throws` entry point. If the configuration types are genuinely intended for external use (e.g. programmatic invocation), document that intention and add tests for it.

**Status**: Re-scoped/tested in the current follow-up. The named release
configuration structs are public `Codable`, `Equatable`, `Sendable` input
contracts for both CLI parsing and direct runner invocation, so deleting them
would remove a programmatic surface used by tests and higher-level runners.
Added source documentation for that intent and
`ReleaseRunConfigurationContractTests`; `swift test --filter
ReleaseRunConfigurationContractTests` passed.

---

### 13.7 DEDUP — `RunConfiguration.parse()` Reimplements Argument Parsing Identically in Every Runner

**Files**: All `*RunConfiguration.swift` files under `Sources/OpenLolaCore/Release/`

Every `parse()` method implements the same `while index < arguments.count` loop, `guard allowed.contains(argument)`, `valueIndex = index + 1` pattern. This is the same duplication identified in §9.1 (the three helper files) applied at the Release layer.

**Fix**: Use the unified `CommandLineArguments` utility proposed in §9.1. All `parse()` methods become 3–5 lines.

---

### 13.8 NAMING — Inconsistent `MeasurementMode` Representation Across Reports

**Files**:
- `Evidence/HardwareValidationReport.swift` lines 64–70: `measured: Bool` + `synthetic: Bool` (two booleans)
- `Release/PackagingFieldTest.swift` line 353: `runMode: PackagingFieldTestRunMode` (enum: `synthetic`/`measured`)
- `Evidence/ReferenceRigReport.swift`: implicit (no flag; state is inferred)

Three different representations for the same concept — was this run measured or synthetic?

**Fix**: Define once in `Core/`:
```swift
public enum MeasurementMethodology: String, Codable {
    case synthetic
    case measured
}
```
Replace all `measured: Bool + synthetic: Bool` pairs and ad-hoc enums with this shared type.

**Status**: Fixed/re-scoped in the current follow-up. Added
`MeasurementMethodology` as the shared synthetic/measured methodology enum and
aliased the Evidence/Release report run-mode names to it so JSON values and
existing public names stay stable. HardwareValidation `measured`/`synthetic`
booleans remain per-evidence-row gates, not the report run mode, and
ReferenceRig currently has no run-mode field to rename without a schema
migration.

---

### 13.9 NAMING — Validator Error Names Are Inconsistent

**Files**: All `validate()` implementations across `Release/` and `Evidence/`

Some errors use `passWithout*` (e.g. `passWithoutMeasuredRun`, `passWithoutSignedAppRuntime`), others use `passWith*` (e.g. `passWithNonPassEvidence`, `passWithNonPassRoute`). The schema for what makes a verdict "invalid-pass" is impossible to understand from names alone.

**Fix**: Standardize to a structured error type:
```swift
enum VerdictValidationError: Error {
    case passRequires(field: String, reason: String)
    case passForbids(field: String, reason: String)
}
```
This makes validation errors self-documenting.

**Status**: Fixed/re-scoped in the current follow-up. New pass-validation code
uses shared `passRequires` / `passForbids` policy calls, and
`VerdictValidationPolicy` now exposes `InvalidPassValidationRule` descriptors
that classify every Evidence/Release public `pass*` domain error case as a
`requires` or `forbids` rule. Existing public error cases are preserved for
compatibility because many tests and callers assert exact domain errors.

---

### 13.10 ARCHITECTURE — Protocol Layer Knows Domain Types (Coupling Risk)

**File**: `Sources/OpenLolaCore/Protocol/SessionProtocol.swift` (lines 168–219)  
`Sources/OpenLolaCore/Protocol/SessionNegotiation.swift` (lines 141–230)

The Protocol module directly imports and validates `AudioTransportCapabilities`, `VideoCapabilities`, `RxBufferProfile`, `SessionLatencyProfile` from domain layers (Audio, Video, Timing). This creates tight coupling: a change to an Audio type forces recompilation of the Protocol module.

**Fix**: Introduce a `CapabilityValidating` protocol in the Protocol module that domain types conform to. Protocol layer depends on the abstraction; domain layers provide conformances.

**Status**: Fixed/re-scoped in the current follow-up. Added
`SessionCapabilityValidating`, `SessionAudioCapabilityNegotiating`, and
`SessionVideoCapabilityNegotiating`; `CapabilitySet` validation and
`SessionNegotiation` audio/video checks now depend on protocol contracts
instead of concrete capability structs. `RxBufferProfile` now lives in the
Protocol layer instead of UDP transport. Public wire DTO names remain stable to
avoid a JSON schema break. `SessionProtocolTests` includes a source contract
for the abstraction, and the focused protocol/ownership/LOC filter passed with
51 tests.

---

## 14. Run-2 Refactoring Backlog Resolution

This section preserves the Run-2 priority list, but the live status is no
longer an open backlog. Each row below maps the original backlog item to its
current remediation status from the tables above.

### Immediate impact (high line count reduction)

| Priority | Original change | Current status |
|---|---|---|
| 1 | Centralise `Validation` primitives (§13.1) | Fixed + tested with `ValidationPrimitives`. |
| 2 | Delete boilerplate initializers (§9.2) | Re-scoped; public initializers were retained where they preserve API construction, and one safe internal initializer was removed. |
| 3 | Unify argument-parsing helpers (§9.1 + §13.7) | Fixed + tested with `CommandLineArguments`. |
| 4 | Extract `ProcessBase` mixin for subprocess cleanup (§11.1) | Fixed + tested with `ProcessLifecycleMixin`. |
| 5 | Create `scripts/lib/common.sh` (§12.1) | Fixed + tested; helper definitions now live in `scripts/lib/common.sh`. |

### Medium impact (structural improvement)

| Priority | Original change | Current status |
|---|---|---|
| 6 | Generic `AppDeviceCard` to merge audio/video cards (§10.1) | Fixed with `AppSelectableDeviceCard`. |
| 7 | Centralise `AppStorageKeys` enum (§10.4) | Fixed. |
| 8 | Extract `VerdictPolicy` / scoring abstraction (§13.5) | Fixed/re-scoped + tested with `VerdictValidationPolicy`. |
| 9 | Replace marker protocols with utilities (§13.4) | Fixed/re-scoped + tested; `PrettyJSONCodable` and `ReportValidatingArtifact` now declare concrete behavior. |
| 10 | Socket context manager in `connector.py` (§11.2) | Fixed + tested with shared UDP socket cleanup. |
| 11 | Generic probe runner in `verify-release-readiness.sh` (§12.2) | Fixed + tested. |
| 12 | Extract `parity-test-common.sh` (§12.3) | Fixed + tested as `scripts/lib/parity.sh` plus a shared UltraGrid metrics helper. |
| 13 | Move inline Python to dedicated scripts (§12.4) | Fixed + tested with dedicated helpers under `scripts/lib/`. |

### Long term (architecture)

| Priority | Original change | Current status |
|---|---|---|
| 14 | `MeasurementReport` base protocol (§13.2) | Fixed/re-scoped + tested as `ReportMetadataArtifact`; the existing concrete `MeasurementReport` name was preserved. |
| 15 | `MeasurementMethodology` enum unification (§13.8) | Fixed/re-scoped + tested for Evidence/Release run modes while preserving public aliases and JSON values. |
| 16 | Decouple Protocol module from domain types (§13.10) | Fixed/re-scoped + tested with capability-negotiation protocols. |
| 17 | Standardise `VerdictValidationError` naming (§13.9) | Fixed/re-scoped + tested through policy taxonomy while preserving public domain error names. |
| 18 | Collapse single-user `RunConfiguration` types (§13.6) | Re-scoped + tested; public CLI/programmatic runner input contracts are intentionally retained. |

---

*Run 2 generated by GitHub Copilot fleet audit — 4 agents, focused on code quality, deduplication, and architecture.*
