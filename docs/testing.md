# Testing and verification

Status: active
Verdict: PARTIAL

Tests protect observable behavior and architectural boundaries. Production
report models whose names contain `Test` are not test-suite cases; executable
tests live in `Tests/`, the Python runtime test package, and Rust test modules.

## Full acceptance

```bash
make verify
```

The wrapper runs architecture and documentation checks, locked Python lint,
typing, tests and CLI selftest, Swift build/tests and CLI probes, Rust format,
Clippy and tests, shell checks, and release-boundary validation. CI also runs
the language lanes independently so one toolchain failure is attributable.
Local `make verify` preserves ignored user state and labels the raw-checkout
residue scan as skipped. Verify the exported inspection candidate separately;
candidate hygiene is the release-boundary proof, while a dirty candidate
remains nonpublishable.

## Focused lanes

Swift, with build products outside the checkout:

```bash
DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer \
swift test --disable-sandbox \
  --scratch-path /private/tmp/open-lola-swiftpm-test-build
```

Python, using the locked environment:

```bash
uv lock --check
uv run --locked --extra dev ruff check \
  runtimes/linux-compat-connector tools/verify_docs tools/lib/*.py
uv run --locked --extra dev python -m mypy --strict \
  runtimes/linux-compat-connector/linux_connector \
  tools/verify_docs tools/lib/*.py
uv run --locked --extra dev python -m pytest -p no:cacheprovider \
  runtimes/linux-compat-connector/linux_connector/tests
uv run --locked python -m linux_connector.lola_connector.cli \
  --local-ip 127.0.0.1 selftest --duration 0.25
```

Rust, from the workspace root:

```bash
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features -- \
  -D warnings -D clippy::undocumented_unsafe_blocks -D clippy::missing_safety_doc
cargo test --workspace --all-targets --all-features
```

Architecture and documentation:

```bash
python3 tools/verify_architecture.py
python3 tools/verify_architecture.py --self-test
bash tools/verify-docs.sh
python3 -m tools.verify_docs
python3 tools/verify_source_documentation.py
bash tools/verify-release-hygiene.sh
git diff --check
```

## What the suites prove

- Swift contract tests protect deterministic JSON, control-message encoding,
  error round trips, and ordered session-state transitions.
- Python tests protect protocol parsing, orchestration boundaries, and the
  exported and subprocess CLI selftest path.
- Rust tests protect protocol, configuration, resource, media, and lifecycle
  behavior on locally available adapters.
- The architecture checker rejects restored legacy roots, invalid macOS facade
  shape, forbidden lower-layer imports/side effects, target-DAG violations,
  and references to retired Python helper modules.
- The Python distribution test builds a wheel in an isolated source copy,
  checks its package contents, installs it into a clean virtual environment,
  and runs the installed CLI self-test.

These are software checks. They do not prove physical two-peer latency, device
drivers, RME/Blackmagic behavior, Windows peer interoperability, native Linux
realtime performance, a graphical macOS session, signing, notarization, or
clean-machine installation. Record those results separately and never replace
them with localhost or synthetic evidence.
