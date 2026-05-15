# F04 Audio Drift PLC And Benchmark

Date: 2026-05-03
Status: required long-run audio proof
Verdict: PARTIAL

## Finding

The current drift/PLC source layer validates same-deadline policy and report
shape, but it has not run the required long physical route proof. The closure
path needs a 60-minute fixed-target run, same-deadline concealment, no adaptive
jitter growth, and a measured LoLa baseline comparison.

## Current Surface

- [../../Sources/OpenLolaCore/DriftPlcReport.swift](../../Sources/OpenLolaCore/DriftPlcReport.swift)
  validates drift and PLC reports.
- [../../Sources/OpenLolaCore/DriftPlcFixedTargetCertification.swift](../../Sources/OpenLolaCore/DriftPlcFixedTargetCertification.swift)
  enforces fixed-target certification with accepted F02 realtime-engine source
  evidence, accepted F03 route evidence, packet-mode/route parity, and a
  measured LoLa baseline comparison.
- `open-lola drift-plc-run` builds a certification report from an accepted
  route report.

## Required Runtime Proof

- F01 RME MADI mode accepted.
- F02 measured realtime engine accepted or explicitly included as the engine
  under test.
- F03 direct P2P route accepted.
- F11 byte-exact UDP PCM loopback and network diagnostics recorded for the same
  route, with ICMP RTT treated only as comparison evidence.
- Duration at least 60 minutes.
- Drift correction happens outside the callback.
- PLC is silence, repeat, or another same-deadline policy that cannot wait for
  future packets.
- Adaptive jitter growth is disabled for the fastest path.

## Benchmark Requirement

The LoLa baseline must be measured on the chosen baseline hardware or recorded
as unavailable with a concrete reason. Do not compare against a remembered
number or synthetic fixture.

Required ledger fields:

- LoLa version and settings;
- audio interface and route;
- sample rate, frame size, and channel count;
- one-way or round-trip measurement method;
- p50/p95/p99/max latency;
- loss, late packets, underruns, and artifacts;
- whether open-lola beats, matches, or trails the baseline.

## PASS Criteria

- 60-minute run has no hidden playout growth.
- Source realtime-engine report is accepted and points at the same accepted
  route certification.
- Fixed playout target is unchanged from start to finish.
- PLC never increases latency.
- Audio artifacts are recorded with timestamps and packet evidence.
- LoLa comparison is measured on the same hardware, route, and packet mode, and
  shows LoLa-class or faster behavior.

## Resume here

After F02 realtime-engine PASS and F03 direct-route PASS, run the 60-minute
drift/PLC proof. Run F11 loopback diagnostics before the long proof so the
route has UDP echo RTT, ICMP RTT, and hop evidence. Create the measured LoLa
benchmark ledger needed by [F10_FASTER_THAN_LOLA_CLOSURE.md](F10_FASTER_THAN_LOLA_CLOSURE.md).

VERDICT: PARTIAL
