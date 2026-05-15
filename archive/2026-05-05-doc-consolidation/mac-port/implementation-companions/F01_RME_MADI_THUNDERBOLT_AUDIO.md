# F01 RME MADI Thunderbolt Audio

Date: 2026-05-03
Status: required hardware baseline
Verdict: PARTIAL

## Finding

The current source layer can inventory Core Audio devices and validate RME
fastest-audio reports, but it has not proved the target RME MADI Thunderbolt
path. A faster-than-LoLa claim must start with the exact RME hardware, driver,
firmware, TotalMix state, clocking, Core Audio UIDs, and MADI channel map.

## Current Surface

- [../../Sources/OpenLolaCore/CoreAudioInventory.swift](../../Sources/OpenLolaCore/CoreAudioInventory.swift)
  captures Core Audio device identity, rates, buffers, latency, and clock
  fields.
- [../../Sources/OpenLolaCore/ReferenceRigReport.swift](../../Sources/OpenLolaCore/ReferenceRigReport.swift)
  records the explicit RME connection path and sample-rate-conversion state for
  Q001 hardware evidence.
- [../../Sources/OpenLolaCore/RmeFastestAudioPath.swift](../../Sources/OpenLolaCore/RmeFastestAudioPath.swift)
  rejects PASS reports unless the selected mode is the fastest stable
  non-aggregate Thunderbolt RME MADI path, the dedicated RME driver is in use,
  sample-rate conversion is absent, and the loopback matrix passes.
- `open-lola device-inventory`, `open-lola audio-loopback-run`, and
  `open-lola validate-rme-fastest-audio-report <path>` are the active CLI
  entry points.

## Required Evidence

Record these facts before any PASS verdict:

- exact RME model and Thunderbolt connection path for the F01 PASS path;
- driver package, driver version, driver mode, firmware version, and TotalMix
  version;
- saved TotalMix snapshot path or attached configuration checksum;
- clock source, sample-rate source, and whether any aggregate or sample-rate
  conversion path is present;
- Core Audio input and output UIDs, stream counts, channel counts, safety
  offsets, nominal rates, and available buffer frame sizes;
- MADI channel map for the tested input/output pair;
- analog loopback wiring or digital loopback route, including whether it proves
  the same performance path as the performance rig;
- 16, 32, 64, and 128 frame matrix at 48, 96, and 192 kHz, including explicit
  "unsupported" disposition where the hardware refuses a mode.

## Implementation Gate

The source gate is implemented. Use the current validators first; do not mark
F01 PASS by editing docs around failed hardware evidence.

Required command sequence:

```bash
swift run open-lola device-inventory
swift run open-lola audio-loopback-run --input-uid <rme-uid> --output-uid <rme-uid> --sample-rate <hz> --frames <n> --duration-seconds <n> --output <path>
swift run open-lola validate-loopback-report <path>
swift run open-lola validate-rme-fastest-audio-report <path>
```

## PASS Criteria

- RME MADI device is visible through Core Audio with concrete non-placeholder
  UID values.
- The tested input and output are the same accepted non-aggregate Thunderbolt
  RME MADI performance device.
- The dedicated RME driver path is in use; class-compliant fallback is not
  accepted for PASS.
- The report proves the fastest stable mode, not just a convenient stable mode.
- No sample-rate conversion, aggregate device, or buffer growth is present.
- The selected mode survives the stability duration required by M03/G02.

## Resume here

Attach the RME device, run `device-inventory`, fill Q001/Q002/Q003 in
[../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md), then produce the RME fastest-audio
report. Keep F01 PARTIAL until the physical matrix validates.

VERDICT: PARTIAL
