# Fixture CLI Smoke Matrix

Date: 2026-05-04  
Status: executable source contract implemented  
Milestone: C08  
Verdict: PARTIAL

## Purpose

This matrix ties fixtures, validators, related tests, and synthetic CLI smoke
commands together before CLI router cleanup, validator deduplication, or source
movement.

The executable source of truth is:

- `Sources/OpenLolaCore/FixtureSmokeMatrix.swift`
- `Sources/OpenLolaCore/FixtureSmokeMatrixData.swift`
- `Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`

## Summary

| Scope | Count |
|---|---:|
| Fixture groups | 28 |
| Fixture files | 55 |
| JSON fixtures | 52 |
| HEX fixtures | 3 |
| Synthetic CLI smoke commands | 29 |
| High-risk false-PASS fixtures | 9 |

All fixtures remain `reviewPending` for public release until CQ019 confirms
synthetic/open-lola-generated provenance.

## Fixture Groups

| Fixture group | Files | Validator | Synthetic smoke | Related test |
|---|---:|---|---|---|
| `AoipEvaluationReports` | 1 | `validate-aoip-report` | `aoip-synthetic-smoke` | `AoipEvaluationReportTests.swift` |
| `CoreAudioInventory` | 2 | none | none | `CoreAudioInventoryTests.swift` |
| `DriftPlcFixedTargetCertificationReports` | 1 | `validate-drift-plc-certification-report` | `drift-plc-certification-synthetic-smoke` | `DriftPlcFixedTargetCertificationFixtures.swift` |
| `DriftPlcReports` | 1 | `validate-drift-plc-report` | `drift-plc-synthetic-smoke` | `DriftPlcReportTests.swift` |
| `EndpointLoopback` | 2 | `validate-loopback-report` | none | `EndpointLoopbackReportTests.swift` |
| `FieldReadyRuntimeProofs` | 2 | `validate-field-runtime-proof` | `field-runtime-synthetic-smoke` | `FieldReadyRuntimeProofTests.swift` |
| `HardwareValidationReports` | 1 | `validate-hardware-validation-report` | `hardware-validation-synthetic-smoke` | `HardwareValidationReportTests.swift` |
| `IntegratedAvReports` | 2 | `validate-integrated-av-report` | `integrated-av-synthetic-smoke` | `IntegratedAvReportTests.swift` |
| `IntegratedProfileReports` | 1 | `validate-integrated-profile-report` | `integrated-profile-synthetic-smoke` | `IntegratedProfileReportTests.swift` |
| `LatencyBenchmarkReports` | 6 | `validate-latency-benchmark-report` | `latency-benchmark-synthetic-smoke` | `LatencyBenchmarkReportTests.swift` |
| `LatencyTuningReports` | 1 | `validate-latency-tuning-report` | `latency-tuning-synthetic-smoke` | `LatencyTuningReportTests.swift` |
| `LightingFixtureGateReports` | 1 | `validate-lighting-gate-report` | `lighting-gate-synthetic-smoke` | `LightingFixtureGateTests.swift` |
| `LoLaParityDeferredLedgers` | 1 | none | `lola-parity-deferred-synthetic-smoke` | `LoLaParityDeferredFeaturesTests.swift` |
| `MacToMacRouteCertificationReports` | 1 | `validate-route-certification-report` | `route-certification-synthetic-smoke` | `MacToMacRouteCertificationTests.swift` |
| `MeasurementReports` | 10 | none | none | `MeasurementReportFixtureTests.swift` |
| `NativeAppShellReports` | 1 | `validate-native-app-shell-report` | `native-app-shell-synthetic-smoke` | `NativeAppShellTests.swift` |
| `NetworkAoipCertificationReports` | 1 | `validate-network-aoip-certification-report` | `network-aoip-certification-synthetic-smoke` | `NetworkAoipCertificationFixtures.swift` |
| `OscCueReports` | 1 | `validate-osc-cue-report` | `osc-cue-synthetic-smoke` | `OscCueReportTests.swift` |
| `PackagingFieldTests` | 6 | `validate-packaging-field-report` | `packaging-field-synthetic-smoke` | `PackagingFieldTestTests.swift` |
| `RealtimeAudioEngineReports` | 2 | `validate-realtime-audio-engine-report` | `realtime-audio-synthetic-smoke` | `RealtimeAudioEngineTests.swift` |
| `RecordingSessionArtifacts` | 1 | `validate-recording-session-report` | `recording-session-synthetic-smoke` | `RecordingSessionArtifactTests.swift` |
| `ReferenceRigReports` | 1 | `validate-reference-rig-report` | none | `ReferenceRigReportTests.swift` |
| `ReleaseHardeningReports` | 2 | `validate-release-hardening-report` | `release-hardening-synthetic-smoke` | `ReleaseHardeningTests.swift` |
| `RmeFastestAudioPathReports` | 1 | `validate-rme-fastest-audio-report` | none | `RmeFastestAudioPathTests.swift` |
| `UdpPcmPackets` | 3 | `validate-udp-pcm-packet` | none | `UdpPcmPacketTests.swift` |
| `UdpPcmRoutes` | 1 | `validate-route-report` | none | `UdpPcmRouteReportTests.swift` |
| `VideoCaptureReports` | 1 | `validate-video-capture-report` | `video-capture-synthetic-smoke` | `VideoCaptureReportTests.swift` |
| `VideoTransportReports` | 1 | `validate-video-transport-report` | `video-transport-synthetic-smoke` | `VideoTransportReportTests.swift` |

## High-Risk False-PASS Fixtures

| Fixture group | Invalid fixtures |
|---|---|
| `FieldReadyRuntimeProofs` | `field-runtime-proof-synthetic-pass.json` |
| `IntegratedAvReports` | `integrated-av-synthetic-pass.json` |
| `PackagingFieldTests` | `packaging-field-test-synthetic-pass.json`, `packaging-field-test-missing-signing.json`, `packaging-field-test-missing-notarization.json`, `packaging-field-test-missing-gatekeeper.json`, `packaging-field-test-missing-clean-mac.json` |
| `RealtimeAudioEngineReports` | `realtime-audio-engine-synthetic-pass.json` |
| `ReleaseHardeningReports` | `release-hardening-synthetic-pass.json` |

## Synthetic CLI Smoke Policy

Every command ending in `-synthetic-smoke` is listed in
`FixtureSmokeMatrix.syntheticSmokes`, marked `syntheticOnly`, and has expected
verdict `partial`. The matrix test discovers command strings from
`Sources/open-lola/*.swift` and fails if a new synthetic smoke is not listed.

The user-facing matrix probe is:

```bash
.build/debug/open-lola fixture-smoke-matrix
```

Expected output includes machine-readable JSON followed by:

```text
VERDICT: PARTIAL
```

## Resume Here

C08 is implemented. C01, C03, C05, C06, C07, C10, C11, and C12 are also implemented; see
[cli-command-inventory.md](cli-command-inventory.md) and
[report-schema-inventory.md](report-schema-inventory.md) and
[realtime-audio-path-inventory.md](realtime-audio-path-inventory.md) and
[network-route-command-matrix.md](network-route-command-matrix.md) and
[video-control-degrade-matrix.md](video-control-degrade-matrix.md). Continue with
staged source candidate inspection, license/notices decisions, or real launched
app evidence.

VERDICT: PARTIAL
