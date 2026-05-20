# Refactor and Code-Quality Plan

**Inputs**: AGENTS.md, docs/code-index.md, docs/verification-baseline.md,
docs/architecture-map.md, docs/deprecation-and-simplification-audit.md,
docs/logic-and-correctness-audit.md

**Constraint**: Production code is not changed by this planning document.

---

## Reading guide

Slices are grouped into seven phases and ordered by the following principles:

1. Fix verification infrastructure first (restore the green test suite).
2. Fix silent wrong behavior before style.
3. Fix high-risk runtime paths before cosmetic cleanup.
4. Remove dead code only when usage evidence is confirmed.
5. Simplify before abstracting.
6. Touch only files required by the task.
7. Many small PRs rather than one large cleanup.

Each slice is independently reviewable. Dependencies between slices are called
out in the ordering rationale.

**Verification baseline**: Before starting any slice, confirm
`swift test --no-parallel` reports exactly the 10 pre-existing issues documented
in `docs/verification-baseline.md`. If the count differs, stop and investigate.

---

## Phase 1 — Green-test restoration

These three slices fix failing tests that represent real correctness issues or
broken safety nets. They must be done first because later slices assume the
test suite is a trustworthy signal.

---

### RP-01: Fix stale test substring in synthetic smoke contract test

**ID**: RP-01
**Phase**: 1 — Green-test restoration
**Risk**: Low

**Problem**

`SyntheticSmokeReportContractTests.swift:76` asserts:
```swift
report.assumptions.contains { $0.contains("Swift-native UDP DEFAULT, JAMLINK, and EMPTY-header audio packetization") }
```
The production string in `ExternalConnectorReport.swift:315` is:
```
"JackTrip connector uses Swift-native UDP DEFAULT, JAMLINK, EMPTY-header, WebRTC data-channel, ..."
```
The substring `"JAMLINK, and EMPTY-header audio packetization"` does not appear in the current
production string. The test has been permanently red since the production string was changed.

**Findings addressed**: LC-007

**Files affected**
- `Tests/OpenLolaCoreTests/SyntheticSmokeReportContractTests.swift` (line 76 only)

**Behavior affected**: Test result only. No runtime behavior changes.

**Public contracts affected**: None.

**Storage/migration impact**: None.

**Tests to add or update**
- Update the existing `contains` substring to a value that is actually present in the current
  production assumption string, e.g. `"Swift-native UDP DEFAULT, JAMLINK, EMPTY-header"`.
- Do not weaken the assertion to a trivially-matching string such as `"JackTrip"`.

**Verification commands**
```bash
swift test --filter syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass
swift test --no-parallel   # confirm overall count improves by 1
```

**Rollback strategy**: Revert the one-line change to the test file.

**Ordering rationale**: Fastest win; restores one green test. No production risk.

**Definition of Done**
- `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass` passes.
- No other test is newly broken.

---

### RP-02: Fix UltraGrid `--peer` argument position in launch plan

**ID**: RP-02
**Phase**: 1 — Green-test restoration
**Risk**: Medium

**Problem**

`UltraGridLaunchPlan.swift` inserts `--peer <IP>` before `--topology`,
`--fec`, `--encryption`, and `--control` flags. The test in
`ExternalConnectorAvMatrixTests.swift:78` expects `arguments.last == "198.51.100.10"`
but gets `"disabled"` (the control mode value). If `uv native-mvtp` treats the peer
address as a trailing positional argument, the current order produces a malformed command.

**Findings addressed**: LC-002 / LC-011

**Files affected**
- `Sources/OpenLolaCore/Connectors/UltraGrid/UltraGridLaunchPlan.swift`
  (move the `--peer` block to after all other flags)

**Behavior affected**: The final UltraGrid launch command changes argument order.
The `--peer` flag (a key-value argument, not a bare positional) moves to the end.
Sessions with an empty peer string are unaffected (`--peer` block is conditionally added).

**Public contracts affected**: `ExternalConnectorLaunchPlan.arguments` field ordering is not
a documented public contract. The CLI command names and flags do not change.

**Storage/migration impact**: None. Saved launch plans are not serialized with argument arrays.

**Tests to add or update**
- The existing failing test `ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules`
  verifies `rx.arguments.last == "198.51.100.10"` — this test must pass after the fix.
- Check that TX-only and RX-only argument arrays both have peer as the last element when
  a peer is configured.

**Verification commands**
```bash
swift test --filter ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules
swift test --no-parallel
```

**Rollback strategy**: Revert the block reorder in `UltraGridLaunchPlan.swift`.

**Ordering rationale**: Confirmed failing test; confirms a real argument-order correctness
issue. No production `uv` binary in this checkout, but fix is required before any
UltraGrid TX integration test can be trusted.

**Definition of Done**
- `ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules` passes.
- No other UltraGrid tests regress.

---

### RP-03: Register missing fixture matrix entries

**ID**: RP-03
**Phase**: 1 — Green-test restoration
**Risk**: Low

**Problem**

`fixtureSmokeMatrixMatchesFixtureTree` fails because two fixture directories
(`JackTripCompatibilityMediaReports` and `UltraGridCompatibilityMediaReports`) exist in the
fixture tree but have no corresponding entries in `FixtureSmokeMatrixData.swift`. New fixtures
added to these directories are silently skipped by the smoke matrix.

**Findings addressed**: LC-012

**Files affected**
- `Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`

