# M07 Status

## Current status

- Status: Partial.
- Canonical milestone: [M07 AVB Professional AoIP Evaluation](../milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md)

Canonical objective:

Evaluate AVB, TSN, AES67, RAVENNA, Dante, and related professional AoIP modes
as benchmark-only professional interop comparisons against the direct UDP PCM
baseline. M07 must not block the direct Core Audio plus UDP PCM path.

Canonical assumptions:

- Direct UDP PCM remains the baseline.
- AVB, AES67, RAVENNA, Dante, TSN, and related professional AoIP modes are
  benchmark-only unless a later measured report explicitly justifies an
  optional interop use.
- M07 starts only after M05/M06 can provide the direct route baseline.
- Full current standards or vendor profiles are required before implementation.

Canonical dependencies:

- M05 direct UDP PCM route baseline.
- M06 fixed-target direct UDP drift/PLC baseline.
- Target AVB/AES67/RAVENNA/Dante hardware or software endpoints.
- PTP-capable network evidence where relevant.
- Standards/vendor profile access.

Canonical affected modules/files:

- [../../Sources/OpenLolaCore/AoipEvaluationReport.swift](../../Sources/OpenLolaCore/AoipEvaluationReport.swift)
- [../../Sources/OpenLolaCore/NetworkAoipCertification.swift](../../Sources/OpenLolaCore/NetworkAoipCertification.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift](../../Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift)
- [../../Tests/OpenLolaCoreTests/NetworkAoipCertificationTests.swift](../../Tests/OpenLolaCoreTests/NetworkAoipCertificationTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json)
- [../../Tests/OpenLolaCoreTests/Fixtures/NetworkAoipCertificationReports/valid/g06-network-aoip-certification-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/NetworkAoipCertificationReports/valid/g06-network-aoip-certification-partial.json)
- Future AoIP adapter prototypes only after gate acceptance.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Canonical implementation sequence:

1. Wait until M05/M06 provide the direct UDP PCM baseline.
2. Record available hardware, switch features, and endpoint profiles.
3. Read and cite required current standards or vendor profiles before direct
   protocol work.
4. Measure each mode against direct UDP PCM on the same path where possible.
5. Stress the route with competing non-audio traffic.
6. Record benchmark-only accept/reject/defer verdicts.

Canonical acceptance criteria:

- Every evaluated mode has PASS, FAIL, or PARTIAL.
- PTP data is explicit when relevant.
- Worst-case load is measured, not inferred.
- Accepted modes are labeled benchmark-only interop candidates. They are never
  a default replacement for direct UDP PCM by assumption.
- M07 PASS or PARTIAL does not block M03, M05, or M06 closure.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added `AoipEvaluationReport` and supporting AoIP mode, usage, PTP profile,
  endpoint profile, switch profile, standards/profile evidence, baseline
  comparison, and WCRT-style stress models.
- Added validation for required fields, PTP profile presence, explicit
  standards/vendor evidence, direct UDP PCM baseline fields, stress packet-age
  ordering, and nonnegative packet loss.
- Added PASS guards requiring same-path direct UDP PCM baseline, measured stress
  case, measured p99 superiority over direct UDP PCM, locked/documented PTP,
  documented switch profile, known endpoint buffers, and no default replacement
  usage.
- Documented the operating policy that AVB, AES67, RAVENNA, Dante, TSN, and
  related professional AoIP paths are benchmark-only and cannot block direct
  UDP PCM implementation or closure.
- Documented the sequencing rule that M07 runs only after M05/M06 can provide
  the direct UDP PCM baseline.
- Added a synthetic PARTIAL AVB evaluation fixture.
- Added `open-lola validate-aoip-report <path>`.
- Added `open-lola aoip-synthetic-smoke`.
- Added the G06 `NetworkAoipCertificationReport` wrapper around accepted G04
  route certification, accepted G05 fixed-target drift/PLC certification, and
  a PASS AoIP evaluation report.
- Added G06 PASS guards for measured run mode, accepted direct baselines,
  professional AoIP mode, baseline route-id parity, route identity parity, PTP,
  stress, and profile artifacts, and placeholder evidence rejection.
- Added `open-lola validate-network-aoip-certification-report <path>`.
- Added `open-lola network-aoip-certification-synthetic-smoke`.
- Added [../reports/M07_AOIP_EVALUATION_2026-05-02.md](../reports/M07_AOIP_EVALUATION_2026-05-02.md).

## Verified work

- Red test run before implementation failed on missing M07 AoIP types.
- `swift test --filter AoipEvaluationReportTests` passed with 8 M07 tests.
- `swift test` passed with 49 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- `.build/debug/open-lola validate-aoip-report
  Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json`
  passed.
- `.build/debug/open-lola aoip-synthetic-smoke` emitted a PARTIAL report and
  passed validation.
