# Benchmark Methodology

Date: 2026-05-03  
Status: publication-safe benchmark contract  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Required report fields and verdict vocabulary | `original open-lola design` |
| Hardware, route, timing, and mode identity as evidence gates | `experimentally derived requirement` |
| Synthetic fixtures producing only source-shape confidence | `original open-lola design` |

## Principle

Every feature needs a test or a measurement. A benchmark that does not name the
hardware, route, mode, thresholds, and verdict is not evidence.

## Required Outputs

Every benchmark report should include:

- report ID and timestamp;
- hardware identity;
- route identity;
- sample rate, frame size, channel count, and media format;
- one-way latency estimate;
- round-trip latency where applicable;
- jitter p50/p95/p99/max;
- packet loss and late packet behavior;
- underruns and overruns;
- dropped video frames;
- CPU load;
- memory allocation warnings on realtime paths;
- thread scheduling warnings;
- verdict: `PASS`, `FAIL`, or `PARTIAL`.

## Source Contract

M02 implements these shared fields as `LatencyBenchmarkReport`. The contract
requires:

- `hardware`, `route`, and `mediaMode` identity;
- `timing.oneWayEstimateMicroseconds`, `timing.roundTripMicroseconds`, and
  jitter p50/p95/p99/max;
- packet loss, late packets, underruns, overruns, missed deadlines, and dropped
  frames;
- CPU p50/p95/p99/max, resident memory, allocation warnings, and thread
  warnings;
- explicit thresholds with a `docs/latency-budget.md` reference;
- component classifications as `criticalPath`, `nearCriticalPath`,
  `offCriticalPath`, `optional`, or `debugOnly`;
- a `PASS`, `FAIL`, or `PARTIAL` verdict.

Synthetic, built-in-device, and sandbox-limited results can validate report
shape. A physical latency `PASS` requires `measured` run mode and
`physicalReferenceRig` evidence.

M07 implements `LatencyTuningReport` on top of this shared contract for the
fastest-stable profile decision. It records a comparable candidate matrix,
excluded non-comparable route or hardware rows, selected and rollback
candidates, before/after tuning changes, and a same-hardware LoLa baseline
comparison gate. A tuning `PASS` is rejected unless the selected candidate is
the fastest stable measured physical candidate within the configured latency
thresholds.

M12 implements `IntegratedProfileReport` for the audio/video/control release
profile decision. It records the default `fastest-audio` profile, optional
video and lighting/control profiles with explicit latency cost, subordinate
evidence verdicts, degradation order, and the four required matrix rows: audio
only, audio plus video, audio plus control, and audio plus video plus control.
An integrated profile `PASS` is rejected unless every subordinate lane and every
matrix row is measured, physical, and `PASS`.

## Test Categories

| Category | Purpose |
|---|---|
| unit tests | validate models, parsers, reports, and safety guards |
| protocol tests | validate packet encoding, malformed input, sequence, and timestamps |
| audio buffer tests | validate fixed blocks, underrun/overrun accounting, and ring behavior |
| packetization tests | validate fixed-size and fragmented payload handling |
| jitter buffer tests | validate fixed playout target and late packet policy |
| clock drift tests | validate estimator and outside-callback correction |
| local loopback tests | validate machine-local timing and packet contracts |
| two-machine P2P tests | validate physical route and packet capture |
| video smoke tests | validate device inventory and capture |
| video latency tests | validate frame age, drops, and audio impact |
| lighting timing tests | validate cue timing and isolated output |
| integrated profile matrix | compare audio only, audio plus video, audio plus control, and full integrated profile |
| regression benchmarks | compare before and after every major change |

## Verdict Rules

`PASS` requires physical or otherwise scope-appropriate evidence for the claim.
Synthetic fixtures can validate source shape but cannot close hardware,
network, video, lighting, or field evidence gates.

`PARTIAL` is the correct verdict when the source contract exists but physical
evidence is missing.

## Resume here

Use the implemented benchmark contracts and fixture matrix for source-level
validation. Keep hardware, route, video, lighting, and field claims `PARTIAL`
until measured evidence exists.

VERDICT: PARTIAL
