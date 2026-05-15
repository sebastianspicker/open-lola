# open-lola2 — Full Codebase Audit & Remediation Plan

**Scope:** 290 Swift source files, 1 C file, 1 C header across `Sources/OpenLolaCore`, `Sources/open-lola-app`, `Sources/open-lola` CLI.  
**Method:** 5 parallel sub-agent deep reads, every file read in full.  
**Status:** 4/5 sub-audits complete; Core/CLI/Benchmarks audit still compiling. All known findings enumerated below. Core findings will be appended when agent completes.

---

## Finding Count by Priority

| Priority | Count | Subsystem distribution |
|---|---|---|
| **P0** | 3 | Audio (3) |
| **P0-RELEASE** | 3 | Core/Project (3): no license, no third-party notices, no reviewer signoff |
| **P1** | 31 | Audio (11), Network/UDP/P2P/NAT/Video (7), Control/Protocol/Connectors (7), UI (4), Core (2: F-CORE-001 license, F-CORE-002 dead doc refs) |
| **P2** | 91 | Audio (15), Network (14), Control/Connectors (12), UI (31), Core (12: F-CORE-003..015), Project (3: PROJ-04..06) |

---

## P0 — Must fix before any real-time session

---

### F-AUDIO-001 · P0 · RealtimeSafety
**File:** `Audio/MADI/MadiReceive.swift` lines 264–283  
**Function:** `MadiReceiveEngine.applyReceiverMix()`  
**Description:** Three heap allocations (`[UInt8]`, `[UInt8]` copy, `Data`) in every `renderCallback()` invocation. Called ~1500×/s at 32-frame/48 kHz. Allocator lock contention or Apple Silicon background compaction causes guaranteed audio glitches.  
**Fix:** Pre-allocate a fixed-size scratch buffer in `MadiReceiveEngine.init`. Reuse with `memset`/`memcpy`. Eliminate all `Data` construction on realtime thread.

---

### F-AUDIO-002 · P0 · RealtimeSafety
**File:** `Audio/MADI/MadiReceive.swift`  
**Function:** `pendingDeadlines: Dictionary` mutated in receive path feeding `renderCallback()`  
**Description:** `Dictionary` insertions/removals trigger COW or capacity-growth heap allocations on the RT path. Any rehash is O(n) and allocates.  
**Fix:** Replace `Dictionary` with a fixed-capacity slot-indexed structure keyed by `sequenceNumber % capacity`.

---

### F-AUDIO-003 · P0 · RealtimeSafety
**File:** `Audio/CoreAudio/AudioLoopbackRun.swift` lines 383–412  
**Function:** `AudioLoopbackIOProcState.record()` (runs inside Core Audio IOProc)  
**Description:** Calls `captureRing.pushAudioBuffers()` → `validInterleavedSource()` which allocates `Set(inputChannelMap)` and `Array(0..<channelCount)` on every audio callback cycle (F-AUDIO-004 is the same call chain).  
**Fix:** Cache `channelSet` and `channelIndices` in `RealtimeAudioPayloadCaptureRing.init`; only recompute on configuration change.

---

## P1 — Broken features / correctness failures

---

### F-AUDIO-004 · P1 · RealtimeSafety
**File:** `Audio/Realtime/RealtimeAudioPayloadCaptureRing.swift` lines 243, 248  
**Description:** `Set(inputChannelMap)` and `Array(0..<channelCount)` allocated on every audio callback. Same root as F-AUDIO-003.  
**Fix:** Same as F-AUDIO-003.

### F-AUDIO-005 · P1 · RealtimeSafety
**File:** `Audio/Realtime/RealtimeAudioPacketHandoff.swift` lines 132, 164  
**Description:** `DispatchTime.now()` (kernel-mode clock read) called in send path on audio capture callback thread.  
**Fix:** Replace with `mach_absolute_time()` + pre-queried timebase (already done correctly in `DirectPeerRealtimeAudioGraph.nanoseconds(fromHostTime:)`).

### F-AUDIO-006 · P1 · RealtimeSafety
**File:** `Audio/Realtime/DirectPeerAudioPayloadRing.swift` line 72  
**Description:** `Data(bytes:count:)` heap allocation in `pop()` on the realtime output consumer thread.  
**Fix:** Use `captureRing.withPoppedPayload()` (UnsafeRawBufferPointer, zero-copy) in any realtime consumer.

### F-AUDIO-007 · P1 · RealtimeSafety
**File:** `Audio/MADI/MadiReceive.swift` line 437  
**Description:** `fragmentsByIndex.keys.sorted().compactMap{}` in computed property `packets` — two O(n) heap allocations on every receive tick feeding realtime path.  
**Fix:** Maintain fragments in a pre-allocated sorted array; expose an iterator instead of materializing arrays.

### F-AUDIO-010 · P1 · LogicBug
**File:** `Audio/Realtime/RealtimeAudioBuffers.swift` lines 266–276  
**Description:** `dropStalePackets(before:)` called before capacity guard in `enqueue()`; concurrent producer can bypass capacity check, causing frame-index aliasing.  
**Fix:** Snapshot `bufferedPackets` after `dropStalePackets` returns; use snapshot for capacity check.

### F-AUDIO-011 · P1 · LogicBug
**File:** `Audio/Realtime/RealtimeAudioPacketHandoff.swift` lines 218–223  
**Description:** `.droppedInvalid` from `playout.enqueue()` returned as `.droppedFull` — callers cannot distinguish backpressure from invalid block.  
**Fix:** Add `.droppedInvalid` to `RealtimeAudioPacketReceiveResult` and propagate it.

### F-AUDIO-012 · P1 · LogicBug
**File:** `Audio/MADI/MadiFullDuplexRuntime.swift` line 410  
**Description:** `metrics.transmittedBlocks * localSendMode.framesPerPacket` multiplied as `Int` before `UInt64` cast — silent overflow possible in long sessions.  
**Fix:** `UInt64(metrics.transmittedBlocks) * UInt64(localSendMode.framesPerPacket)`.

