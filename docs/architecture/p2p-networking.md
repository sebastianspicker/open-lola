# P2P Networking

Date: 2026-05-03  
Status: publication-safe transport design  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Direct UDP, TCP, QUIC, and RTP-like references | `public standard` |
| Original open-lola UDP PCM media packet | `original open-lola design` |
| Manual direct IP as the gold-standard profile | `implementation hypothesis` |
| NAT traversal, relay, and compatibility modes | `compatibility requirement` |
| Packet-capture and route-labeled benchmark closure | `experimentally derived requirement` |

## Design Rule

Direct UDP over known peer addresses is the fastest-path default. Everything
else is compatibility or control-plane work until measured otherwise.

## Transport Strategy

| Mode | Role | Default? | Reason |
|---|---|---:|---|
| Direct UDP | realtime audio and video media | yes | minimal framing, no stream head-of-line blocking, no retransmission waits |
| UDP control | optional session/control | optional | simple same-path probing and capability exchange |
| TCP | configuration and non-realtime control | optional | reliable, simple, not on media path |
| QUIC | WAN/control compatibility experiment | no | useful transport features, but extra machinery for fastest media |
| RTP-like framing | interoperability experiment | no | public standard shape, but not needed for first open-lola proof |
| Relay/forwarder | NAT fallback | no | compatibility-only and likely extra latency |

## Media Packet Requirements

The open-lola media packet is an original design. It should contain only what
the receiver needs on the deadline:

- version;
- stream kind;
- sequence number;
- sender frame index;
- nonzero sender monotonic timestamp;
- sample rate or frame rate;
- block or fragment index;
- payload length;
- payload bytes.

No proprietary packet field, byte order, grammar, or control message may be
copied into this protocol.

## Loss And Jitter

Realtime media uses sequence numbers and timestamps for detection, not recovery
waits. Audio does not retransmit on the fastest path. Video may request a later
keyframe only in an optional compressed mode, and that request must not affect
audio timing.

For raw/intra-frame video, receivers reassemble only a complete current frame.
If a newer frame starts before the older one completes, the older frame is
dropped and later fragments from it are treated as stale.

## Session Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Discovering: optional discovery
    Idle --> DirectConfigured: manual peer address
    Discovering --> DirectConfigured: peer endpoint selected
    DirectConfigured --> Probing: UDP media probe
    Probing --> Running: reciprocal media observed
    Probing --> Failed: no direct media path
    Failed --> Compatibility: optional NAT traversal or relay
    Running --> Draining: stop requested
    Draining --> Idle
```

## LAN And WAN Profiles

LAN/direct-link mode is the gold standard. Switched LAN, campus LAN, WAN, NAT,
and relay paths are separate benchmark profiles. Results from one route do not
certify another route.

## Required Benchmarks

- UDP echo RTT and estimated one-way time;
- packet age at receiver;
- jitter p50/p95/p99/max;
- loss and late packet counts;
- DSCP classification where used;
- packet capture correlation;
- CPU and allocation warnings;
- route labels and capture points.

## Resume here

Continue with [audio-rme-madi.md](audio-rme-madi.md). The first physical network
implementation remains direct two-Mac UDP audio, not NAT traversal.

VERDICT: PARTIAL
