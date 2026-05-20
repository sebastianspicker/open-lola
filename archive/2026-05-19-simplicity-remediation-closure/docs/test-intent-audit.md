# Test Intent Audit

**Repository:** open-lola2
**Audited:** `Tests/OpenLolaCoreTests/` (180 files, ~748 `@Test` annotations, ~5,203 `#expect` assertions)
**Principle:** Every test must encode WHY the behavior matters, not just WHAT output appears.
**Hard rules:** No code changes. No test changes. This document is audit-only.

---

## Scope

The suite uses Swift Testing (`@Test`, `#expect`, `#require`, `Issue.record`). Key infrastructure:

- **`SocketHeavyTestGate`** — actor-backed semaphore that serializes socket-heavy tests to prevent port conflicts. Does NOT conditionally skip tests; all socket tests always run.
- **`.enabled(if: secondaryLoopbackAliasAvailable())`** — 4 tests in `LoLaQuickConnectFallbackTests.swift` require a secondary loopback alias (`lo0:1`) and silently skip when it is absent.
- No `@Test(.disabled(...))` traits found anywhere. There are no permanently-skipped tests.

---

## Findings

### TI-01 — WEAK (version freeze)

| Field | Value |
|---|---|
| **ID** | TI-01 |
| **Test file** | `CapabilitySummaryTests.swift` |
| **Test name** | `capabilitySummaryExposesCurrentM15Surface` |
| **Production behavior supposedly protected** | `CapabilitySummary.current` returns the correct milestone-level summary for the active release. |
| **Why the current test is weak** | Asserts `summary == .m15PackagingFieldTest` and `summary.version == "0.0.0-m15"` — both are milestone-specific hardcoded values. When the milestone advances to m16 (or any later stage), this test fails as a false positive. The test name itself admits this: "M15 Surface." It is a version snapshot, not a behavioral invariant. |
| **What meaningful behavior should be tested** | That `CapabilitySummary.current` returns a value consistent with the current compile-time milestone constant; that the `stage`, `version`, and `summary` fields are mutually consistent; that the summary is not a placeholder or stale fixture. |
| **Example better test description** | `capabilitySummary_current_matchesActiveCompileTimeMilestone` — compare `current.summary` against a symbolic milestone constant rather than a hardcoded `.m15PackagingFieldTest`. |
| **Edge cases to include** | Verify `stage`, `version`, and `summary` are all in sync for the same milestone. Verify that the `.current` property is driven by the canonical milestone constant rather than a separate hardcoded value. |
| **Risk level** | Medium — test will fail on every milestone advance, causing maintenance churn with no behavioral benefit. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | No. If `CapabilitySummary.current` returned a totally different stage (e.g., `.m00Scaffold`) at m15 packaging time, this test would still pass if someone also updated the assertion. It is a snapshot, not a contract. |

---

### TI-02 — WEAK (frozen string IDs + trivial numeric bounds)

| Field | Value |
|---|---|
| **ID** | TI-02 |
| **Test file** | `SyntheticSmokeReportContractTests.swift` |
| **Test name** | `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass` |
| **Production behavior supposedly protected** | Every synthetic smoke report: (a) validates against its schema, (b) has `verdict == .partial`, (c) does not claim a runtime PASS. |
| **Why the current test is weak** | Among the 23 per-smoke assertions, many assert frozen string IDs (`report.id == "m12-apple-silicon-performance-synthetic-smoke"`) and trivial numeric bounds (`report.counters.callbackDuration.sampleCount > 0`). The frozen IDs test that a constant string equals itself; the `> 0` bounds accept any non-zero value including `1`, which would not constitute plausible synthetic performance data. Neither class of assertion would catch a regression in the smoke's logic — only a rename or an initialization failure. The high-value assertions in this test (runtime safety flags, `verdict == .partial`, `syntheticEvidenceUsedForPass == false`) are valid and meaningful. |
| **What meaningful behavior should be tested** | That synthetic smoke counters fall within a plausible range for a synthetic run (e.g., `sampleCount >= minExpectedSamples`). That ID values are programmatically derived from a shared constant, not duplicated strings. That the `runMode == .synthetic` flag is set. |
| **Example better test description** | `syntheticSmoke_callbackDurationCounterReflectsExpectedSampleCount` — assert `sampleCount >= lowerBound` where `lowerBound` is a constant derived from the smoke's declared frame count. |
| **Edge cases to include** | A counter that is exactly `1` (smoke was called but only ran one iteration) should be distinguishable from a healthy run. |
| **Risk level** | Low behavioral risk (smoke verdict and safety assertions are correct); medium regression-detection risk (counter checks are too weak to catch logic regressions). |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | Partially. The verdict and flag assertions would fail. The ID and `> 0` assertions would not fail if the smoke logic was wrong but still produced one sample. |

