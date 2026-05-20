# Verification Baseline

_Established: 2026-05-19_
_Environment: macOS arm64 (Apple Silicon), Xcode 26.3, Swift 6.2.4_

---

## Purpose

This document records every verification command available in the repository,
what was actually run, and the exact result of each run. It is a snapshot, not
a goal state. Nothing here is fixed or edited; all failures are reported as
found.

---

## Environment

| Tool | Version | Notes |
|------|---------|-------|
| Swift | 6.2.4 (swiftlang-6.2.4.1.4) | Apple Silicon |
| Xcode | 26.3 (Build 17C529) | |
| Python | 3.13.5 | Anaconda distribution |
| pip | 26.1 | |
| ruff | 0.14.14 | Available in PATH |
| mypy | 1.14.1 | Available in PATH |
| ShellCheck | 0.11.0 | Available in PATH |
| UltraGrid (`uv`) | **NOT INSTALLED** | Tests expect it at `uv` in PATH; only `uv` (Astral Python tool) found |
| JackTrip | **NOT INSTALLED** | Some tests probe for it; NMP preflight tests skip gracefully |
| Docker | NOT CHECKED | Parity scripts require it; not verified in this run |

---

## Commands Discovered

### Swift / Xcode

```
swift build
swift build --product open-lola
swift build --product open-lola-app
swift test --no-parallel
swift test --filter <TestName>
bash script/build_and_run.sh --verify
bash script/build_cli_app_bundle.sh
```

### Python (linux_connector + scripts)

```
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
```

### Shell verification gates

```
bash scripts/verify-docs.sh
bash scripts/verify-release-hygiene.sh
bash scripts/verify-release-hygiene.sh <candidate-dir>
bash scripts/verify-release-readiness.sh          # full end-to-end gate
```

### Python dependency install (dev extras)

```
pip install -e ".[dev]"
pip install -e ".[dev,pcap]"   # adds scapy for packet-capture tests
```

### Parity / integration scripts (external tools required)

```
bash scripts/run-local-ultragrid-rxtx-docker.sh
bash scripts/run-local-jacktrip-rxtx-docker.sh
bash scripts/run-local-ultragrid-rxtx-native.sh
bash scripts/compare-local-ultragrid-parity-docker.sh
bash scripts/compare-local-jacktrip-parity-docker.sh
bash scripts/stress-local-ultragrid-parity-docker.sh
bash scripts/run-reference-peer-parity-gate.sh
```

### Release export

```
bash scripts/export-release-candidate.sh <output-parent-dir>
```

### CLI probes (after `swift build`)

```
.build/debug/open-lola command-inventory
.build/debug/open-lola source-ownership-inventory
.build/debug/open-lola fixture-smoke-matrix
.build/debug/open-lola report-schema-inventory
.build/debug/open-lola goal-codewise-closure
.build/debug/open-lola goal-codewise-closure-run --output <path>
.build/debug/open-lola validate-goal-codewise-closure-report <path>
.build/debug/open-lola realtime-audio-path-inventory
.build/debug/open-lola network-route-command-matrix
.build/debug/open-lola video-control-degrade-matrix
.build/debug/open-lola native-app-shell-surface-probe
.build/debug/open-lola goal-runtime-evidence-template
.build/debug/open-lola goal-runtime-preflight
.build/debug/open-lola goal-completion-audit
.build/debug/open-lola open-source-release-readiness-run --output <path>
.build/debug/open-lola session-capabilities
```

---

## Commands Actually Run

In order of execution:

| # | Command | Result |
|---|---------|--------|
| 1 | `bash scripts/verify-docs.sh` | **PASS** |
| 2 | `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh` | **PASS** |
| 3 | `ruff check linux_connector scripts/verify_docs scripts/lib/*.py` | **PASS** |
| 4 | `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py` | **PASS** |
| 5 | `python -m pytest -p no:cacheprovider linux_connector` | **PASS** (103 passed, 2 skipped) |
| 6 | `bash scripts/verify-release-hygiene.sh` | **FAIL** |
| 7 | `swift build` | **PASS** (cached — 0.42 s) |
| 8 | `swift test --no-parallel` | **FAIL** (717 passed, 7 functions failed, 10 issues) |

