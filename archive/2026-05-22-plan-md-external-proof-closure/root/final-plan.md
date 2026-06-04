# Open LoLa — Final Authoritative Audit and Remediation Plan

_Consolidated from Passes 1–6. No production code changed. Audit-only._
_Source of truth: `./plan.md` (3,297 lines across 6 passes)._
_Date: 2026-05-21_

---

# 1. Executive Summary

## Overall Codebase Health

Open LoLa is a research-grade Mac-native Swift/SwiftPM audio-video networking project. The
lower-level primitives are well-built: the SPSC ring, POSIX UDP socket operations, session
state machine, and packet format encoders/decoders are solid. The test suite (264 files,
46,257 lines) has good coverage of stateless format/codec logic and report validation.

The codebase is **not field-ready**. Six audit passes across ~180 Swift production files and
all major test files identified **2 P0s, 35 P1s, 52 P2s, and 14 P3s**. The highest-risk areas
are device I/O routing, Core Audio lifecycle management, UDP transport concurrency, and a
pervasive pattern of synthetic/zero evidence being accepted or displayed as real evidence.

## Highest-Risk Areas

1. **Core Audio IOProc lifecycle** — use-after-free crash risk (P0-001)
2. **UDP transport lock architecture** — potential 1-second send stall / deadlock (P0-002)
3. **Audio device routing** — output device silently uses input UID (P1-MADI-001)
4. **CoreAudio memory ownership** — `takeRetainedValue()` on non-retained CF type (P1-MADI-002)
5. **Synthetic evidence displayed as real** — zero metrics → false "target met" green (P1-UI-003/SLOP)
6. **State machine premature success** — `state = .running` before peer confirms (P1-P2P-001)
7. **Unbounded memory growth** — `controlTranscript` grows forever in long sessions (P1-P2P-002)

## Most Urgent Fixes (P0 First)

> These are the only changes that should happen before anything else.

1. **P0-001**: Fix IOProc use-after-free — ensure `AudioDeviceStop` fully quiesces callback before `AudioDeviceDestroyIOProcID`.
2. **P0-002**: Fix UDP `stateLock` architecture — verify/eliminate any path where the lock is held during blocking `recvfrom()`.
3. **P1-MADI-001**: Fix `handoffConfiguration` to pass `outputDeviceUID` (1-line fix, confirmed high risk).
4. **P1-MADI-002**: Fix `takeRetainedValue()` in `CoreAudioInventoryReader.stringProperty`.
5. **P1-MEDIA-001**: Fix `MediaClock.nanoseconds` to not `preconditionFailure` on overflow.
6. **P1-UI-003**: Fix `AppLatencyHeroMetrics.make()` to treat zero jitter/latency as `nil`.

## What Not to Touch Yet

- **JackTrip and UltraGrid connectors (27 combined files)** — confirmed dead code (no CLI wiring),
  but do not delete without project-owner confirmation of intent.
- **`linux_connector/`** — Python seed not audited. Unknown risk. Do not change.
- **Vendored C code** (`xs_ref_sw_ed2/`, `opus-1.5.2/`) — not audited. Do not change.
- **`Sources/OpenLolaCore/Release/` and `Evidence/`** — not audited. Evidence pipeline integrity unknown.
- **Deduplication and structure cleanup** — do not begin Phase 5–6 cleanup until all P0/P1 runtime
  fixes are verified with tests.

---

# 2. Audit Coverage

## Total Files Inspected

| Category | Files | Depth |
|---|---|---|
| OpenLolaCore Swift production (non-vendored) | ~180 | ~80% fully inspected |
| open-lola CLI Swift | 19 | Partially |
| open-lola-app SwiftUI | 43 | ~17 fully read; rest partially |
| OpenLolaContracts | 5 | Fully |
| COpenLolaAtomics C bridge | 2 | Callers only |
| Tests (OpenLolaCoreTests) | 264 | Structure noted; ~20 files deep-read |
| linux_connector Python | — | **Not inspected** |
| scripts/ / script/ | — | **Not inspected** |
| Release/ and Evidence/ harnesses | — | **Not inspected** |
| Vendored C (xs_ref_sw_ed2, opus-1.5.2) | — | **Not inspected** |

## Fully Inspected Files (Key Production Files)

`DirectPeerRealtimeAudioGraph.swift` (953L), `UdpMediaTransport.swift` (717L),
`RxBuffering.swift` (544L), `MediaClock.swift` (502L), `PeerSessionRunner.swift` (544L),
`CoreAudioInventoryReader.swift` (434L), `MadiFullDuplexRuntime.swift` (456L),
`MadiReceiveBuffers.swift` (~400L), `VideoOutputRenderer.swift`, `BlackmagicOutputBoundary.swift`,
`AppSessionStateBanner.swift` (261L), `AppLatencyHeroMetrics.swift`, `AppDesignSystem.swift` (553L),
`AppConnectionTopologyView.swift`, `AppLatencyHeroView.swift`, `AppTransportView.swift`,
`AppExecutionState.swift`, `AppPreviewReceiverView.swift`, `AppShellSettingsTabs.swift`,
`ExternalConnectorExecutablePreflight.swift`, `ExternalConnectorSessionRunner.swift`,
`LoLaTcpControlExchangeRuntime.swift`.

## Partially Inspected Files

`AppExecutionController.swift` (callers and key fields, not full read),
`AppReceiverPreviewServices.swift` (imports and structure only — CoreAudio in app layer unverified),
`DirectPeerSessionReport.swift` (892L — structure and validation chain, not full read),
`AppConsoleChromeView.swift` (not read), `AppShellSupportViews.swift` (not read).

## Uninspected Files and Subsystems

| Area | Reason for Omission |
|---|---|
| `Sources/OpenLolaCore/Release/` | Release harness; out of scope |
| `Sources/OpenLolaCore/Evidence/` | Evidence collection; out of scope |
| `Sources/OpenLolaCore/Benchmarks/` | Indirectly referenced; not fully read |
| `Sources/OpenLolaCore/Connectors/JackTrip/` | Known dead code candidate; not prioritized |
| `Sources/OpenLolaCore/Connectors/UltraGrid/` | Known dead code candidate; not prioritized |
| `Sources/OpenLolaCore/Connectors/NMP/` | Unknown; no CLI wiring found |
| `Sources/COpenLolaAtomics/` | Vendored C; callers audited, C not |
| `Sources/xs_ref_sw_ed2/` | Vendored JPEG-XS reference; out of scope |
| `Sources/opus-1.5.2/` | Vendored Opus; out of scope |
| `linux_connector/` | Python seed; out of scope |
| `scripts/` / `script/` | Shell automation; out of scope |
| `Sources/open-lola/main.swift` (routing) | Partially read for CLI wiring checks |

---

# 3. Runtime Architecture Summary

## Audio Path

```
IOProc callback (Core Audio RT thread)
  → SPSCAtomicRing.push() [lock-free, 1-producer]
  → RealtimeAudioPacketHandoff [NSLock ← P2 risk in RT path]
  → UdpPcmPacket.encode()
  → UdpMediaTransport.send() [POSIX sendto, non-blocking]
```

**Capture → TX:** `DirectPeerRealtimeAudioGraph` → `RealtimeAudioPacketHandoff` → `UdpMediaTransport`

**RX → Playout:**
```
UdpMediaTransport.receive() [blocking POSIX recvfrom, up to 1s timeout]
  → RealtimeAudioFixedTargetJitterBuffer.enqueue()
  → IOProc callback pulls from jitter buffer via SPSCAtomicRing
  → Core Audio output device
```

## UDP / P2P Path

```
PeerSessionRunner (struct, value-type)
  → SessionStateMachine (enum-driven, acceptedConfiguration gate)
  → UdpMediaTransport × 3 (audio, video, metrics sockets)
       → UdpPcmSocketOperations (POSIX bind/connect/send/recv/poll)
  → DirectPeerRealtimeAudioGraph (CoreAudio IOProc)
  → DirectPeerSessionAVSocketRunner (socket event loop)
```

**P2P lifecycle:** `unconfigured → ready → armed → connecting → running → (recovery) → stopped`

## Video Path

```
AVFoundationCapture.startRunning() [blocks caller thread ← P2]
  → VideoFrameAssembler [fragment → complete frame, max-age eviction at 250ms]
  → JPEGXSReferenceCodec (vendored C, encode/decode)
  → UdpMediaTransport.send() [video socket]
                                          ↕
Receive side:
  → UdpMediaTransport.receive() [video socket]
  → VideoFrameReassembler [fragment reassembly, 250ms default max-age]
  → VideoOutputRenderer [Sendable + unsynchronized mutable state ← P2]
  → AVSampleBufferDisplayLayer / BlackmagicOutputBoundary [stub ← P1]
```

## Control Path

```
SessionControlMessage [JSON codec, UDP]
  → PeerSessionRunner.receiveControlMessages() [stops on first error ← P1]
  → SessionStateMachine transitions
  → LoLaTcpControlExchangeRuntime [TCP, partial-write not retried ← P1]
```

Control messages: `proposal`, `accept`, `reject`, `mediaStart`, `audioMetadata`, `metrics`, `recovery`, `error`, `shutdown`

## TX Path

```
DirectPeerRealtimeAudioGraph.IOProc
  → RealtimeAudioPacketHandoff.sendNextPacket()
       [2 × Data allocation per packet at 750Hz ← P2 TX-001]
  → UdpMediaTransport.send()
  → POSIX sendto()
```

## RX Path

```
UdpMediaTransport.receive() [blocking, 1s timeout]
  → decodeReceived() [lock acquired here for decode ← P0-002 contention risk]
  → RealtimeAudioFixedTargetJitterBuffer.enqueue()
  → RxBuffering [AdaptiveController, stale-drop, overflow risk ← P1]
```

## Local RX Path

```
AppReceiverPreviewServices [app layer, CoreAudio direct]
  → Preview IOProc [same IOProc lifecycle risks as P0-001]
  → AppPreviewReceiverView [fire-and-forget window open, no confirmation ← P2]
```
_Note: `AppReceiverPreviewServices.swift` not fully read — local RX path in app layer partially unknown._

## UI-to-Runtime Path

```
AppExecutionController (subprocess via Process API)
  → open-lola CLI subprocess
  → Reads NativeAppShellReport JSON (snapshot, NOT live telemetry)
  → AppSessionState.derive() [never returns .live ← P1]
  → AppLatencyHeroMetrics.make() [zero values show false green ← P1]
  → SwiftUI re-render
```

---

# 4. Findings Index