---

### TI-03 — WEAK (documentation completeness, not behavior)

| Field | Value |
|---|---|
| **ID** | TI-03 |
| **Test file** | `MultichannelTransportTests.swift` |
| **Test name** | `audioRoutingAssumptionLedgerClassifiesEveryFixedStereoAssumption` |
| **Production behavior supposedly protected** | `AudioRoutingAssumptionLedger` is complete and all entries are classified. |
| **Why the current test is weak** | Asserts the ledger is non-empty, has no unclassified entries, and contains a specific set of 11 IDs. This validates documentation completeness — that someone filled in the ledger correctly. It does not test routing decisions, channel mapping, or what happens when a stereo assumption is violated in the actual audio graph. If every assumption were wrong but correctly classified, the test passes. |
| **What meaningful behavior should be tested** | Whether the routing behavior described by each assumption is actually enforced. For example: if a stereo assumption declares that a source must have exactly 2 channels, does the router reject a 1-channel or 3-channel source? |
| **Example better test description** | `audioGraph_rejectsChannelCountViolatingStereoPairingAssumption` — feed a source with a channel count inconsistent with a documented assumption and expect rejection. |
| **Edge cases to include** | Single-channel source when stereo pair assumed. Channel count of zero. Channel order mismatch. |
| **Risk level** | Low — the ledger test is harmless, but it provides false assurance about routing correctness. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | No. If the audio router silently accepted incorrect channel configurations, this test would still pass as long as the ledger documentation remained complete. |

---

### TI-04 — WEAK (smoke proves no crash, not correctness)

| Field | Value |
|---|---|
| **ID** | TI-04 |
| **Test file** | `UdpPcmPacketTests.swift` |
| **Test name** | `udpPcmLocalhostSmokeRoundTripsPacket` |
| **Production behavior supposedly protected** | The UDP PCM localhost smoke round-trips a packet across a real socket. |
| **Why the current test is weak** | Calls `UdpPcmLocalhostSmoke.run()`, asserts `sequenceNumber == 1` and `senderHostTimeNanoseconds > 1`. This proves the smoke ran without crashing and returned a plausible non-zero timestamp. It does not verify: (a) that the payload bytes are byte-for-byte identical on the receive side, (b) that the sequence number increments correctly across multiple packets, (c) that the round-trip latency falls within any meaningful bound, (d) that a corrupt or dropped packet causes the expected error path. The `sequenceNumber == 1` assertion is the first packet — testing wrap-around behavior at `UInt64.max &+ 1` is absent. |
| **What meaningful behavior should be tested** | Payload equality (byte-level) after socket round-trip. Sequence number tracking for multi-packet runs. Failure behavior when the socket is deliberately closed mid-run. |
| **Example better test description** | `udpPcmSmoke_receivedPayloadBytesMatchTransmittedPayload` — after smoke, assert the received packet's decoded audio bytes match the transmitted test vector. |
| **Edge cases to include** | Multi-packet sequence (at least 3), sequence tracker wrap-around, port-already-in-use error. |
| **Risk level** | Medium — the smoke confirms the happy path launches, but payload correctness is not guarded. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | Not for payload corruption. Would fail only if the smoke crashed or returned a zero timestamp. |

---

### TI-05 — WEAK (frozen prefix list without behavioral explanation)

| Field | Value |
|---|---|
| **ID** | TI-05 |
| **Test file** | `VerdictValidationPolicyTests.swift` |
| **Test name** | `verdictValidationPolicyCentralizesUniversalPassForbidPrefixes` |
| **Production behavior supposedly protected** | `VerdictValidationPolicy` centralizes all error case name prefixes that unconditionally block a PASS verdict. |
| **Why the current test is weak** | Asserts the exact ordered list of 6 string prefixes: `["passWith", "passAllows", "passUses", "passIncreases", "passChanges", "passBlocks"]`. This is a snapshot of internal implementation state. If the order changes without a behavioral change, the test fails. More importantly, the test does not explain WHY these prefixes matter (they are the naming convention for error cases that reject PASS verdicts). A test that asserts the list but doesn't verify that each prefix actually causes a PASS rejection provides incomplete coverage. |
| **What meaningful behavior should be tested** | That for each prefix, an error case with that prefix actually causes `validate()` to reject a PASS verdict on a real report. The behavioral invariant is: "any error whose name starts with these prefixes must block PASS." |
| **Example better test description** | `verdictValidationPolicy_passForbidPrefixCausesPassRejectionOnRealReport` — for each prefix, construct a concrete report where the corresponding error fires and assert that `validate()` throws the expected error. |
| **Edge cases to include** | A new prefix not in the list should not silently pass. An error case name without a recognized prefix should not block PASS (to ensure no false negatives). |
| **Risk level** | Low if combined with existing `rejectInvalidReportEvidence` mutation tests; medium standalone because the prefix list is asserted but not exercised end-to-end. |
| **Confidence** | Medium |
| **Would this test fail if behavior changed incorrectly?** | Only if the exact list changes. If a bug caused a `passWith*` error to NOT block PASS, this test would still pass. |

