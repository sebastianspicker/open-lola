# F12 NAT Direct Traversal Validation Report

Date: 2026-05-03
Companion: [F12 NAT ISP Friendly Route](../implementation-companions/F12_NAT_ISP_FRIENDLY_ROUTE.md)
Status: PARTIAL

## Scope

This report validates the source-level F12 direct traversal path. Two clients
register through the self-hosted rendezvous listener, exchange simultaneous UDP
keepalives against the discovered peer endpoints, then reuse the established
socket for the F11 byte-exact UDP PCM loopback measurement path.

This is localhost evidence only. It proves the implementation path and report
contract, not ISP/NAT reachability between two physical sites.

## Commands

```bash
swift test --filter NatFriendlyRoute

.build/debug/open-lola nat-rendezvous-run --bind-host 127.0.0.1 --port 47211 --session-id direct-traversal-cli --mode rendezvousOnly --expected-peers 2 --timeout-seconds 20 --output /private/tmp/open-lola-f12-direct-traversal/listener.json
.build/debug/open-lola nat-friendly-route-run --role sender --bind-host 127.0.0.1 --peer-id sender-direct --rendezvous-host 127.0.0.1 --rendezvous-port 47211 --session-id direct-traversal-cli --port 0 --duration-seconds 2 --raw-rtt-microseconds 100 --output /private/tmp/open-lola-f12-direct-traversal/sender.json --debug-output /private/tmp/open-lola-f12-direct-traversal/sender.jsonl
.build/debug/open-lola nat-friendly-route-run --role looper --bind-host 127.0.0.1 --peer-id looper-direct --rendezvous-host 127.0.0.1 --rendezvous-port 47211 --session-id direct-traversal-cli --port 0 --duration-seconds 2 --raw-rtt-microseconds 100 --output /private/tmp/open-lola-f12-direct-traversal/looper.json --debug-output /private/tmp/open-lola-f12-direct-traversal/looper.jsonl
.build/debug/open-lola validate-nat-friendly-route-report /private/tmp/open-lola-f12-direct-traversal/sender.json
.build/debug/open-lola validate-nat-friendly-route-report /private/tmp/open-lola-f12-direct-traversal/looper.json
```

## Evidence

- Listener report:
  `/private/tmp/open-lola-f12-direct-traversal/listener.json`
- Sender NAT route report:
  `/private/tmp/open-lola-f12-direct-traversal/sender.json`
- Looper NAT route report:
  `/private/tmp/open-lola-f12-direct-traversal/looper.json`
- Sender debug trace:
  `/private/tmp/open-lola-f12-direct-traversal/sender.jsonl`
- Looper debug trace:
  `/private/tmp/open-lola-f12-direct-traversal/looper.jsonl`

## Results

- Rendezvous listener registered 2 peers for `direct-traversal-cli`.
- Sender observed endpoint: `127.0.0.1:54184`.
- Looper observed endpoint: `127.0.0.1:57420`.
- Both reports set `directCandidateDiscovered=true`.
- Both reports set `directTraversalSucceeded=true`.
- Sender embedded F11 loopback:
  - `packetsSent=10`
  - `packetsEchoed=9`
  - `byteExactEcho=true`
  - `p50Microseconds=1824.042`
- Looper embedded F11 loopback:
  - `packetsEchoed=9`
  - `byteExactEcho=true`
- Raw-route baseline supplied to the run: `100` microseconds.
- Sender added latency vs raw baseline: `1724.042` microseconds.

## Open Evidence

- Repeat this on two physical LAN clients.
- Repeat this with a self-hosted rendezvous host across NAT/ISP boundaries.
- Use the measured F11 raw-route RTT instead of the local `100` microsecond
  placeholder baseline.
- If the UDP forwarder is launched for compatibility, keep its warning in the
  report: it may degrade performance and cannot replace raw direct P2P evidence.
- Compare direct traversal loopback against the raw route before allowing this
  compatibility path into any faster-than-LoLa closure claim.

VERDICT: PARTIAL
