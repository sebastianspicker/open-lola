# Refactor Remediation Status

Source of truth: `docs/refactor-plan.md`
Ledger: `docs/remediation-ledger.md`

## Overall

- Overall state: COMPLETE
- Current/last slice: Final verification COMPLETE
- Highest remaining priority: None; all P0/P1/high-risk slices are COMPLETE and all remaining P3 structure/future slices are DEFERRED with reasons.
- Baseline note: `swift test --no-parallel` executed 727 Swift Testing tests and failed with 8 issues, not the plan's documented 10 pre-existing issues. The visible failures map to RP-01, RP-02, RP-03, RP-11, and RP-16.

## Counts

| Status | Count |
| --- | ---: |
| NOT_STARTED | 0 |
| IN_PROGRESS | 0 |
| BLOCKED | 0 |
| DEFERRED | 3 |
| IMPLEMENTED | 0 |
| VERIFIED | 0 |
| COMPLETE | 17 |

## Last Commands

```bash
swift test --no-parallel
swift test --filter syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass
swift test --filter ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules
swift test --filter fixtureSmokeMatrixMatchesFixtureTree
swift test --filter FixtureSmokeMatrix
swift test --filter directPeerAVAudioRXDrainMetricsDoNotDoubleCountPlayoutQueueDrops
swift test --filter directPeerAVConfigurationValidationRequiresSplitAudioDeviceUIDs
swift test --filter directPeerRealtimeAudioGraphRejectsZeroChannelInterleavedInputAndOutput
swift test --filter directPeerRealtimeAudioGraphHostTimeConversionReportsOverflowWithoutStoppingCallback
swift test --filter DirectPeerRealtimeAudioGraph
swift test --filter appExecutionValidationRejectsSecondLaunchWhileValidationIsInFlight
swift test --filter UdpPcmPacket
swift test --filter ExternalConnectorNmpPreflight
swift build
swift test --filter reportValidatorSurfaceFormatsOutputExtraLinesStrictFailuresAndJSONCoding
grep -rn "LoLaParityLedgerRunMode" Sources/ Tests/ --include="*.swift"
swift test --filter releaseAndEvidenceRunModesShareMeasurementMethodology
grep -rn "syntheticG16\|LoLaParityDeferredSyntheticSmoke" Sources/ Tests/ --include="*.swift"
swift test --filter LoLaParityDeferredFeatures
swift build
grep -r '"audioDeviceUID"' Tests/OpenLolaCoreTests/Fixtures private/ 2>/dev/null
swift test --filter directPeerRealtimeAudioGraphConfigurationRequiresSplitDeviceUIDsWhenDecoding
swift build
wc -l Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibilityPayloads.swift Tests/OpenLolaCoreTests/JackTripCompatibilityTests.swift Tests/OpenLolaCoreTests/JackTripCompatibilityTestSupport.swift
swift test --filter scopedCodeFilesStayWithinLineBudget
swift test --filter JackTrip
wc -l Sources/open-lola/Commands/MilestoneCommands.swift
rg -n "handleMilestoneCommand\|case " Sources/open-lola/Commands/MilestoneCommands.swift Tests/OpenLolaCoreTests
wc -l Sources/open-lola/Commands/Network/NetworkCommands.swift
rg -n "handleNetworkCommand\|case " Sources/open-lola/Commands/Network/NetworkCommands.swift Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift Tests/OpenLolaCoreTests/DirectPeerSessionCLITests.swift
rg -n "requireRx(Positive\|NonNegative\|NonEmpty)" Sources/OpenLolaCore/Timing Tests/OpenLolaCoreTests/RxBufferingTests.swift
swift test --filter RxBuffer
sed -n '1090,1165p' docs/refactor-plan.md
git status --short
git diff --check
git diff --stat
bash scripts/verify-docs.sh
swift build
swift test --no-parallel
```

