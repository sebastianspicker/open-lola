# open-lola2 — Full Codebase Audit & Remediation Plan

**Scope:** 285 Swift files + Python linux_connector (~14 files)  
**Audited modules:** Audio/Realtime, CoreAudio, MADI, Network/UDP, Network/NAT, Network/P2P,
Video, Protocol, Control, Connectors/LoLa, Connectors/Core, Connectors/JackTrip/NMP/UltraGrid,
Timing, Core, Support, Release, open-lola-app (SwiftUI), Platform, linux_connector (Python)  
**Total findings: 346**  
**P0 (crash/corruption/race): 31 | P1 (logic/API/safety): 211 | P2 (quality/slop/dedup): 104**

---

## Methodology

Each file was read in full by parallel subagents. Findings are classified:
- **P0** — crash, silent data corruption, race condition on mutable state, memory unsafety
- **P1** — wrong logic, missing error handling, API misuse, protocol violation, broken UI flow
- **P2** — dead code, duplication, slop, boilerplate, code quality, accessibility, structure

Findings are grouped by subsystem domain, then tiered within each group.

---

## 1. Realtime Audio (AUDIO)

### P0 — Must Fix Before Any Release

**[AUDIO-009]** `DirectPeerRealtimeAudioGraph` marked `@unchecked Sendable` but contains
non-atomic `nextInputFrame`/`nextOutputFrame` (UInt64) mutated in the realtime render callback
without any atomic primitive. `stop()` races against the callback. Use `open_lola_atomic_u64`
for these counters or move to actor-isolated state.

**[AUDIO-026]** `defaultDirectRxBufferPolicy` constructs `RxBufferPolicy(targetPackets:
configuration.playoutTargetFrames == 0 ? 0 : 1)`. The ternary produces 1 for any nonzero frame
count regardless of what the target actually is — almost certainly wrong. Should pass
`configuration.playoutTargetFrames` (or a properly derived packet count) directly.

**[AUDIO-036]** In `validAudioBuffers`, `buffer.mDataByteSize` (UInt32) is cast to Int without
bounds check before comparison. On 32-bit targets this overflows. Use
`Int(exactly: buffer.mDataByteSize) ?? …` or assert 64-bit platform.

**[AUDIO-046]** `DirectPeerRealtimeAudioGraph` allocates atomics with
`open_lola_atomic_u64_init` in the constructor but never calls a corresponding destroy/deinit
function. Memory is leaked and the atomic object is never properly torn down. Add a `deinit`
that calls the appropriate C destroy function.

### P1 — High Priority

**[AUDIO-001]** Force-unwrap `payloadBytes.baseAddress!` inside the audio render closure
(`DirectPeerRealtimeAudioGraph.swift:64`). If the buffer's `baseAddress` is nil (zero-count
slice), this crashes in the realtime thread. Guard and return early instead.

**[AUDIO-002]** Second force-unwrap `payloadBytes.baseAddress!` in `Data` initializer at line
143 in the same file. Same fix.

**[AUDIO-003]** `UnsafeMutablePointer(mutating: input)` creates a mutable alias to a const
pointer inside the render callback (line 404). Violates strict aliasing; undefined behaviour.
Use a scratch buffer instead.

**[AUDIO-004]** `memset` called on `outputScratch` inside `renderPlayout` (line 427). `memset`
is a system call that can block in pathological cases. Pre-zero the scratch buffer outside the
callback, or use the write-combining approach.

**[AUDIO-005..008]** `memcpy` calls at lines 460–544 calculate `sourceOffset` and
`destinationOffset` through multiplication without overflow guards. For large `frameCount *
channelCount * bytesPerSample` products, silent overflow produces wrong offsets. Add
`precondition` checks or use checked arithmetic.

**[AUDIO-010]** `nextInputFrame` / `nextOutputFrame` (plain UInt64, not atomic) read/written on
the realtime thread and the control thread (`stop()`). Data race. Replace with
`open_lola_atomic_u64` wrappers already present in `COpenLolaAtomics`.

**[AUDIO-012]** Force-unwrap `payloadBytes.baseAddress!` in `RealtimeAudioPayloadCaptureRing`
(line 154). Same pattern as AUDIO-001.

**[AUDIO-015]** In `captureInto`, after a guard on `destinationBaseAddress` exits early, the
`commitWrite` is skipped but the block was already registered in the ring, corrupting the ring's
invariant. Either move the guard before the `reserveWrite`, or call `abortWrite` in the guard
branch.

**[AUDIO-016]** Force-unwrap `payloadBytes.baseAddress!` in `RealtimeAudioPacketHandoff` (line
143) when constructing a `UdpPcmPacket`. Crash risk on empty slice.

**[AUDIO-017]** `enqueue` in `RealtimeAudioDueBlockPlayout` ignores the return value of
`ring.push(block)` (line 131). If the ring is full, the block is silently dropped without any
drop counter increment. At minimum, count the drop.

**[AUDIO-018]** `dropStalePackets` counts `originalCount - packets.count` as dropped. If
`packets` shrinks for reasons other than the filter (e.g., concurrent modification — though
unlikely), the count is wrong. Count removals in the filter body.

**[AUDIO-020]** Duplicate-detection in `enqueue` uses `packets.firstIndex(where:)` — O(n) on
the playout queue in the hot path. Use a `Set<SequenceNumber>` for O(1) lookup.

**[AUDIO-021]** `renderNextBlock` uses `packets.remove(at:)` — O(n) array mutation in the
realtime path. Use a `Deque` or the existing ring buffer for O(1) removal from front.

**[AUDIO-025]** `isRealtimePlaceholder` calls `PlaceholderDetection.matches` but does not
return the result — function always returns `false`. Fix the missing `return`.

**[AUDIO-029]** `MadiFullDuplexRuntime` appears truncated at line 300 mid-assignment. Code is
incomplete. Requires investigation and completion.

**[AUDIO-031]** Report IDs use `Int(Date().timeIntervalSince1970)` — truncates to 32 bits on
32-bit targets, overflows in 2038. Use `UUID().uuidString` or `Int64`.

**[AUDIO-033/034]** Channel mapping uses `enumerated().enumerated()` producing confusing double
index. The inner `guard outputChannel < configuration.channelCount` is always true by
construction. Remove the redundant guard; fix the enumeration to use a single index.

**[AUDIO-035]** `copySelectedInterleavedChannels` calculates `destinationFrameStride =
shape.channelCount * bytesPerSample` but does not validate frame alignment. If `channelCount`
or `bytesPerSample` is zero, produces a zero stride leading to silent no-op or infinite
memcpy.

**[AUDIO-037]** In `copySelectedAudioBuffers`, nil `mData` pointers are silently skipped via
`continue`. The copy loop finishes with success even when all channels were skipped. Caller
should be told no data was copied.

**[AUDIO-039]** `validateUniqueChannelIndices` uses `requirePositive(channel.stableSourceIndex
+ 1, …)` to test non-negativity. The +1 makes it test `>= -1`, not `>= 0`. Use a direct check
`requireNonNegative(channel.stableSourceIndex, …)`.

**[AUDIO-040/041]** `metrics.rxBuffer` is constructed as `Optional` from a map over an optional
policy (nil when no policy). Downstream code assumes it's non-nil and calls `.observe()` on it
unconditionally. Either make the policy non-optional or add a nil guard everywhere it is used.

**[AUDIO-043]** In `directPeerRealtimeAudioIOProc`, `guard inClientData != nil else { return
noErr }` silently discards the render cycle on nil context. Should assert in debug, log in
release, not return `noErr` (which tells CoreAudio "all good").

