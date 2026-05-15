# F12 NAT ISP Friendly Route Validation Report

Date: 2026-05-03
Companion: [F12 NAT ISP Friendly Route](../implementation-companions/F12_NAT_ISP_FRIENDLY_ROUTE.md)
Status: PARTIAL; rendezvous listener/client, direct traversal, relay fallback, and launcher source validation added

## Scope

This report validates the source-level F12 implementation for self-hosted
rendezvous handoff, NAT-friendly route reporting, direct traversal state, relay
fallback implementation/classification, and raw-P2P preference guards. The
2026-05-03 update
adds a bounded UDP rendezvous listener/client path that records observed socket
endpoints and peer endpoints. The later direct-traversal update adds a
simultaneous keepalive loop and feeds the established socket into the F11
byte-exact loopback path. The relay-fallback update adds a bounded self-hosted
UDP relay and keeps it usable only after direct traversal fails. It does not
claim field reachability because no self-hosted physical LAN or real NAT/ISP
run has been measured.

The latest source update adds `nat-rendezvous-forwarder-run`, a combined
operator launcher for the self-hosted UDP rendezvous listener and UDP forwarder.
The launcher writes both component reports and carries this warning in the JSON
output: compatibility forwarding may degrade performance against raw direct P2P
until measured raw-vs-NAT latency proves otherwise.

## Commands

```bash
swift test --filter NatFriendlyRoute
.build/debug/open-lola nat-rendezvous-localhost-smoke
.build/debug/open-lola nat-rendezvous-forwarder-localhost-smoke
.build/debug/open-lola nat-friendly-localhost-smoke
.build/debug/open-lola nat-relay-fallback-localhost-smoke
.build/debug/open-lola nat-rendezvous-run --bind-host 127.0.0.1 --port <port> --session-id session-1 --mode rendezvousOnly --expected-peers 2 --timeout-seconds 5 --output /private/tmp/open-lola-f12-rendezvous-listener.json
.build/debug/open-lola nat-relay-run --bind-host 127.0.0.1 --port <relay-port> --session-id session-1 --expected-peers 2 --timeout-seconds 30 --output /private/tmp/open-lola-f12-relay.json
.build/debug/open-lola nat-rendezvous-forwarder-run --bind-host 127.0.0.1 --rendezvous-port <port> --forwarder-port <forwarder-port> --session-id session-1 --expected-peers 2 --timeout-seconds 5 --output /private/tmp/open-lola-f12-forwarder-launcher.json
.build/debug/open-lola nat-friendly-route-run --role sender --bind-host 127.0.0.1 --peer-id sender-a --rendezvous-host 127.0.0.1 --rendezvous-port <port> --relay-host 127.0.0.1 --relay-port <relay-port> --session-id session-1 --port 5004 --duration-seconds 2 --raw-rtt-microseconds <f11-raw-rtt-us> --output /private/tmp/open-lola-nat-friendly-route.json --debug-output /private/tmp/open-lola-nat-friendly-route.jsonl
.build/debug/open-lola validate-nat-friendly-route-report /private/tmp/open-lola-nat-friendly-route.json
```

## Source Results

- Red test run failed before implementation because NAT-friendly route types did
  not exist.
- `swift test --filter NatFriendlyRoute` passed with 14 tests.
- PASS validation rejects relay fallback as fastest-path evidence.
- PASS validation rejects reports that do not keep raw P2P preferred.
- PARTIAL relay fallback validation requires a failed direct traversal
  candidate.
- The localhost rendezvous smoke starts a self-hosted listener and registers two
  local clients.
- Both local clients receive observed external endpoints and peer endpoints
  from the listener.
- The direct traversal smoke runs simultaneous UDP keepalives and embeds F11
  loopback reports in the sender and looper route reports.
- The relay fallback smoke forces direct traversal to fail before relay use,
  registers two peers with the self-hosted UDP relay, forwards datagrams, and
  embeds compatibility-only loopback evidence.
- The rendezvous/forwarder launcher smoke starts both host-side services in one
  bounded process, writes a combined PARTIAL report, and includes the
  performance warning.
- Sender reports record direct traversal RTT, supplied raw-route RTT, and added
  latency in microseconds.
- Relay fallback sender reports record `relayFallbackRttMicroseconds`
  separately from direct traversal RTT.
- The localhost smoke writes a valid PARTIAL route report backed by the
  rendezvous listener/client path.
- The bounded route handoff writes and validates a PARTIAL report with
  `rawP2PPreferred` set to true.

## Open Runtime Evidence

- Self-hosted rendezvous/forwarder host identity and firewall policy.
- Two physical LAN clients against the self-hosted listener.
- Two real clients behind NAT or ISP firewalls.
- Direct UDP traversal attempt result.
- Relay fallback measurement only if direct traversal fails.
- Latency comparison against F11 raw route evidence.
- Q011/Q012 are not closed by the launcher alone; they require real host,
  operator, firewall, retention, route-permission, packet-capture, and
  raw-vs-NAT measurement facts.

## Verdict

F12 source validation is implemented. Real NAT/ISP compatibility evidence
remains open.

VERDICT: PARTIAL

## Resume here

Answer Q011 with the self-hosted rendezvous/forwarder host and operator policy,
then run a real NAT-friendly route measurement from two clients. Keep relay
fallback evidence only after direct traversal fails.
