# G02 RME MADI Fastest Audio Path

## LoLa Comparison

LoLa gets its audio speed from professional RME/ASIO-class hardware, tiny
buffers, and callback behavior that favors dropouts over waiting. The Mac
replacement must prove the equivalent on Core Audio with real RME MADI hardware
before video, UI, recording, or control can matter.

## Current Repo State

- Related milestones: [../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md), [../prototype/P01_RME_MADI_HARDWARE_PATH.md](../prototype/P01_RME_MADI_HARDWARE_PATH.md)
- Live status: [../status/M03_STATUS.md](../status/M03_STATUS.md), [../prototype/status/P01_STATUS.md](../prototype/status/P01_STATUS.md)
- Existing source validates endpoint loopback reports and has an
  `audio-loopback-run` preflight/IOProc surface.
- G02 now has a stricter `RmeFastestAudioPathReport` validator that composes
  RME inventory metadata, driver/firmware/TotalMix evidence, and the M03
  loopback report. PASS is rejected unless the selected mode is the measured
  fastest stable RME mode.
- Current measured local inventory has no RME device visible.

## Implementation Plan

1. Connect the RME path and capture `device-inventory` output with stable UID,
   channel count, clock domain, sample-rate ranges, and frame-size ranges.
2. Record driver, firmware, DriverKit/kernel-extension/class-compliant mode,
   TotalMix state, and clock source in P01 status before running loops.
3. Run 48 kHz, 96 kHz, and 192 kHz where supported, with 16/32/64/128 frame
   requests. Record requested versus accepted values.
4. For each accepted row, measure analog round trip, callback p99/max, missed
   deadlines, underruns, overruns, reported device latency, and hidden
   conversion/buffer-growth state.
5. Select the fastest stable default only from a 30-minute row with no hidden
   growth. Built-in audio remains smoke-only.

## Acceptance Tests

- RME device visible in `open-lola device-inventory`.
- At least one RME loopback row validates.
- Full supported frame/rate matrix recorded.
- 30-minute stability row has fixed playout target and no hidden growth.
- `swift run open-lola validate-rme-fastest-audio-report <path>` validates the
  G02 report and returns the report verdict.

## Blockers / TODO(human)

- TODO(human): [M03 analog loopback setup] -> Provide the physical loopback path and target input/output device UID -> [RME analog loopback / RME digital loopback / defer M03 measurement]
- Requires RME hardware and loopback cabling.

## Verification Commands

```bash
swift run open-lola device-inventory
swift run open-lola audio-loopback-run --input-uid <uid> --output-uid <uid> --sample-rate <hz> --frames <n> --duration-seconds <n> --output mac-port/reports/<report>.json
swift run open-lola validate-loopback-report <validated-m03-report.json>
swift run open-lola validate-rme-fastest-audio-report <validated-g02-report.json>
swift test
```

## Resume here

Start from a fresh RME inventory, then fill the G02 report template and the
16/32/64/128 frame matrix before choosing a default.

VERDICT: PARTIAL