**Behavior affected**: Fixture smoke tests will begin exercising the two previously
unregistered directories.

**Public contracts affected**: None.

**Storage/migration impact**: None.

**Tests to add or update**
- The existing `fixtureSmokeMatrixMatchesFixtureTree` test must pass after adding the entries.
- Run all fixture smoke tests to confirm the new entries do not produce unexpected failures.

**Verification commands**
```bash
swift test --filter fixtureSmokeMatrixMatchesFixtureTree
swift test --no-parallel
```

**Rollback strategy**: Remove the two added entries from `FixtureSmokeMatrixData.swift`.

**Ordering rationale**: Low-risk; completes the green-test restoration before moving to
behavior fixes.

**Definition of Done**
- `fixtureSmokeMatrixMatchesFixtureTree` passes.
- All fixture smoke tests that run against the newly registered directories pass or
  are documented as expected partial results.

---

## Phase 2 — Confirmed silent wrong behavior

These slices fix code that produces incorrect results without crashing. All are confirmed
by static analysis with high confidence. RP-04 and RP-05 are the highest-value fixes
because they affect report quality and validation correctness.

---

### RP-04: Fix `audioPayloadsDroppedBeforePlayout` metric double-count

**ID**: RP-04
**Phase**: 2 — Confirmed silent wrong behavior
**Risk**: Low

**Problem**

In `DirectPeerSessionAVSocketRunner.swift` (~line 421), `audioRX.droppedByPlayoutQueue` is
accumulated into both `metrics.audioPayloadsDroppedBeforePlayout` and
`metrics.audioPayloadsDroppedByPlayoutQueue`. The aggregate "dropped before playout" counter
is therefore inflated by exactly `droppedByPlayoutQueue` per drain iteration. Exported
session reports and any derived quality decisions that read this counter are wrong.

**Findings addressed**: LC-001

**Files affected**
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift` (remove one line)

**Behavior affected**: The `audioPayloadsDroppedBeforePlayout` field in
`DirectPeerSessionAVMetrics` reports the correct value. The runtime pass/fail decision
(via `validateUsefulMediaMoved`) is not affected because it reads `audioPayloadsQueuedForPlayout`,
not the dropped counters.

**Public contracts affected**: `DirectPeerSessionAVMetrics.audioPayloadsDroppedBeforePlayout`
is a report field. The value changes (decreases) for any session with playout-queue
rejections. Downstream consumers of this field (dashboards, validators) should be aware.

**Storage/migration impact**: None. No stored state is read or written; the fix changes
a computed accumulation.

**Tests to add or update**
- Add a unit test that constructs a `DirectPeerAudioRXDrainResult` with
  `droppedBeforePlayout = 3` and `droppedByPlayoutQueue = 2`, runs the metric accumulation
  block, and asserts `audioPayloadsDroppedBeforePlayout == 5` (not 7) and
  `audioPayloadsDroppedByPlayoutQueue == 2`.

**Verification commands**
```bash
grep -n "droppedByPlayoutQueue" Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift
swift test --filter DirectPeerSessionAVMetrics   # if a targeted test exists after addition
swift test --no-parallel
```

**Rollback strategy**: Restore the removed line.

**Ordering rationale**: One-line removal with a new test. Fixes incorrect report data that
could mislead quality decisions.

**Definition of Done**
- The duplicate accumulation line is removed.
- A new test asserts the correct counter relationship.
- `swift test --no-parallel` passes with no new failures.

---

### RP-05: Add `outputDeviceUID` to `validateAVConfiguration`

**ID**: RP-05
**Phase**: 2 — Confirmed silent wrong behavior
**Risk**: Low

**Problem**

`validateAVConfiguration` in `DirectPeerSessionAVSocketRunner.swift` (~line 88) checks only
`configuration.audioDeviceUID` (which returns `inputDeviceUID` via the deprecated accessor).
If `inputDeviceUID` is non-empty and `outputDeviceUID` is empty, the check passes but the
graph fails later during `start()` with `DirectPeerAudioGraphError.missingDeviceUID("")` —
an error message that contains an empty string and gives no indication of which field is wrong.

**Findings addressed**: LC-003

**Files affected**
- `Sources/OpenLolaCore/Network/P2P/DirectPeerSessionAVSocketRunner.swift` (add one guard)

**Behavior affected**: Configurations with an empty `outputDeviceUID` will now fail early
with a clear error before the CoreAudio graph is constructed, rather than failing midway
through graph setup. Configurations with both UIDs set are unaffected.

**Public contracts affected**: `DirectPeerSessionAVRuntimeError` gains a potential new case
`missingOutputDeviceUID` (or the existing `missingAudioDeviceUID` is reused — decide in
implementation). If a new error case is added, it is additive only.

**Storage/migration impact**: None.

**Tests to add or update**
- Add a test that constructs a `DirectPeerSessionAVRunConfiguration` with a non-empty
  `inputDeviceUID` and an empty `outputDeviceUID`, calls `validateAVConfiguration`, and
  expects an error to be thrown (whichever error case is chosen).
- Confirm that configurations with both UIDs set do not throw.

**Verification commands**
```bash
swift test --filter DirectPeerSessionAVSocketRunner   # or the relevant test file
swift test --no-parallel
```

**Rollback strategy**: Remove the added guard line.

**Ordering rationale**: Fixes a deferred validation failure that produces a misleading empty-string
error. Low blast radius — one file, one guard.

**Definition of Done**
- `validateAVConfiguration` throws for an empty `outputDeviceUID`.
- A new test asserts both the error case and the success case.
- `swift test --no-parallel` passes with no new failures.

---

### RP-06: Fix `reserveInputStartFrame()` called before copy-success check

**ID**: RP-06
**Phase**: 2 — Confirmed silent wrong behavior
**Risk**: Medium

**Problem**

In `DirectPeerRealtimeAudioGraph.copyInputToCaptureRing`, `reserveInputStartFrame()` (an atomic
fetch-add on `nextInputFrame`) is called before `copyMappedInput` succeeds. If `copyMappedInput`
fails, the counter has already advanced, creating a gap in the frame sequence. The next successful
copy receives a start frame one higher than expected. On the receiving side, the missing sequence
number looks like a dropped network packet, misattributing a local CoreAudio condition to network
loss.

**Findings addressed**: LC-004

**Files affected**
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift`
  (`copyInputToCaptureRing` function — reorder two lines)