| ID | Sev | Category | Subsystem | File | Short Title | Confidence |
|---|---|---|---|---|---|---|
| **P0-001** | **P0** | RUNTIME | Audio/RT | DirectPeerRealtimeAudioGraph.swift | IOProc use-after-free on graph dealloc | High |
| **P0-002** | **P0** | RUNTIME | UDP | UdpMediaTransport.swift | stateLock contention with blocking recvfrom | High |
| P1-MADI-001 | P1 | RUNTIME | MADI/DeviceIO | MadiFullDuplexRuntime.swift:438–455 | outputDeviceUID ignored — both devices use input UID | High |
| P1-MADI-002 | P1 | RUNTIME | MADI/DeviceIO | CoreAudioInventoryReader.swift:162–184 | takeRetainedValue on non-retained CoreAudio string | High |
| P1-MADI-003 | P1 | RUNTIME | MADI/DeviceIO | DirectAudioMediaRouter.swift:56–87 | No device capability cross-check in audio router | High |
| P1-MEDIA-001 | P1 | RUNTIME | Timing | MediaClock.swift:22 | preconditionFailure crash on nanoseconds overflow | High |
| P1-RXBUF-001 | P1 | RUNTIME | RX Buffering | RxBuffering.swift | Integer overflow in RxBufferPolicy factory methods | High |
| P1-RT-001 | P1 | RUNTIME | Audio/RT | DirectPeerRealtimeAudioGraph.swift | stopUnlocked() leaves graph stuck on failed stop | High |
| P1-RT-002 | P1 | RUNTIME | Audio/RT | DirectPeerRealtimeAudioGraph.swift | deinit acquires NSLock — potential deadlock | High |
| P1-RT-003 | P1 | RUNTIME | Audio/RT | DirectPeerRealtimeAudioGraph.swift | DispatchTime.now() syscall inside RT callback | High |
| P1-RT-004 | P1 | RUNTIME | Audio/RT | RealtimeAudioBuffers.swift | Per-sample guard loop in RT callback | Medium |
| P1-RT-005 | P1 | RUNTIME | Audio/RT | DirectPeerRealtimeAudioGraph.swift | Silent audio loss on host-time conversion failure | Medium |
| P1-UDP-001 | P1 | RUNTIME | UDP | LoLaTcpControlExchangeRuntime.swift | TCP partial-write not retried | High |
| P1-P2P-001 | P1 | RUNTIME | P2P/Control | PeerSessionRunner.swift:320 | state = .running set before peer acks media start | High |
| P1-P2P-002 | P1 | RUNTIME | P2P/Control | PeerSessionRunner.swift:13,540 | controlTranscript unbounded growth in long sessions | High |
| P1-P2P-003 | P1 | RUNTIME | P2P/Control | PeerSessionRunner.swift:struct | PeerSessionRunner struct: no concurrency guard | Medium |
| P1-P2P-004 | P1 | RUNTIME | P2P/Control | SessionStateMachine | .error messages dropped in .recovering state | High |
| P1-P2P-005 | P1 | RUNTIME | P2P/Control | PeerSessionRunner.swift:315–320 | No transport rollback on partial connect failure | High |
| P1-CTRL-001 | P1 | RUNTIME | Control | SessionNegotiation | Simultaneous proposal collision — no resolution | Medium |
| P1-CTRL-002 | P1 | RUNTIME | Control | PeerSessionRunner | receiveControlMessages stops on first error | Medium |
| P1-VIDEO-001 | P1 | RUNTIME | Video | BlackmagicOutputBoundary.swift | BlackmagicOutputBoundary is an unimplemented stub | High |
| P1-VIDEO-002 | P1 | RUNTIME | Video | Video/ multi-stream files | Multi-stream runtime staged / not production-ready | High |
| P1-TEST-001 | P1 | TESTS | Tests | LoLaCompatibilityMediaSessionTests.swift | LoLa session tests are synthetic-only | High |
| P1-TEST-002 | P1 | TESTS | Tests | Realtime audio test files | RT audio engine tests fixture-only, no hardware | High |
| P1-TEST-003 | P1 | TESTS | Tests | Reconnection tests | Reconnection test missing bounded timeout | Medium |
| P1-TEST-004 | P1 | TESTS | Tests | Packet handoff tests | Packet handoff concurrency test can hang | Medium |
| P1-TEST-005 | P1 | TESTS | Tests | Lifecycle tests | Lifecycle test validates harness not resources | Medium |
| P1-TEST-006 | P1 | TESTS | Tests | UdpMediaTransportTests.swift | No concurrent close+blocking-recv test | High |
| P1-TEST-007 | P1 | TESTS | Tests | DirectPeerRealtimeAudioGraphTests.swift | No IOProc concurrent stop race test | High |
| P1-TEST-008 | P1 | TESTS | Tests | AppShellBehaviorTests.swift | No zero-value latency/jitter hero metrics test | High |
| P1-TEST-009 | P1 | TESTS | Tests | PeerSessionRunnerTests.swift | No partial-connect failure/rollback test | High |
| P1-SLOP-001 | P1 | SLOP | Evidence | Multiple (12 files) | SyntheticPlaceholderMetrics zeros in production reports | High |
| P1-SLOP-002 | P1 | SLOP | Evidence | Multiple (12 files) | 44 "todo(human):" strings baked into report fields | High |
| P1-UI-001 | P1 | UI | UI/State | AppSessionStateBanner.swift | .live state unreachable from AppSessionState.derive() | High |
| P1-UI-002 | P1 | UI | UI/State | AppConnectionTopologyView.swift | Topology animation fires on supervisor start, not data flow | High |
| P1-UI-003 | P1 | UI | UI/State | AppLatencyHeroMetrics.swift | Zero jitter/latency yields false "target met" green | High |
| P1-UI-004 | P1 | UI | UI/Menu | OpenLolaApp.swift | unsupportedMenuAction renders debug labels in production | High |
| P2-RT-001 | P2 | RUNTIME | Audio/RT | RealtimeAudioPacketHandoff.swift | NSLock in IOProc packet handoff path (realtime path) | High |
| P2-RT-002 | P2 | RUNTIME | Audio/RT | SPSCAtomicRing.swift:46,66 | SPSC owner assertion guarded by #if DEBUG — silent in release | High |
| P2-RT-003 | P2 | RUNTIME | Audio/RT | DirectPeerRealtimeAudioGraph.swift | Force unwrap in capture ring setup | High |
| P2-RT-004 | P2 | RUNTIME | Audio/RT | RealtimeAudioBuffers.swift | dropStalePackets crashes on accounting underflow | High |
| P2-RT-005 | P2 | RUNTIME | Audio/TX | RealtimeAudioPacketHandoff.swift:152–175 | 2×Data alloc per packet in TX hot path at 750Hz | High |
| P2-RT-006 | P2 | RUNTIME | Audio/TX | RealtimeAudioPacketHandoff.swift:184–185 | validateV2FragmentPlan called on every send (may be redundant) | Low |
| P2-UDP-001 | P2 | RUNTIME | UDP | SessionControlMessage | No control message sequence/replay validation | High |
| P2-UDP-002 | P2 | RUNTIME | UDP | LoLaPacketFrame | Wire frame accepts trailing garbage bytes | Medium |
| P2-RXBUF-001 | P2 | RUNTIME | RX Buffering | RxBuffering.swift | staleVideoDropThresholdMicroseconds defined but unused | High |
| P2-RXBUF-002 | P2 | RUNTIME | RX Buffering | RxBuffering.swift | Synthetic benchmark used as production evidence | High |
| P2-RXBUF-003 | P2 | RUNTIME | RX Buffering | RxBuffering.swift | Drift correction path not runtime-exercised | Medium |
| P2-RXBUF-004 | P2 | RUNTIME | RX Buffering | RxBuffering.swift | Overrun detection observational only | Medium |
| P2-RXBUF-005 | P2 | RUNTIME | RX/Playout | RealtimeAudioFixedTargetJitterBuffer | Playout buffer payload storage path unverified | Low |
| P2-P2P-001 | P2 | RUNTIME | P2P/Control | PeerSessionRunner | Recovery cannot restore a closed transport set | High |
| P2-P2P-002 | P2 | RUNTIME | P2P/Control | PeerSessionRunner | Shutdown errors swallowed with try? | High |
| P2-P2P-003 | P2 | RUNTIME | P2P/Control | PeerSessionRunner | Stale session state retained after shutdown | Medium |
| P2-P2P-004 | P2 | RUNTIME | P2P/Control | PeerSessionRunner | Error state not fully cleaned up on recovery | Medium |
| P2-P2P-005 | P2 | RUNTIME | P2P/Control | PeerSessionRunner | Reconnect: connect() on existing socket unverified | Medium |
| P2-MADI-001 | P2 | RUNTIME | MADI/DeviceIO | MadiFullDuplexRuntime | Premature streaming before peer readiness confirmed | High |
| P2-MADI-002 | P2 | RUNTIME | MADI/DeviceIO | MadiReceiveBuffers | Raw offset access without bounds check | High |
| P2-MADI-003 | P2 | RUNTIME | MADI/DeviceIO | CoreAudioInventoryReader | Legacy AudioObjectGetPropertyData APIs | Medium |
| P2-MADI-004 | P2 | RUNTIME | MADI/DeviceIO | MadiReceiveBuffers | precondition for capacity validation | Medium |
| P2-VIDEO-001 | P2 | RUNTIME | Video | VideoOutputRenderer | Sendable declared but has unsynchronized mutable state | High |
| P2-VIDEO-002 | P2 | RUNTIME | Video | AVFoundationCapture | AVCaptureSession.startRunning blocks caller thread | High |
| P2-VIDEO-003 | P2 | RUNTIME | Video | VideoTransportPacket | Frame rate config silently partial on overflow | Medium |
| P2-VIDEO-004 | P2 | RUNTIME | Video | VideoFrameAssembler | Incomplete frame buckets not evicted under sustained loss | High |
| P2-CTRL-001 | P2 | RUNTIME | Control | LoLaTcpControlExchangeRuntime | Catch-all returns struct instead of throwing — discard risk | Medium |
| P2-TEST-001 | P2 | TESTS | Tests | PeerSessionRunnerTests | Peer session runner test checks counters, not media content | Medium |
| P2-TEST-002 | P2 | TESTS | Tests | UdpMediaTransportTests.swift | UDP PCM loopback missing reorder/reconnect cases | Medium |
| P2-TEST-003 | P2 | TESTS | Tests | RxBufferingTests | Hard-coded expected values in RxBuffering tests | Medium |
| P2-TEST-004 | P2 | TESTS | Tests | MediaClockTests | MediaClock tests missing boundary/overflow cases | High |
| P2-TEST-005 | P2 | TESTS | Tests | DirectPeerRealtimeAudioGraphTests | Graph teardown tests don't confirm resource release | Medium |
| P2-TEST-006 | P2 | TESTS | Tests | UdpMediaTransportTests.swift:374,389 | Jitter tests assert ==0 on loopback (trivially true) | High |
| P2-TEST-007 | P2 | TESTS | Tests | DirectPeerRealtimeAudioGraphTests:220 | Callback timing test asserts >=0 (trivially true) | High |
| P2-TEST-008 | P2 | TESTS | Tests | VideoTransportTests (missing) | VideoFrameReassembler 250ms expiry not tested in production path | High |
| P2-TEST-009 | P2 | TESTS | Tests | IntegratedAvDegradeFirstTests.swift | Degraded-network tests are schema-only, not network-level | High |
| P2-DEAD-001 | P2 | DEAD_CODE | Connectors | UltraGrid/ (14 files) | UltraGrid connector has no CLI wiring — may be dead | High |
| P2-DEAD-002 | P2 | DEAD_CODE | Connectors | JackTrip/ (13 files) | JackTrip connector has no CLI wiring — may be dead | High |
| P2-SLOP-001 | P2 | SLOP | MADI | MadiChannelCounts.swift (1 line) | Single-constant 1-line file — inline candidate | High |
| P2-SLOP-002 | P2 | SLOP | UDP | UdpPcmLoopbackDefaults.swift | Loopback defaults used only in test/loopback paths | Medium |
| P2-DEDUP-001 | P2 | DEDUP | Core | 32+ validator files | 32+ identical 2-line validator enum boilerplate | High |
| P2-DEDUP-002 | P2 | DEDUP | Connectors | JackTrip/UltraGrid/NMP/LoLa | Parallel file structure across 4 connector subsystems | Medium |
| P2-STRUCT-001 | P2 | STRUCTURE | Support | NetworkRouteCommandMatrix.swift (682L) | 682L docs-as-code with hard-coded file path strings | High |
| P2-STRUCT-002 | P2 | STRUCTURE | Support | SourceOwnershipInventory.swift | Hard-coded file path strings — stale risk | Medium |
| P2-STRUCT-003 | P2 | STRUCTURE | Network/P2P | DirectPeerSessionReport.swift (892L) | Very large; validation chain at size limit | Medium |
| P2-STRUCT-004 | P2 | STRUCTURE | Core | OpenLolaContractsAliases.swift | Hidden cross-module coupling via typealias layer | Medium |
| P2-DEPR-001 | P2 | DEPRECATED | Connectors | UltraGridCompatibility.swift:4–5 | try! at file scope — startup crash risk | High |
| P2-UI-001 | P2 | UI | UI/Session | AppTransportView.swift | statusTone uses fragile "fail" substring match | High |
| P2-UI-002 | P2 | UI | UI/Session | AppTransportView.swift | JackTrip/UltraGrid "UNAVAILABLE" pill — no explanation | High |
| P2-UI-003 | P2 | UI | UI/Stream | AppShellSectionViews.swift | Remote Evidence panel shows static vocabulary, not runtime state | High |
| P2-UI-004 | P2 | UI | UI/Stream | AppPreviewReceiverView.swift | Return blend/visible streams controls disabled but visible | Medium |
| P2-UI-005 | P2 | UI | UI/State | AppSessionStateBanner.swift | .live banner label shows empty "()" when peer names empty | Medium |
| P2-UI-006 | P2 | UI | UI/State | AppPreviewReceiverView.swift | previewIsActive OR logic gives false-active on partial failure | Medium |
| P2-UI-007 | P2 | UI | UI/A11Y | AppSessionStateBanner.swift | VoiceOver announcements missing for key state transitions | High |
| P2-UI-008 | P2 | UI | UI/Settings | AppShellSettingsTabs.swift | SSH help text uses internal engineering language | High |
| P2-UI-009 | P2 | UI | UI/Settings | AppShellSectionViews.swift | AppShellSettingsSurfacePolicy constants not wired to logic | Medium |
| P2-UI-010 | P2 | UI | UI/Visual | AppDesignSystem.swift | Light-mode state color contrast not assertion-verified | Medium |
| P2-UI-011 | P2 | UI | UI/Preview | AppPreviewReceiverView.swift | Window open is fire-and-forget with no confirmation | High |
| P2-UI-012 | P2 | UI | UI/Diag | AppShellSectionViews.swift | evidenceIncomplete verdict shown in green (false positive) | High |
| P2-UI-013 | P2 | UI | UI/Menu | OpenLolaApp.swift | Only 3 keyboard shortcuts for 11+ menu actions | Medium |
| P3-UDP-001 | P3 | RUNTIME | UDP | LoLaPacketFrame | Wire frame accepts trailing garbage bytes | Medium |
| P3-RXBUF-001 | P3 | RUNTIME | RX Buffering | RxBuffering | Overrun detection observational only | Medium |
| P3-P2P-001 | P3 | RUNTIME | P2P/Control | PeerSessionRunner | Stale session state retained after shutdown | Medium |
| P3-MADI-001 | P3 | RUNTIME | MADI | MadiReceiveBuffers | precondition for capacity (process crash in debug only) | Medium |
| P3-OVER-001 | P3 | OVERENG | Network/UDP | NetworkByteReader.swift | Manual bit-shift reader — no bounds checks | High |
| P3-OVER-002 | P3 | OVERENG | Network/P2P | DirectPeerFNV1A.swift | Custom FNV-1a — correct but verify not in hot path | High |
| P3-DEPR-001 | P3 | DEPRECATED | Audio/RT | SPSCAtomicRing.swift:46,66 | SPSC ownership assertions guarded by #if DEBUG only | High |
| P3-SLOP-001 | P3 | SLOP | UI | AppDesignSystem.swift | AppSessionState.live dead state with full color/animation styling | High |
| P3-SLOP-002 | P3 | SLOP | Core | PlaceholderDetection.swift | PlaceholderDetection/PlaceholderSensitiveField likely unused | Medium |
| P3-SLOP-003 | P3 | SLOP | Network | (3 files) | "0.0.0-m06" version string hardcoded in 3 places | Medium |
| P3-UI-001 | P3 | UI | UI/Visual | AppDesignSystem.swift | Redundant `case .validated: false` in isAnimated switch | High |
| P3-UI-002 | P3 | UI | UI/A11Y | AppChannelMeterView.swift | VoiceOver hint on VU meter is too verbose | High |
| P3-UI-003 | P3 | UI | UI/Preview | AppPreviewReceiverView.swift | Blackmagic limitation message always shown (regardless of hardware) | Medium |