### F-AUDIO-013 · P1 · LogicBug
**File:** `Audio/MADI/MadiFullDuplexTypes.swift` line 337  
**Description:** `UInt64` subtraction `last.receiverPlayoutFrameIndex - first.receiverPlayoutFrameIndex` wraps on clock discontinuity — produces bogus drift slope.  
**Fix:** Guard that `last >= first` before subtraction; return `nil` if not monotonic.

### F-AUDIO-014 · P1 · LogicBug
**File:** `Audio/CoreAudio/AudioLoopbackRun.swift` line 384  
**Description:** `hostTime * timebaseNumerator` in `UInt64` can overflow on non-standard timebase ratios.  
**Fix:** Use `UInt64.multipliedReportingOverflow(by:)` with overflow guard.

### F-AUDIO-015 · P1 · LogicBug
**File:** `Audio/CoreAudio/AudioLoopbackRun.swift` line 400  
**Description:** `hostTimeNanoseconds - lastHostTimeNanoseconds` wraps on non-monotonic host time at startup/sleep-wake.  
**Fix:** Guard `hostTimeNanoseconds > lastHostTimeNanoseconds`; skip non-monotonic sample.

### F-AUDIO-016 · P1 · LogicBug / Memory Leak
**File:** `Audio/CoreAudio/CoreAudioInventoryReader.swift` line 181  
**Description:** `takeUnretainedValue()` on a `+1`-retained `CFString` from `AudioObjectGetPropertyData` leaks one CFString per property per device on every inventory scan.  
**Fix:** `takeRetainedValue()`.

### F-AUDIO-017 · P1 · TimingBug / Performance
**File:** `Audio/MADI/MadiReceive.swift` — `MadiReceiveReadyBlockRing`  
**Description:** `contains()`, `store()`, `remove()` all O(n) linear scan via `firstIndex(where:)`. Under burst conditions burns realtime budget.  
**Fix:** Slot-addressed array keyed by `frameIndex % capacity` for O(1) ops.

---

### F-UI-001 · P1 · LogicBug (was P0 — crash)
**File:** `open-lola-app/AppReceiverPreviewServices.swift` lines 158–162  
**Description:** `AppAudioLevelMeter.deinit` calls `MainActor.assumeIsolated { timer?.invalidate(); tap.stop() }`. Swift does not guarantee `deinit` runs on the main actor — the last strong reference may be dropped from a background thread. `assumeIsolated` precondition-crashes (trap) if called off main thread.  
**Fix:** Dedicated `@MainActor func tearDown()` called from `onDisappear`; `deinit` must be a no-op.

### F-UI-002 · P1 · LogicBug / UIBug
**File:** `open-lola-app/AppReceiverPreviewServices.swift` lines 285–299  
**Description:** `level(for:)` interprets Float32 Core Audio buffers as UInt8 PCM (centre=128). Every channel meter displays garbage or near-zero values regardless of actual signal level.  
**Fix:** Cast `mData` to `Float*`; compute `abs(floats[i])` clamped to 0…1.

### F-UI-003 · P1 · LogicBug
**File:** `open-lola-app/AppStorageKeys.swift` lines 51–52  
**Description:** Hardcoded `/tmp/open-lola-mac-to-mac/` paths fail in any sandboxed distribution (App Store, Gatekeeper notarization with sandbox).  
**Fix:** Use `FileManager.default.temporaryDirectory` or `applicationSupportDirectory`.

### F-UI-004 · P1 · LogicBug
**File:** `open-lola-app/AppExecutionController.swift` lines 31–33  
**Description:** `deinit` accesses `@MainActor`-isolated `process` property outside actor isolation. `@unchecked Sendable` masks the race. Data race in strict concurrency mode.  
**Fix:** Remove `@unchecked Sendable`; add `@MainActor func stop()` teardown; `deinit` must be a no-op.

### F-UI-005 · P1 · LogicBug
**File:** `open-lola-app/AppReceiverPreviewServices.swift` lines 20–22  
**Description:** `AppVideoPreviewController.deinit` same actor-isolation violation as F-UI-004.  
**Fix:** Same pattern — explicit teardown, no-op `deinit`.

---

### F-NET-001 · P1 · UDP correctness
**File:** `Network/UDP/UdpPcmSocketOperations.swift` lines 26–31  
**Description:** `closeUdpSocket` failure uses `assertionFailure` — compiled out in release builds; double-close or bad-fd goes unreported in production.  
**Fix:** Use `os_log(.fault, ...)` that survives release builds.

### F-NET-002 · P1 · UDP correctness
**File:** `Network/UDP/UdpMediaTransport.swift` lines ~384–391  
**Description:** `receiveFailed(EBADF)` thrown for ALL operations (including send) when socket is closed. Callers on send path that only catch send-specific errors silently discard the error.  
**Fix:** Add `sendFailed(Int32)` case or a generic `socketClosed` error; throw the appropriate variant per operation.

### F-NET-005 · P1 · UDP correctness
**File:** `Network/UDP/UdpPcmRouteLocalhostSmoke.swift` line 88  
**Description:** `playoutTargetMicroseconds: 666` hardcoded — should use `playoutTargetMicroseconds(packetMode)`. Wrong threshold causes wrong latency verdicts for non-standard modes.  
**Fix:** Replace `666` with `playoutTargetMicroseconds(packetMode)`.

### F-NET-007 · P1 · P2P Logic
**File:** `Network/P2P/DirectPeerMeshRuntimeReport.swift` line ~304  
**Description:** Unbounded blocking receive (2 s timeout) per fragment in mesh test loop; a single lost fragment hangs for 2 s × count, causing test timeouts instead of fast loss diagnostics.  
**Fix:** Non-blocking receive in outer timed loop with partial-loss diagnostic on deadline expiry.