---

### TI-06 — STRUCTURAL (LOC metric, not behavior)

| Field | Value |
|---|---|
| **ID** | TI-06 |
| **Test file** | `CodeLineBudgetTests.swift` |
| **Test name** | All tests in this file |
| **Production behavior supposedly protected** | Source files stay within declared line-count budgets; discipline around file size is enforced. |
| **Why the current test is weak** | Enforces a proxy metric (lines of code) not behavioral intent. A file at exactly the budget limit containing only comments, dead code, or repeated boilerplate would pass. A file one line over budget that implements a critical correctness fix would fail. No test asserts any behavioral property. |
| **What meaningful behavior should be tested** | N/A — LOC budgets are an architectural discipline tool, not a behavioral contract. The budget enforcement has value for preventing scope creep, but it should be categorized as a process test, not a behavioral test. |
| **Example better test description** | Not applicable — if retained, these tests should be documented as process/hygiene tests with a comment explaining they protect structural conventions, not runtime behavior. |
| **Edge cases to include** | What happens when a budget is exceeded by a legitimate refactor? Is there an override mechanism? The current test provides no exception path. |
| **Risk level** | Low for correctness; medium for team friction (this test will block legitimate changes that happen to exceed a budget). |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | No. If a core audio callback began allocating memory (a critical safety violation), these tests would be unaffected. |

---

### TI-07 — WEAK (PRNG-fragile golden floats)

| Field | Value |
|---|---|
| **ID** | TI-07 |
| **Test file** | `RxBufferingTests.swift` |
| **Test name** | `rxBufferImpairmentSimulatorIsDeterministicAcrossRuns` |
| **Production behavior supposedly protected** | `RxBufferImpairmentSimulator` produces deterministic output for the same seed. |
| **Why the current test is weak** | Asserts against 9-decimal-place golden float values (e.g., `abs(packetAges[0] - 145.0083667750024) < 0.000_000_001`). These values are correct for the current Swift `SystemRandomNumberGenerator` seed, but may change if the PRNG algorithm changes (e.g., on a new Swift version or platform). More critically, the test does not explain what `145.0083...` ns represents — is this within an acceptable jitter budget? Is it realistic for the transport? The assertion validates the math reproduced, not whether the result is meaningful for the simulation's purpose. |
| **What meaningful behavior should be tested** | That with a fixed seed, the simulator produces the same packet age sequence across runs (determinism invariant). That the range of simulated ages falls within a domain-meaningful interval (e.g., typical one-way delay for a campus LAN path). |
| **Example better test description** | `rxBufferImpairmentSimulator_deterministicAcrossMultipleRunsWithSameSeed` — run twice with the same seed, compare outputs for equality rather than comparing to stored golden values. Separately, assert `packetAges.allSatisfy { $0 >= 0 && $0 < maxExpectedOneWayDelayNs }`. |
| **Edge cases to include** | Seed of `0`. Seed of `UInt64.max`. Varying packet count to verify the sequence extends deterministically. |
| **Risk level** | Medium — if golden values change due to runtime/compiler update, tests fail without any real regression. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | Yes, if the numeric outputs change — but for the wrong reason (compiler/PRNG change, not logic regression). |

---

### TI-08 — WEAK (tests markdown prose, not runtime behavior)

