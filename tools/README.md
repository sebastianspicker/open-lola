# Repository tools

Run these tools from the repository root. They are development and test
helpers, not services. Most write only to a directory you choose or to a
temporary path. Read a script before you use it with hardware, Docker, SSH,
packet capture, or external executables.

## Routine checks

Use the Make targets; they pass the right arguments and environment:

```bash
make architecture
make code-quality
make test-python
make test-rust
make lint
make verify
```

The main scripts behind them:

| Tool | Purpose |
|---|---|
| `verify_architecture.py` | Check repository layout, Swift target and import rules, the `OpenLolaCore` facade, and retired Python modules |
| `verify_code_quality.py` | Build the first-party file list; enforce 600 lines per file, Lizard CCN 19, and the reviewed 70-token duplication baseline |
| `verify-docs.sh`, `verify_docs/` | Find and check the maintained public Markdown |
| `verify_source_documentation.py` | Require useful comments on first-party sources and public declarations |
| `verify-tracked-boundary.sh` | Keep private, generated, nested-repository, and local workflow files out of Git |
| `verify-release-readiness.sh` | Run the complete local source check |
| `verify-release-hygiene.sh` | Check the checkout policy, or a source candidate you select |
| `verify-codacy-local.sh` | Run the local Codacy configuration |

[docs/testing.md](../docs/testing.md) has the exact per-language commands and
what the checks cannot prove.

### Duplication baseline

`verify_code_quality.py --self-test` tests its file-list rules, the routing of
shell and C files to the right parser, and the failures for baseline growth and
tool drift.

`--print-duplication-baseline` prints a new baseline as JSON to standard output.
It never changes `code-duplication-baseline.json`. The checked-in baseline is
compact but records its schema, detector settings, path table, clone
fingerprints, occurrence counts, and covered-token counts.

The detector finds the longest shared token runs for each pair of files. A clone
is reported or dropped based only on the files that contain it, never on other
files or on manifest order. Copies of the same run in several files share one
fingerprint. A group counts when its copies cover at least 140 tokens in total
(two copies of 70 tokens, or more copies of fewer). Editing a file changes only
the fingerprints of clones it takes part in.

To update the baseline, review the `--print-duplication-baseline` output for
clones in changed code, then replace the checked-in file with it in the same
change.

The opt-in release benchmarks are off by default. Their commands, workloads,
and limits are in [the benchmark methodology](../docs/benchmark-methodology.md).

## macOS local bundle and assets

`tools/macos/build_and_run.sh` builds a local app bundle and can launch it, for
checking processes, accessibility, screenshots, and the unified log.
`tools/macos/build_cli_app_bundle.sh` puts the CLI and app executables into the
same bundle layout.

Both helpers ad-hoc sign the bundle and leave it unsandboxed. The result is a
local test build, not a Developer ID signed, notarized, or distributable app.

Generate or check the icon and social-preview assets:

```bash
bash tools/macos/generate_brand_assets.sh --check
```

## Source candidate

Export a candidate for inspection outside the checkout:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
```

Then verify that exact candidate. Use the path printed after
`release candidate staged at:`; the directory name ends in a timestamp and
process ID:

```bash
OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate-<stamp>-<pid> \
  bash tools/verify-release-hygiene.sh
```

[docs/RELEASING.md](../docs/RELEASING.md) covers the policy and approval steps.
Exporting a candidate does not approve a release.

## External evidence

`verify-pmr-external-proof-bundle.sh` checks the structure and consistency of a
proof bundle collected elsewhere. It does not create hardware, peer, signing, or
clean-machine evidence.

The JackTrip and UltraGrid scripts help with compatibility work:

- `build-local-ultragrid-docker.sh` and `start-local-ultragrid-docker.sh` build
  and run a pinned local UltraGrid image;
- `run-local-*`, `compare-local-*`, and `stress-local-*` exercise the local
  compatibility report paths;
- `run-reference-peer-parity-gate.sh` runs selected parity comparisons.

The app's launch plans use built-in JackTrip and UltraGrid launch kinds. Passing
a reference wrapper as `--executable` does not prove that the wrapper handled
the media. Treat these scripts as diagnostics, unless the report and a separate
process or packet observation show which external peer actually ran.

Docker, native binaries, and reference peers are optional. A missing tool or a
skipped probe does not count as a pass.

## Helper libraries

`tools/lib/common.sh` has shared shell helpers for failures, paths, and Swift
builds. `tools/lib/parity.sh` supports the parity scripts. The small Python
programs in `tools/lib/` turn JSON inputs into connection or parity metrics and
extract validated executable paths. They are internal to the scripts, not a
public API.

Do not store generated logs, reports, captures, packages, or credentials in
`tools/` or anywhere else in the tracked tree.
