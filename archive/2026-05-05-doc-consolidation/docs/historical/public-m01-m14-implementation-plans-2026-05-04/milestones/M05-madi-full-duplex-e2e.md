# M05 MADI Full-Duplex E2E

Date: 2026-05-04  
Status: source implementation complete; physical RME E2E evidence pending  
Verdict: PARTIAL

## Objective

Run simultaneous multichannel MADI TX and RX between two peers with explicit
clock drift detection, underrun/overrun handling, metrics, and stable
full-duplex channel routing.

## Scope

In scope:

- simultaneous send and receive on the same audio device when supported;
- negotiated full-duplex audio stream pairs;
- sender and receiver frame counters;
- drift slope estimation outside the callback;
- bounded correction policy;
- full-duplex metrics reports;
- direct audio-first operation before video is enabled.

Out of scope:

- Blackmagic video;
- WAN stability profiles;
- relay mode.

## Affected Files

Expected new or changed files:

- `Sources/OpenLolaCore/MadiFullDuplexTypes.swift`
- `Sources/OpenLolaCore/MadiFullDuplexRuntime.swift`
- `Sources/OpenLolaCore/MadiFullDuplexReport.swift`
- `Sources/OpenLolaCore/MadiFullDuplexValidation.swift`
- `Sources/OpenLolaCore/MadiReceive.swift`
- `Sources/OpenLolaCore/MadiReceiveTypes.swift`
- `Sources/open-lola/MadiFullDuplexCommands.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/MadiFullDuplexSessionTests.swift`
- `docs/architecture/madi-full-rx-tx.md`
- `docs/architecture/av-sync-and-timing.md`

## Implementation Tasks

1. Added full-duplex source tests using synthetic sender and receiver clocks.
2. Modeled local and remote frame timelines with sender frame indexes, receiver
   playout frame indexes, and monotonic host timestamps.
3. Added drift estimation based on sender frame delta versus receiver playout
   frame delta.
4. Implemented bounded correction events outside the audio callback.
5. Report underruns, overruns, late drops, recovery events, drift slope, TX
   counters, RX counters, and visible RX-buffer state.
6. Added `madi-full-duplex-run` for source-level full-duplex audio reports from
   manual peer addresses.
7. Kept M05 audio full-duplex independent from video startup by rejecting
   enabled video streams for this source gate.

## Test Plan

Tests first:

- full-duplex audio session starts both TX and RX;
- channel counts are symmetric unless explicitly configured otherwise;
- sample-rate mismatch fails negotiation;
- clock drift simulation records drift and correction events;
- underrun simulation returns immediately from the callback-facing render path;
- overrun simulation drops oldest or newest according to policy;
- metrics include both TX and RX counters.

## Benchmark Plan

- one-way audio latency;
- round-trip audio latency;
- callback duration under simultaneous TX/RX;
- drift slope over 10, 30, and 60 minutes;
- underrun and overrun counts;
- max stable channel count under full-duplex load.

## Acceptance Criteria

- Two peers can run negotiated full-duplex audio in source-level tests and emit
  machine-readable reports from manual peer addresses.
- Drift is detected and reported without hidden RX buffer growth in Direct Audio
  First source smoke.
- Underruns and overruns are counted and recovered according to configured
  receive policy.
- Physical PASS requires two-peer RME evidence.

## Source Evidence

- `MadiFullDuplexAudioPair` validates symmetric source-level audio pairs and
  rejects sample-rate, sample-format, frames-per-packet, and channel-count
  mismatches unless asymmetric channel counts are explicitly allowed.
- `MadiFullDuplexSession` composes the existing `RealtimeAudioPacketHandoff`
  TX path with `MadiReceiveEngine` RX playout, so M03/M04 packet contracts stay
  authoritative.
- `MadiFullDuplexClockDriftSimulator` emits drift slope and correction events
  with `changedInsideAudioCallback == false`.
- `MadiReceiveOverrunPolicy` supports `dropNewest` and `dropOldest` behavior
  for bounded receive pools.
- `madi-full-duplex-synthetic-smoke`, `madi-full-duplex-run`, and
  `validate-madi-full-duplex-report` expose the CLI surface.

## Risks

- Correction policy can damage low-latency feel if it hides as buffer growth.
- Full-duplex device setup can differ across Core Audio drivers.

## Blockers

- M03 and M04 must supply live TX and RX paths.
- Two physical peers are required for E2E PASS.

## Rollback Plan

Allow half-duplex TX-only or RX-only diagnostic modes. If full-duplex media start
fails, shut down both media paths cleanly and keep the negotiated session state
inspectable.

## Progress Checklist

- [x] Add full-duplex synthetic tests.
- [x] Add drift simulation tests.
- [x] Implement full-duplex audio session state.
- [x] Add metrics report.
- [x] Add manual peer CLI route.
- [ ] Run one-way and round-trip audio benchmarks.
- [ ] Run two-peer physical RME proof.

## Resume Point

Resume at the physical-evidence boundary: run `madi-full-duplex-run` with the
real peer addresses for source-level report capture, then repeat with two Macs,
visible RME MADI devices, packet capture correlation, and measured one-way /
round-trip audio benchmarks before promoting M05 to `PASS`.

VERDICT: PARTIAL
