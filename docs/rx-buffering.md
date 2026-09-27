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

The source includes localhost and report-level exercises of these modes. A buffer
profile passes only after repeated measurement on the claimed devices, route,
stream set, and duration. See [latency profiles](latency-profiles.md) and
[benchmark methodology](benchmark-methodology.md).

VERDICT: PARTIAL
