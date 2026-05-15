# Report Schema Inventory

Date: 2026-05-05  
Status: executable C03 inventory implemented with GOAL.md codewise closure schema  
Milestone: C03  
Verdict: PARTIAL

## Purpose

This document summarizes the C03 report validator and evidence-schema inventory.
The executable source of truth is:

- `Sources/OpenLolaCore/ReportSchemaInventory.swift`
- `Sources/OpenLolaCore/ReportValidatorSurface.swift`
- `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift`

The user-facing probe is:

```bash
.build/debug/open-lola report-schema-inventory
```

Expected output is machine-readable JSON followed by:

```text
VERDICT: PARTIAL
```

`PARTIAL` is intentional. The inventory proves report ownership, validator
coverage, fixture linkage, and evidence class. It does not prove real hardware,
route, signing, clean-Mac, notarization, Gatekeeper, or benchmark readiness.

## Summary

| Scope | Count |
|---|---:|
| Report/artifact schemas | 41 |
| Validator commands mapped | 40 |
| Fixture-backed schemas | 28 |
| Schemas requiring measured evidence for PASS | 28 |
| Clean-Mac/release gate schemas | 3 |
| False-PASS regression fixtures | 9 |

## Evidence Classes

| Evidence class | Meaning |
|---|---|
| `synthetic` | Generated source-level evidence only. It cannot support real release PASS. |
| `sourceLevel` | Source contract, inventory, helper, or platform-discovery evidence. |
| `measured` | Runtime measurement evidence is required before PASS is credible. |
| `cleanMac` | Release readiness depends on signed/notarized/Gatekeeper/clean-Mac evidence. |
| `externalWitnessed` | Evidence depends on external hardware, peer, fixture, or witnessed device state. |

## Schema Map