**[AUDIO-045]** `elapsedMicroseconds` uses `end >= startNanoseconds ? end - startNanoseconds :
0`. Host clock is monotonic under normal conditions, but clock resets (e.g., NTP slew) can
cause it to go backwards. Use `max(0, Int64(end) - Int64(startNanoseconds))` with signed
arithmetic and saturating clamp.

**[AUDIO-047]** `validInterleavedSource` validates channel indices are in range but not unique.
Two channels mapping to the same source channel are accepted silently. Add a `Set`-based
uniqueness check.

**[AUDIO-049]** `RealtimeAudioPayloadCaptureRing` pre-allocates `capacity * shape.byteCount`
bytes. No overflow guard. Add `precondition(capacity <= Int.max / max(1, shape.byteCount))`.

**[AUDIO-052]** `AudioLoopbackRun` adds a blocker when `inputUID != outputUID`. This enforces
same-device for loopback, which is correct for the loopback use case, but the blocker message
says "devices must match" — not self-explanatory for operators who don't understand loopback.
Improve the message.

**[AUDIO-054]** `packetAgeMicroseconds` returns 0 when `receivedAtHostTimeNanoseconds <
senderHostTimeNanoseconds` (clock skew). This silently hides age information. Log a warning and
return a sentinel or use absolute delta.

### P2 — Code Quality

**[AUDIO-011]** `increment()` calls `open_lola_atomic_u64_fetch_add` and discards the result.
Add `@discardableResult` to the wrapper or use `_ =` with a comment explaining why the value
is not needed.

**[AUDIO-022]** `fourCharacterCode` in `CoreAudioInventoryReader` has an unreachable code path.
Simplify to single return.

**[AUDIO-042]** `requireRealtimeNonEmpty`, `requireRealtimePositive`, etc. are copy-pasted
across multiple files. Consolidate into `ValidationPrimitives` as a generic function taking a
description string.

**[AUDIO-044]** `_ = inDevice` and similar unused-variable ignores in the C callback shim
should be replaced with `_ in` parameter naming or proper `@discardableResult`.

**[AUDIO-051]** `storage.initializeMemory(as: UInt8.self, repeating: 0, …)` is semantically
identical to `memset`. Use `memset` directly for clarity or add a comment explaining why the
Swift API is preferred.

---

## 2. Network / UDP Transport (NET)

### P0

**[NET-003/004]** `readUInt16LE` and `readUInt32LE` in `UdpPcmPacket` access
`bytes[offset+1..+3]` without bounds checking. Malformed network packets crash the process.
Replace with bounds-checked accessors that throw on out-of-range offsets.

**[NET-006]** `receiveDatagramIfAvailable` checks `errno` after `recv()` but does not save it
immediately — another syscall between recv and the check can clobber it. Save errno
immediately: `let savedErrno = errno` before any other call.

**[NET-013]** `reassembledPayload` in `UdpPcmV2Packet` uses `replaceSubrange` without
validating that `sourceStart + fragmentFrameByteCount` does not exceed the source buffer
length. Overflow → crash. Add explicit bounds check.

**[NET-019]** NAT keepalive sequence in `NatFriendlyRouteRunner` uses the same UInt32 counter
as send/ack tracker without wrapping guard. After 2^32 packets the sequence wraps and all
subsequent acks are misidentified. Use 64-bit sequence or explicitly mask/reset.

**[NET-029]** Fragment count in `UdpPcmV2FragmentPlanner` is calculated with ceiling division,
but `channelsPerFragment` uses floor division. The last fragment may be assigned fewer channels
than expected, leaving some channels unaccounted for. Add an assertion that
`sum(channelsPerFragment * fragmentCount) == totalChannels`.

### P1

**[NET-001/002]** `readUdpMediaUInt16LE` / `readUdpMediaUInt32LE` in `UdpMediaTransport` use
`precondition` for bounds checking on untrusted network data. In release builds, failed
preconditions crash. Replace with `guard index + n <= data.count else { throw … }`.

**[NET-005]** Same issue in `UdpPcmV2Packet.readV2UInt16LE`.

**[NET-007]** `errno` captured after checking `sent < 0` in socket send path; another call
before the capture overwrites errno. Save immediately after send().

**[NET-008]** In `fcntl` call sequence, first call's errno is overwritten by second call if
first succeeds. Save errno after each call independently.

**[NET-010]** `UdpPcmPacket.decode` rejects `sentAtNanoseconds == 0` as invalid, but the
silence-packet factory can produce `sentAtNanoseconds = 1` to distinguish silence from zero.
The validation is inconsistent; document the convention or adjust the check.

**[NET-012]** `fragmentPayloadBytes` in `UdpPcmV2Packet` uses `memcpy` with
`sourceStart + fragmentFrameByteCount` without overflow/bounds check. Add guards.

**[NET-014/015]** `INADDR_ANY.bigEndian` hardcoded instead of `htonl(0)`. Use `in_addr(s_addr:
INADDR_ANY)` with correct byte-order semantics. `inet_addr("127.0.0.1")` should be replaced
with `inet_pton` for consistency and IPv6 readiness.

**[NET-018]** NAT keepalive interval is hardcoded at 100 ms. Expose as a configuration
parameter; different NAT devices have different mapping timeouts.

**[NET-020]** Sequence number delta computed with wrapping subtraction then cast to signed Int
before comparison. Unsigned-to-signed truncation can misidentify a wrap-around as a negative
delta. Use explicit modular comparison.

**[NET-022]** Route validation checks `sampleFormat` but does not account for differing
`bytesPerSample` between int16 and float32. Payload size validation downstream can mismatch.

**[NET-023]** `usleep()` called with a `UInt64` cast to `useconds_t` (UInt32). For delays
> 4 billion µs this silently truncates. Use `nanosleep` or decompose into multiple `usleep`
calls.

**[NET-024]** `waitForConnectedEcho` times out after 1 second but does not exit early on socket
errors (ECONNREFUSED etc.). Add error-code inspection in the receive loop.

**[NET-025]** `NetworkDiagnostics` always sets verdict to `.partial` regardless of ping/
traceroute success. The verdict never reaches `.pass`. This means the diagnostic subsystem can
never certify a clean network path. Fix the logic to set `.pass` when all probes succeed.

**[NET-027]** `inet_ntop` return value (pointer) not checked for NULL in
`NatFriendlyRouteHelpers`. NULL indicates conversion failure; should fall back to raw numeric
representation.

**[NET-028]** Peer registrations in `NatRendezvousRelayRunners` use peerID as dictionary key;
duplicate registrations silently overwrite earlier entries. Log a warning or reject duplicates.

**[NET-030]** `Darwin.close()` return value ignored in socket teardown. While `close()` rarely
fails, the error can indicate a flushed write failed. At minimum, assert in debug builds.

**[NET-032]** `try?` in `looperLoop` swallows all exceptions silently. Use `try` and log errors
to the trace system.

**[NET-033]** After defer-registering socket `close()`, the socket is still referenced before
the defer fires. If an error triggers defer early, the socket may be closed while still in use
by the direct traversal path.

**[NET-035]** Jitter calculation uses a fixed 16-sample window regardless of how many packets
were actually received. For runs with < 16 packets, the metric is artificially low. Gate the
metric on minimum sample count.

### P2

**[NET-011]** `UdpPcmV2Packet` appends 12 zero-bytes of undocumented padding (line 159). Add a
named constant and comment explaining the wire format requirement.