---

## Detailed Results

### 1. `bash scripts/verify-docs.sh` — PASS

Runs:
1. Active and archived Markdown inventory (file listing, no assertions)
2. `python3 -m scripts.verify_docs` — checks links, backtick source paths,
   required topics, ASCII, public-planning contract, TODO markers

Result: `Documentation verification passed.`

Checks run in **public-candidate mode** (no `archive/` or `private/`
internal evidence context found). The `check_milestone_contract`,
`check_implementation_companion`, `check_release_hardening_contract`,
`check_sota_matrix`, and all Windows corpus checks were **skipped**
(`internal_context = False`).

---

### 2. ShellCheck — PASS

`shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`

No issues. All shell scripts pass ShellCheck 0.11.0 with `-x`
(follow sourced files).

---

### 3. Ruff — PASS

`ruff check linux_connector scripts/verify_docs scripts/lib/*.py`

`All checks passed!` — 22 source files, no lint issues.

---

### 4. Mypy — PASS

`python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`

`Success: no issues found in 22 source files`

All modules pass strict mypy 1.14.1 with no type errors.

---

### 5. Python pytest — PASS (103 passed, 2 skipped)

```
platform darwin -- Python 3.13.5, pytest-8.3.4
collected 105 items

linux_connector/tests/test_codec.py                   40 passed
linux_connector/tests/test_process_backends.py        14 passed
linux_connector/tests/test_process_runtime.py         36 passed, 2 skipped
linux_connector/tests/test_runtime_contracts.py       12 passed

2 skipped: loopback alias 127.0.0.2 is not available (EADDRNOTAVAIL)
```

The 2 skipped tests require a loopback alias (`127.0.0.2`) that is not
configured on this machine. This is a known macOS environment gap; Linux
hosts with the alias will run them.

---

### 6. `bash scripts/verify-release-hygiene.sh` — FAIL

**Error:** `verify-release-hygiene: live checkout contains forbidden generated artifact before release readiness: ./.DS_Store`

**Cause:** macOS Finder creates `.DS_Store` files. The hygiene script
(`verify_live_checkout`) scans for any `.DS_Store`, `__pycache__`, or `*.pyc`
files in the working tree (excluding `.build/`, `archive/`, `dist/`,
`private/`).

**Impact:** This failure blocks the full `verify-release-readiness.sh` gate.
The failure is an environment artifact (macOS Finder activity), not a code
defect. Removing `.DS_Store` before running the gate would clear it.

**Can it be trusted?** The hygiene check itself is correct — the policy is
sound. The failure is reproducible on any macOS machine with Finder activity
in the repo directory.

---

### 7. `swift build` — PASS

```
Build complete! (0.42s)
```

The build was cached from a previous run. All five products build successfully:
`OpenLolaCore`, `OpenLolaContracts`, `OpenLolaAppSupport`, `open-lola`,
`open-lola-app`.

**Not verified independently:** `swift build --product open-lola` and
`swift build --product open-lola-app` were not run in isolation; the full
`swift build` covers them.

---

### 8. `swift test --no-parallel` — FAIL

```
Test run with 727 tests in 0 suites failed after ~153 seconds with 10 issues.
```

**717 tests passed. 7 test functions failed (10 issues total).**

#### Failing tests

---

##### F1 — `scopedCodeFilesStayWithinLineBudget` (CodeLineBudgetTests.swift:9)

**Type:** Pre-existing regression

**Error:**
```
Files exceed per-class LOC budgets:
768/720 Tests/OpenLolaCoreTests/JackTripCompatibilityTests.swift
764/720 Sources/OpenLolaCore/Connectors/JackTrip/JackTripCompatibility.swift
```

**Root cause:** Both `JackTripCompatibility.swift` and
`JackTripCompatibilityTests.swift` exceed their 720-line LOC budget. The test
enforces a per-file line-count ceiling defined in
`Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift` or
`scripts/code-line-budget-exceptions.txt`.

**Confirmed pre-existing:** `docs/code-index.md` does not affect this test.

---

##### F2 — `ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules` (ExternalConnectorAvMatrixTests.swift:78)