**Behavior affected**: When `copyMappedInput` fails, `nextInputFrame` is no longer advanced.
The next successful copy gets the same start frame that would have been used before the
failed copy. Frame sequences remain contiguous across copy failures.

**Public contracts affected**: The `nextInputFrame` counter changes behavior only in the
failure path (copy fail). In the success path — by far the common case — behavior is identical.
The sequence number range visible to the remote receiver may differ during CoreAudio error
conditions.

**Storage/migration impact**: None.

**Tests to add or update**
- Add a test using the test injection path (`captureInjectedPayload` with crafted payloads)
  that simulates a failed copy (or directly tests the IOProc path with zero-channel buffers),
  then a valid payload, and asserts the second payload's sequence number is immediately
  consecutive with the last successful sequence number.
- If the IOProc path is not directly unit-testable, add a comment to `copyInputToCaptureRing`
  documenting the invariant: "startFrame is reserved only after copy succeeds."

**Verification commands**
```bash
swift test --filter DirectPeerRealtimeAudioGraph
swift test --no-parallel
```

**Rollback strategy**: Restore the original line order.

**Ordering rationale**: Medium risk because the change is in a realtime audio code path.
However, the fix is a two-line reorder with no logic change in the success path. Must be done
after RP-01–05 are confirmed green so the test suite is a reliable baseline.

**Definition of Done**
- `reserveInputStartFrame()` is called after `copyMappedInput` succeeds.
- A test or comment documents the invariant.
- `swift test --no-parallel` passes with no new failures.

---

### RP-07: Fix IOProc host-time overflow to drop block instead of stopping device

**ID**: RP-07
**Phase**: 2 — Confirmed silent wrong behavior
**Risk**: Low

**Problem**

`directPeerRealtimeAudioIOProc` and `directPeerRealtimeAudioOutputIOProc` in
`DirectPeerRealtimeAudioGraphCallbacks.swift` return `kAudioHardwareIllegalOperationError`
when `nanoseconds(fromHostTime:)` returns `nil` (Mach timebase overflow). Returning this
error from an IOProc causes Core Audio to stop the device immediately. The graph's
`ioProcRunning` flag is not cleared; the session continues without audio, silently.
The overflow is unreachable in practice on Apple Silicon (~584 years uptime at 1:1 timebase),
but the code path, if triggered, produces a worse outcome than a single dropped block.

**Findings addressed**: LC-005

**Files affected**
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphCallbacks.swift`
  (both IOProc functions — change return value + add comment)

**Behavior affected**: On host-time overflow (unreachable in practice), the IOProc skips
one callback block and returns `kAudioHardwareNoError` instead of stopping the device.
Normal execution is unchanged.

**Public contracts affected**: None.

**Storage/migration impact**: None.

**Tests to add or update**
- Add a unit test for `nanoseconds(fromHostTime:)` with overflow inputs
  (e.g. `hostTime = UInt64.max`, `numerator = 2`) asserting `nil` is returned.
- Add a comment in the IOProc that documents why the overflow guard returns
  `kAudioHardwareNoError` (not `kAudioHardwareIllegalOperationError`).

**Verification commands**
```bash
swift test --filter DirectPeerRealtimeAudioGraph
swift test --no-parallel
```

**Rollback strategy**: Restore the original return value.

**Ordering rationale**: Low risk; addresses a catastrophic-but-unreachable failure mode.
Placing it in Phase 2 keeps realtime code changes together so they can be reviewed as a unit.

**Definition of Done**
- Both IOProc overflow branches return `kAudioHardwareNoError`.
- A comment explains the reasoning.
- A test for `nanoseconds(fromHostTime:)` overflow exists and passes.

---

## Phase 3 — Suspected issues (verify before fixing)

These two slices require targeted code inspection or a thread-sanitizer run before
the fix can be confidently written. Each slice begins with a verification step.

---

### RP-08: Verify and resolve NSLock acquisition on the realtime IOProc call chain

**ID**: RP-08
**Phase**: 3 — Suspected issues
**Risk**: High (if confirmed)

**Problem**

`queuePlayoutPayload` in `DirectPeerRealtimeAudioGraph` acquires `rxBufferAdaptationLock`
(an `NSLock`) when computing `currentPlayoutTargetFrames()`. The caller is the network
receive task, which is not realtime. However, if `renderPlayout` (called from the IOProc
realtime thread) also acquires `rxBufferAdaptationLock`, this constitutes a priority
inversion: an `NSLock` is not safe to acquire from a realtime thread.

**Findings addressed**: LC-008

**Files affected**
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift` (inspection + possible fix)

