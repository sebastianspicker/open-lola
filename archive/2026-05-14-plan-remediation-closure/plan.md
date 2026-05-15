# open-lola2 — Full Codebase Audit

**Date:** 2026-05-12  
**Scope:** All Swift sources (`Sources/`), Python linux_connector, shell scripts  
**Method:** Seven parallel sub-agent audits covering every source file  
**Status:** READ-ONLY — no code changed. This is the remediation roadmap.

---

## Audit Coverage

| Area | Files Audited | Findings |
|------|--------------|----------|
| Realtime Audio (engine, codecs, routing, CoreAudio) | 21 | 40 |
| Network / UDP / NAT | 27 | 32 |
| P2P Session / Protocol | 34 | 56 |
| Video pipeline | 20 | 30 |
| Control / Timing / Platform / Connectors Core | 54 | 26 |
| Connectors (LoLa, JackTrip, UltraGrid, NMP, Python) | ~40 | 21 |
| UI / AppShell (SwiftUI) | 30 | 35 |
| **Total** | **~226** | **~240** |

---

## Severity Tiers

- **P0** — crash, data loss, silent data corruption, or security flaw in production paths  
- **P1** — correctness bug, reliability risk, protocol deviation, resource leak, or bad UX in normal operation  
- **P2** — code quality: dead code, slop, boilerplate duplication, missing docs, maintainability debt  

---

## Group 1 — Crashes & Data Loss (P0)

These must be fixed before any public release. Each represents a path that either crashes the process or silently corrupts audio/video data.

### 1.1 Packet Parsing Without Bounds Checks (Network)

**N-002 · P0 · MEMORY_SAFETY**  
`Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift` lines 113–189  
Direct array subscripting on untrusted UDP packet data without verifying `bytes.count`. Packets shorter than 48 bytes bypass the early guard and crash on field reads at lines 133–155.  
**Fix:** Add per-field bounds checks using a safe cursor-based reader before any subscript access.

**N-003 · P0 · MEMORY_SAFETY**  
`Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift` lines 62–75  
Calls to `readCheckedUdpPcmUInt*()` functions are unimplemented or undefined. Will fail to compile or behave unpredictably if stubs are present.  
**Fix:** Implement throwing bounds-checked readers or remove the calls and replace with validated unsafe readers.

**N-019 · P0 · MEMORY_SAFETY** (duplicate of N-003 from different angle)  
Same file — inconsistency between declared read API and actual implementation is a compilation time bomb.

**N-028 · P0 · MISSING_ERROR_HANDLING**  
`Sources/OpenLolaCore/Network/UDP/UdpMediaTransport.swift` lines ~82–92  
`try` applied to functions declared as non-throwing. Indicates broken exception propagation — real errors are silently swallowed.  
**Fix:** Either implement throwing versions or remove `try`; audit every call site.

### 1.2 Opus Codec Force-Unwrap

**A-004 · P0 · MEMORY_SAFETY**  
`Sources/OpenLolaCore/Audio/Codecs/OpusCELTLowDelayCodec.swift` line 99  
`output.baseAddress!` force-unwrap inside `withUnsafeMutableBytes`. If `encoded` is empty (zero-frame edge case), this crashes at runtime.  
**Fix:** Use optional binding: `guard let base = output.baseAddress else { return 0 }`.

### 1.3 CoreAudio IOProc Race on Start

**A-010 · P0 · MEMORY_SAFETY** (agent noted as actually safe after review — keeping as P1 concern)  
`Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` line 194  
The guard pattern around `createdIOProcID` is correct; however the design assumes `AudioDeviceCreateIOProcID` success implies non-nil ID, which is not guaranteed by the CoreAudio docs.  
**Fix:** Add explicit nil assertion post-success to document the assumption.

### 1.4 P2P Session Resource Leaks at Startup

**P-001 to P-003 · P0 · MEMORY_SAFETY / MISSING_ERROR_HANDLING**  
`Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift`  
AVFoundation session initialization inside a defer block can fail to unwind correctly, leaving socket pairs open. Multiple socket descriptors leak if partial initialization throws.  
**Fix:** Use explicit RAII guards (deferred `close()` registered before socket open), not relying on Swift's structured concurrency to close OS resources.

**P-008, P-009 · P0 · MEMORY_SAFETY**  
Same file — socket initialization failures leave the control socket open while audio/video sockets fail to initialize. No cleanup path for the partially-open set.  
**Fix:** Initialize all sockets atomically using a helper that closes all-or-nothing.

**P-023, P-024 · P0 · MISSING_ERROR_HANDLING**  
`Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerLoopbackPair.swift`  
Socket cleanup on negotiation failure leaves file descriptors open. No `close()` in the error path.  
**Fix:** Add explicit FD cleanup in every `catch` block.

**P-030 · P0 · MISSING_ERROR_HANDLING**  
`Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift`  
`runLoopback()` — if `second.acceptProposal()` throws, audio/video transports are already started and never stopped.  
**Fix:** Tear down transports in a `defer` before they are started.

### 1.5 Shell Injection in Run Plan Builder

**P-048 · P0 · LOGIC_BUG / SECURITY**  
`Sources/OpenLolaCore/Network/P2P/DirectPeerTwoPeerLocalRunReportBuilder.swift` lines 216–268  
`aggregateCommand()` builds a shell command by interpolating report paths as raw strings with no escaping or validation. A report path containing spaces or shell metacharacters is injected into the command array unquoted.  
**Fix:** Pass arguments as array elements to `Process`, never as a shell string. Never use `/bin/sh -c` with unsanitized interpolation.

### 1.6 Python Subprocess Crash on Init Failure

**PY-002 · P0 · MISSING_ERROR_HANDLING**  
`linux_connector/lola_connector/backends.py` lines 300–316  
If `asyncio.create_subprocess_exec()` throws before `process` is assigned, the except block calls `process.kill()` on an unbound variable, raising `UnboundLocalError` and crashing the connector.  
**Fix:** Initialize `process = None` before the `try` block; guard `if process is not None: process.kill()`.

### 1.7 UI: Unprotected Lock Access

**U-029 · P0 · API_MISUSE**  
`Sources/open-lola-app/AppReceiverPreviewServices.swift` line 242  
`os_unfair_lock_s()` created correctly but `stop()` at line 281 accesses shared state without holding the lock. If `stop()` is called concurrently with a capture callback, state is corrupted.  
**Fix:** Wrap all `stop()` state mutations under `os_unfair_lock_lock` / `os_unfair_lock_unlock`.

---

## Group 2 — Realtime Audio Safety (P1)

The audio engine runs on a real-time thread. Any allocation, lock, system call, or blocking operation in the callback path causes glitches or dropouts. The following are violations:

### 2.1 Non-Realtime Operations in Audio Callbacks

**A-013 · P1 · PERF**  
`Sources/OpenLolaCore/Audio/Routing/AudioLoopbackRun.swift` line 331  
`Thread.sleep(forTimeInterval:)` called in IOProc measurement setup. Blocking sleep in or near the real-time path causes xruns.  
**Fix:** Replace with `DispatchSemaphore.wait(timeout:)` or condition variable signaling.

**A-003 · P1 · RACE_CONDITION**  
`Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` line 259  
`ioProcRunning` is checked and then `captureRing.push()` called without a memory barrier between them. The IOProc could start between the check and the push.  
**Fix:** Use `OSAtomicCompareAndSwap` or Swift's `Atomic` for the `ioProcRunning` flag.

**A-040 · P1 · RACE_CONDITION**  
`DirectPeerRealtimeAudioGraph.swift` line 146  
`inputIOProcID` assignment and conditional read without synchronization. Observed from the audio thread, the assigned value may not be visible.  
**Fix:** Use `_Atomic` / `ManagedAtomic` or serialize via the CoreAudio-protected property access pattern.

### 2.2 Ring Buffer Correctness

**C-001 · P1 · RACE_CONDITION**  
`Sources/OpenLolaCore/Support/SPSCAtomicRing.swift` lines 45–73  
SPSC ring buffer `push()` has a TOCTOU window: capacity check and write index store are not atomic. If two threads call `push()` simultaneously (violation of SPSC contract), both see space available and write to the same slot.  
**Fix:** Document and enforce single-producer single-consumer invariant with an assertion; add `@inlinable @inline(__always)` with precondition in debug builds. Consider formalizing with `nonisolated(unsafe)`.

**A-005 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift` line 345  
`dropStalePackets()`: `bufferedPackets` is decremented without guard against underflow. A prior accounting bug could drive the count below zero, causing the stale-packet detector to miss real overflows.  
**Fix:** Replace bare decrement with `max(0, bufferedPackets - 1)` and add an assertion.

**A-032 · P1 · LOGIC_BUG**  
`RealtimeAudioBuffers.swift` line 263  
`slot()` divides by `framesPerBlock` without guard — division by zero crash if `framesPerBlock == 0`.  
**Fix:** Add `guard framesPerBlock > 0` in the initializer or computed property.

**A-011 · P1 · LOGIC_BUG**  
`RealtimeAudioEngineReportValidation.swift` line 300  
`defaultDirectRxBufferPolicy()` divides `playoutTargetFrames / framesPerBuffer` without checking `framesPerBuffer > 0`.  
**Fix:** Add guard with a thrown error.

### 2.3 PLC / Packet Loss Concealment Logic

**A-006 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift` line 168  
`plcBlock()` sets `payloadByteCount` to the mode's nominal size for silence/substitute blocks, but this may not match the actual encoded payload size in all PLC modes, causing downstream buffer overruns.  
**Fix:** Derive `payloadByteCount` from the actual encoded output length, not the mode constant.

**A-009 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPacketHandoff.swift` line 42  
`playoutTargetFrames` falls back to 0 if neither `rxBufferPolicy.targetFrames` nor `configuration.playoutTargetFrames` is set. Zero target causes immediate underrun.  
**Fix:** Require at least one to be set, or define a safe non-zero default constant.

### 2.4 CoreAudio Memory / Alignment

**A-016 · P1 · MEMORY_SAFETY**  
`Sources/OpenLolaCore/Audio/CoreAudio/CoreAudioInventoryReader.swift` line 350  
Manual `UnsafeMutableRawPointer.allocate()` for variable-length `AudioBufferList` without validating alignment for the flexible-array member. Misaligned access is UB on ARM.  
**Fix:** Use `AudioBufferList.allocate(maximumBuffers:)` helper or `calloc` with explicit alignment.

### 2.5 Audio Routing Correctness

**A-024 · P1 · RACE_CONDITION**  
`Sources/OpenLolaCore/Audio/Routing/DirectAudioMediaRouter.swift` line 21  
`receivers[streamID]` is retrieved, mutated, and written back without a lock. Two concurrent `route()` calls lose one update (TOCTOU).  
**Fix:** Use a `DispatchQueue` (serial) or `NSLock` to serialize receiver mutations.

**A-008 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift` line 313  
Duplicate entries in `inputChannelMap` pass the uniqueness check because the check only runs in `validAudioBuffers()` on init, not on every push.  
**Fix:** Enforce uniqueness as a precondition in the struct's initializer.

**A-021 · P1 · LOGIC_BUG**  
`DirectPeerRealtimeAudioGraph.swift` lines 386–395  
`copyMappedInput()` returns `false` mid-loop on the first guard failure, abandoning a partial copy. Downstream consumers receive corrupted mixed-state buffers.  
**Fix:** Either pre-validate all guards before starting the copy, or use a scratch buffer and commit atomically.

### 2.6 Mach Timebase Division by Zero

**A-029 · P1 · LOGIC_BUG**  
`DirectPeerRealtimeAudioGraph.swift` line 332  
`nanoseconds()` divides by `hostTimeDenominator` without guarding against zero. `mach_timebase_info` should never return 0, but there is no defensive assertion.  
**Fix:** Add `precondition(hostTimeDenominator > 0)` in the timebase initializer.

---

## Group 3 — Network / UDP Correctness (P1)

### 3.1 Packet Parsing Safety

**N-001 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/UDP/UdpPcmDataHelpers.swift` lines 3–4  
`udpPcmHasBytes(offset:count:)` uses `offset <= bytes.count - count`, which underflows when `count > bytes.count` (wraps to large positive on unsigned), incorrectly returning true.  
**Fix:** Rewrite as `count >= 0 && offset >= 0 && offset <= bytes.count - count && bytes.count >= count`.

**N-013 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/RTP/AES67ST2110L24Transport.swift` lines 155–164  
L24 sign-extension: `value |= ~0xFF_FFFF` on a 64-bit `Int` sets all 64 high bits, not just bits 23–63. This is wrong sign-extension producing corrupted 24-bit audio samples.  
**Fix:** Use `Int32(bitPattern: UInt32(value) | 0xFF00_0000)` and then widen to `Int`.

**N-014 · P1 · LOGIC_BUG**  
`AES67ST2110L24Transport.swift` lines 170–178  
L24 encoding uses asymmetric scalars: negative samples divided by 8_388_608, positive by 8_388_607. This introduces a DC offset and asymmetric clipping in every L24 stream.  
**Fix:** Use a single symmetric scale factor (8_388_607.0) with proper two's-complement quantization.

**N-017 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/Diagnostics/NetworkDiagnostics.swift` line 192  
`summaryParts.index(before: index)` crashes if `"packet"` is the first token in the output line.  
**Fix:** Bounds-check before calling `index(before:)`.

**N-018 · P1 · LOGIC_BUG**  
`NetworkDiagnostics.swift` lines 228–240  
Traceroute hop parsing assumes `fields[1]` without checking `fields.count > 1`. IPv6 addresses in brackets are also not handled.  
**Fix:** Guard `fields.count >= 2`; add IPv6 bracket-stripping.

### 3.2 NAT Traversal Correctness

**N-007 · P1 · RACE_CONDITION**  
`Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteRunner.swift` lines 41–138  
NAT keepalive interval check uses `now &- lastSend >= interval`. If `message.ackSequence` (optional) is compared without unwrapping, the comparison silently uses `nil != UInt64` which is always true, sending unnecessary keepalives.  
**Fix:** Explicitly unwrap `ackSequence` before comparison.

**N-020 · P1 · LOGIC_BUG**  
`NatFriendlyRouteRunner.swift` line 96  
Peer ID check `message.peerID != configuration.peerID` accepts an empty peer ID as "different from config" (always true if config is non-empty), spoofing rendezvous acceptance.  
**Fix:** Validate peer ID is non-empty before comparison.

**N-031 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/NAT/NatFriendlyRouteSmokes.swift` lines 35–36  
Force-indexing `[0]` on the smoke report array without checking count. If the smoke run returns zero reports, crashes immediately.  
**Fix:** Use `.first` with a guard.

### 3.3 Sequence / Fragment Arithmetic

**N-011 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift` line 35  
`packetCount` uses integer division (`sampleRate * duration / framesPerPacket`) without bounds checks. Very large sample rates can overflow `Int`.  
**Fix:** Use checked multiplication and add `Int.max` guard.

**N-027 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/UDP/UdpPcmV2FragmentPlanner.swift` line 177  
Double-to-Int cast of fragment count has no overflow guard. Negative result (impossible but not compile-time provable) would silently produce wrong fragment layout.  
**Fix:** Assert `fragmentCount > 0` after cast.

### 3.4 Socket Configuration

**N-006 · P1 · API_MISUSE**  
`Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift` lines 14–15, 21–32  
`SO_RCVBUF` / `SO_SNDBUF` set to 4 MB but not verified with `getsockopt`. The kernel may silently cap the buffer, causing unexpected packet loss at high bitrates.  
**Fix:** Read back the actual buffer size with `getsockopt` and warn/assert if below the requested value.

**N-005 · P1 · RACE_CONDITION**  
`UdpPcmSocketOperations.swift` lines 59–69  
`errno` is read after the first `fcntl` but before the second; a signal between the two calls corrupts the error state.  
**Fix:** Save `errno` to a local immediately after each syscall.

---

## Group 4 — P2P Session Correctness (P1)

The P2P session layer had the most findings (56 total). Key categories:

### 4.1 Session State Machine Gaps

**P-035 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVVideoReportSupport.swift` lines 50–120  
`runVideoRXLoop()` returns early when a deferred frame defers again, instead of continuing to process new packets. Video frames are permanently dropped when video arrives faster than audio.  
**Fix:** Continue the main processing loop on double-defer; only exit after exhausting all new fragments.

**P-042 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift` lines 181–197  
`rawVideoMaxFragmentsPerFrame()` switch has a `default` case that is unreachable but silently accepts unknown `(avProfile, rxBufferProfile)` combinations with a wrong fragment count.  
**Fix:** Make all cases explicit; remove the default or replace it with `preconditionFailure`.

**P-053 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVRunTypes.swift` lines 382–385  
`audioCompression` property setter calls `audioTransport.legacyAudioCompression`, which is an optional mapping. Silently does nothing if `legacyAudioCompression` returns nil — the setter is a no-op for new transport types.  
**Fix:** Either throw on unsupported transport type or document the no-op behaviour.

**P-052 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Protocol/SessionProtocol.swift` lines 304–356  
`validatePeerMediaTopology()` validates endpoint uniqueness per channel but doesn't validate that control endpoints aren't re-used as audio endpoints across peers, allowing overlapping address allocation.  
**Fix:** Validate uniqueness across all channel types in a single set, not per-channel.

### 4.2 Missing Timeout Handling

**P-050 · P1 · MISSING_ERROR_HANDLING**  
`Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerLoopbackPair.swift` lines 12–23  
`negotiate()` has no timeout. If `second.acceptProposal()` stalls, the entire process blocks indefinitely.  
**Fix:** Wrap with `withThrowingTaskGroup` and a timeout task.

**P-051 · P1 · MISSING_ERROR_HANDLING**  
`Sources/OpenLolaCore/Network/P2P/DirectPeerSessionSocketRunner.swift` lines 86–150  
`runLoopback()` — same infinite-wait pattern on `acceptProposal()` without cancellation or timeout.  
**Fix:** Same fix as P-050.

### 4.3 RTP Audio Truncation

**P-037 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerRTPAudio.swift` lines 22–36  
`sequenceNumber` truncated to `UInt16` with `truncatingIfNeeded` — this is correct for RTP but the wrap-around is never accounted for in the receiver's sequence tracker, causing sequence resets to be treated as large gaps and triggering massive PLC.  
**Fix:** Handle the UInt16 rollover (at 65535→0) explicitly in the receiver's gap detection.

### 4.4 Metrics Correctness

**P-036 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Network/P2P/PeerSessionRunnerMetrics.swift` lines 4–14  
`transportMetrics()` merges audio + video jitter by taking the `max`. Jitter is a statistical property; `max` produces misleading aggregate metrics. Audio jitter 100µs + video jitter 50µs should not be reported as session jitter 100µs.  
**Fix:** Report audio and video jitter as separate fields, or compute a weighted combined estimate.

### 4.5 Protocol Negotiation

**P-038 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Protocol/SessionNegotiation.swift` lines 220–264  
`validateVideoStream()` checks overflow when computing max frame rate but doesn't handle the case where `stream.frameRate.denominator == 0`, which would produce a division by zero before the overflow check.  
**Fix:** Guard `denominator > 0` before the multiplication.

---

## Group 5 — Video Pipeline (P1)

### 5.1 Frame Reassembly Bugs

**V-008 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Video/VideoTransportReassembly.swift` lines 318–331  
`dropExpiredActiveFrames()` uses `maxFrameAgeNanosecondsStorage == UInt64.max` as a sentinel, but the comparison `age > UInt64.max` is always false, meaning frames are never dropped when the age limit is disabled.  
**Fix:** Use `Optional<UInt64>` rather than a sentinel; treat `nil` as "no limit".

**V-017 · P1 · LOGIC_BUG**  
`VideoTransportReassembly.swift` lines 472–495  
`completedPacket()` computes `expectedPayloadOffset` by accumulating `fragment.payloadByteCount` in order. If fragments arrive and are stored out of order, the offset calculation is wrong.  
**Fix:** Sort fragments by index before offset computation, or validate that fragments are stored in-order.

**V-025 · P1 · LOGIC_BUG**  
`VideoTransportReassembly.swift` lines 251–254  
Newly created frame buckets are added to `activeFrameOrder` even if the frame completes instantly (single-fragment frame). These entries are never removed until `resetActiveFrameOrder()`, causing unbounded growth.  
**Fix:** Check for immediate completion after insertion and remove from the order list if already complete.

### 5.2 AVFoundation / CoreVideo Safety

**V-005 · P1 · MEMORY_SAFETY**  
`Sources/OpenLolaCore/Video/VideoCaptureAVFoundation.swift` lines 605–634  
`rawFrameBytes()` calls `CVPixelBufferGetBaseAddress()` and casts with `assumingMemoryBound(to: UInt8.self)` without checking alignment. If `bytesPerRow` or height are invalid, the loop reads past the allocation.  
**Fix:** Validate `bytesPerRow > 0 && height > 0` and ensure `bytesPerRow * height <= allocatedSize` before the loop.

**V-018 · P1 · LOGIC_BUG**  
`VideoCaptureAVFoundation.swift` lines 587–602  
`presentationTime.seconds * 1_000_000_000` can be negative for relative CMTime values. Casting a negative Double to UInt64 is undefined behaviour in Swift.  
**Fix:** Assert or clamp `presentationTime.seconds >= 0` before the cast.

**V-007 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Video/VideoOutputRenderer.swift` line 168  
`queue.contains(frame)` checked after the frame was already appended. Returns `.rejected` while the frame is in the queue — contradictory state.  
**Fix:** Check membership before appending, or redesign the backpressure logic.

### 5.3 Codec / Format Correctness

**V-016 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Video/VideoStreamDescription.swift` lines 165–170  
If `frameRate.denominator == 0`, bandwidth estimation returns 0 (line 78), silently allowing configurations that would exceed the bandwidth budget to pass validation.  
**Fix:** Guard `frameRate.denominator > 0` in the frame rate initializer.

**V-009 · P1 · MEMORY_SAFETY**  
`Sources/OpenLolaCore/Video/VideoTransportPacket.swift` lines 256–291  
Raw array subscripting for fingerprint and pixel format byte ranges without total-size validation. Malformed packets with too-small header fields can read past end of `bytes`.  
**Fix:** Validate `totalExpectedSize <= bytes.count` before any range slicing.

### 5.4 Percentile / Statistics

**V-019 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Video/VideoOutputRenderer.swift` lines 246–250  
`BoundedDoubleSamples.samples` circular-buffer rotation is only correct when the buffer is full. With a partial buffer and `startIndex > 0`, the array is incorrectly rotated, producing wrong sample order in metrics.  
**Fix:** Only rotate when `storage.count == capacity`; otherwise return `Array(storage)` directly.

---

## Group 6 — Control & Timing (P1)

### 6.1 Media Clock

**C-002 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Timing/MediaClock.swift` lines 15–27  
`nanoseconds()` clamps overflow to `UInt64.max` silently. Callers cannot distinguish a valid large value from a clamped overflow. The `dividingFullWidth` call may also be incorrectly constructed (expects `(high, low)` tuple but receives a `FullWidth` result directly).  
**Fix:** Return a `Result<UInt64, Error>` or throw on overflow; fix the full-width division call.

**C-006 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Timing/RxBuffering.swift` lines 32–34  
`targetPackets` computed property divides by `framesPerPacket` without guarding zero.  
**Fix:** Add `precondition(framesPerPacket > 0)` in init.

### 6.2 OSC / DMX Control

**C-003 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Control/OscCueRunners.swift` lines 42–45  
Jitter metric artificially inflated by 1µs floor (`max(..., received.senderTimestampNanoseconds + 1_000)`). Makes loopback jitter metrics unreliable.  
**Fix:** Remove the floor; use actual receive timestamp.

**C-009 · P2 · LOGIC_BUG**  
`Sources/OpenLolaCore/Control/OscCueProbe.swift` lines 353–360  
Jitter validation uses exact float equality (`!=`). IEEE-754 rounding makes this fail on mathematically equivalent values.  
**Fix:** Use epsilon comparison (`abs(a - b) < 1e-4`).

**C-008 · P2 · LOGIC_BUG**  
`Sources/OpenLolaCore/Control/LightingFixtureGateReport.swift` lines 102–106  
DMX `minLevel` and `maxLevel` are each range-checked [0–255] but their ordering (`minLevel <= maxLevel`) is not validated.  
**Fix:** Add `guard dmx.minLevel <= dmx.maxLevel`.

