# RX buffering

In code today: the macOS runtime implements and reports all four RX modes, and
the Rust station has a bounded audio receive queue. Both have run on localhost
only; no mode has been measured on real devices and routes.

A receive buffer trades latency for tolerance of jitter. The mode is negotiated
and reported, and never changes silently.

## Evidence Labels

| Buffer behavior | Label |
|---|---|
| Sequence and timestamp, jitter, drift, and PLC vocabulary | `public standard` |
| Direct, Small, Adaptive, and Stable/WAN modes | `original open-lola design` |
| Device and route promotion thresholds | `experimentally derived requirement` |
| A lower target being stable on a new route | `implementation hypothesis` until measured |

## Modes

| Mode | Intent | Used by profile |
|---|---|---|
| Direct | Minimum intentional buffering; late data is dropped | Direct Audio First only |
| Small | Fixed small target for bounded AV operation | Balanced AV or Multi-Video Performance |
| Adaptive | Target adjusts within bounds from observed conditions | Multi-Video Performance |
| Stable/WAN | Fixed target that favours continuity, with visible latency cost | WAN Stable only |

The receiver tracks sequence gaps, packet age, jitter, occupancy, late and
incomplete blocks, underruns and overruns, concealment, drift estimate, target
changes, and the buffer duration it adds. Adaptive changes stay within declared
bounds and appear in the report.

On macOS, adaptive audio uses the p99 of the latest 128 changes in interarrival
delay. Using differences cancels the offset between the peer and local clocks.
Transport jitter is tracked separately as a smoothed value.

## Runtime rules

- Check stream, format, fragment, and deadline identity before enqueueing.
- Use bounded storage and deterministic eviction.
- Complete a multichannel deadline before playback, or apply the negotiated PLC
  policy.
- Handle clock drift separately from network jitter buffering.
- After a reset or reconnect, never play stale media as current.
- Never use an adaptive increase to claim Direct Audio First performance.

## Rust station audio queue

The queue is measured in local-device frames.

- Valid peer packets are combined or split into one local block per audio
  deadline. Queue depth and prefill count local blocks, so a different peer
  packet size does not change the playback rate.
- At least one peer packet is kept even when it is larger than the queue depth.
- At the depth limit, the oldest samples are overwritten.
- If the queue stays above its prefill target for about 0.7 s, one block is
  discarded, so a late burst does not add latency for the rest of the session.
- When the PortAudio capture ring has a block ready, that block sets the audio
  deadline instead of the wall clock. Capture, playout, and the device then share
  one clock. Receive-only sessions fall back to the wall clock.
- A capture backlog above two blocks is trimmed to one, so a stalled session
  thread does not add its stall to capture latency.

A buffer profile passes only after repeated measurement on the claimed devices,
route, stream set, and duration. See [latency profiles](latency-profiles.md) and
[benchmark methodology](benchmark-methodology.md).

VERDICT: PARTIAL