**[NET-016]** `inet_addr()` calls in `UdpPcmLoopbackSocketRunners` should be replaced with
`inet_pton` throughout for consistency.

**[NET-031]** `packetIntervalNanoseconds` and `playoutTargetMicroseconds` both compute
`framesPerPacket / sampleRateHertz` independently. Extract to a single `packetDuration()` helper.

**[NET-034]** `max(1, packetCount)` in `UdpPcmRouteRunConfiguration` enforces a floor at
runtime rather than at construction. Validate at init and remove the runtime clamp.

---

## 3. P2P Mesh & Session (P2P)

### P0

**[P2P-001]** `DirectPeerAVFoundationRawFrameSource.nextFrame()` never returns the frame — the
`return` statement is missing inside the `#if canImport(AVFoundation)` block (line 79-85).
Function always returns nil. Add `return collector?.latestRawFrame()`.

**[P2P-002]** `DirectPeerAVFoundationRawFrameSource` is `@unchecked Sendable` but has mutable
`session` and `collector` properties accessed without synchronization. Lock or move to an actor.

**[P2P-006]** `sentDatagrams` and `receivedDatagrams` in `DirectPeerSessionSocketRunner` are
plain Int counters mutated by concurrent send/receive operations. Replace with atomic Int64 or
serialize behind a lock.

**[P2P-038]** `videoSequence &+= 1` wraps a UInt64 without any reassembly-side guard. When the
counter wraps, the reassembler cannot distinguish new frames from very old ones. Add a epoch
bit or seqno window validation in the reassembler.

### P1

**[P2P-003/014]** `metrics.audioPayloadsCaptured` is assigned the value of
`metrics.audioPayloadsSent` at line 274, then overwritten at line 333 with the correct value.
The first assignment is dead code. Remove it.

**[P2P-004]** `configuration.durationSeconds * 1_000_000_000` overflows Int for durations >
~9.2 seconds on 32-bit or if Int is 32 bits. Use `Int64` or `UInt64` for nanosecond
computation.

**[P2P-005]** Peer shutdown errors are silenced with `try?` in `DirectP2PLocalhostSmoke`. Use
`try` and log; resource leaks must be visible.

**[P2P-007]** `isClosed` flag in `DirectPeerSessionSocketRunner` is read-modify-written without
atomic protection. Double-close of the file descriptor is possible. Use `os_atomic` or a
`DispatchSemaphore` to guard the close path.

**[P2P-008]** Video frame sequence validation (`proof.latestFrame.sequenceNumber <
proof.firstFrame.sequenceNumber`) does not handle UInt64 wrap-around. Use modular comparison
matching the transmit side.

**[P2P-010]** In `PeerSessionRunner.localhost()`, if `allocatedControlEndpoint()` throws after
transports have been bound, the bound transports are not cleaned up. Add a defer block that
closes transports on error.

**[P2P-011/026]** `audioRouter` is created twice in `PeerSessionRunner` (lines 241 and 267).
The first instance is leaked. Remove the duplicate construction.

**[P2P-016]** `channelCSV()` in `DirectPeerTwoPeerRunPlan` produces an empty string for
`count == 0`. Downstream CSV parsing will fail. Add a guard that throws for count == 0.

**[P2P-017]** Guard at line 97 of `DirectPeerSessionAVSocketRunner` requires
`configuration.manual.packetCount == 1`. This constraint is undocumented and seems incorrect
for multi-packet AV runs. Investigate and document or remove.

**[P2P-021]** Preflight check errors are only thrown for the `.fastest` profile. For other
profiles, device issues are silently ignored. Propagate errors for all profiles.

**[P2P-023]** `isLoopback()` is defined identically in both `DirectPeerTwoPeerRunPlan` and
`MacToMacRouteCertification`. Consolidate into a shared extension on `String`.

**[P2P-025]** Error validation uses OR across counters (`any < 0`) but the error message says
"all counters invalid". Either validate individually with per-field messages, or correct the
message.

**[P2P-029]** `liveVideoSource.start()` can fail but errors are not propagated; the defer
cleanup block can double-stop a never-started source. Check the start result and skip the stop
on failure.

**[P2P-032]** In `DirectPeerMeshRuntimeReport`, a `map` over routes calls `runRoute()` which
can throw. If one route fails, the entire mesh run aborts with no partial results. Use
`compactMap { try? }` with explicit failure tracking, or `TaskGroup` with per-route error
capture.

**[P2P-035]** Synthetic audio payload generation inside the AV loop uses `videoSequence` as the
audio counter. Audio and video sequence spaces are merged. Use separate counters.

**[P2P-036]** `DirectPeerSessionEvidence.digest` compactMaps out nil fields before hashing.
Which fields are nil can vary across sessions, making the digest structure non-deterministic and
meaningless for comparison. Include all fields (use empty string for absent values).

**[P2P-039]** `DirectPeerTwoPeerLocalRunReport` verdict is always `.partial` — both branches of
the ternary set `.partial`. Should set `.pass` when execution succeeds with exit code 0.

**[P2P-043]** AVCaptureSession configuration is not rolled back on partial init failure (between
`beginConfiguration` and exception). Call `commitConfiguration` + teardown on error.

**[P2P-045]** Off-by-one in video frame proof: when `receiveProof` is nil on first iteration,
`framesProven` is set to `acceptedFrames` which may be 1, creating a gap if subsequent frames
arrive out of order. Track the proof start frame explicitly.

### P2

**[P2P-013]** Repetitive optional-cast pattern for `previewSink.close()` in defer blocks.
Extract to a protocol extension `Closeable` with a default no-op implementation.

**[P2P-015]** Report ID `"m06-direct-p2p-localhost-\(Int(Date().timeIntervalSince1970))"` can
collide under concurrent runs in the same second. Use UUID or a monotonic counter.

**[P2P-019]** `metadataSnapshot` limits capabilities to `.prefix(2)`. This may hide channel
count > 2 from the snapshot consumer. Document the intent or remove the prefix.

**[P2P-028]** `bindLoopback()` and `bindIPv4()` share nearly identical socket setup code.
Extract common logic into `makeConfiguredSocket(port:timeout:nonBlocking:) throws -> Int32`.

**[P2P-030]** Same timestamp-based ID collision risk as AUDIO-031 in `DirectP2PLocalhostSmoke`.

---

## 4. Video (VID)

### P0

**[VID-004]** `RawBGRAAppKitPreviewWindow.endSubmit()` acquires `taskLock.lock()` but has no
`defer { taskLock.unlock() }`. If the code between lock and the manual unlock throws or
returns early, the lock is never released → deadlock. Add `defer { taskLock.unlock() }`.

**[VID-009]** `readVideoTransportUInt32LE` and `readVideoTransportUInt64LE` access
`bytes[offset+3]` / `bytes[offset+7]` without bounds checking. Malformed video transport
packets crash the process. Add explicit bounds guards returning nil/throwing.

**[VID-021]** `dropOldestActiveFrame()` iterates `activeFrameOrder` with a cursor while
`resetActiveFrameOrderIfEmpty()` can concurrently modify it. This is a shared-mutable-state
race. Synchronize on a single lock or restructure to avoid concurrent modification.

**[VID-031]** `VideoTransportRunner` loopback socket binds with `port: 0` at line 41 then reads
`boundPort()` after `setNonBlocking()`. The order dependency between binding and the
nonblocking call is not documented and could break if the syscall sequence changes.

