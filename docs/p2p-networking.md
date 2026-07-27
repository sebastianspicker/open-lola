# P2P Networking

Date: 2026-05-22
Status: source-level IP/NAT preflight and UDP transport contracts implemented; physical route evidence pending
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Direct UDP, TCP, QUIC, and RTP-like references | `public standard` |
| Original open-lola UDP PCM media packet | `original open-lola design` |
| Direct UDP/direct-link as the fastest media profile; manual known-peer addresses as lab/advanced setup | `implementation hypothesis` |
| NAT traversal, relay, and compatibility modes | `compatibility requirement` |
| Packet-capture and route-labeled benchmark closure | `experimentally derived requirement` |

## Design Rule

Direct UDP over measured viable routes is the fastest media path. Normal
mac-to-mac setup first collects IP/NAT route evidence and peer reachability
classification; manual known-peer addresses and SSH are lab or advanced paths.
The native app mirrors this boundary: Mac-to-Mac is the default IP/NAT
preflight-first workflow, LoLa is a distinct external connector workflow, and
JackTrip/UltraGrid are native external connector workflows launched through the
Open LoLa `external-connector-session-run` runner.

## Transport Strategy

| Mode | Role | Default? | Reason |
|---|---|---:|---|
| Direct UDP | realtime audio and video media | yes | minimal framing, no stream head-of-line blocking, no retransmission waits |
| IP/NAT route probe | mac-to-mac connection establishment | yes | records reachability, NAT/firewall behavior, failure reasons, and whether direct UDP/IP is viable before media state is trusted |
| UDP control | optional session/control | optional | simple same-path probing and capability exchange |
| TCP | configuration and non-realtime control | optional | reliable, simple, not on media path |
| QUIC | WAN/control compatibility experiment | no | useful transport features, but extra machinery for fastest media |
| RTP-like framing | interoperability experiment | no | public standard shape, but not needed for first open-lola proof |
| Relay/forwarder | NAT fallback | no | compatibility-only and likely extra latency |
| SSH orchestration | advanced/lab fallback | no | may be blocked by institutional policy and must not be assumed or selected silently |

## App Workflow Modes

| App mode | Runtime status | Normal controls | Advanced controls |
|---|---|---|---|
| Mac-to-Mac | launchable after plan/preflight gates | workflow, peers, required device selection, validation/status | ports, buffers, Opus/CELT transport, JPEG-XS compression, report paths, SSH fallback |
| LoLa | launchable through the external LoLa connector | workflow, local/Windows endpoints, validation/status | ports, media/payload settings including AVFoundation JPEG-XS |
| JackTrip | launchable through the Open LoLa external connector runner | workflow, local/peer endpoints, validation/status | ports and report paths |
| UltraGrid | launchable through the Open LoLa external connector runner | workflow, local/peer endpoints, validation/status | ports and report paths |

The app connector launch path uses the native Open LoLa CLI runner and report
validator. It does not bundle or invoke reference `jacktrip` or `uv` binaries,
and it does not replace the separate reference-peer parity gates needed before
interoperability claims can become `PASS`.

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

## Control Replay Policy

Control v1 intentionally does not define a generic monotonically increasing
control sequence number. Replays are bounded by session-specific state instead:

- session-scoped commands carry the accepted `sessionID` and stale or wrong
  sessions are rejected;
- `mediaStart` and `shutdown` are idempotent only in states where repeating them
  is harmless;
- advisory audio metadata uses snapshot revision freshness, not transport
  ordering, to suppress duplicate local publication;
- simultaneous proposals fail closed rather than being merged or tie-broken;
- `PeerSessionRunner` has value semantics and is not internally synchronized;
  callers must serialize access through their owning task, actor, or queue.

This is not a security replay-protection scheme and must not be described as
authentication or anti-replay cryptography.

## Transport Error Handling

UDP, NAT, RTP-shaped, and direct peer paths must fail loudly:

- configuration, socket setup, protocol validation, and malformed packet
  handling throw typed errors;
- nonblocking receive helpers may return `nil` only when no packet is currently
  available;
- socket, decode, validation, and background task failures propagate to the
  caller;
- debug logging may add context, but it does not replace thrown errors;
- partial reports represent missing external evidence or environmental limits,
  not swallowed runtime failures.

## Session Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> RouteProbing: IP/NAT reachability probe
    Idle --> DirectConfigured: explicit lab/manual peer address
    Idle --> SSHFallback: explicit advanced SSH selection
    RouteProbing --> DirectConfigured: viable UDP/IP route selected
    RouteProbing --> Failed: route blocked or insufficient evidence
    DirectConfigured --> Probing: UDP media probe
    Probing --> Running: reciprocal media observed
    Probing --> Failed: no direct media path
    Failed --> Compatibility: optional NAT traversal or relay
    SSHFallback --> Probing: operator-owned remote launch
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

VERDICT: PARTIAL