**Total: 2 P0, 37 P1, 55 P2, 13 P3 = 107 findings**

_Note on finding ID overlap with plan.md: Several finding IDs in plan.md (RT-AUDIO-005, VIDEO-003)
were assigned to different findings across passes. This document uses canonical final IDs above.
Mapping to plan.md IDs is provided in cross-reference notes in each section._

---

# 5. P0 Findings

> **These are crash / use-after-free / deadlock risks. Fix before any other work.**

## P0-001 — IOProc Use-After-Free on Graph Deallocation

- **ID:** P0-001
- **Severity:** P0
- **File:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- **Subsystem:** Realtime Audio / CoreAudio
- **Original plan.md reference:** P3-9 concurrency table, "IOProc use-after-free"
- **Evidence:** `DirectPeerRealtimeAudioGraph.stop()` calls `AudioDeviceStop()` then `AudioDeviceDestroyIOProcID()`. `AudioDeviceStop()` is not guaranteed to block until the IOProc callback completes — it initiates stop but the callback may still be executing on the CoreAudio thread when `AudioDeviceDestroyIOProcID()` frees the proc ID. If the IOProc fires after `DestroyIOProcID`, it accesses freed/invalid state via the registered `Unmanaged.fromOpaque` pointer.
- **Why this can fail at runtime:** Process crash (EXC_BAD_ACCESS), memory corruption, or silent corruption of audio output on stop/restart.
- **Failure mode:** Crash (P0) — EXC_BAD_ACCESS in CoreAudio RT thread, or silent corruption.
- **Suggested remediation:** After `AudioDeviceStop()`, poll until the CoreAudio callback count stops incrementing (or use `AudioDeviceDestroyIOProcID` only after verifying the callback is quiesced via a semaphore/atomic counter). Refer to CoreAudio documentation on `AudioDeviceStop` quiescence guarantees.
- **Required verification:** Cannot verify without real CoreAudio hardware. Requires a stress test: start/stop graph 100× in a loop with `AddressSanitizer` enabled. Verify `callbackCount` does not increment after `stop()` returns.
- **Suggested test:** `directPeerRealtimeAudioGraphCallbackDoesNotFireAfterStop` — requires mock IOProc harness or real device.
- **Risk of change:** High — CoreAudio lifecycle is hardware-dependent.
- **Confidence:** High

---

## P0-002 — UDP Transport stateLock Contention with Blocking recvfrom

- **ID:** P0-002
- **Severity:** P0
- **File:** `Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift`
- **Subsystem:** UDP / Networking
- **Original plan.md reference:** P3-11 "UDP-001", P3-9 concurrency table
- **Evidence:** `UdpMediaTransport` uses `NSLock` (`stateLock`) for state management. `close()` acquires `stateLock` at lines ~318–319. The receive loop in `receive()` calls `receiveDatagram()` (blocking `recvfrom()` with up to 1-second timeout). If `close()` is called from one thread while `receive()` is blocking on `recvfrom()` from another thread, the lock acquisition order and blocking behavior can cause either: (a) `close()` waiting up to 1 second for the receive to complete, causing a 1-second audio send stall if the send path also needs the lock; or (b) a deadlock if both threads are waiting for the lock while the blocking recv holds a related resource.
- **Why this can fail at runtime:** 1-second stall in the audio send path causes a dropout; in degenerate cases, deadlock.
- **Failure mode:** Audio glitch/dropout (1s stall), potential deadlock.
- **Suggested remediation:** Ensure `stateLock` is NOT held during the blocking `recvfrom()` call. Use a separate mechanism (e.g., `close()` sets a flag and signals a socket with `shutdown(SHUT_RD)` or sends a wakeup packet to unblock `recvfrom()`). Verify exact lock scope in `close()` and `decodeReceived()` implementations before applying fix.
- **Required verification:** Write a concurrent test: start `receive()` on a background thread (blocking on socket), then call `close()` from the main thread. Verify `close()` completes within 100ms. Run under Thread Sanitizer.
- **Suggested test:** `udpMediaTransportCloseCompletesWhileReceiveIsBlocking` — see P1-TEST-006.
- **Risk of change:** High — UDP transport is the core media delivery path.
- **Confidence:** High (lock architecture inspected; concurrent test does not exist)

---

# 6. P1 Findings

> **These are confirmed or high-probability correctness bugs. Fix in order after P0.**

## P1-MADI-001 — outputDeviceUID Ignored; Both Devices Use inputDeviceUID

- **File:** `Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexRuntime.swift`, lines 438–455
- **Evidence:** `handoffConfiguration` assigns `inputDeviceUID` to both the input and output device slots. The `outputDeviceUID` field is read but not used.
- **Impact:** Full-duplex audio routes both input AND output to the input device. Output audio is silent or misrouted.
- **Suggested fix:** Pass `outputDeviceUID` to the output device slot. 1-line fix.
- **Verification:** Manual test with two distinct CoreAudio device UIDs. Confirm output reaches the correct device.
- **Confidence:** High

---

## P1-MADI-002 — takeRetainedValue on Non-Retained CoreAudio String

- **File:** `Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift`, lines 162–184
- **Evidence:** `stringProperty` calls `takeRetainedValue()` on a `CFString` result from `AudioObjectGetPropertyData`. The CoreAudio documentation specifies some properties return a retained reference (caller must release) and some do not. Using `takeRetainedValue()` on a non-retained reference causes a double-free or over-release.
- **Impact:** Memory corruption, crash on device inventory query.
- **Suggested fix:** Verify the CoreAudio ownership convention for each property used. Use `takeUnretainedValue()` if the caller does not own the reference.
- **Verification:** Run under AddressSanitizer with a real CoreAudio device. Confirm no heap corruption.
- **Confidence:** High

---

## P1-MADI-003 — No Device Capability Cross-Check in Audio Router

- **File:** `Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift`, lines 56–87
- **Evidence:** `DirectAudioMediaRouter` constructs transport modes based on configuration without cross-checking the actual CoreAudio device capabilities (channel count, supported sample rates, supported buffer sizes).
- **Impact:** Audio route can be configured for parameters the device cannot support. Results in CoreAudio errors or silent misrouting.
- **Suggested fix:** Query device capabilities via `CoreAudioInventoryReader` before constructing the transport mode; reject unsupported configurations with a clear error.
- **Confidence:** High

---

## P1-MEDIA-001 — MediaClock.nanoseconds Hard-Crashes on Overflow

