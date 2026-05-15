# F11 Direct Link Loopback Report

Date: 2026-05-03
Companion: [F11 Network Loopback Diagnostics](../implementation-companions/F11_NETWORK_LOOPBACK_DIAGNOSTICS.md)
Route context: [F03 P2P Network Route](../implementation-companions/F03_P2P_NETWORK_ROUTE.md)
Milestone: [M05 Mac-To-Mac Route Certification](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)
Status: hardware-gated direct-link evidence pending
Verdict: PARTIAL

## Scope

This report is the F11 direct two-Mac loopback evidence record. It covers the
required looper-on-Mac-B and sender-on-Mac-A run with `--diagnostics on` and
`--debug-output`, then validates the sender report, looper report, and reciprocal
session agreement.

It does not claim direct-link PASS yet. The current workspace has no attached
Mac A/Mac B sender and looper JSON reports, packet captures, or direct-link
debug JSONL files for this row.

## Planned Direct-Link Setup

| Field | Planned value | Evidence state |
|---|---|---|
| Session ID | `f11-direct-2026-05-03` | Pending physical run |
| Mac A role | sender | Pending physical run |
| Mac B role | looper | Pending physical run |
| Mac A IP | `192.0.2.10` | Documentation placeholder; pending private run confirmation |
| Mac B IP | `192.0.2.11` | Documentation placeholder; pending private run confirmation |
| UDP port | `55448` | Pending physical run |
| Packet mode | 48 kHz, 32 frames, 2 channels, int16 little-endian | Pending physical run |
| Duration | 60 seconds | Pending physical run |
| Diagnostics | sender `--diagnostics on` | Pending physical run |
| Debug trace | sender and looper `--debug-output` JSONL | Pending physical run |

TODO(human): [F11 direct-link addresses] -> Replace the documentation placeholder Mac A and Mac B static IPs with the measured interface IPs in private run notes before claiming PASS -> [use measured direct-link subnet / choose another static subnet / document an existing direct-link subnet]

TODO(human): [F11 packet-capture interface] -> Record the actual Mac A and Mac B capture interfaces before claiming PASS -> [en5 / en6 / other measured wired interface]

The command examples below use TEST-NET documentation addresses. Replace them
with measured private direct-link addresses in private run notes before running
or claiming PASS.

## Artifact Paths

| Artifact | Required path | State |
|---|---|---|
| Mac A sender report | `/private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-sender.json` | Missing |
| Mac B looper report | `/private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-looper.json` | Missing |
| Mac A sender debug JSONL | `/private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-sender.jsonl` | Missing |
| Mac B looper debug JSONL | `/private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-looper.jsonl` | Missing |
| Mac A packet capture | `/private/tmp/open-lola-f11-direct-2026-05-03/mac-a-udp-55448.pcapng` | Missing |
| Mac B packet capture | `/private/tmp/open-lola-f11-direct-2026-05-03/mac-b-udp-55448.pcapng` | Missing |

Packet captures should use the same packet window as the sender/looper reports
and the same UDP port filter. Store the capture files outside the repo unless a
small, curated fixture is intentionally added later.

## Mac B Looper

Start packet capture first on Mac B, replacing `<mac-b-interface>` with the
measured wired interface:

```bash
sudo tcpdump -i <mac-b-interface> -w /private/tmp/open-lola-f11-direct-2026-05-03/mac-b-udp-55448.pcapng 'udp port 55448'
```

Then run the looper on Mac B:

```bash
swift run open-lola udp-pcm-loopback-run --session-id f11-direct-2026-05-03 --role looper --bind-host 192.0.2.11 --peer 192.0.2.10 --port 55448 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-looper.json --debug-output /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-looper.jsonl
```

## Mac A Sender

Start packet capture first on Mac A, replacing `<mac-a-interface>` with the
measured wired interface:

```bash
sudo tcpdump -i <mac-a-interface> -w /private/tmp/open-lola-f11-direct-2026-05-03/mac-a-udp-55448.pcapng 'udp port 55448'
```

Then run the sender on Mac A with diagnostics and debug tracing enabled:

```bash
swift run open-lola udp-pcm-loopback-run --session-id f11-direct-2026-05-03 --role sender --bind-host 192.0.2.10 --peer 192.0.2.11 --port 55448 --sample-rate 48000 --frames 32 --channels 2 --duration-seconds 60 --output /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-sender.json --diagnostics on --debug-output /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-sender.jsonl
```

## Validation Commands

Run these after both JSON reports are copied or available on the same Mac:

```bash
swift run open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-sender.json
swift run open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-looper.json
swift run open-lola validate-udp-pcm-loopback-session /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-sender.json /private/tmp/open-lola-f11-direct-2026-05-03/udp-pcm-loopback-looper.json
```

Expected validator state for a successful direct run:

- sender and looper reports validate individually;
- session validator emits the shared `sessionID`;
- sender metrics show `byteExactEcho: true`, `lostPackets: 0`,
  `duplicatePackets: 0`, and `outOfOrderPackets: 0`;
- looper metrics show the same echoed packet count as the sender;
- sender diagnostics include ICMP comparison data when ping is permitted;
- packet captures exist on both Macs and cover the report time window.

The sender RTT from this report is the raw-route baseline for F12. Do not close
Q012 or accept NAT/forwarder compatibility evidence until the F12 report records
the same-route raw-vs-NAT latency comparison.

## Current Validation State

The requested physical run was not executed in this workspace because the second
Mac, direct wired subnet, and packet-capture files are not available here.
Therefore the sender report, looper report, reciprocal session validation, and
packet-capture attachment are pending. The raw-vs-NAT comparison is also
pending because no accepted F11 raw-route RTT exists in this workspace.

Local localhost loopback artifacts under `/private/tmp` are not accepted for
this row because the required topology is direct two-Mac Ethernet.

## Verdict

F11 direct-link loopback remains hardware-gated.

VERDICT: PARTIAL

## Resume here

Run the Mac B looper command first, run the Mac A sender command with
`--diagnostics on` and `--debug-output`, stop both packet captures after the
sender exits, then paste the validator output and replace the missing artifact
states above with the concrete sender report, looper report, packet-capture, and
debug JSONL paths.
