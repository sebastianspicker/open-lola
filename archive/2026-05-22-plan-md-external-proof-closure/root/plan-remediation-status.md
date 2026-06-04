# Open LoLa Final Plan Remediation Status

Source of truth: `final-plan.md` (2026-05-21).

Overall state: `PARTIALLY_VERIFIED`

Current slice: none - remediation ledger exhausted; external verification
blockers remain.

Completed slices:
- `PH0-BASELINE`
- `PH0-IOPROC-HARNESS`
- `PH0-UDP-HARNESS`
- `PH0-P2P-CONNECT-HARNESS`
- `PH0-UI-METRICS-HARNESS`
- `S-P1-P2P-004`
- `S-P1-P2P-002`
- `S-P1-UI-004`
- `S-P1-MADI-002` at source/test level
- `S-P1-RXBUF-001`
- `S-P1-P2P-001`
- `S-P1-MADI-003` at source/test level
- `S-P1-RT-002` at source/test level
- `S-P1-RT-003` at source/test level
- `S-P1-RT-004` at source/test level
- `S-P1-SLOP-001-002` at source/test level
- `S-P1-UI-001` at source/test level
- `S-P1-UI-002` at source/test level
- `S-P2-UI-012`
- `S-P2-UI-001`
- `S-P2-UI-007`
- `S-P2-UI-008`
- `S-P2-UI-011`
- `S-P2-DEAD-001`
- `S-P2-DEAD-002`
- `S-P2-DEPR-001`
- `S-P2-DEDUP-001`
- `S-P2-MADI-001` at source/test level
- `S-P2-SLOP-001`
- `S-P3-SLOP-003`
- `S-P2-STRUCT-001`
- `S-P2-STRUCT-002`
- `S-P2-STRUCT-004`
- `S-P2-SLOP-002`
- `S-P3-POLISH` at source/test level

Verified slices:
- `PH0-BASELINE`
- `PH0-IOPROC-HARNESS`
- `S-P0-001` at source/test level
- `S-P0-002` at source/test level
- `S-P1-P2P-005`
- `S-P1-UI-003`
- `S-P1-MADI-001` at source/test level
- `S-P1-MEDIA-001`
- `S-P1-RT-001` at source/test level
- `S-P1-UDP-001`
- `S-P1-P2P-004`
- `S-P1-P2P-002`
- `S-P1-UI-004`
- `S-P1-RXBUF-001`
- `S-P1-P2P-001`
- `S-P1-MADI-003` at source/test level
- `S-P1-RT-002` at source/test level
- `S-P1-RT-003` at source/test level
- `S-P1-RT-004` at source/test level
- `S-P1-SLOP-001-002` at source/test level
- `S-P1-UI-001` at source/test level
- `S-P1-UI-002` at source/test level
- `S-P2-UI-012`
- `S-P2-UI-001`
- `S-P2-UI-007`
- `S-P2-UI-008`
- `S-P2-UI-011`
- `S-P2-DEAD-001`
- `S-P2-DEAD-002`
- `S-P2-DEPR-001`
- `S-P2-DEDUP-001`
- `S-P2-MADI-001` at source/test level
- `S-P2-SLOP-001`
- `S-P3-SLOP-003`
- `S-P2-STRUCT-001`
- `S-P2-STRUCT-002`
- `S-P2-STRUCT-004`
- `S-P2-SLOP-002`
- `S-P3-POLISH` at source/test level

Blocked slices:
- `S-P0-002` TSAN verification: `swift test --sanitize=thread --filter
  udpMediaTransportCloseCompletesWhileReceiveIsBlocking` fails before test
  execution inside and outside the sandbox because dyld rejects Xcode's Thread
  Sanitizer runtime with `Sanitizer load violates platform policy`.

Deferred slices:
- `S-P2-STRUCT-003` because `final-plan.md` says to split
  `DirectPeerSessionReport.swift` only if the validation chain grows further.
- `S-P2-DEDUP-002` because `final-plan.md` explicitly defers connector file
  structure cleanup, and inspection shows the parallel connector files are
  active protocol-specific runtime/comparison surfaces that need a separate
  connector architecture plan before any behavior-preserving migration.
- `P3-RXBUF-001` because current direct graph and MADI receive paths already
  drop/flag overruns and feed adaptive pressure, while adding generic
  corrective action would change latency policy and needs a separate runtime
  design slice.

Source-level verified slices pending external field proof:
- `S-P0-001` still needs real CoreAudio start/stop stress with
  AddressSanitizer before it can be called field-proven.
- `S-P0-002` still needs the required focused Thread Sanitizer run after the
  local Xcode/macOS sanitizer runtime can load.
- `S-P1-MADI-001` still needs a manual run with two distinct CoreAudio device
  UIDs before the routing fix can be called hardware-proven.
- `S-P1-MADI-002` still needs AddressSanitizer with real CoreAudio device
  enumeration before it can be called sanitizer-proven.
- `S-P1-RT-001` used injected CoreAudio stop failure through DEBUG cleanup
  hooks; no real-device stop-failure run was performed.
- `S-P1-MADI-003` validates raw PCM route construction against the advertised
  local audio capability set; no physical CoreAudio/RME inventory proof was run.
- `S-P1-RT-002` uses DEBUG cleanup hooks and a lock-contention regression; no
  real CoreAudio teardown stress or sanitizer run was performed.
- `S-P1-RT-003` proves the callback duration source no longer uses
  `DispatchTime.now()` and keeps counters meaningful with deterministic tick
  injection; no real CoreAudio jitter/stress/sanitizer run was performed.
- `S-P1-RT-004` proves the source-level callback copy path no longer uses the
  per-sample checked byte-offset helper and preserves planar copy plus malformed
  short-buffer drops; no real CoreAudio jitter/stress/sanitizer run was
  performed.
- `S-P1-SLOP-001-002` proves production source no longer ships the deleted
  synthetic zero helper or literal manual evidence placeholder token. The
  replacement `SourceValidationMetrics` values are deterministic source-validation
  metrics only; they are not physical field measurements.
- `S-P1-UI-001` removes the unbacked `AppSessionState.live` surface instead of
  inventing a live signal. The highest active running state remains
  `supervisorRunning`, and validated runtime evidence remains completed
  evidence, not live packet/RMS proof.
- `S-P1-UI-002` gates topology flow animation on decoded packet evidence as
  well as an active supervisor phase. Existing capture reports are completed
  packet evidence, not a live packet/RMS stream.
- `S-P2-UI-012` maps validation preflight `evidenceIncomplete` to warning
  rather than ready/green, preserving the no-fake-PASS UI rule.
- `S-P2-UI-001` replaces transport status text substring matching with typed
  `AppExecutionPhase` tone mapping.