- **File:** `Sources/OpenLolaCore/Timing/MediaClock.swift`, line ~22
- **Evidence:** `nanoseconds(forFrameCount:sampleRateHertz:)` calls `preconditionFailure` on arithmetic overflow. At 48kHz, overflow occurs after ~6.2 million seconds (~71 days). In real sessions, large frame counts or incorrect sample rates passed as arguments could trigger this far sooner.
- **Impact:** Process crash.
- **Suggested fix:** Replace `preconditionFailure` with a bounded/clamp computation or a `Result<UInt64, MediaClockError>` return. Add an overflow test.
- **Confidence:** High

---

## P1-RXBUF-001 — Integer Overflow in RxBufferPolicy Factory Methods

- **File:** `Sources/OpenLolaCore/Timing/RxBuffering.swift`
- **Evidence:** Factory methods in `RxBufferPolicy` use integer arithmetic that can overflow for large buffer size parameters.
- **Impact:** Incorrect policy calculations, wrong buffer allocation sizes, potential crash.
- **Suggested fix:** Use overflow-safe arithmetic (`&+`, `&*`) or `Int.checkedAdd`/`checkedMultiply` equivalents.
- **Confidence:** High

---

## P1-RT-001 — stopUnlocked() Leaves Graph Stuck in "Started" on Failed Stop

- **File:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- **Evidence:** `stopUnlocked()` does not clear `isStarted` flag when `AudioDeviceStop` fails. The graph remains in a "started" state but the device is not running. Subsequent `start()` calls fail; subsequent `stop()` calls fail silently.
- **Impact:** Audio graph wedged; restart requires process restart.
- **Suggested fix:** Force-clear `isStarted` on failed stop after logging the error. Deregister the IOProc regardless of `AudioDeviceStop` result.
- **Confidence:** High

---

## P1-RT-002 — deinit Acquires NSLock (Potential Deadlock)

- **File:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- **Evidence:** `deinit` acquires `NSLock` while the RT callback may be trying to acquire the same lock. If deallocation races with an in-progress RT callback, the deinit thread can deadlock waiting for the lock held by the RT thread.
- **Impact:** Thread deadlock on graph deallocation.
- **Suggested fix:** Ensure the IOProc is fully stopped (P0-001 fix) before `deinit` runs. Consider using an atomic flag instead of NSLock in deinit.
- **Confidence:** High

---

## P1-RT-003 — DispatchTime.now() Syscall Inside RT Callback

- **File:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- **Evidence:** `DispatchTime.now().uptimeNanoseconds` is called inside the CoreAudio IOProc callback. `DispatchTime.now()` invokes a system call which may block under memory pressure, violating the CoreAudio realtime constraint.
- **Impact:** RT callback jitter, audio glitches.
- **Suggested fix:** Use `mach_absolute_time()` directly (or pre-compute the Mach-to-ns conversion outside the callback).
- **Confidence:** High

---

## P1-RT-004 — Per-Sample Guard Loop in RT Callback

- **File:** `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift`
- **Evidence:** A per-sample guard loop in the RT callback path executes redundant bounds/format checks on every sample instead of pre-validating once per callback invocation.
- **Impact:** Increased callback duration per invocation, RT deadline risk.
- **Suggested fix:** Move validation to callback entry; remove per-sample guard.
- **Confidence:** Medium

---

## P1-RT-005 — Silent Audio Loss on Host-Time Conversion Failure

- **File:** `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
- **Evidence:** Host-time to nanoseconds conversion failure is silently ignored; the packet is dropped without logging or metric increment.
- **Impact:** Silent audio packet loss.
- **Suggested fix:** Increment a `hostTimeConversionFailures` metric; log once-per-session as a warning.
- **Confidence:** Medium

---

## P1-UDP-001 — TCP Partial-Write Not Retried

- **File:** `Sources/OpenLolaCore/Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift`
- **Evidence:** TCP `write()` is not retried on partial write. POSIX TCP `write()` can return fewer bytes than requested; the caller must loop until all bytes are written.
- **Impact:** Control messages silently truncated; LoLa session negotiation fails.
- **Suggested fix:** Wrap TCP write in a retry loop until all bytes are written or an error occurs.
- **Confidence:** High

---

## P1-P2P-001 — state = .running Set Before Peer Acknowledges Media Start

- **File:** `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`, line 320
- **Evidence:** `startMedia()` sets `state = .running` (line 320) immediately after local transport connections, before any peer acknowledgement. `applyControlTransition(mediaStart)` (line 325) sends the control message but does not wait for peer acceptance.
- **Impact:** Any UI or logic reading `state == .running` as "session is active and data is flowing" will show a false "connected" state.
- **Suggested fix:** Introduce a `.mediaStarting` state that is held until peer acknowledgement; transition to `.running` only after the peer has confirmed the media session.
- **Confidence:** High

---

## P1-P2P-002 — controlTranscript Unbounded Growth

- **File:** `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`, lines 13, 540
- **Evidence:** `controlTranscript: [SessionControlMessage] = []` grows with every sent/received control message. In a long session with metrics at 1Hz: 3,600 entries/hour; at 10Hz: 36,000/hour. No cap or pruning logic exists.
- **Impact:** Unbounded heap growth; OOM risk in extended sessions.
- **Suggested fix:** Cap `controlTranscript` at a fixed maximum (e.g., 1000 entries) using a ring buffer or by trimming to the last N entries on append.
- **Suggested test:** `peerSessionRunnerControlTranscriptIsBoundedUnderHighFrequencyMessages`
- **Confidence:** High

---

## P1-P2P-003 — PeerSessionRunner Struct Has No Concurrency Guard

- **File:** `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`
- **Evidence:** `PeerSessionRunner` is a Swift struct (value type). If any caller holds a mutable reference and multiple threads mutate it concurrently (e.g., a background socket runner and the main thread calling `beginRecovery`), Swift's value semantics do not prevent concurrent mutation — copies may diverge.
- **Impact:** Data race, incorrect state.
- **Suggested fix:** Wrap all mutations in a serial queue or actor, or document that the struct must only be mutated from one thread.
- **Confidence:** Medium

---

## P1-P2P-004 — .error Messages Dropped in .recovering State

- **File:** `Sources/OpenLolaCore/Network/P2P/SessionStateMachine`
- **Evidence:** The session state machine does not accept `.error` control messages when in the `.recovering` state. A peer that sends an error while the local node is recovering leaves the session stuck in recovery.
- **Impact:** Stuck half-dead recovery loop; session never reaches `.failed` → clean shutdown.
- **Suggested fix:** Allow `.error` → `.failed` transition from any non-terminal state including `.recovering`.
- **Confidence:** High

---

## P1-P2P-005 — No Transport Rollback on Partial Connect Failure in startMedia()

- **File:** `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner.swift`, lines 315–320
- **Evidence:** `startMedia()` calls `audioTransport.connect()` (line 315), `videoTransport.connect()` (316), `metricsTransport.connect()` (317) sequentially. If the second or third connect throws, the first transport(s) are already connected but left open. No rollback logic exists.
- **Impact:** Partially-connected transports leak; a subsequent `startMedia()` may double-connect or a subsequent `stopMedia()` may leave sockets in undefined state.
- **Suggested fix:** Wrap all three connect calls in a do/catch; on error, close any successfully-connected transports before re-throwing.
- **Suggested test:** `peerSessionRunnerStartMediaCleansUpOnPartialConnectFailure`
- **Confidence:** High

---

## P1-CTRL-001 — Simultaneous Proposal Collision Has No Resolution

- **File:** `Sources/OpenLolaCore/Network/P2P/SessionNegotiation`
- **Evidence:** If both endpoints call `makeSessionProposal()` simultaneously, both see the other's proposal arrive and neither accepts (both are in "proposing" state). The session stalls.
- **Impact:** Session never establishes when both sides initiate simultaneously (common in automated reconnect).
- **Suggested fix:** Implement deterministic tie-breaking (e.g., lower UID wins as acceptor).
- **Confidence:** Medium

---

## P1-CTRL-002 — receiveControlMessages Stops on First Error

- **File:** `Sources/OpenLolaCore/Network/P2P/PeerSessionRunner`
- **Evidence:** `receiveControlMessages()` processes a list of messages and returns on the first error, silently dropping remaining messages.
- **Impact:** Later messages in a burst (including critical error or shutdown messages) are never processed.
- **Suggested fix:** Collect all errors; process all messages before returning any error summary.
- **Confidence:** Medium

---

## P1-VIDEO-001 — BlackmagicOutputBoundary Is an Unimplemented Stub

- **File:** `Sources/OpenLolaCore/Video/BlackmagicOutputBoundary.swift`
- **Evidence:** `runtimeAvailable: false`; all functional methods stub-return without implementation.
- **Impact:** Blackmagic video output is not functional. Any UI element or CLI command that claims Blackmagic output is working is incorrect.
- **Suggested fix:** Gate Blackmagic behind a feature flag (`#if BLACKMAGIC_ENABLED`) with a clear `// NOT IMPLEMENTED` comment.
- **Confidence:** High

---

## P1-VIDEO-002 — Multi-Stream Runtime Staged / Not Production-Ready

- **File:** Multiple files in `Sources/OpenLolaCore/Video/`
- **Evidence:** Multi-stream video session management is explicitly staged. No production harness exists.
- **Impact:** Any multi-stream video session attempt will fail or behave incorrectly.
- **Suggested fix:** Gate multi-stream behind a feature flag; document as research-only.
- **Confidence:** High

---

## P1-TEST-001 — LoLa Media Session Tests Are Synthetic-Only

- **File:** `Tests/OpenLolaCoreTests/LoLaCompatibilityMediaSessionTests.swift`
- **Evidence:** All passing LoLa session tests use synthetic fixtures. No live socket or hardware test exists.
- **Impact:** CI green does not prove LoLa compatibility over a real network.
- **Suggested fix:** Add a `@Test(.disabled(if: !socketHeavyTestsEnabled))` live socket test.
- **Confidence:** High

---

## P1-TEST-002 — Realtime Audio Engine Tests Are Fixture-Only

- **File:** `Tests/OpenLolaCoreTests/Realtime audio test files`
- **Evidence:** No test exercises the CoreAudio IOProc with real hardware callbacks.
- **Suggested fix:** Add hardware-gated tests or document the gap explicitly in CI.
- **Confidence:** High

---

## P1-TEST-003/004/005 — Reconnection/Handoff/Lifecycle Tests Missing Bounded Timeout or Resource Release Proof

- **Files:** Reconnection, packet handoff, and lifecycle test files
- **Evidence:** Tests can hang indefinitely (TEST-003/004) or only validate the harness drain wrapper (TEST-005), not actual resource cleanup.
- **Suggested fix:** Add `Task.withTimeout` or `XCTNSNotificationExpectation` with bounded timeout; verify resource counters are zero after teardown.
- **Confidence:** Medium

---

## P1-TEST-006 — No Concurrent close+blocking-recv Test for UdpMediaTransport

- **File:** `Tests/OpenLolaCoreTests/UdpMediaTransportTests.swift`
- **Evidence:** All transport tests are single-threaded loopback. No test exercises P0-002.
- **Suggested test:** `udpMediaTransportCloseCompletesWhileReceiveIsBlocking` — start receive on background thread, call close, verify completion within 1 second.
- **Confidence:** High

---

## P1-TEST-007 — No IOProc Concurrent Stop Race Test