**Type:** Pre-existing logic bug

**Error:**
```
Expectation failed: (rx.arguments.last → "disabled") == "198.51.100.10"
```

**Root cause:** The UltraGrid RX launch plan is generating a final argument of
`"disabled"` when it should be the peer host `"198.51.100.10"`. The argument
order or construction in `ExternalConnectorLaunchPlan.build()` /
`UltraGridLaunchPlan` for the RX role places the peer address in the wrong
position or omits it.

**Impact:** UltraGrid RX launch plan argument construction is incorrect.

---

##### F3 & F4 — `externalConnectorNmpPreflightRunsPlanScopedExecutableChecks` and `externalConnectorNmpPreflightFailsWhenAnyPlanPreflightFails` (ExternalConnectorNmpPreflightTests.swift:41, 71)

**Type:** Environment blocker (UltraGrid not installed)

**Error:**
```
Expectation failed:
  (report.results.first { $0.connector == .mvtpUltraGrid }?.report?.verdict → nil) == .pass
  (report.results.first { $0.connector == .mvtpUltraGrid }?.report?.verdict → nil) == .fail
```

**Root cause:** The NMP preflight probes for the UltraGrid executable (`uv`
by default). The `uv` in PATH is Astral's Python package manager, not
UltraGrid's `uv-qt` binary. The preflight can't find UltraGrid, so the
`.mvtpUltraGrid` connector result is `nil` instead of `.pass` or `.fail`.

**Impact:** Two test functions are blocked by a missing external tool.
These tests would pass on a machine with UltraGrid installed at the expected
path.

---

##### F5 — `fixtureSmokeMatrixMatchesFixtureTree` (FixtureSmokeMatrixTests.swift:17-19)

**Type:** Pre-existing fixture/matrix drift

**Error (3 issues):**
```
Expectation failed: (actualCounts → [..., "JackTripCompatibilityMediaReports": 1,
  ..., "UltraGridCompatibilityMediaReports": 1, ...])
  == (expectedCounts → [...])  ← missing both categories

Expectation failed: (summary.fixtureFileCount → 56) == (actualCounts.values.reduce(0,+) → 58)
Expectation failed: (summary.jsonFixtureCount → 53) == (actualExtensionCounts["json"] → 55)
```

**Root cause:** Two fixture directories exist on disk that are not tracked
in the `FixtureSmokeMatrixData` expected map:
- `Tests/OpenLolaCoreTests/Fixtures/JackTripCompatibilityMediaReports/`
  (1 file)
- `Tests/OpenLolaCoreTests/Fixtures/UltraGridCompatibilityMediaReports/`
  (1 file)

The hardcoded expected counts (56 total, 53 JSON) are stale. The actual tree
has 58 files (55 JSON).

**Impact:** The fixture smoke matrix is out of sync with the test fixture tree.
`FixtureSmokeMatrixData` needs to add these two categories.

---

##### F6 — `releaseExportScriptStagesAllowlistedCandidateAndRunsHygieneGate` (ReleaseArtifactHygieneContractTests.swift:154-156)

**Type:** Regression introduced by `docs/code-index.md`

**Error:**
```
Expectation failed: (docsResult.status → 1) == 0
Expectation failed: (docsResult.output → "...") .contains("Documentation verification passed.")
```

**Full docs verifier output from candidate:**
```
Documentation verifier running public-candidate checks; internal corpus checks skipped.
Documentation verification failed:
- docs/code-index.md:644: backticked source path does not exist: script/build_and_run.sh
- docs/code-index.md:645: backticked source path does not exist: script/build_cli_app_bundle.sh
- docs/code-index.md:691: backticked source path does not exist: script/build_and_run.sh
```

**Root cause:** `docs/code-index.md` (created by the code-index task) uses
backtick references to script/build_and_run.sh and
script/build_cli_app_bundle.sh. The `scripts/verify_docs/markdown_checks.py`
check (`check_backticked_source_paths`) verifies that any backtick-referenced
path beginning with `script/` actually exists in the target directory.

