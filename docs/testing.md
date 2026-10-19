# Testing and verification

Test sources (the Swift test targets and the Rust integration tests) are not
published with this repository. Without them, `make swift-test` builds the
package and prints a `SKIPPED:` line. Rust unit tests inside `src/` still run.

## Full gate

Run from the repository root:

```bash
make verify
```

`make verify` sets `OPEN_LOLA_SKIP_INTERACTIVE_APP=1` and
`OPEN_LOLA_SKIP_LIVE_RESIDUE=1`, so it skips the GUI launch probe and the
raw-checkout residue scan and prints a `SKIPPED:` line for each. To run those
two checks as well, use `make verify-full` in a logged-in GUI session on a
checkout without generated files. All gate variables, including the
`OPEN_LOLA_TEST_OPEN_LOLA_CLI` and `OPEN_LOLA_RELEASE_HYGIENE_LIVE_ROOT`
redirects (which print a warning), are listed in
[configuration.md](configuration.md#build-and-gate-variables).

Both targets run:

- architecture, tracked-path, documentation and source-comment checks;
- the 600-line file and CCN 19 function budgets for first-party code;
- ShellCheck, plus Python lint, type checks and verifier self-tests;
- Rust formatting, Clippy, tests and selftest;
- release hygiene, the Swift build and tests, and the CLI probes.

The final product verdict stays `PARTIAL` by design.

A raw checkout is not a release candidate. Verify an exported candidate
separately as described in [RELEASING.md](RELEASING.md).

## Individual targets

```bash
make architecture
make code-quality
make code-quality-self-test
make test-python
make test-rust
make swift-test
make lint
```

`swift-build` is the warnings-as-errors build.

The underlying commands are:

```bash
uv run --locked --extra dev python tools/verify_code_quality.py

uv lock --check
uv run --locked --extra dev ruff check \
  tools/verify_docs tools/lib/*.py \
  tools/verify_source_documentation.py tools/verify_architecture.py \
  tools/verify_code_quality.py tools/verify_pmr14_runtime_contract.py
uv run --locked --extra dev mypy --strict \
  tools/verify_docs tools/lib/*.py tools/verify_source_documentation.py \
  tools/verify_architecture.py tools/verify_code_quality.py \
  tools/verify_pmr14_runtime_contract.py
make python-tool-tests
cargo run -p rusty-lola --no-default-features -- selftest --duration 0.25

cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- \
  -D warnings -D clippy::undocumented_unsafe_blocks \
  -D clippy::missing_safety_doc
cargo test --workspace --all-targets --all-features
cargo test --workspace --all-targets --no-default-features

node --check web/demo/app.js
actionlint

```

### Code-quality budgets

`make code-quality` checks every tracked, non-ignored first-party source file:
Swift, Rust, Python, shell, PowerShell, web and the Opus bridge. It skips
corpora, archives, generated output and vendored upstream code, but keeps
`third_party/opus/openlola_bridge/`.

- Each file may have at most 600 physical lines.
- Each function Lizard can parse may have a CCN of at most 19. Shell files go
  through Lizard's C-like parser.
- Duplicated code is measured as shared normalized-token runs between two files
  (70 tokens, or 140 summed over all copies). Results are compared against
  `tools/code-duplication-baseline.json`. The gate never rewrites that file;
  any new, grown or stale entry, or a schema or tool-version change, fails and
  needs review.
- A temporary file-size exception needs a reason in
  `tools/code-line-budget-exceptions.txt`. There are currently none.

`make lint` also builds Swift with warnings as errors in an external scratch
path, runs `node --check` on the demo JavaScript, and requires Actionlint
1.7.12. Native Linux and Windows CI jobs build and test both the GUI and
CLI-only configurations.

### Documentation-only changes

```bash
bash tools/verify-docs.sh
python3 -m tools.verify_docs
git diff --check
```

## CI coverage

The main workflow runs repository quality checks, Python 3.11 to 3.13 tooling,
macOS Swift, Ubuntu 24.04 Rust, and Windows Rust release builds and tests. The
Python matrix runs the repository verifier tests. Release readiness includes
the pinned macOS gate and the Python 3.11 tooling job. CodeQL analyzes the
Python tooling and Swift separately. Rust jobs test the native adapter
substitutes, the shared corpus, and CLI-only and all-feature builds. Native
virtual-device and physical tests are opt-in; see [ALSA](linux-alsa.md) and
[V4L2](linux-v4l2.md). A green CI run covers only that run and revision.

## Evidence vocabulary

Use these labels in reports and documentation:

| Label | Meaning |
|---|---|
| `source` | The code or static definition exists. |
| `synthetic` | Generated data exercised an implemented path. |
| `localhost` | Real processes and sockets ran on one host. |
| `measured hardware` | Named physical devices and conditions were measured. |
| `reference peer` | An independently operated peer took part in the run. |
| `not measured` | The required observation does not exist. |

Record the revision, platform, toolchain, command, relevant configuration and
result. A result holds only for that scope. Do not describe hypotheses or
planned acceptance thresholds as implemented features.

## What the suites cover

- Swift regression tests cover transport timing, direct-peer scheduling, media
  buffering and rendering, LoLa connector lifecycle and negotiation, and two
  concurrent synthetic peers running the full A/V loop with headless preview.
  Run them with `make swift-test` in a checkout that has the test sources. The
  broader synthetic CLI probes are separate.
- Core Audio lifetime tests inject failures into HAL creation, startup, stop and
  destruction. They then call the real callback functions after the graph is
  released, including a callback still running past the teardown timeout and
  split registrations. They need no audio device and can run under Address
  Sanitizer.
- Python tests cover the documentation, architecture and code-quality tooling.
  Where the old runtime assertions went is listed in
  [Linux migration](linux-migration.md).
- Rust tests cover protocol, configuration, resources, media, lifecycle and the
  diagnostic and native API substitutes. They also cover malformed-packet
  recovery, bounded drains, cancellation, capture parsing, trust checks and
  repeated selftests.
- The architecture checker enforces the runtime layout, Swift target
  dependencies, facade shape, import and side-effect rules, and the retired
  Python-module rules.

None of this proves a graphical macOS session, real network conditions,
physical devices, Windows driver behavior, native Linux realtime performance,
signed or notarized installation, or approval to publish. Record those results
separately; synthetic or old results do not count for them.

VERDICT: PARTIAL