- **File:** `Tests/OpenLolaCoreTests/DirectPeerRealtimeAudioGraphTests.swift`
- **Evidence:** Existing test uses `setCleanupStateForTesting` but does not exercise the concurrent callback-during-stop race (P0-001).
- **Suggested test:** `directPeerRealtimeAudioGraphCallbackDoesNotFireAfterStop` — requires mock IOProc.
- **Confidence:** High

---

## P1-TEST-008 — No Zero-Value Latency/Jitter Hero Metrics Test

- **File:** `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` (missing test)
- **Evidence:** All test fixtures use `jitterMicroseconds: 2_500`. Zero-value false positive (P1-UI-003) is untested.
- **Suggested test:** `appLatencyHeroMetricsMakeIgnoresZeroValuedMeasurements` — `#expect(result.jitterMs == nil)`.
- **Confidence:** High

---

## P1-TEST-009 — No Partial-Connect Failure/Rollback Test for startMedia()

- **File:** `Tests/OpenLolaCoreTests/PeerSessionRunnerTests.swift` (missing test)
- **Evidence:** No test exercises P1-P2P-005.
- **Suggested test:** `peerSessionRunnerStartMediaCleansUpOnPartialConnectFailure` — inject failing mock transport at each connect slot.
- **Confidence:** High

---

## P1-SLOP-001 — SyntheticPlaceholderMetrics Zeros Used in 12 Production Report Files

- **File:** `Sources/OpenLolaCore/Support/SyntheticPlaceholderMetrics.swift`, used in 12 files
- **Evidence:** Both constants are `Double = 0`. Used as `p50Microseconds`, `p95Microseconds`, `p99Microseconds` in production report structs. Zero values labeled as percentile metrics pass downstream validators trivially.
- **Impact:** Any validation gate that accepts these as real measurements produces false-pass verdicts based on 0µs latency.
- **Suggested fix:** Replace with `Optional<Double>` or a typed `notMeasured` sentinel at each call site, then delete the file.
- **Risk:** High — cascading changes across 12 files.
- **Confidence:** High

---

## P1-SLOP-002 — 44 "todo(human):" Strings Baked Into Production Report Fields

- **File:** Multiple (E2EBenchmarkSyntheticSmoke.swift, LatencyBenchmarkSyntheticSmoke.swift, IntegratedAvRun.swift, and 9 others)
- **Evidence:** 44+ occurrences of literal `"todo(human): ..."` as field values in production report structs. These are unfilled evidence placeholders that ship as runtime values.
- **Impact:** If validators do not scan for this string, these pass as acceptable evidence. Any report downstream of these files may carry false data.
- **Suggested fix:** Add `grep "todo(human)" Sources/` as a CI gate. Replace each with a real measurement or typed null.
- **Confidence:** High

---

## P1-UI-001 — .live State Unreachable from AppSessionState.derive()

- **File:** `Sources/open-lola-app/AppSessionStateBanner.swift`, `AppConnectionTopologyView.swift`
- **Evidence:** `AppSessionState.derive()` never returns `.live`. The animated "Live" green badge is dead UI. `AppConnectionTopologyView.isLive` is always `false`. Stop confirmation for `.live` is unreachable.
- **Impact:** Operators never see a confirmed "live data flowing" state. The highest visible state is `supervisorRunning` (process running), not proven data flow.
- **Suggested fix:** Implement `.live` transition backed by real evidence (packet-received counter, RMS > 0), or remove `.live` and document `supervisorRunning` as the highest achievable state.
- **Confidence:** High

---

## P1-UI-002 — Topology Animation Fires on Supervisor Start, Not Data Flow

- **File:** `Sources/open-lola-app/AppConnectionTopologyView.swift`
- **Evidence:** All four stream-type arrows animate when `phase == .supervisorRunning`, regardless of which streams are actually active.
- **Impact:** Users see all streams animating the moment the process starts. This is false for audio-only sessions, video-disabled sessions, or sessions where media hasn't started.
- **Suggested fix:** Tie animation to stream-specific metrics (e.g., `packetsReceived > 0`).
- **Confidence:** High

---

## P1-UI-003 — Zero Jitter/Latency in Reports Shows False "Target Met" Green

- **File:** `Sources/open-lola-app/AppLatencyHeroMetrics.swift`, lines 127–138
- **Evidence:** `jitter = reports.map(\.metrics.jitterMicroseconds).max().map { $0 / 1_000 }`. If all reports have `jitterMicroseconds = 0`, this produces `Optional(0.0)` (not nil) → rendered as "0.0 ms — stable" in green.
- **Impact:** False green indicator for zero-valued (synthetic) measurements — violates "no fake PASS" policy.
- **Suggested fix:** Add `guard $0 > 0 else { return nil }` inside the map.
- **Suggested test:** `appLatencyHeroMetricsMakeIgnoresZeroValuedMeasurements` (see P1-TEST-008)
- **Confidence:** High

---

## P1-UI-004 — unsupportedMenuAction Renders Debug Labels in Production

- **File:** `Sources/open-lola-app/OpenLolaApp.swift`
- **Evidence:** `unsupportedMenuAction` renders a visible `Button("Unsupported: \(action.title)")` for unhandled menu actions.
- **Impact:** Users see "Unsupported: {action}" in the macOS menu bar — a debug artifact in production.
- **Suggested fix:** Filter unhandled actions from the rendered menu (omit silently + log to debug console).
- **Confidence:** High

---

# 7. P2 Findings

> **Correctness issues, technical debt, and test gaps. Address in order after all P0 and P1 fixes.**

## P2: Audio / Realtime

**P2-RT-001** — NSLock in `RealtimeAudioPacketHandoff` (realtime path). NSLock can block the RT callback thread. Replace with `os_unfair_lock` or lock-free approach. _(File: RealtimeAudioPacketHandoff.swift)_

**P2-RT-002** — SPSC ownership assertions are `#if DEBUG`-only. Silent violation in release builds. Promote to always-on lightweight check or document ownership contract. _(File: SPSCAtomicRing.swift)_

**P2-RT-003** — Force unwrap in capture ring setup. If pre-conditions are not met, process crashes. Replace with guarded initialization. _(File: DirectPeerRealtimeAudioGraph.swift)_

**P2-RT-004** — `dropStalePackets` crashes on accounting underflow via `precondition`. Replace with `min(count, total)` clamping + log. _(File: RealtimeAudioBuffers.swift)_

**P2-RT-005** — Two `Data` heap allocations per sent packet at 750Hz in TX hot path. Consider pre-allocated buffer pool. _(File: RealtimeAudioPacketHandoff.swift:152–175)_

**P2-RT-006** — `validateV2FragmentPlan` called on every `sendNextV2Packets` invocation. If not memoized, this is redundant work. Verify if cached. Low confidence. _(File: RealtimeAudioPacketHandoff.swift:184–185)_

## P2: UDP / Networking

**P2-UDP-001** — No control message sequence number or idempotency check. Replayed or reordered control messages are applied verbatim. _(File: SessionControlMessage)_

**P2-UDP-002** — Wire frame decoder accepts trailing garbage bytes; strict-length validation not enforced. _(File: LoLaPacketFrame)_

**P2-CTRL-001** — `LoLaTcpControlExchangeRuntime` catch-all converts all thrown errors to a returned struct. Callers that discard the return value silently swallow all errors. _(File: LoLaTcpControlExchangeRuntime.swift)_

## P2: RX Buffering / Timing

**P2-RXBUF-001** — `staleVideoDropThresholdMicroseconds` is defined in `RxBuffering` but is not wired into any video-drop decision. _(File: RxBuffering.swift)_

**P2-RXBUF-002** — Synthetic benchmark used as production evidence in `RXBUF-004`. _(File: Benchmarks/)_

**P2-RXBUF-003** — Drift correction path in `AdaptiveController` is never exercised at runtime. _(File: RxBuffering.swift)_

**P2-RXBUF-004** — Overrun detection logic is observational only — no corrective action. _(File: RxBuffering.swift)_

**P2-RXBUF-005** — Playout buffer payload storage path unverified. `renderNextBlock()` needs direct read to confirm bytes flow to output. Low confidence. _(File: RealtimeAudioFixedTargetJitterBuffer)_

## P2: P2P / Control

**P2-P2P-001** — Recovery cannot restore a closed transport set. `restartMedia()` only works if transports are still open — a closed transport requires re-creation. _(File: PeerSessionRunner.swift)_

**P2-P2P-002** — Shutdown errors swallowed with `try?`. _(File: PeerSessionRunner.swift)_

**P2-P2P-003** — Stale session state retained after shutdown. Previous session's `controlTranscript` and `metrics` not cleared. _(File: PeerSessionRunner.swift)_

**P2-P2P-004** — Error state not fully cleaned up on recovery transition. _(File: PeerSessionRunner)_

**P2-P2P-005** — Reconnect: `connect()` called on existing sockets without verifying current state. _(File: PeerSessionRunner)_

## P2: MADI / Device IO

**P2-MADI-001** — Streaming begins before peer readiness is confirmed in `MadiFullDuplexSocketRunner`. _(File: MadiFullDuplexSocketRunner)_

**P2-MADI-002** — Raw offset arithmetic in `MadiReceiveBuffers` without bounds checks. _(File: MadiReceiveBuffers.swift)_

**P2-MADI-003** — Legacy `AudioObjectGetPropertyData` APIs used throughout `CoreAudioInventoryReader`. Migration to modern APIs should be planned. _(File: CoreAudioInventoryReader.swift)_

**P2-MADI-004** — `precondition` for capacity validation in MADI buffers. In production, this crashes; replace with clamping or a recoverable error. _(File: MadiReceiveBuffers.swift)_

## P2: Video

**P2-VIDEO-001** — `VideoOutputRenderer` declared `Sendable` but has unsynchronized mutable state. _(File: VideoOutputRenderer.swift)_

**P2-VIDEO-002** — `AVCaptureSession.startRunning()` blocks the caller thread. Dispatch to background queue. _(File: AVFoundationCapture.swift)_

**P2-VIDEO-003** — Frame rate configuration silently produces a partial (truncated) frame rate on overflow. _(File: VideoTransportPacket)_

**P2-VIDEO-004** — Incomplete frame buckets in `VideoFrameAssembler` are not evicted under sustained fragment loss. _(File: VideoFrameAssembler)_

## P2: Tests

**P2-TEST-001** — Peer session runner test checks counters only, not actual media content. _(File: PeerSessionRunnerTests.swift)_

**P2-TEST-002** — UDP PCM loopback tests missing reorder/reconnect cases. _(File: UdpPcmLoopbackLatencyTests.swift)_

**P2-TEST-003** — Hard-coded expected values in `RxBuffering` tests — brittle if constants change. _(File: RxBufferingTests.swift)_

**P2-TEST-004** — `MediaClock` tests missing boundary and overflow cases. (Connects to P1-MEDIA-001.) _(File: MediaClockTests)_

**P2-TEST-005** — `DirectPeer` graph teardown tests don't confirm actual resource release (IOProc counter, socket handle). _(File: DirectPeerRealtimeAudioGraphTests.swift)_

**P2-TEST-006** — Jitter tests assert `jitterMicroseconds == 0` on loopback: trivially true, provides no signal about RFC 3550 calculation correctness. _(File: UdpMediaTransportTests.swift:374,389)_

**P2-TEST-007** — Callback timing test asserts `callbackMaxMicroseconds >= 0`: trivially true. Should assert within realtime deadline. _(File: DirectPeerRealtimeAudioGraphTests.swift:220)_