**Behavior affected**
- If `renderPlayout` does NOT acquire `rxBufferAdaptationLock`: add a comment documenting
  the lock discipline; no code change.
- If `renderPlayout` DOES acquire `rxBufferAdaptationLock`: redesign the playout path to
  read committed state without locking from the realtime thread (e.g., use an atomic
  snapshot or replace `NSLock` with `os_unfair_lock` where appropriate).

**Public contracts affected**: None if no lock contention. If the lock is removed from the
RT path, the adaptive RX buffer behavior may need to be re-verified.

**Storage/migration impact**: None.

**Tests to add or update**
- Add a comment to `renderPlayout` and `currentPlayoutTargetFrames()` explicitly documenting
  which threads can call each function.
- If a fix is required, add a test that exercises the playout path under concurrent
  `queuePlayoutPayload` calls.

**Verification commands**
```bash
# Step 1: verify by inspection
grep -n "rxBufferAdaptationLock\|renderPlayout" Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraph.swift

# Step 2: if fix is required
swift test --filter DirectPeerRealtimeAudioGraph
swift test --no-parallel
```

**Rollback strategy**: If a fix is required, revert the file to pre-PR state.

**Ordering rationale**: Verification step first; do not write a fix before confirming the
issue exists. Placed after Phase 2 so the audio realtime test baseline is stable.

**Definition of Done**
- Either: a comment documents that `renderPlayout` does not acquire `rxBufferAdaptationLock`,
  verified by code inspection.
- Or: the lock discipline is corrected so the realtime thread never blocks on `NSLock`,
  and a test confirms concurrent correctness.

---

### RP-09: Fix double-validation guard in `AppExecutionController`

**ID**: RP-09
**Phase**: 3 — Suspected issues
**Risk**: Low

**Problem**

`AppExecutionController.validateReport()` checks `!isRunning` but not `process == nil`
before launching a validation process via `runOneShot`. If two UI interactions call
`validateReport` before `runOneShot` sets `self.process`, a second validation process
is launched, the first's result is overwritten, and the UI ends up in a misleading state.
`AppExecutionController` is `@MainActor` so the race window requires both calls to arrive
in the same run-loop turn — this is uncommon but not impossible from a double-tap or
programmatic test.

**Findings addressed**: LC-009

**Files affected**
- `Sources/open-lola-app/AppExecutionController.swift`

**Behavior affected**: A second `validateReport()` call before the first process is set
will be rejected with an early return. No behavior change in the normal single-invocation
case.

**Public contracts affected**: None.

**Storage/migration impact**: None.

**Tests to add or update**
- Add a `@MainActor` unit test that calls `validateReport` twice in rapid succession and
  confirms only one process was launched (observe `phase != .validationRunning` on the
  second call, or assert `lastCommand` is set only once).

**Verification commands**
```bash
swift test --filter AppExecutionController   # once tests exist
swift test --no-parallel
```

**Rollback strategy**: Remove the added guard condition.

**Ordering rationale**: Low practical risk; included to complete all confirmed/suspected
issues before moving to dead-code removal.

**Definition of Done**
- `validateReport()` returns early if `process != nil`.
- A test documents the double-invocation contract.

---

## Phase 4 — Constraints and documentation

These slices clarify behavioral contracts and fix test infrastructure. No logic changes
except where gating tests on binary availability.

---

### RP-10: Document `UdpPcmSequenceTracker` as lossless-only + add gap behavior test

**ID**: RP-10
**Phase**: 4 — Constraints and documentation
**Risk**: Low

**Problem**

`UdpPcmSequenceTracker.accept()` throws `unexpectedSequence` on any sequence gap and has
no recovery path. On a real UDP network with any packet drops, a single dropped packet
permanently ends the session. Whether this is intentional (loopback/CI-only) is not
documented. The name `UdpPcmSequenceTracker` does not indicate the lossless constraint.

**Findings addressed**: LC-006

**Files affected**
- `Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift` (add doc comment)
- `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift` (add gap behavior test)

**Behavior affected**: None at runtime. The documentation clarifies the existing behavior.

**Public contracts affected**: None. A future slice could relax the tracker to a
gap-tolerant mode; that is not in scope here.

**Storage/migration impact**: None.

**Tests to add or update**
- Add a test that calls `accept()` with a gap (e.g. sequences 1, 3) and asserts
  `unexpectedSequence` is thrown. This test documents the current contract.
- Add a comment to `UdpPcmSequenceTracker`:
  > "This tracker requires strictly consecutive sequence numbers. It is only valid on
  > lossless paths (loopback, CI). Use on real networks requires a gap-tolerant wrapper."

**Verification commands**
```bash
swift test --filter UdpPcmPacket
swift test --no-parallel
```

**Rollback strategy**: Remove the added comment and test.

**Ordering rationale**: Documentation-only change with a clarifying test. Low risk.
Establishes a written contract before any future gap-tolerance work.

**Definition of Done**
- A doc comment on `UdpPcmSequenceTracker` states the lossless constraint.
- A test asserts the gap-throw behavior.

---

### RP-11: Gate NMP preflight tests on explicit binary presence

**ID**: RP-11
**Phase**: 4 — Constraints and documentation
**Risk**: Low

**Problem**

