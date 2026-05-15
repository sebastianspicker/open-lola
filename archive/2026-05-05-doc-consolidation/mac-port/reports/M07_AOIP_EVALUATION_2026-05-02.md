# M07 AoIP Evaluation Validation Report

Date: 2026-05-02  
Milestone: [M07 AVB Professional AoIP Evaluation](../milestones/M07_AVB_PROFESSIONAL_AOIP_EVALUATION.md)  
Status: PARTIAL

## Scope

This report validates the M07 source-level AoIP evaluation harness: report
schema, PTP/profile gates, direct UDP PCM baseline comparison gates,
WCRT-style stress gates, fixture validation, synthetic smoke output, and the
G06 network AoIP certification wrapper. It does not validate real AVB, TSN,
AES67, RAVENNA, or Dante behavior.

## AoIP Evaluation Contract

The report records:

- evaluated mode: direct UDP PCM, AVB, TSN, AES67, RAVENNA, or Dante;
- accepted usage: deferred, interop, optional fastest local mode, or rejected
  by validation if marked default replacement;
- PTP version, profile, domain, master clock, and lock state;
- switch model, firmware, link rate, traffic class, stream reservation, and
  schedule;
- sender and receiver endpoint vendor, model, firmware, profile, and buffer
  size;
- standards/vendor profile evidence;
- same-path direct UDP PCM baseline comparison;
- WCRT-style competing-traffic stress data.

PASS reports require same-path direct UDP PCM baseline, measured stress,
measured p99 superiority, documented locked PTP, documented switch and endpoint
profiles, and interop or optional-fastest-local-mode usage.

G06 certification PASS additionally requires measured mode, accepted G04/G05
direct baselines, a PASS AoIP evaluation report, baseline route-id and route
identity parity, PTP/profile/stress artifacts, and no placeholder or fixture
evidence.

## Commands

```bash
swift test --filter AoipEvaluationReportTests
swift test --filter NetworkAoipCertification
swift test
swift build
.build/debug/open-lola validate-aoip-report Tests/OpenLolaCoreTests/Fixtures/AoipEvaluationReports/valid/aoip-avb-partial.json
.build/debug/open-lola validate-network-aoip-certification-report Tests/OpenLolaCoreTests/Fixtures/NetworkAoipCertificationReports/valid/g06-network-aoip-certification-partial.json
.build/debug/open-lola aoip-synthetic-smoke
.build/debug/open-lola network-aoip-certification-synthetic-smoke
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- Red test run before implementation failed on missing M07 AoIP types.
- `swift test --filter AoipEvaluationReportTests` passed with 8 M07 tests.
- `swift test` passed with 49 tests.
- `swift build` passed after rerunning outside the SwiftPM sandbox failure.
- The synthetic PARTIAL AVB fixture passed CLI validation.
- The synthetic PARTIAL G06 certification fixture passed CLI validation.
- The synthetic smoke command emitted a PARTIAL report.
- The G06 certification synthetic smoke command emitted a PARTIAL report.
- Documentation verification passed.
- Shellcheck passed for the docs verifier script.

## Deferred Runtime Evidence

M07 cannot be marked PASS until real reports exist for:

- target AoIP endpoints and switch hardware;
- PTP version, profile, domain, master, lock state, and failure behavior;
- required standards or vendor profile access for the target mode;
- same-path M05 direct UDP PCM baseline;
- WCRT-style competing-traffic stress case;
- explicit PASS, FAIL, or PARTIAL verdict for each evaluated mode.

## Verdict

M07 source validation is complete, but physical AoIP/PTP/WCRT certification
remains open until the G06 wrapper is filled with measured physical evidence.

VERDICT: PARTIAL

## Resume here

Answer Q005 and Q006, then create the first measured interop report from real
hardware, PTP profile, direct UDP PCM baseline, and WCRT-style stress data.
Validate it with `open-lola validate-aoip-report <path>`, then validate the
G06 wrapper with `open-lola validate-network-aoip-certification-report <path>`.
