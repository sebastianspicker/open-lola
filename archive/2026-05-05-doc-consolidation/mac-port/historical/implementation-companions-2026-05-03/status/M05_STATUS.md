# M05 Status

## Current status

- Status: Partial.
- Canonical milestone: [M05 Mac-To-Mac Route Certification](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)

Canonical objective:

Certify Mac-to-Mac UDP PCM routes across direct link, dedicated switch, and
campus path with p50/p95/p99/max/loss reports.

Canonical assumptions:

- Direct link is the first route.
- Dedicated switch is second.
- Campus path is certified only with packet capture evidence.

Canonical dependencies:

- M01 report schema.
- M03 selected fastest endpoint mode.
- M04 UDP PCM packet contract.
- Two Macs and wired network access.

Canonical affected modules/files:

- [../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift](../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift](../../Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json](../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json)
- Future packet capture notes.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)

Canonical implementation sequence:

1. Add sender and receiver CLIs for UDP PCM test traffic.
2. Record sender timestamps, receiver packet age, sequence gaps, late packets,
   and drops.
3. Add route labels for direct link, dedicated switch, and campus path.
4. Run marked and unmarked DSCP cases where allowed.
5. Correlate packet capture with receiver reports.
6. Produce route verdicts.

Canonical acceptance criteria:

- Every route has a verdict: PASS, FAIL, or PARTIAL.
- DSCP classification is honored, rewritten, ignored, harmful, or not tested
  with reason.
- PASS requires a direct wired two-Mac route report with packet-capture
  correlation, DSCP classification, packet age p50/p95/p99/max, loss, late,
  reorder counts, and no hidden playout growth.
- Route reports do not justify hidden playout growth.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added `UdpPcmRouteReport` and supporting route, endpoint, packet-mode,
  network, DSCP, packet-capture, and packet-age metric models.
- Added route report validation for required fields, positive packet-mode
  values, DSCP range and classification evidence, packet accounting,
  p50/p95/p99/max ordering, fixed playout target, packet-capture correlation,
  and hidden playout growth.
- Added a valid direct-link route-report fixture that documents the schema. The
  fixture is synthetic and does not certify a real route.
- Added `open-lola validate-route-report <path>`.
- Added `open-lola udp-pcm-route-localhost-smoke`, which emits a PARTIAL route
  report after sending multiple UDP PCM packets over loopback.
- Added `open-lola udp-pcm-send-once <host> <port>` and
  `open-lola udp-pcm-receive-once <port>` for direct sender/receiver route
  preflight.
- Added `UdpPcmRouteRunConfiguration` and
  `open-lola udp-pcm-route-run --role sender|receiver --peer <ip> --port
  <port> --sample-rate <hz> --frames <n> --channels <n> --duration-seconds
  <n> --output <path> [--dscp <0-63>]` for continuous bounded route runs.
- Added a continuous sender loop using connected nonblocking UDP sockets,
  fixed packet count, fixed packet interval, optional DSCP marking, and the
  existing M04 UDP PCM packet contract. Connected UDP send failures are counted
  in the sender summary instead of terminating the process.
- Added a continuous receiver loop using bounded nonblocking receive,
  packet-mode validation, packet age p50/p95/p99/max, late/reorder/duplicate
  counters, fixed playout target, and hidden playout growth set false unless a
  future runner explicitly changes target policy.
- Tightened `UdpPcmRouteReport` validation so `VERDICT: PASS` rejects DSCP
  `notTested`; PASS must include an observed DSCP classification.
- Added a continuous localhost route smoke around the new sender/receiver loop.
- Added the G04 `MacToMacRouteCertificationReport` wrapper around ordered
  direct-link, dedicated-switch, and campus route candidates.
- Added G04 PASS guards for measured run mode, direct-link PASS, non-localhost
  route reports, packet-mode parity, packet capture artifacts, and placeholder
  evidence.
- Added `open-lola validate-route-certification-report <path>` and
  `open-lola route-certification-synthetic-smoke`.
- Added [../reports/M05_ROUTE_CERTIFICATION_2026-05-02.md](../reports/M05_ROUTE_CERTIFICATION_2026-05-02.md).

## Verified work

- Red test run before implementation failed on missing M05 route-report types.
- `swift test --filter UdpPcmRouteReportTests` passed with 8 M05 tests.
- `swift test` passed with 33 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- `swift run open-lola validate-route-report
  Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json`
  passed.
- `swift run open-lola udp-pcm-route-localhost-smoke` emitted a PARTIAL route
  report and passed validation.
- `.build/debug/open-lola udp-pcm-send-once 127.0.0.1 55555` and
  `.build/debug/open-lola udp-pcm-receive-once 55555` exchanged one UDP PCM
  packet over loopback.
- Red test run for the continuous route runner failed on the missing
  `UdpPcmRouteRunConfiguration`, `UdpPcmContinuousRouteLocalhostSmoke`, and
  `passWithoutDscpClassification` implementation.
