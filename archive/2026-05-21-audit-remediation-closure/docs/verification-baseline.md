# Verification Baseline

Established: 2026-05-20

This is a live verification snapshot, not a goal state. It records what this
checkout can verify today, what was actually run, and what blocks stronger
evidence. No production code was changed for this baseline.

## Current Verdict

Source verification is `PARTIAL`.

Docs, Python, shell, release-hygiene-live, and Swift build gates passed in this
environment. The full Swift test suite did not pass. Product runtime readiness
is not proven because hardware, reference-peer, app-launch, signing,
notarization, clean-Mac, Docker parity, and manual UI gates were not run.

Working tree note: before this file was created, `git status --short` showed an
untracked `docs/code-index.md`. The full Swift suite included that file in its
release-candidate export checks.

## Environment

| Tool | Observed result | Notes |
|---|---:|---|
| Swift | 6.2.4, swiftlang-6.2.4.1.4 | Target shown as arm64-apple-macosx26.0. |
| Xcode | 26.3, build 17C529 | SwiftPM manifest evaluation fails inside the Codex sandbox. |
| Python | 3.13.5 | `python` and `python3` resolve to this version. |
| Ruff | 0.14.14 | Available. |
| mypy | 1.14.1 | Available. |
| ShellCheck | 0.11.0 | Available. |
| Docker CLI | 29.5.0 | CLI exists, but `docker ps` hung and was killed; daemon/service health is not verified. |
| `jacktrip` | missing | `command -v jacktrip` returned no path. |
| `uv` | `/Users/sebastian/.local/bin/uv` | This is likely Astral Python `uv`, not an UltraGrid executable. |

Generated outputs were directed to `/private/tmp` where practical:

- `/private/tmp/open-lola2-baseline-ruff-cache`
- `/private/tmp/open-lola2-baseline-mypy-cache`
- `/private/tmp/open-lola2-baseline-swift-build`
- `/private/tmp/open-lola2-baseline-swift-test`
- `/private/tmp/open-lola2-swiftpm-build`
- `/private/tmp/open-lola2-baseline-tsan`

Ignored checkout-local `.build/` and `dist/` directories are present in the
working tree. This baseline's adapted Swift build/test commands used
`/private/tmp` build paths instead of intentionally writing new repo-local
SwiftPM output.

## Commands Discovered

Discovery sources included `README.md`, `AGENTS.md`, `docs/testing.md`,
`Package.swift`, `pyproject.toml`, `.github/workflows/release-readiness.yml`,
`scripts/README.md`, `scripts/verify-release-readiness.sh`, and release/app
helper scripts.

Dependency setup:

```bash
python -m pip install <dev dependencies from pyproject.toml>
```

CI installs `pyproject.toml` optional dependency group `dev`, which currently
contains mypy, pytest, pytest-asyncio, and ruff. The optional `pcap` group adds
Scapy for packet-capture tooling. No Swift dependency install command was
discovered; SwiftPM uses `Package.swift`.

Build commands:

```bash
swift build
swift build --product open-lola
swift build --product open-lola-app
bash script/build_and_run.sh --verify
bash script/build_cli_app_bundle.sh
```

Test commands:

```bash
swift test --filter <RelevantSwiftTestName>
swift test --no-parallel
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
bash scripts/verify-release-readiness.sh
```

