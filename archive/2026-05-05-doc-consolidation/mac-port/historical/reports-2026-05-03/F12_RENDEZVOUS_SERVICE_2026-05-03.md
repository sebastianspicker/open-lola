# F12 Rendezvous Service Validation Report

Date: 2026-05-03
Companion: [F12 NAT ISP Friendly Route](../implementation-companions/F12_NAT_ISP_FRIENDLY_ROUTE.md)
Status: PARTIAL; superseded for direct traversal by F12_NAT_DIRECT_TRAVERSAL_2026-05-03.md

## Scope

This report validates the source-level self-hosted rendezvous service added for
F12. The service is a bounded UDP listener that accepts client registrations for
`sessionID` and local `peerID`, records the endpoint observed from the socket
source address, and returns another peer endpoint when the session has a second
registered client. Direct traversal and embedded F11 loopback evidence are now
tracked in
[F12_NAT_DIRECT_TRAVERSAL_2026-05-03.md](F12_NAT_DIRECT_TRAVERSAL_2026-05-03.md).

This is not a real two-Mac or NAT/ISP proof. The LAN-interface example below
uses TEST-NET documentation address `192.0.2.46`; the measured private LAN
address is not retained in this public-facing report.

## Commands

```bash
swift test --filter NatFriendlyRoute
.build/debug/open-lola nat-rendezvous-localhost-smoke

.build/debug/open-lola nat-rendezvous-run --bind-host 127.0.0.1 --port 47126 --session-id cli-rendezvous-2 --mode rendezvousOnly --expected-peers 2 --timeout-seconds 30 --output /private/tmp/open-lola-f12-rendezvous-cli/listener-2.json
.build/debug/open-lola nat-friendly-route-run --role sender --bind-host 127.0.0.1 --peer-id sender-cli --rendezvous-host 127.0.0.1 --rendezvous-port 47126 --session-id cli-rendezvous-2 --port 0 --duration-seconds 6 --output /private/tmp/open-lola-f12-rendezvous-cli/sender-2.json --debug-output /private/tmp/open-lola-f12-rendezvous-cli/sender-2.jsonl
.build/debug/open-lola nat-friendly-route-run --role looper --bind-host 127.0.0.1 --peer-id looper-cli --rendezvous-host 127.0.0.1 --rendezvous-port 47126 --session-id cli-rendezvous-2 --port 0 --duration-seconds 6 --output /private/tmp/open-lola-f12-rendezvous-cli/looper-2.json --debug-output /private/tmp/open-lola-f12-rendezvous-cli/looper-2.jsonl
.build/debug/open-lola validate-nat-friendly-route-report /private/tmp/open-lola-f12-rendezvous-cli/sender-2.json
.build/debug/open-lola validate-nat-friendly-route-report /private/tmp/open-lola-f12-rendezvous-cli/looper-2.json

.build/debug/open-lola nat-rendezvous-run --bind-host 192.0.2.46 --port 47127 --session-id lan-rendezvous --mode rendezvousOnly --expected-peers 2 --timeout-seconds 30 --output /private/tmp/open-lola-f12-rendezvous-lan/listener.json
.build/debug/open-lola nat-friendly-route-run --role sender --bind-host 192.0.2.46 --peer-id sender-lan --rendezvous-host 192.0.2.46 --rendezvous-port 47127 --session-id lan-rendezvous --port 0 --duration-seconds 6 --output /private/tmp/open-lola-f12-rendezvous-lan/sender.json --debug-output /private/tmp/open-lola-f12-rendezvous-lan/sender.jsonl
.build/debug/open-lola nat-friendly-route-run --role looper --bind-host 192.0.2.46 --peer-id looper-lan --rendezvous-host 192.0.2.46 --rendezvous-port 47127 --session-id lan-rendezvous --port 0 --duration-seconds 6 --output /private/tmp/open-lola-f12-rendezvous-lan/looper.json --debug-output /private/tmp/open-lola-f12-rendezvous-lan/looper.jsonl
.build/debug/open-lola validate-nat-friendly-route-report /private/tmp/open-lola-f12-rendezvous-lan/sender.json
.build/debug/open-lola validate-nat-friendly-route-report /private/tmp/open-lola-f12-rendezvous-lan/looper.json
```

## Evidence

- Focused test gate: `swift test --filter NatFriendlyRoute` passed with 7
  tests.
- Built-in localhost smoke: `nat-rendezvous-localhost-smoke` returned two route
  reports plus a server report; both clients had observed endpoints and peer
  endpoints.
- Separated localhost CLI listener/client run:
  `/private/tmp/open-lola-f12-rendezvous-cli/listener-2.json`,
  `/private/tmp/open-lola-f12-rendezvous-cli/sender-2.json`,
  `/private/tmp/open-lola-f12-rendezvous-cli/looper-2.json`.
- Same-host LAN-interface CLI listener/client run:
  `/private/tmp/open-lola-f12-rendezvous-lan/listener.json`,
  `/private/tmp/open-lola-f12-rendezvous-lan/sender.json`,
  `/private/tmp/open-lola-f12-rendezvous-lan/looper.json`.
- Debug JSONL paths:
  `/private/tmp/open-lola-f12-rendezvous-cli/sender-2.jsonl`,
  `/private/tmp/open-lola-f12-rendezvous-cli/looper-2.jsonl`,
  `/private/tmp/open-lola-f12-rendezvous-lan/sender.jsonl`,
  `/private/tmp/open-lola-f12-rendezvous-lan/looper.jsonl`.

## Results

- The listener accepted two unique peer registrations per session.
- The listener recorded observed external endpoints from socket source
  addresses.
- Each client report recorded its own observed endpoint and the other peer's
  endpoint.
- `rawP2PPreferred` stayed true and relay use stayed false.
- Endpoint discovery remains compatibility evidence until paired with direct
  traversal and F11 loopback proof.

## Open Evidence

- Run the same commands on two physical LAN clients.
- Run on a self-hosted rendezvous host outside the local LAN.
- Measure the subsequent UDP media path with F11 loopback reports.
- Keep relay fallback outside the faster-than-LoLa PASS gate unless explicitly
  promoted by later measured policy.

VERDICT: PARTIAL