`externalConnectorNmpPreflightRuns*` tests shell out to `uv`. In this environment `uv`
resolves to Astral Python's package manager, not UltraGrid. Tests either pass vacuously
(if the fake executable covers the path) or fail with a confusing error. No real UltraGrid
binary integration is being confirmed.

**Findings addressed**: LC-013

**Files affected**
- `Tests/OpenLolaCoreTests/ExternalConnectorNmpPreflightTests.swift`

**Behavior affected**: Tests that require a real `uv` binary will be skipped unless a
specific environment variable (e.g. `OPENLOLA_ULTRAGRID_UV_PATH`) is set. This makes
the test intent explicit and prevents false confidence.

**Public contracts affected**: None.

**Storage/migration impact**: None.

**Tests to add or update**
- Wrap each test that requires the real `uv` binary with a `withKnownIssue` or `#require`
  guard on an environment variable, so the test is skipped (not silently wrong) when
  the binary is not present.

**Verification commands**
```bash
swift test --filter externalConnectorNmpPreflight
swift test --no-parallel
```

**Rollback strategy**: Remove the environment variable guard.

**Ordering rationale**: Test infrastructure fix; does not change production code. Placed
after Phase 3 so all correctness fixes are in before test suite adjustments.

**Definition of Done**
- Tests that require a real UltraGrid binary are explicitly skipped when the binary is absent.
- The skip reason is readable in test output.

---

## Phase 5 — Dead code removal

Each slice in this phase removes code whose usage was verified as absent or redundant.
All are low risk if the verification step passes.

---

### RP-12: Delete the `JSONReportCoder` dead alias

**ID**: RP-12
**Phase**: 5 — Dead code removal
**Risk**: Low

**Problem**

`OpenLolaContractsAliases.swift` re-exports `JSONReportCoder` from `OpenLolaContracts` into
`OpenLolaCore`. Zero call sites use this alias within `Sources/` or `Tests/`
(excluding the alias file itself and `PrettyJSONCodable.swift` where it is defined).

**Findings addressed**: DA-003

**Files affected**
- `Sources/OpenLolaCore/Core/OpenLolaContractsAliases.swift` (delete one line)

**Behavior affected**: No production code uses `JSONReportCoder` via the alias. Build
succeeds.

**Public contracts affected**: `JSONReportCoder` as a re-export from `OpenLolaCore` is
removed. If any external consumer imports this alias, they must switch to
`OpenLolaContracts.JSONReportCoder` or just `PrettyJSONCodable`. No known external callers.

**Storage/migration impact**: None.

**Tests to add or update**
- Confirm at PR time: `grep -rn "JSONReportCoder" Sources/ Tests/ --include="*.swift"` returns
  only `OpenLolaContracts/PrettyJSONCodable.swift`. If any other file appears, stop and
  investigate before deleting.

**Verification commands**
```bash
grep -rn "JSONReportCoder" Sources/ Tests/ --include="*.swift"
swift build
swift test --no-parallel
```

**Rollback strategy**: Restore the deleted line.

**Ordering rationale**: Zero-risk single-line removal; zero call sites confirmed. Done after
Phase 4 so the test baseline is clean.

**Definition of Done**
- `JSONReportCoder` alias line is deleted.
- `swift build` succeeds.
- `grep -rn "JSONReportCoder" Sources/` returns no results except the definition in
  `OpenLolaContracts`.

---

### RP-13: Inline `LoLaParityLedgerRunMode` typealias

**ID**: RP-13
**Phase**: 5 — Dead code removal
**Risk**: Low

**Problem**

`LoLaParityDeferredFeatures.swift:3` declares:
```swift
public typealias LoLaParityLedgerRunMode = MeasurementMethodology
```
The alias is used only inside `LoLaParityDeferredFeatures.swift` itself. A test
(`MeasurementMethodologyTests.swift:13`) asserts the alias is equivalent to
`MeasurementMethodology`. The alias adds a confusing rename for a well-known shared type.

**Findings addressed**: DA-004

**Files affected**
- `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift`
  (replace all `LoLaParityLedgerRunMode` references with `MeasurementMethodology`, delete typealias)
- `Tests/OpenLolaCoreTests/MeasurementMethodologyTests.swift` (delete the now-tautological
  assertion)

**Behavior affected**: None. The type is identical.

**Public contracts affected**: `LoLaParityLedgerRunMode` is a `public` typealias. If any
external consumer uses it, they must switch to `MeasurementMethodology`. No known external
callers. The type was never part of a documented API.

**Storage/migration impact**: None.

**Tests to add or update**
- Delete `#expect(LoLaParityLedgerRunMode.synthetic == MeasurementMethodology.synthetic)` from
  `MeasurementMethodologyTests.swift`. This test was only asserting an identity that is
  trivially guaranteed by typealias semantics.

**Verification commands**
```bash
grep -rn "LoLaParityLedgerRunMode" Sources/ Tests/ --include="*.swift"
swift build
swift test --no-parallel
```

**Rollback strategy**: Restore the typealias and the test assertion.

**Ordering rationale**: After RP-12; both are low-risk one-file removals in the same area.

**Definition of Done**
- `LoLaParityLedgerRunMode` does not appear in `Sources/` or `Tests/`.
- `swift build` and `swift test --no-parallel` succeed.

---

### RP-14: Delete the deprecated synthetic G16 parity ledger function

**ID**: RP-14
**Phase**: 5 — Dead code removal
**Risk**: Low

**Problem**

