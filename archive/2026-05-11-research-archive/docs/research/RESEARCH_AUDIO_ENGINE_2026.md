# Open Lola Audio Engine Research 2026
Verdict: PARTIAL

Back to companion: [RESEARCH_COMPANION_2026.md](RESEARCH_COMPANION_2026.md)

Date: 2026-05-02  
Status: internal research ledger, current after public background-lane restructure
Evidence: [RESEARCH_EVIDENCE_MATRIX_2026.md](RESEARCH_EVIDENCE_MATRIX_2026.md),
matters 1-24 and 74-75

Source refresh checked 2026-05-02: Apple Core Audio, Apple Audio Workgroups,
and IETF RFC 6716 still support the current plan. See
[../mac-port/sota-open-question-matrix.md](../mac-port/sota-open-question-matrix.md)
for milestone routing.

## Hard Rule

No PLC, codec, retransmission, QoS trick, UI feature, video path, lighting path,
or recording feature may increase default audio playout latency.

## Audio Engine Decision

The fastest implementation target is a headless Core Audio engine using
HAL/AUHAL or direct `AudioDeviceIOProc`, uncompressed PCM, and one UDP datagram
per audio block. Swift/AppKit/SwiftUI may configure and observe the engine, but
must not own the audio deadline.

| Topic | Decision | Implementation rule |
|---|---|---|
| Core Audio HAL/AUHAL/IOProc | adopt now | Use the lowest practical macOS callback path before wrappers. |
| Device buffer probing | adopt now | Request, verify, and log 16/32/64/128 frame behavior. |
| Device latency properties | adopt now | Log hardware and stream latency, but accept only measured loopback. |
| UDP PCM packet contract | adopt now | One audio block per datagram in fastest mode. |
| JackTrip, AOO, SonoBus references | benchmark | Study packet/thread diagnostics; do not inherit adaptive default buffering. |
| Burg/AR PLC and music PLC metrics | benchmark | Same-deadline only; no larger playout target. |
| Tilt Loss or ML PLC | defer | Only after a non-ML baseline meets callback deadlines. |
| Opus/WebRTC/browser media | reject | Not fastest default; codecs and browser stacks add opaque buffering. |

## Core Audio Contract

The first real prototype should enumerate devices and streams, then record:

- nominal and actual sample rate;
- supported and accepted buffer frame sizes;
- `kAudioDevicePropertyLatency` and stream latency where available;
- safety offset where available;
- channel map and sample format;
- aggregate-device state;
- callback duration p50, p95, p99, max, and missed deadlines;
- analog loopback round-trip and corrected one-way estimate.

The API-reported latency is diagnostic only. The acceptance metric is measured
analog end-to-end audio latency.

## Callback Safety Contract

Allowed inside the callback:

- stack work;
- fixed-size preallocated buffers;
- atomic counters;
- single-producer/single-consumer ring push/pop;
- branch-bounded sample copy, conversion, and mix;
- timestamp capture;
- silence or same-deadline PLC for a missing block.

Forbidden inside the callback:

- heap allocation;
- locks and condition variables;
- socket calls;
- DNS;
- logging;
- file I/O;
- Objective-C or Swift reference churn on the hot path;
- unbounded codec, resampler, or PLC work;
- UI dispatch;
- blocking telemetry.

If a receive block is unavailable at the deadline, output silence or a
same-deadline substitute. Do not wait. If a send block cannot be published, drop
the send block and increment a counter. Do not block.

## Packet And Playout Contract

Fastest-mode packet fields should be minimal and fixed-size:

- protocol/version field;
- sequence number;
- sender frame index;
- sender host timestamp;
- sample rate;
- frames per packet;
- channel count;
- sample format;
- header guard or CRC;
- raw PCM payload.

The default receive target is zero or one audio block. Retransmission waits,
adaptive jitter growth, and comfort buffers are rejected for fastest default.
They can exist only as explicitly labeled fallback modes.

## Thread Model

| Thread or lane | Owns | Must not do |
|---|---|---|
| Core Audio callback | Device deadline, playout, capture, timestamp handoff | Sockets, logs, allocation, locks, UI, unbounded work. |
| Network receive | UDP receive, packet validation, late/drop counters, ring publish | Block the callback or resize playout target. |
| Network send | UDP send from already-copied blocks | Wait for UI/control or allocate on the deadline path. |
| Telemetry/control | Counters, reports, configuration | Run in the audio callback or change latency silently. |
| UI/recording | Operator view, setup, files | Own default playout timing. |

Audio Workgroups are a benchmark item, not magic. Use them only for bounded
helper threads that demonstrably reduce missed deadlines compared with the
simpler callback plus network-thread design.

## Source Patterns To Reuse Carefully

JackTrip confirms the value of UDP PCM, packet headers, sequence tracking,
nonblocking network loops, QoS hooks, and visible loss/underrun counters.

AOO confirms the value of separating control/data messages and shows how jitter
buffers and resend behavior can be structured. Its resend waits are not a
fastest-default policy.

SonoBus confirms the value of user-facing diagnostics, latency measurement, and
practical PCM/Opus tradeoffs. Its automatic jitter growth is not a
fastest-default policy.

## Required Probes

1. Core Audio loopback: accepted buffer size, callback p99/max, missed
   deadlines, reported latency, analog latency.
2. UDP PCM lane: packet age at playout, late/drop counters, sequence gaps,
   queue depth, and fixed target proof.
3. PLC lane: compare silence, repeat, Burg/AR, and any ML candidate with no
   playout-target increase.
4. Drift lane: compare fixed sample-rate operation, timestamp-only reporting,
   and bounded fractional resampling outside the callback.
5. Long run: 30 minutes on wired LAN with no default buffer growth.
