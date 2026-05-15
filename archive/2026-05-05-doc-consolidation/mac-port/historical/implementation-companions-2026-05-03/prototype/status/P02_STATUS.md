# P02 Status

## Current status

- Status: Partial.
- Canonical prototype milestone: [P02 Realtime Audio Engine](../P02_REALTIME_AUDIO_ENGINE.md)
- Objective: implement the Core Audio I/O loop and UDP PCM route using the RME
  path from P01.
- Assumptions: P01 provides selected RME input/output UID values; packet format
  stays on the M04 UDP PCM contract; non-realtime work stays outside callbacks.
- Dependencies: P01 RME evidence, M04 packet contract, wired two-Mac route, and
  packet capture point.
- Affected modules/files: UDP PCM packet/route reports, drift/PLC reports, the
  G03 realtime audio engine report, bounded handoff helpers, and CLI commands.
- Implementation sequence: add callback owner, add bounded handoff, integrate
  UDP sender/receiver, add CLI runners, record metrics, validate route and
  drift reports.
- Acceptance criteria: RME loopback has no callback violations, wired two-Mac
  route has packet-capture correlation, and M03/M05/M06 can use real data.
- Rollback/recovery notes: disable new realtime CLI commands if callback safety
  fails; keep report validators intact.

## Completed work

- Added the P02 prototype milestone contract.
- Added this live P02 companion.
- Added `RealtimeAudioEngineReport`, `RealtimeAudioBlockRing`, and
  `RealtimeAudioDueBlockPlayout`.
- Added callback-safety, bounded-handoff, callback-period, packet-handoff, and
  shutdown PASS guards.
- Added `open-lola validate-realtime-audio-engine-report <path>` and
  `open-lola realtime-audio-synthetic-smoke`.

## Verified work

- Baseline documentation verifier and shellcheck passed before adding the
  prototype layer.
- Post-change `swift build` passed.
- Post-change `swift test` passed with 209 Swift Testing tests.
- Post-change `bash scripts/verify-docs.sh` passed with prototype docs included.
- Post-change `shellcheck scripts/*.sh` passed.
- Existing valid route fixture passed
  `swift run open-lola validate-route-report`.
- Existing valid drift/PLC fixture passed
  `swift run open-lola validate-drift-plc-report`.
- `swift test --filter RealtimeAudio` passed after adding the G03 report model,
  bounded ring, due-block playout helper, partial fixture, and CLI branch.
- `swift run open-lola validate-realtime-audio-engine-report
  Tests/OpenLolaCoreTests/Fixtures/RealtimeAudioEngineReports/valid/realtime-audio-engine-partial.json`
  passed with `VERDICT: PARTIAL`.
- `swift run open-lola realtime-audio-synthetic-smoke` passed with
  `VERDICT: PARTIAL`.
- `swift run open-lola device-inventory` passed, but only Apple/iPhone/MacBook
  devices were visible; no RME device was visible for measured G03 closure.

## Partially completed work

- UDP PCM packet, route, and drift/PLC report contracts already exist in the
  canonical roadmap.
- G03 now has source-level validation and a synthetic smoke surface.
- No measured RME Core Audio callback owner has been added in this session.

## Deferred work

- Measured Core Audio callback implementation is deferred until P01 records
  target RME device UID values.
- Two-Mac route measurement is deferred until a wired route and packet capture
  point are available.

## Open tasks

- [ ] Select RME input/output UID and sample format.
- [ ] Add measured realtime callback owner.
- [x] Add bounded realtime-safe handoff source helper.
- [x] Confirm no allocation, logging, file I/O, locks, network setup, or report
  writing is allowed by a PASS report.
- [x] Add source validator and synthetic smoke CLI commands.
- [ ] Add measured single-host loopback, sender, receiver, and two-Mac route
  CLI commands.
- [ ] Record route topology from a measured route: single-host, direct wired,
  switch, or campus.
- [ ] Record packet capture point and DSCP observation.
- [ ] Record drift/PLC run status.

## Known blockers

- P01 RME hardware selection is not complete.
- Wired two-Mac route and packet capture are not recorded.

## Test coverage status

- Required general gates: `swift build`, `swift test`,
  `bash scripts/verify-docs.sh`, `shellcheck scripts/*.sh`.
- Required source gates: `swift run open-lola
  validate-realtime-audio-engine-report <path>` and `swift run open-lola
  realtime-audio-synthetic-smoke`.
- Required hardware gates: `swift run open-lola validate-route-report <path>`
  and `swift run open-lola validate-drift-plc-report <path>`.
- Coverage state: G03 source validator, callback-safety gates, bounded ring
  tests, due-block playout tests, partial fixture, and synthetic smoke exist;
  measured RME callback ownership and packet-route runtime evidence remain
  open.

## Relevant files touched

- [../P02_REALTIME_AUDIO_ENGINE.md](../P02_REALTIME_AUDIO_ENGINE.md)
- [P02_STATUS.md](P02_STATUS.md)
- [../../../Sources/OpenLolaCore/RealtimeAudioEngine.swift](../../../Sources/OpenLolaCore/RealtimeAudioEngine.swift)
- [../../../Sources/open-lola/main.swift](../../../Sources/open-lola/main.swift)
- [../../../Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift](../../../Tests/OpenLolaCoreTests/RealtimeAudioEngineTests.swift)
- `../../../Tests/OpenLolaCoreTests/Fixtures/RealtimeAudioEngineReports/`

## Latest verification

- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift test` passed with 209 Swift Testing tests.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: `swift run open-lola validate-route-report
  Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json`
  passed with `VERDICT: PASS`.
- 2026-05-02: `swift run open-lola validate-drift-plc-report
  Tests/OpenLolaCoreTests/Fixtures/DriftPlcReports/valid/drift-plc-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-02: red G03 test-first run failed on missing
  `RealtimeAudioEngineReport`, ring, playout, and validation types.
- 2026-05-02: `swift test --filter RealtimeAudio` passed after G03 source
  implementation.
- 2026-05-02: `swift run open-lola
  validate-realtime-audio-engine-report
  Tests/OpenLolaCoreTests/Fixtures/RealtimeAudioEngineReports/valid/realtime-audio-engine-partial.json`
  passed with `VERDICT: PARTIAL`.
- 2026-05-02: `swift run open-lola realtime-audio-synthetic-smoke` passed with
  `VERDICT: PARTIAL`.
- 2026-05-02: `swift run open-lola device-inventory` passed, but the live
  inventory showed only Apple/iPhone/MacBook devices and no RME path.
- VERDICT: PARTIAL

## Next recommended steps

Wait for P01 RME UID and loopback evidence, then connect the measured Core
Audio callback owner to the existing bounded handoff and emit a measured G03
report.

## Resume here

Resume after [P01_STATUS.md](P01_STATUS.md) records a visible RME device and a
measured loopback row; replace `realtime-audio-synthetic-smoke` with a measured
RME callback report validated by
`open-lola validate-realtime-audio-engine-report <path>`.
