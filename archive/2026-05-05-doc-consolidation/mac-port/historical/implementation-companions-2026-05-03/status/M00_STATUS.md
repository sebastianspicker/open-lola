# M00 Status

## Current status

- Status: Complete.
- Canonical milestone: [M00 Evidence Baseline And Repo Scaffold](../milestones/M00_EVIDENCE_BASELINE_AND_REPO_SCAFFOLD.md)

Canonical objective:

Establish a minimal Mac source scaffold and evidence baseline before feature
code. After this milestone, the repo has a Swift build/test surface and the
documentation links still pass.

Canonical assumptions:

- Swift Package Manager is the first scaffold because the initial work is
  headless tooling.
- The native UI remains out of scope until M13.
- No Windows LoLa wire compatibility code is added in this milestone.

Canonical dependencies:

- macOS with Xcode command line tools.
- Swift toolchain capable of building a small package.
- Current documentation set in `research/`, `reverse-engineering/`, and
  `mac-port/`.

Canonical affected modules/files:

- `Package.swift`
- `Sources/`
- `Tests/`
- Future `scripts/` only if needed for documentation checks.
- [../PROGRESS.md](../PROGRESS.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)

Canonical implementation sequence:

1. Add a minimal `Package.swift`.
2. Add one tiny library target for shared model types.
3. Add one CLI executable target that prints a version or capability summary.
4. Add initial tests that fail before the scaffold and pass after it exists.
5. Add a docs link/report check if no external checker is available.
6. Update [../PROGRESS.md](../PROGRESS.md) only after verification passes.

Canonical acceptance criteria:

- The package builds on macOS.
- Tests pass.
- The scaffold does not include speculative media features.
- Documentation links still pass.
- [../PROGRESS.md](../PROGRESS.md) marks M00 complete only after validation.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source scaffold changes after M00 begins: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Preserved pre-harness `mac-port/README.md` and `mac-port/PROGRESS.md`
  snapshots under `mac-port/historical/`.
- Added harness entry points, workflow documentation, status index, templates,
  and M00-M15 status companions.
- Added the non-mutating documentation verifier at
  [../../scripts/verify-docs.sh](../../scripts/verify-docs.sh).
- Updated [../README.md](../README.md), [../PROGRESS.md](../PROGRESS.md), and
  [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md) to point at the
  harness and verification command.
- Added [../../Package.swift](../../Package.swift) with one library product and
  one executable product.
- Added [../../Sources/OpenLolaCore/CapabilitySummary.swift](../../Sources/OpenLolaCore/CapabilitySummary.swift)
  as the minimal shared model for the scaffold.
- Added [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
  as the minimal CLI smoke surface.
- Added [../../Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift](../../Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift)
  as the first scaffold test.

## Verified work

- `bash scripts/verify-docs.sh` passed on 2026-05-02.
- `shellcheck scripts/*.sh` passed on 2026-05-02.
- `swift test` first failed as expected before sources existed with
  `target 'OpenLolaCore' referenced in product 'OpenLolaCore' is empty`.
- `swift test` passed after adding the source scaffold.
- `swift build` passed.
- `swift run open-lola` passed and printed the M00 capability summary.

## Partially completed work

- None recorded. M00 scaffold scope is complete.

## Deferred work

- Core Audio, UDP PCM, video, lighting, native UI, recording, packaging, and CI
  remain deferred to later milestones.

## Open tasks

Canonical progress checklist:

- [x] Add `Package.swift`.
- [x] Add minimal sources.
- [x] Add minimal tests.
- [x] Run `swift build`.
- [x] Run `swift test`.
- [x] Run documentation checks.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

## Known blockers

- CI platform and branch policy are not defined in this directory.

## Test coverage status

Canonical test plan:

Before: no `swift build` or `swift test` surface exists.

After:

- `swift build`
- `swift test`
- documentation relative-link check
- topic gate from [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)

Coverage state: one Swift Testing test covers the M00 capability summary model.
The CLI smoke probe covers the executable product.

Harness coverage state: documentation verifier and shellcheck pass.

## Relevant files touched

Planned affected modules/files:

- `Package.swift`
- `Sources/`
- `Tests/`
- Future `scripts/` only if needed for documentation checks.
- [../PROGRESS.md](../PROGRESS.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)

Live files touched:

- [../HARNESS.md](../HARNESS.md)
- [../WORKFLOW.md](../WORKFLOW.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../README.md](../README.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../historical/README_PRE_HARNESS_2026-05-02.md](../historical/README_PRE_HARNESS_2026-05-02.md)
- [../historical/PROGRESS_PRE_HARNESS_2026-05-02.md](../historical/PROGRESS_PRE_HARNESS_2026-05-02.md)
- [M00_STATUS.md](M00_STATUS.md)
- [M01_STATUS.md](M01_STATUS.md)
- [M02_STATUS.md](M02_STATUS.md)
- [M03_STATUS.md](M03_STATUS.md)
- [M04_STATUS.md](M04_STATUS.md)
- [M05_STATUS.md](M05_STATUS.md)
- [M06_STATUS.md](M06_STATUS.md)
- [M07_STATUS.md](M07_STATUS.md)
- [M08_STATUS.md](M08_STATUS.md)
- [M09_STATUS.md](M09_STATUS.md)
- [M10_STATUS.md](M10_STATUS.md)
- [M11_STATUS.md](M11_STATUS.md)
- [M12_STATUS.md](M12_STATUS.md)
- [M13_STATUS.md](M13_STATUS.md)
- [M14_STATUS.md](M14_STATUS.md)
- [M15_STATUS.md](M15_STATUS.md)
- [../templates/MILESTONE_STATUS_TEMPLATE.md](../templates/MILESTONE_STATUS_TEMPLATE.md)
- [../templates/SESSION_HANDOFF_TEMPLATE.md](../templates/SESSION_HANDOFF_TEMPLATE.md)
- [../../scripts/verify-docs.sh](../../scripts/verify-docs.sh)
- [../../scripts/README.md](../../scripts/README.md)
- [../../Package.swift](../../Package.swift)
- [../../Sources/OpenLolaCore/CapabilitySummary.swift](../../Sources/OpenLolaCore/CapabilitySummary.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift](../../Tests/OpenLolaCoreTests/CapabilitySummaryTests.swift)

## Latest verification

- 2026-05-02: red `swift test` failed before source was added with
  `target 'OpenLolaCore' referenced in product 'OpenLolaCore' is empty`.
- 2026-05-02: `swift test` passed with 1 Swift Testing test.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift run open-lola` passed and printed:
  `open-lola 0.0.0-m00 (M00 scaffold)`.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- VERDICT: PASS

## Next recommended steps

Start M01 by adding report fixture tests before any measurement CLI work.

## Resume here

Continue at [../status/M01_STATUS.md](M01_STATUS.md): create the fixture schema
and one valid sample report, then add failing tests for missing hardware,
missing route, missing metric, and missing verdict.