- `S-P2-UI-007` adds VoiceOver announcements for key session transitions while
  leaving routine states silent.
- `S-P2-UI-008` replaces internal SSH help wording with operator-facing copy.
- `S-P2-UI-011` is already addressed in current source: Local Preview window
  requests surface a request-sent, not-confirmed status.
- `S-P2-DEAD-001` is stale against current source: UltraGrid/MVTP is an active
  source-level external connector surface and should not be deleted.
- `S-P2-DEAD-002` is stale against current source: JackTrip is an active
  source-level external connector surface and should not be deleted.
- `S-P2-DEPR-001` replaces the UltraGrid raw-video file-scope `try!` constants
  with non-throwing raw FourCC values while preserving RGB3/RGBA packetization.
- `S-P2-STRUCT-001` adds a source/test path guard for the network route command
  matrix, including owner files, related files, and repo-relative paths embedded
  in representative command strings.
- `S-P2-STRUCT-002` adds a source/test path guard for repo-relative paths
  embedded in SourceOwnershipInventory validation commands, on top of the
  existing current source/test/fixture/doc path validation.
- `S-P2-STRUCT-004` documents `OpenLolaContracts` as the canonical module for
  shared framework-free report contracts and the core alias file as a small
  source-compatibility shim for existing callers.
- `S-P2-SLOP-002` removes the standalone UDP loopback defaults file after
  confirming the constants are consumed by production synthetic/NAT smoke code;
  the constants now live privately beside that smoke implementation.
- `S-P2-DEDUP-002` was inspected and deferred rather than implemented. The
  connector file parallelism spans active LoLa, UltraGrid/MVTP, JackTrip, and
  NMP runtime/comparison code and is not a safe single-slice deduplication.
- `S-P2-MADI-001` gates the MADI socket packet loop on a bounded UDP readiness
  exchange tied to session ID and peer ID. A lone peer now times out instead of
  streaming optimistically.
- `S-P3-POLISH` is source/test verified for bounded P3 items: strict non-zero
  trailing-byte rejection in LoLa wire frames, typed MADI buffer capacity
  errors, P2P shutdown state clearing, always-on SPSC owner-violation handling,
  central byte-reader range guards, FNV intent documentation, and Blackmagic
  preview copy that reflects selected inventory. Stale/no-delete P3 items were
  verified instead of deleted.

Remaining slices: no non-deferred ledger rows remain unverified. Remaining
blocked/deferred work is listed above.

Highest remaining actionable severity: none in the ledger. Highest remaining
blocked verification: P0 TSAN rerun for `S-P0-002`.

Commands run:
- `swift test --no-parallel` (2026-05-22): failed after a broad Swift Testing
  run reached `ReleaseArtifactHygieneContractTests` and found the requested
  companion files missing.
- `swift test --filter directPeerRealtimeAudioGraphStopWaitsForActiveCallbackBeforeDestroyingIOProc`
  (before fix): failed because `stop()` returned while the simulated IOProc
  callback was active and `destroy` observed the active callback.
- `swift test --filter directPeerRealtimeAudioGraphStopWaitsForActiveCallbackBeforeDestroyingIOProc`
  (after fix): passed.
- `swift test --filter DirectPeerRealtimeAudioGraphTests`: passed 11 tests.
- `swift build`: failed inside sandbox with `sandbox-exec: sandbox_apply:
  Operation not permitted`; rerun outside sandbox and passed.
- `swift test --filter CodeLineBudgetTests`: passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  failed inside sandbox with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside sandbox and passed.
- `swift test --no-parallel` (after refreshing stale helper binary): passed
  870 tests.
- `swift test --filter udpMediaTransportCloseCompletesWhileReceiveIsBlocking`
  (before fix): failed because `close()` took 946266 us while `receive()` was
  blocking.
- `swift test --filter udpMediaTransportCloseCompletesWhileReceiveIsBlocking`
  (after fix): passed.
- `swift test --filter UdpMediaTransportTests`: passed 9 tests.
- `swift test --filter CodeLineBudgetTests`: passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  passed outside the sandbox.
- `swift test --no-parallel` (after P0-002): passed 871 tests.
- `swift test --sanitize=thread --filter udpMediaTransportCloseCompletesWhileReceiveIsBlocking`:
  failed before test execution inside and outside the sandbox because dyld
  rejected Xcode's Thread Sanitizer runtime with `Sanitizer load violates
  platform policy`.
- `swift test --filter peerSessionRunnerStartMediaCleansUpOnPartialConnectFailure`
  (before fix): failed because `audioTransport.isClosed` remained false after
  video connect threw.
- `swift test --filter peerSessionRunnerStartMediaCleansUpOnPartialConnectFailure`
  (after fix): passed.
- `swift test --filter PeerSessionRunnerTests`: passed 5 tests.
- `swift test --filter CodeLineBudgetTests`: passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  failed inside sandbox with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside sandbox and passed.
- `swift test --no-parallel` (after P1-P2P-005): passed 872 tests.
- `swift test --filter appLatencyHeroMetricsMakeIgnoresZeroValuedMeasurements`
  (before fix): failed because zero jitter and latency were returned as `0.0`.
- `swift test --filter appLatencyHeroMetricsMakeIgnoresZeroValuedMeasurements`
  (after fix): passed.
- `swift test --filter AppShellBehaviorTests`: passed 10 tests.
- `swift test --filter CodeLineBudgetTests`: initially failed when the new
  test made `AppShellBehaviorTests.swift` 722/720 lines; passed after moving the
  test to `AppLatencyHeroMetricsTests.swift`.
- `swift test --no-parallel` (after P1-UI-003): passed 873 tests.
- `swift test --filter madiFullDuplexHandoffConfigurationPreservesSplitDeviceUIDs`
  (before fix): failed because `outputDeviceUID` was handed off as
  `"rme-madi-input"` instead of `"rme-madi-output"`.
- `swift test --filter madiFullDuplexHandoffConfigurationPreservesSplitDeviceUIDs`
  (after fix): passed.
- `swift test --filter MadiFullDuplexSessionTests`: passed 5 tests.
- `swift test --filter CodeLineBudgetTests`: passed.
- `swift build`: failed inside sandbox with `sandbox-exec: sandbox_apply:
  Operation not permitted`; rerun outside sandbox and passed.
- `swift test --no-parallel` (before refreshing stale helper binary after
  P1-MADI-001): failed with 20 stale-executable issues for
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`:
  failed inside sandbox with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside sandbox and passed.
- `swift test --no-parallel` (after P1-MADI-001 and helper refresh): passed
  874 tests.