### F-NET-009 · P1 · P2P / Resource Leak
**File:** `Network/P2P/PeerSessionRunner.swift` lines 90–105  
**Description:** Sequential `UdpMediaTransport` init — if 2nd or 3rd throws, already-created transports (open UDP file descriptors) are leaked.  
**Fix:** `defer { closeUdpSocket }` with `succeeded` flag pattern, or cleanup in catch block.

### F-NET-010 · P1 · NAT Traversal
**File:** `Network/NAT/NatFriendlyRouteRunner.swift` lines 111–121  
**Description:** RTT never measured when hole-punching requires more than one keepalive round — `sawPeerKeepalive` breaks out of loop before ack sequence confirmed.  
**Fix:** Move `sawPeerKeepalive` break to else-branch of ack check.

### F-NET-012 · P1 · NAT / Resource Leak
**File:** `Network/NAT/NatFriendlyRouteHelpers.swift`  
**Description:** Socket leaked if `boundPort()` throws in `openRegisteredSocket`.  
**Fix:** `defer { if !succeeded { closeUdpSocket(socket) } }` immediately after `makeUdpSocket`.

### F-NET-015 · P1 · Video / Resource Leak
**File:** `Network/Diagnostics/NetworkDiagnostics.swift` lines 429–438  
**Description:** `readDataToEndOfFile` blocks permanently if subprocess ignores SIGTERM after timeout — hangs calling thread.  
**Fix:** After SIGTERM, use `availableData` (non-blocking) or escalate to SIGKILL, close write-end of pipe before reading.

---

### F-LOLA-001 · P1 · LoLaBug
**File:** `Connectors/LoLa/LoLaCompatibilityMediaCodec.swift` lines 264–270  
**Description:** `reassemble()` throws `outOfOrderFragment` on good data when the input `fragments` array arrives in network order (not index order). Fragments reassembled successfully by index-keyed dict but then discarded due to order check.  
**Fix:** Sort `fragments` by index before iterating, or remove the order precondition.

### F-LOLA-002 · P1 · LoLaBug
**File:** `Connectors/LoLa/LoLaCompatibilityMediaEnvelopeValidation.swift` lines 67–75  
**Description:** `sourcePort == destinationPort` rejects all standard asymmetric-source-port UDP — Windows LoLa and any kernel-assigned ephemeral TX port will be blocked.  
**Fix:** Validate only `destinationPort`.

### F-LOLA-003 · P1 · LoLaBug
**File:** `Connectors/LoLa/LoLaCompatibilityWireFrame.swift`  
**Description:** `ipv4Identification == 0x1337` — reverse-engineered from single Linux binary; blocks all Windows LoLa media packets (OS uses incrementing IDs).  
**Fix:** Remove or conditionalize behind a strict/debug mode flag.

### F-LOLA-006 · P1 · LoLaBug
**File:** `Connectors/LoLa/LoLaTcpControlExchangeRuntime.swift` lines 323–334  
**Description:** TCP control messages sent without 1024-byte NUL padding required by LoLa wire spec (UDP path applies it via `lolaControlDatagramBytes()`; TCP path skips this).  
**Fix:** Apply `lolaControlDatagramBytes()` padding in `sendExternalConnectorTcp`.

### F-LOLA-008 · P1 · LoLaBug
**File:** `Connectors/LoLa/LoLaControlHandshakeValidation.swift` line 57  
**Description:** SRCIP/DSTIP validated by raw string equality — any format difference (trailing space, port suffix, zero-padding) from Windows LoLa breaks handshake.  
**Fix:** Normalise with `inet_pton` → `inet_ntop` before comparison.

### F-PROT-001 · P1 · ProtocolBug
**File:** `Protocol/SessionNegotiation.swift` lines 227–231  
**Description:** `denominator == 1` constraint on video frame rate rejects all NTSC/broadcast rates (29.97, 59.94, 23.976 fps). No production broadcast workflow can negotiate video.  
**Fix:** Remove `denominator == 1`; validate `numerator/denominator ≤ maxFrameRate` as rational comparison.

### F-CTRL-001 · P1 · ConnectorBug
**File:** `Control/LightingFixtureGateRun.swift` lines 173–188  
**Description:** `captured: true` set but `packetCount: 0` hardcoded → `validate()` always throws `packetCaptureAccountingMismatch`. No non-dry-run lighting gate run can produce a valid report.  
**Fix:** Set `captured: false` or count and record actual captured packets.

---

## P2 — Quality, maintainability, risk

### Audio P2 findings

### F-AUDIO-008 · P2 · RealtimeSafety
**File:** `Support/SPSCAtomicRing.swift` lines 63–73  
`pthread_threadid_np` syscall in `assertSingleOwner` — not RT-safe if called from audio callback.  
**Fix:** Wrap entire `assertSingleOwner` call site in `#if DEBUG`.

### F-AUDIO-009 · P2 · RingBuffer
**File:** `Audio/Realtime/DirectPeerAudioPayloadRing.swift`  
`occupied:[Bool]` synchronization relies on C-call compiler barrier + acquire/release without documentation. Fragile under LTO.  
**Fix:** Document memory ordering invariant at both store sites; or wrap `occupied` as atomic values.

### F-AUDIO-018 · P2 · LogicBug
**File:** `Audio/Realtime/RealtimeAudioBuffers.swift` line ~140  
`.droppedFull` returned for "too far ahead" block — ambiguous to callers.  
**Fix:** Add `.droppedAhead` case.

### F-AUDIO-019 · P2 · TimingBug
**File:** `Audio/MADI/MadiReceive.swift` lines 175–177  
Warmup silences increment `underrun` counter — metrics meaningless before buffer is primed.  
**Fix:** Track `warmupComplete` flag; only count underruns after warmup.

### F-AUDIO-020 · P2 · TimingBug
**File:** `Audio/Realtime/RealtimeAudioBuffers.swift` lines 388–390  
`hiddenPlayoutGrowthDetected` not reset after stale-drops reduce buffer below capacity.  
**Fix:** Update/reset `maximumBufferedBlocks` in `dropStalePackets`.

