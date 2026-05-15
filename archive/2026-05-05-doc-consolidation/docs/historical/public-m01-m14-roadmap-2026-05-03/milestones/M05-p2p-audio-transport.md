# M05 P2P Audio Transport

Date: 2026-05-03  
Status: source implementation complete; physical evidence pending  
Verdict: PARTIAL

## Objective

Certify the direct peer-to-peer UDP audio route before any WAN, NAT, relay,
video, or lighting expansion.

## Scope

Cover direct IP session setup, UDP PCM sender/receiver, packet age, sequence
loss, jitter, DSCP observation, packet capture, and two-Mac route evidence.

## Affected Files

- [../architecture/p2p-networking.md](../architecture/p2p-networking.md)
- `Sources/OpenLolaCore/UdpPcmRouteCertification.swift`
- `Sources/OpenLolaCore/UdpPcmRouteRunConfiguration.swift`
- `Sources/OpenLolaCore/UdpPcmContinuousRouteRunner.swift`
- `Sources/OpenLolaCore/UdpPcmSocketOperations.swift`
- `Sources/OpenLolaCore/UdpPcmRouteHelpers.swift`
- `Sources/OpenLolaCore/UdpPcmLoopbackLatency.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift`
- `Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift`
- `Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift`

## Implementation Tasks

- Keep direct IP UDP as the default media route.
- Validate protocol version, sample rate, frame size, channel count, format,
  sequence, and timestamp.
- Record packet capture points and DSCP classification.
- Keep NAT traversal and relay out of fastest-path PASS criteria.

### Implemented Command Pair

Run receiver first on Mac B:

```bash
swift run open-lola udp-pcm-route-run --role receiver --bind-host <mac-b-ip> --peer <mac-a-ip> --port <port> --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output <receiver-report.json> --dscp 46 --route-kind directLink --route-label direct-link-reference --route-topology mac-to-mac-direct-cable --sender-label sender-mac --sender-host <mac-a-host> --sender-interface <mac-a-interface> --sender-ip <mac-a-ip> --receiver-label receiver-mac --receiver-host <mac-b-host> --receiver-interface <mac-b-interface> --receiver-ip <mac-b-ip> --link-rate-mbps <mbps> --vlan none --multicast-policy unicast-only --capture-point '<receiver capture label>' --capture-correlated true --capture-notes '<capture correlation note>' --dscp-observed <observed-dscp> --dscp-classification honored --verdict pass
```

Run sender on Mac A:

```bash
swift run open-lola udp-pcm-route-run --role sender --bind-host <mac-a-ip> --peer <mac-b-ip> --port <port> --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output <sender-summary.json> --dscp 46
```

The receiver command exits successfully with `VERDICT: PASS` only if the report
validator also accepts the route as physical, packet-captured, DSCP-classified,
loss-free, duplicate-free, reorder-free, late-packet-free, and fixed to the
one-packet playout target. Without physical evidence fields, the same runner
remains `PARTIAL`.

## Test Plan

- Protocol tests for malformed and out-of-order packets.
- Sender/receiver route report validation.
- Session agreement tests.
- Byte-exact loopback tests.

## Benchmark Plan

Run direct cable first, then known switch, then campus route. Record UDP echo
RTT, estimated one-way packet age, jitter p50/p95/p99/max, loss, late packets,
DSCP behavior, and capture correlation.

## Acceptance Criteria

- Physical direct route PASS exists.
- Packet age stays within the selected playout target.
- No retransmission or hidden playout growth is used.
- Route identity and capture points are recorded.

## Risks

- Localhost success can hide real route behavior.
- DSCP can be rewritten or ignored.
- Campus routes can vary by switch path and policy.

## Blockers

Two Macs, route labels, packet-capture permission, and Q004 route access.

## Rollback Plan

Disable physical-route PASS and keep localhost route tests as source validation
only.

## Progress Checklist

- [x] Direct route command pair recorded.
- [ ] Packet capture recorded.
- [ ] DSCP behavior recorded.
- [ ] Loss and jitter thresholds met.
- [ ] M05 report stored.

## Resume Point

Resume at M06 only after direct physical UDP audio route evidence exists.

VERDICT: PARTIAL
