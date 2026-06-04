# Open LoLa plan.md Missed Remediation Ledger

Date: 2026-05-22

Source of truth: `plan.md`.

Purpose: this ledger converts the remaining `plan.md` misses from
`plan-verification-ledger.md` into actionable remediation slices. It is separate
from `plan-remediation-ledger.md`, which tracks `final-plan.md` slices and does
not enumerate every section-qualified `plan.md` issue.

Overall state: `EXTERNAL_BLOCKED`.

Status vocabulary:
- `NOT_STARTED`: no remediation work has begun for this missed slice.
- `PARTIAL`: some source/test work exists, but the plan issue is not closed.
- `DEFERRED_DESIGN`: unsafe or too broad without a separate design decision.
- `EXTERNAL_BLOCKED`: needs hardware, sanitizer runtime, or live peer proof.
- `VERIFIED`: source/test/hardware proof closes the slice.

## Slice Summary

| Slice ID | Priority | plan.md refs | Status | Remediation outcome | Required proof |
|---|---:|---|---|---|---|
| PMR-00 | P1 | all `plan.md` issues | VERIFIED | Reconcile `plan.md` findings into a canonical section-qualified ledger. | `plan-verification-ledger.md` plus this PMR ledger enumerate remaining section-qualified misses. |
| PMR-01 | P2 | `RT-AUDIO-002` | VERIFIED | Decide and enforce realtime ownership for `RealtimeAudioPacketHandoffRuntime` locking. | Host-thread-only wrapper contract plus source test proving no production use. |
| PMR-02 | P2 | `RT-AUDIO-004` | VERIFIED | Remove realtime-adjacent force unwrap in capture-ring buffer-list access. | Unit test for guarded invariant. |
| PMR-03 | P2 | `RT-AUDIO-005` | VERIFIED | Replace stale-packet accounting precondition crash with typed metric/error behavior. | Regression that corrupt accounting cannot crash. |
| PMR-04 | P0 | Pass 3 `RT-AUDIO-005` | EXTERNAL_BLOCKED | Prove CoreAudio IOProc stop/destroy quiescence on real hardware and sanitizer where possible. | Hardware stress artifact plus ASan/TSAN result or documented sanitizer blocker. |
| PMR-05 | P2 | Pass 6 `TEST-005` | VERIFIED | Add a deadline-bound callback timing test, not only non-negative counter checks. | Test asserts callback max under buffer-period threshold. |
| PMR-06 | P2 | `UDP-NET-002`, control replay | VERIFIED | Define and implement control-message sequence/replay policy or explicitly document omission. | Session-bound replay policy documented and tested. |
| PMR-07 | P2 | Pass 6 `TEST-004` | VERIFIED | Add UDP transport-level non-zero jitter integration coverage. | Controlled transit-variation test through `UdpMediaTransport`. |
| PMR-08 | P2 | `P2P-003` | VERIFIED | Classify P2P shutdown cleanup errors and stop swallowing runtime-owned failures. | `PeerSessionRunner.shutdown(reason:)` is non-throwing and source tests reject production `try? shutdown` cleanup. |
| PMR-09 | P1 | `P2P-STATE-002`, `CTRL-001`, `CTRL-003` | VERIFIED | Close unverified P2P control-plane edge cases. | Simultaneous proposal, serialized ownership policy, and control-drain tests. |
| PMR-10 | P1 | `VIDEO-001`, `VIDEO-002` | VERIFIED | Keep product verdict truthful while implementing or explicitly deferring Blackmagic/multistream readiness. | Active docs and source tests keep DeckLink/multistream readiness as explicit `PARTIAL` gaps without hardware evidence. |
| PMR-11 | P2 | `VIDEO-004` | VERIFIED | Move AVFoundation capture start/stop off the caller path. | `VideoCaptureSessionWorkQueue` dispatches start asynchronously and serializes stop. |
| PMR-12 | P2 | `VIDEO-006`, Pass 6 `TEST-006` | VERIFIED | Test production-default video reassembler expiry under sustained loss. | Default 250 ms expiry regression with controllable receive time. |
| PMR-13 | P2 | `RXBUF-003`, `RXBUF-006`, P3-RXBUF-001 | VERIFIED | Decide generic RX overrun and stale-video policy without changing latency semantics casually. | Stale-video threshold now drives AV sync drops; generic RX/MADI overrun behavior remains runtime-specific and documented. |
| PMR-14 | P2 | `RXBUF-005`, Pass 3 `RX-001` | EXTERNAL_BLOCKED | Prove live RX drift correction and playout payload behavior. | Hardware-grade RX/drift/packet-loss artifact. |
| PMR-15 | P2 | `MADI-002` | VERIFIED | Decide whether remaining CoreAudio `AudioObject*` APIs are accepted public API use or deprecated risk. | Accepted macOS 14 compatibility boundary documented in source/docs and tested. |
| PMR-16 | P1 | `MADI-001`, `MADI-004`, `MADI-007` hardware proof | EXTERNAL_BLOCKED | Field-prove MADI UID handoff, capability checks, and peer readiness on physical two-peer RME hardware. | Two-peer MADI full-duplex artifact with distinct input/output UIDs. |
| PMR-17 | P2 | `UI-NAV-002` | VERIFIED | Add keyboard shortcuts for high-frequency operator actions. | Validate, write-plan, dry-run, arm, refresh, and preview menu shortcuts declared and parser-supported. |
| PMR-18 | P2 | `UI-SESSION-002` | VERIFIED | Add direct unavailable-reason help to JackTrip/UltraGrid transport status. | Status pill help now returns `unavailableAppReason` for both unsupported connector modes. |
| PMR-19 | P2 | `UI-STREAM-002` | VERIFIED | Remove inert preview controls or replace them with non-control status text. | Receiver/settings surfaces now render unsupported local preview items as status copy, not disabled inputs. |
| PMR-20 | P2 | `UI-STATE-005` | VERIFIED | Gate preview control activity on verified active state only. | Partial-preview failure test keeps monitor controls disabled. |
| PMR-21 | P2 | `UI-SET-002` | VERIFIED | Remove or wire settings-surface policy constants. | Stale settings-surface constants removed and source regression prevents reintroduction. |
| PMR-22 | P2 | `UI-PREVIEW-001` | VERIFIED | Surface actual preview window/controller state in the main operator window. | Preview window request, visible, and hidden phases are tracked and shown separately from device preview health. |
| PMR-23 | P1 | `TEST-001`, `TEST-002` | EXTERNAL_BLOCKED | Run live LoLa media-session and real CoreAudio runtime tests. | Recorded artifacts from live peer/device runs. |
| PMR-24 | P2 | Pass 6 `TEST-007` | VERIFIED | Add integrated AV degraded-network behavior coverage. | Deterministic loss/reorder/jitter overlay feeds integrated AV report assertions. |
| PMR-25 | P1 | Pass 6 verification contract | VERIFIED | Rerun the full verification matrix after source fixes. | Local source gate passed; product-runtime release verdict remains `PARTIAL` only for manual external gates. |
| PMR-26 | P2 | `DEDUP-002`, `STRUCT-003` | VERIFIED | Revisit connector parallel structure and report splitting only with a behavior-preserving design. | Source-contract boundary preserves connector/P2P report ownership until a documented migration has compatibility tests. |