| Field | Value |
|---|---|
| **ID** | TI-08 |
| **Test file** | `SourceNamingConventionTests.swift` |
| **Test name** | `cleanRoomNamingPolicyAndTwoPeerPrototypeSurfaceStayDocumented` |
| **Production behavior supposedly protected** | Naming convention documentation stays current; CLI commands for two-peer prototype remain registered. |
| **Why the current test is weak** | Contains two mixed concerns: (1) `#expect(namingDoc.contains("*Helpers"))` — tests that a markdown file contains specific prose fragments. If someone reformats the doc without changing the policy, the test fails. (2) `#expect(commandNames.contains("direct-p2p-two-peer-prototype-report"))` — tests that CLI command names exist. The second half is a valid behavioral test; the first half is fragile prose matching. Mixing documentation linting with behavioral verification in a single test obscures intent. |
| **What meaningful behavior should be tested** | The CLI command presence assertions are meaningful and should be in a separate focused test (or alongside `CLICommandInventoryTests`). The documentation prose matching should be dropped or converted to a documentation lint check outside the test suite. |
| **Example better test description** | Split into: (a) `twoPeerPrototypeCommandsAreRegisteredInCLIRouter` — tests command presence only. (b) A documentation CI lint step (not a Swift test) for prose compliance. |
| **Edge cases to include** | What if a command is present in `CLICommandInventory` but not routed in `main.swift`? (This is already tested in `CLICommandInventoryTests`.) |
| **Risk level** | Low for correctness; medium for maintenance friction due to prose-matching fragility. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | The command presence assertions would. The markdown assertions would only fail if the doc is reformatted, not if the policy is violated at runtime. |

---

### TI-09 — MISSING (router success path and channel mapping)

| Field | Value |
|---|---|
| **ID** | TI-09 |
| **Test file** | `DirectAudioMediaRouterTests.swift` |
| **Test name** | *(only test present: `directAudioMediaRouterRejectsPacketsForUnconfiguredStreams`)* |
| **Production behavior supposedly protected** | `DirectAudioMediaRouter` routes incoming audio packets to the correct registered output buffer with correct channel mapping. |
| **Why the current test is weak / missing** | The only test verifies the rejection path: an unconfigured stream is rejected. There is no test for: (a) a successfully-configured stream receiving a correctly-routed packet, (b) channel remapping — that a multi-channel payload arrives at the correct buffer offset, (c) routing with multiple concurrent streams — that stream 1's packet does not corrupt stream 2's buffer, (d) what happens when the destination buffer is full. The happy path and channel-map correctness — which are the primary behavioral contracts of a router — are completely untested. |
| **What meaningful behavior should be tested** | Correct routing: packet for stream `A` arrives at `A`'s output buffer, not `B`'s. Channel offset math: a 4-channel fragment with `channelOffset == 2` writes to positions 2–5 in the destination. Concurrent stream isolation. Buffer-full behavior. |
| **Example better test description** | `directAudioMediaRouter_routesPacketToRegisteredStreamAtCorrectChannelOffset` |
| **Edge cases to include** | Zero-length payload. Channel offset beyond destination buffer. Two streams with overlapping channel ranges. |
| **Risk level** | High — a routing bug in this layer would cause silent audio corruption or data loss with no test catching it. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | No. A routing bug that silently sends stream A's packets to stream B would not be caught by any current test. |

---

### TI-10 — MISSING (packet continuity across reconnection)

| Field | Value |
|---|---|
| **ID** | TI-10 |
| **Test file** | `ReconnectionTests.swift` |
| **Test name** | `reconnectAfterMediaSocketFailurePreservesAcceptedSessionConfiguration` |
| **Production behavior supposedly protected** | After a media socket failure and reconnection, the session configuration is preserved and media resumes correctly. |
| **Why the current test is weak** | Tests that `acceptedConfiguration` is preserved after a state transition. Does not test: (a) that media packets received before the failure are distinguishable from packets received after recovery, (b) that the RX buffer is correctly flushed or continued across reconnection, (c) that sequence numbers are reset or continued correctly on reconnect, (d) that a partial reconnect does not leave stale state in the handoff layer. The test name implies a configuration-preservation contract but the session's core job (continuous audio delivery) is not verified. |
| **What meaningful behavior should be tested** | That sequence number tracking resets correctly on reconnect. That packets buffered before the disconnect do not corrupt the post-reconnect stream. That the handoff metrics accurately reflect the disruption (dropped blocks, reset counter). |
| **Example better test description** | `reconnect_sequenceCounterResetsAndBufferFlushedAfterMediaSocketFailure` |
| **Edge cases to include** | Reconnect during active audio delivery. Multiple consecutive reconnects. Reconnect when RX buffer is empty vs. near-full. |
| **Risk level** | High — incorrect reconnection behavior causes real-world audio glitches and state corruption. |
| **Confidence** | Medium (would need to trace through `PeerSessionRunner` and handoff layer to confirm what is and is not tested). |
| **Would this test fail if behavior changed incorrectly?** | Partially — it would fail if `acceptedConfiguration` were wiped on reconnect. It would not fail if sequence tracking or buffer state were incorrect after reconnect. |

---

### TI-11 — CONDITIONAL (silently absent in most environments)