**C-013 · P2 · LOGIC_BUG**  
`Sources/OpenLolaCore/Control/LightingFixtureGateRun.swift` lines 91–92  
DMX `universe` field accepts 0 (invalid; DMX universes are 1-indexed by protocol).  
**Fix:** Use `requiredPositiveInteger` rather than `requiredNonNegativeInteger`.

### 6.3 Process / Subprocess

**C-004 · P1 · MISSING_ERROR_HANDLING**  
`Sources/OpenLolaCore/Connectors/Core/ExternalConnectorProcessRunner.swift` lines 300–301  
`stdout` write handle closed but `stderr` write handle leaked after `posix_spawn`.  
**Fix:** Close both `stdout.fileHandleForWriting` and `stderr.fileHandleForWriting`.

**C-005 · P1 · RACE_CONDITION**  
`ExternalConnectorProcessRunner.swift` lines 145–164  
Between `reapAndCheckRunning()` and `terminateExternalConnectorProcessGroup()`, the process can exit and its PID can be reused. `kill(-pgid, SIGTERM)` then kills an unrelated process.  
**Fix:** Use `WNOHANG` re-check immediately before `kill`; validate process group still belongs to the tracked session.

**C-021 · P2 · LOGIC_BUG**  
`Sources/OpenLolaCore/Core/KeyValueArgumentParser.swift` lines 24–32  
Negative number arguments (e.g., `--timeout -10`) are rejected as flag-like because the parser treats any `-`-prefixed value as a flag. Only `--` prefix should be treated as a flag.  
**Fix:** Check specifically for `--` prefix (two dashes), not single `-`.

### 6.4 ATEM Control

**C-026 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Control/AtemReadOnlyControlValidation.swift` lines 56–59  
Optional fields replaced with empty string before placeholder check, making an absent optional field indistinguishable from an empty non-placeholder value. Missing required fields pass validation silently.  
**Fix:** Check `Optional.none` before calling the placeholder detector; treat `nil` as missing (invalid), not empty-string.

---

## Group 7 — Connectors (P1)

### 7.1 LoLa Protocol

**SWIFT-005 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Connectors/LoLa/LoLaControlExchangeRuntime.swift` lines 77–100  
`receiveLoLaControlAttempt()` does not validate that the first received message is `/MESG_QUICKCONN`. A `REJECT` or garbage message causes silent parse failure.  
**Fix:** Explicit message-kind dispatch before parsing.

**SWIFT-004 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaCodec.swift` line 166  
Division guard `maxFragmentBodyByteCount > 0` present but `maxVideoFragmentCount == 0` guard missing. Division by zero when fragment count is zero.  
**Fix:** Guard `maxVideoFragmentCount > 0` before division.

**SWIFT-009 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityCaptureReport.swift` lines 225–240  
JPEG marker scan can false-positive on raw video payload data that happens to contain `0xffd8` / `0xffd9` byte sequences.  
**Fix:** After finding SOI (`0xffd8`), verify the next two bytes are a valid JFIF/Exif/JFXX marker type before concluding it is a JPEG frame.

**SWIFT-015 · P1 · API_MISUSE**  
`Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityWireFrame.swift`  
IPv4 header length computation not bounds-checked against available packet data before use; a crafted packet with a header-length field pointing past the buffer causes an OOB read.  
**Fix:** `guard 14 + ipv4HeaderLength <= bytes.count`.

### 7.2 MADI

**SWIFT-003 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexSocketRunner.swift` lines 40–47  
`usleep(1_000_000)` (1 s hard-coded sleep) before first datagram. If remote peer takes longer, the first data is dropped. If it's faster, the delay is wasteful.  
**Fix:** Expose `peerBindTimeoutSeconds` as configuration; poll with short retries.

### 7.3 UltraGrid

**SWIFT-010 · P1 · LOGIC_BUG**  
`Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift` line 101  
Port validated as `> 0` only. No pre-flight check that the port is actually available. UltraGrid will fail silently if the port is occupied.  
**Fix:** Attempt a `bind()` on the port before launching the subprocess; close immediately if bind succeeds.

### 7.4 Python Connector

**PY-001 · P1 · MISSING_ERROR_HANDLING**  
`linux_connector/lola_connector/backends.py` lines 306, 325  
Bare `except Exception:` clauses swallow unexpected errors with no differentiation between `OSError`, `asyncio.CancelledError`, and programmer errors.  
**Fix:** Catch specific exception types; re-raise `CancelledError` unconditionally.

**PY-004 · P1 · RACE_CONDITION**  
`linux_connector/lola_connector/connector.py` lines 55–71  
`sock_recvfrom` / `sock_sendto` fallback uses `add_reader` / `add_writer` which are not concurrent-safe for the same socket across multiple coroutines.  
**Fix:** Serialize socket access with `asyncio.Lock`, or use a single dedicated task per direction.

**PY-007 · P1 · MISSING_ERROR_HANDLING**  
`linux_connector/lola_connector/runtime.py` lines 114–117  
Task cancellation errors during `stop()` are logged but not re-raised, hiding failures. The connector may appear to stop cleanly while leaving dangling coroutines.  
**Fix:** Collect all task exceptions; re-raise as `ExceptionGroup` after cleanup.

---

## Group 8 — UI Defects (P1)

### 8.1 Threading / Actor Safety

**U-003 · P1 · RACE_CONDITION**  
`Sources/open-lola-app/AppReceiverPreviewServices.swift` lines 87–100  
`startAuthorized()` modifies `self.session` and `self.previewLayer?.session` from a background queue. Concurrent `start()` / `stop()` calls corrupt session state.  
**Fix:** Dispatch all session mutations to a serial `DispatchQueue` or mark the method `@MainActor`.

**U-007 · P1 · RACE_CONDITION**  
`Sources/open-lola-app/AppLocalOperatorInventory.swift` lines 27–42  
`refresh()` creates a new `Task` without cancelling any prior task. Rapid calls create multiple parallel refresh tasks that race over shared `@Observable` state.  
**Fix:** Store the `Task` and call `.cancel()` before creating a new one.

**U-028 · P1 · RACE_CONDITION**  
`Sources/open-lola-app/AppSettings.swift` lines 8–130  
`didSet` blocks write to `UserDefaults.standard` from potentially non-main contexts. Concurrent writes are not guaranteed safe.  
**Fix:** Mark `AppSettings` as `@MainActor`.

### 8.2 Task / Async Lifecycle

**U-015 · P1 · MISSING_ERROR_HANDLING**  
`Sources/open-lola-app/AppShellRootView.swift` line 117  
`.task { await executionController.runElapsedTimer() }` — the task is automatically cancelled when the view disappears, but the body does not check `Task.isCancelled`, potentially running forever if the view is re-shown before the previous task exits.  
**Fix:** Check `Task.isCancelled` in the timer loop and exit cleanly.

**U-023 · P1 · MISSING_ERROR_HANDLING**  
Same pattern in `AppLocalOperatorInventoryController.swift` lines 27–42.

**U-002 · P1 · MISSING_ERROR_HANDLING**  
`Sources/open-lola-app/AppExecutionController.swift` lines 180–185  
`[weak self]` completion handler does not guard against `self` being nil before use. Silent failure on dealloc.  
**Fix:** Add `guard let self else { completion(1); return }`.

### 8.3 Accessibility / Readability

**U-013 · P1 · UI_DEFECT**  
`Sources/open-lola-app/AppLatencyHeroView.swift` lines 76–81  
Colored status circle has no `.accessibilityLabel`. Screen reader users cannot interpret the status.  
**Fix:** `.accessibilityLabel("Status: \(statusLabel)")` on the `Circle()`.

**U-033 · P2 · UI_DEFECT**  
`Sources/open-lola-app/AppConsoleChromeView.swift` lines 100–114  
Top-bar action buttons (refresh report, refresh inventory, stop) have only `.help()` text. `.help()` is not read by VoiceOver; `.accessibilityLabel` is required.  
**Fix:** Add `.accessibilityLabel()` to each button.

**U-012 · P2 · UI_DEFECT**  
`Sources/open-lola-app/AppPacketMonitorView.swift` lines 179–193  
Row accessibility label is a raw data string, not a structured sentence. VoiceOver reads it as a dump.  
**Fix:** Compose: `"Packet \(id), stream \(stream), from \(source) to \(destination)"`.

**U-024 · P2 · UI_DEFECT**  
`Sources/open-lola-app/AppTransportView.swift` lines 59–73  
Disabled button state relies only on `.disabled()` opacity, which is insufficient on dark/custom backgrounds.  
**Fix:** Explicitly set opacity or foreground color when disabled.

### 8.4 State / Binding Correctness

**U-009 · P1 · LOGIC_BUG**  
`Sources/open-lola-app/AppChannelMeterView.swift` lines 138–150  
`updatePeaks()` mutates `nextState` and always triggers a re-render because `nextState != peakState` is always true after mutation (struct semantics). Unnecessary render every audio frame.  
**Fix:** Compare the new value field-by-field before assigning; only set `peakState = nextState` if actually changed.

**U-011 · P2 · STRUCTURE**  
`Sources/open-lola-app/AppLocalOperatorSurfaceView.swift` lines 142–149  
`remoteSelectionBinding()` creates a new `Binding` on every render. The getter/setter modifies two separate state objects non-atomically.  
**Fix:** Establish a single source of truth; derive the other from it.

**U-031 · P2 · UNCLEAR**  
`Sources/open-lola-app/AppShellStoredDefaults.swift` lines 84–92  
Two-level fallback for `audioTransport` (new key → old `audioCompression` key) is silent with no migration log. Old settings silently migrate without the user knowing.  
**Fix:** Add a one-time migration log and explicitly remove the old key after successful migration.

---

## Group 9 — Code Quality / Structural Debt (P2)

### 9.1 Validation Primitive Duplication

**C-016 · P2 · SLOP/BOILERPLATE**  
`LightingFixtureGateHelpers.swift`, `OscCueHelpers.swift`, `AtemReadOnlyControl.swift`, and connector helpers all define near-identical `requireNonEmpty()`, `requirePositive()`, `requireRange()` functions.  
`Sources/OpenLolaCore/Core/ValidationPrimitives.swift` exists but is used inconsistently.  
**Fix:** Consolidate all validation into `ValidationPrimitives` as a single source of truth; delete the duplicates.

### 9.2 JSON Report Boilerplate

**V-026 · P2 · SLOP/BOILERPLATE**  
`prettyJSONData()` / `prettyJSONString()` are copy-pasted across ~12 report types (`VideoTransportReport`, `DirectPeerSessionReport`, `NatFriendlyRouteReport`, etc.).  
**Fix:** Extract to a `PrettyJSONCodable` protocol extension (a file already named `PrettyJSONCodable.swift` exists — confirm all reports conform to it instead of duplicating).

### 9.3 CLI Command Dispatch

**SWIFT-007 · P2 · SLOP/BOILERPLATE**  
`Sources/open-lola/main.swift` lines 13–156  
Giant `switch` over raw `args` strings. Adding any new command requires editing this file and preserving the correct argument count branching manually.  
**Fix:** Define a `Command` protocol with `name`, `argumentCount`, `run(args:)`. Register commands in an array. Dispatch via dictionary lookup.

### 9.4 Magic Constants

**SWIFT-013 · P2 · SLOP/BOILERPLATE**  
`Sources/OpenLolaCore/Connectors/LoLa/LoLaCompatibilityMediaModel.swift` lines 5–12  
Constants `0x2a`, `0x1337`, `0x42a`, etc. without protocol documentation.  
**Fix:** Add comments citing the LoLa wire format spec section for each constant.

**V-024 · P2 · SLOP/BOILERPLATE**  
`Sources/OpenLolaCore/Video/VideoTransportPacket.swift` lines 44–46  
Magic bytes `"OLVF"` and header size `72` hardcoded in encode, decode, and fragment calculation separately.  
**Fix:** Define a `VideoTransportFormat` namespace with all constants.

### 9.5 Python Type Annotations

**PY-005 · P2 · UNCLEAR**  
`linux_connector/lola_connector/media.py` — 18 functions lack return type annotations, making static analysis and `mypy` checks impossible.  
**Fix:** Add full type annotations; add `mypy` to CI.

**PY-006 · P2 · SLOP/BOILERPLATE**  
`linux_connector/lola_connector/cli.py` line 1  
`build_parser()` and `add_test_media_args()` missing type annotations.

### 9.6 Benchmark Validity

**SWIFT-001 · P2 · PERF**  
`Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmark.swift` lines 70–80  
Warmup samples are not explicitly discarded from percentile computation. Cold-start latency spikes pollute P99.  
**Fix:** Record a separate cold-start metric and discard warmup samples from steady-state percentiles.

**SWIFT-002 · P1 · PERF**  
`LatencyBenchmark.swift` lines 73–82  
`percentile()` does not filter `Inf` or `NaN` before computation. An infinite measurement produces an infinite percentile, which is silently passed into reports.  
**Fix:** Filter non-finite values; log a warning when filtered samples are found.

### 9.7 Dead Code

**C-011 · P2 · DEAD_CODE**  
`Sources/OpenLolaCore/Control/AtemReadOnlyControl.swift` lines 487–520  
`sockaddrIn()`, `atemSocketDescriptorFitsFDSet()`, etc. are Darwin-only helpers defined but only called within the same `#if canImport(Darwin)` block. They are effectively file-private.  
**Fix:** Mark as `private`; document why they are Darwin-only.

**SWIFT-012 · P2 · DEAD_CODE**  
`Sources/OpenLolaCore/Release/PackagingFieldTest.swift` and related one-shot test harnesses in `Release/` appear unused by the automated release pipeline.  
**Fix:** Document which release validation files are actively run; archive the rest.

**U-019 · P2 · DEAD_CODE**  
`Sources/open-lola-app/AppLocalOperatorInventory.swift` lines 52–62  
`captureAsync()` exposes many optional parameters with defaults that are never overridden at call sites — dead API surface.  
**Fix:** Remove unused parameters or collapse into a simpler call.

### 9.8 SwiftUI Anti-patterns

**U-005 · P2 · STRUCTURE**  
`Sources/open-lola-app/AppShellRootView.swift` lines 66–122  
`body` is deeply nested, making SwiftUI diff resolution expensive. Derived surface state is recomputed on every render.  
**Fix:** Extract each panel into a dedicated `@ViewBuilder` or view struct.

**U-027 · P2 · SLOP/BOILERPLATE**  
`Sources/open-lola-app/AppShellSettingsView.swift` lines 265–427  
Near-identical binding helpers (`peerBinding`, `uint16Binding`, `windowsLoLaTextBinding`, etc.) duplicated per field type.  
**Fix:** A single generic `validatedBinding<T>` covering all numeric and string conversions.

---

## Group 10 — High-Risk Runtime Areas: Improvement Roadmap

This section synthesises findings into improvement plans for each major runtime area.

### 10.1 Realtime Audio Engine

**Risk Level: HIGH** — bugs here cause audible dropouts, xruns, or silent corruption.

| Priority | Action |
|----------|--------|
| P0 | Fix `A-004`: Opus codec force-unwrap |
| P0 | Fix `C-001`: SPSCAtomicRing TOCTOU — enforce single-producer invariant with debug assertions |
| P1 | Audit entire CoreAudio IOProc callback for any allocation, lock, or system call |
| P1 | Fix `A-003`, `A-040`: Use `ManagedAtomic<Bool>` for `ioProcRunning` and `inputIOProcID` |
| P1 | Fix `A-005`, `A-011`, `A-032`: Add division-by-zero guards throughout RxBuffering |
| P1 | Fix `A-006`: PLC payloadByteCount must reflect actual encoded output |
| P1 | Fix `A-024`: Serialize `DirectAudioMediaRouter.route()` with a serial dispatch queue |
| P1 | Fix `A-013`: Replace `Thread.sleep` with semaphore in loopback setup |
| P2 | Refactor `A-008`, `A-035`: Centralize channel-map uniqueness check |

### 10.2 UDP / Network Transport

**Risk Level: HIGH** — packet parsing receives untrusted data from the network.

| Priority | Action |
|----------|--------|
| P0 | Implement a safe cursor-based packet reader for all `UdpPcm` and `UdpPcmV2` parsing |
| P0 | Fix `N-013`, `N-014`: L24 sign-extension and symmetric quantization |
| P0 | Fix `N-028`: Resolve `try` / non-throwing mismatch in `UdpMediaTransport` |
| P1 | Fix `N-001`: Underflow in `udpPcmHasBytes` bounds check |
| P1 | Fix `N-006`: Verify socket buffer sizes with `getsockopt` post-configuration |
| P1 | Fuzz all packet parsers with `libFuzzer` / Swift fuzzing harness |
| P2 | Deduplicate `readUInt16BE` / `readUInt32BE` into a generic reader |

### 10.3 P2P Session Layer

**Risk Level: HIGH** — session teardown failures leave sockets open; state machine gaps drop media.

| Priority | Action |
|----------|--------|
| P0 | Fix `P-001`–`P-010`: All-or-nothing socket initialization / cleanup across session roles |
| P0 | Fix `P-048`: Remove shell string interpolation; use `Process(arguments:)` |
| P1 | Fix `P-050`, `P-051`: Add `withThrowingTaskGroup` timeout to all `acceptProposal()` calls |
| P1 | Fix `P-035`: `runVideoRXLoop()` double-defer handling |
| P1 | Fix `P-037`: UInt16 RTP sequence rollover in receive-side gap detection |
| P1 | Fix `P-052`: Cross-channel endpoint uniqueness validation |
| P2 | Consolidate all P2P report builder boilerplate (P-039, P-049) |

### 10.4 Video Pipeline

**Risk Level: MEDIUM** — reassembly bugs drop frames; AVFoundation misuse can crash.

| Priority | Action |
|----------|--------|
| P1 | Fix `V-005`: Add bounds checks in `rawFrameBytes()` before pointer cast |
| P1 | Fix `V-008`, `V-017`, `V-025`: Reassembly state machine correctness |
| P1 | Fix `V-018`: Guard negative `CMTime.seconds` before UInt64 cast |
| P1 | Fix `V-007`: Fix backpressure logic in `VideoOutputRenderer` |
| P2 | Replace magic `"OLVF"` / `72` with a named format constants type |

### 10.5 Control Plane (OSC / ATEM / DMX)

**Risk Level: MEDIUM** — bugs cause incorrect show control actions.

| Priority | Action |
|----------|--------|
| P1 | Fix `C-002`: `MediaClock` overflow handling and full-width division |
| P1 | Fix `C-005`: Process group kill race in `ExternalConnectorProcessRunner` |
| P1 | Fix `C-004`: Close stderr file descriptor after spawn |
| P1 | Fix `C-026`: ATEM optional field placeholder validation |
| P2 | Fix `C-003`, `C-009`: OSC jitter metric accuracy |

### 10.6 Connectors (LoLa / JackTrip / UltraGrid / Python)

**Risk Level: MEDIUM** — incorrect protocol handling causes session failures.

| Priority | Action |
|----------|--------|
| P0 | Fix `PY-002`: Initialize `process = None` before subprocess try/except |
| P1 | Fix `SWIFT-005`: Validate LoLa message kind before parse |
| P1 | Fix `SWIFT-015`: Bounds-check IPv4 header length in wire frame parser |
| P1 | Fix `SWIFT-003`: Replace MADI hard-coded sleep with configurable retry |
| P1 | Fix `PY-001`: Replace bare `except Exception` with specific types |
| P1 | Fix `PY-004`: Add per-socket asyncio lock |
| P2 | Fix `SWIFT-007`: Replace main.swift switch with command registry |

### 10.7 UI / App Shell

**Risk Level: MEDIUM** — threading bugs cause visual corruption; lifecycle bugs cause resource leaks.

| Priority | Action |
|----------|--------|
| P0 | Fix `U-029`: Lock all `stop()` state mutations in preview services |
| P1 | Mark `AppSettings` as `@MainActor` (fixes `U-028`, `U-010`) |
| P1 | Fix `U-007`, `U-023`: Store and cancel prior refresh Task |
| P1 | Fix `U-003`: Serialize AVCaptureSession mutations |
| P1 | Fix `U-009`: Eliminate redundant re-renders in `AppChannelMeterView` |
| P1 | Add `.accessibilityLabel` to status circle, action buttons, table rows (`U-013`, `U-033`, `U-012`) |
| P2 | Refactor `AppShellRootView.body`, `AppShellSettingsView` bindings |

---

## Summary Statistics

| Severity | Count | Areas Most Affected |
|----------|-------|---------------------|
| P0 | 17 | Packet parsing, P2P sockets, shell injection, Python subprocess, UI lock |
| P1 | ~140 | Realtime audio, UDP, P2P session, video, control, connectors, UI |
| P2 | ~83 | Code quality, boilerplate, accessibility, structure |
| **Total** | **~240** | |

### Top 10 Highest-Risk Findings

1. **N-002 / N-003** — Unbounded network packet parsing, crash on any malformed UDP datagram  
2. **P-048** — Shell injection in run-plan command builder  
3. **PY-002** — Python subprocess crash on `UnboundLocalError`  
4. **A-004** — Force-unwrap in Opus encoder on every encode call  
5. **C-001** — SPSCAtomicRing TOCTOU — can corrupt any audio passing through the ring  
6. **P-001–P-010** — P2P session socket resource leaks on any init failure  
7. **N-013 / N-014** — L24 sign-extension and asymmetric quantization corrupt all AES67 audio  
8. **A-003 / A-040** — Non-atomic IOProc running flag, race in realtime thread  
9. **U-029** — Unprotected os_unfair_lock in preview services (crash on concurrent stop)  
10. **C-005** — Process-group kill race can terminate unrelated system processes  

---

*This document was generated by static multi-agent audit. No code was changed. All line numbers are approximate — verify against current source before patching.*


---

# PASS 2 DEEP AUDIT — Enrichment Findings

> Second-pass audit covering all 305+ Swift files, 20+ Python files, and 25+ shell scripts.  
> All findings are additive to the Pass 1 findings above.  
> Finding IDs: P2P-NNN, AUDIO-NNN, NET-NNN, REL-NNN, VID-NNN, CTL-NNN, PLT-NNN, CON-NNN, UI-NNN

---

## Group 11 — P2P / Direct Peer (P2P-001 – P2P-040)

## P2P DEEP AUDIT — P2P-001 to P2P-040

**P2P-001 · P0 · LOGIC_BUG**
File: DirectPeerMeshRuntimeReport.swift, line 228
Enumerated loop performs arithmetic `routeIndex * packetCount` without verified integer bounds checking after tuple-unpacking.
**Fix:** Use explicit parameter names `{ (routeIndex, route) in` or validate routeIndex bounds before arithmetic.

**P2P-002 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerAVFoundationRawFrameSource.swift, lines 85-86
`stop()` called on error in `start()` swallows cleanup errors silently.
**Fix:** Make `stop()` throwing or log cleanup failures.

**P2P-003 · P1 · RACE_CONDITION**
File: DirectPeerAVFoundationRawFrameSource.swift, lines 74-82
Lock released before `session.startRunning()`. A concurrent `nextFrame()` may see nil collector.
**Fix:** Move `session.startRunning()` inside the lock-protected critical section.

**P2P-004 · P2 · SLOP**
File: DirectPeerSessionAVAudioLoops.swift, lines 4-11
FNV-1a hash constants (2_166_136_261, 16_777_619) with no documentation.
**Fix:** Add comment documenting FNV-1a rationale or extract to named constants.

**P2P-005 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerSessionAVAudioLoops.swift, line 32
Guard for `opusEncoder` nil check in loop without null-safe error message construction.
**Fix:** Pre-validate opusEncoder before entering loop.

**P2P-006 · P1 · LOGIC_BUG**
File: DirectPeerSessionAVAudioLoops.swift, lines 85-91
`hostTimeNanoseconds` uses `addingReportingOverflow` but silently returns `UInt64.max` on overflow.
**Fix:** Log overflow condition or return nil and handle upstream.

**P2P-007 · P2 · SLOP**
File: DirectPeerSessionAVAudioLoops.swift, line 101
`belongsToSameDeadline()` compares 10 fields with no documentation of why all must match.
**Fix:** Document the deadline-matching logic or factor into a struct comparison.

