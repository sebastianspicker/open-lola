# F03 P2P Network Route

Date: 2026-05-03
Status: required physical route certification
Verdict: PARTIAL

## Finding

The current UDP PCM route tooling proves localhost and validates report shape,
but the faster-than-LoLa path requires a physical peer-to-peer route. Direct
wired Mac-to-Mac Ethernet is the first target. A dedicated switch is second.
Campus paths are benchmark variants only after packet-captured proof.

## Current Surface

- [../../Sources/OpenLolaCore/UdpPcmPacket.swift](../../Sources/OpenLolaCore/UdpPcmPacket.swift)
  defines the fastest-mode packet contract.
- [../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift](../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift)
  validates route reports and continuous sender/receiver summaries. PASS now
  requires a physical route kind, measured duration, duration-to-packet-count
  parity, non-documentation IP addresses, non-placeholder evidence, packet
  capture correlation, DSCP classification, and a one-packet playout target.
- [../../Sources/OpenLolaCore/UdpPcmRouteRunConfiguration.swift](../../Sources/OpenLolaCore/UdpPcmRouteRunConfiguration.swift)
  parses the physical evidence fields required for a PASS-capable receiver
  report: route identity, endpoint names, interface names, link profile, packet
  capture correlation, DSCP observation/classification, and explicit verdict.
- [../../Sources/OpenLolaCore/MacToMacRouteCertification.swift](../../Sources/OpenLolaCore/MacToMacRouteCertification.swift)
  validates the ordered certification wrapper and requires the direct-link
  route to pass before any route certification can pass.
- [../../Sources/OpenLolaCore/UdpPcmLoopbackLatency.swift](../../Sources/OpenLolaCore/UdpPcmLoopbackLatency.swift)
  adds byte-exact UDP PCM sender/looper latency measurement for F11.
- [../../Sources/OpenLolaCore/NetworkDiagnostics.swift](../../Sources/OpenLolaCore/NetworkDiagnostics.swift)
  records ICMP RTT and traceroute hops as diagnostics only.
- `open-lola udp-pcm-route-run` is the active physical sender/receiver entry
  point.

## Route Policy

- Static configuration only for the first production path.
- No session negotiation.
- No retransmission.
- No relay for fastest-path PASS.
- No codec.
- No adaptive jitter buffer.
- No UI-driven latency change.
- DSCP is measured, not trusted.
- ICMP ping and traceroute are comparison evidence only.
- NAT/ISP-friendly mode is compatibility evidence and cannot replace raw P2P
  without a separate measured policy decision.

## Required Evidence

For each route variant, record:

- Mac A and Mac B hardware identities and interface names;
- route kind: `directLink`, `dedicatedSwitch`, or `campusPath`;
- IPs, subnet, MTU, and route label;
- measured duration and expected packet count for the selected packet mode;
- packet-capture point on each side where possible;
- DSCP marking as sent and as observed;
- p50/p95/p99/max packet age, jitter, loss, late packets, and out-of-order
  packets;
- byte-exact UDP PCM loopback RTT and RTT/2 estimate;
- ICMP RTT and traceroute hop count for comparison;
- whether the route preserves the configured playout target without hidden
  growth.

## Route Comparison Sequence

Each candidate route uses the same packet mode, UDP port, and static endpoint
addresses across all probes. The comparison sequence is:

1. Start packet capture on both Macs with a UDP port filter and verbose DSCP
   decoding.
2. Run `udp-pcm-route-run` receiver on Mac B and sender on Mac A with `--dscp`
   set when the route policy allows marking.
3. Run `udp-pcm-loopback-run` looper on Mac B and sender on Mac A with
   `--diagnostics on` and `--debug-output`.
4. Run `network-diagnostics-run` from Mac A to Mac B for ICMP ping and
   traceroute.
5. Extract DSCP observations from both captures and classify them as
   `honored`, `rewritten`, `ignored`, `harmful`, or `notTested`.