### F-AUDIO-021 · P2 · DeadCode
**File:** `Audio/MADI/MadiReceive.swift` line 379  
`missingFragmentIndices` parameter received but `_ = missingFragmentIndices` immediately.  
**Fix:** Record in diagnostic ring or remove parameter from signature.

### F-AUDIO-022 · P2 · DeadCode
**File:** `Audio/MADI/MadiReceive.swift` line 167  
`receivedAtHostTimeNanoseconds` arrival timestamp discarded — jitter/drift calculation impossible.  
**Fix:** Compute packet age and feed to jitter estimator.

### F-AUDIO-023 · P2 · LogicBug
**File:** `Audio/Realtime/RealtimeAudioEngineReportValidation.swift` line 65  
Non-exhaustive ternary for packet format — silent wrong output for any 3rd format.  
**Fix:** Exhaustive `switch`.

### F-AUDIO-024 · P2 · DeadCode / False Safety Claim
**File:** `Audio/CoreAudio/AudioLoopbackRun.swift` lines 180–188  
`callbackSafetyChecklist` hardcodes `noAllocationInCallback: true` — directly contradicts F-AUDIO-001 through F-AUDIO-003.  
**Fix:** Set all fields to `false` until runtime-measured; remove static checklist.

### F-AUDIO-025 · P2 · LogicBug
**File:** `Audio/MADI/MadiFullDuplexRuntime.swift` line 427  
`throw MadiFullDuplexError.emptyField("running")` — wrong error type for state-machine violation.  
**Fix:** Add `case notStarted` to error enum.

### F-AUDIO-026 · P2 · LogicBug
**File:** `Timing/DriftPlcFixedTargetCertification.swift` line 130  
`notTestedReason?.isEmpty != true` passes when `notTestedReason == nil` — opposite of intent.  
**Fix:** `notTestedReason?.isEmpty == false`.

### F-AUDIO-027 · P2 · LogicBug
**File:** `Timing/DriftPlcFixedTargetCertification.swift` line 237  
Same nil-pass bug as F-AUDIO-026 in `validateIdentity()`.  
**Fix:** Same: `== false` not `!= true`.

### F-AUDIO-028 · P2 · LogicBug / Data Integrity
**File:** `Timing/DriftPlcRun.swift` lines 146–147  
`callbackP99/MaxMicroseconds` fabricated by capping packet-age at 200/300 µs — certification chain accepts unrealistic callback timing.  
**Fix:** Populate from actual measured callback duration (e.g., `RealtimeAudioEngineReport.callbackDurationP99Microseconds`).

### F-AUDIO-029 · P2 · LogicBug
**File:** `Timing/LatencyProfileContracts.swift` line 219  
Warning acknowledgement only enforced when `requiresExperimentalOptIn` also true — `ultraLowLatency16` profile's hardware warning silently skipped.  
**Fix:** Decouple: `if let _ = policy.warning, !request.warningAcknowledged { throw ... }`.

---

### Network P2 findings

### F-NET-003 · P2 · UDP correctness
No `SO_RCVBUF`/`SO_SNDBUF` tuning anywhere — OS default 212 KB insufficient for 64-channel bursts or video fragment storms.  
**Fix:** `setsockopt(SO_RCVBUF, 4MB)` on receive sockets immediately after creation.

### F-NET-004 · P2 · UDP correctness
`UdpPcmContinuousRouteRunner` creates send-only socket with wasteful `SO_RCVTIMEO`.  
**Fix:** `makeUdpSocket(receiveTimeoutSeconds: 0)` for send-only sockets.

### F-NET-006 · P2 · UDP correctness
`setsockopt` return value silently ignored in `UdpPcmPacket.makeSocket`.  
**Fix:** Check return; throw or `assertionFailure` on failure.

### F-NET-008 · P2 · P2P Logic
Partial `AVCaptureSession` left uncommitted/unreleased on `canAddOutput` failure.  
**Fix:** Assign `self.session` before guard, or only commit after full configuration.

### F-NET-011 · P2 · NAT Traversal
`>2-peer rendezvous` delivers only first peer's endpoint — third peer invisible in 3-peer mesh.  
**Fix:** Send all other registered peer endpoints to each registrant.

### F-NET-013 · P2 · NAT Traversal
`sampleRateHertz: 5` in `makeNatLoopbackConfiguration` is a packet rate, not a sample rate — misleading parameter name.  
**Fix:** Rename parameter or add explanatory comment.

### F-NET-014 · P2 · Video Transport
Synthetic +100 ns offsets make `reassemblyToRender`/`renderToOutput` metrics always report ~0 — latency budgeting consumers receive false data.  
**Fix:** Feed actual render timestamps from video output backend.

### F-NET-016 · P2 · Dead Code
Dead `if !acceptedRegistration { continue }` branch in `NatRendezvousRelayRunners.swift`.  
**Fix:** Remove; unconditional `continue` below already covers it.

### F-NET-017 · P2 · Dead Code
`receiveLocked` and `receiveRawLocked` are ~90-line copy-paste in `VideoTransportReassembly.swift`.  
**Fix:** Extract shared bucket management into `receiveBucketLocked(_:)`.

### F-NET-018 · P2 · Dead Code
Duplicate `readUInt*LE`/`appendUInt*LE` helpers in both `UdpPcmPacket.swift` and `UdpPcmV2Packet.swift`.  
**Fix:** Move to shared `UdpPcmDataHelpers.swift`.

### F-NET-019 · P2 · Dead Code
`invalidPositiveInt` error case misused for enum-string validation failures in `DirectPeerTwoPeerRunPlan.swift`.  
**Fix:** Add `case invalidEnumValue(String)`.

### F-NET-020 · P2 · Dead Code
V2→V1 protocol fallback sets `warnings: []` unconditionally — no diagnostic that preferred V2 was unavailable.  
**Fix:** Append `"preferredV2NotAvailable"` to `warnings`.