## Detailed Remediation Steps

### PMR-00 - Canonical plan.md coverage reconciliation

- Status: `VERIFIED` on 2026-05-22.
- Outcome: every unresolved `plan.md` finding has one canonical row, including
  duplicate IDs reused across audit passes.
- Inspect: `plan.md`, `plan-verification-ledger.md`,
  `plan-remediation-ledger.md`, `plan-remediation-status.md`.
- Steps:
  1. Extract all finding IDs from `plan.md`, preserving section/pass context.
  2. Map each ID to `ADDRESSED`, `OPEN`, `PARTIAL`, `DEFERRED_DESIGN`, or
     `EXTERNAL_BLOCKED`.
  3. Preserve conflicts where the same short ID means different findings in
     different passes.
  4. Update this ledger and status docs rather than folding these rows into the
     `final-plan.md` ledger.
- Verification: `bash scripts/verify-docs.sh`; `git diff --check`.
- Done when: no remaining `plan.md` issue depends on implicit inference from
  `final-plan.md` row names.
- Evidence: `plan-verification-ledger.md` now names the remaining
  section-qualified `plan.md` misses as PVL rows, and this ledger maps those
  rows into PMR remediation slices while preserving external/deferred status.
  `PVL-COVERAGE-001` is marked `ADDRESSED`; individual open PMR rows remain
  active.

### PMR-01 - Realtime handoff NSLock ownership

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `RealtimeAudioPacketHandoffRuntime` is now explicitly documented as a
    host-thread convenience wrapper that must not be called from realtime audio
    callbacks.
  - `realtimeAudioPacketHandoffRuntimeLockIsNotUsedByProductionRealtimeSources`
    scans `Sources/` and fails if any production source outside
    `RealtimeAudioPacketHandoff.swift` references the locked runtime wrapper.
  - Focused and owning test suites passed:
    `swift test --filter realtimeAudioPacketHandoffRuntimeLockIsNotUsedByProductionRealtimeSources`
    and `swift test --filter RealtimeAudioPacketHandoffTests`.
- Outcome: `RealtimeAudioPacketHandoffRuntime` is either proven off the IOProc
  path or rewritten so realtime callbacks do not take `NSLock`.
- Inspect: `RealtimeAudioPacketHandoff.swift`, realtime graph callbacks,
  MADI/Direct P2P audio handoff callers, `RealtimeAudioPacketHandoffTests`.
- Steps:
  1. Trace every `RealtimeAudioPacketHandoffRuntime` construction and call site.
  2. If runtime callbacks call it, replace the path with an SPSC or preallocated
     nonblocking handoff and keep locks on non-realtime control paths only.
  3. If callbacks do not call it, add a source-level ownership test or inventory
     check documenting that boundary.
- Verification: focused handoff/realtime tests, `swift test --filter
  RealtimeAudioPacketHandoffTests`, `swift test --filter DirectPeerRealtimeAudioGraphTests`.
- Risk: high if this touches callback ownership; no blocking or allocation may
  move into the IOProc path.

### PMR-02 - Capture-ring force unwrap removal

- Status: `VERIFIED` on 2026-05-22.
- Outcome: buffer-list offset access is guarded or proven as a local invariant
  without a force unwrap in runtime-adjacent code.
- Inspect: `RealtimeAudioPayloadCaptureRing.swift`,
  `DirectPeerRealtimeAudioGraphCallbacks.swift`, capture-ring tests.
- Steps:
  1. Replace `MemoryLayout<AudioBufferList>.offset(of: \.mBuffers)!` with a
     guarded static helper.
  2. Return an explicit invalid/drop result if the offset is unavailable.
  3. Add a source-policy or unit regression that prevents reintroducing the force
     unwrap in capture-ring buffer-list access.