Result:
- `swift test --no-parallel`: FAILED with 8 issues in 727 Swift Testing tests; used as drift investigation and slice selection evidence.
- `swift test --filter syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass`: PASS with 1 Swift Testing test.
- `swift test --filter ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules`: PASS with 1 Swift Testing test.
- `swift test --filter fixtureSmokeMatrixMatchesFixtureTree`: PASS with 1 Swift Testing test.
- `swift test --filter FixtureSmokeMatrix`: PASS with 4 Swift Testing tests.
- `swift test --filter directPeerAVAudioRXDrainMetricsDoNotDoubleCountPlayoutQueueDrops`: PASS with 1 Swift Testing test.
- `swift test --filter directPeerAVConfigurationValidationRequiresSplitAudioDeviceUIDs`: PASS with 1 Swift Testing test. An earlier attempt failed because the new test used the default oversized video dimensions; the test setup was corrected.
- `swift test --filter directPeerRealtimeAudioGraphRejectsZeroChannelInterleavedInputAndOutput`: PASS with 1 Swift Testing test.
- `swift test --filter directPeerRealtimeAudioGraphHostTimeConversionReportsOverflowWithoutStoppingCallback`: PASS with 1 Swift Testing test.
- `swift test --filter DirectPeerRealtimeAudioGraph`: PASS with 11 Swift Testing tests.
- `swift test --filter appExecutionValidationRejectsSecondLaunchWhileValidationIsInFlight`: PASS with 1 Swift Testing test.
- `swift test --filter UdpPcmPacket`: PASS with 4 Swift Testing tests.
- `swift test --filter ExternalConnectorNmpPreflight`: PASS with 3 Swift Testing tests.
- `swift build`: initial sandbox run failed with `sandbox_apply: Operation not permitted`; rerun outside sandbox passed.
- `swift test --filter reportValidatorSurfaceFormatsOutputExtraLinesStrictFailuresAndJSONCoding`: PASS with 1 Swift Testing test.
- `grep -rn "LoLaParityLedgerRunMode" Sources/ Tests/ --include="*.swift"`: PASS by absence; no usages remained after alias deletion.
- `swift test --filter releaseAndEvidenceRunModesShareMeasurementMethodology`: PASS with 1 Swift Testing test.
- `grep -rn "syntheticG16\|LoLaParityDeferredSyntheticSmoke" Sources/ Tests/ --include="*.swift"`: PASS by absence; no usages remained after deprecated function deletion.
- `swift test --filter LoLaParityDeferredFeatures`: PASS with 2 Swift Testing tests.
- `swift build`: initial sandbox run failed with `sandbox_apply: Operation not permitted`; rerun outside sandbox passed.
- `grep -r '"audioDeviceUID"' Tests/OpenLolaCoreTests/Fixtures private/ 2>/dev/null`: PASS by absence; no stored fixture/private JSON uses the legacy key.
- `swift test --filter directPeerRealtimeAudioGraphConfigurationRequiresSplitDeviceUIDsWhenDecoding`: PASS with 1 Swift Testing test.
- `swift build`: initial sandbox run failed with `sandbox_apply: Operation not permitted`; rerun outside sandbox passed.
- `wc -l ...JackTrip...`: PASS; `JackTripCompatibility.swift` and `JackTripCompatibilityTests.swift` are 701 lines each.
- `swift test --filter scopedCodeFilesStayWithinLineBudget`: PASS with 1 Swift Testing test.
- `swift test --filter JackTrip`: PASS with 46 Swift Testing tests.
- `wc -l Sources/open-lola/Commands/MilestoneCommands.swift`: INSPECTED; file is 610 lines and currently below the active 720-line budget.
- `rg -n "handleMilestoneCommand\|case " ...`: INSPECTED; command arms remain concentrated in one public CLI dispatcher and require a separate CLI-parity split.
- `wc -l Sources/open-lola/Commands/Network/NetworkCommands.swift`: INSPECTED; file is 380 lines and currently below the active 720-line budget.
- `rg -n "handleNetworkCommand\|case " ...`: INSPECTED; command arms remain concentrated in one public CLI dispatcher and require a separate CLI-parity split.
- `rg -n "requireRx(Positive\|NonNegative\|NonEmpty)" ...`: PASS by absence; old RxBuffer helper names are gone from the timing module and focused tests.
- `swift test --filter RxBuffer`: PASS with 12 Swift Testing tests.
- `sed -n '1090,1165p' docs/refactor-plan.md`: INSPECTED; plan says RP-20+ should begin only after RP-19 is merged and the migration pattern is confirmed clean.
- `git status --short`: INSPECTED; working tree contains a large pre-existing dirty set plus this remediation work.
- `git diff --check`: PASS; no whitespace errors.
- `git diff --stat`: INSPECTED; diff includes broader pre-existing connector/app changes as well as this remediation work.
- `bash scripts/verify-docs.sh`: PASS.
- `swift build`: initial sandbox run failed with `sandbox_apply: Operation not permitted`; rerun outside sandbox passed.
- `swift test --no-parallel`: PASS with 732 Swift Testing tests, 0 failures, 4 skipped.

## Uncertainty

- The source plan's baseline count was stale relative to the current dirty workspace; the final full suite is now green.
- The working tree had a large pre-existing dirty set before this remediation pass, including untracked connector/app/docs files. Final scope review used slice-specific diffs and verification rather than assuming the full dirty tree was created by this pass.
- RP-17 and RP-18 remain deferred because they are P3 public CLI dispatcher restructures with no active line-budget failure; RP-20+ remains deferred because the source plan requires RP-19 to be merged and reviewed first.

## Next Slice

None for this remediation pass. Deferred slices require separate PR-sized work as recorded in the ledger.
