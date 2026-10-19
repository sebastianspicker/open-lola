# Source-alpha release procedure

Open LoLa has no automated publish or deploy command. A release is a source
candidate built from a clean, approved revision. Nothing in this document
authorizes publishing.

## What the candidate contains

Included:

- root manifests, lockfiles, license and community files, and public
  documentation;
- `runtimes/**` and `interop/lola2/**`;
- the codec files selected by `Package.swift`, their required headers and
  notices, and `third_party/opus/openlola_bridge/**`;
- active `tools/**`, `web/demo/**`, and public `.github/**` workflows and
  assets.

Excluded: private, internal, reverse-engineering and archive material; local
editor and tool state; credentials, captures, runtime reports, caches, build
and package output; and vendor tests, training data and build files that are
not compiled.

`tools/release-boundary-policy.txt` defines the paths. The exporter copies a
top-level allowlist and strips unselected vendor material, and the hygiene
checker verifies the resulting tree independently. See
[release-manifest.md](release-manifest.md) for the full list.

## Procedure

1. Freeze an approved clean revision and record its commit ID.
2. Run `make verify` with the pinned macOS, Python and Rust toolchains.
3. Complete the hardware, peer, security, signing and distribution checks that
   the release claims require.
4. Finalize `THIRD_PARTY_NOTICES.md`, the JPEG XS decision, fixture and corpus
   provenance, and independent clean-room and legal review for that revision.
5. Export outside the checkout:

   ```bash
   bash tools/export-release-candidate.sh /private/tmp/open-lola-release
   ```

6. Verify the export. The exporter already runs this check once and prints
   `release candidate staged at:` followed by the directory, whose name ends in
   a timestamp and process ID. Use that path:

   ```bash
   OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate-<stamp>-<pid> \
     bash tools/verify-release-hygiene.sh
   ```

7. Record the candidate hash, toolchain versions, results, review decisions and
   the maintainer's approval.
8. Create a tag or publication artifact from that exact revision only after
   separate approval.

`OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1` allows an export from a dirty tree for
inspection. Such an export must not be published or used as release
provenance.

## Vendored code

`Package.swift` declares the compiled subsets of `third_party/opus` and
`third_party/jpeg-xs`. First-party Opus integration code lives only under
`third_party/opus/openlola_bridge/`. Any edit to the upstream trees needs its
origin and reason recorded, a notice review, and a new release decision. JPEG XS
is evaluation and test material; its distribution and patent status are
unresolved, so it is not cleared for production.

A passing hygiene check shows the candidate has the right files. It does not
show performance, compatibility, security, signing, installation, legal
approval or permission to publish.