**[VID-038]** `configuration.isLoopbackSelfProbe` is accessed in `VideoTransportRunner` (line
37) but this property does not exist in `VideoTransportRunConfiguration`. This is a crash at
runtime on any loopback video probe. Add the property or remove the access.

### P1

**[VID-001]** `rawFrameBytes()` returns empty `Data` for planar pixel buffers without an error.
Callers cannot distinguish an empty-frame success from a conversion failure. Return `nil` or
throw.

**[VID-002]** `bytesPerPixel` hardcoded to 4 in `rawFrameBytes()`. If a non-BGRA capture
format slips through, frames are silently corrupt. Assert or check the pixel format at entry.

**[VID-003]** `submitPending` flag in `RawBGRAAppKitPreviewWindow` is checked and then written
without atomics or a lock. Race between the check (line 64) and concurrent `endSubmit()` calls.
Use `os_atomic_cmpxchg` or a serial DispatchQueue.

**[VID-006/007]** Fragment bucket insert result is ignored at lines 224 and 271 of
`VideoTransportReassembly`. Duplicate fragments increment the duplicate counter correctly but
also trigger a second (no-op) insert, masking the logic. Check the result and only increment
on confirmed duplicate.

**[VID-008]** `readVideoTransportUInt16LE` reads `bytes[offset+1]` without bounds check. Add
guard.

**[VID-010]** `VideoTransportPacket` does not validate that `payloadOffset` is aligned to
`maxFragmentPayloadBytes * fragmentIndex`. Out-of-order or gap fragments can reassemble to
garbled frames.

**[VID-012]** `AVCaptureDevice` authorization semaphore timeout returns `.unknown` status
without indicating whether the timeout or denial caused it. Distinguish timeout from denied by
storing a `DispatchTimeoutResult` before the wait returns.

**[VID-013]** `AVCaptureDeviceInput` is created but not retained outside the capture session.
If the session is released, the input (and its delegate callbacks) become dangling. Retain the
input explicitly.

**[VID-014]** `Thread.sleep(forTimeInterval:)` is called in `VideoCaptureRunner` on the capture
dispatch queue. This blocks the queue thread, starving other capture operations. Replace with
`DispatchQueue.asyncAfter` or a semaphore with timeout.

**[VID-015]** Expired-frame detection in the frame reassembler uses `receivedAt &-
firstFragmentReceivedAt`. If `receivedAt < firstFragmentReceivedAt` (host clock adjustment),
the wrapping subtraction yields a huge positive number, keeping the frame alive indefinitely.
Use signed delta with saturation.

**[VID-016]** Frame pacing in `VideoTransportRunner` sleeps for a fixed interval after each
frame with no compensation for processing time. Frame timing drifts proportionally to encoding
latency. Use an absolute deadline-based sleep.

**[VID-017]** `queue.contains(frame)` in `VideoOutputRenderer` is O(n) and unreliable for
confirming successful append. Remove the check; instead verify queue count incremented.

**[VID-019]** `frameCount` rounding mode (`.toNearestOrAwayFromZero`) differs from
`VideoTransportRunner` which rounds differently. Both should use the same rounding function to
produce coherent expected counts.

**[VID-020]** `renderOutputAccountingMismatch` only checks `framesOutput > framesRendered`, not
that the implied drop counts are non-negative. A negative implied drop count would silently
pass validation.

**[VID-023]** `Data.subdata(in: payloadOffset ..< payloadOffset + maxFragmentPayloadBytes)` in
`VideoTransportPacket` can crash if the range exceeds the data bounds. Add an explicit bounds
check and throw `VideoTransportPacketError.payloadOutOfBounds`.

**[VID-025]** Magic number `% 16 == 15` for fragment drain trigger in `VideoTransportRunner`
is unexplained. Add a named constant `fragmentDrainInterval = 16` with a comment.

**[VID-026]** Missing stream in `VideoTransportMultiStreamRuntime` is silently ignored.
Log a warning and count the drop.

**[VID-028]** `latestRawCapturedFrame` stale reference persists after the frame is dropped from
`rawFrameIndex`. Clear `latestRawCapturedFrame = nil` in the drop path.

**[VID-030]** `dropOlderIncompleteFrames()` removes frames from the bucket but not from
`activeFrameOrder`. Orphaned keys accumulate, causing memory growth proportional to total frames
dropped. Remove from both collections atomically.

**[VID-033]** `configureAVFoundationDevice()` checks frameRate support but returns without
setting the frame rate if unsupported — and without throwing an error. Throw
`VideoCaptureError.unsupportedFrameRate`.

**[VID-035]** `observedQueueDepth` is incremented before `removeFirst()` completes in
`VideoOutputRenderer`. If called concurrently (even if rare), the metric is transiently wrong.
Post-increment after the removal.

**[VID-037]** `bucket.insert(fragment)` return value discarded; `metricsStorage.duplicateFragments`
only incremented when the key already existed in `activeFrames`, not when the set already
contained the fragment. Fix to match the actual insertion logic.

**[VID-040]** `Task.detached` completion in `RawBGRAAppKitPreviewWindow` is never awaited.
`submitPending` reset races with `endSubmit`. Use a serial actor or structured concurrency.

**[VID-041]** `requiredVideoCaptureDouble()` accepts 0 and negative values (checks `>= 0`
instead of `> 0`). Inconsistent with integer variant which requires `> 0`.

**[VID-042]** `resetActiveFrameOrder()` calls `removeAll()` without resetting
`activeFrameOrderCursor` to 0, leaving the cursor pointing past the end of the now-empty
array.

**[VID-043]** `Data(bytes[payloadStart..<bytes.count])` does not validate
`payloadStart <= bytes.count`. When `payloadStart > bytes.count`, produces empty Data silently.

**[VID-045]** Bandwidth validation allows `estimated == budget`. Should use strict `<` if the
intent is to stay under budget, not at the limit.

**[VID-049]** `keepsContinuity()` allows sequence wrap-around silently. Document the expected
behaviour at wrap, or use modular comparison.

### P2

**[VID-005/039]** `bytesPerPixel()` is defined by string-matching in two separate files
(`MultiVideoStreams` and `VideoTransportPacket`) with different fallback values (3 vs 1).
Consolidate into a single method on `VideoPixelFormat`.

**[VID-011]** `trimRawFrameArtifactIfNeeded()` rebuilds the entire offset array on removal —
O(n). Use a circular buffer / `Deque` backed by a base-offset variable.

**[VID-018]** `estimatedBandwidthMegabitsPerSecond` returns 0 for disabled streams; the
`canSendMedia` check before computing is dead code. Remove or restructure.

**[VID-024]** `MultiVideoPriorityDropper.select()` sorts the full frame array each call. Use a
min-heap or partial sort (nth_element equivalent) for top-k selection.

**[VID-029]** `videoTransportPercentile()` rounds up instead of interpolating. For small sample
counts the percentile value is inflated. Implement standard percentile interpolation.

**[VID-034]** `encoded()` calls `validate()` but validation failure propagates without any
field-level context. Log which field failed before re-throwing.

**[VID-044]** Duplicate code for saving raw frame data and metadata in `captureOutput()`.
Extract into `saveRawFrame(_:at:)` helper.

**[VID-046]** `LatencyBenchmark.measure()` results not sanity-checked (e.g., negative duration
after clock skew). Add a post-measurement assert `duration >= 0`.

**[VID-050]** Duplicate `NSImage` creation pattern in `RawBGRAAppKitPreviewWindow`. Consolidate
into a single `makeNSImage(from:size:)` factory.