| Field | Value |
|---|---|
| **ID** | TI-11 |
| **Test file** | `LoLaQuickConnectFallbackTests.swift` |
| **Test name** | `lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut` (and 3 others) |
| **Production behavior supposedly protected** | LoLa UDP transmit falls back to QuickConnect when a status ACK times out; fallback uses the correct message sequence; the loopback alias availability check fails explicitly when the alias is absent. |
| **Why the current test is weak** | Uses `.enabled(if: secondaryLoopbackAliasAvailable())` — the 4 substantive tests silently skip in environments without a secondary loopback alias (`lo0:1`). In a clean CI environment, only `lolaFallbackLoopbackAliasRequirementFailsExplicitlyWhenUnavailable` (which tests the absence check itself) runs. The core fallback protocol behavior — the QuickConnect message exchange — is never verified in CI. The single test that does run is a pure rejection path; the protocol path is invisible. |
| **What meaningful behavior should be tested** | That the QuickConnect fallback message sequence is correct (sent messages, received ACK) — at minimum via a stub peer that does not require a real secondary loopback interface. |
| **Example better test description** | `lolaQuickConnectFallback_messageSequenceIsCorrectWithoutRealInterface` — drive the fallback logic using an injected transport stub (no real socket required) to test the protocol state machine unconditionally. |
| **Edge cases to include** | No ACK received (timeout). Wrong ACK content. Repeated retries. |
| **Risk level** | High — QuickConnect fallback is a user-facing recovery path. If it breaks, users cannot establish sessions, and CI will never catch it. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | No — the 4 substantive tests do not run in CI. The only test that runs verifies absence detection, not the fallback behavior itself. |

---

### TI-12 — MISSING (no concurrent access test for production usage pattern)

| Field | Value |
|---|---|
| **ID** | TI-12 |
| **Test file** | `RealtimeAudioPacketHandoffTests.swift` |
| **Test name** | *(no concurrent test exists)* |
| **Production behavior supposedly protected** | `RealtimeAudioPacketHandoff` is used concurrently: `receive()` is called from the network thread; `dequeue()` is called from the Core Audio render callback. The structure must be safe under this concurrent access pattern. |
| **Why the current test is weak / missing** | All tests invoke `receive()` and `dequeue()` sequentially on a single thread. The overflow and playout tests use `UInt64.max` boundary values but no concurrent calls. The production usage pattern (network thread writing, audio callback thread reading) is never exercised in any test. |
| **What meaningful behavior should be tested** | Concurrent `receive()` + `dequeue()` on separate threads without data corruption. That the `droppedNetworkBlocks` and `metrics` fields remain consistent under concurrent access. That the ring buffer's `ownerViolationCount` stays zero under concurrent usage. |
| **Example better test description** | `realtimeAudioPacketHandoff_concurrentReceiveAndDequeueProcducesNoLostOrCorruptedBlocks` |
| **Edge cases to include** | Concurrent receive when ring is full. Concurrent dequeue when ring is empty. Rapid interleaving at 1ms intervals (mimicking 48kHz audio callback). |
| **Risk level** | High — silent data corruption or crashes in the audio render callback have no user-visible error path. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | No — sequential tests cannot catch concurrent safety regressions. |

---

### TI-13 — MISSING (sequence number wrap-around not tested)

| Field | Value |
|---|---|
| **ID** | TI-13 |
| **Test file** | `UdpPcmPacketTests.swift` |
| **Test name** | `udpPcmSequenceTrackerRejectsSkippedSequence` |
| **Production behavior supposedly protected** | `UdpPcmSequenceTracker` correctly tracks packet sequence numbers, including wrap-around. |
| **Why the current test is weak** | Only tests that a sequence gap (skip by 1 or more) causes a rejection. The production implementation uses `packet.header.sequenceNumber &+ 1` for `nextSequenceNumber` — a wrapping addition. There is no test for what happens when `sequenceNumber == UInt64.max` and the next packet arrives with `sequenceNumber == 0`. If the tracker uses non-wrapping arithmetic in the comparison branch, `UInt64.max + 1` would overflow and either panic (debug) or silently produce wrong behavior (release). |
| **What meaningful behavior should be tested** | That a packet with `sequenceNumber == 0` is accepted after a packet with `sequenceNumber == UInt64.max`. |
| **Example better test description** | `udpPcmSequenceTracker_acceptsWrapAroundFromMaxToZero` |
| **Edge cases to include** | `UInt64.max` → `0` wrap. `0` → `1` (first packet after reset). |
| **Risk level** | Medium — UDP PCM v1 uses `UInt64` so wrap-around is theoretically many hours of continuous operation, but it is a correctness gap. |
| **Confidence** | High |
| **Would this test fail if behavior changed incorrectly?** | No — the test does not cover the wrap-around case. |

