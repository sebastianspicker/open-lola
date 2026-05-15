# M05 Route Certification Route Comparison Report

Date: 2026-05-03
Milestone: [M05 Mac-To-Mac Route Certification](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)
Route context: [F03 P2P Network Route](../implementation-companions/F03_P2P_NETWORK_ROUTE.md)
F11 context: [F11 Network Loopback Diagnostics](../implementation-companions/F11_NETWORK_LOOPBACK_DIAGNOSTICS.md)
Status: route-comparison workflow implemented; physical DSCP evidence pending
Verdict: PARTIAL

## Scope

This report implements the F11 route-comparison evidence path for M05/F03:

- run UDP PCM sender/receiver for the candidate route;
- run byte-exact UDP PCM sender/looper loopback on the same route;
- run ICMP ping and traceroute as diagnostics;
- attach DSCP packet captures;
- compare UDP echo RTT with ICMP RTT while keeping ICMP diagnostic-only.

The current workspace cannot certify a physical route because there is no second
Mac, direct wired route, or packet capture attached here. All local results
below are localhost surface probes and remain `PARTIAL`.

## Physical Artifact Ledger

| Artifact | Required path | State |
|---|---|---|
| UDP route receiver report | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-route-receiver.json` | Missing physical run |
| UDP route sender summary | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-route-sender.json` | Missing physical run |
| UDP loopback sender report | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-sender.json` | Missing physical run |
| UDP loopback looper report | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-looper.json` | Missing physical run |
| UDP loopback sender debug JSONL | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-sender.jsonl` | Missing physical run |
| UDP loopback looper debug JSONL | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-looper.jsonl` | Missing physical run |
| ICMP/traceroute diagnostics report | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/network-diagnostics.json` | Missing physical run |
| Mac A packet capture | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/mac-a-udp-55448.pcapng` | Missing physical run |
| Mac B packet capture | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/mac-b-udp-55448.pcapng` | Missing physical run |
| DSCP summary | `/private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/dscp-summary.txt` | Missing physical run |

TODO(human): [M05 direct route capture] -> Attach the actual Mac A and Mac B packet-capture paths before route PASS -> [direct link capture only / direct plus switch comparison / direct plus campus comparison]

## Physical Command Sequence

Use the same packet mode and UDP port for route, loopback, diagnostics, and
packet capture. The first measured route should be direct wired Ethernet.

Start DSCP packet capture on Mac B:

```bash
sudo tcpdump -i <mac-b-interface> -s 0 -vvv -w /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/mac-b-udp-55448.pcapng 'udp port 55448'
```

Run the UDP route receiver on Mac B. Add `--verdict pass` only after the route
metadata, capture correlation, and observed DSCP classification are known for
the measured physical run; otherwise leave the verdict as `partial`.

```bash
swift run open-lola udp-pcm-route-run --role receiver --bind-host <mac-b-ip> --peer <mac-a-ip> --port 55448 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-route-receiver.json --dscp 46 --route-kind directLink --route-label direct-link-reference --route-topology mac-to-mac-direct-cable --sender-label sender-mac --sender-host <mac-a-host> --sender-interface <mac-a-interface> --sender-ip <mac-a-ip> --receiver-label receiver-mac --receiver-host <mac-b-host> --receiver-interface <mac-b-interface> --receiver-ip <mac-b-ip> --link-rate-mbps <mbps> --vlan none --multicast-policy unicast-only --capture-point 'receiver tcpdump capture' --capture-correlated true --capture-notes 'Receiver capture matched expected packet count and timestamp window.' --dscp-observed <observed-dscp> --dscp-classification honored --verdict pass
```

Start DSCP packet capture on Mac A:

```bash
sudo tcpdump -i <mac-a-interface> -s 0 -vvv -w /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/mac-a-udp-55448.pcapng 'udp port 55448'
```

Run the UDP route sender on Mac A:

```bash
swift run open-lola udp-pcm-route-run --role sender --bind-host <mac-a-ip> --peer <mac-b-ip> --port 55448 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-route-sender.json --dscp 46
```

Run byte-exact loopback on Mac B:

```bash
swift run open-lola udp-pcm-loopback-run --session-id f11-route-comparison-2026-05-03 --role looper --bind-host <mac-b-ip> --peer <mac-a-ip> --port 55448 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-looper.json --debug-output /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-looper.jsonl
```

Run byte-exact loopback on Mac A with diagnostics:

```bash
swift run open-lola udp-pcm-loopback-run --session-id f11-route-comparison-2026-05-03 --role sender --bind-host <mac-a-ip> --peer <mac-b-ip> --port 55448 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-sender.json --diagnostics on --debug-output /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-sender.jsonl
```

Run standalone ICMP/traceroute diagnostics on Mac A:

```bash
swift run open-lola network-diagnostics-run --peer <mac-b-ip> --ping-count 5 --max-hops 8 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/network-diagnostics.json
```

Extract DSCP evidence from the captures:

```bash
tcpdump -nn -vvv -r /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/mac-a-udp-55448.pcapng 'udp port 55448' > /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/dscp-summary.txt
tcpdump -nn -vvv -r /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/mac-b-udp-55448.pcapng 'udp port 55448' >> /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/dscp-summary.txt
```

## Validation Commands

```bash
swift run open-lola validate-route-report /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-route-receiver.json
swift run open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-sender.json
swift run open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-looper.json
swift run open-lola validate-udp-pcm-loopback-session /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-sender.json /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/udp-pcm-loopback-looper.json
swift run open-lola validate-network-diagnostics-report /private/tmp/open-lola-m05-route-comparison-2026-05-03/direct/network-diagnostics.json
```

## Comparison Rule

Use UDP PCM echo RTT as the route latency comparison source:

- `udpAverageRttMicroseconds` from the F11 sender report is the UDP echo RTT
  comparison value;
- `oneWayEstimateMicroseconds` is `RTT / 2` only and is not proven one-way
  audio latency;
- ICMP ping average RTT and traceroute hop count are diagnostics only;
- ICMP cannot satisfy a route PASS guard, replace UDP loopback, or justify a
  larger playout target;
- DSCP classification must come from packet capture, not from the requested
  socket option.

For physical PASS, the route receiver report must still satisfy the M05 route
validator: physical route kind, measured duration, packet-count parity, no
documentation IPs, packet-capture correlation, DSCP classification, no loss or
late packets, one-packet playout target, and no hidden playout growth.
The runner now accepts those evidence fields directly so a valid physical run
can write a PASS-capable receiver report without hand-editing JSON.

## Local Surface Probe Results

Local probes were run only to verify the command surfaces:

```bash
.build/debug/open-lola udp-pcm-route-run --role receiver --bind-host 127.0.0.1 --peer 127.0.0.1 --port 55624 --sample-rate 2 --frames 1 --channels 2 --duration-seconds 10 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-route-receiver-matched.json --dscp 46
.build/debug/open-lola udp-pcm-route-run --role sender --bind-host 127.0.0.1 --peer 127.0.0.1 --port 55624 --sample-rate 2 --frames 1 --channels 2 --duration-seconds 10 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-route-sender-matched.json --dscp 46
.build/debug/open-lola validate-route-report /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-route-receiver-matched.json
.build/debug/open-lola udp-pcm-loopback-run --session-id f11-route-compare-local-2026-05-03 --role looper --bind-host 127.0.0.1 --peer 127.0.0.1 --port 55623 --sample-rate 2 --frames 1 --channels 2 --duration-seconds 8 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-loopback-looper.json --debug-output /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-loopback-looper.jsonl
.build/debug/open-lola udp-pcm-loopback-run --session-id f11-route-compare-local-2026-05-03 --role sender --bind-host 127.0.0.1 --peer 127.0.0.1 --port 55623 --sample-rate 2 --frames 1 --channels 2 --duration-seconds 8 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-loopback-sender.json --diagnostics on --debug-output /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-loopback-sender.jsonl
.build/debug/open-lola validate-udp-pcm-loopback-session /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-loopback-sender.json /private/tmp/open-lola-m05-route-comparison-2026-05-03/udp-pcm-loopback-looper.json
.build/debug/open-lola network-diagnostics-run --peer 127.0.0.1 --ping-count 2 --max-hops 4 --output /private/tmp/open-lola-m05-route-comparison-2026-05-03/network-diagnostics.json
.build/debug/open-lola validate-network-diagnostics-report /private/tmp/open-lola-m05-route-comparison-2026-05-03/network-diagnostics.json
.build/debug/open-lola udp-pcm-route-localhost-smoke
```

Observed local results:

- the UDP sender/receiver reports validated as `PARTIAL`;
- the localhost route smoke recorded 5 received packets, 0 lost packets, and
  `VERDICT: PARTIAL`;
- the byte-exact loopback session validator emitted `VERDICT: PARTIAL`;
- the loopback sender report recorded `byteExactEcho: true`, 16 packets sent, 6
  echoed, 10 lost, p50 UDP echo RTT 1512.125 microseconds, and embedded
  diagnostics comparing 1387.111 microseconds UDP average RTT to 91 microseconds
  ICMP average RTT;
- the standalone diagnostics report recorded 0 percent ICMP loss, 60
  microseconds ICMP average RTT, and traceroute blocked by local permissions;
- no local packet capture was attached, so DSCP remained `notTested`.

The local loss values are not physical route evidence. They reflect local
process scheduling and localhost timing in this workspace.

## Verdict

The F11 route-comparison workflow is implemented and locally surface-probed.
Physical M05 PASS remains blocked on the direct two-Mac sender/receiver run,
byte-exact loopback, ICMP/traceroute diagnostics, DSCP packet capture, and route
certification wrapper with packet-capture artifact paths.

VERDICT: PARTIAL

## Resume here

Run the physical command sequence on two Macs over the direct wired route, attach
the sender/receiver reports, sender/looper loopback reports, debug JSONL files,
network diagnostics report, DSCP summary, and Mac A/Mac B packet captures, then
rerun the validation commands and update this report with the measured physical
comparison.
