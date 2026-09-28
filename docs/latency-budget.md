# Latency budget

Status: source-level accounting model; field budgets require measurement
Verdict: PARTIAL

The latency budget makes every intentional queue and processing stage visible. It
does not assign a universal performance claim to unmeasured hardware.

## Evidence Labels

| Budget input | Label |
|---|---|
| Device latency, safety offsets, callback period, and codec timing from public APIs | `public API` |
| Network QoS, DSCP, PTP, AVB, AES67, RAVENNA, and TSN terminology | `public standard` |
| Report fields and profile eligibility | `original open-lola design` |
| Pass thresholds for a named rig | `experimentally derived requirement` |
| Unmeasured theoretical floor | `implementation hypothesis` |

## Accounted stages

Audio accounting includes capture latency and safety offset, callback and block
duration, handoff and codec work, packet assembly, sender queue age, network
time, receiver jitter and RX buffering, decode, PLC, and drift work, output
callback period, and output-device latency. Video adds capture exposure and
buffering, transform or codec work, fragmentation, reassembly, presentation
queueing, and display latency.

Control, monitoring, evidence, recording, and lighting traffic have separate
budgets. They may consume bounded resources, but they are not folded into audio
latency to hide interference.

## Reporting rules

- Report configured values separately from observed values.
- Name the device, route, sample rate, channel count, frame size, codec, profile,
  RX mode, and run duration.
- Record p50, p95, p99, and max where the source exposes enough samples; never
  derive a percentile from a single observation.
- Record loss, jitter, drift, underruns, overruns, late drops, queue depth, and
  fallback state beside latency.
- State which stages were unavailable instead of substituting estimates.

Direct operation has the lowest intentional receive buffer, but it is not
automatically the fastest passing mode. Profile semantics are in
[latency-profiles.md](latency-profiles.md), and executable evidence rules are in
[benchmark-methodology.md](benchmark-methodology.md).

VERDICT: PARTIAL