- `swift test --filter UdpPcmRouteReportTests` passed with 13 M05 tests after
  adding continuous route runner support.
- Red G04 test-first run failed on missing
  `MacToMacRouteCertificationReport`, validation errors, and synthetic smoke.
- `swift test --filter MacToMacRoute` passed with 10 G04 tests after adding the
  certification wrapper and CLI branch.
- `swift build` passed after the continuous route runner implementation.
- `swift test` passed with 141 tests after the continuous route runner
  implementation.
- `.build/debug/open-lola udp-pcm-route-run --role sender --peer 127.0.0.1
  --port 55558 --sample-rate 5 --frames 1 --channels 2 --duration-seconds 1
  --output /private/tmp/open-lola-route-sender.json --dscp 46` wrote a sender
  summary with 5 packets sent and 0 send errors.
- `.build/debug/open-lola udp-pcm-route-run --role receiver --peer 127.0.0.1
  --port 55558 --sample-rate 5 --frames 1 --channels 2 --duration-seconds 5
  --output /private/tmp/open-lola-route-receiver.json` wrote a receiver route
  report with 5 packets received and `VERDICT: PARTIAL`.
- `.build/debug/open-lola validate-route-report
  /private/tmp/open-lola-route-receiver.json` passed.
- `bash scripts/verify-docs.sh` passed after the M05 status update.
- `shellcheck scripts/*.sh` passed after the M05 status update.
- `swift build` passed after sandbox escalation for SwiftPM manifest
  compilation.
