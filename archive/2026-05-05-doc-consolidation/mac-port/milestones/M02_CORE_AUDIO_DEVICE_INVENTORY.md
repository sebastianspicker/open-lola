# M02 Core Audio Device Inventory

## Objective

Enumerate Core Audio devices and prove a callback-safe inventory/logging path
that reports devices, rates, buffers, latency, and clock domain.

## Background/Context

The project must know what macOS and the selected audio interface actually
accept before selecting a fastest mode. API-reported latency is diagnostic; the
acceptance metric remains measured loopback in M03.

## Reverse-Engineering Findings

Static fact:
[../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
shows Windows LoLa used PortAudio/ASIO and probed ASIO buffer sizes. That is
evidence for hardware-driver-first behavior, not a requirement to use PortAudio.

## Research Findings

[../../research/RESEARCH_AUDIO_ENGINE_2026.md](../../research/RESEARCH_AUDIO_ENGINE_2026.md)
requires recording nominal and actual sample rate, supported and accepted buffer
sizes, device and stream latency, safety offset, channel map, sample format,
aggregate-device state, and callback metrics.

## Assumptions

- Direct Core Audio HAL/AUHAL or `AudioDeviceIOProc` remains the target.
- Device inventory can run outside the audio callback.
- Logs and reports are written outside realtime paths.

## Dependencies

- M00 scaffold.
- M01 report schema.
- macOS Core Audio headers and frameworks.
- At least one local audio device.

## Affected Modules/Files

- Future Core Audio device inventory module.
- Future device inventory CLI.
- Future report fixtures and tests.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

## Implementation Plan

1. Add a device inventory CLI.
2. Query device name, UID, transport, streams, sample rates, buffer frame ranges,
   accepted buffer sizes, latency, safety offset, and clock domain where
   available.
3. Serialize inventory as a report fixture.
4. Add tests for parsing and required fields.
5. Keep all logging outside any future IOProc callback.

## Test Plan

Before: no Core Audio CLI exists.

After:

- CLI reports devices, rates, buffers, latency, and clock domain;
- report fixture tests pass;
- `swift build` and `swift test` pass.

## Validation Method

Run the CLI on the local Mac, save a sample report, and verify tests against the
report schema.

## Acceptance Criteria

- At least one output format is machine-readable.
- Device inventory includes accepted and rejected buffer-size data where
  probing is possible.
- The CLI does not imply that API latency equals measured latency.

SOTA 2026 gate:

- Rows: Q002, SOTA020, SOTA021, SOTA023, SOTA024 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: Core Audio inventory reports accepted rates, buffer ranges, safety offsets, latency diagnostics, and clock-domain data without claiming measured latency.

## Risks and Mitigations

- R002: device support may be limited. Mitigation: report accepted and rejected
  frame sizes explicitly.
- R003: logging could enter realtime paths later. Mitigation: document inventory
  as non-callback code and test report boundaries.

## Known Blockers

- Some device properties may be unavailable or permission-dependent.
- Clock-domain reporting may vary by device.

## Progress Checklist

- [x] Add Core Audio inventory module.
- [x] Add inventory CLI.
- [x] Add report serialization.
- [x] Add tests.
- [x] Run CLI on local Mac.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Next Recommended Action

Start M03 with a 32-frame analog loopback probe using the M02 inventory output
as device-selection input.

## Resume here

Use `swift run open-lola device-inventory` to pick the test device, then record
M03 analog loopback and callback metrics before selecting any fastest mode.