- `bash scripts/verify-docs.sh` (after P1-MADI-001): passed.
- `git diff --check` (after P1-MADI-001): passed.
- `swift test --filter mediaClockNanosecondsClampsOverflowInsteadOfTrapping`
  (before fix): failed by exiting with signal 5 at
  `MediaClock.nanoseconds overflow`.
- `swift test --filter mediaClockNanosecondsClampsOverflowInsteadOfTrapping`
  (after fix): passed.
- `swift test --filter MediaClockTests`: passed 5 tests.
- `swift test --filter CodeLineBudgetTests`: passed.
- `swift build`: failed inside sandbox with `sandbox-exec: sandbox_apply:
  Operation not permitted`; rerun outside sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-MEDIA-001): passed outside sandbox to refresh CLI-backed tests.
- `swift test --no-parallel` (after P1-MEDIA-001): passed 875 tests.
- `bash scripts/verify-docs.sh` (after P1-MEDIA-001): passed.
- `git diff --check` (after P1-MEDIA-001): passed.
- `swift test --filter directPeerRealtimeAudioGraphFailedStopClearsRunningAndDestroysIOProc`
  (before fix): failed because `AudioDeviceDestroyIOProcID` was not attempted
  after the injected stop failure and injected capture still saw the graph as
  running.
- `swift test --filter directPeerRealtimeAudioGraphFailedStopClearsRunningAndDestroysIOProc`
  (after fix): passed.
- `swift test --filter DirectPeerRealtimeAudioGraphTests` (after P1-RT-001):
  passed 11 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphLifecycleTests` (after
  P1-RT-001): passed 1 test.
- `swift test --filter CodeLineBudgetTests` (after P1-RT-001): passed.
- `swift build` (after P1-RT-001): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-RT-001): passed outside sandbox to refresh CLI-backed tests.
- `swift test --no-parallel` (after P1-RT-001): passed 876 tests.
- `bash scripts/verify-docs.sh` (after P1-RT-001): passed.
- `git diff --check` (after P1-RT-001): passed.
- `swift test --filter lolaTcpSendRetriesPartialWritesUntilControlDatagramIsComplete`
  (before fix): failed with `socketFailed("tcp send")` after the injected send
  returned a 128-byte short write.
- `swift test --filter lolaTcpSendRetriesPartialWritesUntilControlDatagramIsComplete`
  (after fix): passed.
- `swift test --filter LoLaCompatibilityTcpControlTests` (after P1-UDP-001):
  passed 5 tests.
- `swift test --filter CodeLineBudgetTests` (after P1-UDP-001): passed.
- `swift build` (after P1-UDP-001): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-UDP-001): passed outside sandbox to refresh CLI-backed tests.
- `swift test --no-parallel` (after P1-UDP-001): passed 877 tests.
- `bash scripts/verify-docs.sh` (after P1-UDP-001): passed.
- `git diff --check` (after P1-UDP-001): passed.
- `swift test --filter peerSessionErrorDuringRecoveryFailsSessionAndClosesMediaTransports`
  (before production changes for P1-P2P-004): passed, proving current source
  already accepts a fatal current-session `.error` during recovery.
- `swift test --filter PeerSessionRunnerLifecycleTests` (after P1-P2P-004):
  passed 7 tests.
- `swift test --filter SessionProtocolTests` (after P1-P2P-004): passed 5
  tests.
- `swift test --filter CodeLineBudgetTests` (after P1-P2P-004): passed.
- `swift build` (after P1-P2P-004): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-P2P-004): passed 878 tests.
- `bash scripts/verify-docs.sh` (after P1-P2P-004): passed.
- `git diff --check` (after P1-P2P-004): passed.
- `swift test --filter peerSessionRunnerControlTranscriptIsBoundedUnderHighFrequencyMessages`
  (before fix): failed because `controlTranscript` reached 1203 entries,
  retained handshake/proposal messages, and had no cap.
- `swift test --filter peerSessionRunnerControlTranscriptIsBoundedUnderHighFrequencyMessages`
  (after fix): passed.
- `swift test --filter PeerSessionRunnerLifecycleTests` (after P1-P2P-002):
  passed 8 tests.
- `swift test --filter PeerSessionRunnerTests` (after P1-P2P-002): passed 5
  tests.
- `swift test --filter SessionProtocolTests` (after P1-P2P-002): passed 5
  tests.
- `swift test --filter CodeLineBudgetTests` (after P1-P2P-002): passed.
- `swift build` (after P1-P2P-002): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-P2P-002): passed outside sandbox to refresh CLI-backed tests.
- `swift test --no-parallel` (after P1-P2P-002): passed 879 tests.
- `bash scripts/verify-docs.sh` (after P1-P2P-002): passed.
- `git diff --check` (after P1-P2P-002): passed.
- `swift test --filter appMenuSourceDoesNotRenderUnsupportedDebugLabels`
  (before fix): failed because app source still contained `Unsupported:` and
  `unsupportedMenuAction`.
- `swift test --filter appMenuSourceDoesNotRenderUnsupportedDebugLabels`
  (after fix): passed.
- `swift test --filter appMenuRenderingFiltersFutureUnmappedActions` (after
  P1-UI-004): passed.
- `swift test --filter AppMenuRenderingTests` (after P1-UI-004): passed 2
  tests.
- `swift test --filter AppShellSlice05Tests` (after P1-UI-004): passed 22
  tests.
- `swift test --filter AppShellTransportMenuPolicyTests` (after P1-UI-004):
  passed 10 tests.
- `swift test --filter CodeLineBudgetTests` (after P1-UI-004): initially
  failed when adding the source-policy tests to `AppShellSlice05Tests.swift`
  made that file 748/720 lines; passed after moving those tests to
  `AppMenuRenderingTests.swift`.
- `swift build` (after P1-UI-004): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-UI-004): passed 881 tests.
- `bash script/build_and_run.sh --verify` (after P1-UI-004): failed inside
  sandbox with SwiftPM manifest `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside sandbox and passed, producing launch evidence under
  `dist/app-launch-evidence`.
- `bash scripts/verify-docs.sh` (after P1-UI-004): passed.
- `git diff --check` (after P1-UI-004): passed.
- `swift test --filter coreAudioInventoryReaderRestrictsRetainedStringPropertiesToDocumentedSelectors`
  (before fix): failed to compile because
  `coreAudioPropertyReturnsRetainedCFObject` did not exist.
- `swift test --filter coreAudioInventoryReaderRestrictsRetainedStringPropertiesToDocumentedSelectors`
  (after fix): passed.
- `swift test --filter CoreAudioInventoryTests` (after P1-MADI-002): passed 5
  tests.