- `swift test` passed with 219 tests after adding the G04 wrapper.
- `.build/debug/open-lola validate-route-certification-report
  Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/valid/g04-route-certification-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- `.build/debug/open-lola route-certification-synthetic-smoke` passed and
  emitted `VERDICT: PARTIAL`.
- `.build/debug/open-lola udp-pcm-route-localhost-smoke` passed and emitted
  `VERDICT: PARTIAL`.
- `shellcheck scripts/*.sh` passed after the G04 wrapper implementation.
- `bash scripts/verify-docs.sh` passed after recording the G04 verification
  evidence.

## Partially completed work

- M05/G04 source validation, localhost mechanics, one-shot preflight,
  continuous sender/receiver route loops, and ordered route-certification
  wrapper validation are complete.
- No physical direct-link, dedicated-switch, or campus route has been certified.
- The direct-link fixture validates the report contract only; it is not live
  measurement evidence.

## Deferred work

- Run the continuous sender/receiver on two Macs over a direct wired link.
- Produce real direct-link packet age, jitter, loss, late, reorder, duplicate,
  DSCP, and packet-capture evidence.
- Repeat on a dedicated switch.
- Repeat on the campus path only after capture points and permissions are
  known.

## Open tasks

Canonical progress checklist:

- [x] Add sender CLI.
- [x] Add receiver CLI.
- [x] Add continuous route runner CLI.
- [x] Add G04 route-certification wrapper validator.
- [x] Add route report schema tests.
- [ ] Certify direct link.
- [ ] Certify dedicated switch.
- [ ] Certify campus path.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q004, SOTA005, SOTA011, SOTA012, SOTA016, SOTA019, SOTA033, SOTA038 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: direct UDP baseline and DSCP route classification are captured before campus or relay routes can be accepted.

Faster-than-LoLa companion implementation plan:

- [x] Add a continuous route runner beyond one-shot smoke. The CLI surface
  should be `open-lola udp-pcm-route-run --role sender|receiver --peer <ip>
  --port <port> --sample-rate <hz> --frames <n> --channels <n>
  --duration-seconds <n> --output <path>`.
- [x] Reuse the M04 one-block UDP PCM packet contract unchanged. One audio block
  is one datagram in fastest mode; no retransmission wait and no adaptive
  playout target growth.
- [x] Use nonblocking BSD UDP sockets for the first measured route. The sender
  uses connected UDP; the receiver binds the measured port. Apply socket setup
  before the timed run and record send/receive errors as counters, not callback
  blockers.
- [ ] Run physical routes in order: direct wired link, dedicated switch, then
  campus path only after capture permissions and route labels are known.
- [ ] Record packet capture correlation for every PASS route: packet count,
  timestamp window, interface, capture filter, DSCP observed value, and whether
  DSCP was honored, rewritten, ignored, harmful, or not tested with reason.
- [ ] Produce route reports with packet age p50/p95/p99/max, sequence gaps,
  late/lost/reordered/duplicate packets, fixed playout target, route verdict,
  and hidden-growth evidence.
- [ ] Fill the G04 route-certification wrapper with measured route reports and
  packet-capture artifact paths.

## Known blockers

- Requires two Macs and network access.
- Campus packet capture may need administrative coordination.
- Q004 remains open because localhost smoke cannot classify physical route DSCP
  behavior.
- Continuous runner and G04 wrapper reports remain PARTIAL until packet capture
  supplies the observed DSCP value, receiver correlation, and artifact path.

TODO(human): [M05 campus route access] -> Identify packet-capture points and permissions for Q004 -> [direct link only / dedicated switch / campus path with admin coordination]

## Test coverage status

Canonical test plan:

Before: no network route verdicts exist.

After:

- route report schema and validator tests pass;
- localhost route smoke emits a PARTIAL report;
- one-shot sender and receiver CLIs exchange one UDP PCM packet;
- continuous sender and receiver CLIs run bounded packet loops;
- direct link report validates;
- dedicated switch report validates where hardware exists;
- campus path report validates where access exists;
- p50/p95/p99/max/loss fields are present;
- `swift build` and `swift test` pass.

Coverage state: Swift tests cover valid direct-link route fixture decoding,
route report JSON round trip, DSCP not-tested reason, packet-capture
correlation for PASS, DSCP classification required for PASS, packet age over
target for PASS, hidden playout growth for PASS, packet accounting mismatch,
route-run configuration parsing, bounded packet-count calculation, the legacy
localhost route smoke report, continuous localhost route smoke validation, G04
route-certification fixture validation, direct-link PASS requirements,
localhost rejection, packet-mode mismatch rejection, capture-artifact
requirements, placeholder rejection, duplicate-route rejection, and JSON round
trip.

## Relevant files touched

Planned affected modules/files:

- Future UDP sender/receiver CLI.
- Future route certification report fixtures.
- Future packet capture notes.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)

Live files touched:

- [../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift](../../Sources/OpenLolaCore/UdpPcmRouteCertification.swift)
- [../../Sources/OpenLolaCore/MacToMacRouteCertification.swift](../../Sources/OpenLolaCore/MacToMacRouteCertification.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift](../../Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift)
- [../../Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift](../../Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json](../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json)
- `../../Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/`
- [../reports/M05_ROUTE_CERTIFICATION_2026-05-02.md](../reports/M05_ROUTE_CERTIFICATION_2026-05-02.md)
- [../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

## Latest verification

- 2026-05-02: `swift test --filter UdpPcmRouteReportTests` passed with 8 M05 tests.
- 2026-05-02: `swift test` passed with 33 tests.
- 2026-05-02: `swift build` passed after sandbox escalation.
- 2026-05-02: `swift run open-lola validate-route-report
  Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json`
  passed after sandbox escalation.
- 2026-05-02: `swift run open-lola udp-pcm-route-localhost-smoke` passed after
  sandbox escalation and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola udp-pcm-send-once 127.0.0.1 55555`
  passed.
- 2026-05-02: `.build/debug/open-lola udp-pcm-receive-once 55555` passed.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- 2026-05-02: red test-first continuous route-runner pass failed on missing
  runner types and stricter DSCP PASS validation before implementation.
- 2026-05-02: `swift test --filter UdpPcmRouteReportTests` passed with 13 M05
  tests after continuous route runner implementation.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift test` passed with 141 tests.
- 2026-05-02: bounded localhost `udp-pcm-route-run` sender wrote
  `/private/tmp/open-lola-route-sender.json` with 5 packets sent and 0 send
  errors.
- 2026-05-02: bounded localhost `udp-pcm-route-run` receiver wrote
  `/private/tmp/open-lola-route-receiver.json` with 5 packets received,
  packet age metrics, loss accounting for the longer receive window, and
  `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola validate-route-report
  /private/tmp/open-lola-route-receiver.json` passed.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: red G04 test-first run failed on missing
  `MacToMacRouteCertificationReport`, validation errors, and synthetic smoke.
- 2026-05-02: `swift test --filter MacToMacRoute` passed with 10 G04 tests
  after implementation.
- 2026-05-02: `swift build` passed after sandbox escalation for SwiftPM
  manifest compilation.
- 2026-05-02: `swift test` passed with 219 tests.
- 2026-05-02: `.build/debug/open-lola validate-route-certification-report
  Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/valid/g04-route-certification-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola route-certification-synthetic-smoke`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola udp-pcm-route-localhost-smoke` passed
  and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: `bash scripts/verify-docs.sh` passed after the G04 status
  update.
- VERDICT: PARTIAL

## Next recommended steps

Use the one-shot sender/receiver only as preflight. Run `udp-pcm-route-run` on
two directly wired Macs with packet capture before testing switch or campus
paths, then validate the G04 wrapper with
`open-lola validate-route-certification-report <path>`.

## Resume here

Use the implemented M05 report schema, continuous route runner, and G04 wrapper
to certify the direct-link route before touching campus network paths. Do not
mark M05 PASS until packet-capture correlation, packet capture artifact paths,
and DSCP classification exist for each accepted physical route.
