# F05 Blackmagic ATEM Capture

Date: 2026-05-03
Status: required production video capture boundary
Verdict: PARTIAL

## Finding

The current M08 capture source can inventory and run AVFoundation, but the
production video priority is Blackmagic/ATEM first. AVFoundation remains the
generic harness and fallback when macOS exposes the ATEM, DeckLink, UltraStudio,
or UVC capture path through the standard capture stack.

## Current Surface

- [../../Sources/OpenLolaCore/VideoCaptureProbe.swift](../../Sources/OpenLolaCore/VideoCaptureProbe.swift)
  classifies ATEM, UVC, DeckLink, UltraStudio, Blackmagic, capture, and external
  names as external capture candidates.
- [../../Sources/OpenLolaCore/VideoCaptureRunner.swift](../../Sources/OpenLolaCore/VideoCaptureRunner.swift)
  collects AVFoundation sample buffers into the latest-frame queue and records
  frame age, frame interval, drop count, process CPU, process memory, and
  measured audio-impact fields.
- Video capture PASS now requires production capture evidence for a concrete
  ATEM, DeckLink, UltraStudio, or Blackmagic capture path, matching the
  AVFoundation device ID when AVFoundation is the exposed path.
- The active source policy is `blackmagicFirstAvFoundationFallback`.
- `blackmagicSdkStatus` records that Desktop Video SDK is an optional boundary
  in generic builds and rejects PASS when measurements show the SDK is required.
- [../../Sources/OpenLolaCore/AtemReadOnlyControl.swift](../../Sources/OpenLolaCore/AtemReadOnlyControl.swift)
  keeps ATEM network control read-only and subordinate to M11.

## Required Evidence

For the target rig, record:

- exact ATEM, DeckLink, UltraStudio, or capture-device model;
- connection method: USB webcam/UVC, Thunderbolt, PCIe, or network status only;
- macOS-visible capture device unique ID, model ID, manufacturer, transport,
  formats, and permission state;
- whether the path is visible through AVFoundation;
- whether the Blackmagic Desktop Video SDK is absent, available, required, or
  rejected after measurement;
- ATEM read-only model, firmware, program/preview, tally, and audio mixer state
  when Ethernet control is part of the rig.

## Adapter Rule

Add a Desktop Video SDK adapter only after one of these is measured:

- the target Blackmagic path is not visible to AVFoundation;
- AVFoundation is visible but not fast enough;
- AVFoundation loses device status needed for field operation.

The optional SDK boundary must not make generic `swift build` or `swift test`
depend on the SDK being installed.

## PASS Criteria

- Production capture path identifies the Blackmagic/ATEM device by concrete
  hardware fields.
- AVFoundation fallback is measured when it is the exposed path.
- Desktop Video SDK need is evidence-based, not speculative.
- Capture reports include frame age, frame interval, drop count, CPU, memory,
  and audio-impact proof.
- PASS rejects generic cameras, mismatched AVFoundation device IDs, missing
  process CPU metrics, and placeholder production evidence.
- ATEM commands remain read-only unless a later explicit arm is approved.

## Resume here

Run `open-lola video-capture-inventory` on the target Mac with the Blackmagic
hardware connected. If the device is visible, run `video-capture-run`; if it is
not visible or not fast enough, scope the optional Desktop Video adapter.

VERDICT: PARTIAL
