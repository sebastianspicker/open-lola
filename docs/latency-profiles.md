# Latency profiles

Status: implemented negotiation and report contracts
Verdict: PARTIAL

Profiles bind transport, receive buffering, video pressure, and evidence policy
into explicit session choices. They are compatibility and reporting contracts,
not promises that a particular device or network will pass.

## Evidence Labels

| Profile property | Label |
|---|---|
| Core Audio and AVFoundation capability inputs | `public API` |
| UDP, DSCP, PTP, and AVB route vocabulary | `public standard` |
| Profile names and compatibility rules | `original open-lola design` |
| Promotion thresholds | `experimentally derived requirement` |

## Profiles

| Profile | Compatible RX mode | Video policy | Fastest-pass eligibility |
|---|---|---|---|
| Direct Audio First | Direct | Disabled; audio only | Eligible when measured evidence passes |
| Balanced AV | Small | Bounded single/few-stream video | Not the fastest profile |
| Multi-Video Performance | Small or Adaptive | Drop video before audio degrades | Not the fastest profile |
| WAN Stable | Stable/WAN | Continuity over minimum latency | Never the fastest profile |

Negotiation rejects incompatible profile, RX, and enabled-stream combinations
before media starts. Reports record the selected profile, buffering cost,
callback and packet timing, loss, jitter and drift, underruns and overruns, and
the evidence class used for any verdict.

## Promotion rule

A profile can pass only for the exact tested device, route, stream set, codec, and
run conditions. Direct Audio First cannot pass from configuration alone, and
Balanced or WAN modes cannot be relabeled as a direct-path result. Video and
control must remain subordinate to the audio evidence gate.

RX behavior is defined in [rx-buffering.md](rx-buffering.md), budget fields in
[latency-budget.md](latency-budget.md), and measurement practice in
[benchmark-methodology.md](benchmark-methodology.md).

VERDICT: PARTIAL
