# M05 Route Certification Validation Report

Date: 2026-05-02  
Milestone: [M05 Mac-To-Mac Route Certification](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)  
Status: PARTIAL

## Scope

This report validates the M05/G04 source-level route certification harness:
route report schema, validation rules, G04 route-certification wrapper, fixture
validation, localhost UDP route smoke, and sender/receiver CLI mechanics. It
does not certify a physical direct-link, dedicated-switch, or campus route.

## Route Report Contract

The route report records:

- route kind: localhost smoke, direct link, dedicated switch, or campus path;
- sender and receiver endpoint labels, host names, interfaces, and IP
  addresses;
- UDP PCM packet mode: sample rate, frames per packet, channel count, and sample
  format;
- network profile: link rate, VLAN, multicast policy, DSCP classification, and
  packet-capture evidence;
- packet metrics: sent, received, lost, late, reordered, duplicate, packet age
  p50/p95/p99/max, jitter p99, fixed playout target, and hidden playout growth;
- verdict: PASS, FAIL, or PARTIAL.

PASS route reports require packet-capture correlation, packet age within the
fixed playout target, no lost or late packets, no hidden playout growth, and no
harmful DSCP classification.

F03 follow-up tightening on 2026-05-03 also requires PASS route reports to use a
physical route kind, include measured duration, match duration to expected
packet count, avoid documentation IP ranges and placeholder fields, and keep the
playout target to one UDP PCM packet period.

## Commands

```bash
swift test --filter UdpPcmRouteReportTests
swift test
swift build
swift run open-lola validate-route-report Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json
swift run open-lola validate-route-certification-report Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/valid/g04-route-certification-partial.json
swift run open-lola udp-pcm-route-localhost-smoke
swift run open-lola route-certification-synthetic-smoke
.build/debug/open-lola udp-pcm-receive-once 55555
.build/debug/open-lola udp-pcm-send-once 127.0.0.1 55555
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red test run before implementation failed on missing M05 route-report types.
- `swift test --filter UdpPcmRouteReportTests` passed with 8 M05 tests.
- `swift test` passed with 33 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The direct-link route contract fixture and G04 route-certification partial
  fixture passed CLI validation.
- `swift run open-lola udp-pcm-route-localhost-smoke` emitted a PARTIAL report.
- The one-shot sender and receiver CLIs exchanged one UDP PCM packet on
  loopback.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Deferred Physical Evidence

M05/G04 cannot be marked PASS until real reports exist for:

- direct wired Mac-to-Mac route;
- dedicated switch route;
- campus path route where access is allowed;
- DSCP classification from packet capture for each accepted route;
- G04 route-certification wrapper with capture artifact paths for every
  accepted physical route.

## Verdict

M05/G04 source validation is complete, but physical route certification remains
open.

VERDICT: PARTIAL

## Resume here

Run the sender/receiver on two Macs over a direct wired link, capture the route,
create a direct-link route report, validate it with
`open-lola validate-route-report <path>`, then validate the wrapper with
`open-lola validate-route-certification-report <path>`.
