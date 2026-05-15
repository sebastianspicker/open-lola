# open-lola2 Full Code Audit & Remediation Plan

> Generated: 2026-05-11  
> Scope: 292 Swift source files, Python linux_connector, shell scripts, tests  
> Method: 7 parallel sub-agent fleet, full-file read of every source file  
> Status: **Python/scripts sub-audit still in progress** — findings will be appended when complete.

---

## How to read this document

Each finding has a **unique ID**, a **priority tier**, a **file + line range**, a **description of the problem**, and a **concrete remediation**.

| Tier | Meaning |
|------|---------|
| **P0** | Silent data corruption, crash, or broken release gate — must fix before shipping |
| **P1** | Observable wrong behaviour, correctness flaw, or significant reliability risk |
| **P2** | Code quality, maintainability, latent risk, dead code, boilerplate |

Findings are grouped by subsystem, then sorted P0 → P1 → P2 within each group.

---

## Table of Contents

1. [Realtime Audio Path](#1-realtime-audio-path)
2. [Timing, Clock & RX Buffering](#2-timing-clock--rx-buffering)
3. [UDP / Network / P2P](#3-udp--network--p2p)
4. [Video Transport & Capture](#4-video-transport--capture)
5. [Control (OSC / ATEM / Lighting)](#5-control-osc--atem--lighting)
6. [UI — SwiftUI App](#6-ui--swiftui-app)
7. [Core Infrastructure & CLI](#7-core-infrastructure--cli)
8. [Python linux_connector & Shell Scripts](#8-python-linux_connector--shell-scripts)
9. [Cross-cutting Summary](#9-cross-cutting-summary)

---

## 1. Realtime Audio Path

### AUDIO-001 · P0 · `DirectPeerRealtimeAudioGraph.swift:302`
**UInt64 overflow trap in host-time nanosecond conversion**

`nanoseconds(fromHostTime:)` performs `hostTime * hostTimeNumerator` with the plain Swift `*` operator, which traps fatally on overflow. After hours of uptime on Intel Macs (where `numer > 1`), `hostTime` is large enough to overflow `UInt64`. The identical conversion in `AudioLoopbackRun.swift:453` correctly uses `multipliedReportingOverflow` + a guard.

**Fix:**
```swift
let (scaled, overflow) = hostTime.multipliedReportingOverflow(by: hostTimeNumerator)
return overflow ? UInt64.max : scaled / hostTimeDenominator
```

---

### AUDIO-002 · P0 · `DirectPeerRealtimeAudioGraph.swift:607–609`
**`assertionFailure` called inside CoreAudio IOProc — illegal in realtime context**

In Debug builds this call allocates the error string, acquires the crash-reporter lock, and terminates. In Release builds on Darwin it may still take a lock. Both are illegal in a realtime callback.

**Fix:** Remove `assertionFailure`; simply return the error code from the IOProc.

---

### AUDIO-003 · P0 · `DirectPeerRealtimeAudioGraph.swift:141–196`
**Two independent IOProcs share same `clientData` — concurrent write race on scratch buffers**

When `inputDeviceID != outputDeviceID`, the same IOProc is registered against two separate hardware devices. Both can fire concurrently on independent realtime threads. `inputScratch` and `outputScratch` are shared without synchronisation; an unexpected non-empty buffer list from either device during reconfiguration causes a data race.

**Fix:** Register two distinct IOProc functions (one for input, one for output), or check which direction is active before accessing shared scratch buffers.

---

### AUDIO-004 · P0 · `DirectPeerRealtimeAudioGraph.swift:250–324`
**`captureInjectedPayload` races with SPSC ring used by the audio IOProc**

`captureInjectedPayload(_:hostTimeNanoseconds:)` is a public API callable from any thread. It writes to the same SPSC ring as the audio IOProc's `copyInputToCaptureRing`. A `DEBUG` assertion fires, but Release builds silently corrupt `writeIndex` and raw payload storage.

**Fix:** Document that `captureInjectedPayload` is only valid when the IOProc is stopped, and enforce this with a state flag.

---

### AUDIO-005 · P1 · `RealtimeAudioBuffers.swift:135–140`
**Late-arriving packets counted as overruns, masking root cause**

`RealtimeAudioDueBlockPlayout.enqueue()` returns `.droppedFull` when `block.startFrame < nextFrame` — this is a late drop, not a buffer-full condition. The caller maps it to `snapshot.overruns += 1`, conflating two distinct failure modes.

**Fix:** Add a `.droppedLate` result case (or use `.droppedInvalid`); update the overrun counter only for true capacity overflow.

---

### AUDIO-006 · P1 · `MadiReceiveBuffers.swift:32–65`
**Hash collision in pending-deadline slot map causes valid packet drops**

`MadiReceivePendingDeadlineSlots` uses `sequenceNumber % capacity` (capacity = 8). Any two in-flight packets whose sequence numbers differ by exactly 8 collide, the store returns `false`, and `pendingDeadlineLimitExceeded(8)` is thrown — even though capacity is not exceeded. Legitimate packets are silently discarded.

**Fix:** Use open-addressing linear probing or a compact linear search instead of pure modulo hashing.

---

### AUDIO-007 · P1 · `DirectPeerAudioPayloadRing.swift:25–28`
**Payload buffer allocated with 1-byte alignment — UB for float32 operations**

For `float32LittleEndian` payloads the sample data requires 4-byte alignment. Any future vectorised (NEON/SSE) processing of the raw pointer would fault.

**Fix:** Use `max(MemoryLayout<UInt32>.alignment, MemoryLayout<Float>.alignment)` as the alignment argument.

---

### AUDIO-008 · P1 · `AudioLoopbackRun.swift:387–417`
**`overruns` counter conflates two unrelated failure modes**

Counter increments for: (1) `hostTime` conversion overflow; (2) pre-allocated interval buffer overflow. These are unrelated failures that need separate diagnostic counters.

**Fix:** Add a `hostTimeConversionFailures` counter separate from `overruns`.

---

### AUDIO-009 · P1 · `MadiFullDuplexSocketRunner.swift:153–159`
**1 ms busy-poll sleep exceeds the 667 µs packet period at 32 frames/packet**

`drainUntil` uses `usleep(1_000)`. At 48 kHz / 32 frames the packet period is ≈ 667 µs. The sleep interval is 50% longer, causing consistent late-drops under the `direct` rx-buffer policy.

**Fix:** Reduce sleep to ≤ 100 µs, or use `poll(2)` / `select(2)` with an appropriate timeout.

---

### AUDIO-010 · P1 · `MadiReceive.swift:189`
**Dead `_ = receivedAtHostTimeNanoseconds` suppression marker**

After the variable is consumed on lines 90–99, it is explicitly discarded again on line 189. This is a leftover suppression marker with no effect.

**Fix:** Delete line 189.

---

### AUDIO-011 · P1 · `RealtimeAudioPacketHandoff.swift:133–156`
**Heap allocation per audio block in transmit path**

`Data(bytes: baseAddress, count: payloadBytes.count)` allocates on every block inside `captureRing.withPoppedPayload`. If this path is ever embedded in an IOProc, it becomes P0.

**Fix:** Accept `UnsafeRawBufferPointer` at the call site, or use a pre-allocated staging buffer.

---

### AUDIO-012 · P1 · `RealtimeAudioBuffers.swift:332–345`
**`hiddenPlayoutGrowthDetected` can produce false PASS failures**

`dropStalePackets` sets the flag when `bufferedPackets > capacityBlocks`, but legitimate transient jitter spikes can trigger this condition. Since the flag is a PASS gate, it causes false validation failures.

**Fix:** Only ever set `hiddenPlayoutGrowthDetected = true`; never clear it inside `dropStalePackets`.

---

### AUDIO-013 · P1 · `RealtimeAudioEngineReportValidation.swift:135`
**`unorderedCallbackMetrics` error case reused for handoff performance counters**

The same error name appears in log output for two different field sets, making diagnosis ambiguous.

**Fix:** Introduce `unorderedPerformanceCounter(String)` or add the field name to the existing case.

---

### AUDIO-014 · P2 · `MadiReceiveReport.swift:232–247`
**Wrong error domain thrown from validation helpers**

`requireMadiReceiveNonEmpty` and `requireMadiReceiveNonNegative` throw `transportModeMismatch` for empty or negative fields — semantically incorrect. 

**Fix:** Introduce `emptyField` and `negativeField` cases; only throw `transportModeMismatch` for actual protocol mismatches.

---

### AUDIO-015 · P2 · `AudioLoopbackHelpers.swift:82–90`
**`parseBool` hardcodes wrong argument name in error messages**

`argument` label is hardcoded to `"--experimental-8-frame"` but the function is also called for `"--acknowledge-latency-warning"`. Any `invalidBool` error for the second argument falsely reports the first name.

**Fix:** Make `argument` a parameter.

---

### AUDIO-016 · P2 · Five files across Audio subsystem
**25+ duplicate `requireXxxNonEmpty/Positive/NonNegative/Finite` helpers**

`RealtimeAudioEngineHelpers.swift`, `MadiFullDuplexValidation.swift`, `MadiReceiveReport.swift`, `MadiTransmit.swift`, `RmeFastestAudioPath.swift` each re-implement structurally identical validation families differing only in which `Error` type they throw.

**Fix:** Consolidate into generic `ValidationPrimitives` overloads; delete the per-file duplicates.

---

### AUDIO-017 · P2 · `RealtimeAudioBuffers.swift:198–316`
**Manual `Codable` implementation (~120 lines) where synthesis would suffice**

`RealtimeAudioHandoffMetrics` has a 50-line `init(from:)` and 30-line `encode(to:)` using `decodeIfPresent … ?? 0`. The sole reason synthesis cannot be used is the `?? default` for optional fields — move defaults into the memberwise `init`.

**Fix:** Use Swift synthesised `Codable`; move defaults to `init(inputBlocks:…)`.

---

### AUDIO-018 · P2 · `MadiFullDuplexReport.swift` + `MadiReceiveReport.swift` + `MadiTransmit.swift`
**Identical `payload(seed:)` helper copy-pasted three times**

```swift
Data((0..<byteCount).map { UInt8(($0 + seed) % 251) })
```

**Fix:** Extract to `SyntheticAudioPayload.make(seed:byteCount:)`.

---

### AUDIO-019 · P2 · `DirectPeerRealtimeAudioGraphTypes.swift:96` + `DirectPeerRealtimeAudioGraph.swift:270`
**Dead `audioDeviceUID` field in `DirectPeerRealtimeAudioGraphConfiguration`**

Legacy field is set in `init` but never read within the audited files. Accumulates silently in JSON persisted configs.

**Fix:** Remove `audioDeviceUID` and update any persisted JSON, or mark `@available(*, deprecated)` with a migration note.

---

## 2. Timing, Clock & RX Buffering

### TIME-001 · P0 · `SPSCAtomicRing.swift:36–64`
**SPSC ring may have no store-release/load-acquire pairing — potential data race**

`push` writes to `storage[]` then calls `open_lola_atomic_u64_store`. `pop` calls `open_lola_atomic_u64_load`. If either C function uses `memory_order_relaxed`, the consumer can observe stale slot data — classic SPSC race with undefined behaviour.

**Fix:** Audit `COpenLolaAtomics`: the store in `push` must use `memory_order_release`; the load in `pop` must use `memory_order_acquire`. Document the ordering guarantee in `SPSCAtomicRing.swift`.

---

### TIME-002 · P1 · `PerformanceAuditReport.swift:56–73`
**`record()` stores running maximum into p50/p95/p99 — all percentile fields equal max**

After N calls every percentile equals the global maximum. The method name is deeply misleading.

**Fix:** Accumulate raw samples in a `[Double]` array; compute true percentiles in a `finalize()` method. Remove or redirect `record()`.

---

### TIME-003 · P1 · `DriftPlcReport.swift:289–297`
**No monotonicity check on `senderFrameIndex` across telemetry samples**

Out-of-order telemetry samples produce nonsensical `driftSlopeFramesPerMinute`.

**Fix:** After the per-sample loop, iterate pairs and throw if `samples[i+1].senderFrameIndex < samples[i].senderFrameIndex`.

---

### TIME-004 · P1 · `RxImpairmentSimulator.swift:93`
**`guard sequence > 0` — packet 0 never affected by any impairment**

First packet is unconditionally clean, skewing all aggregate statistics.

**Fix:** Remove the guard or offset to `sequence % n == (n - 1)`.

---

### TIME-005 · P1 · `RxImpairmentSimulator.swift:106`
**Reorder arrival time can go negative, turning "reordered" into "very early"**

`arrival -= packetPeriodMicroseconds * 1.5` at `sequence=1` produces a negative arrival, clamped to 0 — recorded as arriving at t=0, not a reorder.

**Fix:** Skip reorder injection when the resulting arrival would be negative, or only inject reorders at `sequence >= 2`.

---

### TIME-006 · P1 · `RxImpairmentSimulator.swift:223–272`
**`percentile` uses `.rounded(.up)` index — overestimates for small arrays**

For p50 on a 2-element array, returns the maximum instead of the median.

**Fix:** Use `let i = min(Int(Double(count) * fraction), count - 1)`.

---

### TIME-007 · P1 · `RxBufferBenchmarkRunner.swift:~40`
**Adaptive controller benchmarked with only 48 packets — insufficient to stabilise**

48 packets ≈ 1–2 hysteresis cycles. Reports have no statistical meaning for adaptation behaviour.

**Fix:** Raise default to ≥ 500 packets, or mark results as illustrative only.

---

### TIME-008 · P1 · `LatencyBenchmark.swift`
**Single-shot timing with no warmup and no repetition**

Any OS interrupt or first-run JIT penalty inflates the result with no detection mechanism.

**Fix:** Add configurable `warmupIterations` (≥ 3) and `sampleCount` (≥ 10). Report median and p99.

---

### TIME-009 · P1 · `E2EBenchmarkReportValidation.swift:~143`
**Negative `audioP99DeltaFromBaselineMicroseconds` illegitimately rejected**

A negative delta is physically valid (video presence can reduce audio jitter).

**Fix:** Remove the non-negative constraint. Use a configurable tolerance threshold for pass/fail.

---

### TIME-010 · P1 · `E2EBenchmarkRunner.swift:~294`
**`maxStableChannelCount` is the configured channel count, not a measurement**

`audioMode.channelCount` is copied verbatim. The field is a tautology.

**Fix:** Measure the channel count that sustained stable playout across the full run, or rename to `configuredChannelCount` until a real measurement is implemented.

---

### TIME-011 · P2 · `SPSCAtomicRing.swift:36–64`
**Swift exclusivity enforcement may trap on `storage` array in debug builds**

A Swift `[UInt64]` has COW semantics. Two threads accessing distinct indices may trip the exclusivity checker even though the SPSC invariant makes it semantically safe.

**Fix:** Switch `storage` to `UnsafeMutableBufferPointer<UInt64>` or annotate with `nonisolated(unsafe)`.

---

### TIME-012 · P2 · `MediaClock.swift:~248`
**Mid-sequence non-monotonic `remoteSenderTimeNanoseconds` not caught**

`estimate()` only validates first/last timestamps; inversions in the middle produce a noisy slope.

**Fix:** Add pairwise monotonicity check on `remoteSenderTimeNanoseconds`.

---

### TIME-013 · P2 · `DriftPlcHelpers.swift` / `DriftPlcRun.swift:~123`
**Dead conditional: `? 0 : 1` — always evaluates to 1**

`playoutTargetFrames` is guarded with `max(1, ...)` at this call site, making `? 0 :` unreachable.

**Fix:** Replace with `targetPackets: 1` and assert `playoutTargetFrames > 0`.

---

### TIME-014 · P2 · `RxImpairmentSimulator.swift` (LCG)
**Raw LCG produces biased low bits; jitter distribution is triangular, not uniform**

**Fix:** Apply PCG output permutation or use `SystemRandomNumberGenerator`.

---

### TIME-015 · P2 · `RxImpairmentSimulator.swift` (`adjacentDeltas`)
**Duplicate packets inflate jitter metrics**

**Fix:** Filter out `.duplicate` events before computing `adjacentDeltas`, or document the intentional inflation.

---

### TIME-016 · P2 · `LatencyBenchmark.swift`
**Dead assert: `assert(durationMicroseconds >= 0)` after `max(0, rawValue)` — always true**

**Fix:** Remove the dead assert or promote to `assert(rawNanoseconds >= 0, "clock went backwards")`.

---

### TIME-017 · P2 · `DriftPlcReport.swift:~260`
**`playoutTargetFrames == 0` passes validation silently**

Zero-target and one-packet-target modes have different semantics but are not distinguished.

**Fix:** Split into two explicit modes with separate validation paths.

---

### TIME-018 · P2 · `E2EBenchmarkReportValidation.swift:~143`
**Strict `> 0` threshold for video-impact detection is noise-sensitive**

A delta of 0.001 µs triggers the same flag as a real 50 µs regression.

**Fix:** Replace with a configurable threshold (e.g., `> 5.0` µs).

---

### TIME-019 · P2 · `LatencyTuningReportValidation.swift:101`
**`durationSeconds` validated as non-negative, but zero is accepted**

A zero-duration excluded candidate is never caught.

**Fix:** Change to `requirePositive` for `durationSeconds`.

---

### TIME-020 · P2 · `LatencyTuningReportValidation.swift:301–310`
**`rollbackCandidateMissing` thrown when candidate exists but fails eligibility**

Two distinct failure modes collapse to the same ambiguous error.

**Fix:** Add `rollbackCandidateIneligible(rollbackId)` error case.

---

### TIME-021 · P2 · `RxBuffering.swift:186`
**Zero-packet direct buffer (`targetPackets=0`) produces `latencyCostMicroseconds = 0`**

Any downstream division-by-zero or "0 = unset" interpretation can misbehave.

**Fix:** Document the zero-packet pass-through mode explicitly; add comments to all consumers of `latencyCostMicroseconds` flagging the zero case.

---

### TIME-022 · P2 · `RxBuffering.swift:439–479`
**Hysteresis counters reset asymmetrically — adaptive controller may never decrease buffer depth**

A single moderate sample resets both counters to zero, preventing sustained-quiet runs from triggering a decrease.

**Fix:** Use a three-zone design: stressed → increment high; quiet → increment low; neutral → leave both unchanged.

---

### TIME-023 · P2 · 8+ files
**25+ duplicate `requireXxxNonNegative` helpers across 8 files**

`ValidationPrimitives` / `ReportPrimitiveValidating` infrastructure exists but is bypassed.

**Fix:** Consolidate into `ValidationPrimitives` generic overloads; delete per-file duplicates.

---

### TIME-024 · P2 · 5+ files
**Duplicate percentile-ordering validation reimplemented inline in 4 callers**

`timingPercentilesAreOrdered` in `TimingValidationHelpers.swift` is duplicated in `validateE2ECounter`, `validateRxBenchmarkJitter`, `validateMediaPacketAge`, `validateProfilePacketAge`.

**Fix:** Route all call sites through the shared helper.

---

### TIME-025 · P2 · `MeasurementMethodology.swift`
**`MeasurementMethodology` enum is defined but never referenced — dead code**

**Fix:** Delete or confirm active use.

---

### TIME-026 · P2 · `E2EBenchmarkSyntheticSmoke.swift:~138`
**Dead ternary: `audioMetrics(delta: profile == .audioOnlyDirect ? 0 : 0)` — always 0**

**Fix:** Remove the ternary; pass `delta: 0` directly.

---

### TIME-027 · P2 · `DriftPlcRun.swift` + `E2EBenchmarkRunner.swift`
**Inline `--key value` parse loops duplicate `KeyValueArgumentParser`**

**Fix:** Replace inline loops with `KeyValueArgumentParser.parse(_:)`.

---

### TIME-028 · P2 · `CapabilitySummary.swift`
**Stale M02 milestone constants — project is at M14/M15**

**Fix:** Extend or remove `DevelopmentStage` enum to reflect current milestones.

---

## 3. UDP / Network / P2P

### NET-001 · P1 · `LoLaCompatibilityWireFrame.swift:137–162`
**Strict length equality rejects valid Ethernet-padded frames**

IEEE 802.3 frames are padded to 64 bytes minimum. The decoder requires `ipv4TotalLength == data.count − etherHeaderByteCount`; padded frames always fail. The passive-capture decoder in `LoLaIPv4UDPPacket.decode()` correctly uses `<=`.

**Fix:** Change both checks to `<=`; derive payload slice using header-declared lengths, not `data.count`.

---

### NET-002 · P1 · `LoLaCompatibilityRawLink.swift:423–429`
**`break` on malformed BPF record discards all subsequent packets in the same batch**

A single crafted first record silences all following packets.

**Fix:** Replace `break` with `offset += bpfWordAlign(max(1, headerLength + capturedLength)); continue`.

---

### NET-003 · P1 · `LoLaTcpControlExchangeRuntime.swift:337–353`
**TCP control message read assumes one `recv()` = one message — partial reads cause silent truncation**

TCP is a byte-stream; a 1024-byte LoLa message can arrive in multiple fragments. The current code treats the first `recv()` result as a complete message.

**Fix:** Loop `recv()` until `lolaControlDatagramByteCount` bytes are accumulated, or implement NUL-terminator framing.

---

### NET-004 · P2 · `LoLaCompatibilityControlMessage.swift:243–246`
**Dead code: both branches of `acceptsTruncatedText` return identical value**

```swift
if acceptsTruncatedText { return (name, fields) }
return (name, fields)
```

The `if` branch is a no-op; the truncated-TXT handling documented in comments is structurally dead.

**Fix:** Remove the duplicate return or restore the intended differentiation. Add a unit test.

---

### NET-005 · P2 · `LoLaControlExchangeRuntime.swift:479–484` + `LoLaTcpControlExchangeRuntime.swift:311`
**`setsockopt` failures silently discarded**

Failed `SO_REUSEADDR` / `SO_REUSEPORT` causes the subsequent `bind()` to return `EADDRINUSE` with a misleading attribution.

**Fix:** Guard each `setsockopt` and throw `ExternalConnectorSessionError.socketFailed(…)` on failure.

---

### NET-006 · P2 · `LoLaCompatibilityMediaModel.swift:13–18`
**`audioPayloadByteCount(channels:framesPerPacket:bytesPerSample:)` has no upper bound**

Uncapped `channels` can overflow `Int` multiplication, producing a negative or zero byte count passed to `Data(count:)`.

**Fix:** Add `guard channels <= 256, framesPerPacket <= 65536 else { throw … }`.

---

### NET-007 · P2 · `LoLaSocketUdpMediaTransmitter.swift:82–99`
**EINTR-retry loop has no hard iteration cap — can busy-loop at 100% CPU under signal pressure**

**Fix:** Add a maximum retry counter (e.g., 1000 per call). Make `Double → useconds_t` cast explicit.

---

### NET-008 · P2 · `LoLaCompatibilityRawLink.swift:421–422`
**BPF header field offsets are inline magic numbers — wrong for `bpf_xhdr`**

Offsets 16 and 24 are hardcoded. For the extended BPF header (`bpf_xhdr`, used on newer kernels) the fields are at different offsets, silently producing garbage packet boundaries.

**Fix:** Define named constants referencing `<net/bpf.h>` struct layout. Add a comment that `bpf_xhdr` is not supported.

---

### NET-009 · P2 · `ExternalConnectorProcessRunner.swift:164–168`
**0.3 s SIGTERM-to-SIGKILL grace period too short for JackTrip / UltraGrid teardown**

JackTrip and UltraGrid may need 1–2 s to flush CoreAudio buffers and release devices. A SIGKILL at 0.3 s can leave devices in an in-use state.

**Fix:** Increase grace period to ≥ 2 s, or make it a configurable parameter.

---

### NET-010 · P2 · `DirectP2PTwoPeerLocalRunCommandSupport.swift:388–400`
**rx-proof SCP unconditionally attempted — fails silently for audio-only sessions**

The rx-proof file is only written when `--rx-proof-output` was passed. A missing file causes `scp` to fail, masquerading a successful peer session as a supervisor error.

**Fix:** Only attempt the rx-proof SCP when `--rx-proof-output` was in the peer command. Treat failure as a warning.

---

### NET-011 · P2 · `SPSCAtomicRing.swift` + `COpenLolaAtomics`
**SPSC ring correctness depends on unverified memory-ordering in `COpenLolaAtomics`**

(See also TIME-001.) The Swift wrapper provides no documentation or static assertion that `open_lola_atomic_u64_store` uses `memory_order_release` and `open_lola_atomic_u64_load` uses `memory_order_acquire`.

**Fix:** Document the contract in both the C header and `SPSCAtomicRing.swift`. Add a TSAN-enabled CI step.

---

## 4. Video Transport & Capture

### VID-001 · P0 · `VideoTransportReassembly.swift:239–240`
**First fragment double-inserted into new reassembly bucket**

The bucket is initialised *with* `firstFragment` then `bucket.insert(fragment)` is called again with the same fragment. The `duplicateFragments` counter is not incremented because the increment is in the existing-bucket branch. Net effect: the fragment occupies two slots, wastes memory, and under-counts duplicates.

**Fix:** Remove the redundant `bucket.insert(fragment)` call on line 240.

---

### VID-007 · P0 · `VideoCaptureAVFoundation.swift:~288–320`
**`device.lockForConfiguration()` leaked when `canAddOutput` guard fails**

If `session.canAddOutput(output)` fails, the function calls `session.commitConfiguration()` and throws without calling `device.unlockForConfiguration()`. The device remains permanently locked until process exit.

**Fix:** Add `defer { device.unlockForConfiguration() }` immediately after `lockForConfiguration()` succeeds.

---

### VID-002 · P1 · `VideoTransportReassembly.swift:~285–305`
**`UInt64` sequence number wraparound permanently stalls a stream**

`latestCompletedFrameSequenceNumbersByStreamID` uses `<= latestCompleted` to reject late fragments. After `UInt64.max` the next legal frame (seqNum = 0) is rejected as late.

**Fix:** Use modular comparison: `(seq &- latest) > halfWindowThreshold` (RFC 1982 serial number arithmetic).

---

### VID-003 · P1 · `VideoTransportReassembly.swift:324`
**Strict `<` eviction allows same-seqnum bucket coexistence**

Stale partial-reception state from an old bucket can bleed into a new reception cycle.

**Fix:** Change eviction condition to `<=`.

---

### VID-005 · P1 · `VideoTransportPacket.swift:44–75`
**`encodedByteCount` may under-count variable-length fields, forcing buffer reallocation**

If variable-length fields are omitted from the `encodedByteCount` sum, every high-frequency encode call forces a heap reallocation.

**Fix:** Ensure `encodedByteCount` exactly mirrors the append sequence in `encoded()`. Add `assert(encoded().count == encodedByteCount)` in debug builds.

---

### VID-006 · P1 · `VideoTransportRunner.swift:~200–230`
**Negative `maxPacketBytes` silently passed to fragmentation**

When `configuration.maxPacketBytes < UdpMediaPacketHeader.byteCount`, the subtraction wraps negative. The inner guard catches it, but the error message reports the pre-subtracted value.

**Fix:** Guard before the subtraction; throw with the actual configured value.

---

### VID-008 · P1 · `VideoCaptureAVFoundation.swift:358–432`
**`@unchecked Sendable` suppresses race detection on `AVFoundationSampleBufferCollector`**

State is currently guarded by `stateLock`, but `@unchecked` disables compiler and TSAN verification. Any future unguarded property addition will not be caught.

**Fix:** Document all mutable properties and their lock coverage. Run TSAN in CI. Evaluate refactoring as an actor.

---

### VID-011 · P1 · `VideoOutputRenderer.swift:207–209`
**`keepsContinuity` permanently blocks stream delivery at `UInt64.max`**

`previous == UInt64.max` causes all subsequent frames (including the valid seqNum 0 wraparound) to fail the continuity check.

**Fix:** Treat `(previous == UInt64.max && current == 0)` as valid wraparound. Use wrapping arithmetic: `current == previous &+ 1`.

---

### VID-014 · P1 · `VideoTransportRunner.swift:305–334`
**Busy-wait drain loop wastes a CPU core; parameter name is misleading**

`drainVideoFragments` polls with `usleep(1_000)`. `expectedFrames` is actually the total *generated* count, not expected received.

**Fix:** Replace with `DispatchSemaphore` / `DispatchGroup` signalled from the reassembly callback. Rename `expectedFrames` to `totalGeneratedFrames`.

---

### VID-004 · P2 · `VideoTransportReassembly.swift:366–373`
**`activeFrameOrder` compaction can defer unbounded — accumulates stale `nil` entries**

Compaction fires only when `cursor > 64 && cursor * 2 > count`. Under sustained multi-stream load, compaction is deferred indefinitely.

**Fix:** Lower threshold (e.g., `cursor > 32 && cursor > count / 2`), or compact on each completion/eviction.

---

### VID-009 · P2 · `VideoCaptureAVFoundation.swift:~303–323`
**`RunLoop.current.run(until:)` returns immediately on GCD-managed threads**

GCD threads have no active RunLoop sources; the intended capture warm-up delay becomes zero.

**Fix:** Replace with `Thread.sleep(forTimeInterval:)` or a `DispatchSemaphore` timeout.

---

### VID-010 · P2 · `VideoCaptureAVFoundation.swift:535–542`
**O(n) `removeSubrange(0..<…)` on raw frame data blob**

At 1080p BGRA / 120 frames, each trim is a ~952 MB `memmove`.

**Fix:** Don't compact `rawFrameData` on each trim; only materialise the trimmed view at artifact-collection time, or use a ring-buffer of fixed-size slabs.

---

### VID-012 · P2 · `VideoOutputRenderer.swift:135–165`
**`submit` Bool return is ambiguous after eviction**

A frame accepted then immediately evicted by back-pressure can still return `true`.

**Fix:** Return a dedicated result enum: `accepted`, `acceptedWithBackpressureDrop`, `rejected`.

---

### VID-013 · P2 · `VideoOutputRenderer.swift:~220–260`
**Latency metrics arrays grow without bound at 120 fps**

At 120 fps / 1 hour: 432,000 `Double` entries per array (≈ 3.5 MB). Over multi-hour multi-stream runs: tens of millions of samples.

**Fix:** Replace raw arrays with a fixed-depth circular buffer (e.g., 10,000 samples) or streaming histogram.

---

### VID-015 · P2 · `VideoTransportRunner.swift:~150–200`
**Oversized UDP datagram silently truncated before decode**

`recvfrom` with `maxPacketBytes` silently truncates; the resulting decode failure has no indication of truncation as root cause.

**Fix:** After `recvfrom`, if `receivedByteCount == maxPacketBytes`, log a truncation warning. Consider `MSG_TRUNC | MSG_PEEK`.

---

### VID-016 · P2 · `RawBGRAAppKitPreviewWindow.swift:32–58`
**`.premultipliedFirst` incorrect for opaque hardware BGRA**

For opaque video with `alpha == 255` this is a render no-op but misleads downstream consumers. For any real alpha, colours are incorrectly divided.

**Fix:** Use `CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue` for opaque BGRA.

---

### VID-017 · P2 · `RawBGRAAppKitPreviewWindow.swift:61–106`
**Dropped frames on `submitPending` are completely invisible**

No counter, no log, no back-pressure signal. At 60 fps with a 17 ms render stall, every other frame is silently discarded.

**Fix:** Add `droppedFrameCount: Int` counter incremented inside the `submitPending` guard.

---

### VID-018 · P2 · `MultiVideoStreams.swift:~275–283`
**Free function `estimatedVideoBandwidthMegabitsPerSecond` duplicates property on `VideoStreamDescription`**

**Fix:** Delete the free function; use `.estimatedBandwidthMegabitsPerSecond` at all call sites.

---

### VID-019 · P2 · `MultiVideoStreams.swift:~200–240`
**Per-stream queue depth reports global depth for every stream**

`observedQueueDepth: receiverObservedQueueDepth` is set identically for every stream in the multi-stream array. Per-stream back-pressure is invisible.

**Fix:** Track `observedQueueDepth` per stream ID in a `[UInt32: Int]` map.

---

## 5. Control (OSC / ATEM / Lighting)

### CTL-001 · P1 · `AtemReadOnlyControl.swift:~310–340`
**`timeval.tv_sec` overflow on pathological timeout value**

`Int(configuration.timeoutMilliseconds / 1_000)` with `Int.max` as input produces an incorrect `select` timeout (effectively infinite wait). The `tv_usec` cast is safe, but only if `ms` is bounded.

**Fix:** Add `guard value <= 30_000` in `optionalAtemProbePositiveInteger`, or clamp: `let clampedMs = min(configuration.timeoutMilliseconds, 30_000)`.

---

### CTL-003 · P1 · `OscCueHelpers.swift:14–35`
**`readOscString` 4-byte alignment precondition undocumented and fragile**

Alignment arithmetic is correct for absolute offsets but will be wrong if called with a relative offset inside a sub-structure. No precondition or doc comment warns callers.

**Fix:** Add `/// cursor must be absolute offset from byte 0 of the OSC message` doc comment and a `precondition(cursor >= 0)`.

---

### CTL-006 · P1 · `LightingFixtureGate.swift:247–281`
**Network isolation checked before failure-policy completeness — operator sees one problem at a time**

Both blocking conditions are present simultaneously but only one is reported per call.

**Fix:** Collect all blocking reasons; return `blocked(reasons: [LightingGateBlockReason])` or run both checks before returning.

---

### CTL-007 · P1 · `LightingFixtureGate.swift:~260–281`
**`blocked()` always returns `.disabled` state regardless of block reason**

`.hold`, `.blackout`, `.drop` states are unreachable. Gate state is useless for distinguishing "never configured" from "armed but holding."

**Fix:** Map each `LightingGateBlockReason` to a semantically appropriate state.

---

### CTL-002 · P2 · `AtemReadOnlyControl.swift:247–369`
**`.connected` verdict possible on half-open TCP connection**

`select` + `getsockopt(SO_ERROR) == 0` does not prove ATEM protocol availability. A RST arriving after `getsockopt` produces a false `.connected`.

**Fix:** Document that `.connected` means "TCP handshake completed, not ATEM protocol verified." If stronger confirmation is needed, attempt a 1-byte `recv(MSG_PEEK)` after connect.

---

### CTL-004 · P2 · `OscCueHelpers.swift:45–69`
**Hardcoded 4096-byte OSC receive buffer, no truncation detection**

An oversized OSC datagram is silently truncated; the parse fails with `missingNullTerminator` with no indication of root cause.

**Fix:** Use a 65,507-byte buffer (UDP maximum), or detect `receivedByteCount == 4096` and log a truncation warning.

---

### CTL-005 · P2 · `OscCueHelpers.swift:~60–69`
**OSC receive failure throws `UdpPcmRouteProbeError` — wrong error domain**

Error messages say "PCM route probe receive failed" for an OSC cue operation.

**Fix:** Define `OscCueError.receiveFailed` and throw from the OSC domain.

---

### CTL-008 · P2 · `LightingFixtureGateRun.swift:~121–211`
**Synthetic run hardcodes `dmx.maxLevel = 0`; PASS verdict with no fixture activity**

`maxLevel = 0` implies no DMX output observed, which must never yield PASS.

**Fix:** Add `validatePassVerdict` check: if `verdict == .pass`, require `dmx.maxLevel > 0`.

---

### CTL-009 · P2 · `LightingFixtureGateRun.swift:213–229`
**`LightingCaptureTool.init(rawValue:)` never returns `nil` — typos silently serialised**

Unknown tool names become `.configured(string)` with no early CLI error.

**Fix:** Make `init(rawValue:)` failable; return `nil` for unrecognised strings.

---

### CTL-010 · P2 · `LightingFixtureGateRun.swift:~121`
**`LightingGateRunner.run` non-throwing — internal errors invisible**

Hardware/OS errors are silently encoded as a `verdict` field. Callers checking only `verdict == .pass` may miss a `.partial` verdict encoding an internal error.

**Fix:** Make `run(configuration:)` `throws` for unrecoverable errors.

---

### CTL-011 · P2 · `BlackmagicOutputBoundary.swift`
**Enumeration failure indistinguishable from hardware absent**

`detect()` never throws. SDK crash or OS permission denial is serialised as `runtimeAvailable: false` with no error field.

**Fix:** Add `enumerationError: String?` field; populate on failure.

---

## 6. UI — SwiftUI App

### UI-001 · P1 · `AppDesignSystem.swift:6–12` + `AppShellRootView.swift:89`
**Black text on near-black backgrounds in light mode**

`appBackground` and sibling colors are hardcoded absolute RGB values (≈ 0.045–0.064 luminance). `.foregroundStyle(.primary)` resolves to black in macOS light mode → black-on-black throughout.

**Fix:** Add `.preferredColorScheme(.dark)` to `AppShellRootView`, or replace hardcoded RGB with semantic asset-catalog entries carrying light/dark variants.

---

### UI-002 · P1 · `AppShellRootView.swift:17–40`
**Expensive computations inside `body` — re-run on every render tick**

`DirectPeerTwoPeerRunPlanner.makeReport`, `AppConsoleStatusSnapshot.make`, `AppSessionState.derive`, `NativeAppShellSurfaceProbe.run` are all evaluated in `body`. `elapsedSeconds` ticking every second triggers all four.

**Fix:** Cache results as `@State` or in a dedicated `@Observable` view model; recompute only on relevant input changes.

---

### UI-003 · P1 · `OpenLolaApp.swift:19`
**Synchronous Core Audio enumeration on main thread during `App.init()`**

`hydratedOperatorSurface()` → `CoreAudioInventoryReader().capture()` blocks the main thread on launch with no spinner.

**Fix:** Replace with an async `.task` in `.onAppear`; initialise with a lightweight placeholder first.

---

### UI-004 · P1 · `AppConnectionTopologyView.swift:121–126`
**Flow dot animation uses hardcoded 200pt offset, wraps at track width**

On tracks wider than 200pt, all four dots cluster in the leftmost segment and snap discontinuously.

**Fix:** Pass `geo.size.width` from inside the `GeometryReader` as the animation end value; remove the hardcoded `200` constant.

---

### UI-005 · P1 · `AppReceiverPreviewServices.swift:202–210` + `AppPreviewReceiverView.swift:168–186`
**Monitor gain slider changes ignored at runtime — gain frozen at preview start**

`gain` is a `let` constant captured in `startAuthorized`. No `onChange(of: monitorGain)` handler exists.

**Fix:** Add `.onChange(of: previewState.monitorGain) { restartReceiverPreview() }`, or expose a live `setGain(_:)` method.

---

### UI-006 · P1 · `AppTransportView.swift:63` + `OpenLolaApp.swift:59`
**`⌘⇧E` keyboard shortcut registered on two independent buttons simultaneously**

SwiftUI conflict resolution is undefined; behaviour flickers between windows.

**Fix:** Remove `.keyboardShortcut` from `AppTransportView.armButton`; keep canonical registration in `CommandMenu` only.

---

### UI-007 · P1 · `AppConnectionTopologyView.swift:141–144`
**`stopAnimation()` teleports flow dots to origin with no transition**

`flowOffset = 0` is set outside any `withAnimation` block — instant snap.

**Fix:** Wrap in `withAnimation(.easeOut(duration: 0.2))`; set `isAnimating = false` in its completion handler.

---

### UI-008 · P1 · `AppDesignSystem.swift` + `AppSessionStateBanner.swift:120–149`
**`AppSessionState.connecting` is a dead state — `derive()` never returns it**

The blue connecting indicator is unreachable; its color constants exist but are never applied.

**Fix:** Add the `.connecting` branch in `derive()` for the handoff-requested phase, or remove the state entirely.

---

### UI-009 · P2 · `AppConsoleChromeView.swift:134–145`
**Three icon-only toolbar buttons lack `.accessibilityLabel`**

VoiceOver reads SF Symbol identifiers (e.g., "arrow clockwise") instead of action descriptions.

**Fix:** Add `.accessibilityLabel("Refresh Synthetic Metrics")` etc. to each image-only button.

---

### UI-010 · P2 · `AppChannelMeterView.swift:65` + `AppPacketMonitorView.swift:122`
**Hardcoded `Color.white.opacity(…)` invisible on non-dark surfaces**

**Fix:** Replace with `AppDesignSystem.searchFieldBackground` semantic token with light/dark variants.

---

### UI-011 · P2 · `AppConnectionTopologyView.swift:59–72`
**Peer node labels lack `lineLimit` — long hostnames overflow the fixed 120pt frame**

**Fix:** Add `.lineLimit(1).truncationMode(.middle)` on peer-name `Text`; `.truncationMode(.tail)` on host `Text`.

---

### UI-012 · P2 · `AppConnectionTopologyView.swift`
**Topology diagram has no accessibility representation — VoiceOver skips entire panel**

**Fix:** Add `.accessibilityElement(children: .ignore).accessibilityLabel("Connection: …")` summary.

---

### UI-013 · P2 · `AppChannelMeterView.swift:29–50`
**`Canvas`-rendered VU meters have no accessibility representation**

**Fix:** After `Canvas` block add `.accessibilityLabel(Text("Audio level meters, \(channelCount) channels."))`.

---

### UI-014 · P2 · `AppDeviceCard.swift:98–154`
**Device selection cards don't communicate selected state to assistive technologies**

`checkmark.circle.fill` shown visually but no `.accessibilityAddTraits(.isSelected)`.

**Fix:** Add `.accessibilityAddTraits(isSelected ? .isSelected : [])` to the `Button`.

---

### UI-015 · P2 · `AppExecutionController.swift:48` + `AppReceiverPreviewServices.swift:20, 157`
**Empty `deinit {}` bodies on three classes — dead boilerplate**

**Fix:** Remove all three empty `deinit` implementations.

---

### UI-016 · P2 · `AppDesignSystem.swift:6–47`
**Twelve color constants are module-level globals instead of `static` enum members**

Global names can collide with symbols in linked libraries.

**Fix:** Move all into `AppDesignSystem` as `static let` members.

---

### UI-017 · P2 · `AppShellSupportViews.swift:14–19`
**`UInt16Field` silently discards invalid input with no visual error state**

`IntField` shows a red overlay on invalid input; `UInt16Field` does nothing.

**Fix:** Mirror `IntField`'s `@State private var inputIsInvalid` pattern.

---

### UI-018 · P2 · `AppShellSupportViews.swift:34–50`
**`IntField.inputIsInvalid` not cleared when the externally-bound value changes**

Red border persists after a parent view resets the value.

**Fix:** Add `.onChange(of: value) { _, _ in inputIsInvalid = false }`.

---

### UI-019 · P2 · `AppOperatorArtifactViews.swift:114`
**`writePlanArtifact()` omits `runDirectory:` — produces different plan than execution flow**

Plans written through the artifact panel may have a mismatched run directory.

**Fix:** Pass `runDirectory: URL(fileURLWithPath: appSettings.operatorPlanArtifactPath).deletingLastPathComponent().path`.

---

### UI-020 · P2 · `AppTransportView.swift:34–36` + `AppLatencyHeroView.swift:55–59`
**`verticalDivider` copy-pasted across two unrelated views**

**Fix:** Extract to `AppDesignSystem` as `static func verticalDivider(height: CGFloat = 28) -> some View`.

---

### UI-021 · P2 · `AppLocalOperatorSurfaceView.swift:148–169` + `AppExecutionView.swift:80–106`
**`AppInventoryWarningBanner` and `AppExecutionWarningBanner` are near-identical components**

Both render an orange triangle + title + message list. Only difference is an optional `detail` string.

**Fix:** Unify into `AppWarningBanner(title: String, messages: [String], detail: String? = nil)`.

---

### UI-022 · P2 · `AppConsoleChromeView.swift:203–218` + `AppShellSupportViews.swift:62–75`
**`AppConsoleStatusBadge` and `StatusPill` are functionally identical badge views**

Differ only in corner shape (`RoundedRectangle` vs `Capsule`).

**Fix:** Merge into `AppStatusBadge(title:systemImage:tone:style:)` with `.rounded` / `.capsule` style param.

---

### UI-023 · P2 · `AppSessionStateBanner.swift:100–108`
**`restartPulse()` causes visible flash to full opacity before dimming**

`pulseOpacity = 1.0` is set synchronously before `withAnimation { pulseOpacity = dimmedPulseOpacity }` — one render cycle at 100% opacity.

**Fix:** Remove bare `pulseOpacity = 1.0`; drive the reset through `.id(state.rawValue)` which already forces view recreation.

---

### UI-024 · P2 · `AppShellSettingsView.swift:104`
**Settings `TabView` has fixed 680pt width with no scroll fallback**

Content clips on small or low-resolution displays.

**Fix:** Use `.frame(minWidth: 540, idealWidth: 680)` and wrap content in `ScrollView`.

---

### UI-025 · P2 · `AppShellRootView.swift:14`
**`@SceneStorage` key is a bare string literal**

A typo creates silently non-restoring scene state.

**Fix:** Add `static let selectedSection = "selectedAppShellSection"` to `AppStorageKeys` and reference it.

---

### UI-026 · P2 · `AppExecutionView.swift:18–24`
**Execution error banner has no dismiss action — error persists until next run**

**Fix:** Add a close button that sets `executionController.lastError = nil`.

---

### UI-027 · P2 · `AppShellStoredDefaults.swift:66–68`
**Invalid persisted `rxBufferProfile` silently reverts to default with no user feedback**

**Fix:** Log a warning when the fallback path is taken; optionally surface a "Settings reset" notification.

---

### UI-028 · P2 · `AppPreviewReceiverView.swift:63–83`
**Gain/blend sliders modify state but have no effect unless Local Preview window is open**

Users are not informed that the controls are inactive in this context.

**Fix:** Either disable sliders with `.disabled(!previewIsActive)` (with tooltip), or make `AppAudioLevelMeter.setGain(_:)` update the target live.

---

## 7. Core Infrastructure & CLI

### CORE-001 · P0 · `Release/PackagingFieldTestRun.swift:~162`
**Dead ternary — `PackagingFieldRunner.run` can never produce a `.pass` verdict**

```swift
verdict: packagingFieldVerdict(…) == .pass
    ? .partial   // ← should be .pass
    : .partial
```

**Fix:** Change the true-branch to `.pass`.

---

### CORE-002 · P1 · `Release/RecordingSessionRun.swift:~165–170`
**Hardcoded synthetic pressure — real runtime backpressure never sampled**

`RecordingSideLanePressureSimulator.run(producedChunkCount: 8, …)` always produces the same synthetic data regardless of actual runtime behaviour.

**Fix:** Instrument the live side-lane writer queue to collect actual stall counts.

---

### CORE-003 · P1 · `Release/RecordingSessionRun.swift:~203–214`
**Recording impact metrics trivially pass — recording-under-load values equal idle baseline**

`recordingAudioCallbackP99Microseconds: baselineP99` copies the baseline value as the recording-under-load value. The comparison always passes.

**Fix:** Capture actual CoreAudio callback latency during the recording window.

---

### CORE-004 · P1 · `Release/RecordingSessionHelpers.swift:~166–173`
**FNV-1a used as artifact integrity checksum — non-cryptographic, trivially defeated**

The packaging subsystem uses SHA-256 everywhere; the recording subsystem diverges.

**Fix:** Replace FNV-1a with `CryptoKit.SHA256` to align with `MacPackageArtifact.sha256`.

---

### CORE-005 · P1 · `Release/ReleaseHardeningSyntheticSmoke.swift:~23–29`
**`ReleaseHardeningRunner.run` evaluates no gates — output is indistinguishable from empty fixture**

Only `id`, `title`, `capturedAt`, `notes` are stamped. All benchmark comparisons, packaging readiness checks, and claim verifications remain at placeholder defaults.

**Fix:** Log `remainingPartialGates` for every gate the runner cannot automate. Automate what can be checked (benchmark report existence, `swift test` pass/fail).

---

### CORE-007 · P1 · `Evidence/HardwareValidationReport.swift:~450–456`
**Missing `"synthetic"` / `"not-supplied"` variants in placeholder fragment list**

A hardware identity field containing `"synthetic-mac"` or `"Synthetic RME Interface"` passes the placeholder check and reaches `.pass` validation.

**Fix:** Add `"synthetic"` and `"not-supplied"` (hyphenated) to the fragment list.

---

### CORE-009 · P1 · `Core/KeyValueArgumentParser.swift`
**Values starting with `--` rejected as "missing value for argument"**

Any legitimate `--`-prefixed value (e.g., a label or path) produces a confusing error.

**Fix:** Document the constraint; or allow `--`-prefixed values when the key is in the allowedKeys list and the next token is also a key.

---

### CORE-012 · P1 · `Audio/CoreAudio/CoreAudioInventoryReader.swift:~50`
**Silent fallback strings pass `validate()` — fabricated device identity reaches reports**

`"Unknown Core Audio device"` and `"unknown-\(deviceID)"` are non-empty and pass all validation checks.

**Fix:** Append a `diagnosticNotes` entry on fallback; check for the `"unknown-"` prefix in `validate()`.

---

### CORE-016 · P1 · `Evidence/HardwareValidationRun.swift:~183–187`
**Raw absolute CLI file paths embedded verbatim in published report artifacts**

Internal machine directory structure is disclosed in public release artifacts.

**Fix:** Strip to basename: `URL(fileURLWithPath: path).lastPathComponent`.

---

### CORE-019 · P1 · `main.swift:~154–280`
**Default error-path help string is hand-written and not inventory-backed**

`printTopLevelUsage()` (called for `--help`) is inventory-backed; the `default:` error handler is not. Adding commands without updating the literal produces stale error messages.

**Fix:** Replace the hand-written string in the `default:` case with a call to `printTopLevelUsage()`.

---

### CORE-006 · P2 · `Support/PlaceholderDetection.swift`
**Substring `contains` with no word-boundary anchoring — false positive risk**

The fragment `"required"` matches any string containing "required" as a substring (e.g., "Driver ID required for firmware validation").

**Fix:** Use word-boundary-aware matching (fragment surrounded by non-alphanumeric characters) or separate exact-match from substring patterns.

---

### CORE-008 · P2 · `Release/PackagingFieldTestValidation.swift:~288–293`
**Internal ticket reference `"q010"` in placeholder list is undocumented**

Opaque to maintainers unfamiliar with internal sprint numbering.

**Fix:** Add an inline comment explaining it is the sprint-backlog ticket prefix used in human-operator template fields.

---

### CORE-010 · P2 · `Core/PeerIdentity.swift:~100–108`
**Shell metacharacters not rejected in peer IDs**

`$`, `` ` ``, `\`, `(`, `)`, `&`, `|`, `>`, `<`, `!` pass validation and could cause issues if interpolated into shell commands or JSON.

**Fix:** Expand the unsafe-character set to include common shell metacharacters, or adopt an allowlist: `[a-zA-Z0-9._-]`.

---

### CORE-011 · P2 · `Support/FileDescriptorSet.swift:~17–27`
**`precondition` (fatal crash) instead of `throw` on out-of-range fd**

`openLolaRequireFileDescriptorFitsFDSet` already throws properly and should be used consistently.

**Fix:** Replace `precondition` calls with the throwing `require` variant.

---

### CORE-013 · P2 · `Core/DebugTrace.swift:~72–83`
**Log sanitiser is a denylist (opt-out) — new sensitive field names log unredacted**

Only `"payload"` / `"payloadsample"` / `"payloaddata"` / `"rawpayload"` are scrubbed.

**Fix:** Invert to allowlist: only pass through keys known to be safe; scrub everything else by default. At minimum add catch-all for `"secret"`, `"key"`, `"token"`, `"credential"`.

---

### CORE-014 · P2 · `Release/RecordingSessionLiveCapture.swift:~88–89`
**`Thread.sleep` for capture duration — not cancellable**

No mechanism to stop recording early on error, signal, or timeout expiry.

**Fix:** Replace with a cancellable `DispatchSemaphore` or `Task.sleep` wait.

---

### CORE-015 · P2 · `Release/ReleaseHardening.swift:~430–433`
**Internal-evidence path denylist too narrow**

Blocks only `"win-compiled"`, `"private"`, `"reverse-engineering"`. Misses `"internal/"`, `"confidential/"`, `"proprietary/"`.

**Fix:** Broaden the denylist; use path-prefix matching.

---

### CORE-017 · P2 · `Audio/CoreAudio/AudioStreamDescription.swift:~71–73`
**`nonPositiveField` error thrown for `< 0` guard — name is misleading**

`nonPositiveField` semantically means `≤ 0`; the guard is `< 0`.

**Fix:** Rename to `negativeField`, or change guard to `<= 0` if zero is invalid.

---

### CORE-018 · P2 · `Support/Inventories/VideoControlDegradeMatrix.swift:~338–365`
**Private `entry(...)` helper silently hardcodes `audioProtected: true`**

Entries that need `audioProtected: false` will be silently overridden if refactored to use this helper.

**Fix:** Add `audioProtected` as an explicit parameter to the private helper.

---

### TEST-001 · P1 · *(missing)*
**No `PlaceholderDetectionTests.swift`**

`PlaceholderDetection` is used as a final gate in hardware validation, release hardening, and packaging. Zero direct unit tests.

**Fix:** Add `PlaceholderDetectionTests.swift` covering exact-value matches, fragment hits, mixed-case, near-miss strings, and word-boundary edge cases.

---

### TEST-002 · P1 · *(missing)*
**No `FileDescriptorSetTests.swift`**

Custom `FD_SET`/`FD_ISSET`/`FD_ZERO` re-implementation is entirely untested. An off-by-one in bit indexing silently corrupts `select(2)` calls.

**Fix:** Add tests for bits at fd 0, 1, 31, 32, 63, 1023; clear; overflow boundaries.

---

### TEST-003 · P1 · *(missing)*
**No `RecordingSessionLiveCaptureTests.swift`**

CoreAudio IOProc callback, `CoreAudioRawInputState` ring-buffer management, and AVFoundation video-capture delegate are entirely untested.

**Fix:** Add tests for buffer fill/overflow/flush, IOProc output-buffer zeroing, video-frame enqueue using mock callbacks.

---

### TEST-004 · P2 · `Tests/OpenLolaCoreTests/KeyValueArgumentParserTests.swift`
**Missing edge cases for argument parser**

No tests for `--`-prefixed values, empty string values, or unknown-key rejection.

**Fix:** Add: `["--host", "--direct"]`; `["--host", ""]`; unknown key in strict mode.

---

### TEST-005 · P2 · `Core/CapabilitySummary.swift`
**Stale `DevelopmentStage` enum — only M00/M02 defined; project is at M14/M15**

**Fix:** Extend or remove `DevelopmentStage` to reflect current milestones.

---

## 8. Python linux_connector & Shell Scripts

### PY-001 · P1 · `connector.py:86`
**Duplicate `asyncio.get_running_loop()` assignment — dead code**

`loop = asyncio.get_running_loop()` is called a second time inside the fallback branch of `udp_sendto` after already being assigned on line 81. The variable is already in scope; the reassignment is dead.

**Fix:** Delete the duplicate assignment at line 86.

---

### PY-002 · P1 · `connector.py:189`
**String literal `"MESG_QUICKCONN"` instead of imported constant `MESG_QUICKCONN`**

Every other `_send_control` call uses the constant. A value-changing refactor of the constant would silently corrupt the initiate handshake.

**Fix:** Replace with `MESG_QUICKCONN`.

---

### PY-003 · P1 · `protocol.py:270–274`
**`build_control_text` embeds caller-supplied `txt` without escaping — control field injection**

The parser tokenises on `;` and splits on `:`. A value like `txt = "legit;SRCIP:attacker.com"` silently overwrites `fields["SRCIP"]`. This applies to both `MESG_REJECT` and `MESG_CHAT`.

**Fix:** Percent-encode or strip `;` and `:` from `txt` before embedding, or ensure TXT is always the last field (so trailing garbage is inert).

---

### PY-004 · P1 · `backends.py:318` + `runtime.py:106–113`
**Non-`CancelledError` exception from dying audio subprocess bypasses `send_disconnect()`**

`LolaLinuxRuntime.stop()` uses `suppress(asyncio.CancelledError)` when awaiting tasks, which does not suppress `IncompleteReadError`. A dying audio subprocess leaves the remote LoLa peer in a connected state.

**Fix:** In `stop()`, use `suppress(Exception)` (or a dedicated `StopError`) when awaiting tasks, logging non-cancellation failures before proceeding to close sockets.

---

### PY-005 · P1 · `backends.py:343, 377, 408, 459`
**`assert` used as runtime guard — stripped by `python -O`, causing `None` dereference**

Before dereferencing `self.process` and its I/O streams in four methods (`write_block`, `read_frame` x2, `show_frame`), `assert self.process is not None` is the only guard.

**Fix:** Replace each `assert` with `if … is None: raise RuntimeError(…)`.

---

### PY-006 · P1 · `connector.py:224`
**`accept_once()` has no timeout — hangs forever on misconfiguration**

`initiate()` has a `timeout=2.0` default; `accept_once()` blocks indefinitely.

**Fix:** Add `timeout: float | None = None` parameter, thread into `_receive_control_until`.

---

### PY-007 · P1 · `runtime.py:99–104`
**`start()` appends to `self._tasks` without clearing — stale handles accumulate on restart**

Calling `start()` a second time accumulates completed task handles; their stored exceptions surface from `stop()`.

**Fix:** Assert `not self._tasks` at the top of `start()`, or clear the list before appending.

---

### PY-008 · P1 · `backends.py:299`
**Dead-process check uses only `is None` — does not detect silent subprocess exit**

`self.process` is non-`None` but `returncode` may be set if the process exited silently. The next `readexactly` raises `IncompleteReadError` rather than a clear "process died" error.

**Fix:** Add `or self.process.returncode is not None` to the start guard.

---

### PY-009 · P1 · `selftest.py:30–32`
**Single `await asyncio.sleep(0)` does not guarantee `accept_once()` has bound its socket**

One event-loop yield only schedules the task; on a loaded system the QuickConn can arrive before the server socket is ready.

**Fix:** Use an `asyncio.Event` signalled from inside `accept_once()` after binding.

---

### PY-010 · P2 · `connector.py:229` + `runtime.py:229`
**`assert self._control_sock is not None` in task coroutines — stripped by `-O`**

Becomes an unconditional `None`-dereference under optimisation.

**Fix:** Replace with `if self._control_sock is None: raise RuntimeError(…)`.

---

### PY-011 · P2 · `npcap_udp_relay.py:62–63`
**Blocking UDP sockets in relay loop — `EAGAIN` blocks the entire tshark pipeline**

If the kernel send buffer is full, `sendto()` blocks the entire relay loop, potentially dropping live LoLa packets.

**Fix:** Set sockets non-blocking and catch `BlockingIOError`, or use `asyncio.DatagramTransport`.

---

### PY-012 · P2 · `tools/lola_packet_decoder.py:29` + `pyproject.toml`
**`scapy` imported but not in `pyproject.toml` dependencies — `ModuleNotFoundError` on clean install**

**Fix:** Add `scapy` to `[project.optional-dependencies].pcap` and document the install step.

---

### PY-013 · P2 · `connector.py:331` + `runtime.py:245, 262`
**`socket.gethostname()` embedded in every outgoing control datagram — hostname leakage**

On shared build machines or CI runners, the hostname is broadcast to all LoLa peers and passive observers.

**Fix:** Accept optional `source_name` in `LolaConnector.__init__` defaulting to `""` or a user-configurable value.

---

### PY-014 · P2 · `media.py:425–426`
**`ProcessJpegVideoCapture._extract_frame()` overshoots buffer cap on multi-frame accumulation**

`len(self._buffer) > self.max_frame_bytes` measures the entire buffer from the last SOI marker, not just the current frame. A slow consumer accumulating several frames trips the cap even though no single frame exceeds it.

**Fix:** Track the SOI marker position and measure only bytes from the current SOI.

---

### PY-015 · P2 · `media.py:237–241`
**`MediaReassembler` can pre-allocate ~128 MiB per malicious VideoPrelude**

`expected_size` up to 16 MiB and `fragment_count` up to 16 384 from a peer with no per-session rate limit. For a QuickConn-authenticated session this is an acceptable trust boundary, but it is undocumented.

**Fix:** Document the intentional trust boundary explicitly, or add a per-session fragment-count-per-second limit.

---

### SH-001 · P1 · `scripts/lib/common.sh`
**No `set -euo pipefail` in shared library**

Always sourced into scripts that have it, but a future direct invocation would silently ignore errors from `require_file`, `require_file_contains`, etc.

**Fix:** Add `set -euo pipefail`, or at minimum a guard comment: `# Requires caller to have set -euo pipefail`.

---

### SH-002 · P1 · `scripts/lib/parity.sh`
**No `set -euo pipefail` in shared library**

`parity_wait_for_file_text` and `parity_wait_for_docker_log_text` return non-zero on timeout; without `-e`, callers silently continue past a timeout failure.

**Fix:** Same as SH-001.

---

### SH-003 · P1 · `script/build_and_run.sh:23–24`
**`pkill -x "$APP_NAME"` kills processes for all users on the machine**

On a CI runner or shared host, this terminates other users' `open-lola-app` instances.

**Fix:** Scope to current user: `pkill -u "$USER" -x "$APP_NAME"`.

---

### SH-004 · P1 · `run-local-jacktrip-rxtx-docker.sh:5` + `run-local-ultragrid-rxtx-docker.sh:5` + `run-local-ultragrid-rxtx-native.sh:6`
**Fixed `${TMPDIR:-/tmp}/open-lola-*` output directory — concurrent runs clobber each other**

Two parallel CI jobs overwrite each other's reports, journals, and connection metrics without error.

**Fix:** Suffix with `$$`: `${TMPDIR:-/tmp}/open-lola-jacktrip-rxtx-$$`.

---

### SH-005 · P1 · `compare-local-*.sh` + `stress-local-*.sh` (5 scripts)
**Same fixed output directory race as SH-004**

`compare-local-jacktrip-parity-docker.sh:11`, `compare-local-ultragrid-parity-docker.sh:9`, `compare-local-ultragrid-parity-native.sh:9`, `stress-local-ultragrid-parity-docker.sh:4`, `stress-local-ultragrid-parity-native.sh:4`.

**Fix:** Same as SH-004.

---

### SH-006 · P2 · `open-lola-jacktrip-docker-client.sh:95`
**`${jacktrip_args[*]}` joins array with `IFS` — embedded spaces break Docker entrypoint argument splitting**

**Fix:** Pass arguments individually via repeated `-e` flags or use a newline-delimited variable with a matching split in the entrypoint.

---

### SH-007 · P2 · `run-local-ultragrid-rxtx-docker.sh:35–37` + `run-local-ultragrid-rxtx-native.sh:48–50`
**`monotonic_ms()` duplicated from `parity.sh` — must be fixed in three places**

**Fix:** Source `parity.sh` and call `parity_monotonic_ms` instead.

---

### SH-008 · P2 · `compare-local-ultragrid-parity-docker.sh:119–121` + `compare-local-ultragrid-parity-native.sh:75–82`
**`assert_ultragrid_runtime_log` version check pinned in Docker variant, any-version in native — version mismatch on native is undetectable**

**Fix:** Accept the version string as a parameter defaulting to the pinned release; share one definition in `parity.sh`.

---

### SH-009 · P2 · `parity.sh:56`
**`docker logs … || true` suppresses all Docker errors — downstream failures produce misleading messages**

`docker not on PATH`, daemon unreachable, and invalid container name are all silently swallowed; callers see confusing "missing expected text" errors.

**Fix:** Remove `|| true`; explicitly check Docker availability and container existence before calling `docker logs`.

---

### SH-010 · P2 · `open-lola-ultragrid-native-client.sh:67, 75`
**Array slice arithmetic `${arr[@]:peer_index + 1}` is bash-specific — fails under strict sh or static analysis**

**Fix:** Use explicit temporary: `next=$(( peer_index + 1 ))` then `"${arr[@]:$next}"`.

---

### SH-011 · P2 · `script/build_and_run.sh:28` + `script/build_cli_app_bundle.sh:18`
**`swift build --show-bin-path` without `--product` may trigger unnecessary incremental build**

On some toolchain versions this rebuilds the default target, potentially overwriting a just-built product.

**Fix:** Use `swift build --product "$PRODUCT_NAME" --show-bin-path` in the same invocation, or hard-code `.build/debug` and assert its existence.

---

## 9. Cross-cutting Summary

### Finding counts by tier and subsystem

| Subsystem | P0 | P1 | P2 | Total |
|-----------|----|----|-----|-------|
| Realtime Audio | 4 | 9 | 6 | **19** |
| Timing / RX Buffering | 1 | 9 | 18 | **28** |
| UDP / Network / P2P | 0 | 3 | 8 | **11** |
| Video Transport & Capture | 2 | 7 | 10 | **19** |
| Control (OSC/ATEM/Lighting) | 0 | 4 | 7 | **11** |
| UI — SwiftUI App | 0 | 8 | 20 | **28** |
| Core Infra & CLI | 1 | 10 | 9 | **20** |
| Python / Scripts | 0 | 9 | 6 | **15** |
| Shell Scripts | 0 | 5 | 6 | **11** |
| **TOTAL** | **8** | **64** | **90** | **162** |

---

### Top P0 issues — fix these first

| ID | File | Description |
|----|------|-------------|
| AUDIO-001 | `DirectPeerRealtimeAudioGraph.swift:302` | UInt64 overflow trap in audio callback after hours of uptime |
| AUDIO-002 | `DirectPeerRealtimeAudioGraph.swift:607–609` | `assertionFailure` in CoreAudio IOProc — illegal in RT |
| AUDIO-003 | `DirectPeerRealtimeAudioGraph.swift:141–196` | Concurrent IOProc race on shared scratch buffers |
| AUDIO-004 | `DirectPeerRealtimeAudioGraph.swift:250–324` | SPSC ring written from two threads — silent data race in Release |
| TIME-001 | `SPSCAtomicRing.swift:36–64` | SPSC memory ordering unverified — potential silent audio corruption |
| VID-001 | `VideoTransportReassembly.swift:239–240` | First fragment double-inserted — memory waste and incorrect metrics |
| VID-007 | `VideoCaptureAVFoundation.swift:~288–320` | Device permanently locked after `canAddOutput` guard failure |
| CORE-001 | `Release/PackagingFieldTestRun.swift:~162` | Dead ternary — release gate can never produce `.pass` |

---

### High-impact P1 clusters

**Correctness of the release pipeline (CORE-001–005, CORE-007):**  
The packaging verdict is permanently `.partial`, recording metrics are synthetic/trivial, FNV-1a is used as an integrity hash, and the release-hardening runner evaluates no gates. The entire release gate infrastructure produces non-evidence.

**Realtime audio glitch sources (AUDIO-005–013):**  
Late-packet misclassification, hash-collision-driven packet drops, 1 ms sleep exceeding packet period, and heap allocation in the transmit path are four independent paths to audible artefacts.

**Network protocol correctness (NET-001–003):**  
Padded Ethernet frames always fail wire decoding, a single malformed BPF record silences an entire batch, and TCP control exchange truncates messages — these make the LoLa compatibility layer unreliable on physical hardware.

**Video reassembly (VID-001–003, VID-007, VID-011):**  
Double-insertion of the first fragment, sequence-number wraparound stall, wrong eviction boundary, permanent device lock, and continuity-check failure at UInt64.max combine to make multi-stream reassembly fragile.

**Missing test coverage (TEST-001–003):**  
`PlaceholderDetection`, `FileDescriptorSet`, and the CoreAudio recording live-capture path have zero unit tests despite being critical-path components.

---

### Structural / architectural debt (P2 clusters)

1. **Duplicated validation helpers** — ~25+ structurally identical `requireXxxNonNegative/Positive/NonEmpty/Finite` families across 8+ files (AUDIO-016, TIME-023, TIME-024). A single refactor eliminates hundreds of lines.

2. **Manual `Codable` boilerplate** — `RealtimeAudioHandoffMetrics` and several report types have 60–120 lines of hand-written encode/decode that could be synthesised (AUDIO-017).

3. **Unbounded in-memory growth** — `VideoOutputRenderer` latency arrays, `videoCaptureAVFoundation` rawFrameData blob, and `activeFrameOrder` nil accumulation all grow without bound at high frame rates (VID-010, VID-013, VID-004).

4. **UI accessibility** — the entire app is effectively inaccessible: no accessibility labels on interactive controls, no representation for the topology diagram, no selected-state traits, no VU meter announcements (UI-009–014).

5. **Dead and stale code** — `MeasurementMethodology.swift` (TIME-025), `audioDeviceUID` field (AUDIO-019), stale M02 `DevelopmentStage` enum (TIME-028, TEST-005), dead `connectingState` (UI-008), empty `deinit` bodies (UI-015).

---

*Document generated by automated fleet audit — 7 sub-agents, full-file read of all 292 Swift sources plus Python and shell scripts.*