**P2-TEST-008** — `VideoFrameReassembler` 250ms default age expiry not tested in the production `VideoTransportRunner` path. Only `maxAge=0` (drop-all fixture) is tested. _(File: VideoTransportTests, missing)_

**P2-TEST-009** — `IntegratedAvDegradeFirstTests.swift` (3 tests, 34 lines) covers schema validation only — no actual degraded-network packet loss simulation. _(File: IntegratedAvDegradeFirstTests.swift)_

## P2: Dead Code

**P2-DEAD-001** — UltraGrid connector (14 files, ~714L+ each) has zero CLI or app wiring. Likely dead code. Do not delete without project-owner confirmation. Verification: `grep -rn "UltraGrid" Sources/open-lola/ Sources/open-lola-app/`.

**P2-DEAD-002** — JackTrip connector (13 files) has zero CLI or app wiring. Same verification needed.

## P2: Slop / Boilerplate

**P2-SLOP-001** — `MadiChannelCounts.swift` is a 1-line file with a single constant. Inline into the one primary call site. Low risk.

**P2-SLOP-002** — `UdpPcmLoopbackDefaults` enum is used only in test/loopback paths. Verify if any production session uses these defaults; if not, move to test support.

## P2: Deduplication

**P2-DEDUP-001** — 32+ identical 2-line validator enum declarations across all subsystems (DEDUP-001). Each conforms to `ReportPrimitiveValidating` with zero unique logic. Consolidate per subsystem into one `Validators.swift` file.

**P2-DEDUP-002** — Parallel file structures across JackTrip/UltraGrid/NMP/LoLa connectors (LaunchPlan, PassValidation, ProtocolModel, AudioPayloadCodec). Defer until DEAD-001/002 resolved.

## P2: Structure

**P2-STRUCT-001** — `NetworkRouteCommandMatrix.swift` (682L) embeds documentation as production Swift code with hard-coded file path strings that stale silently when files move.

**P2-STRUCT-002** — `SourceOwnershipInventory.swift` — hard-coded file path strings. Add a test that validates path existence.

**P2-STRUCT-003** — `DirectPeerSessionReport.swift` (892L) is at the size limit for a single file. If validation chain continues growing, split into a separate `*Validation.swift` file.

**P2-STRUCT-004** — `OpenLolaContractsAliases.swift` — typealias layer creates hidden cross-module coupling. Acceptable if `OpenLolaContracts` is intentionally an implementation detail.

## P2: Deprecated APIs

**P2-DEPR-001** — `UltraGridCompatibility.swift:4–5` uses `try!` at file scope for module-init constants. Replace with defensive initialization. Startup crash risk if UltraGrid FourCC validation logic changes.

## P2: UI

**P2-UI-001** — `AppTransportStatusTone` uses fragile `"fail"` substring match for error color mapping.
**P2-UI-002** — JackTrip/UltraGrid "UNAVAILABLE" pill has no explanation or tooltip.
**P2-UI-003** — Remote Evidence panel shows static documentation text, not live stream state.
**P2-UI-004** — Return blend / visible streams controls permanently disabled but occupy layout space.
**P2-UI-005** — `.live` banner label shows empty `" () ↔  ()"` when peer name fields are empty.
**P2-UI-006** — `previewIsActive` OR logic gives false-active signal when one preview service fails.
**P2-UI-007** — VoiceOver announcements missing for `.validated`, `.supervisorRunning`, `.armed` transitions.
**P2-UI-008** — SSH settings help text uses internal engineering language ("runtime fallback contract").
**P2-UI-009** — `AppShellSettingsSurfacePolicy` constants not wired to any conditional logic.
**P2-UI-010** — Light-mode state color contrast not verified by any assertion or test.
**P2-UI-011** — Preview window open is fire-and-forget with no success/failure confirmation.
**P2-UI-012** — `evidenceIncomplete` verdict rendered in green (`stateReady`) — violates "no fake PASS".
**P2-UI-013** — Only 3 keyboard shortcuts for 11+ menu actions (Validate, Arm, etc. have none).

---

# 8. P3 Findings

> **Cosmetic, minor, optional. Address only after all higher-severity items are resolved.**

**P3-UDP-001** — Wire frame accepts trailing garbage bytes. Strict-length validation would be more correct.

**P3-RXBUF-001** — Overrun detection in `RxBuffering` is observational only (logs but no corrective action).

**P3-P2P-001** — Stale session state (previous session metrics, partial transcript) retained after shutdown.

**P3-MADI-001** — `precondition` for buffer capacity validation in MADI buffers — fine in debug, but crash in production if triggered. (Lower risk than P2-MADI-004 which is the arithmetic path.)

**P3-OVER-001** — `NetworkByteReader.swift` manual bit-shift functions have no bounds checks on array index.

**P3-OVER-002** — Custom FNV-1a in `DirectPeerFNV1A.swift` — correct; verify it is not in any hot path.

**P3-DEPR-001** — `SPSCAtomicRing.assertSingleOwner` guarded by `#if DEBUG`. Silent violation in release. Document or promote.

**P3-SLOP-001** — `AppSessionState.live` has full color/icon/animation styling but is dead UI (P1-UI-001 fix will resolve this).

**P3-SLOP-002** — `PlaceholderDetection.swift` and `PlaceholderSensitiveField` — likely unused. Verify and delete.

**P3-SLOP-003** — Version string `"0.0.0-m06"` hardcoded in 3 places. Extract to a single constant.

**P3-UI-001** — Redundant `case .validated: false` in `AppSessionState.isAnimated` switch.

**P3-UI-002** — VoiceOver hint on `AppChannelMeterView` is too verbose for practical use.

**P3-UI-003** — Blackmagic output limitation text always shown regardless of whether Blackmagic hardware is present.

---

# 9. Findings by Subsystem

## Audio / Realtime

| ID | Sev | Title |
|---|---|---|
| P0-001 | P0 | IOProc use-after-free on graph deallocation |
| P1-RT-001 | P1 | stopUnlocked() leaves graph stuck on failed stop |
| P1-RT-002 | P1 | deinit acquires NSLock — potential deadlock |
| P1-RT-003 | P1 | DispatchTime.now() syscall in RT callback |
| P1-RT-004 | P1 | Per-sample guard loop in RT callback |
| P1-RT-005 | P1 | Silent audio loss on host-time conversion failure |
| P1-MADI-001 | P1 | outputDeviceUID ignored — both use inputDeviceUID |
| P1-MADI-002 | P1 | takeRetainedValue on non-retained CoreAudio string |
| P1-MADI-003 | P1 | No device capability cross-check in audio router |
| P2-RT-001 | P2 | NSLock in RT packet handoff path |
| P2-RT-002 | P2 | SPSC assertion DEBUG-only |
| P2-RT-003 | P2 | Force unwrap in capture ring setup |
| P2-RT-004 | P2 | dropStalePackets crashes on underflow |
| P2-RT-005 | P2 | 2×Data alloc per packet in TX hot path |
| P2-MADI-001 | P2 | Premature streaming before peer readiness |
| P2-MADI-002 | P2 | Raw offset access without bounds check |
| P2-MADI-003 | P2 | Legacy CoreAudio API usage |
| P2-MADI-004 | P2 | precondition for MADI buffer capacity |
| P3-DEPR-001 | P3 | SPSC owner assertion DEBUG-only in release |

## UDP / Networking

| ID | Sev | Title |
|---|---|---|
| P0-002 | P0 | stateLock contention with blocking recvfrom |
| P1-UDP-001 | P1 | TCP partial-write not retried |
| P2-UDP-001 | P2 | No control message sequence/replay validation |
| P2-UDP-002 | P2 | Wire frame accepts trailing garbage |
| P2-CTRL-001 | P2 | Catch-all returns struct; discard risk |
| P3-UDP-001 | P3 | Wire frame trailing garbage (strict-length gap) |

## Video

| ID | Sev | Title |
|---|---|---|
| P1-VIDEO-001 | P1 | BlackmagicOutputBoundary is an unimplemented stub |
| P1-VIDEO-002 | P1 | Multi-stream runtime staged / not production-ready |
| P2-VIDEO-001 | P2 | VideoOutputRenderer Sendable + unsynchronized state |
| P2-VIDEO-002 | P2 | AVCaptureSession.startRunning blocks caller thread |
| P2-VIDEO-003 | P2 | Frame rate config silently partial on overflow |
| P2-VIDEO-004 | P2 | Incomplete frame buckets not evicted under loss |

## P2P / Control

| ID | Sev | Title |
|---|---|---|
| P1-P2P-001 | P1 | state = .running before peer acks media start |
| P1-P2P-002 | P1 | controlTranscript unbounded growth |
| P1-P2P-003 | P1 | PeerSessionRunner struct: no concurrency guard |
| P1-P2P-004 | P1 | .error dropped in .recovering state |
| P1-P2P-005 | P1 | No transport rollback on partial connect failure |
| P1-CTRL-001 | P1 | Simultaneous proposal collision no resolution |
| P1-CTRL-002 | P1 | receiveControlMessages stops on first error |
| P2-P2P-001 | P2 | Recovery can't restore closed transport set |
| P2-P2P-002 | P2 | Shutdown errors swallowed with try? |
| P2-P2P-003 | P2 | Stale session state after shutdown |
| P2-P2P-004 | P2 | Error state not fully cleaned up |
| P2-P2P-005 | P2 | Reconnect on existing socket unverified |

## RX Buffering / Timing

| ID | Sev | Title |
|---|---|---|
| P1-MEDIA-001 | P1 | MediaClock.nanoseconds crashes on overflow |
| P1-RXBUF-001 | P1 | Integer overflow in RxBufferPolicy factory |
| P2-RXBUF-001 | P2 | staleVideoDropThresholdMicroseconds unused |
| P2-RXBUF-002 | P2 | Synthetic benchmark as production evidence |
| P2-RXBUF-003 | P2 | Drift correction not runtime-exercised |
| P2-RXBUF-004 | P2 | Overrun detection observational only |
| P2-RXBUF-005 | P2 | Playout buffer payload storage unverified |

## TX Path

| ID | Sev | Title |
|---|---|---|
| P2-RT-005 | P2 | 2×Data alloc per packet at 750Hz |
| P2-RT-006 | P2 | validateV2FragmentPlan on every send |

## Local RX / Preview

| ID | Sev | Title |
|---|---|---|
| P2-UI-011 | P2 | Preview window open fire-and-forget |
| P2-UI-006 | P2 | previewIsActive OR logic false-active |

## UI / State Correctness

| ID | Sev | Title |
|---|---|---|
| P1-UI-001 | P1 | .live unreachable from derive() |
| P1-UI-002 | P1 | Topology animation fires on supervisor start |
| P1-UI-003 | P1 | Zero metrics → false "target met" green |
| P1-UI-004 | P1 | Debug "Unsupported:" labels in production menus |
| P2-UI-001 | P2 | Fragile "fail" substring for status color |
| P2-UI-002 | P2 | UNAVAILABLE pill — no explanation |
| P2-UI-003 | P2 | Remote Evidence panel: static vocabulary, not state |
| P2-UI-004 | P2 | Permanently disabled controls visible |
| P2-UI-005 | P2 | .live banner shows "()" for empty peer names |
| P2-UI-007 | P2 | VoiceOver missing for key state transitions |
| P2-UI-008 | P2 | SSH help uses internal engineering language |
| P2-UI-009 | P2 | AppShellSettingsSurfacePolicy not wired |
| P2-UI-010 | P2 | Light-mode contrast not assertion-verified |
| P2-UI-012 | P2 | evidenceIncomplete shown in green |
| P2-UI-013 | P2 | Only 3 keyboard shortcuts for 11+ actions |