- Verification: capture-ring/realtime tests plus `CodeLineBudgetTests`.
- Done when: no `!` unwrap remains for `mBuffers` offset in the capture ring.
- Evidence: `RealtimeAudioBufferListReader` now returns `nil` for invalid
  index/offset access; `pushAudioBuffers`, `audioBufferForCopy`, and
  `bufferLocation` propagate invalid input as dropped-invalid instead of
  trapping. `realtimeAudioCaptureRingBufferListAccessAvoidsForceUnwrapAndTrapSource`
  passed.

### PMR-03 - Stale-packet accounting underflow

- Status: `VERIFIED` on 2026-05-22.
- Outcome: stale packet accounting mismatch cannot crash the process.
- Inspect: `RealtimeAudioBuffers.swift`, `RealtimeAudioPacketHandoff.swift`,
  realtime buffer tests.
- Steps:
  1. Replace the `precondition(bufferedPackets >= dropped, ...)` path with an
     explicit metric such as accounting underflow detected.
  2. Clamp internal counters without hiding the invalid state.
  3. Add a regression that forces inconsistent accounting through the narrowest
     test hook available and asserts no crash plus an invalid metric.
- Verification: `swift test --filter RealtimeAudio`, `swift test --filter
  DirectPeerRealtimeAudioGraphTests`.
- Risk: medium; preserve drop/latency behavior and only change impossible-state
  reporting.
- Evidence: `RealtimeAudioFixedTargetJitterBuffer` now records
  `packetAccountingUnderflows`, clamps the internal packet count, and marks
  hidden playout growth instead of using `precondition` on stale-drop or
  playout decrement underflow. `fixedTargetJitterBufferReportsAccountingUnderflowWithoutCrash`
  and `swift test --filter fixedTargetJitterBuffer` passed.

### PMR-04 - CoreAudio IOProc hardware and sanitizer proof

- Outcome: source-level lifecycle fixes are backed by real runtime evidence.
- Inspect: `docs/testing.md`, CoreAudio lifecycle tests, hardware run scripts.
- Steps:
  1. Re-run the IOProc lifecycle tests under ASan/TSAN after sanitizer runtime
     policy is fixed.
  2. Run start/stop stress on real CoreAudio hardware with callback activity.
  3. Record artifacts and keep verdict `PARTIAL` until evidence exists.
- Verification: sanitizer command results, hardware stress report, docs update.
- Proof bundle gate: `bash scripts/verify-pmr-external-proof-bundle.sh
  <bundle-dir>` validates `pmr-04/realtime-audio-engine.json` and
  `pmr-04/sanitizer-result.txt` when real artifacts are available. The gate
  requires measured RME MADI realtime evidence, `audioDeviceIOProc` callback
  ownership, UDP setup before start, report writing after stop, completed
  shutdown, nonzero handoff counters, and either `ASAN: PASS` plus `TSAN: PASS`
  or a documented `SANITIZER_RUNTIME_BLOCKED: <reason>`.
- Local guardrail: `pmrExternalProofBundleScriptRejectsWeakExternalArtifacts`
  executes the proof-bundle script with a PMR-04 realtime report using synthetic
  callback ownership and proves the bundle is rejected before final
  `VERDICT: PASS`; the same test proves the old generic `VERDICT: PASS`
  sanitizer text is not sufficient.
- Blocker: local dyld/Xcode sanitizer policy previously rejected sanitizer
  dylibs before test execution.

### PMR-05 - Realtime callback deadline test

- Status: `VERIFIED` on 2026-05-22.
- Outcome: callback timing tests assert an actual deadline, not only
  non-negative counters.
- Inspect: `DirectPeerRealtimeAudioGraphTests.swift`,
  `DirectPeerRealtimeAudioGraphTimingTests.swift`.
- Steps:
  1. Define a source-level deadline from frames per buffer and sample rate.
  2. Use an injected timing source or deterministic callback hook.
  3. Assert `callbackMaxMicroseconds` stays below the selected bound.
- Verification: focused timing test and broader realtime graph tests.
- Risk: avoid wall-clock flaky tests; prefer injected timing.
- Evidence: `directPeerRealtimeAudioGraphCallbackTimingCountersCoverMaxChannelFrameShape`
  now injects deterministic callback ticks and asserts
  `callbackMaxMicroseconds < framesPerBuffer * 1_000_000 / sampleRate` with no
  deadline miss. `swift test --filter directPeerRealtimeAudioGraphCallback`
  passed.

### PMR-06 - Control message sequence and replay policy

- Status: `VERIFIED` on 2026-05-22.
- Outcome: control messages either reject replay/out-of-order input or the
  protocol explicitly documents session-ID-only semantics.
- Inspect: `SessionControlMessage.swift`, `SessionStateMachine`,
  `PeerSessionRunner.swift`, socket runner control receive loops.
- Steps:
  1. Decide whether control messages need monotonic sequence numbers/nonces.
  2. If yes, extend message schema and add compatibility migration tests.
  3. Add duplicate, stale, and out-of-order control-message regressions.
  4. If no, document the omission and why session ID binding is sufficient.
- Verification: session protocol tests, P2P lifecycle tests, source contracts.
- Risk: schema changes are public contract changes.
- Evidence: `docs/p2p-networking.md` now documents the v1 control replay
  policy as session-bound and state-gated, with no generic control sequence
  number and no cryptographic anti-replay claim. `controlReplayPolicyIsDocumentedAsSessionBoundAndIdempotent`
  covers duplicate `mediaStart` and `shutdown` idempotence under the state
  machine. `swift test --filter SessionProtocolTests` passed.

### PMR-07 - UDP transport non-zero jitter integration test

- Status: `VERIFIED` on 2026-05-22.
- Outcome: UDP transport metrics prove non-zero inter-arrival jitter through the
  transport path.