---

## 5. Protocol / Session Negotiation (PROTO)

**[PROTO-001] P1** `SessionControlMessage.apply()` does not validate state transitions. A peer
can jump from `idle` to `accepted` without going through `hello → capabilities → proposed`.
Add an explicit state-machine transition table and throw on invalid transitions.

**[PROTO-002] P1** Frame rate validation in `SessionNegotiation` only rejects denominator == 1,
not denominator == 0 (division by zero) or negative denominators. Add
`guard denominator > 0 else { throw … }`.

**[PROTO-003] P2** MTU validation error message conflates "min > max" with "out of range".
Split into two distinct error cases with clear descriptions.

**[PROTOCOL-001] P1** `validateVideoStream` allows `framerate.denominator <= 0`. Enforced only
for ≠ 1 case. Same fix as PROTO-002.

---

## 6. Control Subsystem (CONTROL)

### P0

**[ATEM-001]** `withMemoryRebound()` in `AtemReadOnlyControl` casts `sockaddr_in*` to
`sockaddr*` unsafely (line 284). If the buffer is smaller than `sockaddr` or misaligned,
undefined behaviour. Use `withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { … } }`.

**[ATEM-002]** `fdSet` bit manipulation at lines 474–476 computes `Int(fd) / bitsPerWord` and
`Int(fd) % bitsPerWord`. If `fd >= FD_SETSIZE` (typically 1024), the index is out-of-bounds.
Add `precondition(fd < FD_SETSIZE)`.

### P1

**[ATEM-003]** Errno not saved before second operation after `socket()` fails. Save errno immediately.

**[ATEM-004] P2** `fdSet` in `AtemReadOnlyControl` and `oscCueFdSet` in `OscCueHelpers` are
identical fd_set manipulation functions. Consolidate into a shared C-shim helper.

**[LIGHTING-001] P1** `requireLightingPassWorkflowText()` throws with a wrong error type for
the empty-field case. The enum case and the throw site are mismatched.

**[LIGHTING-002] P2** `universesObserved == [probe.request.universe]` requires ordered exact
match. Use `Set(universesObserved) == Set([probe.request.universe])` for order-independent comparison.

**[OSC-001] P1** `oscCueFdSet` uses `withUnsafeMutableBytes` on `fd_set` assuming raw buffer
layout matches `Int32` array. This is platform-dependent and unverified. Use the dedicated
`FD_SET`/`FD_ISSET` macros via a C shim.

**[OSC-002] P1** `readOscString()` advances cursor twice with the same alignment loop
condition. The second loop is at least partially redundant; verify correctness against the OSC
1.0 spec for all aligned/unaligned positions.

**[OSC-003] P1** `OscCueProbe` reads timestamp as a string and converts with no error
propagation on invalid (non-numeric) values. Validate before conversion and throw on failure.

**[CONTROL-001] P2** `packetCapture.captured` gated on `configuration.captureTool !=
"not-run"` string comparison. Use an enum with a `.notRun` case.

**[CONTROL-002] P1** `validateWorkflow()` returns early for non-pass verdicts, skipping
`oscCueReportId` validation on pass. Logic is inverted — placeholders should be caught on pass.

**[CONTROL-003] P1** `placeholderSensitiveFields()` coalesces nil `protocolName` to `""`. An
empty string passes the placeholder check silently. Treat nil as a validation failure.

---

## 7. LoLa Compatibility Connector (LOLA)

### P0

**[LOLA-001]** `usleep()` in `LoLaSocketUdpMediaTransmitter` is not retried on EINTR. A
signal delivery at the wrong moment causes an undersized sleep, sending audio too early. Wrap
in a `do { … } while (errno == EINTR)` loop.

**[LOLA-005]** `inet_ntop` writes to `&buffer` without validating buffer capacity against
`INET_ADDRSTRLEN`. If the buffer is too small, stack corruption. Always use a `[CChar](repeating:
0, count: Int(INET_ADDRSTRLEN))` buffer.

**[LOLA-007]** `bytesTransferred` is passed by value into `receiveLoLaControlMessage()`, so the
function's mutations are discarded. The call site's `bytesTransferred` stays at 0. Pass as
`inout` or return a tuple.

### P1

**[LOLA-002]** `sleepUntil()` uses `Date().addingTimeInterval()` which is wall-clock based. If
the system clock is adjusted during sleep, the deadline is wrong. Replace with
`DispatchTime.now() + .nanoseconds(…)` using the monotonic clock.

**[LOLA-003]** `retryLoLaUdpMediaSend()` retries on any send error. `EMSGSIZE`,
`ECONNREFUSED`, `ENOBUFS` should not be retried — they indicate structural failures. Distinguish
transient (EAGAIN/EWOULDBLOCK) from permanent errors.

**[LOLA-004]** `address.pointee.sa_family` read from raw pointer without verifying the buffer
is at least `sizeof(sockaddr)` bytes. Validate buffer size before the pointee access.

**[LOLA-006]** `inet_ntop` null-terminator assumed but not verified. If it is absent (protocol
violation), garbage data is included in the IP string. Add explicit null terminator before
string construction.

**[LOLA-008]** Inconsistent error propagation pattern using `.failure` tuple fields. Some call
sites check for failure, others do not. Standardize: either use `Result<T,E>` everywhere or
use throws.

**[LOLA-009]** `while parsed.parsed.name == "/MESG_CHECKLOLASTATUS"` has no iteration limit or
deadline. A misbehaving peer can stall the handshake indefinitely. Add a maximum retry count
or an absolute deadline.

**[LOLA-010]** TCP socket descriptor leaks on connection failure in
`LoLaTcpControlExchangeRuntime`. Add `defer { Darwin.close(descriptor) }` at the top of the
function body.

**[LOLA-011]** `isLoLaReceiveTimedOutFailure()` gates the QuickConnect fallback. If receive
fails for non-timeout reasons (network error, malformed data), the fallback is still triggered,
masking the real error. Add a separate path for non-timeout failures.

**[LOLA-012]** Fragment reassembly in `LoLaCompatibilityMediaEnvelopeValidation` does not
verify that fragment indices are sequential or form 0..n-1. Out-of-order or duplicate fragments
pass validation.

**[LOLA-013]** Video fragment storage auto-creates entries for any arriving fragment regardless
of whether a prelude arrived. Should require prelude before accepting fragments; otherwise stale
fragments from a prior frame corrupt the new frame.

**[LOLA-014]** Hardcoded offsets `0x2A` and `0x21` in `LoLaCompatibilityMediaCodec` are never
validated against actual datagram size before dereferencing. Add bounds guards.

---

## 8. External Connector / Process Runner (EXTCONN)

### P0

**[EXTCONN-001]** Force-unwrap `buffer.baseAddress!` in `ExternalConnectorProcessRunner` (line
284). If the buffer is empty, crash. Guard with `guard let base = buffer.baseAddress else { …
}`.

**[EXTCONN-002]** `strdup()` allocations freed in defer, but if the body throws before
consuming them, the defer runs but any allocations made after the exception are leaked. Track
all allocations in an array and free all of them in the defer.

### P1

**[EXTCONN-003]** `deadlineDate` uses `addingTimeInterval(configuration.durationSeconds)`.
Negative `durationSeconds` produces a past date. Validate `durationSeconds >= 0` at input.

**[EXTCONN-004]** `kqueue` creation failure not validated before calling `kevent` on the
invalid descriptor. Check the return value of `kqueue()` and throw on failure.

