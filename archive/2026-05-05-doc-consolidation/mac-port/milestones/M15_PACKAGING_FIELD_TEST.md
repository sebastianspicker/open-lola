# M15 Packaging Field Test

## Objective

Package, sign, and field-test the Mac app and tools on clean Macs with a
signed/notarization-ready build and a field report verdict.

## Background/Context

Clean-Mac validation catches permissions, signing, entitlement, and environment
problems that local development cannot prove.

## Reverse-Engineering Findings

Static fact:
[../../reverse-engineering/REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md](../../reverse-engineering/REVERSE_ENGINEERING_ARTIFACTS_AND_ORIGINS_2026.md)
documents Windows binary distribution shape. The Mac package is native and does
not need to mirror Windows installers or helper layout.

## Research Findings

[../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md](../../research/RESEARCH_BENCHMARK_ROADMAP_2026.md)
requires field reports to preserve endpoint latency, network packet timing,
playout target, callback behavior, video age, lighting jitter where applicable,
resource interference, configuration identity, and verdict.

Current Apple source check:

- [Apple notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
  confirms Developer ID distribution uses the notary service and that `altool`
  uploads are deprecated.
- [Apple hardened runtime](https://developer.apple.com/documentation/security/hardened-runtime)
  confirms hardened runtime is required for notarization.
- [Apple entitlements](https://developer.apple.com/documentation/bundleresources/entitlements)
  confirms entitlements are embedded in the code signature.

Current source-validation baseline:

- `PackagingFieldTestReport` records package contents, signing identity type,
  hardened runtime, secure timestamp, notarization readiness, entitlement and
  purpose-string readiness, clean-Mac probe results, and field-report coverage.
- `packaging-field-run` writes the first ad-hoc local package-layout handoff
  from M10, M13, and M14 reports while keeping the M15 verdict PARTIAL.
- `field-runtime-proof-run` writes the aggregate P05 proof from M10, M13, M14,
  and M15 reports while keeping clean-Mac PASS gates explicit.
- `field-readiness-run` chains the bounded M13 app, M14 recording, M15 package,
  and P05 aggregate handoffs from one integrated baseline and output directory.
- PASS remains blocked until Q010 supplies a signing identity and clean-Mac
  target, and a measured field-test report proves the package launches and
  writes a verdict on that clean Mac.

## Assumptions

- The app and CLIs have stable capabilities before packaging.
- Signing identity and clean-Mac target are available before final validation.
- Notarization readiness is required even if distribution remains self-hosted.

## Dependencies

- M13 native app shell.
- M14 recording/session artifacts if field reports include recordings.
- Signing certificate and entitlement plan.
- Clean Mac test machine.
- Final project `LICENSE` decision; M05 currently records a pending placeholder.
- Final `THIRD_PARTY_NOTICES.md`; M07 currently records a notice and attribution
  draft.
- Dependency/license review signoff.
- SDK redistribution review for any optional adapter included in the package.

## Affected Modules/Files

- `OpenLolaCore` packaging/field-test report and validation model.
- `open-lola` CLI report validator and synthetic smoke command.
- Packaging field-test fixtures and focused unit tests.
- Future packaging scripts or Xcode archive settings.
- Future entitlements.
- [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md)

## Implementation Plan

1. Define package contents: app, CLIs, docs, and report templates. Done for
   source validation with `MacPackageIdentity`.
2. Add signing and entitlement configuration. Source readiness fields and PASS
   guards exist; real identity and entitlement files remain Q010-dependent.
3. Build archive or distributable package. Done only for ad-hoc local
   package-layout handoff; Developer ID signed archive remains Q010-dependent.
4. Validate launch, permissions, audio device access, camera access, network
   access, and report writing on a clean Mac. Source PASS guards exist; measured
   clean-Mac run remains deferred.
5. Run field test and record verdict. Source report schema exists.

## Test Plan

Before: no installable app exists.

After:

- package builds;
- signature validation passes;
- clean-Mac launch succeeds;
- field report includes endpoint, network, audio, video, control, and packaging
  evidence as applicable;
- final verdict is recorded.

Measured signed-package and clean-Mac evidence remain required before PASS.

## Validation Method

Run packaging validation locally, then run the package on a clean Mac and record
the exact OS, hardware, permissions, route, and media metrics.

## Acceptance Criteria

- Package is signed and notarization-ready.
- Clean-Mac install or launch path is documented.
- Required permissions are prompted and recorded.
- Field report ends with `VERDICT: PASS`, `VERDICT: FAIL`, or
  `VERDICT: PARTIAL`.
- Release bundle includes license and third-party notices, or records an
  explicit release-blocking `PARTIAL` reason.
- No vendor SDK files, samples, binary artifacts, unclear fixtures, packet
  captures, or generated analysis outputs are bundled unless redistribution and
  provenance are approved.
- M09 release-readiness archive inspection exists for the source/docs release
  surface, or records an explicit release-blocking `PARTIAL` reason.

SOTA 2026 gate:

- Rows: Q010, SOTA009, SOTA013, SOTA015, SOTA073 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: field-test closure records signing identity, clean-Mac target, fallback-route decisions, and deferred artistic/control integrations.

## Risks and Mitigations

- R010: permissions/signing may block tests. Mitigation: package milestone
  explicitly validates microphone, camera, network, and file access.
- R001: build surface may not match package surface. Mitigation: include CLIs
  and app in release validation.

## Known Blockers

- Signing certificate and distribution identity may require user input.
- Clean-Mac hardware may not be immediately available.

TODO(human): [M15 distribution] -> Provide signing identity and clean-Mac target for Q010 -> [ad-hoc local package / Developer ID signed package / defer packaging]

## Progress Checklist

- [x] Define package contents.
- [x] Add signing/entitlement config.
- [ ] Replace M05 `LICENSE` placeholder with final project license.
- [x] Create draft third-party notices.
- [ ] Finalize third-party notices against the release allowlist.
- [ ] Review SDK redistribution and fixture provenance.
- [ ] Attach M09 release-readiness archive inspection.
- [ ] Build package.
- [ ] Validate signature.
- [ ] Test on clean Mac.
- [ ] Record field report.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Next Recommended Action

Use `field-readiness-run` against the current M10 integrated report to refresh
the bounded M13, M14, M15, and P05 handoffs together. Then answer Q010 with the
signing identity, distribution method, entitlements, clean-Mac target, and M09
archive inspection decision for the source/docs release surface.

## Resume here

Start from `PackagingFieldTest.swift`, `FieldReadyRuntimeProof.swift`, and the
handoff commands, or use `field-readiness-run` for the full bounded source
chain. Answer Q010 in [../OPEN_QUESTIONS.md](../OPEN_QUESTIONS.md), then replace
the ad-hoc package layout with the smallest signed package that can launch and
write a field report on a clean Mac.