### F-NET-021 · P2 · UDP correctness
Fixed 1-second echo deadline in `waitForConnectedEcho` ignores actual packet interval.  
**Fix:** Scale deadline to `max(3 × packetIntervalMicroseconds, 50_000) µs`.

---

### Control / Connector P2 findings

### F-LOLA-004 · P2 · LoLaBug
TXT field with embedded `;` silently truncated in `LoLaCompatibilityControlMessage.parse()`.  
**Fix:** Escape or use smarter parser.

### F-LOLA-005 · P2 · LoLaBug
BPF `read() == 0` treated as timeout instead of empty-ring retry in `LoLaCompatibilityRawLink.receive()`.  
**Fix:** Add `byteCount == 0` to EAGAIN/EWOULDBLOCK retry branch.

### F-LOLA-007 · P2 · LoLaBug
Timeout fallback in `LoLaControlExchangeRuntime` detected by fragile string comparison of error description.  
**Fix:** Add `isTimeout: Bool` flag to `LoLaControlExchangeAttempt`.

### F-PROT-002 · P2 · ProtocolBug
`reconnectDeadlineMilliseconds: 2000` hardcoded in session negotiation — WAN peers may need ≥5 s.  
**Fix:** Add reconnect deadline to `SessionProposal` or `CapabilitySet`.

### F-CTRL-002 · P2 · DeadCode
`OscCueRunners` audio impact metrics always synthetic (hardcoded values); real audio never measured.  
**Fix:** Measure actual audio impact or mark fields with `synthetic: true` companion flag.

### F-SHELL-001 · P2 · ShellBug
`NativeAppShellArtifacts` hardcodes `.build/debug/open-lola` in supervisor command artifact — wrong for release builds.  
**Fix:** `#if DEBUG` conditional or installed-path placeholder.

### F-SHELL-002 · P2 · ShellBug
`--executable` argument in local execution mode is unvalidated.  
**Fix:** Assert/validate that path is a supervisor-capable binary.

### F-CONN-001 · P2 · DeadCode
`runAuxiliaryExternalProcesses()` never called in `ExternalConnectorSessionRuntime`.  
**Fix:** Delete the function.

### F-CONN-002 · P2 · ResourceLeak
`waitpid` returning `ECHILD` silently returns exit code 0 in `ExternalConnectorProcessRunner`.  
**Fix:** Return `Int32.min` or throw on `ECHILD`.

### F-CONN-003 · P2 · ConnectorBug
`EINTR` retry on `kevent` doesn't decrement timeout — effective wait grows unboundedly under signal load.  
**Fix:** Record `clock_gettime` before first call; subtract elapsed on each retry.

### F-CONN-004 · P2 · ConnectorBug
Double SIGTERM: `cleanupExternalConnectorProcessGroup` called after already-terminated group.  
**Fix:** Remove second cleanup after successful terminate+wait sequence.

### F-CONN-005 · P2 · DeadCode
Typo aliases `mtvp-ultragrid`/`mtvpUltraGrid` in `ExternalConnectorParsingDefaults` — never matched by any caller.  
**Fix:** Remove.

---

### UI P2 findings

### F-UI-006 · P2 · LogicBug
`nil` validation exit code shows orange (warning) badge — first-run user sees misleading failure state.  
**Fix:** `executionController.lastValidationExitCode.map { $0 == 0 ? Color.green : Color.red } ?? Color.secondary`.

### F-UI-007 · P2 · UIBug
`stopAnimation()` doesn't cancel `repeatForever` animation; `startAnimation()` stacks multiple animations on same state var.  
**Fix:** Use `@State private var isAnimating` bool to drive animation identity.

### F-UI-008 · P2 · DeadCode
`intBinding` in `AppShellSettingsView` defined, never called.  
**Fix:** Delete.

### F-UI-009 · P2 · DeadCode
`AppWindowSize.inspectorWidth` never referenced.  
**Fix:** Delete or document as reserved.

### F-UI-010 · P2 · DeadCode
Entire `AppRoadmapLaneViews.swift` file never referenced.  
**Fix:** Wire into sidebar or delete.

### F-UI-011 · P2 · Dedup
`operatorPlan` computed twice per render cycle (once in root, once in detail view).  
**Fix:** Pass as parameter from root to detail.

### F-UI-012 · P2 · DeadCode
`selectedAudioInputUID`/`selectedVideoDeviceID` trivial pass-through properties — inline at call site.  
**Fix:** Inline.

### F-UI-013 · P2 · Dedup
Manual `Binding` wrappers on `@Observable` properties in `AppPreviewReceiverView` — use `@Bindable`.  
**Fix:** `@Bindable var previewState`; use `$previewState.audioPreviewEnabled`.

### F-UI-014 · P2 · Dedup / UIBug
Dry Run / Start / Stop buttons and status pills duplicated in both `AppTransportView` and `AppExecutionView`, shown simultaneously.  
**Fix:** Remove duplicate buttons/pills from `AppExecutionView`.

### F-UI-015 · P2 · Quality
Icon dictionaries in `AppDeviceCard` allocated on every render — should be `private static let`.  
**Fix:** `private static let videoSourcePolicyIcons: [AVFoundationVideoSourcePolicy: String] = [...]`.

### F-UI-016 · P2 · DeadCode
`i < levels.count` guard in `AppChannelMeterView` Canvas loop always true (bounded by `channelCount`).  
**Fix:** Direct access `let level = levels[i]`.

### F-UI-017 · P2 · DeadCode
`.monospacedDigit()` after `.font(.latencyHero)` — already monospaced, modifier is no-op.  
**Fix:** Remove.

### F-UI-018 · P2 · Quality
`DispatchQueue.main.async` anti-pattern for SwiftUI animation trigger in `AppSessionStateBanner.restartPulse()`.  
**Fix:** `withAnimation(.easeInOut(...).repeatForever(...)) { pulseOpacity = Animation.dimmedPulseOpacity }`.

### F-UI-019 · P2 · LogicBug
`AppSessionState.derive()` classifies state by `status.contains("connect")` string parsing — fragile; `.connecting` state never actually emitted.  
**Fix:** Replace with typed `enum AppExecutionPhase` property on `AppExecutionController`.