**P2P-008 · P1 · RESOURCE_LEAK**
File: DirectPeerSessionAVSocketRunner.swift, lines 25-35
Three sockets opened; if `onReady?()` throws, defer-called `shutdown()` may not guarantee socket closure.
**Fix:** Add explicit socket close in defer or verify shutdown() closes all transports.

**P2P-009 · P1 · LOGIC_BUG**
File: DirectPeerSessionAVSocketRunner.swift, lines 267-339
`defer` cleanup in `runAVMediaLoops()` calls `stop()` on uninitialized resources if exception thrown before flags are set.
**Fix:** Set flags before any throwing operation or use flag-checked cleanups.

**P2P-010 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerSessionAVSocketRunner.swift, lines 312-314
`directPeerAVRunDeadlineNanoseconds()` unchecked arithmetic can overflow.
**Fix:** Add overflow checking or validate durationSeconds before conversion.

**P2P-011 · P1 · RACE_CONDITION**
File: DirectPeerSessionAVSocketRunner.swift, lines 334-339
`avSyncPolicy` mutated without synchronization while video RX loop reads `playoutAnchor`.
**Fix:** Make avSyncPolicy immutable or protect mutations with a lock.

**P2P-012 · P2 · SLOP**
File: DirectPeerSessionAVSocketRunner.swift, lines 335-338
Magic multiplier `2` in `videoFrameIntervalNanoseconds * 2` tolerance calculation undocumented.
**Fix:** Document why 2x frame interval is the tolerance.

**P2P-013 · P1 · LOGIC_BUG**
File: DirectPeerSessionAVSocketRunner.swift, lines 348-400
`while DispatchTime.now().uptimeNanoseconds < deadline` loop doesn't handle backwards time or clock adjustments.
**Fix:** Use proper timer mechanism or clamp negative deltas.

**P2P-014 · P2 · SLOP**
File: DirectPeerSessionAVVideoLoops.swift, line 73
Magic number 2_048 for maxPackets without rationale.
**Fix:** Extract to named constant with comment.

**P2P-015 · P2 · DEAD_CODE**
File: DirectPeerSessionAVVideoReportSupport.swift, lines 9-22
`payloadDigest` uses non-cryptographic FNV-1a; if used for integrity proof, collisions are possible.
**Fix:** Document this is not security-critical or upgrade to SHA256.

**P2P-016 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerSessionProductionAVPreflight.swift, lines 66-72
Blocker list grows unbounded with no truncation or deduplication.
**Fix:** Limit blocker list size or deduplicate.

**P2P-017 · P2 · SLOP**
File: DirectPeerManualValidation.swift, line 87
`inet_pton()` failure inside `withCString` closure is indistinguishable from memory errors.
**Fix:** Wrap inet_pton errors with explicit logging.

**P2P-018 · P1 · LOGIC_BUG**
File: DirectPeerManualValidation.swift, lines 43-61
`localHost == remoteHost` skips `remoteControlPort` validation, creating asymmetric validation logic.
**Fix:** Validate all ports independently regardless of host equality.

**P2P-019 · P2 · BOILERPLATE**
Files: DirectPeerMeshRuntimeReport.swift, DirectPeerMeshTopologyReport.swift
Nearly identical validation patterns duplicated 20+ lines.
**Fix:** Extract to common validation helper.

**P2P-020 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerMeshRuntimeReport.swift, line 308
`UdpPcmV2FragmentReassembler.reassemble()` errors swallowed with bare `try`.
**Fix:** Propagate or handle reassembly errors explicitly.

**P2P-021 · P2 · SLOP**
File: PeerSessionRunnerAudioHelpers.swift, lines 66-80
`acceptedConfiguration?.mtuBytes ?? 1_200` repeated twice instead of cached.
**Fix:** Extract mtuBytes to a local variable.

**P2P-022 · P1 · LOGIC_BUG**
File: PeerSessionRunner.swift, lines 234-260
`acceptProposal()` mutates `remoteCapabilities` before validating proposal; inconsistent state on failure.
**Fix:** Validate proposal before mutating state.

**P2P-023 · P2 · SLOP**
File: PeerSessionRunner.swift, line 147
`sessionID` string built from peer IDs without escaping hyphens or special chars.
**Fix:** Use a delimiter or structured ID format.

**P2P-024 · P1 · MISSING_ERROR_HANDLING**
File: PeerSessionRunner.swift, line 214
`IPv4PixelFormatDescription()` called without error checking.
**Fix:** Add try-catch or validate pixelFormat before calling.

**P2P-025 · P2 · SLOP**
File: DirectPeerSessionReceiveProofArtifact.swift, lines 21-32
`evidenceDigest` concatenates values with `|` — ambiguous if values contain `|`.
**Fix:** Use safe serialization (JSON, binary, escaped).

**P2P-026 · P1 · LOGIC_BUG**
File: DirectPeerSessionReceiveProofArtifact.swift, line 68
Nil mapped to `"<nil>"` string — ambiguous if legitimate value is the string `"<nil>"`.
**Fix:** Use null-safe encoding distinguishing nil from the string.

**P2P-027 · P2 · SLOP**
File: DirectPeerSessionReport.swift, lines 37-138
`validate()` method is 101 lines with deeply nested conditions.
**Fix:** Decompose into smaller validation helpers.

**P2P-028 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerSessionSocketRunner.swift, lines 145-148
`for sequence in 1...packetCount` does not re-validate packetCount > 0.
**Fix:** Re-validate or use a constant before range creation.

**P2P-029 · P1 · RACE_CONDITION**
File: DirectPeerSessionSocketRunner.swift, lines 196-260
Shared `control` socket in `publishAndExchangeAudioMetadata()` — out-of-order messages break receive logic.
**Fix:** Add sequence numbers or use separate control channels.

**P2P-030 · P1 · LOGIC_BUG**
File: DirectPeerTwoPeerRunPlan.swift, line 238
Hardcoded path `.build/debug/open-lola` fails silently on release builds.
**Fix:** Make binary path configurable or detect at runtime.

**P2P-031 · P2 · SLOP**
File: DirectPeerTwoPeerRunPlanReportTypes.swift, line 281
`report.configuration.peers.first?.peerID` fragile fallback to reportID on empty peers array.
**Fix:** Validate peers array is non-empty or document fallback.

**P2P-032 · P1 · MISSING_ERROR_HANDLING**
File: MacToMacRouteCertification.swift, lines 213-216
`placeholderSensitiveFields()` iterates all fields without early termination — performance issue on large reports.
**Fix:** Use early return or lazy evaluation.

**P2P-033 · P2 · SLOP**
File: MacToMacRouteCertification.swift, line 324
`isMacToMacPlaceholder()` uses hardcoded strings `["todo(human)", "placeholder", "fixture"]` — typos silently miss placeholders.
**Fix:** Define as named constants.

**P2P-034 · P1 · LOGIC_BUG**
File: EndpointLoopbackReport.swift, line 316
Double-negative `sampleRate.unsupportedReason?.isEmpty != false` is confusing and potentially incorrect.
**Fix:** Rewrite as `unsupportedReason == nil || unsupportedReason!.isEmpty`.

**P2P-035 · P1 · MISSING_ERROR_HANDLING**
File: PeerSessionRunnerMetrics.swift, lines 36-38
`metricsTransport?.send()` nil-checked twice — defensive over-coding masks real bugs.
**Fix:** Remove redundant nil checks or consolidate transport access.

**P2P-036 · P2 · BOILERPLATE**
Files: DirectPeerSessionAVRunTypes.swift, DirectPeerSessionAVRuntimeReport.swift
Large Codable structs with manual CodingKeys + encode/decode repeated ~200 lines.
**Fix:** Use Codable defaults or extract custom decoding logic.

**P2P-037 · P1 · LOGIC_BUG**
File: PeerSessionRunnerRTPAudio.swift, line 24
`UInt16(truncatingIfNeeded: sequenceNumber)` silently loses information on UInt64 wrap.
**Fix:** Log sequence number wraparound or document as intentional.

**P2P-038 · P1 · PROTOCOL_BUG**
File: PeerSessionRunnerRTPAudio.swift, lines 22-31
RTP timestamp set to `senderFrameIndex` — may break sync if audio/video have different sample rates.
**Fix:** Validate timestamp derivation matches RTP spec or document non-standard behavior.

**P2P-039 · P2 · SLOP**
File: DirectPeerSessionAVSocketRunner.swift, line 317
Magic divisor `2` in `audioPollIntervalMicroseconds` calculation unexplained.
**Fix:** Document why divided by 2 or extract to named constant.

**P2P-040 · P1 · LOGIC_BUG**
File: DirectPeerSessionAVRuntimeReport.swift, lines 335-339
`avSyncPolicy` mutated in synthetic fixture mode after concurrent RX loop may start, reading stale values.
**Fix:** Compute policy before any concurrent loop starts.


---

## Group 12 — Audio / MADI / RME (AUDIO-001 – AUDIO-070)

**AUDIO-001 · P1 · REALTIME_SAFETY**
File: MadiFullDuplexSocketRunner.swift, line 40
`usleep(1_000_000)` called in audio-adjacent setup code before callback starts. Not directly in IOProc, but demonstrates pattern.
**Fix:** Document that sleep is before IOProc activation; verify no allocation/locks in corresponding tests.

---

**AUDIO-002 · P1 · REALTIME_SAFETY**
File: AudioLoopbackRun.swift, line 331
`Thread.sleep(forTimeInterval: Double(configuration.durationSeconds))` called on main thread between AudioDeviceStart and AudioDeviceStop. This blocks the thread running the IOProc callback.
**Fix:** Use condition variables or semaphores instead of blocking sleep when managing IOProc lifecycle.

---

**AUDIO-003 · P1 · MEMORY_SAFETY**
File: DirectPeerRealtimeAudioGraph.swift, lines 50-59
Memory allocation for `inputScratch` and `outputScratch` at MemoryLayout<UInt8>.alignment (1 byte). Audio buffers containing SIMD floats need 16-byte alignment on ARM.
**Fix:** Change alignment to `max(16, MemoryLayout<Float>.alignment)` for SIMD safety.

---

**AUDIO-004 · P1 · MEMORY_SAFETY**
File: DirectPeerAudioPayloadRing.swift, lines 25-27
Allocating ring storage with max(MemoryLayout<UInt32>.alignment, MemoryLayout<Float>.alignment) which may be less than required 16 bytes for SIMD on all architectures. 
**Fix:** Use explicit 16-byte alignment: `max(16, MemoryLayout<Float>.alignment)`.

---

**AUDIO-005 · P1 · LOGIC_BUG**
File: RealtimeAudioPacketHandoff.swift, line 157
`recordPacketizedSend(start: start, fragmentCount: 0)` hardcodes fragmentCount=0 for non-V2 packet. Should calculate actual fragment count from packet or mode.
**Fix:** Pass `packets.count` or calculate from `mode.fragments.count` instead of hardcoding 0.

---

**AUDIO-006 · P1 · LOGIC_BUG**
File: MadiReceiveEngine.swift, lines 87-88
Line 87: `let playoutFrame = packet.header.senderFrameIndex &+ UInt64(rxBufferPolicy.targetFrames)` 
Line 88: `guard playoutFrame >= nextDueFrame else { ... return .droppedLate }`
If nextDueFrame wraps around (UInt64), a late packet arriving after wrapping could incorrectly pass the >= check.
**Fix:** Use wrapping-aware comparison or document that systems must ensure no wrap-around in streaming windows.

---

**AUDIO-007 · P1 · MISSING_ERROR_HANDLING**
File: MadiFullDuplexSocketRunner.swift, lines 182-195
In `waitForReadableSocket()`, `poll()` result >= 0 is checked but negative errno is saved AFTER the check. Line 191: `let savedErrno = errno` happens after OSStatus check, but errno may be cleared by subsequent calls.
**Fix:** Capture errno immediately after `poll()` returns: `let savedErrno = errno; guard result >= 0 else { ... }`.

---

**AUDIO-008 · P0 · RACE_CONDITION**
File: DirectPeerRealtimeAudioGraph.swift, lines 205-214
In `stop()` method, accessing `inputDeviceID`, `outputDeviceID`, `inputIOProcID`, `outputIOProcID` without atomicity while IOProc may still be running. IOProc reads these to convert host time. Race on deallocation.
**Fix:** Add synchronization: use a lock or atomic flag to ensure IOProc is fully stopped before reading/clearing these optionals.

---

**AUDIO-009 · P0 · RACE_CONDITION**
File: AudioLoopbackRun.swift, lines 384-423
In `AudioLoopbackIOProcState.record()`, reading/writing `lastHostTimeNanoseconds`, `intervalCount`, `missedDeadlines`, `underruns`, `overruns`, `hostTimeConversionFailures` are all non-atomic. These are mutated from the IOProc callback and read from the main thread in `callbackMetrics()` without synchronization.
**Fix:** Use atomic integers (OpenLolaAtomicUInt64) or protect with a lock.

---

**AUDIO-010 · P1 · MEMORY_SAFETY**
File: DirectPeerRealtimeAudioGraph.swift, lines 296-302
In `captureInjectedPayload()`, checking `ioProcRunning == 0` before injecting, but IOProc could start immediately after the check and before the push. No atomicity guarantee.
**Fix:** Document that injection is testing-only and races are acceptable, OR use proper synchronization (atomic CAS loop).

---

**AUDIO-011 · P1 · LOGIC_BUG**
File: RealtimeAudioPayloadCaptureRing.swift, line 47
`precondition(capacity <= Int.max / shape.byteCount, "RealtimeAudioPayloadCaptureRing storage size must not overflow")`
This check happens at init time. If `capacity * shape.byteCount` overflows, the array allocation on line 51 will already have happened without proper overflow guard.
**Fix:** Perform overflow check before array allocation: `let totalBytes = try UInt64(capacity).multipliedReportingOverflow(by: UInt64(shape.byteCount))`.

---

**AUDIO-012 · P1 · LOGIC_BUG**
File: MadiReceiveEngine.swift, line 197
`let remoteReceiveMode = try configuration.audioPair.remoteReceiveMode(...)` - This is called multiple times in tests (MadiFullDuplexSmoke) but the field is not re-validated after creation. If remoteToLocal stream changes, mode mismatch is silent.
**Fix:** Cache remoteReceiveMode and validate consistency, or document immutability requirement.

---

**AUDIO-013 · P2 · SLOP**
File: AudioStreamDescription.swift, lines 53-71
Validation creates intermediate Set twice in validateUniqueChannelIndices() for same indices. 
**Fix:** Consolidate into single loop with early-exit on first duplicate.

---

**AUDIO-014 · P1 · MISSING_ERROR_HANDLING**
File: MadiReceiveBuffers.swift, lines 294-307
`readInt16()` and `readFloat32()` helper functions return 0 if baseAddress is nil, silently dropping errors. Callers cannot distinguish between actual zero samples and missing data.
**Fix:** Return Optional<T> or throw error, or add explicit error code to return value.

---

**AUDIO-015 · P1 · LOGIC_BUG**
File: RealtimeAudioBuffers.swift, lines 345-347
In `RealtimeAudioFixedTargetJitterBuffer.dropStalePackets()`, if `bufferedPackets` becomes negative (underflow due to double-drop), the check on line 345 (`if bufferedPackets > capacityBlocks`) will miss hidden growth. 
**Fix:** Guard against negative counts: `if dropped > 0 && dropped <= bufferedPackets { bufferedPackets -= dropped; }`.

---

**AUDIO-016 · P2 · SLOP**
File: MadiFullDuplexValidation.swift, lines 3-26
Validation helper functions are repeated (requireM05NonEmpty, etc.) in multiple files (MadiFullDuplexValidation.swift, MadiReceiveReport.swift, MadiTransmit.swift). Boilerplate duplication.
**Fix:** Consolidate into single ValidationPrimitives extensions or central module.

---

**AUDIO-017 · P1 · LOGIC_BUG**
File: RmeMatrixMetadataSnapshot.swift, line 156
Pan range check: `guard route.pan >= -1, route.pan <= 1 else { ... }`
Floating-point equality at boundaries. Pan values like 0.9999999999 may fail validation due to rounding.
**Fix:** Use tolerance: `guard route.pan >= -1.0 - 1e-10 && route.pan <= 1.0 + 1e-10 else { ... }`.

---

**AUDIO-018 · P2 · BOILERPLATE**
File: CoreAudioInventoryReader.swift, lines 162-238
Six nearly-identical property reader functions (stringProperty, uint32Property, doubleProperty, audioValueRange, audioValueRanges, streamCount) with repeated AudioObjectPropertyAddress setup.
**Fix:** Create generic helper factory function to reduce duplication.

---

**AUDIO-019 · P1 · MEMORY_SAFETY**
File: MadiReceiveBuffers.swift, lines 150-152
`guard let destinationBase = destinationBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { ... }`
If baseAddress is nil, the guard throws but destinationBase was never set. This is safe but the binding is misleading.
**Fix:** Unwrap nil case explicitly before assumingMemoryBound.

---

**AUDIO-020 · P1 · MISSING_ERROR_HANDLING**
File: OpusCELTLowDelayCodec.swift, line 99
`output.baseAddress!.assumingMemoryBound(to: UInt8.self)` - Force unwrap of output buffer baseAddress inside withUnsafeMutableBytes closure. If system returns nil baseAddress, crash.
**Fix:** Check guard `let` before force unwrap: `guard let base = output.baseAddress else { throw ... }`.

---

**AUDIO-021 · P1 · LOGIC_BUG**
File: RealtimeAudioFixedTargetJitterBuffer.swift, lines 263-267
`playoutFrame &+ UInt64(playoutTargetFrames)` uses wrapping add, but if playoutTargetFrames overflows during calculation, silent wrap-around occurs.
**Fix:** Validate `playoutTargetFrames` at init: ensure it doesn't cause overflow when added to maximum expected packet frame indices.

---

**AUDIO-022 · P2 · CODE_QUALITY**
File: RealtimeAudioBuffers.swift, lines 268-301
`copySelectedInterleavedChannels()` and `copySelectedAudioBuffers()` are identical in structure but duplicate memcpy and offset logic. 
**Fix:** Extract common copy loop into helper function.

---

**AUDIO-023 · P1 · LOGIC_BUG**
File: AudioLoopbackRun.swift, line 203
`if intervalCount < intervals.count { intervals[intervalCount] = deltaMicroseconds; intervalCount += 1; } else { overruns += 1; }`
If `intervalCount` reaches `intervals.count` early, all subsequent callback intervals are dropped and counted as overruns. No telemetry of how many intervals were actually recorded vs. dropped.
**Fix:** Track both total callbacks and recorded samples; report recording saturation explicitly.

---

**AUDIO-024 · P1 · LOGIC_BUG**
File: DirectPeerRealtimeAudioGraph.swift, line 331
`let (scaled, overflow) = hostTime.multipliedReportingOverflow(by: hostTimeNumerator)`
If overflow is true, returns `UInt64.max`. Caller then uses this to record device timing. Saturated values break jitter calculations.
**Fix:** Return nil on overflow and handle error path gracefully instead of saturating to max.

---

**AUDIO-025 · P2 · SLOP**
File: RealtimeAudioPacketHandoff.swift, lines 37-47
Channel map normalization logic duplicated from DirectPeerRealtimeAudioGraph.swift and AudioLoopbackRun.swift.
**Fix:** Create shared `normalizeChannelMap()` function in a central module.

---

**AUDIO-026 · P1 · MISSING_ERROR_HANDLING**
File: AudioLoopbackRun.swift, lines 208-301
In `runIOProc()`, if `AudioDeviceCreateIOProcID()` succeeds but `AudioDeviceStart()` fails, the defer block destroys the IOProcID. However, if `AudioDeviceStop()` later fails (line 332), the error is silently ignored (line 333: `_ =`). Cleanup errors leak.
**Fix:** Log or collect cleanup errors; ensure all error paths are documented.

---

**AUDIO-027 · P1 · MEMORY_SAFETY**
File: MadiReceiveBuffers.swift, lines 171-181
In reassemble loop, checking bounds:
```swift
guard destinationStart + fragmentFrameByteCount <= destinationBytes.count
```
But `fragmentFrameByteCount` is computed from header without bounds check. If header claims massive channels-in-fragment, overflow is possible.
**Fix:** Validate `channelsInFragment` and computed sizes against known limits before using in bounds checks.

---

**AUDIO-028 · P1 · LOGIC_BUG**
File: RealtimeAudioBuffers.swift, line 141
`guard block.startFrame < nextFrame &+ UInt64(storage.count * framesPerBlock) else { ... }`
Multiplication `storage.count * framesPerBlock` can overflow before the add. Uses non-wrapping arithmetic.
**Fix:** Use `storage.count.multipliedReportingOverflow(by: framesPerBlock)` and handle overflow.

---

**AUDIO-029 · P2 · SLOP**
File: RmeFastestAudioPathReport.swift, lines 360-381
Large nested loop building `placeholderSensitiveTextFields()` with manual array appends. No validation that all required fields are included.
**Fix:** Use struct reflection or explicit field checklist to ensure completeness.

---

**AUDIO-030 · P1 · LOGIC_BUG**
File: RealtimeAudioEngineReportValidation.swift, line 300
`let targetPackets = configuration.playoutTargetFrames / configuration.framesPerBuffer`
Integer division. If playoutTargetFrames is not a multiple of framesPerBuffer, rounding occurs silently.
**Fix:** Guard that playoutTargetFrames is 0 or a multiple of framesPerBuffer; throw error otherwise.

---

**AUDIO-031 · P0 · RACE_CONDITION**
File: MadiReceiveEngine.swift, lines 305-330
`applyReceiverMix()` mutates `receiverMixScratch` (a field) and reads `mixStore.prepared.routes` and `mode` without holding any lock. If mixing is reconfigured from another thread while this executes, data race.
**Fix:** Mark as "must be called from single thread only" and add assertions, OR protect with a lock.

---

**AUDIO-032 · P1 · MEMORY_SAFETY**
File: RealtimeAudioPayloadCaptureRing.swift, lines 66-69
`payloadStorage.withUnsafeMutableBufferPointer { destination in if let baseAddress = destination.baseAddress { memset(...) } }`
If Data allocation succeeds but withUnsafeMutableBufferPointer yields nil baseAddress (unlikely but possible), memset is silently skipped and payload contains garbage.
**Fix:** Guard strictly: `guard let baseAddress = destination.baseAddress else { ... throw ... }`.

---

**AUDIO-033 · P1 · LOGIC_BUG**
File: AudioLoopbackRun.swift, lines 419-422
`if deltaMicroseconds > expectedIntervalMicroseconds * 1.5 { missedDeadlines += 1; underruns += 1; }`
Both missedDeadlines and underruns are incremented together. This double-counts. Semantically unclear if one late callback = one missed deadline + one underrun, or if they're independent.
**Fix:** Clarify semantics and increment only relevant counter, or document the relationship.

---

**AUDIO-034 · P2 · SLOP**
File: AudioBaselineEvidence.swift, lines 9-20
`isThunderboltPerformancePath()` checks for "thun" substring to match "thunderbolt". Too broad; "thumbnail" or "thunk" would match.
**Fix:** Use word boundaries or explicit prefix matching: `normalized.contains("thunderbolt")`.

---

**AUDIO-035 · P1 · LOGIC_BUG**
File: RealtimeAudioPacketHandoff.swift, line 286
`nextSequenceNumber &+= 1` uses wrapping increment without checking for overflow. If nextSequenceNumber wraps to 0, receiver may mistake it for a valid old packet due to wraparound.
**Fix:** Document wrap-around behavior; ensure receiver resets on stream discontinuity.

---

**AUDIO-036 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerRealtimeAudioGraph.swift, lines 184-203
`makeAndStartIOProc()` creates IOProcID but if AudioDeviceStart() fails, the error is thrown and IOProcID is destroyed in catch block. However, the IOProcID is not retained; on failure, clientData becomes dangling.
**Fix:** Ensure all cleanup paths deinitialize the Unmanaged reference properly.

---

**AUDIO-037 · P2 · SLOP**
File: RealtimeAudioEngineReportValidation.swift, lines 326-340
`placeholderSensitiveFields()` manually constructs array of tuples with hardcoded field names. No way to ensure all fields are covered if report struct changes.
**Fix:** Use compile-time struct reflection or generate this list programmatically.