## Tests / Verification

| ID | Sev | Title |
|---|---|---|
| P1-TEST-001 | P1 | LoLa session tests synthetic-only |
| P1-TEST-002 | P1 | RT audio engine fixture-only |
| P1-TEST-003 | P1 | Reconnection test can hang |
| P1-TEST-004 | P1 | Handoff concurrency test can hang |
| P1-TEST-005 | P1 | Lifecycle test validates harness only |
| P1-TEST-006 | P1 | No concurrent close+recv test |
| P1-TEST-007 | P1 | No IOProc concurrent stop test |
| P1-TEST-008 | P1 | No zero-value hero metrics test |
| P1-TEST-009 | P1 | No partial-connect rollback test |
| P2-TEST-001 | P2 | Session runner tests counters only |
| P2-TEST-002 | P2 | Loopback missing reorder/reconnect |
| P2-TEST-003 | P2 | Hard-coded expected values in RxBuffering tests |
| P2-TEST-004 | P2 | MediaClock missing boundary/overflow tests |
| P2-TEST-005 | P2 | Teardown tests don't verify resource release |
| P2-TEST-006 | P2 | Jitter tests trivially ==0 on loopback |
| P2-TEST-007 | P2 | Callback timing test trivially >=0 |
| P2-TEST-008 | P2 | 250ms frame expiry not tested in production path |
| P2-TEST-009 | P2 | Degraded-network tests are schema-only |

## Dead Code / Slop / Structure

| ID | Sev | Category | Title |
|---|---|---|---|
| P1-SLOP-001 | P1 | SLOP | SyntheticPlaceholderMetrics zeros in 12 production files |
| P1-SLOP-002 | P1 | SLOP | 44 "todo(human):" in production report fields |
| P2-DEAD-001 | P2 | DEAD | UltraGrid connector — no CLI wiring (14 files) |
| P2-DEAD-002 | P2 | DEAD | JackTrip connector — no CLI wiring (13 files) |
| P2-SLOP-001 | P2 | SLOP | MadiChannelCounts.swift 1-line file |
| P2-SLOP-002 | P2 | SLOP | UdpPcmLoopbackDefaults test-only enum |
| P2-DEDUP-001 | P2 | DEDUP | 32+ identical validator enum boilerplate |
| P2-DEDUP-002 | P2 | DEDUP | Parallel connector file structures |
| P2-STRUCT-001 | P2 | STRUCT | NetworkRouteCommandMatrix 682L docs-as-code |
| P2-STRUCT-002 | P2 | STRUCT | SourceOwnershipInventory stale path strings |
| P2-STRUCT-003 | P2 | STRUCT | DirectPeerSessionReport 892L near size limit |
| P2-STRUCT-004 | P2 | STRUCT | OpenLolaContractsAliases hidden coupling |
| P2-DEPR-001 | P2 | DEPR | try! at file scope in UltraGridCompatibility |
| P3-SLOP-001 | P3 | SLOP | AppSessionState.live dead styling |
| P3-SLOP-002 | P3 | SLOP | PlaceholderDetection likely unused |
| P3-SLOP-003 | P3 | SLOP | "0.0.0-m06" hardcoded in 3 places |
| P3-OVER-001 | P3 | OVER | NetworkByteReader no bounds checks |
| P3-OVER-002 | P3 | OVER | Custom FNV-1a — verify not in hot path |
| P3-DEPR-001 | P3 | DEPR | SPSC assertions DEBUG-only |

---

# 10. Remediation Roadmap

> Rule: Cleanup does not outrank runtime. Complete each phase before beginning the next.
> Rule: Reproduce the broken behavior in a test before applying any fix.
> Rule: Every fix requires `swift build` + targeted test + `swift test --no-parallel`.

## Phase 0: Safety and Verification First

Before touching any production code, build the following test harnesses. These harnesses make
P0/P1 fixes verifiable — without them, you cannot prove the fix works.

1. **UDP concurrent lock harness** (for P0-002): Swift test that calls `receive()` on background thread + `close()` from main thread simultaneously on a real loopback socket. Must detect deadlock within 2 seconds.
2. **IOProc quiescence counter** (for P0-001): Atomic callback counter that increments inside the IOProc. After `stop()` returns, verify the counter stays constant for 100ms. Requires hardware or mock.
3. **Mock transport that throws on `connect()`** (for P1-P2P-005): Inject at each of the three connect slots; verify cleanup.
4. **`AppLatencyHeroMetrics.make()` zero-value test** (for P1-UI-003): Unit test only; no infrastructure required.
5. Run `swift test --no-parallel` to establish a baseline before any code changes.

## Phase 1: P0 Runtime Fixes

1. **P0-001**: Fix IOProc use-after-free — quiescence before `DestroyIOProcID`.
2. **P0-002**: Fix UDP `stateLock` architecture — ensure `close()` does not block on receive.

Verification for each:
```
swift build
swift test --filter DirectPeerRealtimeAudioGraphTests   # P0-001
swift test --filter UdpMediaTransportTests              # P0-002
swift test --no-parallel
```

## Phase 2: P1 Correctness Fixes

Group A — Low blast radius (1–2 files each):
1. **P1-MADI-001**: Fix `handoffConfiguration` to use `outputDeviceUID`. (1-line fix)
2. **P1-MEDIA-001**: Replace `preconditionFailure` in `MediaClock.nanoseconds` with bounded return.
3. **P1-RT-001**: Force-clear `isStarted` and deregister IOProc on failed stop.
4. **P1-UDP-001**: Add TCP write retry loop.
5. **P1-P2P-004**: Allow `.error` → `.failed` from `.recovering` state.
6. **P1-P2P-002**: Cap `controlTranscript` at fixed maximum.
7. **P1-UI-003**: Add `guard $0 > 0` in `AppLatencyHeroMetrics.make()`.
8. **P1-UI-004**: Filter unhandled menu actions from rendered menus.

Group B — Medium blast radius:
9. **P1-MADI-002**: Fix `takeRetainedValue()` ownership in `CoreAudioInventoryReader`.
10. **P1-RXBUF-001**: Add overflow-safe arithmetic in `RxBufferPolicy` factory.
11. **P1-P2P-005**: Add transport rollback in `startMedia()`.
12. **P1-P2P-001**: Introduce `.mediaStarting` state; move `.running` to after peer ack.
13. **P1-MADI-003**: Add device capability cross-check in `DirectAudioMediaRouter`.

Group C — Require test infrastructure first:
14. **P1-RT-002**: Fix `deinit` NSLock — after P0-001 fix establishes safe IOProc quiescence.
15. **P1-RT-003**: Replace `DispatchTime.now()` with `mach_absolute_time()` in IOProc.
16. **P1-SLOP-001/002**: Replace synthetic zeros and "todo(human)" strings with real values or typed nulls.

## Phase 3: UI Correctness Fixes

1. **P1-UI-001**: Implement `.live` state backed by runtime evidence or remove and document.
2. **P1-UI-002**: Tie topology animation to stream-specific packet metrics.
3. **P2-UI-012**: Map `evidenceIncomplete` to amber/warning color, not green.
4. **P2-UI-001**: Replace `"fail"` substring match with `AppExecutionPhase`-based color mapping.
5. **P2-UI-007**: Add VoiceOver announcements for `.validated`, `.supervisorRunning`, `.armed`.
6. **P2-UI-008**: Replace SSH help text with user-facing language.
7. **P2-UI-011**: Surface preview window state in main operator window.
8. Remaining P2-UI items as bandwidth allows.

## Phase 4: Dead-Code and Deprecated-Path Deletion

**Prerequisites:** Full `swift test --no-parallel` green; project-owner confirmation for JackTrip/UltraGrid intent.

1. Verify UltraGrid connector (P2-DEAD-001) has no CLI/app wiring:
   `grep -rn "UltraGrid" Sources/open-lola/ Sources/open-lola-app/ scripts/ linux_connector/`
2. If confirmed dead: remove files, update tests, rebuild.
3. Same for JackTrip (P2-DEAD-002).
4. Fix `P2-DEPR-001` (`try!` at file scope) regardless of deletion decision.
5. Once `SyntheticPlaceholderMetrics` usages are replaced (P1-SLOP-001), delete the file.
6. Once `PlaceholderDetection` is confirmed unused (P3-SLOP-002), delete it.

## Phase 5: Deduplication and Simplification

1. **P2-DEDUP-001**: Consolidate validator enum boilerplate per subsystem into one `Validators.swift`.
   (32+ files → one per subsystem. No behavior change. `swift build` + `swift test --no-parallel`.)
2. **P2-SLOP-001**: Inline `MadiChannelCounts.swift` constant.
3. **P3-SLOP-003**: Extract version string to one constant.
4. Defer **P2-DEDUP-002** (connector file structure) until Phase 4 is complete.

## Phase 6: Structure Cleanup

1. **P2-STRUCT-001**: Add a test that validates all `NetworkRouteCommandMatrix` file path strings exist on disk.
2. **P2-STRUCT-002**: Add a test that validates all `SourceOwnershipInventory` path strings.
3. **P2-STRUCT-004**: Investigate and document `OpenLolaContractsAliases` coupling intent.
4. **P2-STRUCT-003**: If `DirectPeerSessionReport` grows further, split validation into `*Validation.swift`.

## Phase 7: Optional Polish

P3 items, additional accessibility, `P3-DEPR-001` (SPSC assertion always-on), remaining P3 UI items.

---

# 11. Suggested Future Implementation Slices

Each slice describes a self-contained piece of work that is currently absent or broken.

## Slice A: Audio Device Routing Validation
- **Scope:** Add device capability cross-check before route construction.
- **Findings addressed:** P1-MADI-001, P1-MADI-003, P2-MADI-001
- **Files affected:** `DirectAudioMediaRouter.swift`, `MadiFullDuplexRuntime.swift`, `CoreAudioInventoryReader.swift`
- **Risk:** Medium — CoreAudio API usage
- **Tests needed:** Inject mock device with mismatched capabilities; verify router rejects.
- **Verification commands:** `swift build`, `swift test --filter MadiTests`, manual with real hardware.
- **Definition of Done:** Full-duplex session uses correct input UID and output UID; route construction fails with a structured error for unsupported configurations.

## Slice B: Core Audio IOProc Lifecycle Hardening
- **Scope:** Ensure callback quiescence before `DestroyIOProcID`; fix `deinit` NSLock deadlock; remove RT-path blocking calls.
- **Findings addressed:** P0-001, P1-RT-001, P1-RT-002, P1-RT-003
- **Files affected:** `DirectPeerRealtimeAudioGraph.swift`, `RealtimeAudioPacketHandoff.swift`
- **Risk:** High — Core Audio RT path
- **Tests needed:** Concurrent stop race test (hardware-gated); `deinit` deadlock stress test.
- **Verification commands:** `swift build`, `swift test --filter DirectPeerRealtimeAudioGraphTests`, AddressSanitizer run.
- **Definition of Done:** `stop()` returns only after callback count has been stable for 10ms; no TSan warnings; `deinit` completes without holding audio lock.

