# Open Lola Benchmark Roadmap 2026

Back to companion: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Date: 2026-05-02  
Status: internal research ledger, current after public background-lane restructure
Evidence: [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md)
Verdict: PARTIAL

## Hard Rule

No benchmark may pass if the tested feature increases default audio playout
latency. Video, lighting, UI, recording, QoS, codec, PLC, and retransmission
features must be rejected, deferred, or moved to fallback mode when they require
larger audio buffers.

## Acceptance Model

Every benchmark report must separate:

- endpoint audio latency;
- network packet timing;
- playout target;
- callback deadline behavior;
- video frame age where applicable;
- lighting cue jitter where applicable;
- CPU/GPU/network interference;
- configuration and hardware identity.

Report p50, p95, p99, max, loss/drop counts, and whether the result changes the
default audio playout target.

## Gate 0: Measurement Rig

| Acceptance criterion | Required evidence |
|---|---|
| Device identity is stable | Interface, sample rate, channels, driver, clock domain. |
| Loopback method is repeatable | Analog loopback wiring, calibration, and raw capture. |
| Packet timing is observable | Sender/receiver timestamps and packet capture. |
| Reports are comparable | Same units, same route labels, same hardware labels. |

## Gate 1: Core Audio Fastest Lane

| Acceptance criterion | Required evidence |
|---|---|
| Accepted frame size is verified | Requested and accepted 16/32/64/128 frame results. |
| Callback is deadline-safe | p99/max callback duration and missed deadline count. |
| Reported latency is logged | Device, stream, and safety-offset values where available. |
| Analog latency is measured | Loopback round-trip and corrected one-way estimate. |
| No hidden growth | 30-minute run with fixed playout target. |

Pass condition: stable audio at the selected frame size with no buffer growth
and no unbounded callback work.

## Gate 2: UDP PCM Mac-To-Mac

| Acceptance criterion | Required evidence |
|---|---|
| One packet per audio block | Packet captures and sequence counters. |
| Fixed receive target | Zero/one-block target shown in logs and report. |
| Late packets do not block | Late/drop counters plus callback timing. |
| Packet format is validated | Header guard/CRC, sample rate, channels, frame count. |
| Route is characterized | Loss, jitter, p99/max, reordering, DSCP state. |

Pass condition: direct UDP PCM stays within the selected playout target on a
certified wired path.

## Gate 3: PLC And Drift

| Acceptance criterion | Required evidence |
|---|---|
| PLC does not add latency | Same playout target before and after PLC. |
| PLC is bounded | p99/max CPU time per block for silence, repeat, Burg/AR, and any ML candidate. |
| Drift is visible | Sender/receiver frame-index and clock-drift telemetry. |
| Resampling is bounded | CPU cost and artifact report outside callback if used. |

Pass condition: artifact reduction improves without changing default latency.

## Gate 4: Network Timing And Interop

| Acceptance criterion | Required evidence |
|---|---|
| DSCP/QoS classification | Honored, rewritten, ignored, or harmful per route. |
| PTP profile is explicit | Version, profile, domain, master, lock state. |
| AVB/TSN/WCRT is stressed | Worst-case load tests with competing traffic. |
| AES67/RAVENNA/Dante is isolated | Endpoint latency and clocking compared with direct UDP PCM. |

Pass condition: deterministic or professional-AoIP modes are labeled correctly
and do not replace the direct fastest baseline without measured superiority.

## Gate 5: Video

| Acceptance criterion | Required evidence |
|---|---|
| AVFoundation capture is bounded | Frame age, drop count, callback timing, CPU load. |
| VideoToolbox is isolated | Realtime settings, queue depth, frame reordering, audio p99/max under load. |
| JPEG XS/UltraGrid are comparable | Glass-to-glass latency and resource contention report. |
| Video degrades first | Test showing frame drop/quality reduction before audio buffer growth. |

Pass condition: video improves presence/cueing while audio timing remains
unchanged.

## Gate 6: Lighting And Show Control

| Acceptance criterion | Required evidence |
|---|---|
| OSC cue timing is measured | Send/receive timestamps and cue jitter. |
| sACN/Art-Net are isolated | One-universe OLA/QLC+ probes and network capture. |
| Standards gates are closed | Full standard/version/clause notes before direct implementation. |
| Fixture metadata is offline | OFL import/validation runs outside realtime lanes. |
| Tracking streams are independent | OpenFollow/PSN/OTP timestamps mapped without audio dependency. |

Pass condition: lighting/control functions without changing audio callback
timing, packet timing, or playout target.

## Report Verdicts

Each benchmark report should end with exactly one verdict:

- `VERDICT: PASS` when the feature meets its gate and preserves default audio
  latency.
- `VERDICT: FAIL` when the feature violates the hard rule or gate criteria.
- `VERDICT: PARTIAL` when evidence is useful but incomplete.
