# Network Route Command Matrix

Date: 2026-05-04  
Status: executable C05 matrix implemented  
Milestone: C05  
Verdict: PARTIAL

## Purpose

This document summarizes the C05 network transport route and argument matrix.
The executable source of truth is:

- `Sources/OpenLolaCore/NetworkRouteCommandMatrix.swift`
- `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift`
- `Sources/open-lola/main.swift`

The user-facing probe is:

```bash
.build/debug/open-lola network-route-command-matrix
```

Expected output is machine-readable JSON followed by:

```text
VERDICT: PARTIAL
```

`PARTIAL` is intentional. The matrix labels command ownership and evidence
boundaries. It does not prove real direct-route, NAT/WAN, relay, hardware, or
benchmark release readiness.

## Summary

| Scope | Count |
|---|---:|
| Matrix entries | 25 |
| Validators | 8 |
| Run commands | 7 |
| Localhost smokes | 8 |
| Packet probes | 2 |
| Fastest direct evidence contributors | 3 |
| NAT compatibility-only entries | 9 |
| Diagnostic-only entries | 2 |
| Loopback measurement entries | 4 |
| Packet contract-only entries | 4 |

## Evidence Boundaries

| Boundary | Meaning |
|---|---|
| `packetContractOnly` | Packet encode/decode or one-shot send/receive behavior only. No route readiness claim. |
| `directFastestCandidate` | Can contribute measured direct-route evidence when paired with physical route metadata and report validation. |
| `directCertificationGate` | Aggregate route gate that keeps direct-link evidence separate from switched and campus paths. |
| `loopbackMeasurement` | UDP loopback timing evidence. Useful support data, but not route superiority proof by itself. |
| `diagnosticOnly` | Ping/traceroute/reachability support evidence. Cannot replace route reports. |
| `natCompatibilityOnly` | NAT, rendezvous, relay, or forwarder compatibility evidence. Cannot be direct-fastest evidence. |
| `directPeerSessionPartialOnly` | Direct P2P source/session plumbing that currently rejects PASS without manual direct-LAN evidence. |

## Route Command Map

| Command | Kind | Output report | Route mode | Evidence boundary | Fastest direct contributor |
|---|---|---|---|---|---|
| `udp-pcm-send-once` | probe | `UdpPcmPacket` | `udpPcmPacketProbe` | `packetContractOnly` | no |
| `udp-pcm-receive-once` | probe | `UdpPcmPacket` | `udpPcmPacketProbe` | `packetContractOnly` | no |
| `validate-udp-pcm-packet` | validator | `UdpPcmPacket` | `udpPcmPacketProbe` | `packetContractOnly` | no |
| `validate-route-report` | validator | `UdpPcmRouteReport` | `udpPcmRoute` | `directFastestCandidate` | yes |
| `validate-route-certification-report` | validator | `MacToMacRouteCertificationReport` | `udpPcmRoute` | `directCertificationGate` | yes |
| `udp-pcm-route-run` | run | `UdpPcmContinuousSenderSummary` or `UdpPcmRouteReport` | `udpPcmRoute` | `directFastestCandidate` | yes |
| `udp-pcm-localhost-smoke` | localhost smoke | `UdpPcmPacket` | `udpPcmPacketProbe` | `packetContractOnly` | no |
| `udp-pcm-route-localhost-smoke` | localhost smoke | `UdpPcmRouteReport` | `udpPcmRoute` | `directFastestCandidate` | no |
| `validate-udp-pcm-loopback-report` | validator | `UdpPcmLoopbackReport` | `udpPcmLoopback` | `loopbackMeasurement` | no |
| `validate-udp-pcm-loopback-session` | validator | `UdpPcmLoopbackReport` pair | `udpPcmLoopback` | `loopbackMeasurement` | no |
| `udp-pcm-loopback-run` | run | `UdpPcmLoopbackReport` | `udpPcmLoopback` | `loopbackMeasurement` | no |
| `udp-pcm-loopback-localhost-smoke` | localhost smoke | `UdpPcmLoopbackReport` | `udpPcmLoopback` | `loopbackMeasurement` | no |
| `validate-network-diagnostics-report` | validator | `NetworkDiagnosticsReport` | `networkDiagnostics` | `diagnosticOnly` | no |
| `network-diagnostics-run` | run | `NetworkDiagnosticsReport` | `networkDiagnostics` | `diagnosticOnly` | no |
| `validate-nat-friendly-route-report` | validator | `NatFriendlyRouteReport` | `natFriendlyRoute` | `natCompatibilityOnly` | no |
| `nat-friendly-route-run` | run | `NatFriendlyRouteReport` | `natFriendlyRoute` | `natCompatibilityOnly` | no |
| `nat-friendly-localhost-smoke` | localhost smoke | `NatFriendlyRouteReport` | `natFriendlyRoute` | `natCompatibilityOnly` | no |
| `nat-rendezvous-run` | run | `NatRendezvousReport` | `natRendezvous` | `natCompatibilityOnly` | no |
| `nat-rendezvous-localhost-smoke` | localhost smoke | `NatRendezvousLocalhostSmokeResult` | `natRendezvous` | `natCompatibilityOnly` | no |
| `nat-relay-run` | run | `NatRelayReport` | `natRelay` | `natCompatibilityOnly` | no |
| `nat-relay-fallback-localhost-smoke` | localhost smoke | `NatRelayFallbackLocalhostSmokeResult` | `natRelay` | `natCompatibilityOnly` | no |
| `nat-rendezvous-forwarder-run` | run | `NatRendezvousForwarderLauncherReport` | `natForwarder` | `natCompatibilityOnly` | no |
| `nat-rendezvous-forwarder-localhost-smoke` | localhost smoke | `NatRendezvousForwarderLauncherReport` | `natForwarder` | `natCompatibilityOnly` | no |
| `validate-direct-p2p-session-report` | validator | `DirectPeerSessionReport` | `directPeerSession` | `directPeerSessionPartialOnly` | no |
| `direct-p2p-localhost-smoke` | localhost smoke | `DirectPeerSessionReport` | `directPeerSession` | `directPeerSessionPartialOnly` | no |

## C05 Runtime Guard

C05 also tightens `NatFriendlyRouteReport.validate()` for PASS:

- relay fallback remains rejected as fastest-path evidence,
- rendezvous-only mode is rejected as fastest-path evidence,
- raw P2P preference remains required,
- direct traversal remains required,
- nested loopback evidence must itself be `PASS`,
- raw route RTT baseline evidence must be present.

This preserves source-level and localhost `PARTIAL` behavior while preventing
NAT/rendezvous/relay reports from being promoted into direct-fastest claims.

## Test Contract

`NetworkRouteCommandMatrixTests.swift` verifies:

- summary counts match executable entries,
- every owner source file, related source file, and test file exists,
- every matrix command is covered by the C01 CLI command inventory,
- NAT, diagnostics, loopback, packet-only, and direct-P2P partial entries do
  not contribute to fastest direct evidence,
- `OpenLolaCLI.networkRouteCommandMatrixData()` round-trips through JSON.

`NatFriendlyRouteTests.swift` verifies:

- relay fallback cannot be a fastest PASS,
- rendezvous-only mode cannot be a fastest PASS,
- fastest PASS requires nested loopback `PASS`,
- fastest PASS requires a raw route RTT baseline.

## Resume Here

C05 is implemented at source level. Continue with
[companions/C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](companions/C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md),
then use C10/C12 release readiness and generated-output hygiene as completed
verification references.

VERDICT: PARTIAL
