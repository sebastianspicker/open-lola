# F11 Network Loopback Diagnostics

Date: 2026-05-03
Status: source validation implemented; physical two-Mac evidence open
Verdict: PARTIAL

## Finding

The route layer needed a measurement mode that proves the UDP PCM path itself,
not only generic IP reachability. F11 adds a byte-exact UDP PCM loopback mode,
ICMP ping and traceroute diagnostics, and bounded debug traces. ICMP RTT is a
comparison baseline only; it is not treated as audio latency proof.

## Objective

Measure whether a peer can receive UDP PCM packets and echo the exact same
datagram bytes back without modifying payload, header, sequence, timestamp, or
sample format. Compare that UDP echo RTT with ICMP RTT and route hops so M05/F03
can distinguish raw direct-route behavior from generic network reachability.

## Assumptions

- Raw direct P2P remains the fastest-path default.
- UDP echo RTT/2 is recorded only as an estimate.
- Diagnostics are run outside the realtime audio callback path.
- Debug traces record metadata, sequence numbers, timing, and hashes only, not
  audio payload samples.

## Dependencies

- M04 UDP PCM packet contract.
- M05 route sender/receiver socket helpers.
- macOS `/sbin/ping` and `/usr/sbin/traceroute` when available.
- Packet capture remains required for a physical M05 PASS route.

## Affected Modules/Files

- `Sources/OpenLolaCore/UdpPcmLoopbackLatency.swift`
- `Sources/OpenLolaCore/NetworkDiagnostics.swift`
- `Sources/OpenLolaCore/DebugTrace.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/UdpPcmLoopbackLatencyTests.swift`
- `Tests/OpenLolaCoreTests/NetworkDiagnosticsTests.swift`
- `Tests/OpenLolaCoreTests/DebugTraceTests.swift`

## Implementation Sequence

1. Add loopback report schema, validation errors, config parser, and CLI
   validator.
2. Add exact-byte looper and sender modes over UDP PCM packets.
3. Add localhost loopback smoke for source-level verification.
4. Add macOS ping and traceroute parsers from fixture output.
5. Add bounded process wrappers that return PARTIAL reports when traceroute is
   blocked by sandboxing or permissions.
6. Add optional diagnostics comparison on loopback sender runs.
7. Add bounded debug trace output for socket and packet-event metadata.
8. Add explicit `sessionID` agreement fields and report-pair validation so the
   sender and looper can prove they ran the same role pair, packet mode, peer
   endpoints, port, and duration.
9. Print the exact reciprocal command for the other client from each loopback
   CLI run.
10. Update F03 route docs so loopback/ICMP/traceroute evidence is collected
   before long drift or faster-than-LoLa claims.
11. Harden debug output so sender or looper failures before report output still
   write a redacted JSONL trace when `--debug-output` is set.

## Current Source Surface

```bash
open-lola udp-pcm-loopback-run --session-id <id> --role sender|looper --bind-host <ip> --peer <ip> --port <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds <n> --output <path> [--dscp <0-63>] [--diagnostics on|off] [--debug-output <path>]
open-lola validate-udp-pcm-loopback-report <path>
open-lola validate-udp-pcm-loopback-session <path-a> <path-b>
open-lola udp-pcm-loopback-localhost-smoke
open-lola network-diagnostics-run --peer <ip> --ping-count <n> --max-hops <n> --output <path>
open-lola validate-network-diagnostics-report <path>
```

## Test Plan

```bash
swift test --filter UdpPcmLoopback
swift test --filter NetworkDiagnostics
swift test --filter DebugTrace
swift build
swift test
.build/debug/open-lola udp-pcm-loopback-localhost-smoke
.build/debug/open-lola validate-udp-pcm-loopback-session <sender-report> <looper-report>
.build/debug/open-lola network-diagnostics-run --peer 127.0.0.1 --ping-count 2 --max-hops 4 --output /private/tmp/open-lola-network-diagnostics.json
.build/debug/open-lola validate-network-diagnostics-report /private/tmp/open-lola-network-diagnostics.json
```

## Acceptance Criteria

- Sender report validates byte-exact echo and records packets sent, echoed,
  lost, duplicate, out-of-order, p50/p95/p99/max RTT, jitter, and RTT/2
  estimate.
- Looper sends received datagram bytes back unchanged.
- Sender and looper reports validate as one session only when `sessionID`,
  reciprocal roles, packet mode, port, peer endpoints, and duration match.
- CLI output prints a concrete reciprocal command for the other client.
- ICMP and traceroute failures produce a valid PARTIAL report, not a crash.
- Debug mode does not modify datagrams or verdict logic.
- Debug failure traces are written even when bind/connect fails before report
  output; traces include redacted run configuration, socket bind/connect state,
  and failure reason, but never payload bytes.
- Physical PASS remains owned by M05/F03 route certification, not by localhost
  smoke or ICMP reachability.

## Rollback/Recovery

If physical loopback gives unstable results, keep the report as PARTIAL or FAIL
and rerun with packet capture on both peers. Do not delete failed reports; mark
why they failed and run a new report.

## Progress Checklist

- [x] Add tests for config parsing, validation, exact echo, parser behavior, and
  debug trace sanitization.
- [x] Implement source models and CLI surfaces.
- [x] Add localhost smoke.
- [x] Add validation report.
- [x] Add session agreement schema, reciprocal CLI command, and pair validator.
- [x] Add validation report for session agreement.
- [x] Harden debug traces for sender/looper pre-report failures while keeping
  payload bytes excluded.
- [ ] Run direct two-Mac sender/looper measurement.
- [ ] Run switch and campus diagnostics with packet-capture permission.

## Resume here

Connect two Macs on a direct static subnet. Start the looper on Mac B, run the
sender on Mac A with diagnostics on, save both reports, then collect packet
capture evidence for F03/M05.

VERDICT: PARTIAL
