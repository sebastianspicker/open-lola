# M15 Packaging Field Test Validation Report

Date: 2026-05-03  
Milestone: [M15 Packaging Field Test](../milestones/M15_PACKAGING_FIELD_TEST.md)  
Status: PARTIAL

## Scope

This report validates the M15 source-level packaging and field-test contract:
package contents, signing readiness, notarization readiness, entitlement and
purpose-string readiness, clean-Mac probe fields, field-report coverage, fixture
validation, synthetic smoke output, an ad-hoc package-layout handoff, and the
aggregate P05 proof handoff. The 2026-05-03 F09 addendum also validates a
composite `field-readiness-run` source handoff that writes the M13 app runtime
report, M14 recording-session report, M15 ad-hoc package report, and P05 proof
from one integrated baseline. It does not validate a real signed app bundle,
notary ticket, Gatekeeper assessment, or clean-Mac launch.

## Current Reference Check

Checked official Apple sources:

- Notarizing macOS software before distribution:
  [https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- Hardened Runtime:
  [https://developer.apple.com/documentation/security/hardened-runtime](https://developer.apple.com/documentation/security/hardened-runtime)
- Entitlements:
  [https://developer.apple.com/documentation/bundleresources/entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
- Preparing your app for distribution:
  [https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution/](https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution/)

Source-derived implementation constraints:

- Developer ID distribution needs Developer ID signing and notarization.
- Notarization readiness includes valid signatures, hardened runtime, and secure
  timestamp.
- `notarytool`, Xcode Organizer, or the notary API are current submission paths;
  `altool` is rejected by the M15 PASS gate.
- Entitlement and purpose-string readiness must be recorded before clean-Mac
  field testing.

## Packaging Field-Test Contract

The report records:

- distribution method;
- app bundle, CLI, docs, report template, and package artifact contents;
- signing identity type, signature validity, hardened runtime, and secure
  timestamp;
- notarization tool, readiness, accepted ticket, stapling, and Gatekeeper
  assessment;
- microphone, camera, local-network, network-client, and sandbox-decision
  readiness;
- clean-Mac hardware, OS, architecture, launch, CLI smoke, permission prompts,
  media access, network access, and report write result;
- field-report endpoint, network, audio, video, control, recording, packaging,
  fallback-route, artistic/control deferral, and verdict-line coverage;
- PASS, FAIL, or PARTIAL verdict.

PASS reports require a measured run, app bundle, `open-lola` CLI, docs and
report templates, valid Developer ID signature for Developer ID distribution,
hardened runtime, secure timestamp, current notarization path, accepted and
stapled ticket, Gatekeeper acceptance, reviewed entitlements and purpose
strings, clean-Mac launch, CLI smoke, permission prompt record, media/network
access, report writing, complete field evidence, and a verdict line.

The bounded handoff commands now produce:

- an ad-hoc package layout with `Open LoLa.app`, `open-lola`,
  `open-lola-app`, docs, entitlements, purpose strings, and field-report
  template artifacts;
- a PARTIAL M15 report from M10, M13, and M14 reports;
- a PARTIAL P05 aggregate proof from M10, M13, M14, and M15 reports.
- a PARTIAL F09 field-readiness chain from one integrated baseline and output
  directory.

## Commands

```bash
swift test --filter PackagingFieldTest
swift test --filter FieldReadyRuntime
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
swift test
swift build
.build/debug/open-lola packaging-field-run --integrated-report /private/tmp/open-lola-g15-m10-integrated-av-smoke.json --app-report /private/tmp/open-lola-g15-m13-native-app-runtime-smoke.json --recording-report /private/tmp/open-lola-g15-m14-recording-session-run.json --output-dir /private/tmp/open-lola-g15-m15-package --report /private/tmp/open-lola-g15-m15-packaging-field-run.json
.build/debug/open-lola validate-packaging-field-report /private/tmp/open-lola-g15-m15-packaging-field-run.json
.build/debug/open-lola field-runtime-proof-run --integrated-report /private/tmp/open-lola-g15-m10-integrated-av-smoke.json --app-report /private/tmp/open-lola-g15-m13-native-app-runtime-smoke.json --recording-report /private/tmp/open-lola-g15-m14-recording-session-run.json --packaging-report /private/tmp/open-lola-g15-m15-packaging-field-run.json --output /private/tmp/open-lola-g15-p05-field-runtime-proof-run.json
.build/debug/open-lola validate-field-runtime-proof /private/tmp/open-lola-g15-p05-field-runtime-proof-run.json
.build/debug/open-lola field-readiness-run --integrated-report /private/tmp/open-lola-g15-m10-integrated-av-smoke.json --duration-seconds 30 --output-dir /private/tmp/open-lola-f09-field-readiness
.build/debug/open-lola validate-native-app-shell-report /private/tmp/open-lola-f09-field-readiness/m13-native-app-runtime-smoke.json
.build/debug/open-lola validate-recording-session-report /private/tmp/open-lola-f09-field-readiness/m14-recording-session.json
.build/debug/open-lola validate-packaging-field-report /private/tmp/open-lola-f09-field-readiness/m15-packaging-field.json
.build/debug/open-lola validate-field-runtime-proof /private/tmp/open-lola-f09-field-readiness/p05-field-runtime-proof.json
.build/debug/open-lola validate-packaging-field-report Tests/OpenLolaCoreTests/Fixtures/PackagingFieldTests/valid/packaging-field-test-partial.json
.build/debug/open-lola packaging-field-synthetic-smoke
```

## Results

- Red test run before implementation failed on missing M15 packaging/field-test
  types.
- `swift test --filter PackagingFieldTest` passed with 15 M15 tests.
- Red F09 test run before implementation failed on missing
  `FieldReadinessRunConfiguration` and `FieldReadinessRunner`.
- `swift test --filter FieldReadyRuntime` passed with 18 P05/F09 tests.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.
- `swift test` passed with 342 tests.
- `swift build` passed after rerunning outside the sandbox to avoid the known
  SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest
  failure.
- The ad-hoc packaging handoff generated a PARTIAL M15 report.
- The generated M15 report validator passed with `VERDICT: PARTIAL`.
- The P05 aggregate proof handoff generated a PARTIAL field-runtime proof.
- The generated P05 proof validator passed with `VERDICT: PARTIAL`.
- The composite `field-readiness-run` generated valid PARTIAL M13, M14, M15,
  and P05 reports under one output directory.
- The packaging field-test fixture validator passed with `VERDICT: PARTIAL`.
- The packaging field-test synthetic smoke command passed with
  `VERDICT: PARTIAL`.

## Deferred Runtime Evidence

M15 cannot be marked PASS until real reports exist for:

- Q010 signing identity, distribution method, entitlements, and clean-Mac target;
- signed app bundle and CLI package;
- valid code signature and hardened runtime;
- secure timestamp;
- accepted notarization ticket and stapling, or an explicitly scoped non-release
  distribution decision;
- Gatekeeper assessment on the clean Mac;
- app launch, CLI smoke, permissions, media access, network access, and report
  writing on the clean Mac;
- final field report over measured M01-M15 evidence.

## Verdict

M15 source validation is complete, but real signing, notarization, Gatekeeper,
and clean-Mac field certification remain open.

VERDICT: PARTIAL

## Resume here

Use `open-lola validate-packaging-field-report <path>` for the first measured
packaging field-test report. Use `open-lola field-runtime-proof-run` to refresh
the P05 aggregate proof after M15 changes. Keep M15 PARTIAL until Q010 is
answered and a real signed package launches and writes a verdict on a clean Mac.
