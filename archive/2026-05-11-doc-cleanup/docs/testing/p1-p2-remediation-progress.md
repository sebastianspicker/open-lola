# P1/P2 Remediation Progress

Date: 2026-05-10
Status: source-owned remediation closed for the May 10 prompt checklist
Verdict: PARTIAL for product/release readiness until real hardware, signing, notarization, fixture provenance, and license signoff gates have evidence.

This ledger maps the 38 explicit P1/P2 issues from the May 10 remediation
request to the current code, tests, and verification evidence. It is source-level
evidence only; it does not convert deferred real-world validation gates into a
release PASS.

## Prompt Checklist

| Prompt item | Status | Evidence |
|---|---|---|
| 1. DirectPeer realtime RX reorder before due frame. | Closed | `DirectPeerRealtimeAudioGraph.renderPlayout` copies the exact due frame from `DirectPeerAudioPayloadRing` and drops stale frames; `directPeerRealtimeAudioGraphPlaysReorderedPayloadAtDueFrame` covers out-of-order arrival. |
| 2. Audio loopback `--rx-buffer-profile` handoff/report path. | Closed | `audioLoopbackRealtimeConfiguration(for:)` carries `RxBufferPolicy` into the realtime handoff; `audioLoopbackRealtimeConfigurationAppliesExplicitRXBufferProfileToHandoff` verifies `stableWan` metrics. |
| 3. DirectPeer AV RX-buffer graph-level proof. | Closed | `audioGraphConfiguration(for:)` and `DirectPeerSessionAVBufferPolicy` carry the accepted profile into ring capacity and playout targets; `directPeerAudioVideoGraphConfigurationCarriesSelectedRXBufferPolicy` covers fastest and balanced profiles. |
| 4. Direct audio routing accepted RX-buffer profile. | Closed | `directAudioMediaRouterAudioMode(...)` preserves the accepted session profile in `AudioTransportMode`; `directAudioMediaRouterModeCarriesSessionRXBufferProfile` covers the route. |
| 5. Fixed-target jitter buffer allocation/drop accounting. | Closed | `RealtimeAudioFixedTargetJitterBuffer` now uses preallocated slots and returns `.droppedInvalid` separately from full-pressure drops; focused jitter-buffer tests cover reordering, invalid shape, and preallocated source contract. |
| 6. DirectPeer graph start rollback on partial startup failure. | Closed | `DirectPeerRealtimeAudioGraph.start(...)` rolls back through `stop()` on configuration or IOProc startup failure, and `makeAndStartIOProc` destroys created IOProcs when start fails. |
| 7. LoLa UDP `tx-rx` bind-before-transmit ordering. | Closed | `LoLaSocketUdpMediaReceiver.receive(... afterBind:)` starts TX only after RX sockets bind; LoLa socket/session tests cover bind-before-send ordering. |
| 8. Fragmented LoLa video datagram counts. | Closed | `LoLaCompatibilityMediaCodec.expectedDatagramCount(...)` computes payload and fragment counts from dimensions, bits per pixel, and fragment body/header overhead; tests cover fragmented 1920x1080 video. |
| 9. UDP post-receive metrics and clock skew. | Closed | `UdpMediaTransport.receive` and `tryReceive` timestamp immediately after datagram receive and record clock skew separately instead of false zero-latency samples. |
| 10. CLI invalid arguments/help. | Closed | CLI probes returned exit 1 for invalid command/option and exit 0 for `--help`; inventory-backed help and DirectPeer CLI parsing tests cover the behavior. |
| 11. Preview off must not allocate/use a video sink. | Closed | `runAVMediaLoops` creates a preview sink only when `configuration.preview == .on`; fastest AV tests assert `previewFramesSubmitted == 0` with preview off. |
| 12. Preview on must open a visible production sink. | Closed | `makeDirectPeerPreviewSink(for:)` uses `RawBGRAAppKitPreviewWindow` for production preview-on runs and keeps `RawBGRATestablePreviewSink` for synthetic fixtures or explicit `OPEN_LOLA_DISABLE_APPKIT_PREVIEW=1`; `directPeerPreviewOnUsesVisibleSinkForProductionAndTestSinkForSyntheticFixture` covers the boundary. |
| 13. Receiver UI must distinguish local preview from decoded network RX. | Closed | The app receiver surface labels local preview paths and empty remote decode state (`Local Preview`, `Local Device Preview`, `No remote video frames decoded`); app shell source contracts cover the user-visible wording. |
| 14. Production camera path must not resend cached frames. | Closed | `DirectPeerAVFoundationFrameDeliveryGate` gates duplicate cached AVFoundation frames; `directPeerAVFoundationFrameDeliveryGateDoesNotResendCachedFrame` covers the no-resend contract. |
| 15. Useful media proof must respect the audio playout window. | Closed | `validateUsefulMediaMoved` and `DirectPeerSessionReport.validate` discount video frames dropped outside the audio window; `directPeerSessionAVPassAccountsForVideoFramesDroppedOutsideAudioWindow` covers the report proof. |
| 16. Supervisor UI must not show false LIVE state. | Closed | `AppTransportView.statusTone` now uses `stateConnecting` while the process is running without media proof; `AppShellSourceContractTests` rejects `stateLive` for this path. |
| 17. Command intent labels must not collide with Start/Run/Stop process controls. | Closed | `AppLocalOperatorSurfaceView` now labels intent buttons `Intent: Handoff`, `Intent: Start`, `Intent: Run`, `Intent: Stop`, and `Clear Intent`; source contracts cover the labels. |
| 18. Release export must keep test fixtures needed by the candidate. | Closed | `scripts/export-release-candidate.sh` keeps `Tests/OpenLolaCoreTests/Fixtures`, and hygiene/docs tests require fixtures in the candidate while still blocking release approval on provenance signoff. |
| 19. Release export must include active source, docs, Linux connector, and CI surfaces. | Closed | Export/hygiene contracts now require `pyproject.toml`, `.github/workflows/release-readiness.yml`, `linux_connector`, `docs/testing`, `docs/diagrams`, Swift sources, tests, and fixtures. |
| 20. Docs verifier must handle public candidates without internal archives. | Closed | `scripts/verify_docs/main.py` detects public-candidate mode, skips internal corpus checks, and `markdown_checks.py` permits links into omitted internal/archive prefixes; release tests run `scripts/verify-docs.sh` inside a staged candidate. |
| 21. Python ruff/pytest release-readiness and CI enforcement. | Closed | `scripts/verify-release-readiness.sh` and `.github/workflows/release-readiness.yml` run Ruff and pytest with pinned local tool expectations; release hygiene tests lock the contract. |
| 22. DirectPeer channel-map length validation. | Closed | `NetworkCommands.swift` validates channel-map lengths against `--channels`, and graph preflight rejects mismatched/negative maps before runtime startup. |
| 23. Invalid payload/input shape must not count as full ring pressure. | Closed | `RealtimeAudioRingPushResult` and `SPSCAtomicRingResult` distinguish invalid input from full rings; counters now separate invalid drops from overrun/full-pressure drops. |
| 24. Host-time conversion helper reuse. | Closed | `MediaClock.nanoseconds(forFrameCount:sampleRateHertz:)` centralizes full-width frame-to-nanosecond conversion for UDP packet intervals and DirectPeer AV playout tolerance. |
| 25. DirectPeer payload ring SPSC guardrails. | Closed | `DirectPeerAudioPayloadRing` records producer/consumer thread owners with atomics and preconditions on cross-thread contract violations; AV support tests lock the source contract. |
| 26. LoLa reports actual UDP wire source/destination. | Closed | `LoLaCompatibilityMediaFrame` carries `sourceHost` and `destinationHost` decoded from `LoLaCompatibilityWireFrame`; session tests cover configured-peer and actual-wire-source divergence. |
| 27. LoLa fallback bind descriptor cleanup. | Closed | `makeLoLaUdpMediaSocket(bindHost:port:)` uses a `shouldClose` cleanup guard until successful bind return; socket tests cover fallback bind failure cleanup. |
| 28. P2P audio-only receive helper. | Closed | `PeerSessionRunner.receiveMediaPacket()` delegates to `receiveAudioMediaPacket()`, and audio receive no longer decodes video or mutates video metrics. |
| 29. Pixel-format normalization and bytes-per-pixel dedupe. | Closed | Shared `normalizedVideoPixelFormat(_:)` and `videoBytesPerPixel(for:)` helpers back DirectPeer wrappers and `VideoPixelFormat.bytesPerPixel`; transport tests cover the shared policy. |
| 30. Metrics-only video renderer accounting. | Closed | Added `VideoOutputBackendKind.metricsOnly`; synthetic render accounting now reports metrics-only instead of a real preview/output backend. |
| 31. App search fields behavior. | Closed | `NativeAppShellSectionSearch` and `NativeAppPacketMonitorRows` implement section and packet filtering; `NativeAppShellTests` cover empty, title, identifier, stream, endpoint, and candidate searches. |
| 32. macOS operator menu exposure. | Closed | The app command menu exposes handoff/clear intent plus refresh, arm, plan-write, dry-run, start, stop, validate, and preview commands; app shell source contracts cover wiring. |
| 33. UID/packet accessibility readability. | Closed | Packet monitor rows expose full hover/accessibility labels, and peer input/output/video IDs expose full-value help/accessibility labels. |
| 34. UI behavior tests beyond source strings. | Closed | `NativeAppShellTests` now cover search, packet filtering, and accessibility behavior; source-string tests remain only for app-target wiring the core target cannot import. |
| 35. Generated/local artifacts in raw tree. | Closed | Generated Swift/Python/build artifacts and root-local private state were removed; the cleanup probe allows only documented internal Windows evidence under `win-compiled/2-0/`. |
| 36. UltraGrid Docker mutable-image policy. | Closed | `open-lola-ultragrid-docker-policy.sh` centralizes pinned image selection and rejects `latest`; build/start/client UltraGrid helpers route through it while exposing `OPEN_LOLA_ULTRAGRID_DOCKER_IMAGE`. |
| 37. Linux connector tests using public API. | Closed | `linux_connector/tests/test_codec.py` exercises public connector/runtime/backend behavior, and `LolaConnector.settings_from_quickconn_ack` exposes the QuickConn ACK settings rule as a public primitive. |
| 38. Python project manifest and pytest asyncio warning. | Closed | `pyproject.toml` defines package/tool config and `asyncio_default_fixture_loop_scope = "function"`; pytest runs without the prior loop-scope warning. |