---

### TI-14 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-14 |
| **Test file** | `SPSCAtomicRingTests.swift`, `DirectPeerAudioPayloadRingTests.swift` |
| **Test names** | `spscAtomicRingIsSafeUnderConcurrentProducerConsumer`, `directPeerAudioPayloadRingIsSafeUnderConcurrentProducerConsumer` |
| **Why these are strong** | Use real `DispatchQueue` concurrency with a 5-second timeout and 10,000-value verification sequence. `DirectPeerAudioPayloadRingTests` additionally verifies `ownerViolationCount == 0` under concurrent access. These tests would fail under a real threading regression. The concurrent test complements the single-threaded order/bounds tests in the same files. |
| **Recommendation** | PRESERVE. Do not weaken or convert to sequential. |

---

### TI-15 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-15 |
| **Test file** | `RealtimeAudioEngineTests.swift` |
| **Test name** | `realtimeAudioEngineRejectsInvalidReportEvidence` |
| **Why this is strong** | Contains 20+ explicit typed-error mutations on a pass-candidate report. Each mutation sets one field to an invalid state and asserts a specific typed error. Includes `safety.noAllocationInCallback = false` → `passWithCallbackSafetyViolation("noAllocationInCallback")`. This test would fail if any validation rule was silently removed or the wrong error type was raised. It is one of the most thorough behavioral tests in the suite. |
| **Recommendation** | PRESERVE. This is the reference pattern for report validation tests. |

---

### TI-16 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-16 |
| **Test file** | `UdpPcmPacketTests.swift` |
| **Test names** | `udpPcmPacketRoundTripsAgainstHexFixture`, `udpPcmPacketRejectsMalformedWireData` |
| **Why these are strong** | Byte-for-byte encode/decode against a stored hex fixture (wire-format regression). Comprehensive malformed input rejection: invalid magic, unsupported version, truncated packet at every prefix length 0..`headerByteCount`, oversized packet, invalid sample rate, channel count, sample format, wrong guard, payload length mismatch. Any regression in wire encoding or malformed input handling would be caught. |
| **Recommendation** | PRESERVE. The hex-fixture approach is the correct pattern for protocol contract tests. |

---

### TI-17 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-17 |
| **Test file** | `RxBufferingTests.swift` |
| **Test names** | `rxBufferAdaptiveControllerHysteresisStepsIncrementAndDecrementCorrectly`, `rxBufferPolicyValidationRejectsOutOfRangePrimitives` |
| **Why these are strong** | Hysteresis tests verify the controller's step-by-step target-frame adjustment against 9 specific samples in sequence — any regression in the adaptive algorithm would be caught. Policy validation tests verify typed errors for every policy primitive boundary. The `rxBufferBenchmarkRunnerRejectsFalsePassConditions` test ensures that a benchmark that claims PASS without measured evidence is rejected. |
| **Recommendation** | PRESERVE. Minor weakness: golden float assertions in the impairment simulator test (TI-07) should eventually be replaced with determinism-by-equality assertions. |

---

### TI-18 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-18 |
| **Test file** | `SyntheticSmokeReportContractTests.swift` |
| **Test name** | `syntheticSmokeReportsRejectFalsePassMutations` |
| **Why this is strong** | Iterates all 23 smoke reports, mutates `verdict = .pass` on each, and asserts that `validate()` throws `syntheticEvidenceUsedForPass`. This test is critical: it is the sole guard preventing a synthetic smoke from being accidentally promoted to a runtime PASS verdict. Would fail immediately if this validation rule were removed. |
| **Recommendation** | PRESERVE. This is the highest-value test for the product's data integrity contract. |

---

### TI-19 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-19 |
| **Test file** | `CLICommandInventoryTests.swift` |
| **Test names** | `commandInventoryCommandsAreBackedByExecutableRouterSource`, `commandInventoryCLIBinaryOutputsCommandListAndProducesExpectedExitCode` |
| **Why these are strong** | The first test scrapes the actual `main.swift` source with a regex to verify every inventoried command is present in the router. The second actually invokes the compiled CLI binary and checks the exit code and output format. Together these tests catch command-registration drift (inventory claims a command exists but router doesn't handle it) and build-level regressions (binary doesn't start). |
| **Recommendation** | PRESERVE. The source-scraping approach is brittle in general, but appropriate here because the router is a flat switch/if-chain with a clear pattern. |

---