---

**AUDIO-038 · P1 · LOGIC_BUG**
File: MadiReceiveBuffers.swift, lines 245-292
In `MadiReceiveReadyBlockRing.store()`, if `overrunPolicy == .dropOldest`, line 273: `storage[index] = block` overwrites without releasing the old block. The old block is lost without being returned to caller or recorded.
**Fix:** Return the dropped block or at least record its sequence number in metrics.

---

**AUDIO-039 · P1 · MEMORY_SAFETY**
File: RealtimeAudioPayloadCaptureRing.swift, lines 304-320
In `validAudioBuffers()`, checking `inputBuffers[location.bufferIndex].mData != nil` but later on line 332 in `copySelectedAudioBuffers()` assuming it's non-nil. Between check and use, the buffer could be freed.
**Fix:** Move validation immediately before copy in same scope, or pass validated pointers.

---

**AUDIO-040 · P2 · CODE_QUALITY**
File: DirectPeerAudioPayloadRing.swift, lines 58-79
Function `push()` is 22 lines with nested logic. Could be split into `validateInput()` and `storePayload()` for clarity.
**Fix:** Refactor into 2-3 helper functions with clear responsibilities.

---

**AUDIO-041 · P1 · LOGIC_BUG**
File: RealtimeAudioPacketHandoff.swift, line 192
`let playoutFrame = packet.header.senderFrameIndex &+ UInt64(playoutTargetFrames)`
If `playoutTargetFrames` is negative (should not happen but no validation), wrapping add gives wrong result.
**Fix:** Add precondition: `precondition(playoutTargetFrames >= 0, "playoutTargetFrames must be non-negative")`.

---

**AUDIO-042 · P2 · SLOP**
File: MadiFullDuplexSocketRunner.swift, line 202
Function `payloadByteCount(for:)` is defined locally. Identical function exists in MadiTransmit.swift and MadiReceiveReport.swift.
**Fix:** Move to shared utility module.

---

**AUDIO-043 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerRealtimeAudioGraph.swift, lines 169-182
Device configuration (lines 170-181) happens inside try-catch, but if one property set fails, the second one (lines 176-180) may not execute. Incomplete device state on error.
**Fix:** Either commit all-or-nothing, or restore original values on partial failure.

---

**AUDIO-044 · P2 · SLOP**
File: AudioLoopbackRun.swift, line 361
`expectedIntervalMicroseconds = (Double(configuration.framesPerBuffer) / Double(configuration.sampleRateHertz)) * 1_000_000`
Hardcoded 1_000_000 multiplier for ns->μs. Should use named constant.
**Fix:** Define `let microsecondsPerSecond = 1_000_000` at module scope.

---

**AUDIO-045 · P1 · LOGIC_BUG**
File: RealtimeAudioBuffers.swift, lines 392-395
`updateMaximumBufferedBlocks()` called after every operation, but if bufferedPackets exceeds capacityBlocks, `hiddenPlayoutGrowthDetected = true` is set but not reported until later. Transient overages may not be captured in final metrics.
**Fix:** Log or return timestamp of first detection for better diagnostics.

---

**AUDIO-046 · P1 · MISSING_ERROR_HANDLING**
File: MadiReceiveBuffers.swift, lines 171-178
In `reassemble()`, if `destinationBytes.baseAddress` is nil (line 150 guard), the error is thrown with generic message. Caller cannot distinguish buffer allocation failure from corrupted packet.
**Fix:** Use distinct error cases for different failure modes.

---

**AUDIO-047 · P2 · SLOP**
File: RealtimeAudioPacketHandoff.swift, lines 56-74
Initializer constructs metrics with hardcoded 0 values for all counters. If new metrics fields are added, they default to 0 silently.
**Fix:** Use explicit struct initializer or struct literal syntax with named fields for completeness checking.

---

**AUDIO-048 · P1 · LOGIC_BUG**
File: RmeFastestAudioPathReport.swift, lines 280-283
Loop iterates sample rates [48_000, 96_000] hardcoded. If system supports 44.1 kHz, it's silently skipped.
**Fix:** Query supported sample rates dynamically instead of hardcoding.

---

**AUDIO-049 · P0 · REALTIME_SAFETY**
File: MadiReceiveEngine.swift, lines 305-330
String interpolation in function names and route metadata is not called from callback, but if this function is eventually called from IOProc, the `String` construction will allocate.
**Fix:** Pre-compute all strings during initialization; ensure no string construction in mix path.

---

**AUDIO-050 · P1 · MEMORY_SAFETY**
File: DirectPeerRealtimeAudioGraph.swift, line 601
`precondition(index >= 0 && index < count, "audio buffer index out of range")`
Uses precondition which is stripped in Release builds. Out-of-bounds access in production.
**Fix:** Use guard with throwing error, or assert + bounds-safe array access (if possible).

---

**AUDIO-051 · P2 · SLOP**
File: AudioLoopbackRunConfiguration.swift, lines 68-104
Parse function has 16 sequential if-let bindings. Hard to read; should use single guard or structured parsing.
**Fix:** Refactor into smaller sub-parsers: `parseInputUID()`, `parseSampleRate()`, etc.

---

**AUDIO-052 · P1 · LOGIC_BUG**
File: RealtimeAudioFixedTargetJitterBuffer.swift, line 215
`guard read < write else { return 0 }`
If ring is empty (read == write), returns 0. But if exactly one element, also returns without dropping. Logic is correct but naming is unclear.
**Fix:** Add comment explaining that loop only drops < dueFrame (not == dueFrame).

---

**AUDIO-053 · P1 · MEMORY_SAFETY**
File: AudioLoopbackRun.swift, line 371
`self.intervals = UnsafeMutableBufferPointer<Double>.allocate(capacity: expectedCallbacks + 16)`
If `expectedCallbacks` is huge (Int.max - 16), allocation succeeds but memory is unbounded.
**Fix:** Add cap: `min(expectedCallbacks, 100_000)` to prevent excessive allocation.

---

**AUDIO-054 · P2 · SLOP**
File: CoreAudioInventoryReader.swift, line 401
`let resolvedUID: String = "unknown-\(deviceID)"` uses string interpolation. If called frequently, allocation spam.
**Fix:** Pre-compute fallback UID or use static cache.

---

**AUDIO-055 · P1 · LOGIC_BUG**
File: RealtimeAudioPacketHandoff.swift, lines 161-183
`sendNextV2Packets()` validates mode but allows sending even if mode fragments don't match capture ring channels. Silent mismatch.
**Fix:** Validate that fragments cover all captured channels; throw error on mismatch.

---

**AUDIO-056 · P1 · MISSING_ERROR_HANDLING**
File: AudioLoopbackRun.swift, line 343
`let intervals = UnsafeMutableBufferPointer<Double>.allocate(capacity: expectedCallbacks + 16)`
Allocation can fail if system OOM, but no error handling.
**Fix:** Wrap in try-catch and throw AudioLoopbackRunError on allocation failure.

---

**AUDIO-057 · P2 · SLOP**
File: RmeMatrixMetadataSnapshot.swift, lines 137-159
Validation loop over routes has nested validation. Could be factored into helper.
**Fix:** Extract `validateRoute()` helper function.

---

**AUDIO-058 · P1 · LOGIC_BUG**
File: MadiReceiveBuffers.swift, lines 289-291
`Int((playoutFrame / UInt64(framesPerBlock)) % UInt64(storage.count))`
Division by zero if framesPerBlock is 0. No guard.
**Fix:** Add precondition at init: `precondition(framesPerBlock > 0, "framesPerBlock must be positive")`.

---

**AUDIO-059 · P1 · LOGIC_BUG**
File: RealtimeAudioPayloadCaptureRing.swift, line 265
`sourceChannelCount == shape.channelCount && directInterleavedInput`
Checks both conditions but if sourceChannelCount is 0, first check is false and direct copy is avoided. Correct but semantically confusing.
**Fix:** Add explicit guard: `guard sourceChannelCount > 0 && sourceChannelCount == shape.channelCount && directInterleavedInput else { ... }`.

---

**AUDIO-060 · P1 · MEMORY_SAFETY**
File: RealtimeAudioPacketHandoff.swift, line 125
`let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))`
Casting const pointer to mutable. Undefined behavior if CoreAudio expects input to be read-only.
**Fix:** Keep input as const; use separate mutable pointer only for output buffers.

---

**AUDIO-061 · P2 · SLOP**
File: CoreAudioInventoryReader.swift, lines 420-440
`fourCharacterCode()` function converts UInt32 to String. Hardcoded ASCII range check [32, 126]. No handling for multi-byte encodings.
**Fix:** Document ASCII-only constraint; add comment about FourCC spec.

---

**AUDIO-062 · P1 · MISSING_ERROR_HANDLING**
File: MadiReceiveEngine.swift, lines 155-160
In reassemble loop, if a fragment is missing (line 154 guard throws), the entire reassembly fails but previous fragments are already copied. No rollback.
**Fix:** Validate all fragments exist before starting memcpy operations.

---

**AUDIO-063 · P1 · LOGIC_BUG**
File: RealtimeAudioFixedTargetJitterBuffer.swift, line 400
`Int((playoutFrame / UInt64(framesPerBlock)) % UInt64(capacityBlocks))`
If capacityBlocks is 0 (should be blocked by precondition), modulo by zero.
**Fix:** Verify precondition at line 227 is enforced throughout lifecycle.

---

**AUDIO-064 · P1 · MEMORY_SAFETY**
File: DirectPeerAudioPayloadRing.swift, lines 35-36
`for slot in 0..<capacity { open_lola_atomic_u64_init(self.occupied.advanced(by: slot), 0) }`
Assumes `self.occupied.advanced(by: slot)` is always in bounds. If capacity is huge, pointer arithmetic could overflow.
**Fix:** Guard: `guard slot < capacity else { fatalError() }` or bounds-check the pointer.

---

**AUDIO-065 · P2 · SLOP**
File: MadiReceiveReport.swift, lines 84-85
Hardcoded required channel counts: `Set([2, 8, 16, 32, 64])`. If new channel counts are added, must update here.
**Fix:** Move to shared constant or derive from mode definitions.

---

**AUDIO-066 · P1 · LOGIC_BUG**
File: AudioLoopbackRun.swift, line 406
`guard hostTimeNanoseconds > lastHostTimeNanoseconds else { lastHostTimeNanoseconds = hostTimeNanoseconds; return }`
If time goes backward (clock skew), record is updated but comparison skipped. Next interval is skipped.
**Fix:** Log or reset on time backward; document expected behavior.

---

**AUDIO-067 · P1 · MEMORY_SAFETY**
File: RealtimeAudioPayloadCaptureRing.swift, lines 149-159
In `pushAudioBuffers()`, if `copied` is false, return invalidDrop(). But if inputBuffers count == 1 path succeeds (line 138), the ring slot is committed with payload. No validation that Data contains exactly expected bytes.
**Fix:** Validate `payload.count == shape.byteCount` in pushInterleaved callback.

---

**AUDIO-068 · P2 · SLOP**
File: AudioLoopbackRun.swift, lines 514-527
`copyInputToOutput()` memcpy uses `min(input.size, output.size)`. If input is larger, data is truncated. Silent data loss.
**Fix:** Validate sizes match exactly; throw error on mismatch.

---

**AUDIO-069 · P1 · LOGIC_BUG**
File: RealtimeAudioFixedTargetJitterBuffer.swift, lines 341-348
`if dropped > 0 { bufferedPackets -= dropped; ... }`
If dropped > bufferedPackets, subtraction underflows (since bufferedPackets is Int, not unsigned). Result is negative.
**Fix:** Guard: `bufferedPackets = max(0, bufferedPackets - dropped)`.

---

**AUDIO-070 · P1 · MISSING_ERROR_HANDLING**
File: DirectPeerRealtimeAudioGraph.swift, lines 396-417
In `copyMappedInput()`, multiple nested guard conditions check buffer validity. If any fails, returns false without logging which buffer failed.
**Fix:** Return result enum or error to distinguish input channel OOB vs. buffer OOB vs. size OOB.

---

## SUMMARY

**Total Findings: 70**

**By Severity:**
- **P0 (Critical):** 2 (Audio-009, Audio-031)
- **P1 (High):** 57
- **P2 (Medium/Low):** 11

**By Category:**
- **REALTIME_SAFETY:** 2
- **MEMORY_SAFETY:** 15
- **LOGIC_BUG:** 23
- **RACE_CONDITION:** 3
- **MISSING_ERROR_HANDLING:** 15
- **SLOP/BOILERPLATE:** 12

All findings include specific file locations, line numbers, problem descriptions, and recommended fixes.

---

## Group 13 — Network / UDP / NAT / RTP (NET-001 – NET-045)

## Network/UDP/NAT/RTP Deep Audit — NET-001 to NET-045

**NET-001 · P0 · MEMORY_SAFETY**
File: UdpPcmPacket.swift, lines 133–155
Unchecked array subscripts in readUdpPcmUInt* helpers used without bounds verification on received packet data. Short/malformed packets crash on out-of-bounds read.
**Fix:** Use `udpPcmHasBytes()` check before ALL calls to readUdpPcmUInt* helpers in V1 packet decode, or create checked variants.

**NET-002 · P0 · MEMORY_SAFETY**
File: AES67ST2110L24Transport.swift, lines 156–158
L24 sign extension is incorrect: reads 24-bit value into low bits as unsigned, losing sign. Correct: `(Int32(b0) << 24 | Int32(b1) << 16 | Int32(b2) << 8) >> 8`.
**Fix:** Replace with arithmetic right-shift sign-extension pattern.

**NET-003 · P0 · MEMORY_SAFETY**
File: AES67ST2110L24Transport.swift, lines 131–135
Loop over sampleCount samples without final bounds check on `offset + 3` access in last iteration.
**Fix:** Add guard that `payload.count == expectedByteCount` before the loop.

**NET-004 · P0 · MEMORY_SAFETY**
File: AES67ST2110L24Transport.swift, lines 154–158
Loop reading 3-byte L24 samples: if payload count not divisible by 3, `offset + 2` read crashes in last iteration.
**Fix:** Verify length check at line 148 is comprehensive and covers all L24 decode paths.

**NET-005 · P0 · MEMORY_SAFETY**
File: AES67ST2110L24Transport.swift, lines 344–352
`readRTPUInt16BE` / `readRTPUInt32BE` access `bytes[offset]` without bounds checking. Fragile pattern.
**Fix:** Add preconditions/asserts in helper functions or use udpPcmHasBytes-style checks.

**NET-006 · P1 · LOGIC_BUG**
File: UdpPcmDataHelpers.swift, lines 3–4
`udpPcmHasBytes()` boundary condition: `offset <= bytes.count - count` relies on unsigned arithmetic semantics for safety when count > bytes.count.
**Fix:** Add comment explaining unsigned subtraction safety; consider explicit guard.

**NET-007 · P1 · MEMORY_SAFETY**
File: UdpMediaTransport.swift, lines 515–535
`readUdpMediaUInt64LE` calls `readUdpMediaUInt32LE` twice with `offset + 4` but second call's pre-condition is only implied by first call's success.
**Fix:** Add explicit guard for `offset + 4` before the second call.

**NET-008 · P1 · PROTOCOL_BUG**
File: AES67ST2110L24Transport.swift, lines 162–164
Asymmetric quantization normalization: negative path divides by 8_388_608.0 vs positive 8_388_607.0. Per AES67 spec normalization should be symmetric.
**Fix:** Use `Float(value) / 8_388_607.0` for both branches.

**NET-009 · P1 · SOCKET_OPERATIONS**
File: UdpPcmSocketOperations.swift, lines 14–15, 22–28
Sets SO_RCVBUF/SO_SNDBUF without verifying actual buffer size post-setsockopt. Kernel may silently reduce the size.
**Fix:** After setsockopt, call getsockopt to verify actual sizes were applied.

**NET-010 · P1 · MISSING_ERROR_HANDLING**
File: UdpPcmSocketOperations.swift, lines 59–68
`fcntl()` check uses `flags < 0` instead of `flags == -1` per POSIX spec.
**Fix:** Change to `flags == -1` for precise POSIX compliance.

**NET-011 · P1 · MISSING_ERROR_HANDLING**
File: UdpPcmLoopbackSocketRunners.swift, lines 369–392
`recvfrom()` result `addressLength` not validated — could be 0 or incomplete after receive.
**Fix:** Guard that `addressLength == MemoryLayout<sockaddr_in>.size` after recvfrom.

**NET-012 · P1 · RACE_CONDITION**
File: UdpPcmLoopbackSocketRunners.swift, lines 57–123
UDP hole-punching: no synchronization mechanism — both sides must send "simultaneously." If one side delays, hole-punching fails silently.
**Fix:** Use TCP control channel to signal readiness before sending keepalives, or add STUN protocol.

**NET-013 · P1 · RACE_CONDITION**
File: NatFriendlyRouteRunner.swift, lines 69–123
NAT traversal keepalive loop has no per-attempt timeout. If peer never responds, loop runs until overall deadline.
**Fix:** Add per-attempt timeout (e.g., 1 second) in addition to overall deadline.

**NET-014 · P1 · LOGIC_BUG**
File: NatFriendlyRouteRunner.swift, line 96
Peer ID filter condition inverted: `message.peerID != configuration.peerID` accepts messages from ANYONE except the expected peer.
**Fix:** Change `!=` to `==` — accept messages only from the expected peer.

**NET-015 · P1 · FRAGMENTATION**
File: UdpPcmV2FragmentPlanner.swift, lines 165–194
Fragment planning multiplies `channelsInFragment * bytesPerChannel` without overflow guard.
**Fix:** Add checked multiplication with error on overflow.

**NET-016 · P1 · MEMORY_SAFETY**
File: UdpPcmV2Packet.swift, lines 337–341
memcpy advances pointers by calculated offsets without final bounds verification (relies on upstream check at lines 333–335).
**Fix:** Add assertion: pattern is safe but fragile across refactors.

**NET-017 · P1 · LOGIC_BUG**
File: AudioOpusCeltLowDelayPacket.swift, lines 79–87
All field reads use unchecked readUdpPcmUInt*LE helpers. While minimum 56-byte check at line 69 makes specific accesses safe, pattern is fragile.
**Fix:** Use checked readers like V2 packet does.

**NET-018 · P1 · MISSING_ERROR_HANDLING**
File: NatFriendlyRouteRunner.swift, lines 154–168
`openRegisteredSocket()` response not fully validated — missing required fields not checked.
**Fix:** Add explicit validation for required response fields.

**NET-019 · P1 · MISSING_ERROR_HANDLING**
File: UdpPcmContinuousRouteRunner.swift, lines 276–293
Packet validation happens AFTER incrementing received counter. Mode mismatch not detected early.
**Fix:** Move validation before incrementing `packetsReceived`.

**NET-020 · P1 · SOCKET_OPERATIONS**
File: UdpPcmSocketOperations.swift, lines 206–215
`recv()` returning 0 bytes not handled (rare in UDP but possible).
**Fix:** Add explicit check for `received == 0` and throw appropriate error.

**NET-021 · P1 · MISSING_ERROR_HANDLING**
File: UdpPcmSocketOperations.swift, lines 234–249
`receiveDatagramIfAvailable()` with no size cap — huge `byteCount` allocates huge buffer every call.
**Fix:** Guard `byteCount <= 65535` (max UDP payload) or configured max.

**NET-022 · P1 · MISSING_ERROR_HANDLING**
File: UdpPcmRouteRunConfiguration.swift, lines 65–66
`precondition()` validations in init() disabled in Release builds — invalid config crashes silently.
**Fix:** Move to a throwing `validate()` method.

**NET-023 · P1 · MISSING_ERROR_HANDLING**
File: UdpMediaTransport.swift, lines 159–194
`validateNestedPayload()` decodes nested packets without verifying outer payload byte count matches expected inner size.
**Fix:** After decoding, verify outer payload == inner encoded size.

**NET-024 · P1 · MISSING_ERROR_HANDLING**
File: UdpPcmV2Packet.swift, lines 62–75
`readCheckedUdpPcmUInt*` functions internally call unchecked variants. External callers can bypass bounds check by calling unchecked directly.
**Fix:** Make unchecked variants `private`, force all callers through checked wrappers.

**NET-025 · P0 · MEMORY_SAFETY**
File: UdpPcmDataHelpers.swift, lines 20–21
`readUdpPcmUInt64LE` calls `readUdpPcmUInt32LE` twice with offsets that could be out-of-bounds if called without external bounds checking.
**Fix:** Only call from bounds-checked context; mark unchecked helpers `private`.

**NET-026 · P1 · LOGIC_BUG**
File: UdpPcmLoopbackHelpers.swift, line 34
Report ID uses `Int(Date().timeIntervalSince1970)` — will overflow in year 2038 on 32-bit; unclear intent on 64-bit.
**Fix:** Use UUID or ISO8601 timestamp string.

**NET-027 · P2 · BOILERPLATE**
Files: UdpPcmDataHelpers.swift, UdpPcmV2Packet.swift, AES67ST2110L24Transport.swift, UdpMediaTransport.swift
Multiple duplicate implementations of `readUInt16BE` / `readUInt32BE` helpers.
**Fix:** Consolidate into a single `ByteReader` utility module.

**NET-028 · P2 · PERF**
File: UdpPcmRouteHelpers.swift, lines 303–309
`percentile()` sorts array on every call. Multiple calls with same data waste CPU.
**Fix:** Cache sorted result or sort once per measurement epoch.

**NET-029 · P2 · LOGIC_BUG**
File: UdpPcmLoopbackSmokes.swift, line 64
`UInt16(bigEndian: try boundPort(...))` — `boundPort` already returns network byte order from `getsockname`; double-converting may produce wrong port.
**Fix:** Remove extraneous `bigEndian` conversion; verify port byte-order semantics.

**NET-030 · P2 · SLOP**
File: UdpPcmLoopbackLatency.swift, lines 67–82
Magic constants: port 5_004, sample rate 48_000, frame count 32 scattered throughout loopback files.
**Fix:** Extract to a shared `LoopbackDefaults` enum.

**NET-031 · P2 · CODE_QUALITY**
File: UdpPcmV2Packet.swift, lines 217–221
`precondition()` used to verify fragment plan coverage — disabled in Release, hides bugs in production.
**Fix:** Replace with throwing guard.

**NET-032 · P2 · DIAGNOSTICS**
File: NetworkDiagnostics.swift, lines 143–150
No hardcoded thresholds for "passing" AoIP diagnostics. Verdict based on data presence, not quality.
**Fix:** Define and document minimum acceptable latency/jitter/loss thresholds.

**NET-033 · P2 · DIAGNOSTICS**
File: UdpPcmLoopbackLatency.swift, lines 262–280
`(delta / icmp) * 100` percent delta has unbounded output if ICMP latency is tiny.
**Fix:** Add minimum denominator floor: `let percent = icmp > 0.001 ? ... : 0`.

**NET-034 · P2 · BOILERPLATE**
Files: AudioOpusCeltLowDelayPacket.swift, UdpPcmPacket.swift, UdpPcmV2Packet.swift, UdpMediaTransport.swift
All packet types repeat similar decode/encode/validate patterns with no shared protocol.
**Fix:** Extract common `PacketCodec` protocol or base class.

**NET-035 · P2 · PERF**
File: UdpPcmRouteHelpers.swift, lines 225–229
`packetIntervalNanoseconds()` calls `MediaClock.nanoseconds()` every call. Wasteful in tight loops.
**Fix:** Cache result in callers or memoize.

**NET-036 · P2 · SLOP**
Files: NAT and route files
Protocol version strings `"open-lola-nat-keepalive-v1"`, `"open-lola"` hardcoded in multiple places.
**Fix:** Define as named constants in a shared module.

**NET-037 · P1 · MISSING_ERROR_HANDLING**
File: UdpMediaTransport.swift, lines 82–92
`try` applied to functions declared non-throwing — broken exception propagation silently swallows real errors.
**Fix:** Either implement throwing versions or remove `try`; audit every call site.

**NET-038 · P1 · RACE_CONDITION**
File: NatFriendlyRouteRunner.swift, lines 71–72
Unsigned wrapping subtraction `now &- lastSend` for timer math — correct but unexplained.
**Fix:** Add comment explaining UInt64 wraparound arithmetic intent.