- `swift test --filter CodeLineBudgetTests` (after P1-MADI-002): passed.
- `swift build` (after P1-MADI-002): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --sanitize=address --filter CoreAudioInventoryTests` (after
  P1-MADI-002): built the sanitized test binary but failed before executing
  tests because dyld rejected the ASan runtime with `Sanitizer load violates
  platform policy`.
- `.build/debug/open-lola device-inventory` (after P1-MADI-002): failed inside
  sandbox with `error: noDevices`; rerun outside sandbox and passed against
  built-in CoreAudio devices.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-MADI-002): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-MADI-002): passed 882 tests.
- `bash scripts/verify-docs.sh` (after P1-MADI-002): passed.
- `git diff --check` (after P1-MADI-002): passed.
- `swift test --filter rxBufferPolicyFactoriesRejectOverflowingPacketFrameProducts`
  (before fix): failed by exiting with signal 5 when an overflowing
  frames-per-packet product trapped during policy factory construction.
- `swift test --filter rxBufferPolicyFactoriesRejectOverflowingPacketFrameProducts`
  (after fix): passed.
- `swift test --filter RxBufferingTests` (after P1-RXBUF-001): passed 12
  tests.
- `swift test --filter CodeLineBudgetTests` (after P1-RXBUF-001): passed.
- `swift build` (after P1-RXBUF-001): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-RXBUF-001): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-RXBUF-001): passed 883 tests.
- `bash scripts/verify-docs.sh` (after P1-RXBUF-001): passed.
- `git diff --check` (after P1-RXBUF-001): passed.
- `swift test --filter peerSessionRunnerDoesNotReportRunningBeforePeerMediaStart`
  (before fix): failed because both peers reported `.running` immediately and
  `sendAudioPacket` returned `1` before a peer media-start message was
  processed.
- `swift test --filter peerSessionRunnerDoesNotReportRunningBeforePeerMediaStart`
  (after fix): passed.
- `swift test --filter peerSessionRunnerDoesNotReportRunningWhenPeerMediaStartArrivesBeforeLocalStart`
  (after fix): passed.
- `swift test --filter PeerSessionRunnerLifecycleTests` (after P1-P2P-001):
  passed 10 tests.
- `swift test --filter PeerSessionRunnerTests` (after P1-P2P-001): passed 5
  tests.
- `swift test --filter ReconnectionTests` (after P1-P2P-001): passed 4 tests.
- `swift test --filter PeerSessionMetricsAndControlTests` (after
  P1-P2P-001): passed 5 tests.
- `swift test --filter PeerSessionAVSupportTests` (after P1-P2P-001): passed
  10 tests.
- `swift test --filter DirectPeerSessionAVQualityPolicyTests` (after
  P1-P2P-001): passed 2 tests.
- `swift test --filter DirectPeerSessionAVRXBufferProfileTests` (after
  P1-P2P-001): passed 7 tests.
- `swift test --filter SessionProtocolTests` (after P1-P2P-001): passed 5
  tests.
- `swift test --filter CodeLineBudgetTests` (after P1-P2P-001): passed.
- `swift build` (after P1-P2P-001): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-P2P-001): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-P2P-001): passed 885 tests.
- `bash scripts/verify-docs.sh` (after P1-P2P-001): passed.
- `git diff --check` (after P1-P2P-001): passed.
- `swift test --filter DirectAudioMediaRouterTests` (before fix): failed to
  compile because `DirectAudioMediaRouterError` and the
  `localAudioCapabilities` initializer did not exist.
- `swift test --filter DirectAudioMediaRouterTests` (after P1-MADI-003):
  passed 6 tests.
- `swift test --filter PeerSessionRunnerTests` (after P1-MADI-003): passed 5
  tests.
- `swift test --filter PeerSessionRunnerLifecycleTests` (after P1-MADI-003):
  passed 10 tests.
- `swift test --filter PeerSessionAVSupportTests` (during P1-MADI-003):
  initially failed because the raw PCM router rejected an Opus stream it does
  not route; passed 10 tests after non-PCM streams were skipped by the raw PCM
  router.
- `swift test --filter CodeLineBudgetTests` (after P1-MADI-003): passed.
- `swift build` (after P1-MADI-003): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-MADI-003): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-MADI-003): passed 886 tests.
- `bash scripts/verify-docs.sh` (after P1-MADI-003): passed.
- `git diff --check` (after P1-MADI-003): passed.
- `swift test --filter directPeerRealtimeAudioGraphDeinitDoesNotAcquireLifecycleLock`
  (before fix): failed because releasing the last graph reference timed out
  while the lifecycle lock was held.
- `swift test --filter directPeerRealtimeAudioGraphDeinitDoesNotAcquireLifecycleLock`
  (after fix): passed.
- `swift test --filter DirectPeerRealtimeAudioGraphLifecycleTests` (after
  P1-RT-002): passed 2 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphTests` (after P1-RT-002):
  passed 11 tests.
- `swift test --filter CodeLineBudgetTests` (after P1-RT-002): passed.
- `swift build` (after P1-RT-002): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-RT-002): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-RT-002): passed 887 tests.
- `bash scripts/verify-docs.sh` (after P1-RT-002): passed.
- `git diff --check` (after P1-RT-002): passed.
- `swift test --filter directPeerRealtimeAudioGraphCallbackTimingAvoidsDispatchTimeNowSource`
  (before fix): failed because `DirectPeerRealtimeAudioGraph.swift` still
  contained `DispatchTime.now()` and did not contain `mach_absolute_time()`.
- `swift test --filter DirectPeerRealtimeAudioGraphTimingTests` (after
  P1-RT-003): passed 2 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphTests` (after P1-RT-003):
  passed 11 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphLifecycleTests` (after
  P1-RT-003): passed 2 tests.
- `swift test --filter CodeLineBudgetTests` (after P1-RT-003): passed.
- `swift build` (after P1-RT-003): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-RT-003): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-RT-003): passed 889 tests.
- `bash scripts/verify-docs.sh` (after P1-RT-003): passed.
- `git diff --check` (after P1-RT-003): passed.
- `swift test --filter directPeerRealtimeAudioGraphCallbackCopyAvoidsPerSampleOffsetGuardSource`
  (before fix): failed because `DirectPeerRealtimeAudioGraph.swift` still
  called `audioByteOffset(` and did not contain `audioChannelCopyPlan(`.
