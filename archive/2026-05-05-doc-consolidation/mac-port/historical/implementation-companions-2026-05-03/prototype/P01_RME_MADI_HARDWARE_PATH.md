# P01 RME MADI Hardware Path

## Objective

Make the actual professional audio interface visible, documented, and
measurable before accepting any ATEM, video, UI, or field-runtime work.

## Background/Context

The canonical M02 inventory and M03 loopback contracts already exist, but a
prototype cannot pass on built-in Mac audio. P01 narrows the hardware target to
RME MADI and records the driver, firmware, clocking, routing, and measured
loopback evidence needed by later realtime and integrated runs.

## Canonical Roadmap Links

- [../milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md](../milestones/M01_MEASUREMENT_HARDWARE_NETWORK_PROFILE.md)
- [../milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md](../milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md)
- [../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md)
- [../status/M02_STATUS.md](../status/M02_STATUS.md)
- [../status/M03_STATUS.md](../status/M03_STATUS.md)

## Assumptions

- RME MADI is the professional audio reference path.
- Built-in mic, built-in speakers, and aggregate smoke fixtures can validate
  code paths but cannot satisfy P01 PASS.
- The existing `open-lola device-inventory` command is preferred unless generic
  Core Audio fields cannot expose the required RME details.
- Serial numbers are recorded only when acceptable for the environment where
  the report will live.

## Dependencies

- RME MADI interface connected to the prototype Mac.
- Current RME macOS driver and firmware tooling installed.
- TotalMix state available for routing evidence.
- Physical loopback path for the tested MADI channels.

## Affected Modules/Files

- [../../Sources/OpenLolaCore/CoreAudioInventory.swift](../../Sources/OpenLolaCore/CoreAudioInventory.swift)
- [../../Sources/OpenLolaCore/EndpointLoopbackReport.swift](../../Sources/OpenLolaCore/EndpointLoopbackReport.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [status/P01_STATUS.md](status/P01_STATUS.md)

## Implementation Plan

1. Connect the RME MADI interface and install current RME macOS driver and
   firmware tooling.
2. Record Mac model, macOS version, RME model, optional serial, firmware,
   driver mode, TotalMix version/state, clock source, sample rate, channel
   count, channel labels, buffer-frame range, safety offsets, and routing.
3. Run `swift run open-lola device-inventory` and confirm the RME device UID is
   visible.
4. Extend inventory output or add `open-lola rme-inventory` only if the generic
   Core Audio inventory cannot record the required fields.
5. Measure RME single-Mac loopback at 48 kHz and 96 kHz with 16, 32, 64, and
   128 frame buffers where the driver accepts those modes.
6. Save measured callback, latency, underrun, and hidden-conversion evidence in
   validated loopback reports.

## Companion Status Fields

[status/P01_STATUS.md](status/P01_STATUS.md) records:

- installed RME driver package and version;
- firmware and driver mode: DriverKit, kernel extension, or class-compliant;
- Core Audio device UID values;
- TotalMix routing snapshot or exact exported state reference;
- PASS/FAIL/PARTIAL loopback table.

## Test Plan

Before: RME MADI may not appear in inventory and no RME loopback row exists.

After:

- `swift build` passes;
- `swift test` passes;
- `bash scripts/verify-docs.sh` passes;
- `shellcheck scripts/*.sh` passes;
- `swift run open-lola device-inventory` shows the RME device;
- `swift run open-lola validate-loopback-report <path>` validates at least one
  RME loopback report.

## Validation Method

Accept measured hardware evidence only. A report must distinguish requested
buffer size from accepted buffer size and must record whether the path includes
hidden conversion, safety buffering, or sample-rate conversion.

## Acceptance Criteria

- `open-lola device-inventory` shows the RME device.
- At least one RME loopback row has measured callback, latency, underrun, and
  hidden-conversion evidence.
- 48 kHz and 96 kHz rows exist or record a concrete unsupported state.
- Built-in audio is marked smoke-only and cannot produce P01 PASS.
- `swift test`, docs verifier, and report validator pass.

## Risks and Mitigations

- RME driver may reject 16 or 32 frame buffers. Mitigation: record rejected
  modes and select the fastest accepted stable mode by measurement.
- TotalMix routing may hide conversion or safety buffering. Mitigation: record
  clock source, routing, and hidden-conversion evidence in the loopback row.
- Hardware identifiers may be sensitive. Mitigation: record serial numbers only
  when acceptable; otherwise record model, firmware, and UID evidence.

## Known Blockers

- Requires physical RME MADI hardware.
- Requires loopback cabling or another measurement fixture on the chosen MADI
  channels.

## Progress Checklist

- [ ] Connect RME MADI interface.
- [ ] Install and record RME driver package/version.
- [ ] Record firmware, driver mode, TotalMix state, clock, channel labels, and
  routing.
- [ ] Confirm RME device UID in `open-lola device-inventory`.
- [ ] Decide whether generic inventory is sufficient or `rme-inventory` is
  required.
- [ ] Run 48 kHz loopback matrix for 16/32/64/128 frames.
- [ ] Run 96 kHz loopback matrix for 16/32/64/128 frames.
- [ ] Validate at least one RME loopback report.
- [ ] Update [status/P01_STATUS.md](status/P01_STATUS.md).

## Next Recommended Action

Connect the RME MADI interface, run `swift run open-lola device-inventory`, and
record the exact Core Audio UID, driver, firmware, clock, and TotalMix state in
[status/P01_STATUS.md](status/P01_STATUS.md).

## Resume here

Start from [status/P01_STATUS.md](status/P01_STATUS.md). P01 remains PARTIAL
until an RME device is visible and at least one validated RME loopback row
contains measured timing and hidden-conversion evidence.
