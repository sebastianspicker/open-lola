# Verification Baseline

Date: 2026-05-16
Host context: macOS, zsh, Python 3.13.5, Swift 6.2.4 / Xcode 26.3.0 toolchain, ruff 0.14.14, pytest 8.3.4, mypy 1.14.1, ShellCheck 0.11.0, Docker 29.5.0.

This is a source and tooling baseline only. It does not prove live audio/video hardware behavior, Windows LoLa interoperability, signing/notarization, clean-Mac installation, or field readiness.

## Verdict

- Python Linux connector checks are green for the commands run: ruff, pytest, and strict mypy.
- Shell lint checks are green for the commands run.
- Swift build is green when SwiftPM runs outside the Codex command sandbox.
- Full Swift tests are green for the command run: 454 Swift Testing tests passed with `swift test --no-parallel`.
- Documentation verification is red because an archived README links to `reverse-engineering/.DS_Store`.
- Release readiness is red because it stops at the failing documentation gate.
- Release hygiene is red in this live checkout because Python module execution created `scripts/verify_docs/__pycache__`.
- ThreadSanitizer CI smokes are blocked on this host/toolchain by macOS platform policy rejecting the TSan runtime dylib.

## Commands Discovered

Install/setup:
- Python project metadata is in `pyproject.toml`; dev dependencies are `mypy==1.14.1`, `pytest>=8.3,<9`, `pytest-asyncio>=0.25,<1`, and `ruff>=0.11,<1`.
- CI installs Python 3.12 and installs project dev dependencies from `pyproject.toml`.
- Swift dependencies and C targets are managed by SwiftPM through `Package.swift`.
- CI installs `shellcheck` through Homebrew when missing.
- Docker is used for Linux connector helper environments through `linux_connector/env/compose.yaml`.

Build:
- `swift build`
- `swift build --product open-lola`
- `swift build --product open-lola-app`
- `script/build_and_run.sh --verify`
- `script/build_cli_app_bundle.sh`
- `bash scripts/export-release-candidate.sh /path/to/output-parent`