6. Validate the route receiver report, loopback sender report, loopback looper
   report, loopback session pair, network diagnostics report, and route
   certification wrapper.

Compare UDP echo RTT to ICMP RTT only as a diagnostic cross-check. UDP PCM route
metrics and byte-exact UDP echo are the route evidence; ICMP ping and traceroute
cannot satisfy PASS, replace UDP loopback, or justify hidden buffer growth.

## Required Command Shape

Run sender and receiver on separate Macs:

```bash
sudo tcpdump -i <receiver-interface> -s 0 -vvv -w <receiver-pcapng> 'udp port <port>'
sudo tcpdump -i <sender-interface> -s 0 -vvv -w <sender-pcapng> 'udp port <port>'
swift run open-lola udp-pcm-route-run --role receiver --bind-host <receiver-ip> --peer <sender-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output <receiver-report> --dscp <0-63> --route-kind directLink --route-label <route-label> --route-topology <route-topology> --sender-label <sender-label> --sender-host <sender-host> --sender-interface <sender-interface> --sender-ip <sender-ip> --receiver-label <receiver-label> --receiver-host <receiver-host> --receiver-interface <receiver-interface> --receiver-ip <receiver-ip> --link-rate-mbps <mbps> --vlan <vlan-or-none> --multicast-policy unicast-only --capture-point <capture-label> --capture-correlated true --capture-notes <capture-note> --dscp-observed <0-63> --dscp-classification honored --verdict pass
swift run open-lola udp-pcm-route-run --role sender --bind-host <sender-ip> --peer <receiver-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output <sender-summary> --dscp <0-63>
swift run open-lola udp-pcm-loopback-run --session-id <id> --role looper --bind-host <receiver-ip> --peer <sender-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --debug-output <looper-debug-jsonl> --output <looper-report>
swift run open-lola udp-pcm-loopback-run --session-id <id> --role sender --bind-host <sender-ip> --peer <receiver-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --diagnostics on --debug-output <sender-debug-jsonl> --output <loopback-report>
swift run open-lola network-diagnostics-run --peer <receiver-ip> --ping-count <n> --max-hops <n> --output <diagnostics-report>
tcpdump -nn -vvv -r <sender-pcapng> 'udp port <port>' > <dscp-summary>
tcpdump -nn -vvv -r <receiver-pcapng> 'udp port <port>' >> <dscp-summary>
swift run open-lola validate-route-report <receiver-report>
swift run open-lola validate-udp-pcm-loopback-report <loopback-report>
swift run open-lola validate-udp-pcm-loopback-session <loopback-report> <looper-report>
swift run open-lola validate-network-diagnostics-report <diagnostics-report>
swift run open-lola validate-route-certification-report <certification-report>
```

## PASS Criteria

- Direct wired route passes first.
- The certification wrapper keeps route candidates ordered as `directLink`,
  `dedicatedSwitch`, then `campusPath`.
- A route report cannot pass with localhost, documentation IP ranges,
  placeholder/fixture fields, missing measured duration, packet-count mismatch,
  duplicate/reordered packets, or a playout target larger than one packet
  period.
- Switch route cannot supersede direct wired without a side-by-side measured
  advantage.
- Campus route cannot be called fastest unless captures show DSCP/QoS behavior
  and packet age/loss remain inside the fixed audio target.
- Loopback mode cannot pass if the looper mutates datagram bytes.
- ICMP RTT cannot be used as a substitute for UDP PCM loopback or route report
  latency.
- NAT relay fallback cannot satisfy raw fastest-path PASS.
- Hidden playout growth or adaptive buffering forces `VERDICT: PARTIAL` or
  `VERDICT: FAIL`.

## Resume here

Connect two Macs directly, choose a static subnet, run sender/receiver and
sender/looper with packet capture, run diagnostics, extract DSCP observations,
then validate the route, loopback, diagnostics, and certification reports. Add
F12 NAT-friendly evidence only after raw route evidence exists.

VERDICT: PARTIAL
