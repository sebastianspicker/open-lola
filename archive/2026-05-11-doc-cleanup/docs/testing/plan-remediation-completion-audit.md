# plan.md Remediation Completion Audit

Date: 2026-05-11
Source of truth: `plan.md`
Objective: implement according to the "Remediation Priority Order" in `plan.md`.

This audit is a prompt-to-artifact checklist. It does not treat a passing
verifier as completion by itself; each priority item below must map to source,
tests, or an explicitly non-automatable gate.

## Success Criteria

1. Phase 1 P0 realtime safety items are implemented in source and covered by
   focused Swift tests or source-contract tests.
2. Phase 2 P1 correctness items are implemented in source and covered by
   focused Swift tests or source-contract tests.
3. Phase 3 P2 cleanup groups have concrete source/test evidence, not only a
   generic full-suite pass.
4. PROJ-06 referenced architecture documents exist on disk and are covered by
   docs verification.
5. Phase 4 project gates remain `PARTIAL` until human/legal/hardware evidence
   exists. These gates must not be converted to PASS by local source tests.
6. The full verifier must pass after source-owned remediation:
   `bash scripts/verify-release-readiness.sh`.

## Verifier Coverage

`bash scripts/verify-release-readiness.sh` passed on 2026-05-11. The script
covered documentation checks, shellcheck, Ruff, pytest, mypy, release hygiene,
`swift build`, `swift test --no-parallel`, and CLI surface probes.

The same run still reported the expected manual gate boundary:

- Developer ID, notarization, Gatekeeper, clean-Mac, hardware, and benchmark
  evidence remain manual gates.
- `goal-completion-audit` and `goal-runtime-preflight` remain `PARTIAL` with
  `real-world-verdict: partial`.
- `open-source-release-readiness-run` remains `PARTIAL` with release blockers.

## Phase 1 Checklist

| Item | Requirement | Evidence | Status |
|---|---|---|---|
| 1 | F-AUDIO-001: remove heap allocation from MADI render callback by preallocating receiver-mix scratch storage. | `Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift` owns `receiverMixScratch` initialized in `MadiReceiveEngine.init`; `renderCallback()` does not call `applyReceiverMix()`. `Tests/OpenLolaCoreTests/MadiReceiveTests.swift` has source-contract checks for `receiverMixScratch`. | Source closed |
| 2 | F-AUDIO-002: replace MADI receive `Dictionary` pending-deadline mutation on realtime path with slot-indexed storage. | `MadiReceiveEngine.pendingDeadlines` is `MadiReceivePendingDeadlineSlots`, not a dictionary; `Tests/OpenLolaCoreTests/MadiReceiveTests.swift` rejects `private var pendingDeadlines: [`. | Source closed |
| 3 | F-AUDIO-003/004: remove `Set`/`Array` allocation from IOProc capture validation by caching channel-map checks at init. | `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift` stores `inputChannelMapIsUnique` and `directInterleavedInput`; `Tests/OpenLolaCoreTests/RealtimeAudioPacketHandoffTests.swift` rejects the old per-callback `Set(inputChannelMap)` and `Array(0..<shape.channelCount)` patterns. | Source closed |

## Phase 2 Checklist

