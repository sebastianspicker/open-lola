# RX Buffering Plan

Date: 2026-05-04  
Status: source implementation complete; physical validation pending  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Direct profile with zero or one extra block | `original open-lola design` |
| Optional profile-based RX buffers | `compatibility requirement` |
| Adaptive changes outside the audio callback | `implementation hypothesis` |
| Visible latency cost for every buffer | `experimentally derived requirement` |

## Current State

The active receive side now has explicit RX policy and telemetry contracts:

- realtime handoff can map incoming packets through an explicit RX policy target;
- late packets are dropped;
- bounded rings report dropped input and network blocks;
- fixed-target jitter handling reports packet age, drift, PLC events, late
  packets, duplicate packets, full buffers, and hidden growth;
- Direct, Small, Adaptive, and Stable/WAN policies expose min, max, target,
  packet count, microsecond cost, and fastest-eligibility fields;
- adaptive target changes are modeled outside the audio callback with
  hysteresis and bounded target-change events;
- deterministic impairment simulation reproduces whole-packet loss, fragment
  loss, duplicates, reordering, late packets, and jitter;
- `rx-buffer-benchmark-run` emits a local runtime benchmark matrix for Direct,
  Small, Adaptive, and Stable/WAN profiles;
- latency benchmark reports can carry an RX buffer impact section;
- latency benchmark reports can carry M07 session-profile telemetry for
  callback p99, route age, packet age, jitter, underruns, overruns, and added
  buffer cost;
- PASS guards reject hidden/adaptive growth in fastest paths.
- MADI RX consumes UDP PCM v2 fragments through an explicit RX policy, exposes
  ready-block latency in frames, packets, and microseconds, and reports late,
  duplicate, reordered, lost-fragment, underrun, and overrun counters.

Real hardware validation for buffered profiles is still pending.

## Buffer Modes

| Mode | Target | Bounds | Use case |
|---|---:|---:|---|
| Direct / no extra buffer | minimum latency | 0-1 packet | direct LAN, excellent P2P |
| Small RX buffer | minor jitter guard | 1-2 packets | stable LAN with occasional jitter |
| Adaptive RX buffer | unstable LAN/campus | min 1, max 4 or configured | measurable jitter variation |
| Stable/WAN buffer | continuity first | configured ms or 8-16 packets | WAN, rehearsal monitoring |

The fastest profile is eligible only for Direct unless a benchmark explicitly
labels the latency cost and removes the fastest PASS claim.

## End-to-End Buffer Policy

The M07 session policy negotiates RX buffering as part of session setup rather
than letting either peer infer buffering from packet arrival. The agreed policy
becomes part of the latency budget and is reported back through metrics.

| Negotiated policy | Accepted use | Required report fields |
|---|---|---|
| direct | Direct Audio First over direct LAN/IP | target frames, packet age, late drops |
| 16-frame playout | measured ultra-low-latency direct route | callback duration, underruns, route age |
| 8-frame experimental | lab-only lower-bound test | warning, instability counts, rollback profile |
| small fixed | Balanced AV or mild jitter guard | added microseconds, underruns, late packets |
| adaptive bounded | Multi-Video Performance or unstable LAN | target changes, hysteresis, max target |
| WAN stable | WAN continuity profile | configured target, jitter, loss, continuity |

Session-level compatibility is explicit:

- Direct Audio First accepts direct RX only.
- Balanced AV accepts small fixed RX only.
- Multi-Video Performance accepts small or adaptive RX and drops video before
  audio latency grows.
- WAN Stable accepts Stable/WAN RX only and cannot claim fastest PASS.

Audio remains the owner of the fastest path. Video, metrics, reconnect, and
control-channel work may observe RX state, but they must not change audio
playout targets inside the real-time callback.

Stale-video policy is runtime-specific, not a generic RX buffer corrective
action. `AVSyncPolicy.staleVideoDropThresholdMicroseconds` drives video sync
drops in the AV timestamp aligner; frames behind audio but still within that
threshold may render without adding audio delay. Direct P2P AV derives the
threshold from the selected frame interval so video cannot expand the audio
playout budget. MADI and realtime audio overruns stay on their own bounded
drop/telemetry policies instead of sharing a generic hidden-growth path.

The session control protocol must reject incompatible combinations such as:

- Direct Audio First with hidden adaptive buffering;
- 8-frame experimental without explicit opt-in;
- WAN Stable while claiming lowest-latency PASS;
- video queue growth that increases audio playout latency;
- receiver-side mix changes that require callback allocation.

## Direct Mode

Behavior:

- no adaptive growth;
- late packets dropped or same-deadline PLC;
- duplicate/reordered packets counted;
- playout target is 0 or 1 packet;
- no retransmission wait.

Telemetry:

- current target frames;
- late/lost/duplicate/reordered counts;
- packet age p50/p95/p99/max;
- jitter p50/p95/p99/max;
- PLC and underrun counts.

## Small RX Buffer

Behavior:

- fixed 1-2 packet target;
- no adaptive growth;
- visible latency cost in frames, microseconds, and packets;
- excluded from fastest PASS unless configured profile permits it.

Recovery:

- late packets are dropped after target;
- underruns trigger same-deadline PLC or silence;
- no hidden target increase.

## Adaptive RX Buffer

Behavior:

- adaptation runs outside the audio callback;
- target changes only within configured bounds;
- hysteresis prevents oscillation;
- packet age, jitter, late, loss, and underrun counters drive decisions;
- every target change is recorded with before/after latency.

Forbidden:

- callback-side allocation;
- callback-side locks or blocking waits;
- silent target growth;
- making adaptive mode the default fastest profile.

## Stable/WAN Buffer

Behavior:

- configured packet or millisecond target;
- prioritizes continuity over lowest latency;
- user-visible warning and report classification;
- not eligible for fastest direct audio PASS.

Use cases:

- remote monitoring;
- unstable campus path;
- WAN rehearsal where continuity is more important than playing latency.

## Drift Handling

Clock drift is not fixed by growing RX buffers in the callback. Drift handling:

- estimates sender/receiver frame slope outside the callback;
- records drift slope and correction events;
- applies correction only through precomputed policy;
- preserves profile latency accounting.

## Tests

Implemented source tests:

- direct mode late drop;
- small fixed buffer target;
- adaptive hysteresis increase/decrease;
- max-bound enforcement;
- stable/WAN latency-cost report;
- jitter simulation;
- packet loss simulation;
- underrun and overrun recovery;
- MADI RX direct late-drop, missing-fragment recovery, fixed Small-buffer
  latency, and bounded ready-block pool behavior;
- session negotiation for Direct Audio First, Balanced AV, Multi-Video
  Performance, and WAN Stable RX compatibility;
- benchmark report telemetry for callback duration, route age, packet age,
  jitter, underruns, overruns, and added buffer cost;
- RX buffer benchmark report validation for all four profile rows, visible
  target changes, and physical-evidence PASS guards;
- no fastest PASS with hidden growth.

## Resume here

Run physical RX validation: direct RME route first, then the same route under
deterministic or managed impairment for Small, Adaptive, and Stable/WAN. Keep
Direct as the fastest default unless measured evidence proves otherwise.

Local source/runtime surface:

```bash
open-lola rx-buffer-benchmark-run --output <report.json> --packets 48
open-lola validate-rx-buffer-benchmark-report <report.json>
```

This local report is useful for implementation evidence only. It remains
`PARTIAL` until every row is repeated on the same physical route with RME MADI
and accepted hardware evidence.

VERDICT: PARTIAL