- Inspect: `UdpMediaTransportTests.swift`, jitter aggregation code.
- Steps:
  1. Build a deterministic receive timing hook or controlled packet timestamps.
  2. Send packets with non-uniform inter-arrival deltas.
  3. Assert transport metrics report non-zero jitter and expected direction.
- Verification: focused UDP transport test and full UDP filter.
- Risk: avoid sleep-based timing flake; prefer injected timestamps.
- Evidence: `udpMediaTransportReportsNonZeroJitterAfterControlledTransitVariation`
  sends 20 packets through connected loopback `UdpMediaTransport` instances with
  controlled timestamp variation and asserts transport-level non-zero jitter.
  `swift test --filter udpMediaTransport` passed.

### PMR-08 - P2P shutdown cleanup errors

- Status: `VERIFIED` on 2026-05-22.
- Outcome: critical runtime shutdown failures are surfaced, while explicitly
  best-effort cleanup remains documented.
- Inspect: `PeerSessionRunner.swift`, `PeerSessionRunnerLoopbackPair.swift`,
  socket runners using `try? shutdown`.
- Steps:
  1. Classify each `try? shutdown` as best-effort test cleanup, defer cleanup,
     or runtime-owned cleanup.
  2. For runtime-owned cleanup, report or aggregate failures.
  3. Add tests for failure propagation where cleanup matters.
- Verification: P2P runner/lifecycle tests.
- Risk: do not make defer cleanup mask the original runtime error.
- Evidence: `PeerSessionRunner.shutdown(reason:)` now matches its actual
  synchronous close behavior and no longer throws. Production P2P runner
  cleanup calls no longer use `try? shutdown`, and
  `peerSessionShutdownCleanupDoesNotSilentlyDiscardProductionP2PErrors` scans
  `Sources/OpenLolaCore/Network/P2P` to prevent reintroducing swallowed
  shutdown cleanup errors. `swift test --filter
  peerSessionShutdownCleanupDoesNotSilentlyDiscardProductionP2PErrors` and
  `swift test --filter PeerSessionRunnerLifecycleTests` passed.

### PMR-09 - P2P control-plane edge cases

- Status: `VERIFIED` on 2026-05-22.
- Outcome: unverified simultaneous proposal, concurrency guard, and receive-loop
  error semantics are either implemented or explicitly deferred.
- Inspect: `PeerSessionRunner.swift`, `SessionStateMachine`,
  `DirectPeerSessionSocketRunner.swift`, P2P lifecycle tests.
- Steps:
  1. Add a simultaneous proposal harness and record current behavior.
  2. Decide whether `PeerSessionRunner` remains single-thread-owned; if so, add
     a source/test guard documenting it.
  3. Test `receiveControlMessages` behavior when one message fails in a batch.
  4. Implement deterministic resolution or document unsupported semantics.
- Verification: focused lifecycle/control tests.
- Risk: control-state behavior affects live P2P setup; avoid compatibility
  changes without tests.
- Evidence: `peerSessionRejectsSimultaneousProposalWithoutAcceptingEitherSide`
  proves simultaneous proposals fail closed without accepting either side.
  `docs/p2p-networking.md` documents serialized ownership for
  `PeerSessionRunner` instead of claiming internal synchronization.
  `directPeerAVControlDrainStopsOnCurrentShutdownAndIgnoresStaleShutdown` now
  drains stale and current shutdown datagrams in one service pass, dropping the
  stale control message and stopping on the current one. `swift test --filter
  PeerSessionRunnerLifecycleTests` passed.

### PMR-10 - Blackmagic and multistream readiness boundary

- Status: `VERIFIED` on 2026-05-22.
- Outcome: no UI/report claims imply DeckLink or multistream field readiness
  without real implementation and proof.
- Inspect: `BlackmagicOutputBoundary.swift`, video transport/multistream files,
  app preview output copy, docs/video docs.
- Steps:
  1. Decide whether to implement DeckLink enumeration/output now or keep a
     documented `PARTIAL` boundary.
  2. If implementing, add hardware enumeration, output path, and proof artifacts.
  3. For multistream, distinguish source-level negotiation from production-ready
     runtime proof.
- Verification: Blackmagic tests, video transport tests, hardware proof if
  implementation is attempted.
- Blocker: physical Blackmagic hardware and SDK availability for field proof.
- Evidence: `docs/video-blackmagic-atem.md` states DeckLink output is not
  linked, localhost probes remain `PARTIAL`, multi-stream staging is
  source-level only, and physical Blackmagic/ATEM hardware evidence remains
  pending. `BlackmagicOutputBoundary.detect()` and `localPreviewFallback()`
  report `PARTIAL` unless physical DeckLink evidence exists.
  `receiveRenderSyntheticSmokeAndBlackmagicBoundaryRequirePhysicalEvidence`,
  `videoTransportReportRejectsInvalidPassEvidence`,
  `multiVideoMetricsRejectDuplicateStreamCounters`, and
  `appPreviewVideoOutputStatusReflectsSelectedBlackmagicInventory` passed.

### PMR-11 - AVFoundation capture start threading

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `AVFoundationVideoCaptureRunner.run` now calls `AVFoundationCaptureSessionHandle.startRunning()`
    and `stopRunning()` instead of invoking `AVCaptureSession.startRunning()`
    and `stopRunning()` directly on the caller path.
  - `VideoCaptureSessionWorkQueue` dispatches start work asynchronously on a
    dedicated serial queue and serializes stop behind any pending start work.
  - `videoCaptureSessionStartDispatchesOffCallerQueueAndSerializesStop` proves
    a blocked start operation returns to the caller before the operation is
    released, then verifies stop work is serialized through the same queue.
  - Focused and owning test suites passed:
    `swift test --filter videoCaptureSessionStartDispatchesOffCallerQueueAndSerializesStop`
    and `swift test --filter VideoCaptureReportTests`.