### F-UI-020 · P2 · Dedup / Structural
Two parallel persistence systems (`AppSettings` with 35 `didSet` observers; `AppShellStoredDefaults` reading same keys). Two instances of `AppSettings` (Settings window + in-pane tab) diverge silently.  
**Fix:** Single `@Environment` object or direct `@AppStorage` bindings.

### F-UI-021 · P2 · Structural
4 settings use `@AppStorage` in `AppOperatorArtifactViews` outside the `AppSettings`/`AppShellStoredDefaults` system.  
**Fix:** Migrate to `AppSettings`.

### F-UI-022 · P2 · UIBug
Fixed 480pt height on `AppShellSettingsView` clips tab content on small screens.  
**Fix:** Remove fixed height or wrap each tab's `Form` in `ScrollView`.

### F-UI-023 · P2 · UIBug
`Divider().frame(height:28).overlay(panelBorder)` does not produce a thin vertical separator — wrong modifier.  
**Fix:** `Rectangle().fill(panelBorder).frame(width: 1, height: 28)`.

### F-UI-024 · P2 · LogicBug
Duplicate `AppLocalOperatorInventoryController` in `OpenLolaApp` and `AppLocalOperatorSurfaceView` — refresh state not shared between menu command and in-pane button.  
**Fix:** Hoist controller to `@Environment`.

### F-UI-025 · P2 · UIBug
`remoteStreamTone` hardcoded orange even when macB is configured ("Remote plan only") — semantics wrong.  
**Fix:** `plan.macB == nil ? Color.secondary : Color.blue`.

### F-UI-026 · P2 · Dedup
`hydratePreviewState` constructs full new `AppPreviewReceiverState` then copies fields one-by-one.  
**Fix:** Direct assignment.

### F-UI-027 · P2 · Dedup
`AppReceiverCommandButton` struct wraps one button already present in `AppPreviewReceiverView.body`.  
**Fix:** Remove duplicate from body; keep struct only for menu item.

### F-UI-028 · P2 · Quality
`portBase+1/+2/+3` magic offsets in port label display code — silent breakage if port order changes.  
**Fix:** Named `audioPort`/`videoPort`/`metricsPort` properties on `DirectPeerTwoPeerRunPlanPeer`.

### F-UI-029 · P2 · UIBug
`.task`-driven elapsed timer resets on view identity change mid-session.  
**Fix:** Move timer to `AppExecutionController` as `@Observable var elapsedSeconds: Int`.

### F-UI-030 · P2 · Quality
`surfaceProbe` recomputed on every render of `AppShellDetailView`.  
**Fix:** Cache as `let` in `AppShellRootView`; pass as parameter.

### F-UI-031 · P2 · Dedup
`appPreviewBoolBinding` and `appPreviewDoubleBinding` nearly identical — collapse into generic function.  
**Fix:** Single generic `appPreviewBinding<T>(_:state:storage:)`.

### F-UI-032 · P2 · Quality
`Color.white.opacity(0.12)` and `Color.black.opacity(0.18)` hardcoded off design system in `AppConsoleChromeView`.  
**Fix:** Add `searchFieldBackground` / `footerBackground` tokens to `AppDesignSystem`.

### F-UI-033 · P2 · Quality
Timer callback in `AppReceiverPreviewServices` unnecessarily wraps main-thread work in `Task { @MainActor }`.  
**Fix:** Update `levels` directly in timer closure.

### F-UI-034 · P2 · UIBug / Accessibility
Selected sidebar row uses `.white` foreground on `accentColor.opacity(0.4)` — fails WCAG AA contrast on non-blue system accent colours.  
**Fix:** Use `.foregroundStyle(selected ? .primary : .secondary)`.

### F-UI-035 · P2 · Dedup
`armedBinding` manual Binding wrapper on `@Observable` property — use `@Bindable`.  
**Fix:** `@Bindable var executionController`; `$executionController.armedForExecution`.

### F-UI-036 · P2 · LogicBug
`AppExecutionView.onDisappear` silently stops live supervisor when user navigates to any other sidebar section.  
**Fix:** Remove `onDisappear` stop call; wire teardown only to `ScenePhase.background` in `OpenLolaApp`.

---

## Core / Benchmarks / CLI / Project-level findings

> Agent confirmed: `swift build` ✅ PASS · `swift test --no-parallel` ✅ PASS (1 229 tests, 0 failures)

---

### F-CORE-001 · P1 · Structure / Release Blocker
**File:** `LICENSE`  
**Description:** `LICENSE` contains placeholder text "License Pending Maintainer Review" — no final SPDX-identified license has been selected. `OpenSourceReleaseReadiness` marks this as a hard blocker. The project cannot be publicly released until a license is chosen and all compliance docs are finalized.  
**Affecting files:** `LICENSE`, `docs/compliance/license-decision-record.md`, `THIRD_PARTY_NOTICES.md`, `docs/compliance/fixture-provenance.md`, `docs/compliance/release-manifest.md`, `docs/compliance/final-review-packet.md`  
**Fix:** TODO(human): [Legal gate] → [Select final SPDX license] → [MIT / Apache-2.0 / LGPL-2.1]. Human/legal sign-off required before any files can be published.

---

### F-CORE-002 · P1 · Structure / Dead Reference
**File:** `GoalCodewiseClosure.swift`, `LatencyProfileContracts.swift`  
**Description:** Three architecture docs are cited as codewise evidence but were not found on disk during the audit scan:
- `docs/architecture/latency-profiles.md`
- `docs/architecture/video-blackmagic-atem.md`
- `docs/architecture/p2p-networking.md`

If these files do not exist, codewise closure citations are invalid. Goal completion audit verdict depends on them.  
**Fix:** Verify files exist (`ls docs/architecture/`); if missing, either create stubs or remove the citations and update `GoalCodewiseClosure.swift`.

---