- `swift test --filter DirectPeerRealtimeAudioGraphTimingTests` (after
  P1-RT-004): passed 4 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphTests` (after P1-RT-004):
  passed 11 tests.
- `swift test --filter DirectPeerRealtimeAudioGraphLifecycleTests` (after
  P1-RT-004): passed 2 tests.
- `swift test --filter CodeLineBudgetTests` (after the first P1-RT-004
  implementation): failed because `DirectPeerRealtimeAudioGraph.swift` grew to
  1001/953 lines.
- `swift test --filter CodeLineBudgetTests` (after moving copy helpers into
  `DirectPeerRealtimeAudioGraphBufferCopy.swift`): passed.
- `swift build` (after P1-RT-004): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after P1-RT-004): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside
  sandbox and passed.
- `swift test --no-parallel` (after P1-RT-004): passed 891 tests.
- `bash scripts/verify-docs.sh` (after P1-RT-004): passed.
- `git diff --check` (after P1-RT-004): passed.
- `swift test --filter productionSourcesDoNotShipSyntheticPlaceholderMetricsOrManualTodoEvidence`
  (before S-P1-SLOP-001-002 fix): failed with production matches for
  `SyntheticPlaceholderMetrics` and literal `TODO(human)` evidence placeholders.
- `swift test --filter productionSourcesDoNotShipSyntheticPlaceholderMetricsOrManualTodoEvidence`
  (after S-P1-SLOP-001-002 fix): passed.
- `swift test --filter syntheticSmokeMetricsUseSourceValidationValuesInsteadOfZeroPlaceholders`:
  passed.
- `swift test --filter m07LatencyProfileSyntheticSmokeCarriesSessionProfileTelemetry`:
  passed.
- `swift test --filter SyntheticSmokeReportContractTests`: passed 3 tests.
- `swift test --filter LatencyBenchmarkReportTests`: passed 6 tests.
- `swift test --filter E2EBenchmarkReportTests`: initially failed because the
  product-scoped helper binary in `/private/tmp/open-lola2-swiftpm-build` was
  stale; after rebuilding that helper outside the SwiftPM sandbox, passed 5 tests.
- `swift test --filter HardwareValidationReportTests`: passed 7 tests.
- `swift test --filter PlaceholderDetectionTests`: passed 3 tests.
- `swift test --filter IntegratedAvRunAggregationTests`: passed 2 tests.
- `swift test --filter IntegratedProfileRunEvidenceTests`: passed 4 tests.
- `swift test --filter RealtimeAudioEngineTests`: passed 5 tests.
- `swift test --filter IntegratedProfileReportTests`: passed 4 tests after the
  test stopped assuming the old zero audio-only latency placeholder.
- `swift test --filter releaseReadinessScriptDefinesLocalVerificationMatrix`:
  passed after the release-readiness docs gate was made bytecode-clean.
- `swift test --filter CodeLineBudgetTests`: passed.
- `swift build` (after S-P1-SLOP-001-002): failed inside sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside sandbox
  and passed.
- `find Sources -type f -name '*.swift' ... -exec grep -HniE
  'SyntheticPlaceholderMetrics|todo\(human\)' {} +`: returned no production
  source matches.
- `shellcheck -x scripts/verify-release-readiness.sh`: passed.
- `bash scripts/verify-docs.sh`: passed.
- `git diff --check`: passed.
- `swift test --no-parallel` (after S-P1-SLOP-001-002): passed 892 tests after
  fixing the stale integrated-profile expectation.
- `bash scripts/verify-release-readiness.sh`: first exposed ignored generated
  live-checkout residue (`.DS_Store`, `.ruff_cache`, `.mypy_cache`,
  `scripts/verify_docs/__pycache__`) and a self-residue issue in the script's
  docs step; after deleting ignored residue and running docs with
  `PYTHONDONTWRITEBYTECODE=1`, the full release-readiness script passed with
  `source-gate-verdict: pass`, `product-runtime-verdict: partial`, and
  `VERDICT: PARTIAL`.
- `swift test --filter appSessionStateSurfaceDoesNotExposeUnbackedLiveState`
  (before S-P1-UI-001 fix): failed because `AppSessionState.allCases` still
  exposed `"Live"`.
- `swift test --filter appSessionStateSurfaceDoesNotExposeUnbackedLiveState`
  (after S-P1-UI-001 fix): passed.
- `swift test --filter AppShell`: passed 90 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P1-UI-001): passed.
- `swift build --product open-lola-app` (after S-P1-UI-001): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `bash scripts/verify-docs.sh` (after S-P1-UI-001): passed.
- `git diff --check` (after S-P1-UI-001): passed.
- `swift test --filter appConnectionTopologyAnimationRequiresPacketEvidence`
  (before S-P1-UI-002 fix): failed because `.supervisorRunning` alone returned
  true.
- `swift test --filter appConnectionTopologyAnimationRequiresPacketEvidence`
  (after S-P1-UI-002 fix): passed.
- `swift test --filter AppShell` (after S-P1-UI-002): passed 90 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P1-UI-002): passed.
- `swift build --product open-lola-app` (after S-P1-UI-002): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `bash scripts/verify-docs.sh` (after S-P1-UI-002): passed.
- `git diff --check` (after S-P1-UI-002): passed.
- `swift test --filter appValidationPreflightReportsBlockersWithTargetSections`
  (before S-P2-UI-012 fix): failed because `.evidenceIncomplete` resolved to
  the ready/green tone.
- `swift test --filter appValidationPreflightReportsBlockersWithTargetSections`
  (after S-P2-UI-012 fix): passed.
- `swift test --filter AppShell` (after S-P2-UI-012): passed 90 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-UI-012): passed.
- `swift build --product open-lola-app` (after S-P2-UI-012): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `bash scripts/verify-docs.sh` (after S-P2-UI-012): passed.
- `git diff --check` (after S-P2-UI-012): passed.
- `swift test --filter appTransportStatusToneUsesTypedExecutionPhase` (before
  S-P2-UI-001 fix): failed because `.failedToStart` and `.validationFailed`
  remained secondary while idle text containing `"failed"` turned red.
- `swift test --filter appTransportStatusToneUsesTypedExecutionPhase` (after
  S-P2-UI-001 fix): passed.
- `swift test --filter AppShell` (after S-P2-UI-001): passed 91 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-UI-001): passed.
- `rg -n "localizedCaseInsensitiveContains\\(\"fail\"\\)|contains\\(\"fail\"\\)|contains\\(\"failed\"\\)" Sources/open-lola-app/AppTransportView.swift`:
  returned no matches.
- `swift build --product open-lola-app` (after S-P2-UI-001): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `bash scripts/verify-docs.sh` (after S-P2-UI-001): passed.
- `git diff --check` (after S-P2-UI-001): passed.
- `swift test --filter appSessionBannerAccessibilityAnnouncementTargetsKeyStateTransitions`
  (before S-P2-UI-007 fix): failed because `.armed`,
  `.supervisorRunning`, and `.validated` returned nil announcement messages.
- `swift test --filter appSessionBannerAccessibilityAnnouncementTargetsKeyStateTransitions`
  (after S-P2-UI-007 fix): passed.
- `swift test --filter AppShell` (after S-P2-UI-007): passed 91 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-UI-007): passed.
- `swift build --product open-lola-app` (after S-P2-UI-007): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `bash scripts/verify-docs.sh` (after S-P2-UI-007): passed.
- `git diff --check` (after S-P2-UI-007): passed.
- `swift test --filter appExecutionModeUnavailableHelpUsesOperatorFacingCopy`
  (before S-P2-UI-008 fix): failed because the Settings help text contained
  `"runtime fallback contract"` and `"orchestration"`.
- `swift test --filter appExecutionModeUnavailableHelpUsesOperatorFacingCopy`
  (after S-P2-UI-008 fix): passed.
- `swift test --filter AppShell` (after S-P2-UI-008): passed 92 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-UI-008): passed.
- `swift build --product open-lola-app` (after S-P2-UI-008): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `bash scripts/verify-docs.sh` (after S-P2-UI-008): passed.
- `git diff --check` (after S-P2-UI-008): passed.
- `swift test --filter appPreviewWindowRequestFeedbackDoesNotClaimDisplaySuccess`
  (for S-P2-UI-011): passed before production changes, proving current source
  already reports a request-sent, not-confirmed preview-window state.
- `swift test --filter AppShell` (after S-P2-UI-011 review): passed 92 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-UI-011 review):
  passed.
- `swift build --product open-lola-app` (after S-P2-UI-011 review): failed
  inside the SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not
  permitted`; rerun outside the sandbox and passed.
