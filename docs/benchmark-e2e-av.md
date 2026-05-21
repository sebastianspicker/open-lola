# End-to-End AV Benchmark Methodology

Date: 2026-05-21
Status: source-level benchmark contract implemented; physical evidence open
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Core Audio callback metrics, AVFoundation/Blackmagic capture metrics, VideoToolbox metrics, and process resource counters | `public API` |
| direct UDP, DSCP, PTP, AVB, packet age, jitter, loss, and throughput metrics | `public standard` |
| open-lola latency profiles and profile promotion gates | `original open-lola design` |
| two-peer hardware evidence before PASS | `experimentally derived requirement` |
| direct UDP over a measured LAN/direct-link route as benchmark gold standard | `implementation hypothesis` |

## Objective

Benchmark the full system as users will run it: two peers, live multichannel
audio, one or more video streams, direct peer-to-peer media, explicit profiles,
and machine-readable reports.

## Implemented Source Surface

M13 now has a source-level aggregate report contract:

- `E2EBenchmarkReport` records two-peer hardware identity, component report IDs,
  profile rows, impairment rows, recovery/shutdown metrics, thresholds, and a
  machine-readable verdict.
- `E2EBenchmarkReport.validate()` rejects `PASS` without measured physical
  two-peer evidence, complete profile rows, video metrics for video-enabled
  profiles, impairment rows, recovery events, and clean shutdown evidence.
- `E2EBenchmarkSyntheticSmoke` emits a valid `PARTIAL` report for source-shape
  and CLI validation.
- `E2EBenchmarkRunner` aggregates validated latency, integrated A/V, video
  transport, and Apple Silicon performance reports into the M13 report shape.

The CLI surface is:

```bash
open-lola e2e-benchmark-synthetic-smoke
open-lola validate-e2e-benchmark-report <report.json>
open-lola e2e-benchmark-run --audio-benchmark <latency.json> --integrated-av <integrated-av.json> --video-transport <video-transport.json> --performance-audit <performance.json> --duration-seconds <n> --output <e2e.json>
```

## Required Benchmarks

Audio:

- audio callback duration p50/p95/p99/max;
- audio one-way latency;
- audio round-trip latency;
- MADI max stable channel count;
- 8/16/32/64-frame stability;
- underrun and overrun counts;
- RX buffer depth over time;
- clock drift and correction events.

Network:

- packet age p50/p95/p99/max;
- jitter distribution;
- packet loss, late, duplicate, and reordered packets;
- DSCP requested/observed/classified;
- direct-link throughput;
- packet capture correlation point;
- reconnect and shutdown timing.

Video:

- Blackmagic capture latency;
- encode or packetization latency;
- video receive/reassembly latency;
- render/output latency;
- frame drop policy behavior;
- multi-video CPU/GPU/memory cost;
- audio impact with video active.

Integrated:

- end-to-end AV latency;
- audio-only versus audio+video versus audio+multi-video matrix;
- Direct Audio First, Balanced AV, Multi-Video Performance, and WAN Stable
  profiles;
- process CPU, GPU, and resident memory;
- hot-path allocation counts.

## Two-Peer Matrix

| Row | Audio | Video | Network | Expected verdict |
|---|---|---|---|---|
| audio-only direct | full MADI TX/RX | off | direct UDP | first PASS candidate |
| balanced AV | full MADI TX/RX | one Blackmagic stream | direct UDP | comparison row, not fastest claim |
| fastest AV | full MADI TX/RX | one Blackmagic stream | direct UDP | PASS only if audio equals audio-only direct |
| audio plus multi-video | full MADI TX/RX | two or more streams | direct UDP | PASS only in multi-video profile |
| WAN stable | full MADI TX/RX | optional reduced video | WAN/NAT | separate profile, not fastest PASS |

## Method