The release candidate export (`scripts/export-release-candidate.sh`) copies
`scripts/` (plural) but does **not** copy `script/` (singular). Therefore,
inside the candidate, script/build_and_run.sh and
script/build_cli_app_bundle.sh do not exist and the check fails.

**This test was passing before `docs/code-index.md` was created.** The fix is
to remove the backtick wrapping from `script/` paths in `docs/code-index.md`
(use inline code only where the path actually exists in both the live checkout
and the release candidate), or to update the export script to include
`script/`.

**Impact:** The release artifact hygiene test is now failing. Does not affect
any production logic.

---

##### F7 — `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass` (SyntheticSmokeReportContractTests.swift:76)

**Type:** Pre-existing string-mismatch between test expectation and source

**Error:**
```
Expectation failed: report.assumptions.contains {
  $0.contains("Swift-native UDP DEFAULT, JAMLINK, and EMPTY-header audio packetization")
}
```

**Root cause:** The test expects the substring `"Swift-native UDP DEFAULT,
JAMLINK, and EMPTY-header audio packetization"`. The actual string in
`Sources/OpenLolaCore/Connectors/Core/ExternalConnectorReport.swift:315` is:

```
"JackTrip connector uses Swift-native UDP DEFAULT, JAMLINK, EMPTY-header,
WebRTC data-channel, WebTransport datagram, JACK graph dry-run, plugin bridge,
and Opus-extension packetization paths, ..."
```

The key difference: the actual string has `"JAMLINK, EMPTY-header"` (no
`", and"` before `EMPTY-header`), whereas the test looks for
`"JAMLINK, and EMPTY-header"`. The test and the source are out of sync.

**Impact:** `ExternalConnectorSyntheticSmoke` assumption strings are not
validated by this test. The test must be updated to match the current source
text, or the source text must match the test expectation.

---

## Skipped / Not Run

| Gate | Reason |
|------|--------|
| `bash scripts/verify-release-readiness.sh` | Full gate; includes `swift build`, `swift test --no-parallel`, CLI probes, and native app launch probe. Not run in full; individual constituent steps were run separately. |
| CLI probes (`.build/debug/open-lola ...`) | Not run. Binary is built; probes are safe to run but were not part of this baseline run. They are covered by `swift test` (CLI inventory and fixture smoke tests). |
| Native app launch probe (script/build_and_run.sh --verify) | Requires display server access, Accessibility permissions, and screenshot capability. Not run. |
| Parity/integration scripts (`scripts/run-local-*`, `compare-*`, `stress-*`) | Require Docker and/or UltraGrid/JackTrip binaries. Not run. |
| `bash scripts/export-release-candidate.sh` | Not run directly; exercised indirectly by `ReleaseArtifactHygieneContractTests`. |
| `swift build --product open-lola` / `open-lola-app` | Not run in isolation; covered by full `swift build`. |
| Python `pip install -e ".[dev]"` | Not run; tools (ruff, mypy, pytest) were already available in the global Anaconda environment. |
| `pip install -e ".[dev,pcap]"` | Not run; `scapy` not needed for the pcap-skip path. |
| Internal docs corpus checks | Skipped by `verify-docs.sh` because `has_internal_documentation_context()` is False (no `private/` or full `archive/` corpus present). |

---

## Summary: What Is Verified

| Layer | Verified | Result |
|-------|----------|--------|
| Shell scripts (ShellCheck) | Yes | PASS |
| Python lint (ruff) | Yes | PASS |
| Python types (mypy --strict) | Yes | PASS |
| Python unit tests (pytest) | Yes | 103 PASS, 2 SKIP (env blocker) |
| Docs verification (live checkout) | Yes | PASS |
| Release hygiene (live checkout) | Yes | **FAIL** (.DS_Store present) |
| Swift build | Yes | PASS |
| Swift tests (all 727) | Yes | 717 PASS, 10 ISSUES |

---

## Summary: What Is Not Verified

