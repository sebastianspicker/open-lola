# F11 Session Agreement Validation Report

Date: 2026-05-03
Companion: [F11 Network Loopback Diagnostics](../implementation-companions/F11_NETWORK_LOOPBACK_DIAGNOSTICS.md)
Status: PARTIAL

## Scope

This report validates the source-level F11 session agreement addition. It proves
that loopback reports now carry an explicit `sessionID`, reciprocal roles,
local/peer endpoints, port, packet mode, and duration, and that the CLI can
validate a sender/looper report pair for the same session.

It does not claim physical route PASS. Direct two-Mac packet-captured loopback
evidence remains open.

## Commands

```bash
swift test --filter UdpPcmLoopback
swift test
.build/debug/open-lola udp-pcm-loopback-localhost-smoke
.build/debug/open-lola udp-pcm-loopback-run --session-id f11-audit-session-pass4 --role looper --bind-host 127.0.0.1 --peer 127.0.0.1 --port 55448 --sample-rate 5 --frames 1 --channels 2 --duration-seconds 2 --output /private/tmp/open-lola-f11-session-pass4-looper.json --debug-output /private/tmp/open-lola-f11-session-pass4-looper.jsonl
.build/debug/open-lola udp-pcm-loopback-run --session-id f11-audit-session-pass4 --role sender --bind-host 127.0.0.1 --peer 127.0.0.1 --port 55448 --sample-rate 5 --frames 1 --channels 2 --duration-seconds 2 --output /private/tmp/open-lola-f11-session-pass4-sender.json --diagnostics off --debug-output /private/tmp/open-lola-f11-session-pass4-sender.jsonl
.build/debug/open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-f11-session-pass4-sender.json
.build/debug/open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-f11-session-pass4-looper.json
.build/debug/open-lola validate-udp-pcm-loopback-session /private/tmp/open-lola-f11-session-pass4-sender.json /private/tmp/open-lola-f11-session-pass4-looper.json
```

## Source Results

- `swift test --filter UdpPcmLoopback` passed with 11 tests.
- `swift test` passed with 375 tests.
- New tests reject mismatched role pair, packet mode, port, peer endpoint, and
  duration.
- The loopback CLI now requires `--session-id`.
- Each `udp-pcm-loopback-run` prints a concrete `reciprocal-command` for the
  other client.
- `validate-udp-pcm-loopback-session` validates two reports only when their
  session agreement is reciprocal.
- UDP `ECONNREFUSED` during sender echo receive is now recorded as missing echo
  instead of aborting before a report can be written.

## Runtime Results

- The in-process localhost smoke emitted `VERDICT: PARTIAL` with 5 packets sent,
  5 echoed, 0 lost, and `byteExactEcho: true`.
- The two-process localhost session wrote sender and looper reports with matching
  session agreement fields and `validate-udp-pcm-loopback-session` emitted
  `VERDICT: PARTIAL`.
- The two-process localhost sender report recorded 10 packets sent, 0 echoed,
  and 10 lost. This is valid failure evidence for the local run, not route PASS.

## Open Evidence

- Direct two-Mac session with the reciprocal command copied to the second Mac.
- Packet capture on both peers.
- Successful byte-exact echo over direct link.
- ICMP/traceroute comparison for the same `sessionID`.
- Switch and campus variants after direct-link evidence exists.

## Verdict

F11 session agreement is implemented and validated at the source/CLI level.
Physical two-client latency evidence remains open.

VERDICT: PARTIAL

## Resume here

Run the printed reciprocal command on the second Mac, keep the same `sessionID`
on both sides, then validate the two reports with
`open-lola validate-udp-pcm-loopback-session <sender-report> <looper-report>`.