- Outcome: `AVCaptureSession.startRunning()` does not block the caller path.
- Inspect: `VideoCaptureRunner.swift`, `VideoCaptureAVFoundation.swift`, capture
  runner tests.
- Steps:
  1. Move start/stop session work to a dedicated serial capture session queue.
  2. Ensure configuration changes remain serialized with start/stop.
  3. Add instrumentation or a test double proving caller return is bounded.
- Verification: video capture tests and any app/bundle preview smoke available.
- Risk: AVFoundation session mutation must stay on one queue.

### PMR-12 - Production-default video reassembler expiry

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `VideoFrameReassembler` now has a DEBUG-only receive-time injection path
    for tests while production callers still stamp received fragments with
    `DispatchTime.now().uptimeNanoseconds`.
  - `videoFrameReassemblerExpiresIncompleteFramesAtProductionDefaultAge`
    exercises the default 250 ms expiry boundary without sleeps: an incomplete
    frame is retained at exactly the threshold and evicted at threshold + 1 ns.
  - Focused and owning test suites passed:
    `swift test --filter videoFrameReassemblerExpiresIncompleteFramesAtProductionDefaultAge`
    and `swift test --filter VideoTransportReportTests`.
- Outcome: incomplete frame buckets are evicted under sustained loss using the
  production default, not only a zero-age fixture.
- Inspect: `VideoTransportReassembly.swift`, `VideoTransportReportTests.swift`,
  `VideoTransportRunner.swift`.
- Steps:
  1. Add a controllable clock or explicit received-time inputs if needed.
  2. Create fragments that remain incomplete beyond the default 250 ms age.
  3. Assert stale frame eviction and missing-fragment metrics.
- Verification: video transport report/reassembly tests.
- Risk: do not add slow sleeps to the suite.

### PMR-13 - RX buffer stale-video and overrun policy

- Status: `VERIFIED` on 2026-05-22.
- Outcome: generic RX corrective behavior is designed before code changes alter
  latency/drop semantics.
- Inspect: `MediaClock.swift`, `RxBuffering.swift`, direct graph/MADI overrun
  handling, docs/rx-buffering.
- Steps:
  1. Write a short policy note comparing current direct graph and MADI behavior.
  2. Decide whether stale video threshold remains report-only or drives drops.
  3. Add targeted tests only after policy is explicit.
- Verification: docs verifier, RxBuffering/realtime/MADI tests if code changes.
- Evidence: `AVTimestampAligner.decision` now uses
  `AVSyncPolicy.staleVideoDropThresholdMicroseconds` before dropping video
  behind audio. `docs/rx-buffering.md` records the boundary: AV stale-video
  drops are runtime-specific, direct P2P AV derives the threshold from the
  selected frame interval, and MADI/realtime audio overruns remain on their
  own bounded drop/telemetry policies instead of a generic hidden-growth path.
  `balancedAVUsesStaleVideoThresholdBeforeDroppingBehindAudio` and
  `swift test --filter AVTimestampAlignmentTests` passed.

### PMR-14 - Live RX drift and playout proof

- Outcome: RX drift correction and payload playout behavior are proven beyond
  synthetic/source tests.
- Inspect: drift PLC, direct P2P AV runtime, MADI receive, evidence scripts.
- Steps:
  1. Run a controlled packet-loss/jitter/reorder session with real or
     hardware-grade endpoints.
  2. Capture RX playout, drift telemetry, dropped/late metrics, and verdict.
  3. Keep product verdict `PARTIAL` until artifacts exist.
- Verification: recorded evidence report and validator command.
- Proof bundle gate: `bash scripts/verify-pmr-external-proof-bundle.sh
  <bundle-dir>` validates RX benchmark, drift certification, direct P2P session,
  and direct P2P evidence-bundle artifacts for PMR-14. The gate requires a
  `pass` physical-reference RX benchmark with a direct row marked
  `fastestPassEligible`, measured `pass` drift certification with measured LoLa
  baseline on the same hardware/route and an `openLolaFaster` or
  `openLolaEquivalent` result, `pass` physical two-peer P2P evidence with packet
  capture, DSCP, and clock artifacts, nonzero sent/received/routed/queued audio
  payload counts, and zero explicit loss/drop/underrun/deadline counters.
- Local guardrail: `pmrExternalProofBundleScriptRejectsWeakExternalArtifacts`
  executes the proof-bundle script with a PMR-14 direct P2P report that records
  zero `audioPayloadsQueuedForPlayout`, proving the bundle is rejected before
  final `VERDICT: PASS`.
- Blocker: live devices or deterministic external harness.

### PMR-15 - CoreAudio API compatibility decision

- Status: `VERIFIED` on 2026-05-22.
- Outcome: remaining `AudioObject*` calls are either accepted, wrapped with a
  compatibility note, or replaced.
- Inspect: CoreAudio inventory/routing/app preview services.
- Steps:
  1. Classify every `AudioObjectGetPropertyData*` and `AudioObjectSetPropertyData`.
  2. Check current Apple API availability and whether a newer public API exists.
  3. Update docs/source comments or implementation accordingly.
