# Repository tools

Run these tools from the repository root. They are development and validation
helpers, not deployed services. Most write only to a caller-selected directory
or a temporary path; review each script before using it with hardware, Docker,
SSH, packet capture, or external executables.

## Routine verification

Prefer the Make targets because they preserve the supported arguments and
environment:

```bash
make architecture
make code-quality
make test-swift
make test-python
make test-rust
make lint
make verify
```

The important underlying tools are:

| Tool | Purpose |
|---|---|
| `verify_architecture.py` | Check repository layout, Swift target/import boundaries, facade shape, and retired Python modules |
| `verify_code_quality.py` | Build the canonical first-party manifest; enforce 600 lines, Lizard CCN 19, and the reviewed 70-token duplication baseline |
| `verify-docs.sh`, `verify_docs/` | Inventory and validate maintained public Markdown |
| `verify_source_documentation.py` | Require useful first-party source and public-declaration comments |
| `verify-tracked-boundary.sh` | Reject private, generated, nested-repository, and local workflow material from Git |
| `verify-release-readiness.sh` | Compose the complete local source gate |
| `verify-release-hygiene.sh` | Check the raw checkout policy or an explicitly selected source candidate |
| `verify-codacy-local.sh` | Run the repository's local Codacy parity configuration |

Exact language commands and proof limits are in
[docs/testing.md](../docs/testing.md).

`verify_code_quality.py --self-test` exercises its manifest boundaries,
shell-to-C-parser routing, and duplication-baseline growth/tool-drift failures.
`--print-duplication-baseline` is a review aid only: it writes JSON to standard
output and never changes `code-duplication-baseline.json`. The checked-in
baseline is deliberately compact but records its schema, detector settings,
path table, clone fingerprints, occurrence counts, and covered-token counts.
The detector groups clones in manifest path order, so moving or renaming source
files reshuffles fingerprints even when no code is duplicated. After a move, review
the `--print-duplication-baseline` output for clones that involve changed code,
then replace the checked-in baseline with it in the same change.

The opt-in release benchmarks live beside the code they measure, under the Swift
`runtimes/macos/Tests/` and Rust `tests/` trees, and stay disabled by default. Their commands,
workloads, and evidence limits are in
[the benchmark methodology](../docs/benchmark-methodology.md).

## macOS local bundle and assets

`tools/macos/build_and_run.sh` stages and optionally launches a local app bundle
for process, accessibility, screenshot, and unified-log evidence.
`tools/macos/build_cli_app_bundle.sh` assembles the CLI and app executables into
the same local bundle shape.

Both helpers use ad-hoc signing and produce unsandboxed local test artifacts.
They do not create a Developer ID, notarized, Gatekeeper-verified, or
distribution-ready application.

Generate or verify the checked-in icon and social-preview assets with:

```bash
bash tools/macos/generate_brand_assets.sh --check
```

## Source candidate

Create an inspection candidate outside the checkout:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
```

Verify the exact candidate:

```bash
OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate \
  bash tools/verify-release-hygiene.sh
```

The policy and approval sequence are in
[docs/RELEASING.md](../docs/RELEASING.md). An export is not publication
authority.

## External evidence

`verify-pmr-external-proof-bundle.sh` validates the shape and consistency of an
externally collected proof bundle. It does not generate hardware, peer, signing,
or clean-machine evidence.

The JackTrip and UltraGrid scripts are compatibility-development helpers:

- `build-local-ultragrid-docker.sh` and `start-local-ultragrid-docker.sh` manage
  a pinned local UltraGrid image/container;
- `run-local-*`, `compare-local-*`, and `stress-local-*` exercise local
  compatibility report paths; and
- `run-reference-peer-parity-gate.sh` coordinates selected parity inputs.

Current application launch plans select internal JackTrip/UltraGrid launch
kinds. Supplying a reference wrapper as an `--executable` value does not prove
that wrapper handled the media path. Treat these scripts as implementation
diagnostics unless the generated report and an independent process/packet
observation establish the external peer that actually ran.

Docker, native binaries, and reference peers are optional environment-specific
inputs. A missing tool or a skipped probe is not a passing result.

## Helper libraries

`tools/lib/common.sh` contains shared shell failure, path, and Swift-build
helpers. `tools/lib/parity.sh` contains parity-script support. The small Python
programs under `tools/lib/` transform JSON inputs into connection or parity
metrics and extract validated executable paths. They are script internals, not
public package APIs.

Do not store generated logs, reports, captures, packages, or credentials in
`tools/` or anywhere else in the tracked tree.
