# G04 Mac-To-Mac UDP PCM Route

## LoLa Comparison

LoLa uses low-queue packet handling and clean high-PPS network paths. The
Mac-native path deliberately starts with normal UDP PCM, but it must prove that
packet age, jitter, loss, DSCP behavior, and capture correlation stay inside the
selected playout target on real routes.

## Current Repo State

- Related milestone: [../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)
- Live status: [../status/M05_STATUS.md](../status/M05_STATUS.md)
- Existing source validates route reports, can run localhost/one-shot and
  continuous UDP probes, and now includes a G04
  `MacToMacRouteCertificationReport` wrapper.
- G04 source validation now adds
  `open-lola validate-route-certification-report <path>` and
  `open-lola route-certification-synthetic-smoke`.
- Missing piece: physical direct-link, dedicated-switch, and campus route
  evidence with packet capture artifacts.

## Implementation Plan

1. Use G01 route labels and G03 packet mode as the source of truth.
2. Run direct Mac-to-Mac sender and receiver with packet capture at the receiver
   and, when possible, at the sender-side switch port.
3. Repeat on dedicated switch and campus path only after the direct link is
   understood.
4. Record packet p50/p95/p99/max age, jitter p99, loss, late packets,
   duplicates, reordering, DSCP requested/observed/classification, and
   receiver-capture correlation.
5. Reject any route where hidden playout growth is required to appear stable.
6. Make the best physical route the baseline input for G05, G09, and G10.

## Acceptance Tests

- `validate-route-report` accepts measured physical route reports.
- `validate-route-certification-report` accepts the ordered G04 route
  certification wrapper.
- PASS requires packet capture correlation and DSCP classification.
- PASS rejects localhost routes, placeholder evidence, packet-mode mismatch,
  missing direct-link PASS, missing capture artifacts, loss, late packets,
  hidden growth, and packet age over target.
- At least one physical route has a dated PASS or all physical routes have
  dated FAIL/PARTIAL evidence.

## Blockers / TODO(human)

- TODO(human): [M05 campus route access] -> Identify packet-capture points and permissions for Q004 -> [direct link only / dedicated switch / campus path with admin coordination]
- Requires two Macs and a capture point.

## Verification Commands

```bash
swift run open-lola udp-pcm-route-run --role receiver --peer <sender-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output mac-port/reports/<receiver>.json
swift run open-lola udp-pcm-route-run --role sender --peer <receiver-ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output mac-port/reports/<sender>.json
swift run open-lola validate-route-report mac-port/reports/<receiver>.json
swift run open-lola validate-route-certification-report mac-port/reports/<g04-certification>.json
swift run open-lola route-certification-synthetic-smoke
```

## Resume here

Fill the G04 route-certification template with a measured direct-link route
report and receiver packet capture artifact first. Do not benchmark campus
paths until the direct-link packet-age baseline is known.

VERDICT: PARTIAL