**[EXTCONN-005]** `posix_spawn_file_actions_adddup2` and `addclose` return values not checked.
A failed file action causes the child process to inherit wrong file descriptors silently.
Check and throw on failure.

**[EXTCONN-006]** `status` computed property in `RunningExternalConnectorProcess` has a side
effect (calls `reapIfExited`). Computed properties with side effects violate principle of
least surprise. Rename to `reapAndGetStatus()` and make it a method.

**[EXTCONN-007]** `terminatedAfterDuration` is set to `running.isRunning` — but
`isRunning == false` means the process has already exited, which means it _did_ terminate
(before or at the deadline). The boolean is inverted. Should be `!running.isRunning`.

**[EXTCONN-009]** `attempts.first` with no non-empty guard in
`ExternalConnectorExecutablePreflight`. If `externalConnectorExecutableCandidates()` returns
empty, `attempts[0]` crashes. Add `guard !attempts.isEmpty else { throw … }`.

**[EXTCONN-011]** `posix_spawnattr_init` and `posix_spawn_file_actions_init` return Int but
values are not checked. Initialize and validate before use.

**[EXTCONN-012]** `controlPort`, `audioPort`, `videoPort` in `ExternalConnectorSession.init`
are not validated to be > 0. Port 0 means "any available port" to the OS, which is almost
never the intent here.

---

## 9. Timing / Jitter / RxBuffering (TIMING)

**[TIMING-001] P1** `MediaClock.hostTimeNanoseconds(forFrameIndex:)` converts frame delta via
floating-point intermediate, introducing cumulative rounding errors at high frame counts. Use
integer arithmetic: `frameIndex * nanosPerFrame.numerator / nanosPerFrame.denominator`.

**[TIMING-002] P1** `validateMonotonicHostTimes()` allows duplicate timestamps (checks `<=`
instead of `<`). Strict monotonicity requires `<`. Duplicate timestamps in clock data indicate
measurement errors and should be flagged.

**[TIMING-003] P1** `latencyTuningCandidateIsFaster()` uses string `reportId` comparison as
tiebreaker for floating-point latency values. If two floats differ only in the last ULP,
sort order depends on string content — not stable. Use a UUID-based stable ID, not reportId.

**[TIMING-004] P1** `RxImpairmentSimulator` duplicate packet simulation adds a second packet
at `arrivalMicroseconds += 10` but the sort on line 136 can reorder it before the original.
After inserting the duplicate, assert that the sorted order preserves the intended arrival-time
relationship.

**[TIMING-005] P2** Validation helpers `requireRxNonEmpty`, `requireDriftNonEmpty`,
`requireLatencyNonEmpty`, etc. are copy-pasted across Timing, Protocol, and Control. All
implement the same pattern: `guard !value.isEmpty else { throw .emptyField }`. Consolidate
into a single generic function in `ValidationPrimitives`.

**[TIMING-006] P2** `requireRxNonEmpty` throws `nonPositiveField` (wrong error type) for an
empty string. Should throw an `emptyField` case. Similarly `requireRxDouble` throws
`negativeField` for a non-finite double — should throw `nonFiniteField`.

**[TIMING-007] P2** Percentile ordering checks (`p50 <= p95 <= p99 <= max`) appear in
`validateProfilePacketAge`, `validateRxBenchmarkJitter`, and `validateLatencyTuningTiming` with
duplicated code. Extract to `validatePercentileOrdering(_ metrics: LatencyPercentiles)`.

**[TIMING-008] P2** `SPSCAtomicRing` relies on unsigned wrapping arithmetic for write-read
comparisons but does not document this assumption or validate that `capacity` is ≤ 2^63 (so
the difference never exceeds the signed range). Add a precondition and a comment.

**[TIMING-009] P2** Double-negative pattern `notTestedReason?.isEmpty == false` used throughout
DriftPlc and LatencyTuning files. Replace with `notTestedReason?.isEmpty != true` or use a
guard let with `!reason.isEmpty`.

**[TIMING-010] P2** `isDriftCertificationPlaceholder()` trims with `lowercased()` before exact
matching but does not strip whitespace. `" unknown"` or `"unknown "` would not match. Add
`.trimmingCharacters(in: .whitespaces)`.

**[TIMING-011] P2** `RxBufferAdaptiveController.observe()` boundary conditions for `jitterP99`
thresholds are undocumented (`>` vs `>=`). Add a comment specifying exact threshold semantics.

---

## 10. Core / CLI / Support (CORE)

**[CLI-001] P2** `OpenLolaCLI` has multiple try-catch blocks with near-identical JSON loading
patterns. Extract to `func loadJSON<T: Decodable>(_ type: T.Type, from path: String) throws -> T`.

**[CLI-002] P2** `DebugTrace` — verify it is not called from realtime audio paths; any logging
in the render thread is a realtime violation.

**[CLI-003] P2** `KeyValueArgumentParser` — unhandled edge case when a key appears multiple
times; last value silently wins. Document or error on duplicate keys.

**[PEERIDENT-001] P2** `PeerIdentity` — no validation that the identity string does not contain
characters that would break CLI argument parsing (spaces, quotes, semicolons).

---

## 11. SwiftUI App Layer (UI)

### P0 / Crash

*(No P0 UI crashes identified, but several P1 items that would prevent the app from functioning correctly.)*

### P1 — Broken UX / Wrong State / Logic

**[UI-013]** `@State captureReport` in `AppShellRootView` is declared but never assigned after
init. The packet monitor view is always empty. Wire it to the execution controller's live
capture output.

**[UI-015]** `AppExecutionController` weak-self termination handler accesses `self` after a nil
check but the check itself is performed on a different value. Fix the weak-capture pattern:
`guard let self else { return }`.

**[UI-017]** `AppLocalOperatorInventory.lastRefreshWarning` only surfaces the first error
(`inventoryErrors.first`). If multiple devices fail to enumerate, later errors are silently
dropped. Show all errors or at least log them.

**[UI-025]** 37 `@AppStorage` declarations in a single `AppShellSettingsView`. Extract to an
`AppSettings` `@Observable` class backed by `UserDefaults` so settings can be shared without
copy-pasting keys.

**[UI-026]** `sectionTitle` computed property in `AppShellRootView` returns the first matching
section with no fallback for an invalid `selectedSection`. Add a nil-coalescing default.

**[UI-028]** `AppExecutionController.runOneShot` assigns `self.process` without clearing the
previous process. Repeated calls leak process handles.

**[UI-029]** `IntField` silently rejects input `<= 0` with no visual feedback. Show a
`.help("Must be a positive integer")` modifier or use a validation border color.

**[UI-031]** `directPeerCommandFields.framesPerPacket` assigned from `Int` to `UInt32` without
range check. Large Int values silently truncate. Add explicit bounds guard.

**[UI-033]** `dryRunButton` calls `writePlan()` inline without checking the result or surfacing
errors to the UI. Wrap in a do-catch and update `lastError`.

**[UI-035]** `loadStoredDefaults()` called in `onAppear` after the view body has already
rendered with stale defaults. Move initial hydration to `init` or provide `Binding` default
values at the source.

**[UI-037]** `Process` termination handler in `AppExecutionController` accesses `weak self`
without checking `isRunning` state, causing a race where a completed run updates stale state.

**[UI-039]** `hydratePreviewState()` called immediately after `AppPreviewReceiverState()` in
`OpenLolaApp.init` overwrites all initial values. If hydration source is empty (first launch),
the app starts in an undefined state. Separate construction from hydration.

