# F12 NAT ISP Friendly Route

Date: 2026-05-03
Status: rendezvous listener/client, direct traversal, relay fallback, and combined launcher source validation implemented; physical LAN/NAT deployment open
Verdict: PARTIAL

## Finding

Raw peer-to-peer UDP is still the right default for academic direct networks,
but field use may need an ISP/NAT-friendly compatibility path. F12 now includes
a bounded self-hosted UDP rendezvous listener and client registration path. The
listener records `sessionID`, local `peerID`, the source endpoint observed by
the server, and the other registered peer's endpoint when present. The client
then runs a simultaneous UDP keepalive loop and feeds the established socket
into the F11 byte-exact loopback measurement path. Relay evidence cannot
satisfy the fastest-path PASS gate. A bounded self-hosted UDP relay now exists,
but `nat-friendly-route-run` uses it only after a direct traversal candidate is
discovered and the direct traversal attempt fails.

The operator-facing launcher starts the self-hosted rendezvous listener and UDP
forwarder together. It emits a machine-readable PARTIAL handoff and an explicit
warning that the compatibility path may degrade performance against raw direct
P2P until raw-vs-NAT latency is measured.

## Objective

Provide a self-hosted, non-cloud compatibility mode that helps two clients find
each other across NAT or ISP firewalls while preserving the latency-first raw
route as the default. Every NAT-friendly report must state the tradeoff against
raw P2P.

## Assumptions

- The rendezvous host is self-hosted by the operator.
- Direct UDP traversal is attempted before any relay fallback.
- Relay fallback is allowed only as compatibility evidence.
- Raw direct P2P remains preferred for faster-than-LoLa closure unless a future
  measured decision explicitly changes that policy.

## Dependencies

- F03 raw P2P route policy.
- F11 loopback report contract.
- A self-hosted host or VPS for rendezvous tests.
- Firewall/NAT information from both endpoints.

## Affected Modules/Files

- `Sources/OpenLolaCore/NatFriendlyRoute.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift`
- `mac-port/reports/F12_RELAY_FALLBACK_2026-05-03.md`
- `mac-port/reports/F12_RENDEZVOUS_FORWARDER_LAUNCHER_2026-05-03.md`
- `mac-port/OPEN_QUESTIONS.md`
- `mac-port/IMPLEMENTATION_COMPANION.md`
- `mac-port/PROGRESS.md`

## Implementation Sequence

1. Add NAT-friendly report schema with rendezvous endpoint, local endpoint,
   observed endpoint, peer endpoint, direct traversal state, relay state,
   keepalive interval, added latency, and raw-P2P preference.
2. Add PASS guards that reject relay fallback as fastest-path evidence.
3. Add configuration parsing and bounded handoff CLIs.
4. Add localhost smoke to validate the schema and raw-P2P preference.
5. Add F12 open questions for rendezvous host and route permissions.
6. Add a self-hosted UDP relay runner, optional relay args on the route runner,
   and a localhost smoke that proves relay use only after failed direct
   traversal.
7. Add a combined rendezvous/UDP-forwarder launcher for host operators, with a
   required warning that the forwarder may degrade performance.
8. After source validation, deploy a self-hosted rendezvous/forwarder host and
   measure direct traversal before considering relay fallback.

## Current Source Surface

```bash
open-lola nat-rendezvous-run --bind-host <ip> --port <port> --session-id <id> --mode rendezvousOnly|directTraversal|relayFallback --expected-peers <n> --timeout-seconds <n> --output <path>
open-lola nat-relay-run --bind-host <ip> --port <port> --session-id <id> --expected-peers <n> --timeout-seconds <n> --output <path>
open-lola nat-rendezvous-forwarder-run --bind-host <ip> --rendezvous-port <port> --forwarder-port <port> --session-id <id> --expected-peers <n> --timeout-seconds <n> --output <path>
open-lola nat-friendly-route-run --role sender|looper --bind-host <ip> --peer-id <local-id> --rendezvous-host <ip> --rendezvous-port <port> --session-id <id> --port <local-udp-port> --duration-seconds <n> --output <path> [--raw-rtt-microseconds <us>] [--relay-host <ip>] [--relay-port <port>] [--debug-output <path>]
open-lola validate-nat-friendly-route-report <path>
open-lola nat-rendezvous-localhost-smoke
open-lola nat-friendly-localhost-smoke
open-lola nat-rendezvous-forwarder-localhost-smoke
open-lola nat-relay-fallback-localhost-smoke
```

## Test Plan

```bash
swift test --filter NatFriendlyRoute
swift build
swift test
.build/debug/open-lola nat-rendezvous-localhost-smoke
.build/debug/open-lola nat-friendly-localhost-smoke
.build/debug/open-lola nat-rendezvous-forwarder-localhost-smoke
.build/debug/open-lola nat-relay-fallback-localhost-smoke
```

## Acceptance Criteria

- Report validates direct traversal and relay fallback states separately.
- Self-hosted rendezvous listener accepts UDP client registrations and records
  observed external endpoints from socket source addresses.
- Two clients in one session can discover each other's observed endpoints
  through the rendezvous listener.
- Both clients run simultaneous UDP keepalives against the discovered endpoint.
- Successful direct traversal embeds an F11 byte-exact loopback report using the
  established socket.
- Added latency is recorded against a supplied raw-route RTT baseline.
- Relay fallback embeds relay RTT separately as `relayFallbackRttMicroseconds`.
- PASS rejects relay fallback as fastest-path evidence.
- PASS rejects reports that do not keep raw P2P preferred.
- Relay fallback validation requires a failed direct traversal candidate.
- Combined launcher writes rendezvous and UDP-forwarder reports and carries the
  performance warning into the JSON output.
- Bounded CLI writes a machine-readable PARTIAL handoff.
- Real deployment remains PARTIAL until the self-hosted rendezvous host,
  firewall behavior, direct traversal result, and loopback latency are measured.

## Rollback/Recovery

If NAT traversal fails, keep the report as PARTIAL with the observed endpoint
state and firewall notes. If relay fallback is enabled for compatibility, keep
it outside the raw route and faster-than-LoLa closure gate.

## Progress Checklist

- [x] Add tests for config parsing, report round trip, localhost smoke, and
  relay fallback PASS rejection.
- [x] Implement source models and CLI surfaces.
- [x] Add validation report.
- [x] Implement bounded self-hosted rendezvous listener/client registration.
- [x] Validate localhost two-client rendezvous discovery.
- [x] Add simultaneous UDP direct traversal keepalive loop.
- [x] Feed established traversal socket into F11 loopback measurement.
- [x] Record added latency against supplied raw-route RTT baseline.
- [x] Implement bounded self-hosted UDP relay runner.
- [x] Add optional route-runner relay fallback arguments.
- [x] Validate localhost relay fallback only after failed direct traversal.
- [x] Implement built-in rendezvous/UDP-forwarder launcher with explicit
  performance warning.
- [x] Validate launcher smoke and warning output.
- [ ] Select and document the self-hosted rendezvous host.
- [ ] Run rendezvous registration from two physical LAN clients.
- [ ] Run direct traversal from two real NAT/ISP endpoints.
- [ ] Measure relay fallback only if direct traversal fails.

## Resume here

Choose a self-hosted rendezvous host, record the host and firewall policy in
Q011, then run `nat-rendezvous-forwarder-run` on that host. Run
`nat-friendly-route-run` from both physical clients. Compare direct traversal
first; only keep relay fallback evidence if direct traversal fails, and compare
relay loopback latency to F11 raw direct-route evidence.

VERDICT: PARTIAL
