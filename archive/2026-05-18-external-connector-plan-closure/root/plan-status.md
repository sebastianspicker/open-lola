# UltraGrid and JackTrip Connector Plan Status

Updated: 2026-05-18
Source plan: `plan.md`
Goal reference: `GOAL.md`
Status: active
Verdict: PARTIAL

## Goal Alignment

This plan supports `/goal` by keeping external connector work aligned with the
root project goal: clean-room Apple Silicon native protocol/runtime surfaces,
explicit evidence boundaries, and no real-world `PASS` without measured runtime
proof.

The active connector goal is source-level remediation for Swift-native
UltraGrid/MVTP and JackTrip compatibility. Real-world closure remains blocked
until measured external peer, route, live media, and field evidence are attached
through reports.

## Current Status

- Root `plan.md` is active and backed by the deep audit in `plan-draft.md`.
- Root remediation companions are active:
  - `plan-remediation-ledger.md`
  - `plan-remediation-status.md`
- Verification trust slice is complete.
- Evidence/report contract hardening is complete for the source-level external
  connector report: observed evidence classes and missing real-world evidence
  classes are explicit.
- JackTrip DEFAULT packet correctness slice is complete for the bounded
  source-level contract: sentinels, 16-bit validation, redundancy datagram
  framing, and stop-control datagram accounting.
- JackTrip UDP runtime semantics are complete for the bounded source-level
  slice: local peer learning, redundancy recovery, sequence quality counters,
  and explicit network service-class status are reported.
- UltraGrid RTP/MVTP receive analysis is complete for the bounded source-level
  slice: RTP loss, duplicate, reorder, SSRC, timestamp, jitter-like delta, and
  raw-video reassembly failure counters are reported.
- Shared media-provider injection is complete for the bounded deterministic
  source-level slice; fixture providers prove bytes reach JackTrip and UltraGrid
  packets without claiming live-device or peer evidence.
- Reference-peer parity gate readiness is complete for the bounded opt-in
  script slice; missing peer/binary prerequisites produce machine-readable skip
  artifacts and exit `77`.
- UltraGrid generated raw-video sizing is complete for the bounded source-level
  slice; generated video uses full configured raw frames and reports payload
  byte counters.
- App and docs truthfulness is complete for this connector-contract pass;
  focused app-shell tests and docs verification passed after public contract
  updates.
- UltraGrid advanced FEC/encryption/codec/control modes remain explicitly
  unsupported and fail loud in codec tests until scoped packet evidence exists.
- JackTrip hub/TCP/auth/WebRTC/WebTransport and non-16-bit PCM modes remain
  explicitly unsupported and fail loud in codec/report tests until scoped
  packet evidence exists.
- UltraGrid NAT/server-client topology work is deferred until the direct
  reference-peer parity gate has measured evidence.
- Release hygiene now distinguishes live `/goal` remediation state from release
  artifacts: active root plan companions are allowed in the live checkout when
  complete, while release-candidate scans reject root plan artifacts.
- UltraGrid and JackTrip peer interoperability remains unproven.
- Live CoreAudio, MADI/direct-audio, AVFoundation, and measured reference-peer
  evidence remain pending.

## Counts

| Priority | Open | Partial | Done | Deferred |
| --- | ---: | ---: | ---: | ---: |
| P1 | 0 | 0 | 7 | 0 |
| P2 | 0 | 0 | 6 | 1 |

## Completed Since Plan Creation

- Created root `plan.md` from `plan-draft.md`.
- Restored the focused report-schema gate by removing unrelated private evidence
  paths from release-hardening fixtures and synthetic-smoke generation.
- Added JackTrip DEFAULT channel sentinel support:
  - `NumOutgoingChannelsToNet == 0` resolves to the incoming channel count.
  - `NumOutgoingChannelsToNet == 0xff` resolves to zero payload channels.
  - First-slice JackTrip packet validation is constrained to 16-bit PCM.
- Added JackTrip redundancy and stop-control accounting:
  - Redundancy is encoded as multiple complete DEFAULT packets concatenated in
    one UDP datagram.
  - The native runner builds bounded redundancy windows such as
    `[n, n-1, n-2]` for redundancy `3`.
  - Stop-control datagrams are counted separately instead of being silently
    hidden in receive accounting.
- Added JackTrip UDP runtime semantics:
  - Local UDP receiver tests prove peer endpoint learning from inbound source
    address and port.
  - Reports distinguish unrecovered gaps, duplicate packets, primary-packet
    reordering, and packets recovered through redundancy.
  - Reports expose network service-class status without claiming QoS or DSCP
    evidence.
- Hardened source-level connector evidence reporting:
  - External connector reports now list observed evidence classes.
  - External connector reports list missing evidence classes required before
    real-world `PASS`.
  - Fixture and validator tests cover the provenance boundary.
- Added UltraGrid RTP/MVTP receive analysis:
  - Reports expose RTP loss, duplicates, primary-packet reordering, SSRC
    changes, timestamp regressions, and jitter-like timestamp delta changes.
  - Raw-video receive analysis reports frame reassembly failures.
- Added deterministic media-provider injection:
  - JackTrip packet builders accept injected int16 audio providers.
  - UltraGrid packet builders accept injected audio/video providers.
  - Focused tests prove provider bytes reach encoded packet payloads.
- Added opt-in reference-peer parity gate readiness:
  - `scripts/run-reference-peer-parity-gate.sh` writes a machine-readable
    readiness/command-plan artifact.
  - Missing peer host, Open LoLa binary, or reference executables exit `77`
    with `VERDICT: PARTIAL`.
- Added UltraGrid generated raw-video sizing:
  - Synthetic generated frames now use the full configured byte size.
  - Reports expose audio payload, video frame payload, and RTP payload byte
    counters.
  - Focused tests cover a 640x360 RGB generated frame and expected fragment
    count.
- Rechecked app/docs truthfulness:
  - `docs/source-contracts.md` and `scripts/README.md` reflect the new
    connector runtime/report contracts.
  - Focused app-shell tests still keep JackTrip and UltraGrid planning/status
    surfaces truthful.

## Verification Snapshot

Passing:

```bash
swift test --filter ReportSchemaInventoryTests
swift test --filter JackTripCompatibilityTests
swift test --filter 'UltraGridCompatibilityTests|JackTripCompatibilityTests|ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests|ExternalConnectorReportTests|ReportSchemaInventoryTests|AppShellSlice05Tests|ReleaseHardeningTests'
bash scripts/verify-docs.sh
swift build
```

Broad gate status:

```bash
swift test --no-parallel
```

The broad Swift gate passes with 676 tests. Product status remains `PARTIAL`
because source-level verification still does not attach measured external peer,
route, live media, or field evidence.

## Next Action

Run the broad Swift suite and keep the product verdict `PARTIAL` until measured
external peer, route, live media, and field evidence exists.