- Verification: CoreAudio inventory tests, live device inventory smoke.
- Risk: CoreAudio API changes may affect hardware enumeration and routing.
- Evidence: Apple Developer documentation still exposes the public
  `AudioObjectGetPropertyData`, `AudioObjectGetPropertyDataSize`, and
  `AudioObjectSetPropertyData` HAL functions, while the local Xcode 26.3 macOS
  26.2 SDK reports `AudioHardwareObject` as macOS 15+. Because `Package.swift`
  targets macOS 14, `docs/audio-rme-madi.md` now records the accepted
  compatibility boundary and both remaining helper files carry the same source
  note. `coreAudioHALPropertyAccessDecisionDocumentsMacOS14CompatibilityBoundary`,
  `swift test --filter coreAudioHALPropertyAccessDecisionDocumentsMacOS14CompatibilityBoundary`,
  and `swift test --filter CoreAudioInventoryTests` passed.

### PMR-16 - Physical MADI proof

- Outcome: MADI source/test fixes are field-proven with physical RME hardware.
- Inspect: MADI full-duplex runner, socket runner, router, docs/audio-rme-madi.
- Steps:
  1. Run two-peer MADI full duplex with distinct input/output CoreAudio UIDs.
  2. Confirm capability validation, readiness exchange, TX/RX packet counts, and
     teardown.
  3. Validate generated report and update status without promoting unsupported
     evidence.
- Verification: MADI report artifact, validator, hardware notes.
- Proof bundle gate: `bash scripts/verify-pmr-external-proof-bundle.sh
  <bundle-dir>` validates the physical `madi-full-duplex.json` report and
  hardware notes for PMR-16, including non-empty and distinct input/output
  UIDs, peer-readiness exchange, teardown completion, packet-capture notes,
  distinct two-peer hosts, and nonzero TX/RX/rendered MADI packet-block metrics.
- Local guardrail: `pmrExternalProofBundleScriptRejectsWeakExternalArtifacts`
  executes the proof-bundle script with identical PMR-16 input/output UID notes
  and with zero completed/rendered MADI receive blocks, proving both weak
  bundles are rejected before final `VERDICT: PASS`.
- Blocker: physical two-peer RME MADI setup.

### PMR-17 - Operator keyboard shortcuts

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `NativeAppShellActionInventory.menuActions` now declares shortcuts for the
    high-frequency operator actions: refresh source/synthetic, arm execution,
    write two-peer plan, dry run supervisor, validate supervisor report, and
    open local preview.
  - `AppMenuShortcut` now parses the newly declared shortcut strings used by
    the contract, and `AppExecutionSettingsShortcutCopy` surfaces the validate
    shortcut from the default action inventory.
  - `appOperatorMenuActionsDeclareSupportedShortcuts` verifies the action
    contract and parser stay aligned.
  - Focused and owning test suites passed:
    `swift test --filter appOperatorMenuActionsDeclareSupportedShortcuts`,
    `swift test --filter appValidationShortcutCopyRequiresMenuContractShortcut`,
    `swift test --filter AppMenuRenderingTests`, and
    `swift test --filter AppShellSlice05Tests`.
- Outcome: high-frequency app menu actions have keyboard shortcuts.
- Inspect: `OpenLolaApp.swift`, menu surface contract tests.
- Steps:
  1. Pick non-conflicting shortcuts for validate, arm, write plan, preview, and
     any remaining operator-critical actions.
  2. Add tests for shortcut parsing/rendering.
  3. Build or smoke the app menu when practical.
- Verification: menu rendering tests, app build/bundle smoke.

### PMR-18 - Unsupported connector reason in transport status

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `AppTransportView` now applies `statusModeHelp` to the transport mode
    status badge, and `AppTransportStatusModePolicy.help` returns
    `sessionMode.unavailableAppReason` for unavailable connector modes.
  - `appTransportUnavailableConnectorStatusExplainsReason` covers both
    JackTrip and UltraGrid titles plus their operator-facing unavailable
    reasons.
  - Focused and owning test suites passed:
    `swift test --filter appTransportUnavailableConnectorStatusExplainsReason`
    and `swift test --filter AppShellTransportMenuPolicyTests`.
- Outcome: JackTrip/UltraGrid status pills explain why they are unavailable.
- Inspect: `AppTransportView.swift`, session mode availability policy, app tests.
- Steps:
  1. Surface `sessionMode.unavailableAppReason` as help or adjacent secondary
     copy on the transport status row.
  2. Add a policy test for both connector modes.
- Verification: AppShell transport/menu tests and app build.

### PMR-19 - Inert preview controls

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `AppPreviewReceiverView` no longer renders Return blend, Visible streams,
    or Selected stream as disabled controls; it keeps the existing unsupported
    local-preview status copy.
  - `AppPreviewSettingsTab` no longer accepts or renders bindings for those
    unsupported controls, and still shows the single-stream limitation through
    `AppPreviewDisabledReasonCopy.unsupportedLocalPreviewControls`.
  - `appPreviewUnsupportedLocalControlsRenderAsStatusCopyNotInputs` prevents
    these controls from reappearing as `Slider`/`IntField` inputs in the
    receiver/settings source.
  - Focused and owning test suites passed:
    `swift test --filter appPreviewUnsupportedLocalControlsRenderAsStatusCopyNotInputs`,
    `swift test --filter AppShellUIPolicyTests`, and
    `swift test --filter AppShellSlice05Tests`.
- Outcome: controls that cannot be used in local preview are not presented as
  ordinary disabled controls.
- Inspect: `AppPreviewReceiverView.swift`, settings tabs, preview tests.
- Steps:
  1. Replace Return blend / Visible streams / Selected stream controls with
     static status copy, or hide them until supported.
  2. Keep the single-stream limitation discoverable.
  3. Add tests preventing always-disabled controls from rendering as controls.
- Verification: AppShell preview/UI policy tests.

