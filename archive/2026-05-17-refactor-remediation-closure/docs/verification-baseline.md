# Verification Baseline

Date: 2026-05-16

Purpose: record the current verification surface and live baseline before any
cleanup or refactor. This is not a remediation plan.

Verdict: PARTIAL. Documentation, Python, shell/static checks, whitespace, and
Swift build are green in this run. The broad Swift test suite is red because
`CodeLineBudgetTests` reports one file over the configured line budget. Release
hygiene is also red because the live checkout contains generated cache
residue.

## Environment

- Host shell: `zsh`.
- Swift: `/usr/bin/swift`.
- Python: `/opt/anaconda3/bin/python` and `/opt/anaconda3/bin/python3`.
- Ruff: `/opt/anaconda3/bin/ruff`.
- Mypy: `/opt/anaconda3/bin/mypy`.
- Pytest: `/opt/anaconda3/bin/pytest`.
- ShellCheck: `/opt/homebrew/bin/shellcheck`.
- `timeout`: unavailable in this shell (`zsh:1: command not found: timeout`).
- SwiftPM inside the normal sandbox cannot compile the manifest here:
  `sandbox-exec: sandbox_apply: Operation not permitted`. Swift build/test
  commands below were rerun outside the sandbox and used
  `/private/tmp/open-lola2-verification-baseline-build` as the build path.

Generated/cache output observed before this baseline:

- `.build/`
- `.ruff_cache/`
- `.mypy_cache/`

Generated output created by this run:

- `/private/tmp/open-lola2-verification-baseline-build`
- `/tmp/open-lola-verification-baseline-ruff-cache`
- `/tmp/open-lola-verification-baseline-mypy-cache`

## Commands Discovered

### Dependency Installation

Discovered from `.github/workflows/release-readiness.yml` and `pyproject.toml`:

```bash
python - <<'PY'
import subprocess
import sys
import tomllib

with open("pyproject.toml", "rb") as handle:
    dependencies = tomllib.load(handle)["project"]["optional-dependencies"]["dev"]
subprocess.check_call([sys.executable, "-m", "pip", "install", *dependencies])
PY
```

Python dev dependencies declared:

- `mypy==1.14.1`
- `pytest>=8.3,<9`
- `pytest-asyncio>=0.25,<1`
- `ruff>=0.11,<1`

Optional packet-capture dependency:

- `scapy>=2.6,<3` under `[project.optional-dependencies].pcap`

No Swift package-install command is declared. Swift dependencies are local
targets and vendored C/reference sources in `Package.swift`.

### Build Commands

Discovered from `README.md`, `AGENTS.md`, `docs/testing/README.md`, and
`Package.swift`:

```bash
swift build
swift build --product open-lola
swift build --product open-lola-app
bash script/build_and_run.sh --verify
bash script/build_cli_app_bundle.sh
```

CI and release wrapper also build through SwiftPM.

### Unit Test Commands

Discovered:

```bash
swift test --filter <RelevantSwiftTestName>
swift test --no-parallel
PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector
```

Focused Swift examples documented for compatibility work:

```bash
swift test --filter LoLaCompatibilityMediaCodecTests
swift test --filter LoLaCompatibilityMediaSessionTests
```

CI sanitizer smokes:

```bash
swift test --sanitize=thread --filter SPSCAtomicRing --no-parallel
swift test --sanitize=thread --filter DirectPeerAudioPayloadRing --no-parallel
swift test --sanitize=thread --filter VideoCaptureReport --no-parallel
```

### Integration/E2E And Runtime Probes

Discovered from `docs/testing/README.md`, `README.md`, and `scripts/README.md`:

```bash
bash scripts/verify-release-readiness.sh
.build/debug/open-lola session-capabilities
.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness.json
.build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness.json
```

Local connector parity/smoke commands are documented under `scripts/README.md`,
including JackTrip and UltraGrid Docker/native helpers. They are local process
evidence only and remain `PARTIAL` without physical route/media/timing
measurement.

Manual evidence gates remain for hardware, route, timing, video, control,
lighting, recording, signing, notarization, Gatekeeper, clean-Mac launch, and
reviewer evidence.

### Lint, Typecheck, Static Analysis, Docs, Format