**[UI-043]** `AppSessionStateBanner` pulse animation restarts only on `onAppear` and `onChange`.
If the view is reused with the same state value, the animation stalls. Restart on `id`-based
identity change instead.

**[UI-047]** `Task.detached(priority: .userInitiated)` blocks on audio inventory enumeration
from `AppLocalOperatorInventory`. This is a background operation but incorrectly uses
`userInitiated` priority (high QoS), competing with UI rendering. Drop to `.utility`.

**[UI-049]** `CoreAudioInventoryReader` errors appended to `inventoryErrors` but only the first
is shown. Use a scrollable error list or a badge count.

**[UI-051]** Search filter in `AppPacketMonitorView` uses `lowercased()` without Unicode
normalization. NFC-normalized strings that look identical may not match. Use
`.localizedCaseInsensitiveContains`.

**[UI-055]** `loadStoredDefaults()` mutates an `@Observable` object from a non-Main-Actor
context. Wrap the mutation in `MainActor.run { … }`.

### P1 — UI Readability / Contrast

**[UI-008/009]** `.foregroundStyle(.black)` on button text over orange/amber backgrounds may
fail WCAG AA contrast ratio at certain display brightness levels. Use `.primary` or a
design-token color that adapts.

**[UI-021]** Track background `.white.opacity(0.05)` in `AppChannelMeterView` is nearly
invisible on dark backgrounds. Minimum `opacity(0.15)` or use `.quaternaryLabel`.

**[UI-023]** `TextField` background `.white.opacity(0.06)` in `AppConsoleChromeView` provides
insufficient contrast for the text cursor and placeholder text. Use at least `0.12` or a
semantic color.

**[UI-024]** Same issue in `AppPacketMonitorView` filter `TextField`.

**[UI-032]** Table header `.black.opacity(0.2)` background is invisible in dark mode. Use
`.fill(.background)` or a named color asset that adapts.

**[UI-034]** Status indicator circle is 6 pt. Below Apple HIG minimum touch target of 44 pt
and below minimum 14 pt for purely informational indicators. Increase to ≥ 10 pt or use a
text badge instead.

**[UI-036]** Selected sidebar row `Color.blue.opacity(0.28)` is too low-contrast for the
active-row indicator. Use `Color.accentColor.opacity(0.4)` minimum, or `List` selection
highlight via `.listRowBackground`.

**[UI-057]** Dimmed sidebar items at `opacity(0.45)` may be unreadable for low-vision users.
Consider `.disabled(true)` + `.contentShape(Rectangle())` instead of manual opacity.

### P2 — Slop / Dead Code / Structure

**[UI-001/002/003]** Hardcoded `/tmp/open-lola-mac-to-mac/` paths, `mac-a.local`,
`mac-b.local` strings in `AppOperatorArtifactViews`. Move to settings / AppStorageKeys.

**[UI-004]** Topology view animation started but `stopAnimation()` never called on view
disappear. Add `.onDisappear { animation.stop() }`.

**[UI-005/006/027]** Three `@State` properties in `AppLocalOperatorSurfaceView` duplicate
`remoteInventory` state with four `onChange` handlers to sync them. Replace with a single
Binding derivation.

**[UI-010]** `Color.black.opacity(0.28)` sidebar background hardcoded. Extract to
`AppDesignSystem.sidebarBackground`.

**[UI-012]** `prefix(200)` packet limit hardcoded. Make it a named constant
`AppConstants.packetMonitorCapacity = 200`.

**[UI-014]** Combine `Publisher` + `sink` for the elapsed timer in `AppShellRootView`. Refactor
to a SwiftUI `async` task with `for await tick in AsyncTimerSequence(…)`.

**[UI-038]** `captureReport` tone hardcoded to `.orange` when nil. Use `.secondary`.

**[UI-040]** `visibleStreams` and `selectedVideoStream` clamped with `max(1, …)` inline rather
than at the model level. Move validation into `AppShellStoredDefaults`.

**[UI-042]** Stream-type color in `AppPacketMonitorView` selected by `contains("audio")`
string. Use an enum `.streamType` from the data model.

**[UI-045]** Divider opacity `0.4` hardcoded. Use `AppDesignSystem.dividerOpacity`.

**[UI-046]** `AppDeviceCard` icon selected by `name.contains(…)` string matching. Use a lookup
table keyed on `AVCaptureDevice.DeviceType`.

**[UI-048]** `AppSessionStateBanner` elapsed time hidden when not running. Show last elapsed
time in secondary color rather than hiding it, so operators know how long the previous run was.

**[UI-050]** `.latencyHero` font 48 pt not responsive to Dynamic Type. Use `.largeTitle` +
`.bold()` or scale with `@ScaledMetric`.

**[UI-054]** `writePlan()` duplicated in both `AppTransportView` and `AppExecutionView`. Extract
to `AppExecutionController.writePlanOrLogError()`.

**[UI-056]** `ForEach` over tuples using `.0` as id. Extract to a named `Identifiable` struct.

**[UI-058/059]** Repeated `Binding { … } set: { … }` construction for audio preview toggle and
gain slider. Extract to `appPreviewBoolBinding(_:)` and `appPreviewDoubleBinding(_:)` helpers.

---

## 12. Python linux_connector (PY)

### P0

**[PY-004]** Control datagram parser silently passes malformed messages that don't start with
`/MESG_`. No validation that mandatory message types appear in the correct sequence. A crafted
datagram can slip through higher-level validation. Add strict sequence enforcement.

**[PY-021]** In `MediaReassembler.add()`, when `expected_size == 0` (from multi-fragment
prelude with wrong hint), the fragment overflow check `end > expected_size` is never triggered.
Fragments can silently overflow. Validate `expected_size > 0` before accepting fragments, or
treat 0 as "unknown" with strict per-fragment bounds tracking.

### P1

**[PY-001]** `assert proc.stdout is not None` in `npcap_udp_relay.py`. Asserts are disabled
with `-O`. Replace with `if proc.stdout is None: raise RuntimeError(…)`.

**[PY-002]** `proc.terminate()` in the finally block has no SIGKILL fallback. Replace with
`proc.terminate(); proc.wait(timeout=3); proc.kill()` pattern.

**[PY-003/013]** `udp_recvfrom` and `udp_sendto` fall back to `asyncio.sleep(0.001)` spin
loops when `sock_recvfrom`/`sock_sendto` are unavailable. This adds ≥ 1 ms latency per
packet. Use `loop.add_reader()` callback instead.

**[PY-005]** `value.encode("ascii", errors="replace")` silently replaces invalid characters.
Use `errors="strict"` and validate protocol strings at the source.

**[PY-006]** `struct.unpack_from("<IIIII", payload, 0x0C)` uses an implicit hardcoded offset.
Define `MEDIA_HEADER_OFFSET = 0x0C` as a named constant with a comment linking to the wire
format spec.

**[PY-007]** `MediaReassembler.add()` auto-initializes a frame when `frame_id is None` for
audio. This hides missing prelude for audio — a protocol violation passes silently. Add explicit
differentiation.

**[PY-008]** IP header packing in `ethernet.py` uses a format string without named field
references. The format is fragile to field order changes. Add an inline comment mapping each
format specifier to its wire field name.

**[PY-010]** `ProcessAudioCapture` leaves the subprocess alive if `read_block()` raises after
a successful `start()`. Add `async with` or explicit `aclose()` on exception in `read_block`.

**[PY-011]** `getattr(backend, "aclose", None)` duck-typing for cleanup. Define an
`AudioBackend` Protocol with `aclose()` and type-check at construction.