Lint, typecheck, static-analysis, and format-style checks:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
RUFF_CACHE_DIR=/tmp/open-lola-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py
MYPY_CACHE_DIR=/tmp/open-lola-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
bash scripts/verify-release-hygiene.sh
git diff --check
```

CI-only or CI-advertised sanitizer gates:

```bash
swift test --sanitize=thread --filter SPSCAtomicRing --no-parallel
swift test --sanitize=thread --filter DirectPeerAudioPayloadRing --no-parallel
swift test --sanitize=thread --filter VideoCaptureReport --no-parallel
```

Integration, parity, and runtime probes:

```bash
.build/debug/open-lola session-capabilities
.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness.json
.build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness.json
bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-ultragrid ultragrid
bash scripts/run-reference-peer-parity-gate.sh /private/tmp/open-lola-reference-peer-parity-jacktrip jacktrip
```

Release and generated-output commands:

```bash
bash scripts/export-release-candidate.sh /path/to/output-parent
bash scripts/verify-release-hygiene.sh /path/to/release-candidate
```

No database migrations, generated-code command, package-lock command, or
snapshot update command was discovered. Required generated/copy artifacts are
SwiftPM test resources, release-candidate exports, app bundle staging, and
manual/app evidence files under external paths.

## Commands Actually Run

| Command | Result |
|---|---|
| `bash scripts/verify-docs.sh` | PASS: `Documentation verification passed.` |
| `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh` | PASS: no output. |
| `env RUFF_CACHE_DIR=/private/tmp/open-lola2-baseline-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py` | PASS: `All checks passed!` |
| `env PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS: 103 passed, 2 skipped in 0.72s. |
| `env MYPY_CACHE_DIR=/private/tmp/open-lola2-baseline-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py` | PASS: no issues in 22 source files. |
| `bash scripts/verify-release-hygiene.sh` | PASS: live checkout generated-residue scan only; no release candidate supplied. |
| `swift build --build-path /private/tmp/open-lola2-baseline-swift-build` | FAIL in sandbox: SwiftPM manifest `sandbox-exec: sandbox_apply: Operation not permitted`. |
| `swift build --build-path /private/tmp/open-lola2-baseline-swift-build` outside sandbox | PASS: build complete in 23.69s. |
| `swift build --build-path /private/tmp/open-lola2-baseline-swift-build --product open-lola` outside sandbox | PASS: product build complete in 0.38s. |
| `swift build --build-path /private/tmp/open-lola2-baseline-swift-build --product open-lola-app` outside sandbox | PASS: product build complete in 0.13s. |
| `swift test --build-path /private/tmp/open-lola2-baseline-swift-test --no-parallel` outside sandbox | FAIL: 835 tests, 6 issues, 156.398s. |
| `swift build --product open-lola --build-path /private/tmp/open-lola2-swiftpm-build` outside sandbox | PASS: refreshed fixed CLI path required by machine-readable tests. |
| `swift test --build-path /private/tmp/open-lola2-baseline-swift-test --filter MachineReadableSurfaceContractTests --no-parallel` outside sandbox | PASS: 6 tests in 1.255s after refreshing the fixed CLI path. |
| `swift test --sanitize=thread --build-path /private/tmp/open-lola2-baseline-tsan --filter SPSCAtomicRing --no-parallel` outside sandbox | FAIL before selected test execution: ThreadSanitizer runtime load blocked by platform policy. |
| `docker --version` | PASS: Docker CLI 29.5.0. |
| `docker ps` | BLOCKED: hung with no output and was killed, exit 143. |

Swift build/test emitted vendored C warnings from Opus and JPEG-XS code,
including missing `lrint`/`lrintf` fallbacks, debug-build Opus slowness, and an
enum conversion in JPEG-XS. These warnings did not fail the build.

## Failure Details

### Full Swift Suite

`swift test --build-path /private/tmp/open-lola2-baseline-swift-test --no-parallel`
failed with 6 issues.

`CodeLineBudgetTests.scopedCodeFilesStayWithinLineBudget` failed because current
files exceed policy budgets:

- `Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift`: 2442 / 1860
- `Sources/open-lola-app/AppShellRootView.swift`: 1210 / 1117
- `Sources/open-lola-app/AppExecutionController.swift`: 1046 / 1008
- `Tests/OpenLolaCoreTests/AppShellSlice05Tests.swift`: 974 / 720
- `Sources/open-lola-app/AppConsoleModels.swift`: 846 / 720
- `Sources/open-lola-app/AppSettings.swift`: 829 / 720

Three `MachineReadableSurfaceContractTests` initially failed because the tests
look at a fixed binary path,
`/private/tmp/open-lola2-swiftpm-build/debug/open-lola`, and that binary was
older than product sources:

- `machineReadableExecutableJSONSurfacesRoundTrip`
- `machineReadableExecutableGoalTemplateRejectsFalsePassMutation`
- `openLolaExecutableRejectsUnknownCommand`

After running the documented fixed-path build, the focused
`MachineReadableSurfaceContractTests` suite passed: 6 tests in 1.255s. Treat
these initial failures as an environment/prebuild dependency, not as proof that
the machine-readable surface is broken.

`ReleaseArtifactHygieneContractTests.releaseExportScriptStagesAllowlistedCandidateAndRunsHygieneGate`
failed with two issues. The exported release candidate's docs verifier reported
that `docs/code-index.md` contains backticked source paths for the singular
script directory that are not present in the candidate. Reported locations:

- `docs/code-index.md:196`
- `docs/code-index.md:197`
- `docs/code-index.md:285`
- `docs/code-index.md:358`

This is a current release-boundary failure for the working tree being tested.
It was not fixed because this task is baseline-only and scoped to
`docs/verification-baseline.md`.

Four LoLa UDP fallback/control tests were skipped during the full Swift suite:

- `lolaUdpTransmitFallsBackToQuickConnectWhenStatusAckTimesOut`
- `lolaUdpReceiveKeepsControlSocketAliveForPostConnectRetries`
- `lolaUdpTxRxKeepsControlSocketAliveForPostConnectCommands`
- `lolaUdpControlRetryResponderReportsBindFailure`

The Python suite also skipped two process runtime tests because loopback alias
`127.0.0.2` is not available on this host.