`LoLaParityDeferredFeatures.swift:216` contains a function marked
`@available(*, deprecated, message: "Synthetic G16 parity ledger is fixture/documentation
scaffolding only...")`. The active CLI path uses `LoLaParityDeferredFixtures.partialLedger()`.
The deprecated function should be deleted if it has no active callers.

**Findings addressed**: DA-002

**Files affected**
- `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift` (delete deprecated function)

**Behavior affected**: None if the function is unrouted. Verify before deleting.

**Public contracts affected**: The deprecated function is public. If any external consumer
uses it, deletion is a breaking change. Verify with `grep` before proceeding.

**Storage/migration impact**: None.

**Tests to add or update**
- Pre-deletion verification: `grep -rn "syntheticG16\|LoLaParityDeferredSyntheticSmoke" Sources/ Tests/`
  should return only the definition site. If any call site appears, add it to the
  `Verification needed` log and do not delete until those call sites are updated.

**Verification commands**
```bash
grep -rn "syntheticG16\|LoLaParityDeferredSyntheticSmoke" Sources/ Tests/ --include="*.swift"
swift build
swift test --no-parallel
```

**Rollback strategy**: Restore the deleted function.

**Ordering rationale**: Low risk; must confirm zero callers before deleting. Depends on
RP-13 being complete so the file is already simplified.

**Definition of Done**
- `grep` confirms zero call sites.
- Function is deleted.
- `swift build` succeeds.
- `swift test --no-parallel` passes.

---

### RP-15: Verify and delete the legacy `audioDeviceUID` CodingKey decode branch

**ID**: RP-15
**Phase**: 5 — Dead code removal
**Risk**: Medium

**Problem**

`DirectPeerRealtimeAudioGraphTypes.swift:130` has a `@available(*, deprecated)` marker
on the `audioDeviceUID` CodingKey in the `Codable` decode path. The field was split into
`inputDeviceUID` and `outputDeviceUID`. If no saved JSON config or fixture still uses the
old `audioDeviceUID` key, the legacy decode branch can be removed. If any does, removal
is a breaking change.

**Findings addressed**: DA-001

**Files affected**
- `Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift`
  (conditional: delete legacy CodingKey decode branch if no JSON callers found)

**Behavior affected**: If removed, JSON configs containing only `audioDeviceUID` (and not
`inputDeviceUID`/`outputDeviceUID`) will fail to decode.

**Public contracts affected**: The `Codable` decode contract for
`DirectPeerRealtimeAudioGraphConfiguration` changes if the legacy key is removed.

**Storage/migration impact**: High if any stored config uses `audioDeviceUID`. Perform the
verification step before any code change.

**Tests to add or update**
- Verification step: `grep -r '"audioDeviceUID"' Tests/Fixtures/ private/` — if any match
  found, the legacy branch must be kept until those fixtures are migrated.
- If removal proceeds, add a test asserting that JSON with only `inputDeviceUID` and
  `outputDeviceUID` decodes successfully, and that JSON with only `audioDeviceUID` now
  throws a `DecodingError`.

**Verification commands**
```bash
# Step 1: check for saved JSON using the legacy key
grep -r '"audioDeviceUID"' Tests/Fixtures/ private/ 2>/dev/null

# Step 2: if safe to delete
swift build
swift test --no-parallel
```

**Rollback strategy**: Restore the legacy CodingKey decode branch.

**Ordering rationale**: Must be done after all other dead-code removals have confirmed the
verification process works. Placed last in Phase 5 because it carries the highest risk
(stored config compatibility).

**Definition of Done**
- Either: `grep` finds no JSON using `"audioDeviceUID"` key; the legacy branch is deleted;
  tests confirm new decode behavior.
- Or: `grep` finds one or more fixtures using `"audioDeviceUID"`; those fixtures are
  migrated to `inputDeviceUID`/`outputDeviceUID`; the legacy branch is then deleted.

---

## Phase 6 — File size and structure

These slices fix files that exceed or approach the 720-line budget. Each is a structural
refactor only — CLI command names, arguments, and behavior must remain identical.

---

### RP-16: Split JackTrip source and test files under 720-line budget

**ID**: RP-16
**Phase**: 6 — File size and structure
**Risk**: Medium

**Problem**

`JackTripCompatibility.swift` (764 lines) and `JackTripCompatibilityTests.swift` (768 lines)
both exceed the 720-line budget enforced by `scopedCodeFilesStayWithinLineBudget`. The
quality gate is currently red for these two files.

**Findings addressed**: LC-010

**Files affected**
- `Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift`
  (split into two or more files; e.g., by protocol surface vs. implementation detail)
- `Tests/OpenLolaCoreTests/JackTripCompatibilityTests.swift`
  (split by concern; e.g., packet header tests vs. launch plan tests vs. protocol model tests)

**Behavior affected**: None. Pure structural reorganization; no API change.

**Public contracts affected**: All `public` symbols must remain public and reachable from
the same module after the split. No symbol renaming or deletion.

**Storage/migration impact**: None.

**Tests to add or update**
- All existing tests must continue to pass.
- `scopedCodeFilesStayWithinLineBudget` must pass after the split.

**Verification commands**
```bash
swift test --filter scopedCodeFilesStayWithinLineBudget
swift test --filter JackTrip
swift test --no-parallel
```

**Rollback strategy**: Restore the original single-file versions.

