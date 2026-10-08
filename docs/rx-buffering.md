# RX buffering

Status: implemented policy and benchmark-report contracts
Verdict: PARTIAL

Receive buffering trades added latency for tolerance of network jitter and
scheduling variation. The selected policy is negotiated and reported; it may not
change silently.

## Evidence Labels

| Buffer behavior | Label |
|---|---|
| Sequence and timestamp, jitter, drift, and PLC vocabulary | `public standard` |
| Direct, Small, Adaptive, and Stable/WAN modes | `original open-lola design` |
| Device and route promotion thresholds | `experimentally derived requirement` |
| A lower target being stable on a new route | `implementation hypothesis` until measured |

## Modes

| Mode | Intent | Profile relationship |
|---|---|---|
| Direct | Minimum intentional buffering; late data is dropped | Direct Audio First only |
| Small | Fixed small target for bounded AV operation | Balanced AV or Multi-Video Performance |
| Adaptive | Bounded target adjustment from observed conditions | Multi-Video Performance |
| Stable/WAN | Continuity-first fixed target with visible latency cost | WAN Stable only |

The receiver tracks sequence continuity, packet age, jitter, occupancy, late and
incomplete blocks, underruns and overruns, concealment, drift estimate, target
changes, and added buffer duration. Adaptive policy changes stay within declared
bounds and are included in the report.

## Runtime rules

- Validate stream, format, fragment, and deadline identity before enqueue.
- Use bounded storage and deterministic eviction.
- Complete a multichannel deadline before playback, or apply the negotiated PLC
  policy.
- Keep clock-drift handling distinct from network-jitter buffering.
- Reset or reconnect without presenting stale media as current.
- Never use an adaptive increase to claim Direct Audio First performance.

The Rust station implements the audio side of this policy as a bounded
receive queue: every readable datagram is admitted (the oldest is replaced at
the depth bound), one block is presented per audio deadline, and a queue that
stays above its prefill target for about 0.7 s discards one block so a late
burst does not leave its latency behind for the rest of the session. When the
PortAudio capture ring has a block ready, that block paces the audio deadline
ahead of the wall clock, so capture, playout and the device share one clock;
the wall clock remains the fallback for receive-only sessions. A capture
backlog above two blocks is trimmed to one so a stalled session thread does
not add its stall to the capture latency.

The source includes localhost and report-level exercises of these modes. A buffer
profile passes only after repeated measurement on the claimed devices, route,
stream set, and duration. See [latency profiles](latency-profiles.md) and
[benchmark methodology](benchmark-methodology.md).

VERDICT: PARTIAL