## Open Gates

No source-owned item from the 38-item prompt checklist remains open.

Product and release readiness remain `PARTIAL` until the project has real
hardware/two-Mac evidence, fixture provenance approval, license/notice approval,
code signing/notarization, and clean-Mac launch evidence. Those gates are
outside this source-only remediation pass and must not be reported as PASS from
local tests alone.

## Verification Log

| Command | Result |
|---|---|
| `swift test --no-parallel` | Passed: 1229 tests in 0 suites after closing the UltraGrid helper contract failure. |
| `swift test --filter 'AudioLoopbackRunTests\|DirectPeerSessionAVRXBufferProfileTests\|DirectPeerRealtimeAudioGraphTests\|DriftPlcReportTests' --no-parallel` | Passed: 50 tests covering realtime RX reordering, loopback RX profile handoff metrics, DirectPeer AV graph/router RX profile wiring, and fixed-target jitter buffer storage/accounting. |
| `swift test --filter DirectPeerRealtimeAudioGraphTests --no-parallel` | Passed: 9 tests covering graph mapping, channel-map preflight length/negative validation, RX target playout, reordered payload playout, invalid zero-channel buffers, and startup rollback source contract. |
| `swift test --filter 'LoLaQuickConnectFallbackTests\|LoLaUdpMediaSocketTests\|LoLaCompatibilityMediaSessionTests\|LoLaCompatibilityTcpControlTests\|MadiFullDuplexSessionTests' --no-parallel` | Passed: 48 tests covering LoLa bind-before-transmit TX/RX, fd-set guards, recvfrom timeout/error distinction, retry responder reporting, UDP bind cleanup, and MADI RX-buffer profile propagation. |
| `swift test --filter 'PeerSessionAVSupportTests\|AppShellSourceContractTests\|ReleaseArtifactHygieneContractTests' --no-parallel` | Passed: 19 tests covering visible preview selection, UI truthfulness contracts, command intent labels, and release candidate docs/hygiene behavior. |
| `swift test --filter VerificationToolingContractTests --no-parallel` | Passed: 7 tests after restoring explicit UltraGrid image override documentation in the helper scripts. |
| `ruff check .` | Passed. |
| `python -m pytest -q` | Passed: 30 passed, 2 skipped, no pytest-asyncio loop-scope warning. |
| `bash scripts/verify-release-hygiene.sh` | Passed with `VERDICT: PASS`. |
| `bash scripts/verify-docs.sh` | Passed in the raw checkout after the public-candidate verifier split. |
| `shellcheck -x scripts/export-release-candidate.sh scripts/verify-release-hygiene.sh scripts/verify-docs.sh scripts/lib/common.sh` | Passed after release verifier/export changes. |
| `shellcheck -x scripts/*.sh scripts/lib/*.sh` | Passed after the UltraGrid policy/script updates. |
| `python -m mypy --strict linux_connector` | Passed: no issues in 13 source files. |
| `.build/debug/open-lola not-a-command` | Passed negative CLI probe: exit 1 with usage and `error: invalid argument: not-a-command`. |
| `.build/debug/open-lola direct-p2p-session-run --bad` | Passed negative CLI probe: exit 1 with `error: invalid argument: unknown --bad`. |
| `.build/debug/open-lola --help` | Passed help probe: exit 0 with inventory-backed command list. |
| `.build/debug/open-lola session-capabilities` | Passed CLI surface probe with `VERDICT: PASS`. |
| `script/build_and_run.sh --verify` | Passed app surface probe after fixing the previous `AppPreviewReceiverState.visibleStreams` Observation recursion. |
| Generated/local artifact cleanup probe | Passed after cleanup: no root `.build`, `.build-gap6`, Python cache, `dist`, `.DS_Store`, root `LastSsn.ssn`, or root `LolaGui.ini`; only documented internal `win-compiled/2-0/LastSsn.ssn` and `win-compiled/2-0/LolaGui.ini` remain. |
