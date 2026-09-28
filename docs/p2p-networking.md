# P2P networking

Status: source and localhost direct-peer paths implemented; field proof open
Verdict: PARTIAL

Open LoLa uses explicit peer configuration and preflight before direct media
execution. Direct-peer operation is preferred where the route and evidence
support it; NAT, rendezvous, and relay behavior remain separate, visible choices.

## Evidence Labels

| Networking choice | Label |
|---|---|
| UDP sockets, IPv4, DSCP, PTP, and AVB route observations | `public standard` |
| Session JSON, endpoint sets, stream IDs, and media envelopes | `original open-lola design` |
| Physical route and reconnect thresholds | `experimentally derived requirement` |
| A direct route being the fastest usable path | `implementation hypothesis` until measured |

## Session flow

1. Resolve explicit local and remote peer identities and endpoints.
2. Run route, NAT, and capability preflight.
3. Exchange capabilities and propose the session profile, streams, MTU, and
   endpoint set.
4. Accept or reject the configuration before media starts.
5. Start control, audio, video, and metrics sockets at explicit boundaries.
6. Exchange bounded media and timing observations.
7. Pause or stop media, request final metrics, and shut down in order.

The macOS source supports localhost and manual-address two-peer runs plus a
localhost all-pairs mesh probe. Mesh topology reports validate configuration;
they do not prove physical multi-peer media. SSH is an explicit advanced lab
execution mode, not an implicit transport dependency.

## Transport rules

- Control does not carry audio media.
- Media packets carry type, stream identity, sequence and timestamp information,
  and bounded payload length.
- Receivers reject unexpected sources, malformed sizes, unsupported stream
  identities, stale or late data, and incomplete frames according to policy.
- Loss, jitter, packet age, reconnect, and shutdown are visible in reports.
- Video, OSC, sACN, Art-Net, and other auxiliary work must not block audio.

Current direct paths are not authenticated and provide no media confidentiality
or integrity. Use trusted, isolated networks as required by
[SECURITY.md](../SECURITY.md).

## Operator boundary

Manual host, port, role, route, and output values are trusted configuration. Run
matching revisions, verify local bind addresses and firewalls, and preserve the
report from each peer. A successful localhost run or a process exit of zero does
not establish a physical direct-link result.

Open LoLa's own packet and session contracts are in
[open-lola-protocol.md](open-lola-protocol.md). LoLa compatibility behavior is
owned by the runtime component docs.

VERDICT: PARTIAL
