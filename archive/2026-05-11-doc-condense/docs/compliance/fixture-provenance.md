# Fixture Provenance Register

Date: 2026-05-11
Milestone: [M04 Establish Clean-Room Requirement Translation](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M04-clean-room-requirements.md)
Status: provenance rule adopted, maintainer confirmation pending with current release blockers
Verdict: PARTIAL

## Purpose

This register records the clean-room provenance rule for test fixtures. It does
not assert legal clearance for every fixture; it defines what must be true
before fixtures can be included in a public release.

Latest local refresh: 2026-05-11.

| Report | Result | Fixture impact |
|---|---|---|
| `/private/tmp/open-lola-open-source-release-readiness-current.json` | `VERDICT: PARTIAL`; 9 requirements, 6 blockers. | Fixture provenance remains one of the six open-source release blockers. |
| `/private/tmp/open-lola-goal-completion-audit-current.json` | `VERDICT: PARTIAL`; 93 mapped items, 77 pass, 16 partial, 26 blockers. | Fixture confirmation is required for release readiness but does not close hardware/runtime/signing blockers. |

<!-- TODO(human): [Fixture provenance signoff] -> Confirm every fixture group below is synthetic/open-lola-generated, public-standard with redistribution terms, or approved measured data; otherwise exclude unclear fixtures from the release allowlist -> [include confirmed fixtures / exclude unclear fixtures / exclude all fixtures from first release] -->

## Fixture Rule

Fixtures must be one of:

- synthetic data generated from open-lola source contracts;
- public-standard examples with citation and redistribution terms;
- measured open-lola data with explicit consent, private-data review, and
  sanitization;
- excluded from public release.

Fixtures must not be copied from proprietary binaries, proprietary packet
captures, decompiled output, vendor-internal samples, venue/customer data, or
unclear sources.

## Current Inventory

Current fixture count under `Tests/OpenLolaCoreTests/Fixtures/`:

- JSON fixtures: 53
- HEX fixtures: 3
- Total fixture files: 56

C08 adds an executable fixture/CLI smoke matrix in
`Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrix.swift`,
`Sources/OpenLolaCore/Support/Inventories/FixtureSmokeMatrixData.swift`, and
`Tests/OpenLolaCoreTests/FixtureSmokeMatrixTests.swift`. That matrix checks the
live fixture tree against the counts below and verifies that every synthetic CLI
smoke command is explicitly marked synthetic-only.

| Fixture group | Count | Current provenance class | Public release posture |
|---|---:|---|---|
| `AoipEvaluationReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `CoreAudioInventory` | 2 | Synthetic/local-shape inventory fixtures. | Include only after CQ019 confirmation. |
| `DriftPlcFixedTargetCertificationReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `DriftPlcReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `EndpointLoopback` | 2 | Synthetic validation fixtures. | Include only after CQ019 confirmation. |
| `ExternalConnectorReports` | 1 | Synthetic source-level connector report. | Include only after CQ019 confirmation. |
| `FieldReadyRuntimeProofs` | 2 | Synthetic PARTIAL proof plus false-PASS guard. | Include only after CQ019 confirmation. |
| `HardwareValidationReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `IntegratedAvReports` | 2 | Synthetic PARTIAL report plus false-PASS guard. | Include only after CQ019 confirmation. |
| `IntegratedProfileReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `LatencyBenchmarkReports` | 6 | Synthetic valid/invalid validation fixtures. | Include only after CQ019 confirmation. |
| `LatencyTuningReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `LightingFixtureGateReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `LoLaParityDeferredLedgers` | 1 | Synthetic deferred parity ledger. | Include only after CQ019 confirmation. |
| `MacToMacRouteCertificationReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `MeasurementReports` | 10 | Synthetic valid/invalid measurement fixtures. | Include only after CQ019 confirmation. |
| `NativeAppShellReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `NetworkAoipCertificationReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `OscCueReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `PackagingFieldTests` | 6 | Synthetic PARTIAL report plus C09 false-PASS guards. | Include only after CQ019 confirmation. |
| `RealtimeAudioEngineReports` | 2 | Synthetic PARTIAL report plus false-PASS guard. | Include only after CQ019 confirmation. |
| `RecordingSessionArtifacts` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `ReferenceRigReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `ReleaseHardeningReports` | 2 | Synthetic PARTIAL report plus false-PASS guard. | Include only after CQ019 confirmation. |
| `RmeFastestAudioPathReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `UdpPcmPackets` | 3 | Open-lola-generated HEX packet fixtures. | Include only after CQ019 confirmation. |
| `UdpPcmRoutes` | 1 | Source-contract route fixture. | Include only after CQ019 confirmation. |
| `VideoCaptureReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |
| `VideoTransportReports` | 1 | Synthetic PARTIAL report. | Include only after CQ019 confirmation. |

## Public Release Gate

Before fixtures are included in a public release:

- CQ019 must confirm that all fixture files are synthetic, open-lola-generated,
  public-standard, or approved measured data.
- Any measured fixture must be checked for private device IDs, hostnames,
  endpoints, capture paths, venue data, and user data.
- Any unclear fixture must be excluded from the release bundle.
- The M10 review packet must include this register or an updated derivative.

## Resume Here

When adding a new fixture, add its group, count, provenance class, publication
posture, and validation owner here before relying on it for a public release or
compatibility claim.

VERDICT: PARTIAL