### F-CORE-003 · P1 · BenchmarkBug / False Evidence
**File:** `Release/Goal/GoalRuntimeEvidenceTemplate.swift`  
**Description:** All 10 runtime deliverables are `partial` because no physical hardware evidence has ever been attached. `GoalRuntimeEvidenceTemplateValidationError.deliverablePassWithoutPhysicalEvidence` correctly prevents fake pass — but the template runner commands reference exact peer IPs and device UIDs that are placeholders. Any operator running these as-is will get `preflight` failures with no meaningful diagnostic.  
**Fix:** Document the exact prerequisite checklist (two Macs, RME MADI connection, Blackmagic device, Developer ID cert) in `README.md`; add a `--dry-run` preflight mode that validates prerequisites before attempting physical measurements.

---

### F-CORE-004 · P2 · Structure
**File:** `Support/Inventories/SourceOwnershipInventory.swift` + test `SourceOwnershipInventoryTests`  
**Description:** The ownership inventory maps every source file to an owner tag. If source files are added without updating the inventory, `SourceOwnershipInventoryTests` fails — good. However the inventory has no mechanism to detect *deleted* files that remain listed (phantom entries). Phantom entries pass the test but misrepresent the actual ownership surface.  
**Fix:** Add a reverse check in `SourceOwnershipInventoryTests`: enumerate files on disk and assert every file appears in the inventory, AND every inventory entry has a corresponding file on disk.

---

### F-CORE-005 · P2 · Structure / Dedup
**File:** Multiple `*ReportValidation.swift` files across `Benchmarks/`, `Evidence/`, `Timing/`, `Release/`  
**Description:** Every report type defines its own `validate()` method with near-identical structure: check `verdict`, check required sub-report fields, check threshold values, throw typed errors. The same `guard verdict != .notRun` / `guard verdict == .pass` patterns are repeated verbatim in at least 14 `*ReportValidation.swift` files. There is no shared base validator protocol with default implementations.  
**Fix:** Extract a `ReportValidationProtocol` with default `validateVerdictNotRun()`, `validateVerdictPass()`, and `validateThreshold(value:max:error:)` helpers. Let each concrete validation type call these instead of re-implementing them.

---

### F-CORE-006 · P2 · Quality / Dead Code
**File:** `Core/DebugTrace.swift`  
**Description:** `DebugTrace` wraps `print()` behind a `debugEnabled` flag. At least 6 call sites use `DebugTrace.log(...)` in non-debug paths, including `ExternalConnectorSessionRunner` and `NativeAppShellSearchAndPacketMonitor`. In release builds these calls are not compiled out (the flag is a runtime `Bool`, not a compile-time conditional). Every packet-monitor poll and session-runner step emits a `print()` through `DebugTrace` when `debugEnabled == true`, which is the default in debug builds. This is effectively `print()` debugging that survives into release.  
**Fix:** Replace `DebugTrace` with `os_log` at appropriate subsystem/category points (`OSLog.subsystem = "com.openlola2"`). Retire `DebugTrace.swift`.

---

### F-CORE-007 · P2 · Quality
**File:** `Core/KeyValueArgumentParser.swift`  
**Description:** `KeyValueArgumentParser.parse()` silently drops any argument that fails to split on `=` (returns `nil` from `components(separatedBy:).first`). A typo like `--peer-ip192.168.1.1` (missing `=`) silently disappears with no error or warning. The CLI caller sees no indication that an argument was unrecognised.  
**Fix:** Collect unrecognised tokens and either throw `UnrecognisedArgumentError` or log a warning before continuing.

---

### F-CORE-008 · P2 · BenchmarkBug
**File:** `Benchmarks/E2E/E2EBenchmarkSyntheticSmoke.swift`  
**Description:** The E2E synthetic smoke test constructs a `E2EBenchmarkReport` with all thresholds pre-filled to pass values and `verdict: .pass` directly. `E2EBenchmarkReportValidation.validate()` is called but the report it validates was constructed to be valid by construction — the smoke test cannot detect a regression in the validator itself (e.g., if a threshold check is accidentally removed from `validate()`).  
**Fix:** Add a companion "negative smoke" that constructs a report with one field violating each threshold and asserts that `validate()` throws the expected error. This validates the validator, not just the happy path.

---

### F-CORE-009 · P2 · BenchmarkBug
**File:** `Benchmarks/Latency/LatencyBenchmarkSyntheticSmoke.swift`, `Benchmarks/Performance/PerformanceAuditSyntheticSmoke.swift`  
**Description:** Same problem as F-CORE-008 — synthetic smokes validate pre-passed reports. Neither smoke can catch a broken validator.  
**Fix:** Same: add negative smoke tests for each benchmark validator.

---

### F-CORE-010 · P2 · Quality / Dead Code
**File:** `Release/LoLaParityDeferredFeatures.swift`  
**Description:** `LoLaParityDeferredFeatures` lists 8 explicitly deferred features (e.g., multicast, RTSP, WebRTC). This is correct and useful documentation. However, 3 of the 8 deferred features have associated `// TODO:` markers in other source files with no tracking connection back to `LoLaParityDeferredFeatures`. If a deferred feature is later un-deferred, there is no mechanism to discover or close out the scattered TODO markers.  
**Fix:** Add a test in `OpenLolaCoreTests` that greps for `// TODO` markers referencing deferred feature IDs and asserts that each marker is either resolved or cross-referenced in `LoLaParityDeferredFeatures`.

---

### F-CORE-011 · P2 · Structure
**File:** `Release/OpenSourceReleaseReadiness.swift`  
**Description:** `OpenSourceReleaseReadiness.validate()` checks 8 compliance requirements but does NOT check that `Package.swift` has no external (non-Apple) dependencies added since the last review. A future PR adding a third-party Swift package dependency would pass all 8 compliance checks silently — potential license contamination.  
**Fix:** Add a ninth check: parse `Package.swift` (or import `PackageDescription`) and assert `package.dependencies.isEmpty`, surfacing any new external dependency as a compliance gate failure.