- `swift test --filter externalConnectorLaunchPlansCoverUltraGridJackTripAndAvTransportPorts`
  (for S-P2-DEAD-001): passed.
- `swift test --filter ExternalConnectorSessionTests` (for S-P2-DEAD-001):
  passed 10 tests.
- `swift build --product open-lola` (for S-P2-DEAD-001): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `.build/debug/open-lola external-connector-session-run --connector mvtp-ultragrid --role tx --peer 127.0.0.1 --output /private/tmp/open-lola-ultragrid-dead-code-evidence.json --dry-run true`
  (after rebuilding `open-lola`): wrote a PARTIAL `mvtpUltraGrid` dry-run
  report.
- `.build/debug/open-lola external-connector-session-run --connector jacktrip --role tx --peer 127.0.0.1 --output /private/tmp/open-lola-jacktrip-dead-code-evidence.json --dry-run true`
  (for S-P2-DEAD-002): failed with
  `missingRequiredArgument("--peer-audio-port")`, proving the JackTrip-specific
  CLI parser path is active.
- `.build/debug/open-lola external-connector-session-run --connector jacktrip --role tx --peer 127.0.0.1 --peer-audio-port 4464 --output /private/tmp/open-lola-jacktrip-dead-code-evidence.json --dry-run true`
  (for S-P2-DEAD-002): wrote a PARTIAL `jackTrip` dry-run report.
- `swift test --filter externalConnectorLaunchPlansCoverUltraGridJackTripAndAvTransportPorts`
  (for S-P2-DEAD-002): passed.
- `swift test --filter ExternalConnectorSessionTests` (for S-P2-DEAD-002):
  passed 10 tests.
- `swift test --filter ultraGridRawVideoFourCCConstantsAvoidThrowingFileScopeInitialization`
  (before S-P2-DEPR-001 fix): failed because `UltraGridCompatibility.swift`
  still contained file-scope `try! UltraGridFourCC` constants.
- `swift test --filter ultraGridRawVideoFourCCConstantsAvoidThrowingFileScopeInitialization`
  (after S-P2-DEPR-001 fix): passed.
- `swift test --filter UltraGrid` (after S-P2-DEPR-001): passed 37 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-DEPR-001): passed.
- `swift build --product open-lola` (after S-P2-DEPR-001): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `swift test --filter reportPrimitiveValidatorTypealiasOnlyDeclarationsLiveInSubsystemValidatorFiles`
  (before S-P2-DEDUP-001 consolidation): failed because 29 exact
  typealias-only `ReportPrimitiveValidating` declarations still lived in
  scattered subsystem helper/report files.
- `swift test --filter reportPrimitiveValidatorTypealiasOnlyDeclarationsLiveInSubsystemValidatorFiles`
  (after S-P2-DEDUP-001 consolidation): passed.
- `swift test --filter ValidationPrimitivesTests` (after S-P2-DEDUP-001):
  passed 4 tests.
