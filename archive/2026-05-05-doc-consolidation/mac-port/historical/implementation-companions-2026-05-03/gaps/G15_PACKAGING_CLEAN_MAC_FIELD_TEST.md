# G15 Packaging Clean Mac Field Test

## LoLa Comparison

LoLa is distributed as installable Windows software with specific hardware and
network setup expectations. The Mac alternative needs a clean-Mac field path,
but packaging cannot certify the product until measured runtime evidence exists.

## Current Repo State

- Related milestone: [../milestones/M15_PACKAGING_FIELD_TEST.md](../milestones/M15_PACKAGING_FIELD_TEST.md)
- Related prototype: [../prototype/P05_FIELD_READY_RUNTIME.md](../prototype/P05_FIELD_READY_RUNTIME.md)
- Live status: [../status/M15_STATUS.md](../status/M15_STATUS.md), [../prototype/status/P05_STATUS.md](../prototype/status/P05_STATUS.md)
- Open question: Q010 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)
- Existing source validates packaging field-test and aggregate field runtime
  proof reports.
- Existing source has `packaging-field-run`, an ad-hoc local package-layout
  handoff that reads M10, M13, and M14 reports, writes package contents,
  entitlements, purpose-string, docs, and report-template artifacts, and emits
  a PARTIAL M15 report.
- Existing source has `field-runtime-proof-run`, a P05 aggregate proof handoff
  that reads M10, M13, M14, and M15 reports and emits a PARTIAL P05 report.
- Missing piece: real signing identity, Developer ID package, notarization,
  Gatekeeper, and clean-Mac evidence.

## Implementation Plan

1. Keep ad-hoc local package as PARTIAL until G10/G13/G14 provide measured
   runtime evidence.
2. Record signing identity choice, bundle identifiers, hardened runtime,
   entitlements, purpose strings, secure timestamp, and notarization method.
3. Build CLI and app bundle with required resources and report templates. Done
   for ad-hoc local package-layout handoff; real signed archive remains open.
4. Sign, notarize, staple, and run Gatekeeper assessment where Developer ID is
   available.
5. Install on clean Mac, run CLI report-writing workflow, app launch, permission
   prompts, RME visibility, ATEM status if included, and machine-readable field
   verdict.
6. Update P05 aggregate proof from real M13, M14, and M15 reports.

## Acceptance Tests

- `validate-packaging-field-report` accepts measured clean-Mac report.
- `validate-field-runtime-proof` accepts aggregate P05 proof.
- PASS requires Developer ID signing, hardened runtime, notarization, purpose
  strings, Gatekeeper, clean-Mac launch, report writing, and verdict line.

## Blockers / TODO(human)

- TODO(human): [M15 distribution] -> Provide signing identity and clean-Mac target for Q010 -> [ad-hoc local package / Developer ID signed package / defer packaging]
- Requires clean Mac target and signing credentials.

## Verification Commands

```bash
swift run open-lola packaging-field-run --integrated-report <integrated-av-report.json> --app-report <native-app-report.json> --recording-report <recording-report.json> --output-dir <package-dir> --report <packaging-report.json>
swift run open-lola field-runtime-proof-run --integrated-report <integrated-av-report.json> --app-report <native-app-report.json> --recording-report <recording-report.json> --packaging-report <packaging-report.json> --output <field-runtime-proof.json>
swift run open-lola validate-packaging-field-report <packaging-report.json>
swift run open-lola validate-field-runtime-proof <field-runtime-proof.json>
swift build
swift test
```

## Resume here

Use `packaging-field-run` and `field-runtime-proof-run` for the bounded ad-hoc
handoff first. Do not mark packaging PASS from a development Mac. Record
Developer ID signing, notarization, Gatekeeper, and clean-Mac evidence first.

VERDICT: PARTIAL