Unit/source tests:
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`
- `swift test --filter LoLaCompatibilityMediaCodecTests`
- `swift test --filter LoLaCompatibilityMediaSessionTests`
- `swift test --no-parallel`

Integration/e2e/smoke:
- `bash scripts/verify-release-readiness.sh`
- `bash scripts/verify-release-hygiene.sh`
- `docker compose -f linux_connector/env/compose.yaml config --quiet`
- CI thread-sanitizer smokes:
  - `swift test --sanitize=thread --filter SPSCAtomicRing --no-parallel`
  - `swift test --sanitize=thread --filter DirectPeerAudioPayloadRing --no-parallel`
  - `swift test --sanitize=thread --filter VideoCaptureReport --no-parallel`
- Manual/runtime gates documented by the repo include native app launch, CLI probes, hardware route evidence, Windows LoLa peer evidence, signing/notarization, and clean-Mac install checks.

Lint/typecheck/static analysis:
- `ruff check linux_connector scripts/verify_docs scripts/lib/*.py`
- `python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh`

Docs/format-like checks:
- `bash scripts/verify-docs.sh`
- `python3 -m scripts.verify_docs`
- `shellcheck -x scripts/verify-docs.sh scripts/lib/*.sh`
- No dedicated formatter or format-check command was found.

Migrations/generated/snapshots/fixtures/services:
- No database migration system was found.
- Swift test fixtures live under `Tests/OpenLolaCoreTests/Fixtures`.
- Generated release candidates are created by `scripts/export-release-candidate.sh`.
- Python bytecode caches are forbidden by release hygiene in the live checkout.
- Docker compose syntax can be checked for `linux_connector/env/compose.yaml`; this does not prove service runtime.

## Commands Run

| Command | Result | Notes |
| --- | --- | --- |
| `python --version` / `python3 --version` / `swift --version` | PASS | Python 3.13.5; Swift driver 1.127.15, Apple Swift 6.2.4, target arm64-apple-macosx26.0. |
| `ruff --version` | PASS | `ruff 0.14.14`. |
| `pytest --version` | PASS | `pytest 8.3.4`. |
| `python -m mypy --version` | PASS | `mypy 1.14.1 (compiled: yes)`. |
| `shellcheck --version` | PASS | ShellCheck 0.11.0. |
| `docker --version` | PASS | Docker 29.5.0. |
| `bash scripts/verify-docs.sh` | FAIL | Broken relative link: `archive/2026-05-11-reverse-engineering-consolidation/README.md` -> `reverse-engineering/.DS_Store`. |
| `python3 -m scripts.verify_docs` | FAIL | Same broken archived `.DS_Store` link. This command created `scripts/verify_docs/__pycache__`. |
| `shellcheck -x scripts/verify-docs.sh scripts/lib/*.sh` | PASS | No output. |
| `RUFF_CACHE_DIR=/private/tmp/open-lola-verification-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py` | PASS | `All checks passed!` |
| `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` | PASS | 87 collected; 85 passed, 2 skipped in 0.67s. |
| `MYPY_CACHE_DIR=/private/tmp/open-lola-verification-mypy-cache python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py` | PASS | `Success: no issues found in 22 source files`. |
| `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh` | PASS | No output. |
| `docker compose -f linux_connector/env/compose.yaml config --quiet` | PASS | Compose file parses; no service runtime was started. |
| `bash scripts/verify-release-hygiene.sh` | FAIL | Live checkout contains forbidden generated artifact: `./scripts/verify_docs/__pycache__`. |
| `bash scripts/verify-release-readiness.sh` | FAIL | Stops immediately at `bash scripts/verify-docs.sh` with the archived `.DS_Store` broken link. |
| `swift build --build-path /private/tmp/open-lola-verification-swift-build` | BLOCKED in sandbox | SwiftPM manifest evaluation failed with `sandbox-exec: sandbox_apply: Operation not permitted`. This is not source failure evidence. |
| `swift build --build-path /private/tmp/open-lola-verification-swift-build` outside the sandbox | PASS | Build complete in 25.48s. Warnings came from bundled Opus/JPEG XS C sources. |
| `swift test --build-path /private/tmp/open-lola-verification-swift-build --no-parallel` outside the sandbox | PASS | Build complete in 28.15s; 454 Swift Testing tests passed in 143.343s. |
| `swift test --build-path /private/tmp/open-lola-verification-tsan-spsc --sanitize=thread --filter SPSCAtomicRing --no-parallel` outside the sandbox | BLOCKED | Sanitized build completed in 47.50s, but test launch failed: dyld rejected `libclang_rt.tsan_osx_dynamic.dylib` with `Sanitizer load violates platform policy`. |

## Failures

1. Documentation verification fails on an archived `.DS_Store` link.
   - Failing path: `archive/2026-05-11-reverse-engineering-consolidation/README.md`
   - Broken target: `reverse-engineering/.DS_Store`
   - Impact: the docs gate and release-readiness wrapper cannot complete.

2. Release hygiene fails because a generated Python cache exists in the live checkout.
   - Path: `scripts/verify_docs/__pycache__`
   - Cause in this run: `python3 -m scripts.verify_docs` created `.cpython-313.pyc` files.
   - Impact: `bash scripts/verify-release-hygiene.sh` is correctly red for the current live checkout.

3. ThreadSanitizer smokes cannot run on this host/toolchain as configured.
   - The sanitized build succeeds.
   - The test binary aborts before tests run because macOS rejects the TSan runtime dylib with platform policy.
   - Remaining CI TSan filters were not run because they depend on the same sanitizer runtime.

## Skipped Or Not Fully Verified

- `swift test --filter LoLaCompatibilityMediaCodecTests` and `swift test --filter LoLaCompatibilityMediaSessionTests` were not run separately because the full `swift test --no-parallel` suite ran successfully and includes those test files.
- `swift test --sanitize=thread --filter DirectPeerAudioPayloadRing --no-parallel` was skipped after the first TSan smoke proved the sanitizer runtime cannot load.
- `swift test --sanitize=thread --filter VideoCaptureReport --no-parallel` was skipped for the same TSan runtime blocker.
- Release-readiness steps after documentation verification were not reached by `scripts/verify-release-readiness.sh`.
- Native app launch, UI inspection, audio/video hardware routes, Windows LoLa peer runs, signing/notarization, clean-Mac install, and field-runtime evidence were not run.
- Release candidate export was not run.
- Docker service runtime was not run; only compose syntax was checked.
- Test meaningfulness was not exhaustively audited in this pass. Existing testing docs note that this repo has source-string guards and fixture/report contract tests; this baseline records command behavior, not a full test-quality review.

## Missing Dependencies And Environment Blockers

- No missing Python, shell, Docker, or Swift command-line tools were found for the checks run.
- Local Python is 3.13.5 while CI uses Python 3.12, so Python results are local-host evidence, not exact CI parity.
- SwiftPM cannot evaluate the manifest inside the Codex command sandbox on this host. Swift build/test evidence required running SwiftPM outside that sandbox.
- ThreadSanitizer is blocked by platform policy for the Xcode 26.3.0 sanitizer runtime on this host.
- Release hygiene is blocked until generated cache residue is absent from the live checkout.
- Release readiness is blocked until documentation verification is green.

## Suspicious Or Low-Trust Results

- `bash scripts/verify-release-readiness.sh` cannot currently be treated as a full release result because it exits at the documentation gate.
- `bash scripts/verify-release-hygiene.sh` is trustworthy for checkout cleanliness, but the current failure includes cache files created by this baseline run.
- `docker compose ... config --quiet` proves only compose syntax, not container health or connector behavior.
- The Python pytest result covers `linux_connector`; it does not cover Swift runtime behavior.
- The Swift test result proves source-level unit/contract behavior only. Many passing fixtures are explicitly `partial` or synthetic and do not prove real hardware, signing, Windows peer, or field behavior.
- The TSan result is an environment/toolchain blocker, not evidence that concurrency paths are safe or unsafe.

## Current Verified Surface

- Python Linux connector lint/type/unit checks passed for the commands run.
- Shell scripts passed ShellCheck for the checked paths.
- Docker compose syntax is valid for `linux_connector/env/compose.yaml`.
- Swift package builds successfully outside the sandbox.
- The full non-sanitized Swift test suite passed outside the sandbox.

## Current Unverified Surface

- End-to-end release readiness remains unverified because docs verification fails.
- Release hygiene remains red until generated residue is removed.
- Thread-sanitized concurrency evidence is unavailable on this host.
- Runtime audio/video device I/O, UDP/P2P live traffic, TX/RX/local RX behavior, packet loss/jitter/reordering under real load, UI runtime behavior, native app launch, Windows LoLa interoperability, signing/notarization, release candidate export, and clean install are unverified.

## Generated Cache/Output Created

The command `python3 -m scripts.verify_docs` created Python bytecode under `scripts/verify_docs/__pycache__`. This is repository-local generated output and is intentionally recorded here instead of silently removed.
