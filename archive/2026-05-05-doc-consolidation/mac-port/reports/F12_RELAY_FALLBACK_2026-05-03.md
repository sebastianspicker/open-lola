# F12 Relay Fallback Validation Report

Date: 2026-05-03
Companion: [F12 NAT ISP Friendly Route](../implementation-companions/F12_NAT_ISP_FRIENDLY_ROUTE.md)
Status: PARTIAL

## Scope

This report validates the source-level self-hosted UDP relay fallback for F12.
The relay is not a fastest path. It is compatibility evidence only, and it is
used by `nat-friendly-route-run` only after a direct traversal candidate exists
and the direct traversal attempt fails.

The localhost smoke intentionally forces direct traversal to a closed UDP
endpoint before the clients register with the relay. That proves fallback
ordering in code. It does not prove ISP/NAT reachability between two physical
sites.

## Commands

```bash
swift test --filter NatFriendlyRoute

.build/debug/open-lola nat-relay-fallback-localhost-smoke
```

The standalone self-hosted relay surface is:

```bash
.build/debug/open-lola nat-rendezvous-forwarder-run --bind-host <ip> --rendezvous-port <port> --forwarder-port <port> --session-id <id> --expected-peers 2 --timeout-seconds <n> --output <path>

.build/debug/open-lola nat-relay-run --bind-host <ip> --port <port> --session-id <id> --expected-peers 2 --timeout-seconds <n> --output <path>

.build/debug/open-lola nat-friendly-route-run --role sender --bind-host <ip> --peer-id <sender-id> --rendezvous-host <ip> --rendezvous-port <port> --relay-host <ip> --relay-port <port> --session-id <id> --port <local-udp-port> --duration-seconds <n> --raw-rtt-microseconds <us> --output <path>

.build/debug/open-lola nat-friendly-route-run --role looper --bind-host <ip> --peer-id <looper-id> --rendezvous-host <ip> --rendezvous-port <port> --relay-host <ip> --relay-port <port> --session-id <id> --port <local-udp-port> --duration-seconds <n> --raw-rtt-microseconds <us> --output <path>
```

## Evidence

- Focused test slice: 14 `NatFriendlyRoute` tests passed.
- CLI smoke verdict: `VERDICT: PARTIAL`.
- Relay report registered 2 peers.
- Relay report forwarded 9 datagrams.
- Sender report set `compatibilityMode=relayFallback`.
- Sender report set `directCandidateDiscovered=true`.
- Sender report set `directTraversalSucceeded=false`.
- Sender report set `relayUsed=true`.
- Sender loopback set `byteExactEcho=true`.
- Sender relay fallback RTT was 1512.75 microseconds in the local smoke.

## Acceptance Result

- Direct traversal remains the first attempt.
- Relay fallback requires a failed direct traversal candidate.
- Relay route reports keep `rawP2PPreferred=true`.
- Relay route notes explicitly mark the path as compatibility-only evidence.
- PASS validation still rejects relay fallback through
  `passWithRelayAsFastestPath`.
- The combined rendezvous/forwarder launcher carries the performance warning
  into JSON and CLI output.
- The relay report itself remains `PARTIAL` until physical self-hosted relay,
  firewall, NAT, and raw-route comparison evidence exists.

## Open Evidence

- Deploy the relay on the selected self-hosted host from Q011.
- Run the same session from two physical NAT/ISP endpoints.
- Record direct traversal failure evidence before accepting relay fallback
  evidence.
- Compare relay RTT/loss/jitter against the F11 raw direct route and keep relay
  outside F10 faster-than-LoLa PASS.

VERDICT: PARTIAL
