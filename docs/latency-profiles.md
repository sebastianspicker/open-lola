# Latency Profiles

Date: 2026-05-04  
Status: source contract implemented; physical evidence pending  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Safe low-latency default | `implementation hypothesis` |
| 16-frame profile as explicit ultra-low-latency mode | `original open-lola design` |
| 8-frame profile as experimental opt-in | `experimentally derived requirement` |
| Physical RME acceptance for PASS | `experimentally derived requirement` |

## Profile Summary

| Profile | Frame target | 48 kHz block time | 96 kHz block time | Default RX |
|---|---:|---:|---:|---|
| Safe Low Latency | 32, fallback 64 | 0.667 ms / 1.333 ms | 0.333 ms / 0.667 ms | direct |
| Ultra Low Latency 16 | 16 | 0.333 ms | 0.167 ms | direct |
| Extreme Low Latency 8 | 8 | 0.167 ms | 0.083 ms | direct |

## Session AV Profiles

The M07 source implementation adds session-level profiles that include audio,
video, network, buffering, and recovery behavior.

| Profile | Audio target | RX policy | Video policy | Network policy |
|---|---:|---|---|---|
| Direct Audio First | lowest stable hardware buffer | direct only | video disabled | direct UDP media |
| Balanced AV | measured low buffer | small fixed RX only | stable single-stream pacing | direct UDP media |
| Multi-Video Performance | measured safe buffer | small or adaptive RX | drop video before audio latency grows | direct UDP media with stream IDs |
| WAN Stable | continuity buffer | stable/WAN RX only | continuity over frame completeness | WAN/NAT profile, relay only future fallback |

Profile negotiation is part of the original open-lola control protocol. A peer
may advertise several supported profiles, but the accepted session profile must
name:

- sample rate, sample format, channel count, and channel map;
- audio buffer frames and RX policy;
- video stream count, frame format, resolution, frame rate, and drop policy;
- control channel address and media channel address;
- benchmark class required before claiming PASS.

The session must never silently upgrade a faster profile to a buffered profile.
Every added audio frame, network packet target, video queue, or recovery buffer
must appear in the latency budget and report. `SessionLatencyProfilePolicy`
records the default RX profile, allowed RX set, fastest PASS eligibility,
benchmark-evidence requirement, video-pressure policy, and continuity priority.

These are buffer-duration calculations only. They are not end-to-end latency
claims. Device safety offsets, hardware latency, packetization, route age,
playout target, and receiver output latency must be added separately.

The executable source contract lives in `LatencyProfilePolicy`,
`LatencyProfileSelection`, `LatencyProfileBudget`, `LatencyProfileEvidence`,
`SessionLatencyProfilePolicy`, and `SessionLatencyProfileBenchmarkMetrics`.
Synthetic evidence can validate source shape, but PASS requires measured
physical RME/direct-route evidence.

## Safe Low Latency

Intent:

- default fastest profile for normal direct LAN or excellent P2P links;
- broadest stable professional hardware path;
- no hidden buffer growth.

Requirements:

- 32 frames preferred, 64 frames fallback;
- 48 kHz and 96 kHz benchmark rows;
- direct RX profile by default;
- 0 or 1 block playout target;
- no underruns, no callback deadline misses, no allocation warnings;
- PASS only with physical route and hardware evidence.

## Ultra Low Latency 16

Intent:

- explicit opt-in profile for capable RME/direct-route rigs;
- not a default until long-run stability is proven.

Requirements:

- 16-frame Core Audio buffer accepted by the device;
- RME/direct-route gate for PASS;
- CPU scheduling headroom measured at p99 and max;
- packetization benchmark under selected channel count;
- direct RX by default, small RX only with visible latency cost;
- separate benchmark report and rollback profile.

CLI/config opt-in:

```sh
open-lola audio-loopback-run --input-uid <rme-uid> --output-uid <rme-uid> \
  --sample-rate 48000 --frames 16 --latency-profile ultraLowLatency16 \
  --duration-seconds 1800 --output <report.json>
```

Acceptance:

- no underruns in the configured duration;
- no callback deadline misses;
- no hidden buffers;
- measured route packet age stays within the profile budget;
- selected channel count is explicitly measured.

## Extreme Low Latency 8

Intent:

- experimental profile for measuring the lower bound on this Mac/RME path;
- always opt-in with visible dropout risk.

Requirements:

- 8-frame Core Audio buffer accepted and applied;
- no default promotion from 16/32 frames;
- max stable channel count measured separately;
- user-visible warning in CLI/UI configuration;
- callback allocation and scheduling probes enabled;
- no PASS without long-run physical evidence.

CLI/config opt-in:

```sh
open-lola audio-loopback-run --input-uid <rme-uid> --output-uid <rme-uid> \
  --sample-rate 48000 --frames 8 --latency-profile extremeLowLatency8 \
  --experimental-8-frame true --duration-seconds 7200 --output <report.json>
```

Acceptance:

- experimental `PARTIAL` until long-run RME evidence exists;
- no hidden RX buffer growth;
- no video, lighting, UI, recording, or matrix work on audio-critical threads;
- measurable rollback to 16 or 32 frames.

## RX Buffer Modes

The milestone implementation must expose the following buffer modes as explicit
configuration values:

| Mode | Purpose | Fastest eligible |
|---|---|---|
| direct | no extra receiver buffering except same-deadline handoff | yes |
| 16-frame playout | ultra-low-latency playout target for measured direct routes | yes, only with evidence |
| 8-frame experimental | lower-bound experiment, never default | no, until long-run evidence exists |
| small RX buffer | fixed 1-2 packet jitter guard | no fastest claim unless report says so |
| adaptive RX buffer | bounded target changes outside callback | no |
| WAN stable | continuity under WAN jitter | no |

Direct Audio First defaults to direct mode. Balanced AV can use small RX after
measurement. Multi-Video Performance can use small or adaptive RX when video
traffic creates measurable jitter. WAN Stable always trades latency for
continuity.

## Packetization Strategy

Small buffers increase packet rate. The media sender must:

- preallocate packet and fragment buffers;
- use deadline-based sequence numbers;
- keep v2 fragments under MTU;
- reject channel counts whose fragment count cannot fit the deadline;
- use `float32LittleEndian` only when bandwidth and CPU allow it;
- use `int16LittleEndian` only as an explicit bandwidth profile.

## Benchmark Report Fields

M07 benchmark reports can carry `sessionProfileMetrics` with:

- negotiated session profile and RX profile;
- callback duration p99;
- route age and packet age p50/p95/p99/max;
- jitter p50/p95/p99/max;
- underrun and overrun counts;
- added buffer cost in frames, packets, and microseconds;
- a fastest-PASS claim flag that rejects buffered session profiles.

The source smoke command is:

```sh
open-lola latency-profile-benchmark-synthetic-smoke --output <report.json>
open-lola validate-latency-benchmark-report <report.json>
```

## Test Method

Tests first:

- profile model validation is covered by `LatencyProfileTests`;
- 16-frame configuration is accepted only when opt-in, RME, direct route, and
  hardware support are present;
- 8-frame configuration requires experimental opt-in and warning
  acknowledgement;
- theoretical buffer latency, packet rate, and payload bandwidth are calculated
  for 48 kHz and 96 kHz;
- session-profile-to-RX mapping rejects incompatible combinations before
  media starts;
- benchmark, tuning, endpoint loopback, and RME fastest-path tests reject PASS
  when physical RME/direct-route evidence is absent.

VERDICT: PARTIAL