| Item | Requirement | Evidence | Status |
|---|---|---|---|
| 4 | F-AUDIO-016: use `takeRetainedValue()` for CoreAudio CFString properties. | `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift`; `Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift`. | Source closed |
| 5 | F-AUDIO-012/013/014/015: guard timing arithmetic overflow/wrap. | `MadiFullDuplexRuntime.swift`, `MadiFullDuplexTypes.swift`, `AudioLoopbackRun.swift`; tests in `MadiFullDuplexSessionTests.swift` and `AudioLoopbackRunTests.swift` check `UInt64(...)` multiplication, monotonic guards, and `multipliedReportingOverflow`. | Source closed |
| 6 | F-AUDIO-007/017: avoid O(n) MADI receive pending/ready scans. | `MadiReceivePendingDeadlineSlots` and `MadiReceiveReadyBlockRing` are used in `MadiReceive.swift`; `MadiReceiveTests.swift` covers the source contract and receive behavior. | Source closed |
| 7 | F-AUDIO-005/006: replace callback clock syscall and realtime pop allocation. | `RealtimeAudioPacketHandoff.swift` uses `mach_absolute_time()` and `captureRing.withPoppedPayload`; `DirectPeerAudioPayloadRing.swift` exposes zero-copy `withPoppedPayload`; covered by `RealtimeAudioPacketHandoffTests.swift` and `PeerSessionAVSupportTests.swift`. | Source closed |
| 8 | F-AUDIO-010/011: close buffer capacity race and preserve invalid-drop errors. | `RealtimeAudioBuffers.swift` distinguishes `.droppedInvalid`, `.droppedAhead`, and full-pressure drops; covered by `RealtimeAudioEngineTests.swift` and `RealtimeAudioPacketHandoffTests.swift`. | Source closed |
| 9 | F-LOLA-001/002/003/006/008: close core LoLa interop blockers. | LoLa fragment reassembly, destination-port validation, variable decoded IPv4 IDs, TCP control padding, and IP normalization live in `Connectors/LoLa/**`; covered by `LoLaCompatibilityMediaCodecTests.swift`, `LoLaCompatibilityMediaEnvelopeValidationTests.swift`, `ExternalConnectorLoLaCompatibilityTests.swift`, `LoLaCompatibilityTcpControlTests.swift`, and `LoLaControlHandshakeValidationTests.swift`. | Source closed |
| 10 | F-PROT-001: allow rational broadcast frame rates. | `DirectPeerSessionAVSocketRunner.swift` compares rational frame rates without `denominator == 1`; `SessionNegotiationTests.swift` covers NTSC-style denominators. | Source closed |
| 11 | F-CTRL-001: prevent lighting gate self-invalidating packet-capture reports. | `LightingFixtureGateRun.swift` marks the no-live-packet safety handoff as `captured: false`; `LightingFixtureGateTests.swift` covers packet-capture accounting validation. | Source closed |
| 12 | F-NET-001: report UDP close failures in release builds. | `UdpPcmSocketOperations.swift` uses `os_log(.fault, ...)`; covered by UDP/network contract tests and full Swift test run. | Source closed |
| 13 | F-NET-009/012: prevent UDP fd leaks on partial transport setup. | `UdpMediaTransport.swift` and `NatRendezvousRelayRunners.swift` use `succeeded` cleanup guards; `PeerSessionRunner.swift` closes descriptors through defer-backed helpers; covered by P2P/NAT/UDP tests. | Source closed |
| 14 | F-NET-015: avoid subprocess pipe hang after SIGTERM. | `NetworkDiagnostics.swift` escalates to `SIGKILL` before final pipe reads; covered by `NetworkDiagnosticsTests.swift`. | Source closed |
| 15 | F-UI-001/004/005: remove actor-isolated deinit crashes. | `AppReceiverPreviewServices.swift` and `AppExecutionController.swift` use explicit teardown/no-op deinit patterns; `AppShellSourceContractTests.swift` rejects `MainActor.assumeIsolated` and `AppExecutionController: @unchecked Sendable`. | Source closed |
| 16 | F-UI-002: read Float32 Core Audio meter buffers correctly. | `AppReceiverPreviewServices.swift` computes Float32 meter snapshots; app/source tests cover the preview service surface. | Source closed |
| 17 | F-UI-003: replace hardcoded `/tmp` app paths. | `NativeAppShellExecution.swift` resolves application-support paths; `NativeAppShellTests.swift` asserts supervisor paths are under Application Support, not `/tmp`. | Source closed |
| 18 | F-UI-036: do not stop live supervisor on sidebar navigation. | `AppExecutionView.swift` has no stop-on-disappear path; `OpenLolaApp.swift` tears down only on `ScenePhase.background`; `AppShellSourceContractTests.swift` covers both conditions. | Source closed |

## Phase 3 Checklist