**Ordering rationale**: Placed after Phase 5 so dead-code removals have already reduced
line counts where possible before the structural split.

**Definition of Done**
- Both `JackTripCompatibility.swift` and `JackTripCompatibilityTests.swift` are under 720 lines.
- `scopedCodeFilesStayWithinLineBudget` passes for these files.
- All JackTrip-related tests pass.

---

### RP-17: Split `MilestoneCommands.swift` into domain sub-dispatchers

**ID**: RP-17
**Phase**: 6 — File size and structure
**Risk**: Medium

**Problem**

`Sources/open-lola/Commands/MilestoneCommands.swift` is 610 lines with a single
`handleMilestoneCommand` function containing 62 switch arms (28 `case [...]` + 34 `case let
args`). All arms follow the same three-step pattern: parse configuration → run/validate →
write report. Every new milestone command must be inserted into this function. The file is
approaching the 720-line budget.

**Findings addressed**: DA-006

**Files affected**
- `Sources/open-lola/Commands/MilestoneCommands.swift` (thin dispatcher only — delegates by domain)
- New files (e.g., `MilestoneAudioCommands.swift`, `MilestoneVideoCommands.swift`,
  `MilestoneNetworkCommands.swift`, `MilestoneTimingCommands.swift`,
  `MilestoneReleaseCommands.swift`) added in `Sources/open-lola/Commands/`

**Behavior affected**: None. All CLI command names, arguments, and outputs must be identical.
This is a structural extract — move switch arms, do not rewrite them.

**Public contracts affected**: CLI command names are a public contract. Do not rename or
remove any command.

**Storage/migration impact**: None.

**Tests to add or update**
- All existing milestone command smoke tests must pass.
- If no automated test exercises each CLI command, add at minimum one test per sub-dispatcher
  that exercises the parse step.

**Verification commands**
```bash
swift build --product open-lola
swift test --no-parallel
.build/debug/open-lola milestone --help  # confirm all commands still appear
```

**Rollback strategy**: Revert all new files and restore the original `MilestoneCommands.swift`.

**Ordering rationale**: Placed after Phase 5 (dead code removed) and RP-16 (file-split
pattern established). Extract sub-dispatchers one domain at a time to reduce blast radius.

**Definition of Done**
- `MilestoneCommands.swift` is under 300 lines (a thin dispatcher).
- Each sub-dispatcher file is under 720 lines.
- All CLI milestone commands work identically to pre-split behavior.
- `swift test --no-parallel` passes.

---

### RP-18: Split `NetworkCommands.swift` into domain sub-dispatchers

**ID**: RP-18
**Phase**: 6 — File size and structure
**Risk**: Medium

**Problem**

`Sources/open-lola/Commands/Network/NetworkCommands.swift` is 380 lines with ~46 switch arms
covering UDP-PCM routes, direct-P2P sessions, connector sessions, network diagnostics, video
transport, and more. The same pattern as RP-17.

**Findings addressed**: DA-007

**Files affected**
- `Sources/open-lola/Commands/Network/NetworkCommands.swift` (thin dispatcher)
- New sub-dispatcher files in `Sources/open-lola/Commands/Network/`

**Behavior affected**: None. Same structural extract as RP-17.

**Public contracts affected**: CLI command names must remain identical.

**Storage/migration impact**: None.

**Tests to add or update**
- All existing network command tests must pass.

**Verification commands**
```bash
swift build --product open-lola
swift test --no-parallel
.build/debug/open-lola network --help
```

**Rollback strategy**: Revert to the original `NetworkCommands.swift`.

**Ordering rationale**: Follows RP-17. Identical approach; can be done in parallel if two
reviewers are available.

**Definition of Done**
- `NetworkCommands.swift` is under 200 lines (a thin dispatcher).
- Each sub-dispatcher is under 720 lines.
- All network CLI commands work identically.
- `swift test --no-parallel` passes.

---

## Phase 7 — Validation deduplication (pilot, then module-by-module)

This phase eliminates the ~50 duplicated validation helper functions spread across 15 files
by migrating them to `ReportValidationProtocol` in `ValidationPrimitives.swift`. Migrate
one module per PR, in order of increasing complexity.

---

### RP-19: Pilot migration — `RxBuffering.swift` validation helpers to `ReportValidationProtocol`

**ID**: RP-19
**Phase**: 7 — Validation deduplication
**Risk**: Low (pilot module)

**Problem**

`Sources/OpenLolaCore/Timing/RxBuffering.swift` defines four private validation helpers
(`requireRxNonEmpty`, `requireRxPositive`, `requireRxNonNegative` × 2) that duplicate
the same logic already present in `ValidationPrimitives.swift`. Migrating this module
first establishes the pattern and confirms `ReportValidationProtocol` adoption is viable.

**Findings addressed**: DA-005 / DA-010 (pilot slice)