### PMR-20 - Verified preview-active gate

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `AppPreviewReceiverState.previewIsActive` now requires
    `verifiedPreviewPhase == .active`; the raw preview phase can no longer
    enable monitor controls by itself.
  - `appPreviewReceiverControlsRequireVerifiedActiveServiceState` covers the
    degraded/partial preview case where raw preview activity exists but the
    verified service state is not fully active.
  - Focused and owning test suites passed:
    `swift test --filter appPreviewReceiverControlsRequireVerifiedActiveServiceState`
    and `swift test --filter AppShellUIPolicyTests`.
- Outcome: monitor controls enable only when the verified preview state is fully
  active.
- Inspect: `AppPreviewReceiverState.previewIsActive`, preview phase tests.
- Steps:
  1. Change `previewIsActive` to use verified active state only.
  2. Add degraded/partial preview tests where one service fails and controls
     remain disabled.
- Verification: AppShell slice/preview tests.

### PMR-21 - Settings policy constants

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `AppShellSettingsSurfacePolicy` was removed from
    `AppShellSectionViews.swift`; the remaining settings-section test now
    asserts the actual read-only contract instead of literal policy constants.
  - `appSettingsSurfaceDoesNotUseStalePolicyConstants` checks that the stale
    enum and constant names do not reappear in the source file.
  - Focused and owning test suites passed:
    `swift test --filter appSettingsSurfaceDoesNotUseStalePolicyConstants`,
    `swift test --filter AppShellUIPolicyTests`, and
    `swift test --filter AppShellSlice05Tests`.
- Outcome: settings surface policy constants either drive behavior or disappear.
- Inspect: `AppShellSectionViews.swift`, settings views/tabs, tests.
- Steps:
  1. Find all reads of `AppShellSettingsSurfacePolicy`.
  2. If unused, remove constants and stale tests that only assert their value.
  3. If useful, wire them into actual view branching.
- Verification: AppShell settings tests and code search.

### PMR-22 - Preview window state in main surface

- Status: VERIFIED on 2026-05-22.
- Evidence:
  - `AppPreviewReceiverState` now tracks `previewWindowPhase` separately from
    device preview health, with explicit request, visible, and hidden states.
  - The Open LoLa menu marks the preview window as requested before calling
    `openWindow(id: "receiver")`; `AppReceiverWindowView` marks actual visible
    and hidden states from `onAppear`/`onDisappear`.
  - `AppPreviewReceiverView` surfaces `Preview window` status in the main
    preview routing panel, and the receiver window shows the same window status
    in its local status panel.
  - `appPreviewWindowStateReportsRequestVisibleAndHiddenPhases`,
    `appPreviewWindowRequestFeedbackDoesNotClaimDisplaySuccess`, and
    `swift test --filter AppShellTransportMenuPolicyTests` passed.
- Outcome: the main operator window reports actual preview controller state, not
  only request-sent copy.
- Inspect: `AppPreviewReceiverView.swift`, preview controller, root surface.
- Steps:
  1. Bind `AppVideoPreviewController.phase/status` into the main preview panel.
  2. Distinguish requested, starting, active, degraded, failed, and closed.
  3. Add tests for request without confirmed display.
- Verification: AppShell preview tests and app window smoke if available.

### PMR-23 - Live LoLa and CoreAudio test gaps

- Outcome: synthetic-only LoLa/CoreAudio gaps have recorded external evidence or
  remain explicitly blocked.
- Inspect: LoLa compatibility tests, realtime audio tests, docs/testing.
- Steps:
  1. Run live LoLa media session against a real peer.
  2. Run real CoreAudio runtime tests beyond fixture-only paths.
  3. Validate artifacts and record exact commands/results.
- Verification: live reports and validators.
- Proof bundle gate: `bash scripts/verify-pmr-external-proof-bundle.sh
  <bundle-dir>` validates a bidirectional live LoLa media-session, completed
  `audio-loopback-run` CoreAudio report with no IOProc preflight blockers, and
  recording-session artifacts for PMR-23. The gate now also parses the LoLa
  JSON to require a non-loopback live peer, distinct local/peer hosts, nonzero
  sent bytes, expected datagrams, audio frames, wire bytes, and envelope
  validation, and parses the CoreAudio JSON to require RME MADI preflight,
  `audioDeviceIOProc`, callback interval samples, nonzero handoff counters,
  completed handoff shutdown, and empty cleanup failures.
- Local guardrail: `pmrExternalProofBundleScriptRequiresLiveAndHardwareArtifacts`
  asserts the proof-bundle script still requires the PMR-23 live-link
  predicates, the CoreAudio completed/no-blocker predicates, and the external
  validators needed by PMR-04, PMR-14, PMR-16, and PMR-23. This prevents local
  verifier drift but does not close the external row without real artifacts.
  `pmrExternalProofBundleScriptRejectsWeakExternalArtifacts` executes the
  script with a temporary bundle and fake CLI, proving weak LoLa media-session,
  loopback-peer LoLa JSON, blocked CoreAudio, zero-callback CoreAudio JSON, and
  invalid sanitizer outputs are rejected before the proof gate can print final
  `VERDICT: PASS`.
- Blocker: external peer/device availability.

### PMR-24 - Integrated AV degraded-network coverage

- Status: `VERIFIED` on 2026-05-22.
- Outcome: integrated AV degrade-first behavior is exercised under network
  degradation, not only schema validation.
- Inspect: `IntegratedAvDegradeFirstTests.swift`, UDP/media test harnesses,
  integrated AV runner.
- Steps:
  1. Add a packet-loss/reorder/jitter injection path at the narrowest viable
     layer.
  2. Run an integrated AV report through degradation.
  3. Assert report fields and verdict reflect degradation before audio impact.
