# M09 Blackmagic RX Render Output

Date: 2026-05-04  
Status: source-level implementation complete; physical Blackmagic output evidence open  
Verdict: PARTIAL

## Objective

Receive peer video frames, reassemble and reorder them, drop late or incomplete
frames, render locally, and output through a Blackmagic-compatible path where
public APIs allow it.

## Scope

In scope:

- one negotiated video stream;
- receive packet validation;
- frame reassembly;
- frame drop and pacing policy;
- local preview or output renderer;
- Blackmagic-compatible output strategy;
- video latency measurement;
- audio-priority protection.

Out of scope:

- multi-stream layout;
- AV sync correction beyond timestamp reporting;
- proprietary output paths.

## Affected Files

New or changed files:

- `Sources/OpenLolaCore/VideoTransportPacket.swift`
- `Sources/OpenLolaCore/VideoTransportReassembly.swift`
- `Sources/OpenLolaCore/VideoTransportRunner.swift`
- `Sources/OpenLolaCore/VideoTransportReport.swift`
- `Sources/OpenLolaCore/VideoOutputRenderer.swift`
- `Sources/OpenLolaCore/BlackmagicOutputBoundary.swift`
- `Tests/OpenLolaCoreTests/BlackmagicReceiveRenderTests.swift`
- `Tests/OpenLolaCoreTests/Fixtures/VideoTransportReports/valid/video-transport-partial.json`
- `docs/architecture/blackmagic-video-rx-tx.md`

## Implementation Tasks

1. Added tests for receiving complete, late, duplicate, and incomplete video
   frames.
2. Implemented bounded reassembly by stream ID and frame sequence.
3. Added frame pacing and drop policies: latest-only, deadline, and continuity.
4. Implemented a local render/output abstraction with the public API fallback
   first.
5. Added an optional Blackmagic output boundary behind compile/runtime detection.
6. Recorded receive, reassembly, render, and output timestamp deltas in reports.
7. Kept output queue pressure in the video lane; PASS validation still rejects
   any audio callback, underrun, or playout-target regression.

## Test Plan

Tests first:

- source-level RX/render smoke via `video-transport-synthetic-smoke`;
- complete frame reassembles and renders;
- missing fragment drops frame;
- late frame drops under deadline policy;
- duplicate packet is counted;
- output backpressure drops video, not audio;
- video latency fields are present in reports;
- physical Blackmagic RX/render smoke remains the PASS-only evidence gate.

## Benchmark Plan

- receive-to-reassembly latency is reported for synthetic and run reports;
- reassembly-to-render latency is reported for synthetic and run reports;
- render/output latency is reported for synthetic and run reports;
- dropped frames under load are counted by late, backpressure, continuity, and
  incomplete-reassembly reason;
- CPU, GPU, and memory cost;
- audio callback duration while video RX/output is active.

## Acceptance Criteria

- One received video stream can render or output frames with measured latency.
- Late and incomplete frames are dropped according to policy.
- Output pressure cannot block media control, network audio, or audio callback
  work.
- Physical PASS requires Blackmagic-compatible output evidence.

## Risks

- macOS preview and hardware output have different timing behavior.
- Frame queue growth can hide latency unless bounded and reported.

## Blockers

- M08 video TX packet format required.
- Blackmagic-compatible output hardware required for hardware PASS.

## Rollback Plan

Keep video RX/render disabled by negotiation if output is not available. Retain
packet reassembly tests and local preview as diagnostics.

## Progress Checklist

- [x] Add frame reassembly tests.
- [x] Add render/output drop policy tests.
- [x] Implement bounded RX queues.
- [x] Add local preview/output backend.
- [x] Add Blackmagic-compatible output boundary smoke.
- [x] Benchmark receive/render latency in synthetic reports.
- [ ] Run physical Blackmagic-compatible output smoke.
- [ ] Capture CPU/GPU/memory and audio-callback evidence with hardware active.

## Resume Point

Run the physical follow-up with Blackmagic output hardware and capture a
`video-transport-run` report plus audio-active evidence. Source-level M09 now
has bounded receive reassembly, render/output pacing, latency metrics, and a
PASS gate requiring real Blackmagic output evidence.

VERDICT: PARTIAL
