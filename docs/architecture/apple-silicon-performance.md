# Apple Silicon Performance Plan

Date: 2026-05-04  
Status: low-latency Apple Silicon implementation plan  
Verdict: PARTIAL

## Evidence Labels

| Design choice | Label |
|---|---|
| Core Audio realtime callbacks, Dispatch QoS, mach continuous time, Metal, VideoToolbox, CoreMedia, CoreVideo | `public API` |
| UDP media, DSCP, direct LAN, PTP, and OS scheduling constraints | `public standard` |
| open-lola profile separation and visible buffer accounting | `original open-lola design` |
| Hot-path allocation and latency benchmark acceptance | `experimentally derived requirement` |
| Audio-critical thread priority over video and UI | `implementation hypothesis` |

## Objective

Use Apple Silicon headroom without hiding latency in queues, allocations, or
format conversions. The fastest implementation is the one with the fewest
unbounded operations on the realtime path.

## Critical Path Rules

- no blocking IO in the audio callback;
- no heap allocation in the audio callback;
- no locks or unbounded waits in the audio callback;
- no logging, JSON, file writes, or report generation in the callback;
- no UI, video, lighting, discovery, or negotiation on the audio thread;
- no hidden sample-rate conversion;
- no hidden buffer growth;
- every queue, ring, and device buffer appears in the latency budget.

## Hot-Path Data Movement

Priority order:

1. Use device-native sample format when it avoids conversion.
2. Use preallocated interleaved deadline buffers.
3. Packetize by referencing or copying from preallocated slabs outside the
   callback.
4. Avoid `Data` and `[UInt8]` conversion in media hot paths after the prototype
   contract is proven.
5. Keep video pixel buffers in CVPixelBuffer/IOSurface/Metal-compatible memory
   when possible.
6. Encode/decode only when measured end-to-end latency improves.

## Worker Separation

| Worker | QoS | Work |
|---|---|---|
| audio callback | realtime/device-owned | copy/push/pull fixed buffers and counters |
| audio network TX | userInteractive or time-constrained equivalent | packetize and send audio datagrams |
| audio network RX | userInteractive or time-constrained equivalent | receive, reassemble, enqueue playout |
| video capture | userInitiated | capture frames and drop before backlog |
| video encode/packetize | userInitiated | raw/intra/VideoToolbox processing |
| video RX/render | userInitiated | reassemble, drop, render/output |
| control/session | utility or userInitiated | negotiation and recovery |
| observability | utility | metrics snapshots and reports after stop |
| UI | main | read-only status and commands |

## Benchmark Instrumentation

Add measured counters for:

- callback duration;
- callback deadline misses;
- packetization time;
- depacketization/reassembly time;
- socket send/receive latency;
- RX queue depth;
- allocation count in hot path;
- memory bandwidth estimate for audio/video copies;
- CPU core usage;
- GPU work duration for Metal/VideoToolbox paths;
- process resident memory.

## Source Implementation

The source-level M12 implementation is now `PerformanceAuditReport`.
It is intentionally a gate, not a physical benchmark substitute.

Implemented surfaces:

- `PerformanceAuditReport` validates hot-path safety, copy documentation,
  worker separation, raw-before-accelerated benchmark decisions, source report
  references, profile report references, machine/process context, and
  machine-readable verdicts.
- `AppleSiliconRuntimePolicy` makes the Apple Silicon assumptions explicit:
  native arm64 rather than Rosetta, Dispatch QoS rather than core pinning,
  device-owned audio callbacks, low-copy unified-memory video boundaries,
  no CPU/GPU readback round trip on the audio-critical path, and acceleration
  only after a raw low-copy baseline.
- `PerformanceAuditSyntheticSmoke` emits a valid `PARTIAL` source report.
- `RealtimeAudioHandoffMetrics` exposes maximum capture-ring occupancy,
  maximum playout queue depth, packetization duration, depacketization duration,
  drops, underruns, and allocation warnings.
- `UdpMediaMetrics` exposes packetization and depacketization duration counters
  for the media envelope.
- `VideoTransportReport` carries optional video packetization, reassembly,
  frame-age, and queue-depth counters.
- `LatencyBenchmark.measure` is the small benchmark helper used by source
  smokes and synthetic video transport timing.
- The CLI exposes:

```bash
open-lola performance-audit-synthetic-smoke
open-lola validate-performance-audit-report <path>
```

PASS is rejected unless the report is measured on physical Apple Silicon
evidence, the Apple Silicon runtime policy is satisfied, realtime audio
surfaces have no allocation, blocking IO, logging, or unsafe lock warnings,
every retained copy is documented and measured, video and UI workers cannot
block audio, Metal and VideoToolbox decisions reference a raw low-copy baseline,
and safe, ultra, and experimental profile reports are present.

## Affected Files

- `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioEngine.swift`
- `Sources/OpenLolaCore/Audio/Realtime/RealtimeAudioBuffers.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmSocketOperations.swift`
- `Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift`
- `Sources/OpenLolaCore/Video/VideoCaptureRunner.swift`
- `Sources/OpenLolaCore/Video/VideoTransportReport.swift`
- `Sources/OpenLolaCore/Video/VideoTransportRunner.swift`
- `Sources/OpenLolaCore/Integration/IntegratedProfileReport.swift`
- `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift`
- `Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmark.swift`
- `Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReport.swift`
- `Tests/OpenLolaCoreTests/PerformanceAuditTests.swift`

## Tests

- hot-path APIs reject dynamic configuration changes after start;
- audio callback metrics are counters-only;
- media workers can be started/stopped independently;
- video worker overload increments drop counters before audio metrics change;
- benchmark reports require allocation and callback timing evidence for PASS.

## Resume here

After source validation, run the physical Apple Silicon benchmark matrix:

1. Raw/low-copy audio plus video baseline.
2. Metal candidate only after raw baseline.
3. VideoToolbox candidate only after raw baseline.
4. Direct Audio First, Balanced AV, and Multi-Video Performance profiles.

Store the measured report and validate it with:

```bash
open-lola validate-performance-audit-report <measured-m12-report.json>
```

Keep `VERDICT: PARTIAL` until physical Apple Silicon/RME/video evidence exists.

VERDICT: PARTIAL