**[PY-012]** `frames_per_callback = 0` silently disables external pacing. This is a valid
sentinel but not documented. Add a comment and a log warning when the fallback path is taken.

**[PY-015]** `tags == "sdiisdiiii"` hardcoded string for OSC tag sequence validation. Define as
`QUICKCONN_TAG_SEQUENCE = "sdiisdiiii"` with a protocol reference comment.

**[PY-017]** `_wait_until` busy-spins with `asyncio.sleep(0)` for sub-ms precision. This wastes
CPU on every send. Accept that Python cannot achieve sub-ms timing without a kernel timer, and
document the precision ceiling.

**[PY-018]** QuickConn ACK applies the Bayer mirror only on receive, not on send. Protocol
asymmetry can cause a mismatch with OSC15-dialect peers. Review and apply symmetrically.

**[PY-020]** `MediaSettings.from_fields()` catches `ValueError` with a generic message. Re-raise
with `raise ValueError(f"invalid numeric field {key}={value!r}") from e` to preserve the
original exception.

### P2

**[PY-009]** `phases` list in `MultiToneAudioCapture` is shared state modified across
coroutine calls. Document that this is intentionally single-threaded async state, not
thread-safe.

**[PY-014]** `SO_REUSEPORT` failure in `make_udp_socket` silently ignored. Add a `logging.warning()`
call when the option cannot be set.

**[PY-016]** `_audio_tx_enabled` asyncio Event and `connector.audio_signal_requested` boolean
are parallel state for the same fact. Remove the boolean and use the Event as single source of
truth.

**[PY-019]** `DEFAULT_MAX_FRAME_BYTES = 16 MB` hardcoded. Expose as a CLI parameter or at
least log a warning when a frame exceeds 8 MB.

**[PY-022]** `getattr(args, "wait_for_remote_test_signal", False)` pattern duplicated 4 times.
Add the flag to all affected argument parsers explicitly.

---

## 13. Swift Connectors — JackTrip / NMP / UltraGrid / Package (CONN)

**[CONN-001] P1** JackTrip queue depth `-q 4` and redundancy `-r 1` hardcoded. Expose as
`JackTripRunConfiguration` fields.

**[CONN-002] P1** JackTrip peer audio port falls back to local audio port. This will fail for
cross-network sessions. Require explicit peer port.

**[CONN-003] P1** NMP workflow error classification mixes `emptyField` / `duplicateArgument` /
`unknownArgument` codes. Standardize error enum to match the actual failure condition.

**[CONN-004] P1** NMP defaults to `ExternalConnectorKind.allCases` when `--connectors` is
absent. This silently launches all connectors. Add an explicit required flag or use a safe
single-connector default.

**[CONN-005] P1** UltraGrid `-P` port string built without port validation. Validate all four
port numbers are in range [1, 65535] before constructing the argument string.

**[CONN-006] P2** UltraGrid default device names (`testcard`, `gl`, `coreaudio`) are
hardcoded. Expose as configuration options with platform-appropriate defaults.

**[CONN-007] P0** NMP workflow blocks all `.pass` verdicts via
`throw ExternalConnectorValidationError.realWorldPassNotAllowed`. This means no NMP session
can ever succeed. Investigate whether this is intentional scaffolding and either remove or
gate on a `--allow-pass` flag.

**[CONN-008] P1** `Package.swift` targets macOS 14+ only. No explicit Linux support is declared
but `linux_connector` is a first-class component. Add a `#if os(Linux)` note or separate
library target for Linux-compatible code.

**[CONN-009] P2** `atomic_compare_exchange_strong_explicit` in `COpenLolaAtomics.c` uses
`memory_order_acq_rel` for success and `memory_order_acquire` for failure. This is technically
correct per C11, but add a comment explaining why failure order is weaker.

---

## Remediation Roadmap

### Sprint 0 — P0 Blockers (fix before any testing on real hardware)

1. AUDIO-009, AUDIO-010 — Atomic counters in realtime audio graph
2. AUDIO-026 — Wrong `targetPackets` in default RxBuffer policy
3. AUDIO-046 — Missing atomic destroy in `deinit`
4. VID-004 — Lock/unlock mismatch in preview window (deadlock)
5. VID-009 — Bounds-unchecked reads in video transport packet
6. VID-038 — `isLoopbackSelfProbe` undefined property (runtime crash)
7. VID-021 — Concurrent iteration/mutation race in frame reassembler
8. P2P-001 — Missing `return` in `nextFrame()` (video always nil)
9. P2P-002, P2P-006 — Unsynchronized mutable state on Sendable types
10. NET-003, NET-004 — Unchecked array access on untrusted network data
11. NET-013 — Unchecked buffer access in V2 fragment reassembly
12. NET-029 — Off-by-one in fragment planner
13. ATEM-001, ATEM-002 — Unsafe memory rebind and fd_set OOB
14. LOLA-001, LOLA-005, LOLA-007 — EINTR retry, buffer overflow, inout bug
15. EXTCONN-001, EXTCONN-002 — Force unwrap and strdup leak in process runner
16. PY-004, PY-021 — Protocol bypass via malformed datagrams, fragment overflow
17. CONN-007 — NMP `.pass` verdict always blocked

### Sprint 1 — P1 Critical Path (required for correct operation)

Group A: Audio/Realtime correctness
- AUDIO-001..008, 012, 015, 016, 017, 018, 020, 021
- AUDIO-025, 029, 031, 033, 034, 035, 037, 039, 040, 041, 043, 045, 047, 049, 052, 054

Group B: Network/UDP correctness
- NET-001, 002, 005, 007, 008, 010, 012, 014, 015, 018, 020, 022, 023, 024, 025, 027, 028, 030, 032, 033, 035

Group C: P2P / Session lifecycle
- P2P-003..011, 016, 017, 021, 023, 025, 026, 029, 032, 035, 036, 039, 043, 044, 045

Group D: Video pipeline
- VID-001..003, 006..008, 010, 012..017, 019..020, 023, 025..026, 028, 030, 033, 035, 037, 040, 041, 042, 043, 045, 049

Group E: Protocol / Control / LoLa
- PROTO-001, 002 | LOLA-002..014 | EXTCONN-003..012 | OSC-001..003 | CONTROL-002, 003

Group F: UI critical
- UI-013, 015, 017, 025, 026, 028, 029, 031, 033, 035, 037, 039, 043, 047, 049, 051, 055
- UI readability: UI-008, 021, 023, 024, 032, 034, 036, 057

Group G: Python
- PY-001..003, 005..008, 010..012, 015, 017, 018, 020

### Sprint 2 — P2 Quality / Dedup / Structure

- Consolidate validation primitives across all modules (TIMING-005, AUDIO-042, CLI-001)
- Unify IPv4/IPv6 socket helpers (NET-016, NET-031)
- Deduplicate UI patterns (AppStorage wrapper, Binding helpers, writePlan)
- Port and address validation at construction (EXTCONN-012, CONN-005)
- Design system token usage (UI-010, 012, 038, 045, 050, 054)
- SPSCAtomicRing documentation and capacity precondition (TIMING-008)
- Python: type hints, named constants, logging (PY-009, 014, 016, 019, 022)
- BytesPerPixel single source of truth (VID-005, 039)
- isLoopback() deduplication (P2P-023)
- Percentile ordering validation helper (TIMING-007)

---

*End of Audit. Total findings: 346. Generated by parallel subagent codebase analysis.*