| Schema | Family | Evidence class | Validator commands | Fixture group | PASS needs measured evidence |
|---|---|---|---|---|---|
| `ReferenceRigReport` | hardware baseline | `externalWitnessed` | `validate-reference-rig-report` | `ReferenceRigReports` | yes |
| `EndpointLoopbackReport` | audio endpoint loopback | `measured` | `validate-loopback-report` | `EndpointLoopback` | yes |
| `RmeFastestAudioPathReport` | RME fastest audio path | `externalWitnessed` | `validate-rme-fastest-audio-report` | `RmeFastestAudioPathReports` | yes |
| `RealtimeAudioEngineReport` | realtime audio engine | `measured` | `validate-realtime-audio-engine-report` | `RealtimeAudioEngineReports` | yes |
| `UdpPcmPacket` | UDP PCM packet contract | `sourceLevel` | `validate-udp-pcm-packet` | `UdpPcmPackets` | no |
| `UdpPcmRouteReport` | UDP PCM route | `measured` | `validate-route-report` | `UdpPcmRoutes` | yes |
| `MacToMacRouteCertificationReport` | Mac-to-Mac route certification | `measured` | `validate-route-certification-report` | `MacToMacRouteCertificationReports` | yes |
| `UdpPcmLoopbackReport` | UDP PCM loopback | `measured` | `validate-udp-pcm-loopback-report`, `validate-udp-pcm-loopback-session` | none | yes |
| `NetworkDiagnosticsReport` | network diagnostics | `sourceLevel` | `validate-network-diagnostics-report` | none | no |
| `NatFriendlyRouteReport` | NAT-friendly route | `measured` | `validate-nat-friendly-route-report` | none | yes |
| `DirectPeerSessionReport` | direct P2P session | `measured` | `validate-direct-p2p-session-report` | none | yes |
| `LatencyBenchmarkReport` | latency benchmark | `measured` | `validate-latency-benchmark-report` | `LatencyBenchmarkReports` | yes |
| `LatencyTuningReport` | latency tuning | `measured` | `validate-latency-tuning-report` | `LatencyTuningReports` | yes |
| `DriftPlcReport` | drift and PLC | `measured` | `validate-drift-plc-report` | `DriftPlcReports` | yes |
| `DriftPlcFixedTargetCertificationReport` | fixed-target drift PLC certification | `measured` | `validate-drift-plc-certification-report` | `DriftPlcFixedTargetCertificationReports` | yes |
| `AoipEvaluationReport` | AoIP evaluation | `measured` | `validate-aoip-report` | `AoipEvaluationReports` | yes |
| `NetworkAoipCertificationReport` | network AoIP certification | `measured` | `validate-network-aoip-certification-report` | `NetworkAoipCertificationReports` | yes |
| `VideoCaptureReport` | video capture | `externalWitnessed` | `validate-video-capture-report` | `VideoCaptureReports` | yes |
| `AVFoundationVideoDeviceInventoryReport` | video capture inventory | `sourceLevel` | `validate-video-capture-inventory` | none | no |
| `VideoTransportReport` | video transport | `measured` | `validate-video-transport-report` | `VideoTransportReports` | yes |
| `IntegratedAvReport` | integrated AV | `measured` | `validate-integrated-av-report` | `IntegratedAvReports` | yes |
| `IntegratedProfileReport` | integrated profile | `measured` | `validate-integrated-profile-report` | `IntegratedProfileReports` | yes |
| `HardwareValidationReport` | hardware validation | `externalWitnessed` | `validate-hardware-validation-report` | `HardwareValidationReports` | yes |
| `OscCueReport` | OSC cue control | `externalWitnessed` | `validate-osc-cue-report` | `OscCueReports` | yes |
| `AtemReadOnlyControlReport` | ATEM read-only control | `externalWitnessed` | `validate-atem-control-report` | none | yes |
| `LightingFixtureGateReport` | lighting fixture gate | `externalWitnessed` | `validate-lighting-gate-report` | `LightingFixtureGateReports` | yes |
| `NativeAppShellReport` | macOS app shell | `sourceLevel` | `validate-native-app-shell-report` | `NativeAppShellReports` | no |
| `NativeAppShellSurfaceProbeReport` | macOS app shell surface | `sourceLevel` | `validate-native-app-shell-surface-probe-report` | none | no |
| `RecordingSessionArtifactReport` | recording session artifacts | `sourceLevel` | `validate-recording-session-report` | `RecordingSessionArtifacts` | no |
| `PackagingFieldTestReport` | packaging field test | `cleanMac` | `validate-packaging-field-report` | `PackagingFieldTests` | yes |
| `FieldReadyRuntimeProofReport` | field-ready runtime proof | `cleanMac` | `validate-field-runtime-proof` | `FieldReadyRuntimeProofs` | yes |
| `LoLaParityDeferredLedgerReport` | LoLa parity deferred ledger | `sourceLevel` | `validate-lola-parity-deferred-ledger` | `LoLaParityDeferredLedgers` | no |
| `FasterThanLoLaClosureReport` | faster-than-LoLa closure | `measured` | `validate-faster-than-lola-closure` | none | yes |
| `GoalCodewiseClosureReport` | GOAL.md codewise closure | `sourceLevel` | `validate-goal-codewise-closure-report` | none | no |
| `ReleaseHardeningReport` | release hardening | `cleanMac` | `validate-release-hardening-report` | `ReleaseHardeningReports` | yes |
| `MadiReceiveSyntheticReport` | MADI receive | `sourceLevel` | `validate-madi-rx-report` | none | no |
| `MadiFullDuplexReport` | MADI full-duplex | `sourceLevel` | `validate-madi-full-duplex-report` | none | no |
| `PerformanceAuditReport` | performance audit | `sourceLevel` | `validate-performance-audit-report` | none | no |
| `E2EBenchmarkReport` | E2E benchmark | `measured` | `validate-e2e-benchmark-report` | none | yes |
| `CoreAudioInventoryReport` | CoreAudio inventory | `sourceLevel` | none | `CoreAudioInventory` | no |
| `MeasurementReport` | generic measurement fixture | `sourceLevel` | none | `MeasurementReports` | no |

## Test Contract

`ReportSchemaInventoryTests.swift` verifies:

- shared validator formatting for normal validators,
- report-specific extra lines such as `aggregate-verdict`,
- strict validation failures are preserved by the shared surface,
- every CLI validator command is mapped to a schema entry,
- fixture groups and synthetic smokes link to the C08 matrix,
- owner source files, validation files, and tests exist,
- summary counts match entries,
- `OpenLolaCLI.reportSchemaInventoryData()` round-trips through JSON.

## Resume Here

C03 and C05 are implemented. Continue with
[companions/C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](companions/C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md).

VERDICT: PARTIAL