### ThreadSanitizer

The first CI sanitizer smoke command built but could not launch tests:

```text
dyld: libclang_rt.tsan_osx_dynamic.dylib ... Sanitizer load violates platform policy
```

The remaining two CI sanitizer filters were not run because this is a host/toolchain
policy blocker before selected test execution, not a filter-specific failure.

### Docker

`docker --version` returned a CLI version, but `docker ps` hung with no output
and was killed. Docker-based JackTrip/UltraGrid parity commands are therefore
not verified on this host.

## Skipped Checks

- `bash scripts/verify-release-readiness.sh`: skipped because its component
  Swift suite currently fails, and it also runs app launch verification that
  stages `dist/OpenLoLa.app`.
- `bash script/build_and_run.sh --verify`: skipped because it stages an app
  bundle under `dist/` and launches/verifies the app surface; this baseline
  avoided new repo-local generated output.
- `bash script/build_cli_app_bundle.sh`: skipped because it stages bundle
  output and is covered only indirectly by script/source-policy tests here.
- Release-candidate export command: not run directly; its contract test failed
  inside the Swift suite.
- Release-hygiene candidate scan: skipped because no release-candidate path was
  supplied.
- Docker JackTrip/UltraGrid parity scripts: skipped because Docker daemon
  health was not verified, and pinned images/containers were not prepared.
- Native UltraGrid and JackTrip parity scripts: skipped because reference tools
  and peer evidence are not available; `jacktrip` is missing.
- Reference-peer parity gates: skipped because `OPEN_LOLA_REFERENCE_PEER_HOST`
  was not set.
- Manual hardware gates: skipped for RME/MADI, Blackmagic/ATEM/video capture,
  physical peer route, packet capture, DSCP/PTP, audio/video quality, signing,
  notarization, Gatekeeper, clean-Mac launch, and reviewer approval.
- Manual UI/UX acceptance gate: skipped; no screenshots or accessibility
  evidence were captured.
- CI ThreadSanitizer filters for `DirectPeerAudioPayloadRing` and
  `VideoCaptureReport`: skipped after the `SPSCAtomicRing` sanitizer launch was
  blocked by platform policy.

## Suspicious Or Lower-Trust Tests

- Source-text, inventory, documentation, line-budget, workflow, and release
  policy tests are useful guards, but they are not runtime proof for audio,
  video, network, hardware, signing, or field readiness.
- Tests that run CLI probes through a fixed external build path are not
  self-contained unless `/private/tmp/open-lola2-swiftpm-build/debug/open-lola`
  has been freshly built.
- Localhost and synthetic smoke tests do not prove product `PASS`; they remain
  source-level evidence only.
- The live release-hygiene scan without a candidate path proves generated
  residue policy only. It is not a full release-boundary scan.
- The Docker CLI version alone is not enough to trust Docker parity gates; the
  daemon query hung.

No comprehensive test-meaningfulness audit was performed in this baseline. The
test names and active docs show that some tests intentionally enforce policy or
inventory contracts rather than runtime behavior.

## What Is Verified

- Active documentation currently passes the repo docs verifier.
- Shell scripts pass ShellCheck.
- Python connector and docs-verifier Python code pass Ruff and strict mypy.
- Python connector tests pass except the two skipped loopback-alias cases.
- Live checkout release-hygiene generated-residue scan passes.
- SwiftPM can build the package, CLI product, and app product outside the Codex
  sandbox using `/private/tmp` build paths.
- Machine-readable CLI surface tests pass after the documented fixed-path CLI
  build is refreshed.

## What Is Not Verified

- The full Swift suite is not green.
- Release-candidate export/hygiene is not green with the current working tree.
- ThreadSanitizer CI smokes cannot launch on this host/toolchain.
- Docker, native UltraGrid, JackTrip, reference-peer, and parity scripts are not
  verified.
- App bundle launch, screenshot, accessibility, signing, notarization,
  Gatekeeper, clean-Mac, hardware, and physical route checks are not verified.
- Product runtime field readiness remains unproven.

## Stronger Verification Blockers

1. Fix or explicitly rebaseline the line-budget policy failures.
2. Decide whether `docs/code-index.md` should avoid release-candidate-missing
   script-directory paths or whether the release export allowlist should include
   that directory.
3. Build `/private/tmp/open-lola2-swiftpm-build/debug/open-lola` before running
   machine-readable executable tests, or remove that external fixed-path
   dependency from the tests.
4. Resolve the local ThreadSanitizer runtime policy blocker or run those CI
   smokes on a host where the sanitizer dylib can load.
5. Verify Docker daemon access before running local parity scripts.
6. Provide reference peer host/tooling, hardware, signing, and manual evidence
   before claiming product runtime readiness.
