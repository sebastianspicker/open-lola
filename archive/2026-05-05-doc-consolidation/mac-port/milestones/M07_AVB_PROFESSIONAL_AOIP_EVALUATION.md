# M07 AVB Professional AoIP Evaluation

## Objective

Evaluate AVB, TSN, AES67, RAVENNA, Dante, and related professional AoIP modes
as gated interop options against the direct UDP PCM baseline.

## Background/Context

Professional AoIP modes may be useful in managed academic environments, but
they introduce profile, endpoint, switch, PTP, and vendor-buffer behavior
outside direct app control.

## Reverse-Engineering Findings

Static fact:
[../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
shows Windows LoLa used its own media path, not standards-based AoIP. This
milestone is a Mac-native interop evaluation, not reverse-engineered LoLa work.

## Research Findings

[../../research/RESEARCH_NETWORK_TIMING_2026.md](../../research/RESEARCH_NETWORK_TIMING_2026.md)
requires PTP version/profile/domain/master, switch features, link rates, traffic
classes, stream reservation or schedule, WCRT-style load cases, p50/p95/p99/max,
loss, recovery behavior, and comparison against direct UDP PCM.

## Assumptions

- Direct UDP PCM remains the baseline.
- AVB/TSN/AES67/RAVENNA/Dante are optional modes unless measured superiority is
  proven.
- Full current standards or vendor profiles are required before implementation.

## Dependencies

- M05 direct UDP PCM baseline.
- Target AVB/AES67/RAVENNA/Dante hardware or software endpoints.
- PTP-capable network evidence where relevant.
- Standards/vendor profile access.

## Affected Modules/Files

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

## Implementation Plan

1. Record available hardware, switch features, and endpoint profiles.
2. Read and cite required current standards or vendor profiles before direct
   protocol work.
3. Measure each mode against direct UDP PCM on the same path where possible.
4. Stress the route with competing non-audio traffic.
5. Record accept/reject/defer verdicts.

## Test Plan

Before: no profile evidence exists.

After:

- AoIP evaluation report schema and validator tests pass;
- synthetic AoIP smoke emits a PARTIAL report;
- G06 network AoIP certification wrapper validates only when tied to accepted
  G04/G05 direct baselines and a PASS AoIP evaluation report;
- each tested mode has a report with explicit profile data;
- direct UDP PCM comparison exists;
- stress-case metrics exist;
- no mode changes default playout latency without measured superiority.

## Validation Method

Use [../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md)
Gate 4 and reject modes that rely on undocumented buffers or unmeasured timing.

## Acceptance Criteria

- Every evaluated mode has PASS, FAIL, or PARTIAL.
- PTP data is explicit when relevant.
- Worst-case load is measured, not inferred.
- Accepted modes are labeled interop or optional fastest local mode, not
  default replacement by assumption.
- G06 certification PASS rejects synthetic route, fixture profile evidence,
  and missing PTP/profile/stress artifacts.

Clean-room/license gate:

- Standards, vendor profile, SDK, driver, and redistribution constraints must
  be recorded before any adapter is published.
- Proprietary vendor tooling or licensed SDKs cannot be vendored or required by
  default builds without M05/M07 compliance review.
- Interop reports must cite measured public facts and original open-lola tests,
  not reverse-engineering evidence.

SOTA 2026 gate:

- Rows: Q005, Q006, SOTA025, SOTA026, SOTA027, SOTA028, SOTA029, SOTA030, SOTA031, SOTA032, SOTA034, SOTA036, SOTA037, SOTA076, SOTA077, SOTA078, SOTA079, SOTA080, SOTA081 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: PTP, AVB, TSN, AES67, RAVENNA, and Dante stay gated until profile, hardware, switch, endpoint, and WCRT evidence exists.

## Risks and Mitigations

- R006: deterministic claims may not hold. Mitigation: WCRT-style stress tests.
- R009: standards-controlled protocols may need full specs. Mitigation: gate
  implementation on standards access.

## Known Blockers

- Hardware and standards access may be unavailable.
- Dante and some profiles may require vendor tooling or licensing.

TODO(human): [M07 timing network] -> Identify PTP, AVB, AES67, RAVENNA, or Dante-capable switches/endpoints for Q005-Q006 -> [no interop hardware / AVB-only / professional AoIP endpoints]

## Progress Checklist

- [x] Add AoIP evaluation report schema.
- [x] Add PTP, baseline, and stress guard tests.
- [x] Add synthetic partial fixture and smoke.
- [x] Add G06 network AoIP certification wrapper validator.
- [ ] Inventory available AoIP hardware.
- [ ] Record real PTP/switch profile data.
- [ ] Read required standards or vendor profiles for target hardware.
- [ ] Run direct UDP PCM baseline comparison.
- [ ] Run stress cases.
- [ ] Record verdicts.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Next Recommended Action

Use `open-lola validate-aoip-report <path>` to validate the first measured
interop report, then validate the G06 wrapper with
`open-lola validate-network-aoip-certification-report <path>`. Do not write
protocol adapters first; inventory available AoIP hardware and compare one
measured path against M05 direct UDP PCM.

## Resume here

Start by answering Q005 and Q006 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md),
then create the first measured interop report from real hardware, PTP profile,
direct UDP PCM baseline, and WCRT-style stress data. Do not mark M07 PASS from
synthetic reports or until the G06 certification wrapper passes.