Discovered:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
ruff check linux_connector scripts/verify_docs scripts/lib/*.py
python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh
bash scripts/verify-release-hygiene.sh
git diff --check
```

No dedicated format command was found. `git diff --check` is the available
whitespace check used in this baseline.

### Migrations, Generated Code, Snapshots, Fixtures, Services

- Swift test fixtures live under `Tests/OpenLolaCoreTests/Fixtures/`.
- SwiftPM processes fixtures into the isolated build directory during tests.
- Release candidate exports are staged with
  `bash scripts/export-release-candidate.sh /path/to/output-parent`; the raw
  checkout is not a release artifact.
- Docker/JackTrip/UltraGrid helper commands require local Docker images,
  native binaries, or reviewed image tags depending on path.
- Linux connector packet decoder requires optional `scapy`.
- No database migrations were discovered.

## Commands Actually Run

| Command | Result | Notes |
|---|---|---|
| `bash scripts/verify-docs.sh` | PASS | Ended with `Documentation verification passed.` |
| `python3 -m scripts.verify_docs` | PASS | Ended with `Documentation verification passed.` |
| `env RUFF_CACHE_DIR=/tmp/open-lola-verification-baseline-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py` | PASS | `All checks passed!` |
| `env PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS | 98 Python tests passed in 0.79s. |
| `env MYPY_CACHE_DIR=/tmp/open-lola-verification-baseline-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py` | PASS | `Success: no issues found in 22 source files`. |
| `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh` | PASS | Exit code 0, no output. |
| `git diff --check` | PASS | Exit code 0, no whitespace errors. |
| `bash scripts/verify-release-hygiene.sh` | FAIL | Fails live checkout generated-residue scan on `./.ruff_cache`. |
| `timeout 900 swift build --build-path /private/tmp/open-lola2-verification-baseline-build` | NOT RUN | `timeout` command is unavailable. |
| `swift build --build-path /private/tmp/open-lola2-verification-baseline-build` inside sandbox | FAIL | SwiftPM manifest sandbox failure: `sandbox-exec: sandbox_apply: Operation not permitted`. |
| `swift build --build-path /private/tmp/open-lola2-verification-baseline-build` outside sandbox | PASS | Build complete in 35.77s. Warnings from vendored Opus/JPEG XS C sources. |
| `swift test --build-path /private/tmp/open-lola2-verification-baseline-build --no-parallel` outside sandbox | FAIL | 472 Swift Testing tests run, 1 issue. Failing test: `scopedCodeFilesStayWithinLineBudget`. |

## Failures

### Release Hygiene

Command:

```bash
bash scripts/verify-release-hygiene.sh
```

Result:

```text
== release hygiene repository policy ==
== release hygiene live checkout generated-residue scan ==
verify-release-hygiene: live checkout contains forbidden generated artifact before release readiness: ./.ruff_cache
```

Interpretation: release hygiene cannot currently be used as a green release
signal until generated cache residue is removed or the live scan root is
intentionally scoped. This baseline did not delete `.ruff_cache`.

### SwiftPM Sandbox Manifest Failure

Command:

```bash
swift build --build-path /private/tmp/open-lola2-verification-baseline-build
```

when run inside the normal sandbox failed with:

```text
sandbox-exec: sandbox_apply: Operation not permitted
```

Interpretation: SwiftPM verification on this Mac requires running outside the
strict sandbox, matching the repo docs.

### Swift Test Failure

Command:

```bash
swift test --build-path /private/tmp/open-lola2-verification-baseline-build --no-parallel
```

Result:

```text
Test run with 472 tests in 0 suites failed after 151.791 seconds with 1 issue.
```

Failing test:

```text
scopedCodeFilesStayWithinLineBudget()
Caught error: Files exceed per-class LOC budgets:
830/720 linux_connector/tests/test_process_runtime.py
```

Interpretation: the broad Swift suite is red on a line-budget policy guard, not
on an observed runtime assertion in this run. Do not say "Swift tests pass" for
this checkout.

## Skipped Checks

- `bash scripts/verify-release-readiness.sh`: skipped after its component gates
  showed blockers. It would run `verify-release-hygiene.sh`, `swift build`,
  `swift test --no-parallel`, CLI probes, and native app launch verification.
  Current blockers already include live `.ruff_cache` release-hygiene failure
  and the Swift line-budget test failure.
- `swift test --sanitize=thread --filter SPSCAtomicRing --no-parallel`: skipped
  in this baseline because the non-sanitized broad Swift suite is already red.
- `swift test --sanitize=thread --filter DirectPeerAudioPayloadRing --no-parallel`:
  skipped for the same reason.
- `swift test --sanitize=thread --filter VideoCaptureReport --no-parallel`:
  skipped for the same reason.
- `bash script/build_and_run.sh --verify`: skipped because it performs native
  app launch/UI evidence collection; the broader release wrapper is already
  blocked before that point.
- Docker/native JackTrip and UltraGrid parity probes: skipped because they
  require local services/images/native tools and are not the safest baseline
  commands for a docs-only verification inventory.
- Manual hardware/signing/release evidence gates: not runnable automatically in
  this environment.
- Optional `scapy` packet decoder checks: not run; optional `pcap` dependency
  was not installed or verified.

## Missing Dependencies And Environment Blockers

- `timeout` is missing.
- SwiftPM manifest execution fails under the normal sandbox and must be
  escalated/outside-sandbox for meaningful Swift build/test evidence.
- Live checkout contains `.ruff_cache`, causing release hygiene failure.
- Existing `.mypy_cache` is also present; the hygiene command stops at the
  first forbidden artifact, so this may become the next blocker after
  `.ruff_cache` is removed.
- Physical hardware, route, signing, notarization, Gatekeeper, clean-Mac, and
  reviewer evidence are absent/manual and block product-level `PASS`.

## Flaky Or Suspicious Tests

- No flaky behavior was directly observed in this run.
- Several Swift tests are long enough to be worth watching in future baselines:
  `semanticRecordingSessionArtifactTestsScenario` took about 22.7s,
  LoLa TCP/UDP control loopbacks took about 8-9.6s, and some external connector
  process/workflow tests took multiple seconds.
- The initial XCTest line `Executed 0 tests` is from the test runner shell; the
  actual Swift Testing run executed 472 tests. Do not mistake the initial line
  for an empty suite.

## Tests That Appear Policy-Only Or Implementation-Trivial

This pass did not do a full test-quality audit. Candidate categories that do
not prove runtime behavior by themselves:

- `CodeLineBudgetTests`: useful as a maintainability guard, but it is a
  line-count policy test and currently blocks the broad Swift suite.
- Inventory/matrix alignment tests such as CLI command inventory, source
  ownership inventory, route matrices, docs verifier policy, and report schema
  inventory tests. These are useful governance checks, but they should not be
  treated as hardware/runtime proof.
- Fixture and synthetic smoke contract tests. They protect report semantics but
  do not prove field readiness.

## Commands That Cannot Be Trusted As Green Today

- `bash scripts/verify-release-readiness.sh`: not trustworthy as a green signal
  until release hygiene and broad Swift tests are green. It also includes native
  app launch evidence, which can be environment-sensitive.
- `swift test --no-parallel`: currently red because of `CodeLineBudgetTests`.
- `bash scripts/verify-release-hygiene.sh`: currently red due generated cache
  residue in the live checkout.
- Local Docker/native connector parity scripts: useful only as local process
  evidence and explicitly not physical latency/media proof.
- Synthetic smoke commands and fixtures: useful for schema/contract coverage,
  not product `PASS`.

## Current Verified Surface

Verified in this baseline:

- Documentation verifier and docs shell wrapper.
- Python connector unit tests: 98 passed.
- Python lint and strict typecheck for connector and docs verifier code.
- Shell scripts covered by the declared ShellCheck command.
- Whitespace via `git diff --check`.
- Swift source builds outside the sandbox with isolated build output.

Not verified:

- Full Swift test suite is not green.
- Release-readiness wrapper is not green.
- Thread sanitizer smokes were not run.
- Native app launch verification was not run.
- Docker/native JackTrip and UltraGrid probes were not run.
- Manual hardware/signing/release gates were not run.
- Product runtime readiness remains `PARTIAL`.

## Stronger Verification Blockers

1. Remove or isolate generated cache residue before release hygiene:
   `.ruff_cache` is the current first blocker.
2. Resolve or consciously update the LOC budget failure:
   `linux_connector/tests/test_process_runtime.py` is 830 lines against the
   720-line policy.
3. Rerun `swift test --build-path /private/tmp/open-lola2-verification-baseline-build --no-parallel`
   or the repo-standard `swift test --no-parallel` outside the sandbox.
4. Only after Swift and hygiene are green, rerun
   `bash scripts/verify-release-readiness.sh`.
5. Run CI sanitizer smokes when the baseline is otherwise green.
6. Add manual/runtime evidence for hardware, route, app launch, signing, and
   packaging before making product-level readiness claims.