| Layer | Blocker |
|-------|---------|
| Release hygiene on a clean candidate | `.DS_Store` present; `docs/code-index.md` `script/` references cause candidate docs check failure |
| UltraGrid NMP preflight tests (F3, F4) | `uv` (UltraGrid) not installed |
| Native app launch | Requires display, Accessibility API, screenshot capability |
| Docker parity lanes | Docker not verified; UltraGrid/JackTrip images not pulled |
| Full `verify-release-readiness.sh` | Blocked by hygiene failure and native-app launch gate |
| Internal docs corpus checks | Requires `private/` and `archive/` corpus |
| Real hardware tests (CoreAudio device I/O, RME MADI, Blackmagic) | Require physical hardware; all run as synthetic/localhost in CI |
| Python loopback alias tests (2 skipped) | `127.0.0.2` not assigned on this machine |

---

## Pre-Existing Failures (Not Caused by This Session)

| Test | Root cause | Severity |
|------|-----------|---------|
| `scopedCodeFilesStayWithinLineBudget` | `JackTripCompatibility.swift` (764 lines) and `JackTripCompatibilityTests.swift` (768 lines) exceed 720-line budget | Low — style/size gate |
| `ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules` | UltraGrid RX launch plan generates wrong final argument (`"disabled"` instead of peer IP) | Medium — logic bug in UltraGrid arg construction |
| `externalConnectorNmpPreflightRunsPlanScopedExecutableChecks` | UltraGrid not installed | Environment |
| `externalConnectorNmpPreflightFailsWhenAnyPlanPreflightFails` | UltraGrid not installed | Environment |
| `fixtureSmokeMatrixMatchesFixtureTree` | `JackTripCompatibilityMediaReports` and `UltraGridCompatibilityMediaReports` fixture directories exist but are not registered in `FixtureSmokeMatrixData` | Low — matrix staleness |
| `syntheticSmokeReportsValidateAsPartialWithoutClaimingRuntimePass` | Test substring `"JAMLINK, and EMPTY-header"` does not match source string `"JAMLINK, EMPTY-header,"` | Low — test/source string mismatch |

---

## Failure Introduced By This Session

| Test | Root cause | Fix needed |
|------|-----------|-----------|
| `releaseExportScriptStagesAllowlistedCandidateAndRunsHygieneGate` | `docs/code-index.md` uses backtick-wrapped script/build_and_run.sh and script/build_cli_app_bundle.sh; `script/` is not included in the release candidate export | Remove backtick wrapping from `script/` references in `docs/code-index.md`, or change them to plain text / fenced code blocks |

---

## Suspicious / Potentially Weak Tests

| Test / area | Concern |
|-------------|---------|
| Most `*SyntheticSmoke*` tests | They validate report shape and verdict labels, not live runtime behaviour. A test passing here does not prove the corresponding runtime path works on hardware. |
| `releaseHygienePolicyDocsManifestNoticeAndVerificationMatrixStayAligned` | Validates that specific strings appear in policy documents. Brittle if phrasing changes; does not validate the policy is enforced. |
| `fixtureSmokeMatrixMatchesFixtureTree` | Compares fixture-tree file counts against hardcoded numbers in source. As shown, drift happens silently until the count test catches it. |
| `scopedCodeFilesStayWithinLineBudget` | Enforces per-file LOC budgets via a static scan. Does not prevent logic complexity — only file length. |
| Most `*ReportTests` and `*ValidationTests` | Test that report structs round-trip through JSON and produce the expected verdict labels. They do not exercise the measurement paths that produce the reports. |

---

## Coverage Gaps and Uncertainty

- **No hardware-backed test was run.** All CoreAudio, RME MADI, and Blackmagic
  tests run synthetic or localhost-only paths. Results cannot be promoted to
  field-readiness evidence.
- **No Docker tests were run.** UltraGrid and JackTrip parity lanes are
  entirely untested in this baseline.
- **Swift test suite was run serially** (`--no-parallel`). Some tests may
  behave differently under parallel execution; this was not tested.
- **SwiftUI views are not tested.** All UI test coverage goes through
  `NativeAppShell` backend contracts, not rendered SwiftUI views.
- **The full `verify-release-readiness.sh` gate was not run end-to-end.**
  The native app launch probe in particular requires manual environment setup.
- **`docs/verification-baseline.md` itself was not present before this run**
  and therefore causes `docs/code-index.md` line counts to differ slightly in
  any subsequent runs of `check_backticked_source_paths` or similar.