| Group | Requirement | Evidence | Status |
|---|---|---|---|
| F-NET-003/004/006/008/011/013/014/016/017/018/019/020/021 | UDP, NAT, P2P, video transport, duplicate helper, fallback-warning, and timeout cleanup. | `UdpPcmSocketOperations.swift`, `UdpPcmContinuousRouteRunner.swift`, `DirectPeerAVFoundationRawFrameSource.swift`, `NatRendezvousRelayRunners.swift`, `NatFriendlyRouteHelpers.swift`, `VideoOutputRenderer.swift`, `VideoTransportReassembly.swift`, `UdpPcmDataHelpers.swift`, `DirectPeerTwoPeerRunPlan.swift`, `MultichannelTransport.swift`, `UdpPcmLoopbackSocketRunners.swift`; covered by `Udp*`, `NatFriendlyRouteTests.swift`, `PeerSessionAVSupportTests.swift`, `MultichannelTransportTests.swift`, and `VideoTransport*Tests.swift`. | Source closed |
| F-AUDIO-008/009/018/019/020/021/022/023/024/025/026/027/028/029 | Realtime guardrails, MADI metrics, playout accounting, validation correctness, warning acknowledgements. | `DirectPeerAudioPayloadRing.swift`, `RealtimeAudioBuffers.swift`, `MadiReceive.swift`, `RealtimeAudioEngineReportValidation.swift`, `AudioLoopbackRun.swift`, `MadiFullDuplex*`, `DriftPlc*`, `LatencyProfileContracts.swift`; covered by corresponding audio/timing tests. | Source closed |
| F-LOLA-004/005/007 | TXT parsing, BPF empty-ring retry, typed timeout flag. | `LoLaCompatibilityControlMessage.swift`, `LoLaCompatibilityRawLink.swift`, `LoLaControlExchangeRuntime.swift`; covered by LoLa compatibility/session/fallback tests. | Source closed |
| F-PROT-002 | Reconnect deadline is configurable. | `SessionProtocol.swift` / `SessionNegotiation.swift`; covered by `SessionNegotiationTests.swift` and `SessionProtocolTests.swift`. | Source closed |
| F-CTRL-002 | OSC cue audio impact must not be presented as measured if synthetic. | `OscCueRunners.swift` and report validators preserve source-level/synthetic boundaries; covered by `OscCueReportTests.swift` and full verifier CLI probes. | Source closed |
| F-SHELL-001/002 | Supervisor command path must not hardcode debug build and `--executable` must be validated. | `NativeAppShellArtifacts.swift`, `NativeAppShellExecution.swift`, `AppExecutablePathResolver.swift`; covered by `NativeAppShellArtifactTests.swift`, `NativeAppShellTests.swift`, and `AppShellSourceContractTests.swift`. | Source closed |
| F-CONN-001/002/003/004/005 | Connector dead code, process reaping, EINTR timeout accounting, cleanup, typo aliases. | `ExternalConnectorSessionRuntime.swift`, `ExternalConnectorProcessRunner.swift`, `ExternalConnectorParsingDefaults.swift`; covered by `ExternalConnectorProcessGroupTests.swift`, `ExternalConnectorSessionTests.swift`, `ExternalConnectorAvMatrixTests.swift`, and NMP tests. | Source closed |
| F-UI-006..035 | UI status, animation, dead code, dedup, persistence, accessibility, elapsed timer, design tokens. | `Sources/open-lola-app/**` and `Sources/OpenLolaCore/Platform/**`; covered by `NativeAppShellTests.swift`, `AppShellSourceContractTests.swift`, `AppChannelMeterSourceTests.swift`, `NativeAppShellArtifactTests.swift`, and app shell source tests. | Source closed |
| F-CORE-004..015 | Ownership reverse checks, validation helpers, parser behavior, negative benchmark validation, deferred TODO cross-references, release dependency gate, generated CLI usage, verdict policy registry, prototype naming TODO, fixture matrix dedup. | `SourceOwnershipInventoryTests.swift`, `ValidationPrimitives.swift`, `DebugTrace.swift`, `KeyValueArgumentParser.swift`, benchmark validator tests, `LoLaParityDeferredFeaturesTests.swift`, `OpenSourceReleaseReadiness.swift`, `CLICommandInventoryTests.swift`, `VerdictValidationPolicy.swift`, `SourceNamingConventionTests.swift`, `FixtureSmokeMatrixData.swift`; covered by full Swift tests and release-readiness CLI probes. | Source closed |
| PROJ-06 | Verify referenced architecture docs exist. | `docs/architecture/latency-profiles.md`, `docs/architecture/video-blackmagic-atem.md`, and `docs/architecture/p2p-networking.md` exist and are covered by `bash scripts/verify-docs.sh`. | Closed |

## Phase 4 Checklist

| Gate | Requirement | Evidence | Status |
|---|---|---|---|
| PROJ-01 | Final open-source license selected. | `LICENSE` and `docs/compliance/license-decision-record.md` still contain pending human/legal decision markers. | Open manual gate |
| PROJ-02 | Final third-party notices. | `THIRD_PARTY_NOTICES.md` and compliance docs intentionally remain draft/pending. | Open manual gate |
| PROJ-03 | Final review/signoff packet. | `docs/compliance/final-review-packet.md` records pending reviewer decisions. | Open manual gate |
| PROJ-04 | Physical two-Mac RME MADI hardware run for all 10 runtime deliverables. | `goal-runtime-preflight` and `goal-completion-audit` remain `real-world-verdict: partial`; fixtures are partial/synthetic where appropriate. | Open hardware gate |
| PROJ-05 | Developer ID signing certificate plus clean-Mac install test. | Release-readiness verifier reports Developer ID, notarization, Gatekeeper, and clean-Mac evidence as manual gates. `GoalRuntimeEvidenceTemplateReport` carries concrete command templates for every advertised runtime evidence surface, including packaging/signing commands, `packaging-field-run`, `field-runtime-proof-run`, and `field-readiness-run`; `GoalRuntimeEvidenceTemplateTests` guards this handoff and the validators. | Open manual/hardware gate |

## Completion Decision

Source-owned Phase 1 through Phase 3 remediation is closed against the current
tree and verifier evidence. The objective cannot be marked complete because
Phase 4 remains explicitly open and cannot be satisfied by code-only work in
this environment.

Current project verdict: `PARTIAL`.