**Files affected**
- `Sources/OpenLolaCore/Timing/RxBuffering.swift`
  (delete private helpers; conform the module's validator to `ReportValidationProtocol`)
- `Sources/OpenLolaCore/Core/ValidationPrimitives.swift`
  (no change unless a missing helper is discovered during migration)

**Behavior affected**: Identical validation behavior. Error types thrown by the moved
helpers must remain unchanged (or the migration must update all catch sites).

**Public contracts affected**: The thrown error types must remain identical to avoid
breaking existing error-handling code.

**Storage/migration impact**: None.

**Tests to add or update**
- All existing `RxBuffering`-related tests must pass without modification.
- Add a test asserting that the previously-private validation helpers reject their
  error cases (e.g., empty string, negative value) — if no such test exists — to ensure
  the migration preserves all constraints.

**Verification commands**
```bash
swift test --filter RxBuffer
swift test --no-parallel
```

**Rollback strategy**: Restore the deleted helpers in `RxBuffering.swift`.

**Ordering rationale**: Smallest, most self-contained module for the pilot. Success
establishes whether `ReportValidationProtocol` adoption is smooth before touching the
14 remaining modules.

**Definition of Done**
- The four private helpers are deleted from `RxBuffering.swift`.
- The module's validator conforms to `ReportValidationProtocol`.
- All existing tests pass.
- A migration note documents the error-type preservation requirement for subsequent modules.

---

### RP-20 through RP-33: Remaining validation helper migrations

**ID**: RP-20 … RP-33
**Phase**: 7 — Validation deduplication (future slices)

After RP-19 confirms the migration pattern works, apply the same approach to the remaining
14 modules in `docs/deprecation-and-simplification-audit.md` DA-005 table. Suggested order
(simplest to most complex):

1. `SessionProfileBenchmark.swift` (1 helper)
2. `AudioLoopbackHelpers.swift` (1 helper)
3. `MediaGeometrySizing.swift` (1 helper)
4. `MadiReceiveReport.swift` (3 helpers)
5. `MadiTransmit.swift` (3 helpers)
6. `RealtimeAudioEngineHelpers.swift` (4 helpers)
7. `DriftPlcHelpers.swift` (4 helpers)
8. `RxBufferBenchmarkReport.swift` (5 helpers)
9. `LatencyBenchmarkReport.swift` (6 helpers)
10. `DriftPlcFixedTargetCertification.swift` (4 helpers)
11. `MadiFullDuplexValidation.swift` (5 helpers)
12. `E2EBenchmarkReportValidation.swift` (8 helpers)
13. `VideoCaptureHelpers.swift` (9 helpers)
14. `VideoTransportHelpers.swift` (6 helpers)

Each module is a separate PR. Each PR:
- Deletes the per-module helpers
- Conforms the validator to `ReportValidationProtocol`
- Runs `swift test --no-parallel` and confirms no regression

These slices are not detailed further here. RP-19 is the prerequisite; begin RP-20
only after RP-19 is merged and the migration pattern is confirmed clean.

---

## Execution checklist

| Slice | Phase | Findings | Risk | Status |
|-------|-------|----------|------|--------|
| RP-01 | 1 — Green-test restoration | LC-007 | Low | Not started |
| RP-02 | 1 — Green-test restoration | LC-002, LC-011 | Medium | Not started |
| RP-03 | 1 — Green-test restoration | LC-012 | Low | Not started |
| RP-04 | 2 — Silent wrong behavior | LC-001 | Low | Not started |
| RP-05 | 2 — Silent wrong behavior | LC-003 | Low | Not started |
| RP-06 | 2 — Silent wrong behavior | LC-004 | Medium | Not started |
| RP-07 | 2 — Silent wrong behavior | LC-005 | Low | Not started |
| RP-08 | 3 — Suspected issues | LC-008 | High (if confirmed) | Not started |
| RP-09 | 3 — Suspected issues | LC-009 | Low | Not started |
| RP-10 | 4 — Constraints/docs | LC-006 | Low | Not started |
| RP-11 | 4 — Constraints/docs | LC-013 | Low | Not started |
| RP-12 | 5 — Dead code removal | DA-003 | Low | Not started |
| RP-13 | 5 — Dead code removal | DA-004 | Low | Not started |
| RP-14 | 5 — Dead code removal | DA-002 | Low | Not started |
| RP-15 | 5 — Dead code removal | DA-001 | Medium | Not started |
| RP-16 | 6 — File size/structure | LC-010 | Medium | Not started |
| RP-17 | 6 — File size/structure | DA-006 | Medium | Not started |
| RP-18 | 6 — File size/structure | DA-007 | Medium | Not started |
| RP-19 | 7 — Validation dedup (pilot) | DA-005, DA-010 | Low | Not started |
| RP-20+ | 7 — Validation dedup (remaining) | DA-005, DA-010 | Low | Not started |

---

## Findings not planned

The following audit findings are deliberately excluded from this plan:

| Finding | Reason not planned |
|---------|-------------------|
| DA-008 (`ExternalConnectorSessionRuntime` protocol) | Justified DI pattern; keep as-is |
| DA-009 (parallel connector launch plan structure) | Risk of wrong abstraction; investigate first |
| DA-011 (`prototype` naming in CLI) | Naming is a public contract; needs schema promotion milestone |
| DA-012 (`VideoTransportMultiStreamRuntime` staged) | Status unclear; add comment, no code change needed |
| DA-013 (CoreAudio HAL OSStatus checking) | Keep API; audit OSStatus handling separately |

---

## Verification rules applying to all slices

1. Run `bash scripts/verify-docs.sh` after any documentation change.
2. Run `swift test --no-parallel` after every code change and confirm the count of
   pre-existing failing tests does not increase.
3. Do not use backtick-wrapped paths starting with `script/` (singular) in any documentation
   file — this triggers the release hygiene gate (see `docs/verification-baseline.md`).
4. Any new public API or error case must appear in both the type definition and at least one test.
5. Report fields that change values require a note in the PR description documenting the
   behavioral delta for downstream consumers.
