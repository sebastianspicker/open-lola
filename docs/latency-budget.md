# Latency budget

The latency budget lists every queue and processing stage so each one's cost is
visible. It is an accounting model for reports; it makes no performance claim for
hardware that has not been measured.

## Evidence Labels

| Budget input | Label |
|---|---|
| Device latency, safety offsets, callback period, and codec timing from public APIs | `public API` |
| Network QoS, DSCP, PTP, AVB, AES67, RAVENNA, and TSN terminology | `public standard` |
| Report fields and profile eligibility | `original open-lola design` |
| Pass thresholds for a named rig | `experimentally derived requirement` |
| Unmeasured theoretical floor | `implementation hypothesis` |

## Stages

Audio stages, in order:

1. capture latency and safety offset;
2. callback and block duration;
3. handoff and codec work;
4. packet assembly and sender queue age;
5. network time;
6. receiver jitter and RX buffering;
7. decode, PLC, and drift correction;
8. output callback period and output device latency.

Video adds capture exposure and buffering, transform or codec work,
fragmentation, reassembly, presentation queueing, and display latency.

Control, monitoring, reports, recording, and lighting traffic each have their own
budget. They may use bounded resources, but their cost is never folded into audio
latency where it would hide interference.

## Reporting rules

- Report configured values separately from observed values.
- Name the device, route, sample rate, channel count, frame size, codec, profile,
  RX mode, and run duration.
- Record p50, p95, p99, and max when there are enough samples. Never derive a
  percentile from a single observation.
- Record loss, jitter, drift, underruns, overruns, late drops, queue depth, and
  fallback state next to latency.
- Say which stages could not be measured instead of filling in estimates.

Direct mode has the smallest intentional receive buffer, but it is not
automatically the fastest mode that passes. See
[latency-profiles.md](latency-profiles.md) for profiles and
[benchmark-methodology.md](benchmark-methodology.md) for measurement rules.

VERDICT: PARTIAL