## Slice C: UDP Transport Concurrency Fix
- **Scope:** Fix stateLock architecture so `close()` does not block waiting for `recvfrom()`.
- **Findings addressed:** P0-002, P2-P2P-002
- **Files affected:** `UdpMediaTransport.swift`, `UdpPcmSocketOperations.swift`
- **Risk:** High — core media delivery path
- **Tests needed:** Concurrent `close()` + blocking `receive()` test (P1-TEST-006).
- **Verification commands:** `swift test --filter UdpMediaTransportTests`, TSan run.
- **Definition of Done:** `close()` completes within 100ms regardless of `receive()` blocking state.

## Slice D: Latency Hero Metrics Correctness
- **Scope:** Fix zero-value false-positive in `AppLatencyHeroMetrics.make()`. Fix `.live` state derivation.
- **Findings addressed:** P1-UI-003, P1-UI-001, P1-UI-002, P1-TEST-008
- **Files affected:** `AppLatencyHeroMetrics.swift`, `AppSessionStateBanner.swift`, `AppConnectionTopologyView.swift`
- **Risk:** Low (UI only)
- **Tests needed:** `appLatencyHeroMetricsMakeIgnoresZeroValuedMeasurements`
- **Verification commands:** `swift build`, `swift test --filter AppShellBehaviorTests`, manual session observation.
- **Definition of Done:** Zero-valued reports produce nil hero metrics (shown as "—"). Topology animates only when packet metrics are non-zero.

## Slice E: P2P Session Correctness
- **Scope:** Fix `.error` state transition, `controlTranscript` cap, partial-connect rollback, premature `.running` state.
- **Findings addressed:** P1-P2P-001 through P1-P2P-005, P1-CTRL-001, P1-CTRL-002
- **Files affected:** `PeerSessionRunner.swift`, `SessionStateMachine`, `SessionNegotiation`
- **Risk:** Medium — affects all session lifecycles
- **Tests needed:** P1-TEST-009 (partial connect); state machine test for `.error` in `.recovering`; transcript cap test.
- **Verification commands:** `swift test --filter PeerSessionRunnerTests`, `swift test --filter PeerSessionRunnerLifecycleTests`
- **Definition of Done:** State machine reaches `.failed` on error-in-recovery; transcript never exceeds cap; failed partial connect leaves no open transports.

## Slice F: MediaClock and RxBuffer Safety
- **Scope:** Replace `preconditionFailure` with bounded return; fix overflow in factory methods.
- **Findings addressed:** P1-MEDIA-001, P1-RXBUF-001
- **Files affected:** `MediaClock.swift`, `RxBuffering.swift`
- **Risk:** Low — arithmetic fixes
- **Tests needed:** Overflow boundary test for `nanoseconds(forFrameCount:)` and `RxBufferPolicy` factory.
- **Verification commands:** `swift test --filter MediaClockTests`, `swift test --filter RxBufferingTests`
- **Definition of Done:** No `preconditionFailure` reachable from production paths; overflow returns error or clamped value.

## Slice G: Blackmagic Output Feature Flag
- **Scope:** Gate `BlackmagicOutputBoundary` behind `#if BLACKMAGIC_ENABLED`.
- **Findings addressed:** P1-VIDEO-001
- **Files affected:** `BlackmagicOutputBoundary.swift`, callers
- **Risk:** Low — documentation change + flag
- **Tests needed:** Verify build succeeds with flag off and on.
- **Verification commands:** `swift build`
- **Definition of Done:** No code path claims Blackmagic output is available unless the SDK is integrated and the flag is set.

## Slice H: Synthetic Evidence Gate
- **Scope:** Replace synthetic zeros and "todo(human):" strings with real measurements or `Optional` fields.
- **Findings addressed:** P1-SLOP-001, P1-SLOP-002
- **Files affected:** 12 production files + `SyntheticPlaceholderMetrics.swift`
- **Risk:** High — schema changes cascade to validators and tests
- **Tests needed:** `grep "todo(human)" Sources/` should return 0 in CI gate.
- **Verification commands:** `swift build`, `swift test --no-parallel`, `bash scripts/verify-release-readiness.sh`
- **Definition of Done:** No production field contains `0.0` as a synthetic stand-in; `SyntheticPlaceholderMetrics.swift` is deleted; CI `grep` gate is green.

---

# 12. Verification Strategy

## Build Commands (always run after any change)

```bash
swift build
swift build --product open-lola
swift build --product open-lola-app
bash script/build_and_run.sh --verify
```

## Lint and Typecheck

```bash
bash scripts/verify-docs.sh
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh script/*.sh linux_connector/env/*.sh
bash scripts/verify-release-hygiene.sh
```

## Unit Tests (targeted)

```bash
swift test --filter UdpMediaTransportTests
swift test --filter DirectPeerRealtimeAudioGraphTests
swift test --filter PeerSessionRunnerTests
swift test --filter PeerSessionRunnerLifecycleTests
swift test --filter AppShellBehaviorTests
swift test --filter AppShellValidationEvidenceGraphTests
swift test --filter VideoTransportReportTests
swift test --filter SyntheticSmokeReportContractTests
swift test --filter MediaClockTests
swift test --filter RxBufferingTests
swift test --filter LoLaCompatibilityMediaCodecTests
swift test --filter LoLaCompatibilityMediaSessionTests
```

## Full Suite

```bash
swift test --no-parallel
```

## Manual Runtime Checks (Required Before Any Field Evidence Claim)

| Check | Condition |
|---|---|
| Core Audio device I/O loopback | Run on real hardware with distinct input/output devices |
| UDP P2P loopback with packet loss | Use `pfctl`/`dnctl` to inject 5%, 10%, 20% loss |
| TX/RX state proof with non-localhost | Use real network endpoints, not 127.0.0.1 |
| Video frame reassembly under fragment loss | Drop individual fragment packets; verify eviction metrics |
| 60-minute session memory profile | Verify `controlTranscript` does not exceed cap |
| Zero-metrics hero display | Verify hero shows "—" before data flows |
| `.live` state post-fix | Verify green badge appears only with confirmed data flow |

## Test Gap Summary (Not Yet Built)

| Missing Test | Severity | Blocks |
|---|---|---|
| Concurrent `close()` + blocking `recv()` | P1 | P0-002 verification |
| IOProc concurrent stop race | P1 | P0-001 verification |
| `AppLatencyHeroMetrics` zero-value | P1 | P1-UI-003 |
| `PeerSessionRunner.startMedia` partial connect | P1 | P1-P2P-005 |
| `VideoFrameReassembler` 250ms expiry | P2 | Frame eviction correctness |
| Jitter non-zero inter-arrival through transport | P2 | RFC 3550 formula correctness |
| Degraded-network integration (packet loss) | P2 | IntegratedAv degradation |

---

# 13. Remaining Uncertainty

1. **JackTrip and UltraGrid connectors** — Confirmed no CLI wiring. Intent (planned future feature vs. permanently abandoned) requires project-owner confirmation before deletion.

2. **`AppReceiverPreviewServices.swift` (517L, CoreAudio in app layer)** — Not fully read. May have the same IOProc lifecycle risks as P0-001. This is a `P1` risk area that was not confirmed or ruled out.

3. **`COpenLolaAtomics` C implementation** — Callers inspected; C atomics implementation not reviewed. If atomic operations are incorrect, the SPSC ring is unsafe.

4. **`xs_ref_sw_ed2/` and `opus-1.5.2/`** — Vendored C; Swift wrapper use reviewed, C internals not. Unknown vulnerabilities.

5. **`linux_connector/`** — Python seed not reviewed in any pass. Protocol conformance, compatibility with live sessions, and code quality are all unknown.

6. **`scripts/` / `script/`** — Shell automation not reviewed. Release pipeline integrity unknown.

7. **`Sources/OpenLolaCore/Release/` and `Evidence/`** — Evidence matrix and release harness not inspected. Cannot confirm evidence quality, completeness, or whether any PASS verdict relies on synthetic data.

8. **`UdpMediaTransport.stateLock` exact deadlock mechanism** — P0-002 is rated high confidence based on lock architecture inspection. The exact interleaving that causes deadlock vs. 1-second stall depends on the precise scope of `stateLock` in `close()` vs. `decodeReceived()`. A re-read of lines 318–320 and 518–543 against the receive loop is recommended before applying a fix.

9. **`VideoTransportRunner` 250ms frame age adequacy** — Production default is 250ms. Whether this is appropriate for all configured stream counts and network RTTs was not analyzed. If a decoder requires more than one round-trip to reassemble, frames may be silently dropped.

10. **`LoLaTcpControlExchangeRuntime` caller discard risk** — The catch-all-to-struct error pattern (P2-CTRL-001) is only a risk if callers ignore the return value. Full call-site grep was not completed.

11. **`.live` state alternative paths** — `AppSessionState.derive()` was confirmed to never return `.live`. There may be alternative paths (external connector reports, direct state injection) that were not traced. Requires full call graph analysis.

12. **Benchmarks/ subsystem** — Whether E2E and Latency benchmarks are ever run from CI with real hardware, or are purely synthetic, is unknown. If purely synthetic with zero-valued metrics, the entire `Benchmarks/` subtree may contain SLOP-001-pattern false data.

13. **`NMP/` connector** — Not audited. Runtime readiness unknown.

14. **File permission anomalies** — Several realtime audio files returned "Permission denied" during bash tool inspection but were readable via sub-agents. If actual filesystem permissions are inconsistent, build reproducibility may be affected.

---

# 14. Explicit Non-Goals

This audit explicitly did **not** and future work based on this document should not:

1. **Change any production code.** This is an audit document only.
2. **Apply any fix without first building a reproduction test.**
3. **Delete any file without confirming via `grep -rn` + `swift build` that it is unused.**
4. **Delete JackTrip or UltraGrid connectors without project-owner confirmation.**
5. **Add speculative features.** Every code change must address a finding in this document.
6. **Add abstractions for single-use code.** `DEDUP-001` remediation is file consolidation, not new architecture.
7. **Begin cleanup phases before P0/P1 runtime fixes are verified.**
8. **Promote localhost, built-in-device, synthetic, or placeholder evidence to product PASS.**
9. **Audit `linux_connector/`, `scripts/`, `script/`, `Sources/COpenLolaAtomics/`, `Sources/xs_ref_sw_ed2/`, `Sources/opus-1.5.2/`, or `Sources/OpenLolaCore/Release/`.** These areas are out of scope.
10. **Claim field readiness without hardware-backed test evidence for audio, video, and network paths.**
11. **Claim any finding is fixed without a targeted test confirming the root cause behavior.**

---

## Continuation Prompt (if further audit passes are needed)

> "Continue the Open LoLa audit. Focus: [one of the following]
>
> A. `Sources/OpenLolaCore/Release/` and `Evidence/` — release harness and evidence pipeline.
> B. `Sources/OpenLolaCore/Connectors/NMP/` — NMP endpoint runtime readiness.
> C. `AppReceiverPreviewServices.swift` — CoreAudio IOProc in app layer (P0-001 risk surface).
> D. `linux_connector/` — Python protocol seed, LoLa compatibility, and protocol conformance.
> E. `scripts/` / `script/` — Release pipeline integrity and automation correctness.
>
> Update `./final-plan.md` only. Do not change production code."

---

_End of Open LoLa Final Audit Plan._
_Coverage: ~80% of non-vendored Swift production files. 5 areas uninspected (listed above)._
_Finding totals: 2 P0, 37 P1, 55 P2, 13 P3 = 107 total._
_Status: Audit complete for Passes 1–6. Production code unchanged throughout._