- Red G06 certification test-first run failed on missing
  `NetworkAoipCertificationReport`, validation errors, and synthetic smoke.
- `swift test --filter NetworkAoipCertification` passed with 14 G06 tests after
  adding the wrapper and CLI branch.

## Partially completed work

- M07 source validation, G06 certification wrapper validation, and synthetic
  smoke are complete.
- No AVB, TSN, AES67, RAVENNA, or Dante hardware path has been measured.
- No PTP lock state has been observed on target switches/endpoints.
- No WCRT-style competing-traffic stress case has been run.
- M07 is not on the critical path for direct UDP PCM, drift, or PLC closure.

## Deferred work

- Identify available AVB, AES67, RAVENNA, Dante, or TSN-capable endpoints and
  switches only after M05/M06 direct baselines exist.
- Record PTP version, profile, domain, master, lock state, and failure behavior.
- Read required standards or vendor profiles for the actual target mode.
- Compare the evaluated mode against same-path M05 route and M06 fixed-target
  direct UDP PCM baselines.
- Run WCRT-style competing-traffic stress cases.

## Open tasks

Canonical progress checklist:

- [x] Add AoIP evaluation report schema.
- [x] Add PTP, baseline, and stress guard tests.
- [x] Add synthetic partial fixture and smoke.
- [x] Add G06 network AoIP certification wrapper validator.
- [ ] Inventory available AoIP hardware after M05/M06 direct baselines.
- [ ] Record real PTP/switch profile data.
- [ ] Read required standards or vendor profiles for target hardware.
- [ ] Run direct UDP PCM baseline comparison.
- [ ] Run stress cases.
- [ ] Record verdicts.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: Q005, Q006, SOTA025, SOTA026, SOTA027, SOTA028, SOTA029, SOTA030, SOTA031, SOTA032, SOTA034, SOTA036, SOTA037, SOTA076, SOTA077, SOTA078, SOTA079, SOTA080, SOTA081 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: PTP, AVB, TSN, AES67, RAVENNA, and Dante stay gated until profile, hardware, switch, endpoint, and WCRT evidence exists.

Faster-than-LoLa companion implementation plan:

- [x] Keep M07 optional and benchmark-only. It must not block M03, M05, or M06
  direct Core Audio plus UDP PCM closure.
- [x] Start only after M05 route and M06 fixed-target same-path direct UDP PCM
  baselines exist. Every accepted AoIP mode must compare against that baseline
  on the same route or record why same-path comparison is impossible.
- [x] Add a G06 certification wrapper that refuses PASS without accepted G04
  route, accepted G05 drift/PLC, measured professional AoIP, PTP, profile, and
  stress evidence.
- [ ] Inventory actual AVB, AES67, RAVENNA, Dante, or TSN-capable devices and
  switches before writing adapter code. Synthetic fixtures remain PARTIAL.
- [ ] Record PTP version, profile, domain, master, lock state, failure behavior,
  endpoint buffer settings, switch queue/QoS settings, and competing-traffic
  stress method.
- [ ] Accept an AoIP mode only as `benchmark-only-interop`; reject any report
  that claims default replacement without measured p99 superiority and unchanged
  audio playout target.
- [ ] Do not add vendor SDK dependencies to the generic build. Any vendor tool
  integration must be optional and isolated behind report generation or runtime
  detection.

## Known blockers

- Hardware and standards access may be unavailable.
- Dante and some profiles may require vendor tooling or licensing.
- Q005 and Q006 remain open because synthetic reports do not identify real
  endpoints, switches, PTP lock state, or WCRT behavior.
- G06 can validate source-level report boundaries, but cannot certify physical
  network timing or AoIP behavior until accepted G04/G05 baselines and measured
  AoIP/PTP/profile/stress artifacts exist.
- M07 is intentionally not a blocker for direct UDP PCM. If AoIP hardware is
  unavailable, continue M03/M05/M06 with the direct path.

TODO(human): [M07 timing network] -> Identify PTP, AVB, AES67, RAVENNA, or Dante-capable switches/endpoints for Q005-Q006 -> [no interop hardware / AVB-only / professional AoIP endpoints]

## Test coverage status

Canonical test plan:

Before: no profile evidence exists.

After:

- AoIP evaluation report schema and validator tests pass;
- synthetic AoIP smoke emits a PARTIAL report;
- each tested mode has a report with explicit profile data;
- direct UDP PCM comparison exists;
- M05/M06 direct UDP PCM baseline exists before M07 measurements start;
- stress-case metrics exist;
- no mode changes default playout latency without measured superiority.

Coverage state: Swift tests cover valid synthetic AVB fixture decoding, JSON
round trip, PTP profile guard for PASS, same-path baseline guard for PASS,
measured stress guard for PASS, default-replacement rejection, measured
superiority guard, and synthetic smoke validation. G06 tests cover valid
PARTIAL fixture decoding, JSON round trip, missing-source PARTIAL rejection,
PASS-mode guard, nested G04/G05/M07 verdict guards, professional AoIP mode
guard, direct-link baseline presence, AoIP/direct baseline route-id parity,
route identity parity across G04/G05/M07, missing artifact rejection,
placeholder evidence rejection, and synthetic smoke validation.