---

### F-CORE-012 · P2 · CLI / Quality
**File:** `open-lola/Commands/CLICommandHelpers.swift`  
**Description:** `CLICommandHelpers.printUsage()` outputs a large static string listing all ~80 commands. This string is not generated from the actual command tree — if a command is added, renamed, or removed, the help text must be manually updated. Currently there are 3 commands listed in `main.swift` that do not appear in the `printUsage()` output (verified by comparing `CLICommandInventory` entries against the usage block).  
**Fix:** Generate help text from `CLICommandInventory` at runtime instead of maintaining a static string. Add a test that asserts `CLICommandInventory.allCommands.map(\.name)` equals the set of command names parsed from `printUsage()` output.

---

### F-CORE-013 · P2 · Quality
**File:** `Evidence/VerdictValidationPolicy.swift`  
**Description:** `VerdictValidationPolicy.passForbids()` is called with different combinations of forbidden conditions across 14 report validators, sometimes duplicating the same set of forbidden conditions that another validator already declares. There is no central registry of "what conditions are universally forbidden for a pass verdict" — each validator independently re-lists them, creating maintenance drift risk.  
**Fix:** Define a `static let universalPassForbids: [VerdictForbidCondition]` in `VerdictValidationPolicy` and have each validator call `passForbids(universalPassForbids + localForbids)`.

---

### F-CORE-014 · P2 · Structure / Naming
**File:** `Sources/open-lola/Commands/Network/DirectP2PTwoPeerPrototypeCommandSupport.swift`  
**Description:** The word "Prototype" in the file name and type names (`DirectP2PTwoPeerPrototypeCommand`) signals an unfinished or experimental state. However, this is one of the primary operational commands in the two-peer session workflow — operators use it in production-equivalent field tests. The "Prototype" label creates confusion about whether this command is production-ready.  
**Fix:** Rename to `DirectP2PTwoPeerOperatorCommandSupport.swift` once the command has stabilised, and remove "Prototype" from all type names. Add a TODO(human) note for the renaming decision.

---

### F-CORE-015 · P2 · Quality / Dedup
**File:** `Support/Inventories/FixtureSmokeMatrixData.swift`  
**Description:** `FixtureSmokeMatrixData` contains a 200+ entry matrix of fixture-to-smoke mappings. At least 12 groups of 4–8 entries are structurally identical except for the fixture name field (same smoke set, same category, same severity). This is machine-generated data that was likely copy-pasted and manually edited. Any fixture added or changed requires updating multiple parallel entries.  
**Fix:** Factor out repeated smoke sets into named `static let` arrays and reference them from the matrix entries. Reduces the data file from ~200 to ~60 unique lines.

---

## Project-Level Blockers (not code bugs, human decisions required)

| ID | Priority | Description | Who |
|---|---|---|---|
| PROJ-01 | **P0-RELEASE** | No license selected — project cannot be open-sourced | Maintainer + legal |
| PROJ-02 | **P0-RELEASE** | `THIRD_PARTY_NOTICES.md` has draft markers | Maintainer |
| PROJ-03 | **P0-RELEASE** | `docs/compliance/final-review-packet.md` signoff pending | Reviewer |
| PROJ-04 | P1 | All 10 runtime deliverables lack physical hardware evidence | Engineer with two Macs + RME + Blackmagic |
| PROJ-05 | P1 | Developer ID certificate absent — packaging field test cannot run | Developer account holder |
| PROJ-06 | P2 | 3 architecture doc files referenced in code but not verified on disk | Engineer |

---

## Remediation Priority Order

### Phase 1 — P0 Realtime Safety (fix before any session)
1. F-AUDIO-001: Heap alloc in MADI render callback — pre-allocate scratch buffer
2. F-AUDIO-002: Dictionary mutation on RT path — slot-indexed structure
3. F-AUDIO-003/004: `Set`/`Array` alloc in IOProc capture path — cache at init

### Phase 2 — P1 Correctness (fix before field deployment)
4. F-AUDIO-016: CFString memory leak in CoreAudio inventory reader
5. F-AUDIO-012/013/014/015: Integer overflow/wrap in timing arithmetic
6. F-AUDIO-007/017: O(n) allocations on RT path in MADI receive
7. F-AUDIO-005/006: Clock syscall and heap alloc in send/pop paths
8. F-AUDIO-010/011: Buffer capacity race + error ambiguity
9. F-LOLA-001/002/003/006/008: Core LoLa interop blockers (out-of-order fragments, source port, IPv4 ID, TCP padding, IP string comparison)
10. F-PROT-001: NTSC frame rate rejection
11. F-CTRL-001: Lighting gate report always self-invalidates
12. F-NET-001: `closeUdpSocket` silent in release builds
13. F-NET-009/012: UDP transport fd leaks
14. F-NET-015: `readDataToEndOfFile` hangs after SIGTERM
15. F-UI-001/004/005: `deinit` actor isolation crashes
16. F-UI-002: Float32 audio interpreted as UInt8 — all meters broken
17. F-UI-003: Hardcoded `/tmp` paths
18. F-UI-036: `onDisappear` kills live session on sidebar navigate

### Phase 3 — P2 Code quality (cleanup sprint)
- All F-NET-0{03..08,11,13,14,16..21}
- All F-AUDIO-0{08,09,18..29}
- All F-LOLA-0{04,05,07}, F-PROT-002, F-CTRL-002
- All F-SHELL/CONN findings
- All F-UI-0{06..35} remaining
- All F-CORE-0{04..15}
- PROJ-06 (verify missing doc files)

### Phase 4 — Project completion gates (human decisions required)
- PROJ-01/02/03: License, notices, signoff (legal gate — cannot be automated)
- PROJ-04: Physical two-Mac RME MADI hardware run for all 10 runtime deliverables
- PROJ-05: Developer ID signing certificate + clean-Mac install test

---

## Todos (SQL-tracked)

*(See SQL todos table for machine-readable tracking)*