### TI-20 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-20 |
| **Test file** | `DirectPeerRealtimeAudioGraphTests.swift` |
| **Test names** | `directPeerRealtimeAudioGraphCapturesAndOutputsBlocksUnderConcurrentAccess`, `directPeerRealtimeAudioGraphRejectsZeroChannelCapture`, `directPeerRealtimeAudioGraphRejectsZeroChannelOutput`, JSON migration tests |
| **Why these are strong** | The concurrent access test uses a real `DispatchQueue` with 32 iterations and verifies payload equality. Zero-channel rejection tests would fail if the guard were removed. JSON migration tests verify that old-format configs are correctly upgraded rather than silently failing. |
| **Recommendation** | PRESERVE. One gap: there is no test for the scenario where capture succeeds but output fails to configure (partial initialization). |

---

### TI-21 — PRESERVE

| Field | Value |
|---|---|
| **ID** | TI-21 |
| **Test file** | `LoLaCompatibilityMediaEnvelopeValidationTests.swift`, `LoLaCompatibilityControlSocketTests.swift` |
| **Test names** | `lolaMediaReceiveAcceptsEphemeralSourcePortWhenDestinationPortMatches`, `lolaMediaReceiveRejectsUnexpectedMediaPort`, `lolaTransmitBindsConfiguredControlPortForRemotePeers`, `lolaTransmitUsesEphemeralSourceForSameHostLoopbackTests` |
| **Why these are strong** | The envelope tests use real encoded frames and verify port acceptance/rejection at the protocol level. The control socket tests use real OS ephemeral port allocation to verify bind behavior for remote peers vs. loopback peers vs. same-host peers — three meaningfully different cases. These tests protect the LoLa protocol compatibility surface. |
| **Recommendation** | PRESERVE. The real-socket tests rely on port availability; if flakiness appears due to port conflicts, `SocketHeavyTestGate` serialization should be extended to cover these tests. |

---

## Summary

### 1. High-Risk Missing Tests

| Priority | Missing test | Risk |
|---|---|---|
| 1 | **TI-09**: `DirectAudioMediaRouter` routing success and channel mapping | Audio data silently routed incorrectly with no detection |
| 2 | **TI-12**: Concurrent `RealtimeAudioPacketHandoff.receive()` + `dequeue()` | Race condition or data corruption in the audio render callback |
| 3 | **TI-11**: `LoLaQuickConnectFallbackTests` (4 tests) run in CI | QuickConnect fallback regression invisible in CI |
| 4 | **TI-10**: Packet continuity (sequence, buffer state) across reconnection | Reconnect causes silent stream corruption or stale sequence tracking |
| 5 | **TI-13**: `UdpPcmSequenceTracker` wrap-around at `UInt64.max` → `0` | Arithmetic overflow after very long sessions |

### 2. Weak Tests to Rewrite

| ID | Test | Problem | Action |
|---|---|---|---|
| TI-01 | `capabilitySummaryExposesCurrentM15Surface` | Version snapshot breaks on every milestone advance | Replace hardcoded milestone constants with symbolic comparison |
| TI-02 | `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass` | `sampleCount > 0` too weak; frozen ID strings | Assert plausible min count; derive IDs from shared constants |
| TI-03 | `audioRoutingAssumptionLedgerClassifiesEveryFixedStereoAssumption` | Tests documentation, not routing behavior | Keep as a documentation completeness gate; add a separate routing behavior test |
| TI-04 | `udpPcmLocalhostSmokeRoundTripsPacket` | Proves no crash, not payload correctness | Add payload byte equality assertion and multi-packet sequence tracking |
| TI-05 | `verdictValidationPolicyCentralizesUniversalPassForbidPrefixes` | Frozen prefix list asserted but not exercised end-to-end | Add one test per prefix that exercises the end-to-end PASS rejection |
| TI-07 | `rxBufferImpairmentSimulatorIsDeterministicAcrossRuns` | PRNG-fragile 9-decimal golden values | Replace with run-twice-and-compare-for-equality determinism test |
| TI-08 | `cleanRoomNamingPolicyAndTwoPeerPrototypeSurfaceStayDocumented` | Prose matching for documentation; mixed concerns | Extract command-presence assertions into a dedicated test; drop prose matching |

### 3. Tests That Are Valuable and Should Be Preserved