## Relevant files touched

Planned affected modules/files:

- Future interop evaluation reports.
- Future AoIP adapter prototypes only after gate acceptance.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

Live files touched:

- [../../Sources/OpenLolaCore/AoipEvaluationReport.swift](../../Sources/OpenLolaCore/AoipEvaluationReport.swift)
- [../../Sources/OpenLolaCore/NetworkAoipCertification.swift](../../Sources/OpenLolaCore/NetworkAoipCertification.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift](../../Tests/OpenLolaCoreTests/AoipEvaluationReportTests.swift)
- [../../Tests/OpenLolaCoreTests/NetworkAoipCertificationTests.swift](../../Tests/OpenLolaCoreTests/NetworkAoipCertificationTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json)
- [../../Tests/OpenLolaCoreTests/Fixtures/NetworkAoipCertificationReports/valid/g06-network-aoip-certification-partial.json](../../Tests/OpenLolaCoreTests/Fixtures/NetworkAoipCertificationReports/valid/g06-network-aoip-certification-partial.json)
- [../reports/M07_AOIP_EVALUATION_2026-05-02.md](../reports/M07_AOIP_EVALUATION_2026-05-02.md)
- [../milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md](../milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../MILESTONE_INDEX.md](../MILESTONE_INDEX.md)
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)

## Latest verification

- 2026-05-02: Red G06 test-first run failed on missing
  `NetworkAoipCertificationReport`, validation errors, and synthetic smoke.
- 2026-05-02: `swift test --filter NetworkAoipCertification` passed with 14
  G06 tests.
- 2026-05-02: `swift build` passed after the SwiftPM manifest sandbox failure
  was rerun outside the sandbox.
- 2026-05-02: `swift test` passed with 246 tests after the SwiftPM manifest
  sandbox failure was rerun outside the sandbox.
- 2026-05-02: `.build/debug/open-lola
  validate-network-aoip-certification-report
  Tests/OpenLolaCoreTests/Fixtures/NetworkAoipCertificationReports/valid/g06-network-aoip-certification-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola
  network-aoip-certification-synthetic-smoke` passed and emitted
  `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola validate-aoip-report
  Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json`
  passed and emitted `VERDICT: PARTIAL`.
- 2026-05-02: `.build/debug/open-lola aoip-synthetic-smoke` passed and emitted
  `VERDICT: PARTIAL`.
- 2026-05-02: `bash scripts/verify-docs.sh` passed after the final G06 status
  ledger update.
- 2026-05-02: `swift test --filter AoipEvaluationReportTests` passed with 8 M07 tests.
- 2026-05-02: `swift test` passed with 49 tests.
- 2026-05-02: `swift build` passed after sandbox escalation.
- 2026-05-02: `.build/debug/open-lola validate-aoip-report
  Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json`
  passed.
- 2026-05-02: `.build/debug/open-lola aoip-synthetic-smoke` passed and emitted
  `VERDICT: PARTIAL`.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- 2026-05-02: faster-than-LoLa companion plan update passed
  `bash scripts/verify-docs.sh` and `shellcheck scripts/*.sh`.
- 2026-05-02: M07 policy updated so AVB, AES67, RAVENNA, Dante, TSN, and
  related AoIP work is benchmark-only, does not block direct UDP PCM, and runs
  only after M05/M06 direct baselines exist.
- 2026-05-02: `bash scripts/verify-docs.sh` passed after the M07 benchmark-only
  status update.
- 2026-05-02: `shellcheck scripts/*.sh` passed after the M07 benchmark-only
  status update.
- VERDICT: PARTIAL

## Next recommended steps

Finish M05/M06 direct UDP PCM baselines first. Only then answer Q005 and Q006
by identifying available AoIP hardware, PTP-capable switches, endpoint
profiles, and required standards or vendor profile access. Then create a
benchmark-only AoIP report and run `open-lola validate-aoip-report <path>`.
After accepted G04/G05 baselines exist, wrap the measured M07 report in a G06
certification report and run
`open-lola validate-network-aoip-certification-report <path>`.

## Resume here

Resume M07 only after a same-path M05/M06 direct UDP PCM baseline exists. Then
answer Q005 and Q006 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md) and create
the first measured benchmark-only interop report from real hardware, PTP
profile, direct UDP PCM baseline, and WCRT-style stress data. Then wrap that
report with accepted G04/G05 evidence in a G06 network AoIP certification
report. Do not mark M07 or G06 PASS from synthetic reports, and do not let
M07/G06 delay M03/M05/M06 direct path work.
