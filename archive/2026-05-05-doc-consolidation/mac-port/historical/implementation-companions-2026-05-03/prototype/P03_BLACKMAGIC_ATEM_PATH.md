# P03 Blackmagic ATEM Path

## Objective

Add Blackmagic/ATEM as subordinate video and control lanes without coupling
them to audio timing.

## Background/Context

The first video path should use AVFoundation through the existing camera
abstraction. ATEM USB webcam output and UVC capture devices are treated as
AVFoundation sources. Blackmagic Desktop Video or DeckLink support is optional
and must remain behind a boundary that keeps generic Swift builds and tests
passing without the SDK.

## Canonical Roadmap Links

- [../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md](../milestones/M08_GENERIC_VIDEO_CAPTURE_PROBE.md)
- [../milestones/M09_NATIVE_VIDEO_TRANSPORT.md](../milestones/M09_NATIVE_VIDEO_TRANSPORT.md)
- [../milestones/M10_INTEGRATED_HEADLESS_AV.md](../milestones/M10_INTEGRATED_HEADLESS_AV.md)
- [P04_INTEGRATED_AV_PROOF.md](P04_INTEGRATED_AV_PROOF.md)

## Assumptions

- ATEM control starts read-only.
- Any switching command requires an explicit arm step in a later user-approved
  change.
- Capture unavailable and permission-denied states are valid prototype outputs
  when reported concretely.
- Optional Blackmagic SDK absence must not break `swift build` or `swift test`.

## Dependencies

- Existing video capture report contract.
- macOS camera permission state.
- ATEM Ethernet control network access when an ATEM is present.
- Optional UVC, UltraStudio, DeckLink, or ATEM USB webcam capture path.

## Affected Modules/Files

- [../../Sources/OpenLolaCore/VideoCaptureProbe.swift](../../Sources/OpenLolaCore/VideoCaptureProbe.swift)
- [../../Sources/OpenLolaCore/IntegratedAvReport.swift](../../Sources/OpenLolaCore/IntegratedAvReport.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [status/P03_STATUS.md](status/P03_STATUS.md)

## Implementation Plan

1. Add AVFoundation capture behind the existing `CameraSource` boundary.
2. Enumerate available AVFoundation video devices and permission state.
3. Treat ATEM USB webcam output or UVC capture devices as AVFoundation sources.
4. Add optional Blackmagic Desktop Video or DeckLink support only behind a
   compile-time or runtime-optional boundary.
5. Add ATEM read-only Ethernet control probe for discover/connect, model,
   firmware, program/preview source, tally, audio mixer state, and connection
   health.
6. Gate all switching commands behind explicit arm; keep the first prototype
   read-only unless a later task enables control.

## Companion Status Fields

[status/P03_STATUS.md](status/P03_STATUS.md) records:

- ATEM model, firmware, IP, connection method, and control mode;
- capture path: AVFoundation, UVC, DeckLink/UltraStudio, or unavailable;
- permission state and device unique ID;
- read-only control evidence;
- whether any armed control command was allowed.

## Test Plan

Before: video capture can be synthetic or contract-only; ATEM control evidence
does not exist.

After:

- `swift build` passes without Blackmagic SDK installed;
- `swift test` passes without Blackmagic SDK installed;
- `bash scripts/verify-docs.sh` passes;
- `shellcheck scripts/*.sh` passes;
- AVFoundation capture report validates or records concrete unavailable or
  permission state;
- ATEM read-only probe produces a status report without affecting audio.

## Validation Method

Validate capture and control independently from audio. P03 can be PARTIAL when
hardware is absent, but it cannot claim PASS without either a measured
AVFoundation/Blackmagic capture path or a concrete unavailable state plus ATEM
read-only evidence when ATEM hardware is part of the target rig.

## Acceptance Criteria

- AVFoundation capture report validates or records a concrete unavailable or
  permission state.
- ATEM read-only probe produces a status report without affecting audio.
- Optional Blackmagic SDK absence does not break `swift build` or `swift test`.
- No switching command can run without explicit arm.

## Risks and Mitigations

- Vendor SDK coupling can break generic builds. Mitigation: keep SDK-specific
  code optional and isolated.
- Camera permission prompts can block unattended runs. Mitigation: report
  permission state explicitly and fail closed.
- ATEM control can be operationally unsafe. Mitigation: read-only default and
  explicit arm for future commands.

## Known Blockers

- Requires camera permission or a concrete permission-denied report.
- Requires ATEM network access for read-only probe PASS.
- Requires user approval before any switching command is enabled.

## Progress Checklist

- [ ] Add AVFoundation device enumeration.
- [ ] Add AVFoundation capture report path.
- [ ] Record UVC or ATEM USB webcam source identity when available.
- [ ] Keep optional Blackmagic SDK boundary out of generic builds.
- [x] Add ATEM read-only control probe.
- [x] Record ATEM reachability status without affecting audio.
- [ ] Update [status/P03_STATUS.md](status/P03_STATUS.md).

## Next Recommended Action

Start with AVFoundation enumeration and permission reporting through the
existing video capture report contract. Run ATEM read-only probing only after
the capture path can report a concrete state.

## Resume here

Start from [status/P03_STATUS.md](status/P03_STATUS.md). Keep P03 PARTIAL until
capture state and ATEM read-only evidence are both recorded without audio
coupling.
