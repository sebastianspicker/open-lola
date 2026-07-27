# Contributing to open-lola

## Source-alpha scope

This repository is an experimental source alpha. Its public verdict is
`PARTIAL`: source, tests, fixtures, and reports are useful implementation
evidence, not a claim of field, hardware, security, or release readiness.

Contributions must remain clean-room. Use public standards, public APIs,
original experiments, and sources you are entitled to share. Do not submit
proprietary binaries, decompiled material, confidential captures, credentials,
or material received under a non-disclosure obligation.

## Before opening a change

1. Describe the observed behavior and label supporting evidence accurately:
   `source`, `synthetic`, `localhost`, `measured hardware`, `reference peer`,
   or `not measured`.
2. Keep a claim at the evidence level it earned. A passing unit test, fixture,
   or localhost run is not field interoperability or product `PASS`.
3. Keep public submissions sanitized. Do not include secrets, private packet or
   media captures, personal data, hostnames, or customer/project information.
   Use the [Security tab](../../security) for a suspected vulnerability.

## Local verification

### Source documentation

Every first-party Swift, Python, shell, PowerShell, C, C-header, and Dockerfile
source must begin with a brief purpose comment that explains the responsibility
kept in that file and why the boundary exists. Public top-level types and
functions, exported Python declarations, and command entry points need concise
doc comments or docstrings. Members and private helpers need comments when an
invariant, safety boundary, fallback, protocol rule, or non-obvious tradeoff
would otherwise be unclear.

Prefer intent over narration: explain why work is bounded, deferred, validated,
or kept off a realtime path instead of restating the next line of code.
Vendored upstream source, generated fixtures, and data-only assets are outside
this documentation rule.

Run the deterministic coverage check with:

```bash
python3 scripts/verify_source_documentation.py
```

For documentation or policy changes, run the narrow checks that apply:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
git diff --check
bash scripts/verify-release-hygiene.sh
```

For Swift changes, use the repository's macOS-safe SwiftPM invocation:

The primary CI toolchain is Xcode 26.6 with Swift 6.3.3.

```bash
export OPEN_LOLA_SWIFT_BUILD_PATH=/private/tmp/open-lola-swiftpm-build
export OPEN_LOLA_TEST_OPEN_LOLA_CLI="$OPEN_LOLA_SWIFT_BUILD_PATH/debug/open-lola"
swift build --disable-sandbox --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
swift test --disable-sandbox --no-parallel --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
```

For Python connector checks, keep caches and the environment outside the
checkout:

Use the repository's Python 3.14.6 pin; Python 3.11 remains the supported
lower bound.

```bash
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env uv lock --check
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env PYTHONDONTWRITEBYTECODE=1 uv run --extra dev --locked ruff check linux_connector scripts/verify_docs scripts/lib/*.py
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env PYTHONDONTWRITEBYTECODE=1 uv run --extra dev --locked python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env PYTHONDONTWRITEBYTECODE=1 uv run --extra dev --locked python -m pytest -p no:cacheprovider linux_connector/tests
```

Report every command run and every check you could not run in the pull request.
See [the active testing index](docs/testing.md) for the broader matrix and its
evidence boundaries.

## Pull requests

Keep each pull request focused, preserve existing evidence labels, and explain
any changed claim, fixture provenance, release boundary, or runtime risk. Do
not describe a source-alpha change as shipped, certified, interoperable, or
field-ready without the corresponding measured and reviewed evidence.

By participating, you agree to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).
