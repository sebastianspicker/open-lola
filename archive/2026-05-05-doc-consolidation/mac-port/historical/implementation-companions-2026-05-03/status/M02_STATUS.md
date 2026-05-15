# M02 Status

## Current status

- Status: Complete.
- Canonical milestone: [M02 Core Audio Device Inventory](../milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md)

Canonical objective:

Enumerate Core Audio devices and prove a callback-safe inventory/logging path
that reports devices, rates, buffers, latency, and clock domain.

Canonical assumptions:

- Direct Core Audio HAL/AUHAL or `AudioDeviceIOProc` remains the target.
- Device inventory can run outside the audio callback.
- Logs and reports are written outside realtime paths.

Canonical dependencies:

- M00 scaffold.
- M01 report schema.
- macOS Core Audio headers and frameworks.
- At least one local audio device.

Canonical affected modules/files:

- Future Core Audio device inventory module.
- Future device inventory CLI.
- Future report fixtures and tests.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Canonical implementation sequence:

1. Add a device inventory CLI.
2. Query device name, UID, transport, streams, sample rates, buffer frame ranges,
   accepted buffer sizes, latency, safety offset, and clock domain where
   available.
3. Serialize inventory as a report fixture.
4. Add tests for parsing and required fields.
5. Keep all logging outside any future IOProc callback.

Canonical acceptance criteria:

- At least one output format is machine-readable.
- Device inventory includes accepted and rejected buffer-size data where
  probing is possible.
- The CLI does not imply that API latency equals measured latency.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added `CoreAudioInventoryReport`, `CoreAudioDeviceInventory`, buffer-frame
  candidate classification, validation, and deterministic JSON serialization.
- Added `CoreAudioInventoryReader`, a read-only Core Audio HAL inventory path
  that runs outside any realtime callback.
- Added the `open-lola device-inventory` CLI command while preserving the
  default M00 summary output.
- Added deterministic Core Audio inventory fixtures and Swift tests.
- Added [../reports/M02_CORE_AUDIO_INVENTORY_2026-05-02.md](../reports/M02_CORE_AUDIO_INVENTORY_2026-05-02.md).

## Verified work

- Red test run before implementation failed on missing M02 inventory types.
- `swift test` passed with 11 tests after implementation.
- `swift build` passed.
- `swift run open-lola` passed and preserved the M00 scaffold summary.
- `swift run open-lola device-inventory` passed on the local Mac and captured 3
  Core Audio devices as JSON.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.

## Partially completed work

- None for the M02 inventory milestone.

## Deferred work

- Q002 remains open for M03 because analog loopback must still prove whether
  accepted sample rates hide conversion or safety buffering.
- Callback p99/max measurement and fastest endpoint mode selection remain M03
  work.

## Open tasks

Canonical progress checklist:

- [x] Add Core Audio inventory module.
- [x] Add inventory CLI.
- [x] Add report serialization.
- [x] Add tests.
- [x] Run CLI on local Mac.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q002, SOTA020, SOTA021, SOTA023, SOTA024 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: Core Audio inventory reports accepted rates, buffer ranges, safety offsets, latency diagnostics, and clock-domain data without claiming measured latency.

## Known blockers

- No M02 blockers remain.
- Device property availability and clock-domain values still vary by device and
  must be treated as report data, not assumptions.

## Test coverage status

Canonical test plan:

Before: no Core Audio CLI exists.

After:

- CLI reports devices, rates, buffers, latency, and clock domain;
- report fixture tests pass;
- `swift build` and `swift test` pass.

Coverage state: Swift tests cover fixture decoding, required-device validation,
buffer candidate classification, and JSON round-trip serialization. The CLI
probe covered local Core Audio enumeration on this Mac.

## Relevant files touched

Planned affected modules/files:

- Future Core Audio device inventory module.
- Future device inventory CLI.
- Future report fixtures and tests.
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Live files touched:

- [../../Package.swift](../../Package.swift)
- [../../Sources/OpenLolaCore/CoreAudioInventory.swift](../../Sources/OpenLolaCore/CoreAudioInventory.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift](../../Tests/OpenLolaCoreTests/CoreAudioInventoryTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/valid/core-audio-inventory-valid.json](../../Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/valid/core-audio-inventory-valid.json)
- [../../Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/valid/core-audio-inventory-empty.json](../../Tests/OpenLolaCoreTests/Fixtures/CoreAudioInventory/valid/core-audio-inventory-empty.json)
- [../reports/M02_CORE_AUDIO_INVENTORY_2026-05-02.md](../reports/M02_CORE_AUDIO_INVENTORY_2026-05-02.md)
- [../milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md](../milestones/M02_CORE_AUDIO_DEVICE_INVENTORY.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)
- [../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md](../milestones/M03_ENDPOINT_LOOPBACK_FASTEST_MODE.md)
- [M03_STATUS.md](M03_STATUS.md)

## Latest verification

- 2026-05-02: `swift test` passed with 11 tests.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift run open-lola` passed.
- 2026-05-02: `swift run open-lola device-inventory` passed and captured 3
  local Core Audio devices.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- VERDICT: PASS

## Next recommended steps

Start M03 with the inventory output as the device-selection input, then run a
32-frame analog loopback probe before filling the full 16/32/64/128 matrix.

## Resume here

Use `swift run open-lola device-inventory` to select a test device for M03, then
record analog loopback and callback metrics in the M03 report path.
