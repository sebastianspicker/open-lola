# Audio Latency Benchmark Methodology

Date: 2026-05-04  
Status: source methodology and RX simulation implemented; physical evidence pending  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Analog loopback and two-machine P2P as acceptance evidence | `experimentally derived requirement` |
| Synthetic smokes as source-shape evidence only | `original open-lola design` |
| RME MADI hardware gate for fastest PASS | `implementation hypothesis` |
| Critical-path allocation checks | `experimentally derived requirement` |

## Measurement Matrix

Every benchmark row must name:

- hardware identity;
- Core Audio device UID and channel layout;
- driver and firmware evidence where available;
- sample rate;
- frames per buffer;
- channel count;
- sample format;
- latency profile;
- RX buffer profile;
- route kind and packet-capture point;
- duration and acceptance threshold;
- verdict.

## Required Benchmarks

| Benchmark | Purpose |
|---|---|
| local loopback latency | confirm device/callback/packet path on one Mac |
| two-machine P2P latency | confirm real network packet age and jitter |
| jitter distribution | p50/p95/p99/max route behavior |
| underrun count | prove audio continuity for selected profile |
| dropped packet count | quantify loss and late drops |
| CPU load | p50/p95/p99/max scheduling risk |
| critical-path allocation | prove no callback allocation warnings |
| max stable channel count | find stable channel count at 8/16/32/64 frames |
| RX buffer latency impact | measure direct, small, adaptive, stable/WAN cost |

## Local Loopback

Local loopback validates code shape and hardware mode:

1. capture Core Audio inventory;
2. run endpoint loopback across 8/16/32/64/128 frames where supported;
3. record callback p50/p95/p99/max and deadline misses;
4. record underruns, overruns, allocation warnings, and hidden buffers;
5. attach analog loopback when physical PASS is claimed.

The endpoint loopback source contract now requires 8/16/32/64/128 frame rows
for every supported sample rate. Rejected 8-frame rows are valid when the device
or evidence does not support them; PASS with 8 frames requires longer physical
stability evidence.

## Two-Machine P2P

Two-machine P2P validates the route:

1. use direct wired route first;
2. record sender/receiver host identity and interface;
3. capture packet age, jitter, loss, reordering, and DSCP behavior;
4. compare audio-only route against audio plus video/control loads;
5. reject PASS if video/control changes audio latency.

## Multichannel Matrix

Run the matrix for:

- 2, 8, 16, 32, 64, and max stable channels;
- 8, 16, 32, 64, and 128 frames where accepted;
- `float32LittleEndian` and explicit `int16LittleEndian` bandwidth profile;
- v1 stereo fallback and v2 fragmented transport.

## RX Buffer Impact

For every RX profile report:

- target frames;
- min/max frames;
- current frames over time;
- p50/p95/p99/max packet age;
- p50/p95/p99/max jitter;
- late/lost/duplicate/reordered packet counts;
- underruns, overruns, PLC events;
- drift slope;
- added latency in frames and microseconds.

The source benchmark model now carries RX impact fields and deterministic
impairment summaries. `rx-buffer-benchmark-run` exercises the local RX policy
runtime for Direct, Small, Adaptive, and Stable/WAN rows, but it is still
single-machine implementation evidence. PASS still requires physical hardware
and route evidence.

## Acceptance

PASS requires:

- measured physical run for the claimed hardware and route;
- no hidden buffers;
- no callback allocation warnings;
- no blocking callback operations;
- no audio impact from video or lighting;
- selected profile is fastest stable for the stated objective;
- machine-readable `VERDICT: PASS`.

Synthetic, built-in-device, or incomplete hardware rows remain `PARTIAL`.

For 16-frame or 8-frame claims, reports must also attach
`LatencyProfileEvidence` with opt-in state, warning acknowledgement where
required, rollback profile, max stable channel count, and physical RME/direct
route benchmark status. Missing or insufficient profile evidence rejects PASS.

## Resume here

Run the physical low-buffer and RX impact matrix before accepting 16-frame,
8-frame, or adaptive RX claims: 8/16/32/64/128 frames and Direct, Small,
Adaptive, and Stable/WAN on identical RME/direct and impaired-route conditions.

VERDICT: PARTIAL
