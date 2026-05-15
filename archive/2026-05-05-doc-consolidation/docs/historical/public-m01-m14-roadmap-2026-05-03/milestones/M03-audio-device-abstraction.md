# M03 Audio Device Abstraction

Date: 2026-05-03  
Status: source-level implementation complete; physical closure pending  
Verdict: PARTIAL

## Objective

Create the Core Audio/RME device abstraction needed to select the fastest stable
professional audio path.

## Scope

Cover device enumeration, RME MADI or compatible interface identity, sample
rate, channel count, buffer size, clocking, and hidden conversion checks.

## Affected Files

- [../architecture/audio-rme-madi.md](../architecture/audio-rme-madi.md)
- `Sources/OpenLolaCore/CoreAudioInventory.swift`
- `Sources/OpenLolaCore/RmeFastestAudioPath.swift`
- `Sources/OpenLolaCore/AudioLoopbackRun.swift`
- `Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift`
- `Tests/OpenLolaCoreTests/RmeFastestAudioPathTests.swift`
- Future M03 reports under `mac-port/reports/`

## Implementation Tasks

- Preserve existing Core Audio inventory fields and add only missing fields
  needed by the benchmark schema.
- Record device UID, manufacturer, transport, clock domain, channel layout,
  sample-rate ranges, accepted buffer candidates, and aggregate-device state.
- Reject fastest-mode PASS if sample-rate conversion, aggregate routing, or
  unknown driver path is present.
- Keep MADI channel-map expansion separate from the initial stereo proof.

Implementation status:

- `CoreAudioDeviceInventory` now records input/output channel-layout snapshots
  derived from Core Audio stream configuration.
- `CoreAudioInventoryReport.validate()` rejects inconsistent channel layout
  totals and labels.
- `RmeFastestAudioPathReport.validate()` rejects PASS when selected sample rate,
  buffer size, channel count, clock-domain evidence, aggregate routing, hidden
  conversion state, driver mode, or fastest-stable selection contradicts the
  inventory and loopback evidence.
- Fixture tests cover valid inventory parsing, channel-layout mismatch
  rejection, accepted/rejected RME hardware profiles, aggregate routing,
  sample-rate conversion, missing clock domain, unsupported selected sample
  rate/buffer, and non-fastest selected mode.

## Test Plan

- Unit tests for inventory parsing and RME fastest-path validation.
- Fixture tests for accepted and rejected hardware profiles.
- CLI smoke for `open-lola device-inventory`.

## Benchmark Plan

Run the 48/96/192 kHz x 16/32/64/128 frame matrix where hardware allows it.
Record accepted modes, rejected modes, callback intervals, and hardware state.

## Acceptance Criteria

- RME or compatible target path is visible through Core Audio.
- No sample-rate conversion is active in fastest mode.
- The fastest stable measured mode is selected rather than assumed.

The source-level validator implements these gates. A physical PASS still
requires Q001 hardware identity plus Q002-Q003 loopback evidence.

## Risks

- macOS sandboxing may hide devices.
- Driver or TotalMix state may affect measured latency.
- Lowest buffer size may be unstable under real route load.

## Blockers

Q001 hardware identity and Q002-Q003 loopback path are required for physical
closure.

## Rollback Plan

Keep the existing Core Audio inventory and reject physical PASS. Defer RME
selection until hardware facts are available.

## Progress Checklist

- [ ] Record target device UID.
- [ ] Record sample-rate and buffer matrix.
- [ ] Validate no hidden conversion.
- [ ] Select fastest stable mode.
- [ ] Store physical report.

## Resume Point

Resume at M04 after the selected device mode has enough evidence to drive an
audio loopback run.

VERDICT: PARTIAL