| ID | Test file / name | Why |
|---|---|---|
| TI-14 | `SPSCAtomicRingTests`, `DirectPeerAudioPayloadRingTests` — concurrent tests | Only guard against real threading regressions in ring buffers |
| TI-15 | `realtimeAudioEngineRejectsInvalidReportEvidence` | 20+ typed-error mutations; highest-value validation test in the suite |
| TI-16 | `udpPcmPacketRoundTripsAgainstHexFixture`, malformed rejection tests | Wire-format regression guard; malformed input coverage |
| TI-17 | `rxBufferAdaptiveControllerHysteresisStepsIncrementAndDecrementCorrectly` | Step-by-step adaptive controller regression |
| TI-18 | `syntheticSmokeReportsRejectFalsePassMutations` | Sole guard against synthetic smoke being promoted to runtime PASS |
| TI-19 | `CLICommandInventoryTests` | Source-scraping + binary invocation; catches command-registration drift |
| TI-20 | `DirectPeerRealtimeAudioGraphTests` — concurrent, zero-channel, migration tests | Graph-level concurrent access + boundary rejection |
| TI-21 | `LoLaCompatibilityMediaEnvelopeValidationTests`, `LoLaCompatibilityControlSocketTests` | Real-frame and real-socket LoLa protocol tests |

### 4. Suggested Regression-Test Backlog

In priority order:

1. `DirectAudioMediaRouter` — routing success, channel-offset math, multi-stream isolation (TI-09)
2. `RealtimeAudioPacketHandoff` — concurrent `receive` + `dequeue` with payload equality verification (TI-12)
3. `LoLaQuickConnectFallback` — unconditional transport-stub test for QuickConnect message sequence (TI-11)
4. `ReconnectionTests` — sequence number reset and buffer flush after media socket failure (TI-10)
5. `UdpPcmSequenceTracker` — wrap-around from `UInt64.max` to `0` (TI-13)
6. `RxBufferImpairmentSimulator` — replace golden floats with determinism-by-equality test (TI-07)
7. `CapabilitySummaryTests` — replace milestone-specific snapshot with symbolic milestone comparison (TI-01)
8. `udpPcmLocalhostSmokeRoundTripsPacket` — add payload byte equality check (TI-04)
9. `VerdictValidationPolicy` — one end-to-end PASS rejection test per prefix (TI-05)

### 5. Verification Commands

```bash
# Run the full test suite
swift test --no-parallel

# Run a specific test file
swift test --filter udpPcmSequenceTrackerRejectsSkippedSequence

# Run socket-heavy tests (serialized via SocketHeavyTestGate)
swift test --filter lolaTransmitBindsConfiguredControlPortForRemotePeers

# Run conditional loopback tests (requires lo0:1 alias)
sudo ifconfig lo0 alias 127.0.0.2 up
swift test --filter lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut

# Run ring buffer concurrent tests
swift test --filter spscAtomicRingIsSafeUnderConcurrentProducerConsumer
swift test --filter directPeerAudioPayloadRingIsSafeUnderConcurrentProducerConsumer

# Verify CLI binary tests (requires a built binary)
swift build --product open-lola
swift test --filter commandInventoryCLIBinaryOutputsCommandListAndProducesExpectedExitCode
```

### 6. Remaining Uncertainty

1. **LoLaQuickConnectFallback conditional behavior** — it is unclear whether the loopback alias (`lo0:1`) is configured in any CI environment. If not, the 4 substantive QuickConnect tests have never run in automated CI. Needs environment confirmation.

2. **`DirectAudioMediaRouter` channel mapping** — the production channel mapping math has not been traced in full. The gap identified (TI-09) is based on test-file inspection alone. If channel mapping is exercised transitively through higher-level integration tests (e.g., `PeerSessionAVSupportTests`), the risk is lower.

3. **`RealtimeAudioPacketHandoff` thread safety** — the production types used in the handoff (`RealtimeAudioDueBlockPlayout`, the payload ring) use value semantics or atomic primitives. Whether these are sufficient without a lock under the real callback pattern needs a threading model review, not just a test review.

4. **`SocketHeavyTestGate` timeout behavior** — the gate serializes tests but does not enforce a per-test timeout beyond the gate's internal `DispatchSemaphore` wait. If a socket test hangs indefinitely, the gate will block all subsequent serialized tests. No test verifies the gate's own timeout/failure behavior.

5. **`UdpPcmV2Packet` malformed rejection coverage** — `UdpPcmV2PacketTests.swift` was inspected and shows coverage for truncated packets, invalid header guard, payload length mismatch, and arithmetic overflow in fragment planning. Coverage appears comparable to the v1 tests. No finding raised for v2.

6. **App UI state tests** — `AppShellBehaviorTests.swift` and `AppShellSlice05Tests.swift` test execution controller phase transitions and validation readiness. These tests were not fully audited in this pass. They appear to test concrete behavioral paths (`controller.phase == .failedToStart`, `controller.status == "Run failed to start."`), but the "no fake status text" requirement from the project rules was not exhaustively verified against all UI state tests.
