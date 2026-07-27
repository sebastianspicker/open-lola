# Releasing

Date: 2026-07-24
Status: source-alpha release procedure; publication approval pending
Verdict: PARTIAL

This procedure prepares a reproducible source-only alpha. It does not authorize
commits, tags, pushes, GitHub releases, binary distribution, or changes to the
project's legal posture.

## Release model

- Proposed first alpha: `v0.1.0-alpha.1`.
- Package and app marketing version: `0.1.0`.
- Distribution: curated source tree only.
- Release title: `Open LoLa v0.1.0-alpha.1: source alpha`.
- Required status document: [../RELEASE_STATUS.md](../RELEASE_STATUS.md).

The prerelease suffix belongs to the Git tag and release title. Keep numeric
bundle/package versions compatible with their platform formats.

## Hard stops

Do not publish while any of these conditions is true:

- `LICENSE` remains a no-license notice and grants no rights;
- third-party notices, JPEG XS disposition, or fixture provenance are open;
- the exact commit has not completed source, clean-room, legal, and release
  review;
- the pinned CI matrix is not green;
- the exported candidate differs from the reviewed revision;
- maintainer approval for the commit, tag, push, and GitHub release has not been
  given explicitly.

## 1. Review the public tree

Confirm that the checkout contains only active product source, tests, fixtures,
public docs, GitHub community files, reproducible configuration, and release
tooling. Private evidence, archives, captures, credentials, local tool state,
working notes, and transient products must remain outside the tracked boundary.

```bash
git status --short
bash scripts/verify-tracked-boundary.sh
bash scripts/verify-release-hygiene.sh
```

Review every pending deletion and untracked public file deliberately. Never use
a bulk cleanup command as release evidence.

## 2. Refresh public documentation

Update these files together when the candidate state changes:

- `README.md`
- `RELEASE_STATUS.md`
- `CHANGELOG.md`
- `SUPPORT.md`
- `docs/current-state.md`
- `docs/testing.md`
- `docs/release-boundary.md`
- `docs/release-manifest.md`

Regenerate the approved screenshots from the real SwiftUI hierarchy:

```bash
bash scripts/macos/render_docs_screenshots.sh
```

The images are fixed offline UI documentation. They are not app-launch,
live-media, latency, hardware, or interoperability evidence.

## 3. Run local source gates

Use caches and build products outside the checkout:

```bash
bash scripts/verify-docs.sh
PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs
PYTHONDONTWRITEBYTECODE=1 python3 scripts/verify_source_documentation.py
shellcheck -x scripts/*.sh scripts/lib/*.sh scripts/macos/*.sh linux_connector/deployment/wsl/*.sh
git diff --check

export OPEN_LOLA_SWIFT_BUILD_PATH=/private/tmp/open-lola-swiftpm-build
swift build --disable-sandbox --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
swift test --disable-sandbox --no-parallel \
  --scratch-path "$OPEN_LOLA_SWIFT_BUILD_PATH"
```

Run the locked Python checks where dependency resolution is available:

```bash
UV_CACHE_DIR=/private/tmp/open-lola-uv-cache \
UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env \
uv run --locked --extra dev ruff check \
  linux_connector scripts/verify_docs scripts/lib/*.py

UV_CACHE_DIR=/private/tmp/open-lola-uv-cache \
UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env \
MYPY_CACHE_DIR=/private/tmp/open-lola-mypy-cache \
uv run --locked --extra dev python -m mypy --strict \
  linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py

UV_CACHE_DIR=/private/tmp/open-lola-uv-cache \
UV_PROJECT_ENVIRONMENT=/private/tmp/open-lola-uv-env \
PYTHONDONTWRITEBYTECODE=1 \
uv run --locked --extra dev python -m pytest -p no:cacheprovider \
  linux_connector/tests
```

Record skipped or sandbox-blocked checks as uncertainty; do not convert subset
evidence into an all-tests-pass claim.

## 4. Export the inspection candidate

Generate the source candidate outside the repository:

```bash
bash scripts/export-release-candidate.sh /private/tmp/open-lola-release
```

The exporter prints the exact candidate path and runs the full candidate hygiene
scan. A `RELEASE_CANDIDATE_EXPORT_VERDICT: PASS` proves source-shape hygiene
only. It rejects a dirty checkout by default. A maintainer may set
`OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1` for review during development, but the
result is marked `DIRTY_INSPECTION_ONLY` and is not a release input.

Inspect the candidate independently:

```bash
OPEN_LOLA_RELEASE_CANDIDATE=/path/from/export \
  bash scripts/verify-release-hygiene.sh
```

## 5. Freeze and review

After the local tree is ready, but before any publication action:

1. select the exact commit proposed for the alpha;
2. run the pinned GitHub Actions workflow on that commit;
3. review the candidate diff, notices, screenshots, and status document;
4. confirm the source export contains no binaries or local-only material;
5. obtain explicit maintainer approval for each Git mutation and publication
   action.

The workflow validates pushes to `main`, pull requests, manual dispatches, and
alpha tags matching `v*-alpha.*`. It has read-only repository permissions and
does not upload or publish artifacts.

## 6. Review GitHub repository settings

After the reviewed repository is public, but before announcing the alpha,
verify these settings manually:

- repository title, description, website, and topics match the current
  positioning and do not imply affiliation or production readiness;
- `.github/assets/open-lola-social-preview.png` is selected as the repository
  social preview;
- private vulnerability reporting is enabled and the Security tab exposes the
  route documented in `SECURITY.md`;
- issue forms and the pull-request template render correctly;
- the default branch is protected with the release-readiness workflow required;
- Actions has only the permissions required by the checked-in workflow; and
- no environment, Pages deployment, package, release, or artifact publication
  is enabled implicitly.

Record the result in `RELEASE_STATUS.md`. Repository settings are external state
and cannot be proven by a local source-tree check.

## 7. Publish only after approval

Once every blocker and approval item is closed, create the approved commit and
annotated or signed tag according to repository policy, push only the approved
references, and create a GitHub prerelease from the reviewed notes. The release
must:

- be marked as a prerelease;
- link to `RELEASE_STATUS.md`, `CHANGELOG.md`, and the release manifest;
- describe the evidence as source/synthetic unless stronger measurements exist;
- contain no binary attachments for this source-only alpha;
- keep the `PARTIAL` product/runtime verdict visible.

Any future binary release needs a separate signed, notarized, Gatekeeper-tested,
clean-Mac workflow and its own evidence packet.

VERDICT: PARTIAL
