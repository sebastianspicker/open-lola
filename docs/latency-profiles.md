# Latency profiles

A profile picks the transport, receive buffering, video load, and pass rules for
a session in one choice. Negotiation and reporting of profiles are implemented. A
profile does not promise that a given device or network will pass.

## Evidence Labels

| Profile property | Label |
|---|---|
| Core Audio and AVFoundation capability inputs | `public API` |
| UDP, DSCP, PTP, and AVB route vocabulary | `public standard` |
| Profile names and compatibility rules | `original open-lola design` |
| Promotion thresholds | `experimentally derived requirement` |

## Profiles

| Profile | Compatible RX mode | Video policy | Can be the fastest passing mode |
|---|---|---|---|
| Direct Audio First | Direct | Disabled; audio only | Yes, when measured evidence passes |
| Balanced AV | Small | Bounded single/few-stream video | No |
| Multi-Video Performance | Small or Adaptive | Drop video before audio degrades | No |
| WAN Stable | Stable/WAN | Continuity over minimum latency | Never |

Negotiation rejects incompatible combinations of profile, RX mode, and enabled
streams before media starts. Reports record the selected profile, buffering cost,
callback and packet timing, loss, jitter, drift, underruns and overruns, and the
evidence class behind any verdict.

## Pass rule

A profile passes only for the exact device, route, stream set, codec, and run
conditions that were tested. Direct Audio First cannot pass from configuration
alone. A Balanced or WAN run cannot be relabeled as a direct-path result. Video
and control never override the audio result.

See [rx-buffering.md](rx-buffering.md) for RX behavior,
[latency-budget.md](latency-budget.md) for budget fields, and
[benchmark-methodology.md](benchmark-methodology.md) for measurement.

VERDICT: PARTIAL