- `swift test --no-parallel` (first run after S-P2-DEDUP-001): failed with
  stale helper-binary errors because
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola` was older than
  product sources.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after S-P2-DEDUP-001): failed inside the SwiftPM sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside the
  sandbox and passed.
- `swift test --no-parallel` (after S-P2-DEDUP-001 helper refresh): passed 896
  tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-DEDUP-001): passed.
- `bash scripts/verify-docs.sh` (after S-P2-DEDUP-001): passed.
- `git diff --check` (after S-P2-DEDUP-001): passed after removing one extra
  EOF blank line from `LatencyBenchmarkReport.swift`.
- `rg -n "madiSyntheticRequiredChannelCounts|MadiChannelCounts" Sources/OpenLolaCore/Audio/MADI Tests/OpenLolaCoreTests`
  and `find Sources/OpenLolaCore/Audio/MADI -name MadiChannelCounts.swift`
  (after S-P2-SLOP-001): confirmed the single-file constant was deleted and the
  remaining definition lives in `MadiTransmit.swift`.
- `swift test --filter MadiTransmit` (after S-P2-SLOP-001): passed 3 tests.
- `swift test --filter MadiReceive` (after S-P2-SLOP-001): passed 7 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-SLOP-001): passed.
- `bash scripts/verify-docs.sh` (after S-P2-SLOP-001): passed.
- `git diff --check` (after S-P2-SLOP-001): passed.
- `rg -n "0\\.0\\.0-m06" Sources/OpenLolaCore` (after S-P3-SLOP-003):
  confirmed the literal now appears only at `OpenLolaCLI.implementationVersion`.
- `swift test --filter directPeerFactoriesUseCLIImplementationVersion`
  (after S-P3-SLOP-003): passed.
- `swift test --filter SessionProtocolTests` (after S-P3-SLOP-003): passed 6
  tests.
- `swift test --filter PeerSessionRunnerTests` (after S-P3-SLOP-003): passed 5
  tests.
- `swift test --filter CodeLineBudgetTests` (after S-P3-SLOP-003): passed.
- `bash scripts/verify-docs.sh` (after S-P3-SLOP-003): passed.
- `git diff --check` (after S-P3-SLOP-003): passed.
- `swift test --filter networkRouteCommandMatrixEntriesHaveExistingOwnersSourcesAndTests`
  (after S-P2-STRUCT-001): passed.
- `swift test --filter NetworkRouteCommandMatrixTests` (first run after
  S-P2-STRUCT-001): failed only because
  `/private/tmp/open-lola2-swiftpm-build/debug/open-lola` was older than product
  sources.
- `swift test --filter CodeLineBudgetTests` (after S-P2-STRUCT-001): passed.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after S-P2-STRUCT-001): failed inside the SwiftPM sandbox with
  `sandbox-exec: sandbox_apply: Operation not permitted`; rerun outside the
  sandbox and passed.
- `swift test --filter NetworkRouteCommandMatrixTests` (after S-P2-STRUCT-001
  helper refresh): passed 6 tests.
- `bash scripts/verify-docs.sh` (after S-P2-STRUCT-001): passed.
- `git diff --check` (after S-P2-STRUCT-001): passed.
- `swift test --filter SourceOwnershipInventoryTests` (baseline before
  S-P2-STRUCT-002): passed 4 tests.
- `swift test --filter SourceOwnershipInventoryTests` (after S-P2-STRUCT-002):
  passed 4 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-STRUCT-002): passed.
- `bash scripts/verify-docs.sh` (after S-P2-STRUCT-002): passed.
- `git diff --check` (after S-P2-STRUCT-002): passed.
- `swift test --filter OpenLolaContractsTargetTests` (after S-P2-STRUCT-004):
  passed 2 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-STRUCT-004): passed.
- `bash scripts/verify-docs.sh` (after S-P2-STRUCT-004): passed.
- `git diff --check` (after S-P2-STRUCT-004): passed.
- `rg -n "UdpPcmLoopbackDefaults|UdpPcmLoopbackDefaults.swift" Sources Tests plan-remediation-ledger.md plan-remediation-status.md final-plan.md`
  (after S-P2-SLOP-002): confirmed the standalone file is gone and remaining
  source references are private to `UdpPcmLoopbackSmokes.swift`.
- `swift test --filter UdpPcmLoopbackLatencyTests` (after S-P2-SLOP-002): passed
  8 tests.
- `swift test --filter SyntheticSmokeReportContractTests` (after
  S-P2-SLOP-002): passed 3 tests.
- `swift test --filter NatFriendlyRouteTests` (after S-P2-SLOP-002): passed 7
  tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-SLOP-002): passed.
- `bash scripts/verify-docs.sh` (after S-P2-SLOP-002): passed.
- `git diff --check` (after S-P2-SLOP-002): passed.
- `find Sources/OpenLolaCore/Connectors -maxdepth 2 -type f` (during
  S-P2-DEDUP-002): inventoried active connector files under Core, LoLa,
  JackTrip, NMP, and UltraGrid.
- `rg -n "P2-DEDUP-002|LaunchPlan|PassValidation|ProtocolModel|AudioPayloadCodec" final-plan.md Sources/OpenLolaCore/Connectors Tests/OpenLolaCoreTests docs`
  (during S-P2-DEDUP-002): confirmed the finding and active connector-specific
  launch, validation, protocol, codec, and test references.
- `bash scripts/verify-docs.sh` (after S-P2-DEDUP-002): passed.
- `git diff --check` (after S-P2-DEDUP-002): passed.
- `swift test --filter SPSCAtomicRingTests` (during S-P3-POLISH): passed 3
  tests.
- `swift test --filter lolaWireFrameRoundTripsRecoveredEnvelopePaddingAndVariableIPv4IDs`
  (during S-P3-POLISH): passed.
- `swift test --filter MadiReceiveTests` (during S-P3-POLISH): passed 4 tests.
- `swift test --filter PeerSessionRunnerTests` (during S-P3-POLISH): passed 5
  tests.
- `swift test --filter AppShellUIPolicyTests` (during S-P3-POLISH): passed 10
  tests.
- `swift test --filter NetworkByteReaderTests` (during S-P3-POLISH): first
  compile failed because the guarded read helpers needed explicit `return`
  statements; after fix, passed 1 test.
- `swift test --filter ExternalConnectorLoLaCompatibilityTests` (during
  S-P3-POLISH): passed 7 tests.
- `swift test --filter PeerSessionRunnerNegotiationTests` (during
  S-P3-POLISH): passed 4 tests.
- `swift test --filter MadiFullDuplexSessionTests` (during S-P3-POLISH): passed
  5 tests.
- `swift test --filter AppShell` (during S-P3-POLISH, before moving the new
  preview-output policy test): passed 93 tests.
- `swift test --filter CodeLineBudgetTests` (during S-P3-POLISH): first failed
  with `747/720 Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`; after
  moving the preview-output policy test to `AppShellUIPolicyTests.swift`, passed.
- `swift test --filter Udp` (during S-P3-POLISH): passed 62 tests, 4 skipped.
- `swift test --filter LoLaCompatibility` (during S-P3-POLISH): passed 46
  tests.
- `swift test --filter JackTripCompatibilityTests` (during S-P3-POLISH): passed
  25 tests.
- `swift test --filter UltraGridCompatibilityTests` (during S-P3-POLISH):
  passed 16 tests.
- `swift test --filter AES67ST2110L24TransportTests` (during S-P3-POLISH):
  passed 7 tests.
- `swift test --filter DirectPeerTwoPeerPrototypeReportTests` (during
  S-P3-POLISH): passed 7 tests.
- `swift test --filter RxBufferingTests` (during S-P3-POLISH): passed 12 tests.
- `swift test --filter PlaceholderDetectionTests` (during S-P3-POLISH): passed
  3 tests.
- `swift test --filter MadiFullDuplexSessionTests` (after S-P2-MADI-001):
  passed 6 tests.
- `swift test --filter CodeLineBudgetTests` (after S-P2-MADI-001): passed.
- `bash scripts/verify-docs.sh` (after S-P2-MADI-001): passed.
- `git diff --check` (after S-P2-MADI-001): passed.
- `swift build --product open-lola` (after S-P2-MADI-001): passed outside the
  SwiftPM sandbox.
- `swift build --product open-lola-app` (after S-P2-MADI-001): passed outside
  the SwiftPM sandbox.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (after S-P2-MADI-001): passed outside the SwiftPM sandbox.
- `swift test --no-parallel` (final after S-P2-MADI-001): passed 901 tests.
- `swift test --filter CodeLineBudgetTests` (final verification): passed.
- `swift test --filter AppShell` (final verification): passed 93 tests.
- `bash scripts/verify-docs.sh` (final verification): passed.
- `git diff --check` (final verification): passed.
- `swift build --product open-lola` (final verification): failed inside the
  SwiftPM sandbox with `sandbox-exec: sandbox_apply: Operation not permitted`;
  rerun outside the sandbox and passed.
- `swift build --product open-lola-app` (final verification): passed outside
  the sandbox.
- `swift test --no-parallel` (first final verification run): failed with 20
  stale-executable issues because `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`
  was older than current product sources.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build`
  (final helper refresh): passed outside the sandbox.