1. Record hardware inventory on both peers.
2. Lock sample rate, channel count, frames per packet, and latency profile.
3. Run audio-only baseline.
4. Run full-duplex audio direct P2P.
5. Run balanced AV and record its visible audio cost.
6. Run fastest AV with preview off, direct RX, latest-frame video, and no hidden
   RX growth; compare against the audio-only fastest baseline.
7. Add multiple video streams and compare again.
8. Run packet-capture correlation and DSCP read-back.
9. Run recovery tests: peer restart, network interruption, clean shutdown.
10. Write one aggregate E2E report with source report IDs and raw metrics.

Concrete two-peer evidence commands for the direct AV PASS gate:

```bash
mkdir -p reports/captures reports/evidence
sudo tcpdump -i en6 -vvv -w reports/captures/direct-p2p-av-mac-b.pcapng \
  'udp and (port 57012 or port 57013 or port 57014)'
tcpdump -nn -vvv -r reports/captures/direct-p2p-av-mac-b.pcapng 'ip' \
  | tee reports/evidence/dscp-observation.txt
sntp -d time.apple.com | tee reports/evidence/clock-sync.txt
open-lola verify-direct-p2p-session-evidence-bundle \
  reports/direct-p2p-av-mac-b.json .
```

`DirectPeerSessionReport` PASS evidence must point to the capture artifact,
classify DSCP from the receiver-side read-back, and attach a clock artifact with
the measured maximum offset. Current PASS validation accepts only honored DSCP
with an observed read-back value; rewritten, ignored, harmful, or unobserved
DSCP remains trace evidence, not PASS evidence. Schema validation is portable
and checks declarations only; PASS promotion must also run the evidence-bundle
verifier so the declared artifacts exist and match their SHA-256 hashes. Fastest
AV PASS additionally needs an audio-only fastest baseline report path and a
comparison artifact proving latency, RX buffer policy, loss, and jitter did not
regress.

## Acceptance Criteria

- all component reports validate;
- every latency component is visible in frames, packets, microseconds, or bytes;
- no audio callback deadline misses in accepted profile;
- no hidden audio buffer growth;
- zero underruns for Direct Audio First;
- video drops before audio metrics change;
- fastest AV cannot pass unless its audio latency, playout target, underruns,
  overruns, loss, and jitter remain equal to the audio-only fastest baseline
  within one audio frame at the selected sample rate;
- reconnect completes or fails cleanly without device callback leaks;
- final report ends in `VERDICT: PASS`, `VERDICT: FAIL`, or
  `VERDICT: PARTIAL`.

## Current Verification State

The source-shape benchmark and hardware-validation smokes currently pass as
contract checks but remain non-physical evidence:

```bash
open-lola e2e-benchmark-synthetic-smoke
open-lola hardware-validation-synthetic-smoke
open-lola current-evidence-status-matrix
open-lola goal-completion-audit-run --output <report.json>
open-lola validate-goal-completion-audit-report <report.json>
```

The latest unsandboxed local completion audit,
`/private/tmp/open-lola-goal-completion-audit-2026-05-21-doc-refresh-unsandboxed.json`,
still reports `VERDICT: PARTIAL` with 21 blockers. It maps 93 items: 77 pass,
16 partial, and 16 blocked. The benchmark/runtime blocker classes are invisible
RME MADI hardware, missing physical receiver-side RME receive/mix evidence,
invisible Blackmagic/ATEM/DeckLink/UltraStudio hardware, missing physical
two-peer/direct-route run evidence, no visible Developer ID Application signing
identity, and missing notarization, Gatekeeper, clean-Mac, and field evidence.
The same audit also keeps public release approval blocked on final source and
documentation license decisions, third-party notices, fixture provenance,
reviewer signoff, and release approval.

## Resume here

Start with `open-lola e2e-benchmark-synthetic-smoke` to validate the source
shape. For physical closure, collect measured component reports on two Apple
Silicon peers, aggregate them with `open-lola e2e-benchmark-run`, and validate
the output with `open-lola validate-e2e-benchmark-report`. Until then, keep
benchmark reports `PARTIAL`.

VERDICT: PARTIAL