- Verification: focused integrated AV test and report validation.
- Risk: keep test deterministic; avoid wall-clock network flake.
- Evidence: `IntegratedAvNetworkDegradation.apply(impairment:to:)` applies
  deterministic `RxImpairmentSimulator` loss/reorder/jitter output to a
  measured `VideoTransportReport` before integrated AV aggregation.
  `integratedAvRunAggregatesDegradedNetworkBeforeAudioImpact` runs the
  socket-backed video transport path, overlays packet loss, fragment loss,
  reorder, late delivery, and jitter, then asserts the integrated AV report
  keeps audio callback/target metrics unchanged while video drops/late frames
  and degradation-before-audio-impact evidence are present. `swift test
  --filter integratedAvRunAggregatesDegradedNetworkBeforeAudioImpact`,
  `swift test --filter IntegratedAvDegradeFirstTests`,
  `swift test --filter IntegratedAvRunAggregationTests`, and `swift test
  --filter IntegratedAvReportTests` passed.

### PMR-25 - Full verification matrix

- Status: `VERIFIED` on 2026-05-22 for local source/test/release-readiness
  verification.
- Outcome: after source remediation, the full `plan.md` verification contract is
  either passing or explicitly blocked with exact evidence.
- Commands to run when code slices land:
  - `swift build`
  - `swift build --product open-lola`
  - `swift build --product open-lola-app`
  - `swift test --no-parallel`
  - `bash scripts/verify-docs.sh`
  - `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
  - `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
  - `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`
  - `bash scripts/verify-release-hygiene.sh`
  - `bash script/build_and_run.sh --verify`
- Also rerun sanitizer and manual hardware checks where relevant.
- Done when: final status names every skipped command with reason and risk.
- Evidence:
  - `git diff --check` passed.
  - `swift build` passed after rerun outside the sandbox because SwiftPM
    manifest sandboxing failed with `sandbox-exec: sandbox_apply: Operation not
    permitted`.
  - `swift build --product open-lola` passed.
  - `swift build --product open-lola-app` passed.
  - `swift build --product open-lola --build-path
    /private/tmp/open-lola2-swiftpm-build` passed to refresh the CLI executable
    required by machine-readable CLI tests.
  - Initial `swift test --no-parallel` failed with 20 stale-executable issues
    for `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`; after the
    explicit build-path product was refreshed, `swift test --no-parallel`
    passed with 920 tests.
  - `bash scripts/verify-docs.sh` passed.
  - `ruff check --no-cache linux_connector scripts/verify_docs
    scripts/lib/*.py` passed. The first plain `ruff check` created
    `.ruff_cache`; it was removed before release hygiene.
  - `python -m mypy --strict --cache-dir=/private/tmp/open-lola2-mypy-cache
    linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
    passed. The first plain mypy run created `.mypy_cache`; it was removed
    before release hygiene.
  - `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh
    linux_connector/env/*.sh` passed.
  - `bash scripts/verify-release-hygiene.sh` passed after generated Python
    caches were removed.
  - `bash script/build_and_run.sh --verify` passed and produced native app
    launch evidence under `dist/app-launch-evidence`.
  - `bash scripts/verify-release-readiness.sh` passed as a wrapper command:
    docs, placeholder scan, shellcheck, ruff, Python tests, mypy, release
    hygiene, `swift build`, `swift test --no-parallel`, native app launch
    probe, and release CLI probes completed. Its local `source-gate-verdict`
    was `pass`; its `product-runtime-verdict` remained `partial`.
- Skipped/unavailable: sanitizer proof and manual runtime/release gates were not
  run locally. The release-readiness wrapper names Developer ID, notarization,
  Gatekeeper, clean-Mac, hardware, and benchmark evidence as manual gates.
  CoreAudio sanitizer and hardware proof remain tracked by PMR-04, RX/live
  drift by PMR-14, physical MADI by PMR-16, and live LoLa/CoreAudio by PMR-23.

### PMR-26 - Deferred structure/design cleanup

- Status: `VERIFIED` on 2026-05-22.
- Outcome: connector parallel structure and report split decisions are handled
  only when they become justified by current code growth.
- Inspect: connector directories, `DirectPeerSessionReport`, validator files.
- Steps:
  1. Reassess actual duplication after active connector decisions.
  2. Write a behavior-preserving design before moving public surfaces.
  3. Add path/API compatibility tests before any restructure.
- Verification: source ownership/path tests, connector tests, docs verifier.
- Evidence: `docs/source-contracts.md` now records the structure boundary:
  keep LoLa, MVTP/UltraGrid, JackTrip, NMP, and preflight code under
  `Sources/OpenLolaCore/Connectors/`; keep `DirectPeerSessionReport` under
  `Sources/OpenLolaCore/Network/P2P/` while it is the direct P2P route/AV
  evidence contract; require a documented owner, schema/fixture stability, and
  path/API compatibility tests before any future move.
  `sourceOwnershipInventoryKeepsConnectorAndP2PReportStructureExplicitUntilDesignedMigration`
  and `swift test --filter SourceOwnershipInventoryTests` passed.

## Recommended Execution Order

1. PMR-04: collect CoreAudio IOProc hardware stop/destroy stress and sanitizer
   proof, or record the exact sanitizer runtime blocker.
2. PMR-14: collect live RX drift correction and playout payload evidence under
   packet loss/jitter.
3. PMR-16: collect physical two-peer RME MADI full-duplex evidence with
   distinct input/output CoreAudio device UIDs.
4. PMR-23: collect live LoLa media-session and real CoreAudio runtime artifacts.