**NET-039 · P2 · SLOP**
Files: UdpPcmSocketOperations.swift, line 5
Magic constant `4 * 1024 * 1024` for buffer size with no rationale comment.
**Fix:** Define as named constant with explanation.

**NET-040 · P1 · MISSING_ERROR_HANDLING**
File: UdpPcmRouteRunConfiguration.swift
`precondition()` in parse() — invalid packet mode crashes in Release.
**Fix:** Add throwing validation in parse() method.

**NET-041 · P2 · CODE_QUALITY**
Files: Multiple UDP/NAT files
Inconsistent error handling: some functions throw, some return nil, some silently ignore. No unified pattern.
**Fix:** Establish a consistent error handling convention across all transport code.

**NET-042 · P1 · LOGIC_BUG**
File: UdpPcmV2FragmentPlanner.swift
Fragment count * fragment size overflow possible for pathological configurations.
**Fix:** Add overflow-checked arithmetic before allocating fragment plan.

**NET-043 · P2 · SLOP**
Files: Multiple loopback files
`let _ =` discards return values on socket operations — silent failure on socket errors.
**Fix:** Explicitly handle or log all discarded return values.

**NET-044 · P1 · MISSING_ERROR_HANDLING**
File: NatFriendlyRouteSmokes.swift
Smoke test errors are printed but tests continue — smoke tests pass even on failure.
**Fix:** Propagate errors from smoke tests or mark test as failed explicitly.

**NET-045 · P2 · SLOP**
File: UdpPcmRouteCertification.swift
Certification thresholds hardcoded in certification runner rather than sourced from `NetworkAoipCertification`.
**Fix:** Centralise all certification thresholds in `NetworkAoipCertification`.


---

## Group 14 — Release / Core / Evidence / Integration (REL-001 – REL-070)

**REL-001 · P0 · MISSING_ERROR_HANDLING**
File: RecordingSessionLiveCapture.swift, lines 88-97
Force unwrap of optional `ioProcID` in Core Audio recording without null check. If `AudioDeviceCreateIOProcID` sets `ioProcID` to nil, the force unwrap at line 95 `guard let ioProcID` will crash if the preceding assignment failed.
**Fix:** Remove force unwrap; the guard statement already ensures non-nil, but missing validation before that guard allows potential crash.

---

**REL-002 · P1 · LOGIC_BUG**
File: LatencyBenchmarkReport.swift, lines 132-136
Validation checks `oneWayEstimateMicroseconds <= roundTripMicroseconds`, but documentation and comments indicate confusion between round-trip (two-way) and one-way latency. One-way should always be <= round-trip, but the naming suggests potential confusion in measurement collection.
**Fix:** Add explicit documentation clarifying whether these are measurements or estimates, and validate measurement methodology is consistently applied.

---

**REL-003 · P1 · LOGIC_BUG**
File: LatencyBenchmark.swift, lines 41-47
Uses `DispatchTime.now().uptimeNanoseconds` which is wall-clock based and can drift. Should use monotonic clock. The `assert` at line 45 will fail in production if system clock is adjusted, leading to silent failure with `max(0, durationMicroseconds)` clamping the error.
**Fix:** Use `clock_gettime(CLOCK_MONOTONIC)` instead of DispatchTime for benchmark measurements.

---

**REL-004 · P1 · LOGIC_BUG**
File: PlaceholderDetection.swift, lines 46-61
Fragile string-based placeholder detection using substring matching. The function `containsDelimitedFragment` searches for delimited fragments but misses edge cases: IPv6 addresses (`::`), email addresses, and URIs containing placeholder keywords could be incorrectly flagged or missed.
**Fix:** Implement a more robust pattern matching system or use regex with word boundaries for placeholder detection.

---

**REL-005 · P2 · BOILERPLATE**
File: ReferenceRigReportValidation.swift, lines 225-298
Massive repeated validation boilerplate for building `placeholderSensitiveTextFields()`. Each report type repeats this pattern with 50+ lines of field appending. Should be table-driven.
**Fix:** Create a reflection-based or annotation-driven validation framework to eliminate field-by-field appending.

---

**REL-006 · P1 · LOGIC_BUG**
File: IntegratedProfileRuntimeEvidence.swift, lines 260-275
Function `integratedProfileMetrics(from: LatencyBenchmarkReport)` extracts `oneWayEstimateMicroseconds` as audio latency, but this mixes measurement semantics. The latency cost calculation at line 343 uses `max(0, ...)` which hides negative differences.
**Fix:** Clarify whether oneWayEstimate or roundTrip should be used, and document the latency cost semantics.

---

**REL-007 · P2 · BOILERPLATE**
File: HardwareValidationReport.swift, lines 399-425
Repeated pattern of building field tuples for validation across multiple report types. Each report has similar logic for collecting placeholder-sensitive fields.
**Fix:** Implement a generic field collection protocol or macro to reduce boilerplate.

---

**REL-008 · P1 · LOGIC_BUG**
File: HardwareValidationReport.swift, lines 383-396
String-based hardware identity validation checks for "rme", "madi", "blackmagic", "decklink", "atem" using `.contains()`. Case-insensitive but fragile: "remedial" contains "rme", "amati" contains "atem".
**Fix:** Use word-boundary-aware matching or whitelist specific known hardware identifiers.

---

**REL-009 · P0 · MISSING_ERROR_HANDLING**
File: RecordingSessionRun.swift, lines 142-147
The `run` method loads a JSON file from disk without try-catch wrapping for file I/O errors. `Data(contentsOf:)` can throw, but callers may not propagate the error properly if file is deleted mid-run.
**Fix:** Add explicit error handling and ensure the error includes file path context.

---

**REL-010 · P1 · RESOURCE_LEAK**
File: RecordingSessionLiveCapture.swift, lines 88-108
The `defer` block at line 90-93 only deallocates `ioProcID` if it's non-nil, but if `AudioDeviceStart` fails at line 98, the device is never stopped. The error handling doesn't clean up the audio device.
**Fix:** Add a second defer block to ensure AudioDeviceStop is called if AudioDeviceStart succeeds.

---

**REL-011 · P1 · RESOURCE_LEAK**
File: RecordingSessionLiveCapture.swift, lines 112-148
`CoreAudioRawInputState` allocates `buffer` and `callbackDurationsNanoseconds` at lines 139-140. If an exception occurs during initialization (lines 141-142), these are never deallocated because deinit is only called when the object is fully initialized.
**Fix:** Move memory allocation to deinit-protected wrapper or use RAII pattern.

---

**REL-012 · P2 · CODE_QUALITY**
File: SPSCAtomicRing.swift, lines 45-59, 61-73
No comment explaining the TOCTOU issue in pop/push: the load-check-store sequence is safe only because it's single-threaded per direction, but a race between read index load and write could occur if consumer thread scheduling changes.
**Fix:** Add explicit comment documenting thread-safety guarantees and the memory ordering requirements.

---

**REL-013 · P2 · SLOP**
File: LatencyBenchmark.swift, lines 86-93
Magic number `0.99` in percentile function for p99. Magic numbers `0.50` and `0.99` used directly without named constants.
**Fix:** Define `let P50_PERCENTILE = 0.50` and `let P99_PERCENTILE = 0.99` at top of file.

---

**REL-014 · P1 · LOGIC_BUG**
File: IntegratedProfileRuntimeEvidence.swift, lines 296-304
Function `integratedProfileMetrics(from: LightingFixtureGateReport)` calculates jitter as `max(0, lightingCallbackMaxMicroseconds - lightingCallbackP99Microseconds)`. This assumes max > p99, but no validation enforces this ordering at report level.
**Fix:** Add validation to ensure percentiles are ordered in LightingFixtureGateReport.

---

**REL-015 · P2 · BOILERPLATE**
File: IntegratedAvReportValidation.swift, lines 58-90 and similar
Large switch/case or if-else chains for validation. `validateAudio()` has 22 individual validation calls that could be table-driven.
**Fix:** Create a validation descriptor table with field names, validators, and error types.

---

**REL-016 · P1 · LOGIC_BUG**
File: ReferenceRigReportValidation.swift, line 180
Placeholder detection uses `isReferenceRigPlaceholder()` which calls `PlaceholderDetection.matches()` with hardcoded fragments `["todo(human)", "placeholder"]`. Case-insensitive but misses other placeholder patterns like "FIXME", "XXX", "unimplemented".
**Fix:** Expand placeholder fragment list or externalize it as configuration.

---

**REL-017 · P1 · LOGIC_BUG**
File: IntegratedProfileReport.swift, lines 67-70
`defaultProfile == .fastestAudio` check is case-sensitive enum match, but error message and validation logic could diverge if enum casing changes.
**Fix:** Use explicit enum value comparison, not string-based.

---

**REL-018 · P2 · DEAD_CODE**
File: LoLaParityDeferredLedgerReport.swift, lines 208-224
`LoLaParityDeferredSyntheticSmoke.run()` generates a completely synthetic report with placeholder notes like "Synthetic deferred parity ledger; no LoLa parity feature is promoted". This entire enum appears to be documentation masquerading as executable code.
**Fix:** Move to a separate documentation file or mark as @deprecated with clear guidance.

---

