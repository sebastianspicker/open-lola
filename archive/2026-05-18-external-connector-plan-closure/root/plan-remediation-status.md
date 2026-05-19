# UltraGrid and JackTrip Connector Remediation Status

Date: 2026-05-18
Status: active
Verdict: PARTIAL

## Current State

- Root `plan.md` is active and backed by `plan-draft.md`.
- Verification trust slice is complete.
- Evidence/report contract hardening is complete for the source-level external
  connector report.
- JackTrip DEFAULT packet correctness is complete for the bounded source-level
  slice: header sentinels, 16-bit validation, redundancy datagram framing, and
  stop-control datagram accounting.
- JackTrip UDP runtime semantics are complete for the bounded source-level
  slice: peer learning, redundancy recovery, sequence counters, and explicit
  network service-class status.
- UltraGrid RTP/MVTP receive analysis is complete for the bounded source-level
  slice.
- Deterministic media-provider injection is complete for JackTrip and UltraGrid
  source-level packet builders.
- Reference-peer parity gate readiness is complete for the bounded opt-in
  script slice.
- UltraGrid generated raw-video sizing is complete for the bounded source-level
  slice.
- App and docs truthfulness is complete for this connector-contract pass.
- UltraGrid and JackTrip real-world compatibility remain `PARTIAL`.

## Completed In This Pass

- Added the canonical remediation roadmap in `plan.md`.
- Restored `ReportSchemaInventoryTests` by removing unrelated private-evidence
  triggers from the release-hardening partial and synthetic-pass fixtures and
  the matching synthetic-smoke builder.
- Added JackTrip DEFAULT channel sentinel handling:
  - `NumOutgoingChannelsToNet == 0` resolves to the incoming channel count.
  - `NumOutgoingChannelsToNet == 0xff` resolves to zero payload channels.
  - First-slice packet validation is restricted to 16-bit PCM.
- Added JackTrip redundancy datagram and stop-control accounting support:
  - UDP datagrams can encode/decode multiple complete DEFAULT packets.
  - The native runner emits redundancy windows from configured
    `jackTrip.redundancy`.
  - Receive reports include `stopControlDatagramCount`.
- Added JackTrip UDP runtime reporting:
  - Local UDP receiver coverage proves source endpoint learning.
  - Receive analysis reports redundancy recovery, unrecovered gaps, duplicate
    packets, and primary-packet reordering.
  - Network service-class status is explicit and does not claim DSCP/QoS
    evidence without route capture.
- Added source-level connector evidence provenance:
  - Reports expose observed evidence classes.
  - Reports expose missing evidence classes required for real-world `PASS`.
  - Fixture and validator coverage separates synthetic, local loopback,
    reference-peer, live-device, and field-route evidence.
- Added UltraGrid RTP/MVTP receive analysis:
  - Reports expose RTP loss, duplicates, reordering, SSRC changes, timestamp
    regressions, and jitter-like timestamp delta changes.
  - Reports expose raw-video frame reassembly failures.
- Added deterministic media-provider injection:
  - JackTrip packet builders accept injected int16 audio providers.
  - UltraGrid packet builders accept injected audio/video providers.
  - Tests prove provider bytes reach encoded packets without claiming live
    hardware or external peer success.
- Added opt-in reference-peer parity gate readiness:
  - `scripts/run-reference-peer-parity-gate.sh` writes a machine-readable
    readiness and command-plan artifact.
  - Missing prerequisites produce exit `77` and `VERDICT: PARTIAL`.
- Added UltraGrid generated raw-video sizing:
  - Generated frames use full configured raw frame byte counts.
  - Reports expose audio payload, video frame payload, and RTP payload byte
    counters.
  - Focused tests cover a 640x360 RGB generated frame.
- Rechecked app/docs truthfulness:
  - Active docs and scripts index describe the new connector runtime/report
    contracts.
  - Focused app-shell tests still preserve CLI/planning-only connector status.

## Verification

Passing checks:

```bash
swift test --filter ReportSchemaInventoryTests
swift test --filter JackTripCompatibilityTests
swift test --filter 'UltraGridCompatibilityTests|JackTripCompatibilityTests|ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests|ExternalConnectorReportTests|ReportSchemaInventoryTests|AppShellSlice05Tests|ReleaseHardeningTests'
```

Passing broad Swift check:

```bash
swift test --no-parallel
```

The broad Swift gate passed with 676 tests after line-budget exceptions were
recorded for existing oversized files and the E2E benchmark methodology
reference was aligned with `docs/benchmark-e2e-av.md`. Release hygiene allows a
complete active root plan bundle in live `/goal` checkouts and rejects root
plan artifacts from release-candidate scans.

Passing broader non-test checks:

```bash
bash scripts/verify-docs.sh
swift build
```

## Next Slice

No open connector-plan slice remains. Keep product status `PARTIAL` until
measured external peer, route, live media, and field evidence exists.
