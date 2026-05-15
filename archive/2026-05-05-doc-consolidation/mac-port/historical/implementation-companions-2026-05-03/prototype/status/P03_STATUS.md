# P03 Status

## Current status

- Status: Partial.
- Canonical prototype milestone: [P03 Blackmagic ATEM Path](../P03_BLACKMAGIC_ATEM_PATH.md)
- Objective: add AVFoundation capture and ATEM read-only control as subordinate
  lanes that cannot affect audio timing.
- Assumptions: ATEM starts read-only; switching requires explicit future arm;
  optional Blackmagic SDK absence must not break generic builds.
- Dependencies: video capture report contract, camera permission state, and
  ATEM Ethernet access when hardware is present.
- Affected modules/files: video capture probe, integrated A/V report, CLI
  capture/control probes, and this status companion.
- Implementation sequence: enumerate AVFoundation devices, report permission
  state, handle UVC/ATEM USB webcam sources, isolate optional SDK support, add
  ATEM read-only probe.
- Acceptance criteria: capture report validates or records concrete
  unavailable/permission state, ATEM read-only probe reports status, generic
  Swift builds pass without Blackmagic SDK.
- Rollback/recovery notes: leave optional vendor SDK support disabled if it
  breaks generic builds; keep read-only ATEM behavior as default.

## Completed work

- Added the P03 prototype milestone contract.
- Added this live P03 companion.
- Added AVFoundation capture-state support through the M08/G07 source surface.
- Added G08 ATEM read-only reachability reporting with bounded timeout, host,
  port, polling interval, network interface, same-network-as-audio flag,
  connection duration, error text, and `armedCommandsAllowed=false`.
- Added stricter ATEM PASS evidence gates for non-placeholder model, firmware,
  program/preview, tally, audio mixer, protocol, and network-interface fields.

## Verified work

- Baseline documentation verifier and shellcheck passed before adding the
  prototype layer.
- Post-change `swift build` passed.
- Post-change `swift test` passed with 128 Swift Testing tests.
- Post-change `bash scripts/verify-docs.sh` passed with prototype docs included.
- Post-change `shellcheck scripts/*.sh` passed.
- Existing valid video capture fixture passed
  `swift run open-lola validate-video-capture-report`.
- G08 ATEM implementation passed `swift test --filter OscCueReportTests` with
  20 focused OSC/ATEM tests.
- G08 ATEM implementation passed `swift build` after rerunning outside the
  SwiftPM sandbox failure.
- G08 ATEM implementation passed `swift test` with 253 tests.
- The bounded ATEM reachability CLI wrote a validated PARTIAL report with
  `health: timeout`, `protocolName: tcp-reachability`,
  `armedCommandsAllowed=false`, and no switching commands.
- Documentation verification and shellcheck passed after the G08 update.

## Partially completed work

- Existing M08/M10 report contracts can represent video capture and integrated
  A/V evidence.
- AVFoundation source validation and ATEM read-only reachability reporting
  exist.
- No real ATEM model, firmware, program/preview, tally, audio mixer, or
  audio-active polling evidence has been recorded.

## Deferred work

- Real ATEM read-only protocol or SDK-backed status extraction is deferred
  until hardware/network access and an optional adapter boundary exist.
- Any switching command remains deferred pending explicit user approval.

## Open tasks

- [ ] Record capture path: AVFoundation, UVC, DeckLink/UltraStudio, or
  unavailable.
- [ ] Record camera permission state.
- [ ] Record device unique ID.
- [x] Record ATEM IP, connection method, and control mode.
- [x] Record read-only reachability evidence.
- [ ] Record real ATEM model, firmware, program/preview, tally, and audio mixer
  state.
- [x] Record whether any armed control command was allowed.
- [x] Confirm generic build/test passes without Blackmagic SDK.

## Known blockers

- Requires camera permission or a concrete unavailable/denied state.
- Requires ATEM network access and read-only protocol or SDK evidence for
  read-only probe PASS.
- Requires future explicit arm before control commands.

## Test coverage status

- Required general gates: `swift build`, `swift test`,
  `bash scripts/verify-docs.sh`, `shellcheck scripts/*.sh`.
- Required hardware gates: `swift run open-lola validate-video-capture-report
  <path>` and later integrated A/V validation.
- Coverage state: synthetic video capture validation exists; AVFoundation
  source validation and ATEM reachability report validation exist. Real ATEM
  protocol/status extraction and audio-active polling are not recorded yet.

## Relevant files touched

- [../P03_BLACKMAGIC_ATEM_PATH.md](../P03_BLACKMAGIC_ATEM_PATH.md)
- [P03_STATUS.md](P03_STATUS.md)
- [../../../Sources/OpenLolaCore/AtemReadOnlyControl.swift](../../../Sources/OpenLolaCore/AtemReadOnlyControl.swift)
- [../../../Tests/OpenLolaCoreTests/OscCueReportTests.swift](../../../Tests/OpenLolaCoreTests/OscCueReportTests.swift)

## Latest verification

- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift test` passed with 128 Swift Testing tests.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: `swift run open-lola validate-video-capture-report
  Tests/OpenLolaCoreTests/Fixtures/VideoCaptureReports/valid/video-capture-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-03: `swift test --filter OscCueReportTests` passed with 20 focused
  OSC/ATEM tests.
- 2026-05-03: `swift build` passed after rerunning outside the SwiftPM sandbox
  failure.
- 2026-05-03: `swift test` passed with 253 tests.
- 2026-05-03: `.build/debug/open-lola atem-readonly-probe --host 192.0.2.10
  --port 9910 --timeout-milliseconds 100 --poll-interval-milliseconds 1000
  --network-interface en5 --same-network-as-audio false --output
  /private/tmp/open-lola-m11-atem-readonly.json` wrote a PARTIAL report with
  `health: timeout` and `armedCommandsAllowed=false`.
- 2026-05-03: `.build/debug/open-lola validate-atem-control-report
  /private/tmp/open-lola-m11-atem-readonly.json` passed with
  `VERDICT: PARTIAL`.
- 2026-05-03: `bash scripts/verify-docs.sh` passed.
- 2026-05-03: `shellcheck scripts/*.sh` passed.
- VERDICT: PARTIAL

## Next recommended steps

Run `open-lola atem-readonly-probe --host <atem-ip> --port 9910
--timeout-milliseconds 250 --output <path>` on the target network, then add a
real read-only ATEM protocol or SDK adapter only behind an optional boundary.
Keep ATEM switching commands absent.

## Resume here

Start with a target-network `atem-readonly-probe` run, then validate the report
with `open-lola validate-atem-control-report <path>`. Keep P03 PARTIAL until
real ATEM hardware/status and audio-impact evidence exist.
