# P2P networking

Open LoLa connects to peers you configure by hand and runs a preflight before any
media starts. Localhost and manual-address direct-peer runs work in the macOS
source; physical network runs have not been validated. NAT traversal,
rendezvous, and relay are separate options you choose, never automatic.

## Evidence Labels

| Networking choice | Label |
|---|---|
| UDP sockets, IPv4, DSCP, PTP, and AVB route observations | `public standard` |
| Session JSON, endpoint sets, stream IDs, and media envelopes | `original open-lola design` |
| Physical route and reconnect thresholds | `experimentally derived requirement` |
| A direct route being the fastest usable path | `implementation hypothesis` until measured |

## Session flow

1. Resolve the local and remote peer identities and endpoints from configuration.
2. Run route, NAT, and capability preflight.
3. Exchange capabilities and propose the profile, streams, MTU, and endpoints.
4. Accept or reject the configuration before media starts.
5. Open the control, audio, video, and metrics sockets.
6. Exchange media and timing data with bounded queues.
7. Pause or stop media, request final metrics, and shut down in order.

The macOS source supports two-peer runs on localhost or manual addresses, and a
localhost all-pairs mesh probe. Mesh reports check the configuration; they do not
show that physical multi-peer media works. SSH is an optional lab mode, not
something the transport depends on.

## Transport rules

- Control never carries audio.
- Media packets carry type, stream ID, sequence and timestamp, and a bounded
  payload length.
- Receivers drop packets from unexpected sources, with bad sizes or unknown
  stream IDs, that arrive stale or late, or that belong to incomplete frames, as
  the profile dictates.
- Loss, jitter, packet age, reconnects, and shutdown appear in reports.
- Video, OSC, sACN, Art-Net, and other side traffic must not block audio.

Direct paths are not authenticated and do not protect media confidentiality or
integrity. Use trusted, isolated networks as described in
[SECURITY.md](../SECURITY.md).

## Operator notes

Host, port, role, route, and output values you enter are trusted as given. Run
the same revision on both peers, check local bind addresses and firewalls, and
keep the report from each peer. A localhost run or a zero exit code does not
show that a physical direct link works.

Open LoLa's own packet and session format is in
[open-lola-protocol.md](open-lola-protocol.md). LoLa compatibility behavior is
covered by the runtime docs and the `interop/lola2` corpus.

VERDICT: PARTIAL