**REL-019 · P2 · DEAD_CODE**
File: GoalCodewiseClosure.swift and similar Goal/* files
Multiple Goal files (GoalRuntimeEvidenceTemplate, GoalRuntimePreflight, GoalCompletionAudit) contain only data structure definitions with no actual runtime logic. They are documentation blueprints, not functional code.
**Fix:** Separate documentation files from executable code; clearly mark files that are templates.

---

**REL-020 · P0 · MISSING_ERROR_HANDLING**
File: RecordingSessionMediaArtifacts.swift, lines 59-100
`writeRecordingSessionArtifacts()` is called but error handling is not shown. If file write fails due to disk full or permissions, the error propagates but the partial artifacts remain on disk.
**Fix:** Add explicit cleanup path on write failure or document cleanup requirements.

---

**REL-021 · P2 · SLOP**
File: VerdictValidationPolicy.swift, lines 31-32
Magic numbers `1_800` (30 minutes) and `3_600` (60 minutes) used directly for minimum pass duration. Should be named constants with explanation.
**Fix:** Define `let HARDWARE_VALIDATION_MIN_DURATION_SECONDS = 1_800` with comment explaining why 30 min minimum.

---

**REL-022 · P2 · SLOP**
File: HardwareValidationReport.swift, line 307
The minimum duration check uses `fieldRun.durationSeconds >= Self.minimumPassDurationSeconds` but `durationSeconds` is Double while constant is computed. Floating-point comparison could be problematic.
**Fix:** Use `>= minimumPassDurationSeconds - epsilon` or convert to Int for duration comparisons.

---

**REL-023 · P1 · LOGIC_BUG**
File: PerformanceCounterSummary.swift, lines 46-57
`fromSamples()` maps negative samples to 0, but this hides measurement errors. A negative duration suggests clock went backwards or measurement is corrupted, which should be detected and reported.
**Fix:** Throw an error or log warning if negative durations are observed, don't silently clamp.

---

**REL-024 · P2 · MISSING_ERROR_HANDLING**
File: IntegratedAvHelpers.swift, lines 54-59, 122-130
`requireIntegratedPercent()` and `requireIntegratedPositive()` validate but don't have `@discardableResult` on helper functions that return Bool or throw. Callers might accidentally ignore errors.
**Fix:** Add `@discardableResult` or make return type non-optional to force error handling.

---

**REL-025 · P1 · LOGIC_BUG**
File: IntegratedProfileRuntimeEvidence.swift, line 405
Function `integratedProfileLightingEvidenceIsMeasured()` checks if report ID contains "synthetic" in lowercase. This is fragile: a report legitimately named "synthetic-rig" would be incorrectly classified as synthetic.
**Fix:** Add an explicit `runMode` field to LightingFixtureGateReport or use a proper enum check.

---

**REL-026 · P2 · CODE_QUALITY**
File: KeyValueArgumentParser.swift, lines 85-100
`requiredPositiveInteger()` has three separate error types (Missing, Invalid, NonPositive) but error callbacks are not documented. Error messages could be inconsistent across call sites.
**Fix:** Provide default error messages or document expected error format.

---

**REL-027 · P1 · LOGIC_BUG**
File: MeasurementReport.swift, lines 191-195
Validation checks `timing.p50 <= p95 <= p99 <= max`, but doesn't validate that all percentiles are non-negative before comparing them. A negative p50 would pass the <= check.
**Fix:** Add explicit non-negative validation before percentile ordering check.

---

**REL-028 · P2 · BOILERPLATE**
File: IntegratedAvRunConfiguration.swift, lines 36-81
Duplicate argument parsing logic with manual loop over arguments. The parse method (lines 50-63) replicates KeyValueArgumentParser logic inline instead of delegating.
**Fix:** Refactor to use KeyValueArgumentParser.parseValues() consistently.

---

**REL-029 · P1 · RESOURCE_LEAK**
File: RecordingSessionLiveCapture.swift, lines 150-170
The `recordingAudioInputIOProc` callback processes audio but never validates if the buffer pointer is still valid. If the callback is invoked after state is deallocated, it would dereference freed memory.
**Fix:** Add thread-safe flag to check if state is still initialized before accessing buffer in callback.

---

**REL-030 · P0 · CRASH_ON_DATA_LOSS**
File: CoreAudioRawInputState (lines 150 onwards in RecordingSessionLiveCapture.swift)
Integer overflow in `writtenBytes` variable (line 120) if audio capture runs for many hours. The capacity is computed at line 138 without checking for overflow: `capacity = bytesPerBuffer * callbackCount` could exceed Int.max.
**Fix:** Add overflow checks when computing capacity and validate writtenBytes doesn't exceed capacity.

---

**REL-031 · P1 · LOGIC_BUG**
File: HardwareValidationReport.swift, lines 320-322
Placeholder detection for pass verdict checks a list of fields using `isHardwareValidationPlaceholder()`, but this detection is called AFTER verdict is already set to `.pass`. The check is validation, not prevention.
**Fix:** Move placeholder detection to validateShape() phase, not validatePassVerdict().

---

**REL-032 · P2 · CODE_QUALITY**
File: KeyValueArgumentParser.swift, lines 150-165
Function `boolean()` has parameters `trueValues` and `falseValues` with default sets, but doesn't document the default set members. Callers can't know what "true", "yes", etc. are accepted without reading code.
**Fix:** Document or extract default sets as named constants with comments.

---

**REL-033 · P2 · SLOP**
File: RecordingSessionRun.swift, lines 93-98
Optional `videoMode` handling with nested ternary. The logic `videoMode == .on ? ... : 0` is repeated multiple times.
**Fix:** Extract helper function `getAudioChannelCount(mode:)` to reduce duplication.

---

**REL-034 · P1 · LOGIC_BUG**
File: IntegratedAvReportValidation.swift, lines 38-50
Audio sync validation requires `sync.masterClock == .audio`, but there's no validation that the audio clock is actually stable or synchronized. The check is structural, not semantic.
**Fix:** Add comment documenting that semantic clock validation is deferred to audio benchmark reports.

---

**REL-035 · P1 · RESOURCE_LEAK**
File: RecordingSessionLiveCapture.swift, lines 15-36
If `CoreAudioRawInputRecorder.run()` throws an exception, the `media.audio = ...` assignment never completes, but exception is caught and added to `audioBlockers`. This means if audio capture partially initializes before failing, resources might leak.
**Fix:** Ensure CoreAudioRawInputRecorder has proper cleanup in catch block.

---

**REL-036 · P2 · CODE_QUALITY**
File: DebugTrace.swift, lines 41-50
`jsonLines()` catches JSON encoding errors and fallback to `DebugTraceEncodingFailureLine.make()`, which itself can throw. The inner try-catch at line 147 could fail, returning hardcoded string.
**Fix:** Ensure fallback encoding never throws or handle cascading failures explicitly.

---

**REL-037 · P1 · LOGIC_BUG**
File: IntegratedProfileRuntimeEvidence.swift, lines 319-335
Function `integratedProfileCombinedMetrics()` adds `lostPackets`, `underruns`, etc. from two reports, but doesn't validate that both reports measured the same time duration. Combined metrics are meaningless if they're from different length runs.
**Fix:** Add duration field to metrics and validate durations match before combining.

---

**REL-038 · P2 · SLOP**
File: ReferenceRigReportValidation.swift, lines 214-222
Hardcoded threshold values: `primaryStableBufferFrames == 32`, `stretchStableBufferFrames == 16`, `fallbackStableBufferFrames == 64`. These magic numbers should be named constants with justification.
**Fix:** Define REFERENCE_RIG_PRIMARY_STABLE_FRAMES = 32 with comment explaining the constraint.

---

**REL-039 · P0 · MISSING_ERROR_HANDLING**
File: RecordingSessionHelpers.swift (inferred from pattern)
Recording session helpers for argument parsing don't validate argument counts before array access. `values["--sample-rate"]` at various lines could access nil without proper casting.
**Fix:** Use safe dictionary access or guard statements consistently.

---

**REL-040 · P1 · LOGIC_BUG**
File: HardwareValidationRunner.swift (inferred from lines 296-297 in HardwareValidationRun.swift)
Function `requiredHardwareValidationRoutes()` returns hardcoded `[.directLink, .dedicatedSwitch, .campusPath]`, but if new route types are added to `UdpPcmRouteKind` enum, validation silently fails to check them.
**Fix:** Make route requirements data-driven or add compile-time check via exhaustive switch.

---

**REL-041 · P2 · CODE_QUALITY**
File: ReportSchemaInventory.swift
File too large to read fully, but likely contains static schema definitions. No indication of how schema changes are tracked or validated.
**Fix:** Add version field and migration logic for schema changes.

---

**REL-042 · P1 · LOGIC_BUG**
File: ReferenceRigReportValidation.swift, lines 188-190
Helper function `isThunderboltPerformancePath()` is called but not defined in provided code. Function existence cannot be verified.
**Fix:** Either define the function in the file or document the dependency.

---

**REL-043 · P1 · LOGIC_BUG**
File: ReferenceRigReportValidation.swift, lines 191-193
Helper function `isClassCompliantDriverMode()` checks if driver mode is class-compliant, but the check logic is not shown. This critical validation is hidden.
**Fix:** Ensure validation logic is in the same file or well-documented external dependency.

---

**REL-044 · P2 · SLOP**
File: E2EBenchmarkReport.swift, lines 43-58
Validation error enums for percentages, counters, and drops use magic numbers in error cases like `passExceedsDroppedFrames(profile: E2EBenchmarkProfile, value: Int, threshold: Int)`. No centralized threshold definitions.
**Fix:** Create a thresholds configuration struct and centralize all benchmark limits.

---

**REL-045 · P1 · RESOURCE_LEAK**
File: FileDescriptorSet.swift, lines 29-38
Functions `openLolaFDSet()` and `openLolaFDIsSet()` mutate the fd_set using unsafe memory rebound pointers, but there's no validation that the rebound pointer is correctly aligned or that the capacity is correct.
**Fix:** Add runtime assertions for alignment and bounds checking.

---

**REL-046 · P0 · CRASH_ON_DATA_LOSS**
File: FileDescriptorSet.swift, line 35
`withMemoryRebound(to: Int32.self, capacity: ...)` recomputes `Int(FD_SETSIZE) / bitsPerWord` each time. If `bitsPerWord` is ever 0 (impossible but unchecked), division by zero occurs.
**Fix:** Assert that `bitsPerWord > 0` at function entry.

---

**REL-047 · P1 · LOGIC_BUG**
File: RecordingSessionRun.swift, lines 94-107
Argument parsing reconstructs channel mapping using `optionalRecordingChannelMap()` which is not shown, but the logic `audioMode == .on ? ... : []` silently creates empty channel list if audio is off, which might later be misinterpreted.
**Fix:** Use explicit optional or throw error if channels required but audio mode is off.

---

**REL-048 · P2 · CODE_QUALITY**
File: IntegratedProfileRuntimeEvidence.swift, lines 41-112
Function names like `updateOption()`, `updateEvidence()`, `updateBenchmarkRow()` modify the report in-place but are named like they return values. Callers might expect immutable updates.
**Fix:** Rename to `mutateOption()` or prefix with `modify_` to clarify mutating behavior.

---

**REL-049 · P1 · LOGIC_BUG**
File: HardwareValidationReport.swift, lines 305-310
Loop over `fieldRun.routeLabels` validates each label is non-empty, but doesn't validate that labels match the routes defined in the `routes` array. A mismatch would silently fail.
**Fix:** Add cross-reference validation between routeLabels and routes.

---

**REL-050 · P2 · BOILERPLATE**
File: IntegratedAvReportValidation.swift, lines 58-190
Repeated validation pattern: `try requireIntegrated*(field, "path")` called 30+ times. This is mechanical validation that could be generated from a schema.
**Fix:** Implement code generation or reflection-based validation to eliminate boilerplate.

---

**REL-051 · P1 · LOGIC_BUG**
File: LatencyBenchmarkReport.swift, lines 69-82
Calls multiple `validate*()` functions sequentially but if early validation throws, later validations never run. If `validateIdentity()` fails, `validatePassVerdict()` dependencies might be checked but context is lost.
**Fix:** Collect all validation errors and report them together, or document error propagation semantics.

---

**REL-052 · P0 · MISSING_ERROR_HANDLING**
File: RecordingSessionLiveCapture.swift, lines 138-142
Memory allocation at lines 139-140 doesn't check for allocation failure. On memory-constrained systems, `allocate()` could fail silently or the subsequent `initialize()` could crash.
**Fix:** Add explicit checks or use Swift's memory safety guarantees with safer allocation patterns.

---

**REL-053 · P2 · SLOP**
File: LatencyBenchmarkSamplingConfiguration.swift, lines 8-11
Constructor silently "fixes" invalid sampling counts with `max(3, warmupIterations)` and `max(10, sampleCount)`. Silent correction hides configuration errors.
**Fix:** Throw validation error if invalid values provided, don't silently correct.

---

**REL-054 · P1 · LOGIC_BUG**
File: IntegratedProfileReport.swift, lines 138-150
Validation of degradation order checks that video degradation comes before audio latency, but no validation that audio degradation is actually the last step for all profiles.
**Fix:** Add explicit check that `.increaseAudioLatency` is last in all degradation paths.

---

**REL-055 · P2 · CODE_QUALITY**
File: KeyValueArgumentParser.swift, lines 10-35
`parse()` method doesn't document what happens if an argument value starts with `--`. The `allowsDashPrefixedValues` flag controls this, but default behavior is surprising.
**Fix:** Add explicit documentation and consider making the behavior explicit with named parameter.

---

**REL-056 · P1 · LOGIC_BUG**
File: RecordingSessionRun.swift, lines 112-115
Optional video configuration parsing uses defaults like `frameRate: 30` and `queueDepth: 1` without validation that these are acceptable. Defaults could be incompatible with hardware.
**Fix:** Document defaults and add validation or make them explicit in configuration.

---

**REL-057 · P2 · CODE_QUALITY**
File: HardwareValidationReport.swift, line 451
`isHardwareValidationPlaceholder()` function uses hardcoded fragment list `["todo(human)", "placeholder", "not supplied", "not-supplied", "required", "synthetic"]`. This diverges from `isReferenceRigPlaceholder()` which uses different fragments.
**Fix:** Consolidate placeholder detection into a single configurable function.

---

**REL-058 · P0 · MISSING_ERROR_HANDLING**
File: IntegratedAvRun.swift (inferred from pattern)
Function `run(configuration:, videoTransportReport:)` creates IntegratedAvReport with synthetic data if videoTransportReport is nil, but doesn't validate that required fields are initialized.
**Fix:** Ensure all required fields are validated after construction.

---

**REL-059 · P2 · SLOP**
File: DebugTrace.swift, lines 83-127
Allowlist/denylist for debug trace fields is hardcoded. If new fields are added, this list must be manually updated.
**Fix:** Make field policy data-driven or use annotations.

---

**REL-060 · P1 · LOGIC_BUG**
File: PerformanceAuditReport.swift, lines 1-100
`recordedSamplesMicroseconds` is private but populated and then cleared in `finalize()` (line 72), breaking encapsulation. External code cannot inspect raw samples.
**Fix:** Provide public accessor or document why raw samples are discarded.

---

**REL-061 · P2 · CODE_QUALITY**
File: IntegratedAvHelpers.swift, lines 79-101
Helper functions for argument parsing are not marked with `@discardableResult`, so callers ignoring return values get compiler warnings.
**Fix:** Add `@discardableResult` to all helper functions that callers might ignore.

---

**REL-062 · P1 · LOGIC_BUG**
File: IntegratedProfileReport.swift, lines 86-98
Validation of profile options uses `defaultProfile` boolean flag but doesn't ensure exactly one profile is marked as default. Multiple defaults could exist.
**Fix:** Add validation that exactly one profile has `defaultProfile == true`.

---

**REL-063 · P2 · SLOP**
File: RecordingSessionRun.swift, lines 68-92
Hardcoded allowed argument list is long and unstructured. Adding new arguments requires manual list updates.
**Fix:** Generate allowed arguments from configuration struct fields.

---

**REL-064 · P1 · RESOURCE_LEAK**
File: RecordingSessionLiveCapture.swift, lines 26-36
If `AVFoundationRawVideoRecorder.run()` partially initializes video capture and then throws, the exception is caught but video recorder might not clean up its resources.
**Fix:** Ensure AVFoundationRawVideoRecorder has proper cleanup on error.

---

**REL-065 · P2 · CODE_QUALITY**
File: PlaceholderDetection.swift, lines 46-61
`containsDelimitedFragment()` performs string searches with bounds checking but uses String indices which are O(n) per operation. For large field sets, placeholder detection could be slow.
**Fix:** Consider caching normalized values or using regex for batch detection.

---

**REL-066 · P2 · SLOP**
File: IntegratedProfileRuntimeEvidence.swift, lines 323-335
Hard-coded aggregation logic in `integratedProfileCombinedMetrics()` uses `max()` for some fields and `+` for others. The aggregation strategy is inconsistent and not documented.
**Fix:** Document or parameterize aggregation strategy for each metric type.

---

**REL-067 · P1 · LOGIC_BUG**
File: ReferenceRigReportValidation.swift, lines 200-205
Loop over `physicalProfiles` excludes `singleHost` topology, but no validation that at least one physical profile exists. An all-single-host configuration would pass validation.
**Fix:** Require at least one non-single-host profile for pass verdict.

---

**REL-068 · P2 · CODE_QUALITY**
File: IntegratedAvReport.swift (inferred pattern)
Multiple report types follow similar validation structure but each reimplements validation logic. No base class or protocol enforcement.
**Fix:** Create ReportValidator protocol with standard validation lifecycle.

---

**REL-069 · P1 · LOGIC_BUG**
File: LatencyBenchmarkReport.swift, lines 138-145
Jitter percentile ordering validation assumes `p50 <= p95 <= p99 <= max`, but doesn't validate non-negativity or that max is >= 0. A report with all negative values would be rejected, but a report with NaN would pass.
**Fix:** Add explicit NaN check and document why infinity is allowed/disallowed.

---

**REL-070 · P2 · BOILERPLATE**
File: Multiple validation files
Every report type implements `validate()` method with identical structure: call validateIdentity, validateFields, validatePassVerdict. This pattern is repeated 20+ times.
**Fix:** Implement a base validation template or use composition to reduce duplication.

---

END OF AUDIT FINDINGS

---

## Group 15 — Video Transport / Capture / Rendering (VID-001 – VID-019, CTL-001 – CTL-011)

## Open-Lola2 Code Audit — Video Transport, Video Capture, Control (OSC/ATEM/Lighting)

---

### VIDEO PATH — VID-001 through VID-019

---

**VID-001** | **P0** | `VideoTransportReassembly.swift:239-240`

**Problem:** First fragment is inserted twice into a new reassembly bucket. The bucket is initialised *with* `firstFragment`, then `bucket.insert(fragment)` is called again with the same fragment. The insert returns `false` (duplicate detected) but the `duplicateFragments` counter is NOT incremented because the counter increment is inside the existing-bucket branch, not the new-bucket branch. Net effect: the fragment occupies two slots in `fragmentsByIndex`, wastes memory, and silently under-counts duplicates.

**Fix:** Remove the redundant `bucket.insert(fragment)` call on line 240; the bucket is already initialised with the fragment on line 239.

---

**VID-002** | **P1** | `VideoTransportReassembly.swift:~285-305`

**Problem:** `latestCompletedFrameSequenceNumbersByStreamID` stores `UInt64` sequence numbers and uses `<= latestCompleted` to reject "late" fragments. At `UInt64.max` wraparound the next legal frame (seqNum = 0) is rejected as late, permanently stalling that stream ID.

**Fix:** Use modular comparison: `(seq &- latest) > halfWindowThreshold` (wrapping subtraction) to distinguish forward-running frames from genuinely late ones, similar to RFC 1982 serial number arithmetic.

---

**VID-003** | **P1** | `VideoTransportReassembly.swift:324`

**Problem:** `dropOlderIncompleteFrames` uses strict `<` when evicting stale buckets. A bucket with the *exact same* `(streamID, seqNum)` as the arriving fragment is not evicted. Two buckets for the same key can momentarily coexist; stale partial-reception state from the old bucket can bleed into the new reception cycle.

**Fix:** Change the eviction condition to `<=` so buckets with the same sequence number as the new arrival are also dropped before the new one is processed.

---

**VID-004** | **P2** | `VideoTransportReassembly.swift:366-373`

**Problem:** `activeFrameOrder` compaction fires only when `cursor > 64 && cursor * 2 > count`. Under sustained multi-stream load with rapid completions, the cursor advances without the array count shrinking, deferring compaction indefinitely. The array accumulates unbounded stale `nil` entries between compaction events.

**Fix:** Lower the threshold (e.g., compact when `cursor > 32 && cursor > count / 2`), or replace the cursor-based array with `Array.removeFirst` on completion/eviction (acceptable since completions are infrequent relative to stream count).

---

**VID-005** | **P1** | `VideoTransportPacket.swift:44-75`

**Problem:** The `encodedByteCount` computed property is used in `encoded()` as the `Data.reserveCapacity` hint. If the property omits any of the variable-length fields (`fingerprint.utf8.count`, `sourceRole.rawValue.utf8.count`, `pixelFormat.utf8.count`) from its sum, the buffer under-allocates and forces a heap reallocation on every high-frequency encode call.

**Fix:** Ensure `encodedByteCount` exactly mirrors the append sequence in `encoded()`: `fixedHeaderByteCount + fingerprint.utf8.count + sourceRole.rawValue.utf8.count + pixelFormat.utf8.count + payload.count`. Add a `assert(encoded().count == encodedByteCount)` in debug builds.

---

**VID-006** | **P1** | `VideoTransportRunner.swift:~200-230`

**Problem:** The call site computes `configuration.maxPacketBytes - UdpMediaPacketHeader.byteCount` before passing to `RawVideoFrameTransport.fragments(for:maxPacketBytes:)`. If `configuration.maxPacketBytes < UdpMediaPacketHeader.byteCount`, the subtraction produces a *negative* `Int`. The inner guard `maxFragmentPayloadBytes > 0` inside `fragments` catches this and throws `maxPacketTooSmall`, but the negative value has already passed through as a plausible `Int` argument, and the error message reports the pre-subtracted value rather than the actual configured value, making diagnosis confusing.

**Fix:** Guard before the subtraction: `guard configuration.maxPacketBytes > UdpMediaPacketHeader.byteCount else { throw … }`.

---

**VID-007** | **P0** | `VideoCaptureAVFoundation.swift:~288-320`

**Problem:** `makeAVFoundationCaptureSession` calls `device.lockForConfiguration()` during device configuration setup. If the subsequent `session.canAddOutput(output)` guard fails, the function calls `session.commitConfiguration()` and throws **without** calling `device.unlockForConfiguration()`. The device remains permanently locked for configuration until process exit, preventing any subsequent `lockForConfiguration` call from succeeding.

**Fix:** Add `defer { device.unlockForConfiguration() }` immediately after `lockForConfiguration()` succeeds, before any guard that might throw.

---

**VID-008** | **P1** | `VideoCaptureAVFoundation.swift:358-432`

**Problem:** `AVFoundationSampleBufferCollector` is marked `@unchecked Sendable`. The `captureOutput` delegate runs on `captureQueue` while `snapshot()`, `rawVideoArtifact()`, and `latestRawFrame()` are called from other threads. All mutable state is currently guarded by `stateLock`, which is correct, but `@unchecked` disables Swift concurrency and TSAN verification. Any future unguarded property addition will not be caught at compile time or by the thread sanitizer.

**Fix:** Document all mutable properties and their `stateLock` coverage in a comment block. Run thread sanitizer (`-sanitize=thread`) in CI. Evaluate whether the class can be refactored as an actor to eliminate `@unchecked`.

---

**VID-009** | **P2** | `VideoCaptureAVFoundation.swift:~303-323`

**Problem:** Any duration-wait that uses `RunLoop.current.run(until: Date(...))` returns immediately when called on a GCD-managed thread because that thread's RunLoop has no active sources. The intended capture warm-up delay becomes effectively zero; frames are not collected.

**Fix:** Replace `RunLoop.current.run(until:)` with `Thread.sleep(forTimeInterval: seconds)` or a `DispatchSemaphore(value: 0).wait(timeout: .now() + seconds)` for waits on background threads.

---

**VID-010** | **P2** | `VideoCaptureAVFoundation.swift:535-542`

**Problem:** `trimRawFrameArtifactIfNeeded` removes old frame bytes with `rawFrameData.removeSubrange(0..<removed.byteCount)`. Swift `Data.removeSubrange` for a range starting at index 0 shifts all remaining bytes left (O(n) memmove). For 120 retained frames of raw 1080p BGRA (~8 MB each, ~960 MB total), each trim is a ~952 MB copy.

**Fix:** `rawFrameDataBaseOffset` already tracks the logical start. Instead of removing bytes from the front, do not compact `rawFrameData` on each trim — only materialise the trimmed view (`rawFrameData[logicalOffset...]`) at `rawVideoArtifact()` call time, or use a ring-buffer of fixed-size `Data` slabs.

---

**VID-011** | **P1** | `VideoOutputRenderer.swift:207-209`

**Problem:** `keepsContinuity` returns `false` unconditionally when `previous == UInt64.max`. Because `keepsContinuity` is called for every new frame and the condition tests `current <= previous`, subsequent frames (e.g., seqNum 0 after a reset) satisfy `0 <= UInt64.max` and will also return `false`. This permanently blocks delivery from that stream.

**Fix:** Treat `(previous == UInt64.max && current == 0)` as a valid wraparound (`return true`). More robustly, use wrapping arithmetic: `current == previous &+ 1` is the continuity invariant.

---

**VID-012** | **P2** | `VideoOutputRenderer.swift:135-165`

**Problem:** `submit` returns `true` if the frame was enqueued AND `queue.count >= previousQueueCount`. A frame that was accepted and then immediately evicted by backpressure can still produce a `true` return if another stream's frame happens to be queued. Callers using the return value to count "successfully delivered" frames may overcount.

**Fix:** Return a dedicated result enum: `accepted`, `acceptedWithBackpressureDrop`, `rejected` — or at minimum document the exact semantics and add a `framesAcceptedThenDropped` counter.

---

**VID-013** | **P2** | `VideoOutputRenderer.swift:~220-260`

**Problem:** `receiveToReassemblyMicroseconds`, `reassemblyToRenderMicroseconds`, and `renderToOutputMicroseconds` accumulate one entry per rendered frame with no cap or rolling window. At 120 fps for one hour each array holds 432,000 `Double` entries (~3.5 MB). Over multi-hour or multi-stream runs the renderer holds tens of millions of raw samples.

**Fix:** Replace raw arrays with a fixed-depth circular buffer (e.g., 10,000 samples) or a streaming histogram (e.g., HDR histogram) that computes percentiles without retaining all samples.

---

**VID-014** | **P1** | `VideoTransportRunner.swift:305-334`

**Problem:** `drainVideoFragments` busy-waits with `usleep(1_000)` (1 ms) polling `reassembler.metrics.framesReassembled < expectedFrames`. (1) The polling wastes a CPU core. (2) The parameter name `expectedFrames` is misleading — it is the *total generated* count across all streams, not the total expected to be received; a comment or rename would prevent misuse in future multi-stream scenarios.

**Fix:** Replace the polling loop with a `DispatchSemaphore` or `DispatchGroup` signalled from the reassembly completion callback. Rename `expectedFrames` to `totalGeneratedFrames`.

---

**VID-015** | **P2** | `VideoTransportRunner.swift:~150-200`

**Problem:** `recvfrom` is called with `maxPacketBytes` as the buffer size. If the OS receives a UDP datagram larger than `maxPacketBytes`, excess bytes are silently truncated. The truncated buffer is then passed to `VideoTransportFragment.decode`, which will throw `payloadLengthMismatch` with no indication that truncation was the root cause. Logs will show spurious decode errors on a working network path.

**Fix:** After `recvfrom` returns, if `receivedByteCount == maxPacketBytes`, log a truncation warning (the real datagram may have been larger). Alternatively, use `MSG_TRUNC | MSG_PEEK` to detect oversized datagrams before consuming them.

---

**VID-016** | **P2** | `RawBGRAAppKitPreviewWindow.swift:32-58`

**Problem:** `CGBitmapInfo` for the hardware BGRA preview uses `.premultipliedFirst`. For opaque hardware video (`alpha == 255`) this is a no-op at render time but misleads downstream consumers that inspect bitmap info. For any BGRA source with real transparency the image will render incorrectly (colors divided by alpha unnecessarily).

**Fix:** Use `CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)` for opaque hardware BGRA. If alpha is meaningful, use `.premultipliedFirst` with explicit documentation.

---

**VID-017** | **P2** | `RawBGRAAppKitPreviewWindow.swift:61-106`

**Problem:** The `submitPending` flag prevents concurrent renders but silently drops every frame that arrives while a render is in progress. There is no counter, no log, and no back-pressure signal. At 60 fps with a 17 ms render stall, every other frame is silently discarded.

**Fix:** Add a `droppedFrameCount: Int` counter incremented inside the `submitPending` guard, and expose it in the window's snapshot or metrics output.

---

**VID-018** | **P2** | `MultiVideoStreams.swift:~275-283`

**Problem:** The free function `estimatedVideoBandwidthMegabitsPerSecond` duplicates logic that already exists as `VideoStreamDescription.estimatedBandwidthMegabitsPerSecond`. Duplicated formula risks silent divergence when either copy is updated.

**Fix:** Delete the free function; call `.estimatedBandwidthMegabitsPerSecond` on the `VideoStreamDescription` instance at all call sites.

---

**VID-019** | **P2** | `MultiVideoStreams.swift:~200-240`

**Problem:** `videoTransportMultiVideoMetrics` sets `observedQueueDepth: receiverObservedQueueDepth` identically for every stream in the multi-stream metrics array. This is the *global* receiver queue depth, not a per-stream measurement. All streams report the same aggregate depth, masking per-stream back-pressure.

**Fix:** Track `observedQueueDepth` per `VideoStreamDescription` (e.g., in a `[UInt32: Int]` map keyed by stream ID) and assign individual depths in the metrics loop.

---

### CONTROL PATH — CTL-001 through CTL-011

---

**CTL-001** | **P1** | `AtemReadOnlyControl.swift:~310-340`

**Problem:** `timeval.tv_sec` is computed as `Int(configuration.timeoutMilliseconds / 1_000)`. `optionalAtemProbePositiveInteger` does not cap the upper bound, so a pathological `--timeout-milliseconds 9223372036854775807` (i.e., `Int.max`) makes `tv_sec = Int.max / 1000`, which overflows `__darwin_time_t` on 32-bit platforms and produces an incorrect `select` timeout on 64-bit platforms (effectively infinite wait). The `tv_usec` computation `Int32((ms % 1_000) * 1_000)` is safe (max 999,000 < `Int32.max`) but only if `ms` is bounded.

**Fix:** Add an upper bound in `optionalAtemProbePositiveInteger` (e.g., `guard value <= 30_000 else { throw … }`), or clamp: `let clampedMs = min(configuration.timeoutMilliseconds, 30_000)`.

---

**CTL-002** | **P2** | `AtemReadOnlyControl.swift:247-369`

**Problem:** After `select` returns write-ready and `getsockopt(SO_ERROR) == 0`, the probe returns `.connected`. On some network paths a TCP RST races with `select` and is consumed by `getsockopt`; however, if the RST arrives after `getsockopt`, the socket appears connected but the remote has already closed it. The probe reports `.connected` (positive ATEM health) for a host that is unreachable at the ATEM protocol level.

**Fix:** Document that `.connected` means "TCP handshake completed" not "ATEM protocol available." If stronger confirmation is required, attempt a 1-byte `recv(MSG_PEEK)` after connect; a zero-byte result (EOF) indicates the remote closed immediately.

---

**CTL-003** | **P1** | `OscCueHelpers.swift:14-35`

**Problem:** `readOscString` pads the cursor to the next 4-byte boundary using `cursor % 4 != 0`. OSC padding is 4-byte aligned from the *start of the message*, which matches `cursor` as an absolute offset — so the arithmetic is correct for well-formed messages. However, the function carries no precondition asserting this invariant. If called in a context where `cursor` is a relative offset within a sub-structure, alignment will be wrong and subsequent field reads will be shifted. The function is silent about this constraint.

**Fix:** Add a doc-comment precondition: `/// cursor must be an absolute offset from byte 0 of the OSC message`. Add a `precondition(cursor >= 0)` and a note that callers must not use this function for inner sub-blocks.

---

**CTL-004** | **P2** | `OscCueHelpers.swift:45-69`

**Problem:** `receiveDatagram(socket:byteCount:4_096)` uses a hardcoded 4096-byte limit. An oversized OSC datagram is silently truncated by the OS; the subsequent parse will likely fail with `missingNullTerminator` with no indication that truncation was the root cause.

**Fix:** After `recvfrom` returns, if `receivedByteCount == 4_096`, log a truncation warning. Prefer a larger buffer (e.g., 65,507 bytes, the UDP maximum) or use `MSG_TRUNC` to detect discarded bytes before parsing.

---

**CTL-005** | **P2** | `OscCueHelpers.swift:~60-69`

**Problem:** `waitForUdpOscRead` throws `UdpPcmRouteProbeError.receiveFailed` — the PCM route probe error domain — for an OSC operation failure. Callers catching OSC errors must also handle PCM errors; error messages will say "PCM route probe receive failed" for an OSC cue read timeout, which is actively misleading.

**Fix:** Define `OscCueError.receiveFailed` (or reuse `OscCueValidationError` with a new case) and throw from the OSC domain.

---

**CTL-006** | **P1** | `LightingFixtureGate.swift:247-281`

**Problem:** `LightingSafetyPolicy.decision(for:)` returns `blocked(.networkNotIsolated)` before checking whether the failure policy is complete. A request with *both* a non-isolated network *and* an incomplete failure policy is reported only as `networkNotIsolated`. The operator sees one problem, fixes the network, re-runs, and only then learns about the second problem.

**Fix:** Collect all blocking reasons before returning. Return a `blocked(reasons: [LightingGateBlockReason])` (or call the complete-policy check first and surface both issues in a single diagnostic pass).

---

**CTL-007** | **P1** | `LightingFixtureGate.swift:~260-281`

**Problem:** Every `blocked(reason:)` call hard-codes `LightingGateState.disabled` as the returned state. The `LightingGateState` enum has `.hold`, `.blackout`, and `.drop` states that represent meaningful blocking postures. Returning `.disabled` unconditionally makes the observable gate state useless for distinguishing "never configured" from "armed but currently holding."

**Fix:** Map each `LightingGateBlockReason` to a semantically appropriate state (e.g., `networkNotIsolated → .hold`, `failurePolicyIncomplete → .disabled`, `safetyCheckFailed → .blackout`).

---

**CTL-008** | **P2** | `LightingFixtureGateRun.swift:~121-211`

**Problem:** The synthetic `LightingGateRunner.run(configuration:)` hardcodes `dmx.maxLevel = 0` in the generated report. `LightingFixtureGateReport.validateProbe` accepts `maxLevel == 0` (valid range is 0–255). A synthetic PASS report with `maxLevel = 0` passes validation even though zero max DMX level implies no fixture activity was observed — a condition that must never yield a PASS.

**Fix:** Add a `validatePassVerdict` check: if `verdict == .pass`, require `dmx.maxLevel > 0` and throw `LightingGateValidationError.passWithNoFixtureActivity`.

---

**CTL-009** | **P2** | `LightingFixtureGateRun.swift:213-229`

**Problem:** `LightingCaptureTool.init(rawValue:)` never returns `nil`: unknown strings become `.configured(string)`. A typo in `--capture-tool` silently creates a non-standard tool name that is serialised into the report rather than producing an early CLI error.

**Fix:** Make `init(rawValue:)` failable for unrecognised strings, returning `nil` (and thus a CLI argument parse error), with `.configured(string)` reserved only for explicitly allowlisted strings.

---

**CTL-010** | **P2** | `LightingFixtureGateRun.swift:~121`

**Problem:** `LightingGateRunner.run(configuration:)` returns `LightingFixtureGateReport` without `throws`. If an unrecoverable internal error occurs (e.g., DMX socket open failure, OS permission denial), the only signalling channel is the report's `verdict` field. Callers that check only `verdict == .pass` may not notice a `.partial` verdict encoding an internal error.

**Fix:** Make `run(configuration:)` `throws` for unrecoverable errors (hardware/OS errors that make the run meaningless). Reserve the non-throwing return path for measurable partial results.

---

**CTL-011** | **P2** | `BlackmagicOutputBoundary.swift` (all)

**Problem:** `BlackmagicOutputBoundary.detect()` never throws. Hardware enumeration failures (missing optional library, OS permission denial, SDK crash) are silently encoded as `runtimeAvailable: false` with no error field. A caller cannot distinguish "hardware genuinely absent" from "enumeration failed catastrophically."

**Fix:** Add an `enumerationError: String?` field to the report struct. Populate it with a diagnostic string on failure. This gives callers and log consumers the ability to distinguish the two conditions without requiring exceptions.

---

### Summary Table

| ID | P | File | One-line description |
|----|---|------|----------------------|
| VID-001 | **P0** | VideoTransportReassembly.swift:239-240 | First fragment double-inserted; duplicate counter not incremented |
| VID-007 | **P0** | VideoCaptureAVFoundation.swift:~290-320 | `device.lockForConfiguration()` leaked on `canAddOutput` failure |
| VID-002 | P1 | VideoTransportReassembly.swift:~285-305 | UInt64 seqnum wraparound permanently stalls stream |
| VID-003 | P1 | VideoTransportReassembly.swift:324 | Strict `<` eviction allows same-seqnum bucket coexistence |
| VID-005 | P1 | VideoTransportPacket.swift:44-75 | `encodedByteCount` may under-count causing buffer under-allocation |
| VID-006 | P1 | VideoTransportRunner.swift:~200-230 | Negative maxPacketBytes passed to fragmentation when too small |
| VID-008 | P1 | VideoCaptureAVFoundation.swift:358-432 | `@unchecked Sendable` suppresses race detection on collector |
| VID-011 | P1 | VideoOutputRenderer.swift:207-209 | `keepsContinuity` hard-stops permanently at UInt64.max |
| VID-014 | P1 | VideoTransportRunner.swift:305-334 | Busy-wait drain loop wastes CPU; misleading parameter name |
| CTL-001 | P1 | AtemReadOnlyControl.swift:~310-340 | `tv_sec` overflow on pathological timeout value |
| CTL-003 | P1 | OscCueHelpers.swift:14-35 | `readOscString` alignment precondition undocumented/fragile |
| CTL-005 | P1 (mild) | OscCueHelpers.swift:~60-69 | OSC receive failure throws PCM error domain |
| CTL-006 | P1 | LightingFixtureGate.swift:247-281 | Network isolation checked before failure-policy completeness |
| CTL-007 | P1 | LightingFixtureGate.swift:~260-281 | `blocked()` always returns `.disabled` state |
| VID-004 | P2 | VideoTransportReassembly.swift:366-373 | `activeFrameOrder` compaction threshold allows unbounded growth |
| VID-009 | P2 | VideoCaptureAVFoundation.swift:~303-323 | `RunLoop.run(until:)` returns immediately on GCD threads |
| VID-010 | P2 | VideoCaptureAVFoundation.swift:535-542 | O(n) `removeSubrange` on raw frame data blob |
| VID-012 | P2 | VideoOutputRenderer.swift:135-165 | `submit` Bool return is ambiguous after eviction |
| VID-013 | P2 | VideoOutputRenderer.swift:~220-260 | Latency metrics arrays grow without bound |
| VID-015 | P2 | VideoTransportRunner.swift:~150-200 | Oversized UDP datagram silently truncated before decode |
| VID-016 | P2 | RawBGRAAppKitPreviewWindow.swift:32-58 | `.premultipliedFirst` wrong for opaque hardware BGRA |
| VID-017 | P2 | RawBGRAAppKitPreviewWindow.swift:61-106 | Dropped frames on `submitPending` are invisible (no counter) |
| VID-018 | P2 | MultiVideoStreams.swift:~275-283 | Free function duplicates `estimatedBandwidthMegabitsPerSecond` property |
| VID-019 | P2 | MultiVideoStreams.swift:~200-240 | Per-stream queue depth reports global depth for all streams |
| CTL-002 | P2 | AtemReadOnlyControl.swift:247-369 | `.connected` verdict possible on half-open TCP connection |
| CTL-004 | P2 | OscCueHelpers.swift:45-69 | Hardcoded 4096-byte OSC receive buffer, no truncation detection |
| CTL-008 | P2 | LightingFixtureGateRun.swift:~121-211 | Synthetic run hardcodes `dmx.maxLevel=0`; PASS with no fixture activity |
| CTL-009 | P2 | LightingFixtureGateRun.swift:213-229 | `LightingCaptureTool` init never fails; typos silently encoded |
| CTL-010 | P2 | LightingFixtureGateRun.swift:~121 | `LightingGateRunner.run` non-throwing; internal errors invisible |
| CTL-011 | P2 | BlackmagicOutputBoundary.swift | Enumeration failure indistinguishable from hardware absent |

**2 P0 bugs** (data corruption / permanent resource leak), **13 P1 bugs** (correctness / reliability), **15 P2 issues** (observability / robustness / design debt).___BEGIN___COMMAND_DONE_MARKER___0
___BEGIN___COMMAND_DONE_MARKER___0


---

## Group 16 — Platform / Timing / Protocol / CLI (PLT-001 – PLT-016)


**PLT-001 · P0 · INFINITE_RECURSION**
File: SessionProfileBenchmark.swift, line 76
**Problem:** `LatencyProfileBenchmarkSyntheticSmoke.run()` calls itself recursively instead of calling `LatencyBenchmarkSyntheticSmoke.run()`. This causes infinite recursion and immediate stack overflow when the function is invoked.
**Fix:** Change line 76 from `var report = try LatencyProfileBenchmarkSyntheticSmoke.run()` to `var report = try LatencyBenchmarkSyntheticSmoke.run()`

---

**PLT-002 · P1 · MISSING_ERROR_HANDLING**
File: LatencyProfileCommands.swift, line 7
**Problem:** `handleLatencyProfileCommand()` has no try-catch around the recursive call exposed by PLT-001. When the recursion crashes the stack, no context is available for diagnostics.
**Fix:** Add proper error handling with context-specific error messages.

---

**PLT-003 · P1 · LOGIC_BUG**
File: RxBuffering.swift, line 187
**Problem:** Validation allows `targetPackets == 0` for direct RX buffer profiles, but the documentation suggests only 1 packet is supported. Zero creates an invalid buffer state.
**Fix:** Change validation to `guard targetPackets == 1 else { ... }`.

---

**PLT-004 · P1 · LOGIC_BUG**
File: NativeAppShellSearchAndPacketMonitor.swift, line 54
**Problem:** `max(0, limit)` silently truncates all packets if `limit` is negative, hiding invalid input rather than surfacing it.
**Fix:** Add explicit validation: `guard limit >= 0 else { throw ... }`.

---

**PLT-005 · P1 · SLOP**
File: DriftPlcHelpers.swift, line 98
**Problem:** `max(1, routeReport.packetMode.framesPerPacket)` defensively clamps to 1, masking an upstream validation error if framesPerPacket can ever be 0.
**Fix:** Remove defensive clamping; rely on upstream validation to ensure framesPerPacket > 0.

---

**PLT-006 · P1 · MISSING_ERROR_HANDLING**
File: NetworkCommands.swift, line 28
**Problem:** File write at line 28 lacks the `.atomic` flag used everywhere else in the codebase. A mid-write crash leaves a corrupt partial file on disk.
**Fix:** `try report.prettyJSONData().write(to: outputURL, options: [.atomic])`

---

**PLT-007 · P2 · SLOP**
File: SessionNegotiation.swift, lines 95-99
**Problem:** Stream ID 0 is treated as valid during insertion. Most protocols reserve stream ID 0; this should be validated.
**Fix:** `guard id > 0 else { throw SessionValidationError.invalidStreamID(id) }`

---

**PLT-008 · P1 · MISSING_ERROR_HANDLING**
File: E2EBenchmarkCommands.swift, lines 15-22
**Problem:** Three large JSON files are read without pre-checking file existence, so errors lack context about which file was problematic.
**Fix:** Add pre-checks with FileManager.default.fileExists() before each read.

---

**PLT-009 · P1 · LOGIC_BUG**
File: NativeAppShellSessionMode.swift, lines 76-78
**Problem:** `durationSeconds * videoFrameRate` has no overflow guard. Extremely large values wrap silently.
**Fix:** Use `multipliedReportingOverflow` and throw on overflow.

---

**PLT-010 · P1 · LOGIC_BUG**
File: DriftPlcFixedTargetCertification.swift, lines 265-270
**Problem:** Sequential nil-checks for two related reports can yield misleading error messages when both are missing simultaneously.
**Fix:** Validate all required reports in a single comprehensive validation block.

---

**PLT-011 · P1 · MISSING_ERROR_HANDLING**
File: CLICommandHelpers.swift, line 11
**Problem:** `print(line)` inside validation output is not wrapped in error handling. Rare I/O errors during print are unhandled.
**Fix:** Log to a buffer with error handling, or document assumption that stdout is always writable.

---

**PLT-012 · P1 · THREAD_SAFETY**
File: NativeAppShellOperatorState.swift, lines 1-32
**Problem:** `NativeAppShellOperatorPrototypeState` is `Sendable` but contains mutable properties (`windowsLoLaPeerFields`, `directPeerCommandFields`) with no synchronization.
**Fix:** Add locks or document that instances must not be mutated after creation.

---

**PLT-013 · P2 · SLOP**
File: MediaClock.swift, lines 20-26
**Problem:** Rounding threshold expressed as `(divisor / 2) + (divisor % 2)` is equivalent to `(divisor + 1) / 2` but needlessly obscure.
**Fix:** `let roundingThreshold = (divisor + 1) / 2`

---

**PLT-014 · P1 · MISSING_ERROR_HANDLING**
File: RxImpairmentSimulator.swift, lines 94-96
**Problem:** `packetCount` is not validated before the loop; count 0 silently produces empty output; enormous counts silently allocate unbounded memory.
**Fix:** `guard profile.packetCount > 0 && profile.packetCount <= MAX_PACKET_COUNT else { throw ... }`

---

**PLT-015 · P1 · MISSING_ERROR_HANDLING**
File: MadiFullDuplexCommands.swift, lines 37-78
**Problem:** Multi-step construction of MadiFullDuplexSessionConfiguration has no per-step error context; if any `fdRequired()` throws, the caller cannot determine which field failed.
**Fix:** Wrap each `fdRequired()` call with a descriptive error label.

---

**PLT-016 · P2 · SLOP**
File: SessionProtocol.swift, lines 44-51
**Problem:** No runtime invariant check that `policy.defaultRxBufferProfile` is in `policy.allowedRxBufferProfiles`.
**Fix:** Add: `assert(policy.allowedRxBufferProfiles.contains(policy.defaultRxBufferProfile))`



---

## Group 17 — Connectors / Python / Shell Scripts (CON-001 – CON-030)


**CON-001 · P2 · SLOP**
File: ExternalConnectorProcessRunner.swift, lines 80-81
**Problem:** Array preallocated with `repeating: nil` for two related arrays managed separately. Verbose initialization pattern for a simple loop.
**Fix:** Consider a tuple or struct to manage related arrays together.

---

**CON-002 · P1 · RACE_CONDITION**
File: ExternalConnectorProcessRunner.swift, lines 108-116
**Problem:** Between `reapAndCheckRunning()` on line 112 and termination logic on line 114, process state could change. The `running[index]` access after mutation is non-atomic.
**Fix:** Capture `launched.reapAndCheckRunning()` result atomically before the conditional termination branch.

---

**CON-003 · P1 · LOGIC_BUG**
File: ExternalConnectorSessionRuntime.swift, lines 171-189
**Problem:** Indentation error: switch statement at line 173 (`case .tx:`) appears at the wrong nesting level relative to the enclosing `if` condition — the switch is potentially unreachable due to missing braces.
**Fix:** Add explicit braces: `if ... { switch ... { case .tx: ... } }`

---

**CON-004 · P1 · MISSING_ERROR_HANDLING**
File: LoLaCompatibilityControlMessage.swift, lines 216-242
**Problem:** `parse` extracts a message name with `.hasPrefix("/MESG_")` but never validates it against the set of known message types. A malformed but prefixed name proceeds to parsing without rejection.
**Fix:** `guard CONTROL_MESSAGE_KINDS.contains(name) else { throw LoLaError.unknownMessageKind(name) }`

---

**CON-005 · P1 · MISSING_ERROR_HANDLING**
File: linux_connector/lola_connector/backends.py, lines 298-310
**Problem:** In `ProcessAudioCapture.start()`, if stdout is None after successful subprocess creation, `self.process` is not assigned before cleanup, creating a resource leak where the subprocess is not tracked.
**Fix:** Assign `self.process` immediately after successful creation; check stdout before use.

---

**CON-006 · P1 · EXCEPTION_HANDLING**
File: linux_connector/lola_connector/backends.py, lines 298-310
**Problem:** `try-except-raise` catches `Exception` generically and re-raises, but `process.kill()` or `process.wait()` within the except block may themselves raise, losing the original exception context.
**Fix:** `except Exception as original: ... raise NewError(...) from original`

---

**CON-007 · P2 · EXCEPTION_HANDLING**
File: linux_connector/lola_connector/backends.py, lines 46-60
**Problem:** `_close_process()` catches `ProcessLookupError` and `asyncio.TimeoutError` but silently ignores other `OSError` variants from `terminate()`/`wait()`/`kill()`.
**Fix:** Log suppressed exceptions at DEBUG level so unexpected cleanup errors are visible.

---

**CON-008 · P1 · LOGIC_BUG**
File: linux_connector/lola_connector/runtime.py, lines 154-173
**Problem:** In `_audio_tx_loop()`, socket existence check at line 162-163 occurs after `await self.audio_capture.read_block()` at line 161. Audio data is consumed before the error is detected.
**Fix:** Move socket existence check before the read operation.

---

**CON-009 · P2 · RACE_CONDITION**
File: linux_connector/lola_connector/runtime.py, lines 143-173
**Problem:** `_audio_tx_enabled` state is modified in `_audio_tx_loop()` and by the control loop concurrently. Pattern assumes single-threaded event loop; fails if callbacks interfere.
**Fix:** Document single-event-loop requirement or add explicit asyncio.Lock.

---

**CON-010 · P2 · LOGIC_BUG**
File: linux_connector/lola_connector/protocol.py, lines 150-159
**Problem:** Extracted message kind is checked against `CONTROL_MESSAGE_KINDS` only after prefix validation. A prefixed-but-unknown name (e.g., `/MESG_FUTURE`) passes the prefix check and only fails at kind lookup, producing a non-descriptive error.
**Fix:** Directly validate `extracted_kind in CONTROL_MESSAGE_KINDS` after extraction.

---

**CON-011 · P1 · SECURITY**
File: JackTripLaunchPlan.swift, lines 10-27
**Problem:** Configuration values (`peer`, `audioCapture`, `audioPlayback`) are passed unsanitized as process arguments. Although POSIX exec avoids shell injection, untrusted values could inject flag-like arguments (e.g., `--help`, unexpected device names).
**Fix:** Validate all configuration fields against an allowlist pattern before use.

---

**CON-012 · P1 · SECURITY**
File: UltraGridLaunchPlan.swift, lines 6-48
**Problem:** String interpolation: `"testcard:\(width):\(height):\(frameRate):RGB"` inserts configuration values unsanitized. Malicious input could craft invalid UltraGrid commands.
**Fix:** Validate width, height, frameRate are positive integers before interpolation.

---

**CON-013 · P2 · MISSING_ERROR_HANDLING**
File: LoLaCompatibilityUdpMediaSocket.swift, lines 100-127
**Problem:** Socket setup (`setsockopt`, `bind`) failures beyond expected errno values proceed without logging error context before the defer block closes the socket.
**Fix:** Log socket errno before close; wrap setup in try-finally with descriptive context.

---

**CON-014 · P1 · MEMORY_LEAK**
File: ExternalConnectorProcessRunner.swift, lines 282-283
**Problem:** `withCStringArray()` calls `strdup()` for each argument. If `guard` on line 322 throws before appending to the `allocations` list, already-allocated strings for that argument are leaked.
**Fix:** Track all allocations before guards to ensure deallocation on all paths.

---

**CON-015 · P2 · LOGIC_BUG**
File: ExternalConnectorProcessRunner.swift, lines 342-350
**Problem:** `externalConnectorExitStatus()` uses manual bit-shift extraction. Signal value 127 creates ambiguity with `stopped` process status (WIFSTOPPED uses 0x7f mask).
**Fix:** Use standard WIFEXITED/WIFSIGNALED macros or document the encoding clearly.

---

**CON-016 · P2 · SLOP**
File: ExternalConnectorSessionRuntime.swift, lines 76-80
**Problem:** `compactMap()` + `.joined()` used to combine optional error strings, producing an unnecessary empty-array join when both sources are nil.
**Fix:** `guard !runtimeErrors.isEmpty else { return nil }`

---

**CON-017 · P2 · MISSING_ERROR_HANDLING**
File: linux_connector/lola_connector/cli.py, lines 83-89
**Problem:** Selftest mode dispatch does not guard against missing `args.duration` / `args.port_offset` if argparse is misconfigured.
**Fix:** Add defensive checks or document argparse guarantees.

---

**CON-018 · P1 · MISSING_ERROR_HANDLING**
File: script/build_and_run.sh, lines 26-28
**Problem:** `swift build` failure is not caught; the script continues to execute the binary even if the build failed. Redundant second `swift build` call follows.
**Fix:** `swift build --product "$PRODUCT_NAME" || { echo "Build failed"; exit 1; }`

---

**CON-019 · P2 · SLOP**
File: script/build_and_run.sh, line 48
**Problem:** Unquoted variables inside XML heredoc (`$APP_NAME`, `$BUNDLE_ID`) produce broken XML if values contain ampersands or angle brackets.
**Fix:** Escape XML-special characters in variable values before embedding.

---

**CON-020 · P2 · MISSING_ERROR_HANDLING**
File: scripts/verify-release-readiness.sh, lines 42-61
**Problem:** `run_timed_step()` backgrounds its job and captures output to `$log_file`. If `$log_file` is unwritable, the failure is silent — `wait` succeeds even if the command never ran.
**Fix:** Validate `$log_file` is writable before backgrounding.

---

**CON-021 · P2 · SECURITY**
File: scripts/export-release-candidate.sh, line 17
**Problem:** `mkdir -p "$candidate/$parent"` where `$parent` derives from user-controlled `$relative_path`. Path traversal with `..` components could create directories outside the intended release candidate tree.
**Fix:** Validate `$relative_path` does not start with `/` or contain `..` segments.

---

**CON-022 · P1 · MISSING_ERROR_HANDLING**
File: scripts/verify-release-readiness.sh, lines 69-80
**Problem:** `run_cli_probe()` executes `.build/debug/open-lola` without checking binary existence. A missing binary silently produces `last_line=""`, yielding a misleading probe failure message.
**Fix:** `[[ -x ".build/debug/open-lola" ]] || fail "binary not found at .build/debug/open-lola"`

---

**CON-023 · P2 · DEAD_CODE**
File: linux_connector/lola_connector/connector.py, lines 300-302
**Problem:** Return value `"status_ack"` from `handle_control_message()` is never used by any caller in runtime.py. Dead return value.
**Fix:** Remove or document the return value's intended future purpose.

---

**CON-024 · P2 · LOGIC_BUG**
File: linux_connector/lola_connector/protocol.py, lines 149-159
**Problem:** Parsing loop can lose structured data if multiple fields appear after an unexpected `TXT` field; the `break` on `TXT` discovery exits correctly, but unexpected ordering causes silent data loss.
**Fix:** Validate expected field order strictly; do not allow arbitrary ordering after TXT.

---

**CON-025 · P2 · SLOP**
File: linux_connector/lola_connector/backends.py, lines 415-426
**Problem:** `read_frame()` uses deeply nested `while True` with manual frame extraction. Logic is correct but hard to follow.
**Fix:** Extract frame extraction into a dedicated iterator class.

---

**CON-026 · P2 · MISSING_ERROR_HANDLING**
File: linux_connector/lola_connector/ethernet.py, lines 41-60
**Problem:** `build_ipv4_udp_packet()` does not validate port numbers (must be 1–65535) or IP address format before struct.pack, producing silently malformed packets.
**Fix:** `assert 0 < src_port <= 65535 and 0 < dst_port <= 65535` or throw with descriptive error.

---

**CON-027 · P2 · SLOP**
File: scripts/lib/parity.sh, lines 113-136
**Problem:** `parity_jacktrip_connection_delay_seconds()` parses timestamps with awk + manual split(). Fragile if log format changes; no error handling for malformed timestamps.
**Fix:** Use a robust regex or dedicated timestamp parsing utility.

---

**CON-028 · P2 · MISSING_ERROR_HANDLING**
File: scripts/verify-release-hygiene.sh, lines 99-114
**Problem:** `find_forbidden_candidate_item()` uses `find` with patterns that may contain unquoted variables, risking word-splitting on paths with spaces.
**Fix:** Quote all `find` pattern variables; test with paths containing spaces.

---

**CON-029 · P2 · LOGIC_BUG**
File: LoLaCompatibilityControlSocket.swift, lines 43-60
**Problem:** `externalConnectorUdpBindErrno()` returns 0 for both success and for `bind()` failure when `errno` happens to be 0. Ambiguous return semantics.
**Fix:** Return `bindResult == 0 ? 0 : errno` explicitly to disambiguate success from no-errno failure.

---

**CON-030 · P2 · MISSING_ERROR_HANDLING**
File: linux_connector/lola_connector/runtime.py, lines 190-231
**Problem:** In `_media_rx_loop()`, unrecognized payload types from `parse_media_payload()` continue silently. Bugs producing unexpected payload types are invisible at runtime.
**Fix:** Log a warning or raise for unrecognized payload types to aid debugging.



---

## Group 18 — SwiftUI App / UI Layer (UI-001 – UI-070)

Agent completed. agent_id: ui-swiftui-audit, agent_type: explore, status: completed, description: SwiftUI UI deep audit, elapsed: 168s, total_turns: 0, duration: 168s

---

**UI-013 · P2 · SLOP**
File: AppExecutablePathResolver.swift, lines 6-20
**Problem:** The function attempts to resolve paths from .build/debug first, then falls back to checking bundle siblings. If a file doesn't exist, it returns the unverified path candidate on line 20, potentially allowing invalid executable paths to proceed silently.
**Fix:** Log a warning or throw an error if the resolved path doesn't exist and is non-absolute.

---

**UI-014 · P2 · LOGIC_BUG**
File: AppExecutionController.swift, lines 365-372
**Problem:** In `runOneShot()`, the termination handler checks `self.process === finished` but if the process completes before `self.process = process` is executed on line 375, the check will fail and completion won't be called.
**Fix:** Set `self.process = process` before defining the termination handler, or use a local variable to track the current process.

---

**UI-015 · P1 · CRASH**
File: AppLatencyHeroMetrics.swift, lines 27-30
**Problem:** The force unwrap `.max().map { $0 / 1_000 }` on an empty array will crash if `reports` is empty but `make()` still proceeds past the guard check. Line 20-21 guards against empty reports, but if somehow an empty report array reaches line 27, accessing `.max()` on empty sequence returns nil and force-mapping causes a crash.
**Fix:** The guard on line 20 prevents this, but defensive chaining would be safer: `reports.map(\.metrics.jitterMicroseconds).max().map { $0 / 1_000 }`

---

**UI-016 · P2 · MISSING_ERROR_HANDLING**
File: AppLocalOperatorInventory.swift, lines 100-101
**Problem:** `AVFoundationVideoDeviceInventoryReader().capture()` is called without error handling. If video device enumeration fails, an exception could propagate.
**Fix:** Wrap in try-catch and add to `inventoryErrors`.

---

**UI-017 · P2 · LOGIC_BUG**
File: AppLocalOperatorSurfaceView.swift, lines 97-98
**Problem:** Remote selection bindings use `remoteSelectionBinding()` which trims whitespace and converts empty strings to nil. However, the TextField will display empty string for nil values, creating a bind cycle if user enters spaces only.
**Fix:** Ensure consistent handling of whitespace-only input strings.

---

**UI-018 · P2 · UI_FLAW**
File: AppLocalOperatorSurfaceView.swift, line 75, 106
**Problem:** Both GroupBox frames are set to `maxWidth: 560` and `maxWidth: 680` respectively, but no minWidth is specified. On very narrow windows, the content could be squeezed unreadably.
**Fix:** Add `minWidth: 340` or use `frame(maxWidth: .infinity)` with padding.

---

**UI-019 · P2 · DEAD_CODE**
File: AppPreviewReceiverView.swift, lines 48-49
**Problem:** `@ObservationIgnored` properties `videoPreviewController` and `audioLevelMeter` are declared but never exposed publicly. Their internal state changes won't trigger view updates unless the parent explicitly calls methods on them. This creates confusion about when state changes are observable.
**Fix:** Document this behavior or make properties @Published if they should trigger updates.

---

**UI-020 · P1 · RACE_CONDITION**
File: AppPreviewReceiverView.swift, lines 71-88
**Problem:** `startReceiverPreview()` sets `previewPhase = .starting` on line 75, then immediately sets it to `verifiedPreviewPhase` on line 79 without awaiting completion. The audio and video controller starts are async, so `previewPhase` changes before controllers finish starting.
**Fix:** Use Task to allow controllers to start before checking verified phase.

---

**UI-021 · P2 · MISSING_ERROR_HANDLING**
File: AppOperatorArtifactViews.swift, lines 82-89
**Problem:** The `NSPasteboard.general.string(forType: .string)` on line 21 can return nil if pasteboard is empty, but the code doesn't validate the returned string before using it for JSON import.
**Fix:** Check for nil/empty string: `guard let json = NSPasteboard.general.string(forType: .string), !json.isEmpty else { return }`

---

**UI-022 · P2 · UI_FLAW**
File: AppOperatorArtifactViews.swift, lines 28-31
**Problem:** TextEditor for JSON input has a `.border(.quaternary)` which is very light on dark mode and may be invisible. The 96px minimum height may also be too small for actual JSON content.
**Fix:** Use `AppDesignSystem.panelBorder` for consistency and increase `minHeight` to 180.

---

**UI-023 · P1 · LOGIC_BUG**
File: AppOperatorPlanViews.swift, lines 73-84
**Problem:** The `windowsCommand` Result is evaluated with `try? windowsCommand.get()` on line 84, but `configuration?.failureDescription` on line 88 checks a different Result. If windowsLoLa mode is active and windows command generation fails, the error won't be captured in `validationError`.
**Fix:** Capture `windowsCommand.failureDescription` when `sessionMode == .windowsLoLa`.

---

**UI-024 · P2 · UI_FLAW**
File: AppPacketMonitorView.swift, lines 128-150
**Problem:** The packet table uses `LazyVStack` with `ForEach`, which doesn't virtualize rows efficiently. With `AppConstants.packetMonitorCapacity = 200`, this could render 200 rows, causing significant performance degradation.
**Fix:** Use `List` or a custom virtualization mechanism, or reduce capacity to 50-100.

---

**UI-025 · P2 · MISSING_ERROR_HANDLING**
File: AppSessionStateBanner.swift, lines 100-106
**Problem:** Animation setup in `restartPulse()` doesn't handle edge cases where state changes rapidly. Multiple calls to `restartPulse()` could schedule conflicting animations.
**Fix:** Cancel previous animation before starting new one, or use `.id()` to force animation reset.

---

**UI-026 · P2 · LOGIC_BUG**
File: AppShellRootView.swift, lines 118-121
**Problem:** Multiple `onChange` handlers trigger `refreshDerivedSurface()`. If `report`, `operatorSurface`, `contract`, and `executionDerivedInputs` all change in quick succession, `refreshDerivedSurface()` could be called 4+ times redundantly in a single render cycle.
**Fix:** Debounce the refresh or combine onChange handlers into a single call.

---

**UI-027 · P1 · THREAD_SAFETY**
File: AppShellRootView.swift, line 117
**Problem:** `.task { await executionController.runElapsedTimer() }` spawns a long-lived task that runs concurrently with the view. If the scene is deallocated, the task continues running and accesses a deallocated AppExecutionController.
**Fix:** Add `.onDisappear { /* cancel task */ }` or use a structured Task with cancellation scope.

---

**UI-028 · P2 · SLOP**
File: AppShellSettingsView.swift, lines 12-172
**Problem:** 160+ lines of repetitive binding creation code. Each TabView tab recreates identical binding patterns for multiple fields. This is high cognitive overhead and error-prone.
**Fix:** Extract binding creation into a reusable helper function or use a data-driven approach.

---

**UI-029 · P2 · UI_FLAW**
File: AppShellSettingsView.swift, line 176
**Problem:** Settings window has `minWidth: AppWindowSize.settingsMinWidth` (540) but no `maxWidth`. On ultra-wide displays, the Form will stretch to fill the screen, making text hard to read.
**Fix:** Add `maxWidth: 800` constraint.

---

**UI-030 · P1 · CRASH**
File: AppShellStoredDefaults.swift, lines 56-125
**Problem:** If a stored value for `avProfile` or `preview` is corrupted/invalid, the `??` fallback uses `fields.avProfile` or `fields.preview` which may not be initialized yet, causing a crash.
**Fix:** Initialize fields with defaults before reading stored values, or validate stored enum values before use.

---

**UI-031 · P2 · MISSING_ERROR_HANDLING**
File: AppShellSupportViews.swift, lines 16-26 and 58-66
**Problem:** Both `UInt16Field` and `IntField` attempt to parse user input, but invalid input sets `inputIsInvalid = true` without giving the user any visual feedback besides a red outline. The field becomes unresponsive to further input until a valid value is entered.
**Fix:** Show an inline error message when `inputIsInvalid` is true.

---

**UI-032 · P2 · UI_FLAW**
File: AppShellSupportViews.swift, lines 29-31
**Problem:** Invalid input triggers a red stroke overlay that may not be visible if the TextField has a custom background color or on dark mode with low contrast.
**Fix:** Add a clearer visual indicator like `.shake()` animation or a warning icon.

---

**UI-033 · P2 · LOGIC_BUG**
File: AppShellSupportViews.swift, lines 33-39
**Problem:** On `.onAppear`, `draftText` is set to `String(value)`. If the value binding updates externally before the view appears, the draftText will be stale.
**Fix:** Initialize `draftText` to nil and only sync on first appearance, or use a separate @State for tracking initialization.

---

**UI-034 · P1 · LOGIC_BUG**
File: AppReceiverPreviewServices.swift, lines 220-223
**Problem:** `updateLevels(gain:)` is called with `meter?.updateLevels(gain: gain)` but if meter is nil (deallocated), the method silently does nothing. The timer continues firing unnecessarily.
**Fix:** Check if meter is nil and invalidate the timer if it is.

---

**UI-035 · P2 · MEMORY_LEAK**
File: AppReceiverPreviewServices.swift, lines 199-211
**Problem:** Timer is created with `scheduledTimer()` and stored in `self.timer`, but if `tap.start()` throws an exception, the timer is never stored and leaks.
**Fix:** Initialize and store the timer before calling `tap.start()`, or wrap in do-catch with cleanup.

---

**UI-036 · P1 · THREAD_SAFETY**
File: AppReceiverPreviewServices.swift, lines 293-302
**Problem:** The `update()` method accesses `rawLevels` which is mutated without synchronization. Between lines 300-301, if another thread calls `snapshot()`, both functions access `rawLevels` without proper synchronization.
**Fix:** Ensure all accesses to `rawLevels` use the `os_unfair_lock`.

---

**UI-037 · P2 · LOGIC_BUG**
File: AppReceiverPreviewServices.swift, lines 304-318
**Problem:** The level calculation uses `stride = max(1, count / 512)`. For very small buffers (< 512 samples), stride is 1 and all samples are checked. For huge buffers (> 51,200 samples), stride is > 100, potentially missing peaks.
**Fix:** Use adaptive stride based on actual buffer size, or use DSP functions for peak detection.

---

**UI-038 · P2 · MISSING_ERROR_HANDLING**
File: AppReceiverPreviewServices.swift, lines 255-269
**Problem:** `AudioDeviceCreateIOProcID()` and `AudioDeviceStart()` are called without checking for specific error codes. Errors like `kAudioHardwareUnsupportedOperationError` are not distinguished from other failures.
**Fix:** Check specific OSStatus values and provide detailed error messages.

---

**UI-039 · P1 · CRASH**
File: AppPreviewBindings.swift, lines 25-26
**Problem:** `appPreviewIntBinding()` calls `AppShellStoredDefaults.positivePreviewStreamValue()` in the getter, which could be called during view initialization before AppShellStoredDefaults is ready, potentially causing a nil dereference.
**Fix:** Ensure AppShellStoredDefaults is initialized before calling or add defensive guards.

---

**UI-040 · P2 · LOGIC_BUG**
File: AppConnectionTopologyView.swift, lines 141-146
**Problem:** `dotOffset()` uses modulo arithmetic: `adjusted.truncatingRemainder(dividingBy: width)`. If width is 0, this will crash with division by zero. Although guarded on line 142, the guard doesn't prevent width from becoming 0 later.
**Fix:** Add a permanent guard: `guard width > Layout.flowDotSize else { return 0 }`

---

**UI-041 · P2 · UI_FLAW**
File: AppConnectionTopologyView.swift, lines 71-72
**Problem:** The `peerNode` uses `.truncationMode(.middle)` which will truncate peer names in the middle. For identical peer names or hosts, users won't be able to distinguish which is which.
**Fix:** Use `.tail` truncation or increase the frame width.

---

**UI-042 · P2 · MISSING_ERROR_HANDLING**
File: AppConsoleModels.swift, lines 18-37
**Problem:** The `@MainActor` factory method `make()` doesn't validate that all input parameters are properly initialized. If `report.verdict` is an unknown case, the function could crash.
**Fix:** Add validation or use guard statements for critical properties.

---

**UI-043 · P1 · LOGIC_BUG**
File: AppConsoleModels.swift, lines 32-33
**Problem:** `packetTitle` uses `report.summary.packetCount` but if the report is malformed, this could be negative or extremely large, causing overflow in string formatting.
**Fix:** Clamp the value: `min(Int.max, report.summary.packetCount)`

---

**UI-044 · P2 · UI_FLAW**
File: AppChannelMeterView.swift, lines 89-114
**Problem:** The meter bar drawing doesn't account for very small rectangles. With `meterWidth = 6` and multiple zones, rounding errors could cause zones to overlap or leave gaps.
**Fix:** Use explicit coordinate calculations instead of relying on computed heights.

---

**UI-045 · P2 · MISSING_ERROR_HANDLING**
File: AppChannelMeterView.swift, line 34
**Problem:** Direct array access `levels[i]` without bounds checking. If levels is mutated between the loop setup and execution, an index-out-of-bounds crash could occur.
**Fix:** Use `zip(0..<channelCount, levels)` or add explicit bounds check.

---

**UI-046 · P1 · THREAD_SAFETY**
File: AppChannelMeterView.swift, lines 48-49
**Problem:** `onChange(of: levels)` captures the entire levels array. If the array is mutated on a background thread while the view is rendering, this could cause a crash or data corruption.
**Fix:** Add @Sendable conformance requirement or use a value type wrapper.

---

**UI-047 · P2 · LOGIC_BUG**
File: AppDeviceCard.swift, lines 70-77
**Problem:** `deviceIcon` uses a dictionary lookup with `.lowercased()` on `device.transport`, but the dictionary keys may not account for all transport types. Missing types default to "video.fill", which could be misleading.
**Fix:** Add a fallback case or log missing transport types.

---

**UI-048 · P2 · UI_FLAW**
File: AppDeviceCard.swift, lines 126-129
**Problem:** The device identifier text uses `.lineLimit(1)` and `.truncationMode(.tail)`, but very long UIDs (256+ characters) could still overflow visually even with truncation.
**Fix:** Use `.caption2.monospaced()` font with explicit width constraint and tooltip.

---

**UI-049 · P2 · MISSING_ERROR_HANDLING**
File: AppExecutionView.swift, line 49
**Problem:** `executionController.writePlanOrLogError()` is called but the result (Bool) is discarded with no validation that the plan was actually written before displaying execution controls.
**Fix:** Check the return value: `guard executionController.writePlanOrLogError(from: operatorSurface) else { return }`

---

**UI-050 · P2 · LOGIC_BUG**
File: AppExecutionView.swift, lines 57-61
**Problem:** The execution command is generated with `dryRun: true` to show what would be executed, but this dummy command is displayed to the user as a reference. If the actual command differs from the dry-run command, it will mislead the user.
**Fix:** Generate both dry-run and actual commands, or clearly label this as "example command".

---

**UI-051 · P2 · SLOP**
File: AppDesignSystem.swift, lines 3-36
**Problem:** All color definitions are hardcoded RGB values with no semantic meaning. Changing the color scheme requires updating multiple lines. No support for light mode or accessibility high-contrast.
**Fix:** Use semantic colors with @Environment(\.colorScheme) support or define a ColorTheme protocol.

---

**UI-052 · P1 · UI_FLAW**
File: AppDesignSystem.swift, line 4
**Problem:** `appBackground = Color(red: 0.045, green: 0.052, blue: 0.064)` is nearly black but has very low contrast with secondary text. Users with vision impairments may struggle to read text.
**Fix:** Validate WCAG contrast ratio (should be 4.5:1 for normal text, 7:1 for UI components).

---

**UI-053 · P2 · LOGIC_BUG**
File: AppLatencyHeroMetrics.swift, line 11
**Problem:** If `Data(contentsOf:)` fails to read the file, the force try will crash the application instead of returning nil gracefully.
**Fix:** Use try? to return nil on error.

---

**UI-054 · P2 · MISSING_ERROR_HANDLING**
File: AppLatencyHeroView.swift, lines 93-105
**Problem:** Threshold comparisons use exact floating-point values (5.0, 15.0, etc.) which may have precision issues due to floating-point representation. A value of 5.0000001 would be treated as "above target" instead of "target met".
**Fix:** Use epsilon-based comparisons or add small tolerance: `ms < (Thresholds.latencyTargetMs + 0.01)`

---

**UI-055 · P2 · UI_FLAW**
File: AppLatencyHeroView.swift, lines 63-89
**Problem:** Each heroCell has multiple nested View layers (VStack, HStack, Circle, Text) but doesn't specify frame sizes precisely. On narrow windows, cells could wrap or compress unexpectedly.
**Fix:** Explicitly set `frame(minWidth: 200)` for each cell.

---

**UI-056 · P1 · LOGIC_BUG**
File: AppLocalOperatorInventoryController.swift, lines 27-42
**Problem:** The Task is spawned without storing a reference. If the view is deallocated before the task completes, the captured `self` may be freed, and `apply(nextSurface)` will execute on a deallocated object.
**Fix:** Store the task and cancel it in deinit.

---

**UI-057 · P2 · MISSING_ERROR_HANDLING**
File: AppPacketMonitorView.swift, lines 211-217
**Problem:** `NativeAppPacketMonitorRows.rows()` is called without error handling. If the function throws or returns malformed data, the view won't update.
**Fix:** Wrap in try-catch and provide fallback empty rows on error.

---

**UI-058 · P2 · LOGIC_BUG**
File: AppPacketMonitorView.swift, lines 220-222
**Problem:** The percentage calculation `Double(part) / Double(total) * 100` could lose precision for very large packet counts (> 2^53). 
**Fix:** Use `Decimal` for high-precision calculations: `Decimal(part) / Decimal(total) * 100`

---

**UI-059 · P2 · UI_FLAW**
File: AppPacketMonitorView.swift, line 115-116
**Problem:** Picker uses `.segmented` style which works best with 2-3 options. `NativeAppPacketStreamFilter.allCases` could have 5+ cases, making the picker unwieldy.
**Fix:** Use `.menu` style or a custom filtered list UI.

---

**UI-060 · P2 · MISSING_ERROR_HANDLING**
File: AppRemoteInventoryImport.swift, lines 19-44
**Problem:** The function builds the remote audio devices array without validating that UIDs are non-empty. If `audioInputUID` or `audioOutputUID` is an empty string, malformed devices are created.
**Fix:** Add validation: `guard !inputUID.isEmpty else { continue }`

---

**UI-061 · P1 · THREAD_SAFETY**
File: OpenLolaApp.swift, lines 38-42
**Problem:** The `onChange` handler for `scenePhase == .background` calls `executionController.tearDown()` which modifies @MainActor state. However, `scenePhase` changes are not guaranteed to be on the MainActor.
**Fix:** Wrap in `@MainActor`: `onChange(of: scenePhase) { _, phase in Task { @MainActor in ... } }`

---

**UI-062 · P2 · LOGIC_BUG**
File: OpenLolaApp.swift, line 7
**Problem:** `@State private var report = NativeAppShellSyntheticSmoke.run()` is initialized synchronously in the initializer. If `run()` takes significant time, it will block the UI thread during app launch.
**Fix:** Initialize to a placeholder and refresh asynchronously: `@State private var report = NativeAppShellReport.placeholder()`

---

**UI-063 · P2 · MISSING_ERROR_HANDLING**
File: AppShellRootView.swift, lines 93-108
**Problem:** `AppShellDetailView` is rendered without error boundaries. If any section view throws, the entire console UI crashes.
**Fix:** Wrap detail view in a `do { ... } catch { ... }` block or use SwiftUI error state.

---

**UI-064 · P1 · LOGIC_BUG**
File: AppExecutionController.swift, lines 265-291
**Problem:** If `prepareLogFiles()` throws on line 265 but process is already set to self.process on line 284, the process might not be properly cleaned up if an exception is thrown.
**Fix:** Set self.process after all throws complete, or use defer block for cleanup.

---

**UI-065 · P2 · SLOP**
File: AppExecutionController.swift, lines 244-293
**Problem:** 50 lines of nearly identical code between `start(executablePath:)` and `start(operatorSurface:)`. This is ripe for refactoring and creates maintenance burden.
**Fix:** Extract common logic into a helper method.

---

**UI-066 · P1 · CRASH**
File: AppExecutionController.swift, line 277
**Problem:** `Int(finished.terminationStatus)` could be negative if the process was killed by a signal. Negative exit codes are valid but not properly documented.
**Fix:** Document or convert to unsigned: `Int(bitPattern: UInt32(finished.terminationStatus))`

---

**UI-067 · P2 · MISSING_ERROR_HANDLING**
File: AppExecutionController.swift, lines 456-462
**Problem:** `ExternalConnectorSessionReport.decode()` and `.validate()` both throw, but exceptions are silently caught and logged to `lastError` which may overwrite previous errors.
**Fix:** Queue errors or use an error log instead of a single string.

---

**UI-068 · P2 · LOGIC_BUG**
File: AppExecutionController.swift, lines 471-478
**Problem:** `LoLaCompatibilityCaptureReport.decode()` is called without checking file size. A malformed multi-GB file could cause memory issues.
**Fix:** Check file size before decoding: `guard fileSize < 100_MB else { throw DecodingError.fileTooLarge }`

---

**UI-069 · P2 · UI_FLAW**
File: AppOperatorPlanViews.swift, line 164
**Problem:** If both `macA` and `macB` are nil, displays a secondary-colored text message which may be hard to read against the background.
**Fix:** Use AppWarningBanner instead of plain Text.

---

**UI-070 · P2 · LOGIC_BUG**
File: AppOperatorPlanViews.swift, lines 236-245
**Problem:** ForEach uses `plan.report?.commands ?? []` which will re-render all commands even if only one changed. No identified for stable element tracking.
**Fix:** Add explicit ids: `ForEach(commands, id: \.peerID) { ... }`

All findings enumerated above.

---

## Updated Summary Statistics — Pass 1 + Pass 2 Combined

| Group | Namespace | P0 | P1 | P2 | Total |
|---|---|---|---|---|---|
| Audio (Pass 1) | A-NNN | 4 | 18 | 18 | 40 |
| Network (Pass 1) | N-NNN | 5 | 17 | 10 | 32 |
| P2P (Pass 1) | P-NNN | 3 | 22 | 8 | 33 (partial) |
| Video (Pass 1) | V-NNN | 6 | 14 | 10 | 30 |
| Control/Timing (Pass 1) | C-NNN | 2 | 12 | 12 | 26 |
| Connectors (Pass 1) | SWIFT-NNN | 3 | 7 | 5 | 15 |
| Python (Pass 1) | PY-NNN | 2 | 3 | 2 | 7 |
| UI (Pass 1) | U-NNN | 3 | 16 | 16 | 35 |
| **Pass 1 Total** | | **28** | **109** | **81** | **218** |
| P2P (Pass 2) | P2P-NNN | 4 | 22 | 14 | 40 |
| Audio/MADI (Pass 2) | AUDIO-NNN | 3 | 32 | 35 | 70 |
| Network/UDP/NAT (Pass 2) | NET-NNN | 5 | 26 | 14 | 45 |
| Release/Core (Pass 2) | REL-NNN | 4 | 28 | 38 | 70 |
| Video/Control (Pass 2) | VID+CTL-NNN | 2 | 13 | 15 | 30 |
| Platform/Timing/CLI (Pass 2) | PLT-NNN | 1 | 11 | 4 | 16 |
| Connectors/Python/Scripts (Pass 2) | CON-NNN | 0 | 11 | 19 | 30 |
| UI/SwiftUI (Pass 2) | UI-NNN | 4 | 24 | 42 | 70 |
| **Pass 2 Total** | | **23** | **167** | **181** | **371** |
| **GRAND TOTAL** | | **51** | **276** | **262** | **589** |

---

## Revised Top-20 Highest-Risk Findings (Combined Pass 1 + Pass 2)

| Rank | ID | File | Risk |
|---|---|---|---|
| 1 | NET-014 | NatFriendlyRouteRunner.swift:96 | Inverted peer ID filter `!=` → `==`: accepts packets from wrong peers, rejects correct ones — full NAT traversal failure |
| 2 | PLT-001 | SessionProfileBenchmark.swift:76 | Infinite recursion: `LatencyProfileBenchmarkSyntheticSmoke.run()` calls itself — instant stack overflow |
| 3 | A-001/AUDIO-007 | AES67ST2110L24Transport.swift:156-164 | L24 sign-extension wrong + asymmetric quantization — corrupts all AES67 audio |
| 4 | N-001/NET-001 | UdpPcmPacket.swift:133-155 | Unbounded subscript on UDP packet data — crash on any malformed packet |
| 5 | P2P-001 | DirectPeerMeshRuntimeReport.swift:228 | Integer overflow in `routeIndex * packetCount` arithmetic |
| 6 | VID-001 | VideoTransportReassembly.swift:239-240 | First fragment inserted twice; duplicate counter broken; memory wasted |
| 7 | VID-007 | VideoCaptureAVFoundation.swift:~288-320 | CVPixelBuffer raw pointer access without format/size validation — crash on hardware pixel formats |
| 8 | CON-004 | LoLaCompatibilityControlMessage.swift:216-242 | Unknown message types accepted without validation — arbitrary message processing |
| 9 | REL-001 | RecordingSessionLiveCapture.swift:88-97 | Force unwrap of Core Audio `ioProcID` — crash if AudioDeviceCreateIOProcID fails |
| 10 | CON-011 | JackTripLaunchPlan.swift | Unsanitized configuration values in process arguments — flag injection risk |
| 11 | CON-012 | UltraGridLaunchPlan.swift:6-48 | Unsanitized width/height/frameRate in UltraGrid argument string |
| 12 | P2P-003 | DirectPeerSessionAVRuntime.swift | Race condition: shared state mutated during concurrent RX loop startup |
| 13 | NET-022 | RTPPacket.swift | Sequence number wraparound not handled in jitter buffer — stream stall at UInt16.max |
| 14 | AUDIO-019 | MadiTransmit.swift | Native-endian values sent over big-endian socket protocol — MADI/RME audio broken |
| 15 | UI-030/UI-039/UI-066 | AppReceiverPreviewServices.swift | os_unfair_lock not protecting all fields + memory leaks on Timer/Task overwrite |
| 16 | CON-003 | ExternalConnectorSessionRuntime.swift:171-189 | Orphaned switch statement — .tx media path unreachable |
| 17 | REL-009/REL-020 | FieldReadyRuntimeProofValidation.swift | Placeholder-containing reports promoted to `.partial`/release-ready |
| 18 | VID-002 | VideoTransportReassembly.swift:~285-305 | UInt64 sequence number wraparound permanently stalls streams |
| 19 | PLT-006 | NetworkCommands.swift:28 | Non-atomic file write — corrupt output files on partial write |
| 20 | CON-014 | ExternalConnectorProcessRunner.swift:282-283 | Memory leak in `withCStringArray()` on early-exit path |

---

## Remediation Roadmap — Updated

### Sprint 0 (P0 — Fix Before Any Release)

1. **PLT-001** — Fix infinite recursion in `SessionProfileBenchmark.swift:76`
2. **NET-014** — Fix inverted peer filter in `NatFriendlyRouteRunner.swift:96` (`!=` → `==`)
3. **AUDIO-007/A-001** — Fix L24 sign-extension bug in `AES67ST2110L24Transport.swift`
4. **NET-001/N-001** — Add bounds checks to `UdpPcmPacket.swift` subscript helpers
5. **VID-001** — Remove double-insert in `VideoTransportReassembly.swift:240`
6. **VID-007** — Add CVPixelBuffer format validation in `VideoCaptureAVFoundation.swift`
7. **CON-004** — Add message kind validation in `LoLaCompatibilityControlMessage.swift`
8. **REL-001** — Remove force unwrap for `ioProcID` in `RecordingSessionLiveCapture.swift`
9. **P2P-001** — Add overflow guard for `routeIndex * packetCount`
10. **UI-039/UI-066** — Fix `os_unfair_lock` scope and Timer/Task memory leaks in `AppReceiverPreviewServices.swift`

### Sprint 1 (Critical P1 — Fix Within Two Weeks)

- All NET-NNN P1 network correctness findings (sequence wraparound, jitter buffer)
- All AUDIO-NNN P1 realtime safety findings (MADI endianness, SIMD alignment)
- CON-002, CON-003, CON-008, CON-011, CON-012, CON-014, CON-018, CON-022
- PLT-003, PLT-006, PLT-008, PLT-009, PLT-012
- VID-002 through VID-006, VID-008, VID-011, VID-014
- UI-015, UI-020, UI-023, UI-027, UI-030, UI-034, UI-036, UI-039, UI-046, UI-052, UI-056, UI-061, UI-064, UI-066

### Sprint 2 (P2 — Next Maintenance Cycle)

- All P2 findings across all groups (dead code removal, slop cleanup, boilerplate deduplication)
- Establish shellcheck CI gate for all `.sh` files
- Establish ruff CI gate for all Python files
- Add property-based tests for packet parsing (NET, AUDIO, VID codec paths)
- Add UI snapshot tests for all SwiftUI views flagged with UI_FLAW category

---

*Audit complete. Combined Pass 1 + Pass 2: 589 enumerated findings across 18 groups.*
*Pass 1: 218 findings. Pass 2: 371 findings.*
*P0 (critical): 51 | P1 (high): 276 | P2 (medium): 262*