- `swift test --no-parallel` (after final helper refresh): passed 900 tests.

Last result:
- All non-deferred ledger rows are source/test verified, and final docs, diff,
  product builds, product-helper build, and broad Swift verification passed.
  Overall state remains `PARTIALLY_VERIFIED`, not `COMPLETE`, because the P0
  TSAN gate and external hardware/manual runtime proof remain unavailable.

Uncertainty:
- Hardware-backed CoreAudio start/stop stress with AddressSanitizer is not yet
  run for P0-001, so the slice is source-level verified but not field-proven.
- Thread Sanitizer did not execute for P0-002 because the local Xcode/macOS
  runtime rejected the TSAN dylib before tests started.
- P1-P2P-001 was verified with source-level loopback control exchange only; no
  multi-machine live P2P run was performed.
- P1-UI-002 uses decoded capture-report packets as the available packet
  evidence gate. It does not add a live packet/RMS stream.
- P1-UI-004 does not add missing menu shortcuts or alter runtime menu action
  semantics beyond filtering unsupported future actions from rendering.
- P1-MADI-001 manual hardware verification with distinct input and output
  CoreAudio UIDs was not run.
- P1-MADI-002 AddressSanitizer verification did not execute because the local
  Xcode/macOS runtime rejected the ASan dylib before tests started; the live
  inventory smoke used only built-in CoreAudio devices outside the sandbox.
- P1-RT-001 did not include a real CoreAudio device run that forces
  `AudioDeviceStop` failure; the proof is DEBUG-hook source/test evidence.
- P1-P2P-004 did not require production code changes; the new regression
  guards current behavior only.
- P1-P2P-002 keeps the existing sent-message transcript model; it does not add
  received-message history and does not address the separate concurrency-guard
  finding.
- P1-MADI-003 is source/test verified against advertised local capabilities,
  not physical CoreAudio/RME inventory. Existing production audio-graph
  preflight still owns actual CoreAudio inventory checks.
- P2-MADI-001 was split into its own ledger row because peer readiness in
  `MadiFullDuplexSocketRunner` is separate from router capability validation.
- P1-RT-002 is source/test verified with DEBUG cleanup hooks and a
  lock-contention regression. It was not verified with real CoreAudio teardown
  stress or sanitizer instrumentation.
- P1-RT-003 is source/test verified only; no real CoreAudio jitter/stress run
  or sanitizer instrumentation was performed.
- P1-RT-004 is source/test verified only; no real CoreAudio jitter/stress run
  or sanitizer instrumentation was performed. `final-plan.md` names
  `RealtimeAudioBuffers.swift`, but the live per-sample AudioBufferList copy
  validation loop was in `DirectPeerRealtimeAudioGraph.swift`.
- S-P1-SLOP-001-002 replaced synthetic zero stand-ins with deterministic
  source-validation metrics so schemas remain stable. Those values are not
  physical measurements and do not promote any synthetic report to field `PASS`.
- S-P1-UI-001 is source/test verified only. It removes the dead live UI state
  and does not add packet-received or RMS-backed live detection. The topology
  animation policy is unchanged and remains the next UI slice.
- S-P1-UI-002 is source/test verified only. It prevents animation from a bare
  supervisor start but does not introduce a live packet/RMS telemetry source.
- S-P2-UI-012 changes UI tone mapping only; validation model semantics and
  blockers are unchanged.
- S-P2-UI-001 changes status badge color policy only; it does not alter
  execution state transitions or status strings.
- S-P2-UI-007 was verified through policy tests only; no manual VoiceOver run
  was performed in the macOS app.
- S-P2-UI-008 is a copy-only UI fix; it does not change SSH runtime behavior or
  enable SSH execution mode in Settings.
- S-P2-UI-011 was verified through source/test inspection only; no manual
  macOS window-display smoke was performed.
- S-P2-DEAD-001 was verified at source/test/CLI dry-run level only; no live
  UltraGrid reference-peer interoperability run was performed.
- S-P2-DEAD-002 was verified at source/test/CLI dry-run level only; no live
  JackTrip reference-peer interoperability run was performed.
- S-P2-DEPR-001 left a separate pre-existing file-scope `try!` in
  `UltraGridProtocolModel.swift` untouched because the slice in `final-plan.md`
  scopes the crash-risk finding to `UltraGridCompatibility.swift`.
- S-P2-DEDUP-001 was source/test verified only. The first broad suite run
  failed on a stale product-scoped CLI helper and passed after rebuilding that
  helper outside the SwiftPM sandbox. No manual runtime smoke was performed.
- S-P2-SLOP-001 was source/test verified only. No manual MADI runtime or
  hardware smoke was performed because the slice only moves an internal
  synthetic matrix constant.
- S-P3-SLOP-003 was source/test verified only. This is an internal constant
  consolidation and does not change the advertised implementation version.
- S-P2-STRUCT-001 is source/test verified only. It adds a path guard for the
  existing matrix and does not restructure the docs-as-code command matrix.
- S-P2-STRUCT-002 is source/test verified only. It does not require
  `proposedSourcePath` future-placement hints to exist as current repo paths.
- S-P2-STRUCT-004 is documentation/source-comment verified only. It did not
  change alias behavior or public contract types.
- S-P2-SLOP-002 and S-P2-DEDUP-002 were missing from the ledger despite being in
  `final-plan.md`; they have been added back as remaining P2 slices.
- S-P2-SLOP-002 was source/test verified only. It was not moved to test support
  because production synthetic/NAT smoke code still uses the defaults; no live
  network route smoke was run for this file-local cleanup.
- S-P2-DEDUP-002 remains a future design/refactor risk, not a current code
  change. The remaining connector duplication may still carry maintenance cost.
- S-P2-MADI-001 proves socket-level peer readiness only; it does not provide
  physical two-peer RME MADI hardware readiness proof.
- S-P3-POLISH is source/test verified only. No physical LoLa, MADI, P2P, or
  Blackmagic output hardware proof was run for the optional polish bundle.
- P3-RXBUF-001 remains deferred because generic corrective action would change
  runtime latency/drop policy; existing direct graph and MADI paths already
  handle overruns in their own runtime-specific paths.

Next slice:
- No safe code slice remains in `final-plan.md`. Next closure step is external:
  rerun the P0 TSAN gate after the local sanitizer runtime can load, then run
  the documented hardware/manual CoreAudio, MADI, P2P, LoLa, and Blackmagic
  proof paths.
