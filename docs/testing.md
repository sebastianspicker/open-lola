# Testing and verification

Status: active
Verdict: PARTIAL

Tests here protect observable behavior and architecture. A passing check proves
only the named source, synthetic, localhost, or packaging scope; it does not
establish hardware, reference-peer, security, signing, or distribution claims.

## Full source gate

Run from the repository root:

```bash
make verify
```

The Make target sets the documented headless and raw-checkout residue skips, then
runs the architecture, tracked-boundary, documentation, and source-comment
checks; the first-party 600-line and CCN 19 budgets; ShellCheck; Python tooling
lint, type, and verifier self-tests; Rust formatting, Clippy, tests, and
selftest; release hygiene; the Swift build and tests; and the CLI evidence
probes. The final product verdict remains `PARTIAL` by design.

A raw checkout is not a source release candidate. Verify an exported candidate
separately as described in [RELEASING.md](RELEASING.md).

## Focused lanes

```bash
make architecture
make code-quality
make code-quality-self-test
make test-python
make test-rust
make lint
```

`swift-build` owns the warnings-as-errors build. `make verify` and the release-readiness script
remain independently runnable complete gates.

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

`make code-quality` enumerates one live, non-ignored first-party manifest of
Swift, Rust, Python, shell, PowerShell, web, and bridge sources. It excludes
corpora, archives, generated output, and vendored upstream code while retaining
`third_party/opus/openlola_bridge/`. Every file is limited to 600 physical lines,
and every Lizard-supported function to CCN 19. Shell paths deliberately use
Lizard's C-like parser; the retired WSL PowerShell lane has no remaining runtime
source. Normalized-token clones of 70 or more tokens are compared against the
reviewed `tools/code-duplication-baseline.json`, and the gate never rewrites that
baseline. New, increased, grown, stale, schema, or tool-drifted entries fail for
review. Any temporary file-size exception must be recorded with a reason in
`tools/code-line-budget-exceptions.txt`; the current ledger has no exceptions.

`make lint` additionally requires Swift warnings as errors with an external
scratch path, `node --check` for every static demo JavaScript module, and
Actionlint 1.7.12. Native Linux and Windows CI lanes compile and test both GUI and
CLI-only configurations.

Documentation-only changes should run:

```bash
bash tools/verify-docs.sh
python3 -m tools.verify_docs
git diff --check
```

## CI coverage

The main workflow covers repository quality, Python 3.11 through 3.13 tooling,
macOS Swift, Ubuntu 24.04 Rust, and Windows Rust release builds and tests. The
Python matrix keeps its existing job identities and shared quality dependency; it
runs repository verifier tests instead of the retired connector. Release
readiness includes the pinned macOS gate and the Python 3.11 tooling lane. CodeQL
analyzes Python tooling and Swift independently. Rust jobs test native adapter
substitutes, the shared corpus, and CLI-only and all-feature builds. Native
virtual-device and physical cases are opt-in and described in
[ALSA](linux-alsa.md) and [V4L2](linux-v4l2.md).

CI configuration is execution evidence only for the exact workflow run and
revision. It does not replace an unavailable platform, device, peer, or manual
gate.

## Evidence vocabulary

Use these labels in reports and documentation:

| Label | Meaning |
|---|---|
| `source` | A source or static contract exists. |
| `synthetic` | Generated data exercised an implemented path. |
| `localhost` | Real process/socket behavior ran on one host. |
| `measured hardware` | Named physical devices and conditions were measured. |
| `reference peer` | An independently operated peer participated in the run. |
| `not measured` | The required observation does not exist. |

State the revision, platform, toolchain, command, relevant configuration, and
result. A claim is validated only for that exact scope, and hypotheses or planned
acceptance thresholds must not appear as implemented capability.

## What the suites protect

- Swift tests cover deterministic contracts, session transitions, packet
  validation, media policy, report models, and the checked-in compatibility
  corpus.
- Python verifies documentation, architecture, and code-quality tooling. Its
  retired runtime assertions are mapped in
  [Linux migration](linux-migration.md).
- Rust tests cover protocol, configuration, resources, media, lifecycle, and
  diagnostic/native API substitutes, along with malformed-packet recovery,
  bounded drains, cancellation, capture parsing, trust boundaries, and repeated
  selftests.
- The architecture checker enforces runtime layout, Swift target dependencies,
  facade shape, import and side-effect boundaries, and retired Python-module
  rules.

These suites do not prove a graphical macOS session, real network conditions,
physical devices, Windows driver behavior, native Linux realtime performance,
signed or notarized installation, or publication approval. Record those results
separately, and never substitute synthetic or historical evidence.

VERDICT: PARTIAL
