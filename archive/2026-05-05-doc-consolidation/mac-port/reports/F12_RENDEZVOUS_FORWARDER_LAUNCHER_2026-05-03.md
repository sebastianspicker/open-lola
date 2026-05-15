# F12 Rendezvous Forwarder Launcher Validation Report

Date: 2026-05-03
Companion: [F12 NAT ISP Friendly Route](../implementation-companions/F12_NAT_ISP_FRIENDLY_ROUTE.md)
Status: PARTIAL

## Scope

This report validates the source-level host-side launcher for F12. The launcher
starts the self-hosted UDP rendezvous listener and UDP forwarder in one bounded
process, writes both component reports into one JSON handoff, and emits a
performance warning.

This is not field closure. It does not select the real host, operator,
firewall, retention policy, route permissions, packet-capture points, or
raw-vs-NAT latency evidence required by Q011 and Q012.

## Commands

```bash
swift test --filter NatFriendlyRoute

.build/debug/open-lola nat-rendezvous-forwarder-localhost-smoke

.build/debug/open-lola nat-rendezvous-forwarder-run --bind-host <ip> --rendezvous-port <port> --forwarder-port <port> --session-id <id> --expected-peers 2 --timeout-seconds <n> --output <path>
```

## Evidence

- Focused test slice: 14 `NatFriendlyRoute` tests passed, including launcher
  argument parsing, same-port rejection, bounded service startup, combined
  report validation, and warning text.
- The launcher report contains the rendezvous listener report.
- The launcher report contains the UDP forwarder report.
- The JSON field `performanceWarning` states that built-in UDP
  rendezvous/forwarder mode may degrade performance versus raw direct P2P.
- The CLI prints the same warning before the PARTIAL verdict.

## Acceptance Result

- The rendezvous and forwarder ports must differ.
- The combined launcher remains bounded by `--timeout-seconds`.
- The launcher is operator convenience only; clients still run
  `nat-friendly-route-run`.
- The forwarder remains compatibility evidence and cannot satisfy faster-path
  PASS evidence.

## Open Field Evidence

- Select the self-hosted rendezvous/forwarder host, operator, ports, firewall
  rules, and retention policy for Q011.
- Record ICMP, traceroute, UDP echo, DSCP, and packet-capture permissions for
  Q012.
- Run F11 raw direct-link loopback on the accepted route.
- Run F12 direct traversal through the selected host from two real endpoints.
- Keep forwarder latency as compatibility-only unless direct traversal fails,
  and compare any forwarder RTT/loss/jitter against the F11 raw route.

VERDICT: PARTIAL
