# Source-alpha release procedure

Open LoLa has no automated publish or deployment command. A release is an
explicitly approved source candidate built from a clean revision, and no command
in this document grants publication authority.

## Candidate boundary

The source candidate includes:

- root manifests, lockfiles, license and community files, and maintained public
  documentation;
- `runtimes/**` and `interop/lola2/**`;
- the codec files selected by `Package.swift`, their required headers and
  notices, and `third_party/opus/openlola_bridge/**`; and
- active `tools/**`, `web/demo/**`, and public `.github/**` workflow and assets.

It excludes private, internal, reverse-engineering, and archive material; local
agent and editor state; credentials, captures, runtime reports, caches, build and
package output; and uncompiled vendor tests, training, and build collateral.

`tools/release-boundary-policy.txt` is the executable path authority. The
exporter applies a top-level allowlist and removes unselected vendor material,
and the hygiene checker independently verifies the resulting tree.

## Procedure

1. Freeze an approved clean revision and record its commit ID.
2. Run `make verify` with the pinned macOS, Python, and Rust toolchains.
3. Complete the hardware, peer, security, signing, and distribution gates
   required by the claims being made.
4. Finalize `THIRD_PARTY_NOTICES.md`, the JPEG XS disposition, fixture and corpus
   provenance, and independent clean-room and legal review for that revision.
5. Export outside the checkout:

   ```bash
   bash tools/export-release-candidate.sh /private/tmp/open-lola-release
   ```

6. Verify the exact export:

   ```bash
   OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate \
     bash tools/verify-release-hygiene.sh
   ```

7. Record the candidate hash, toolchain versions, results, review decisions, and
   explicit maintainer approval.
8. Only after separate authorization, create any tag or publication artifact from
   that exact revision.

`OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1` permits an inspection export from a dirty
tree. That export is nonpublishable and cannot become release provenance.

## Vendor boundary

`Package.swift` declares the compiled subsets of `third_party/opus` and
`third_party/jpeg-xs`. First-party Opus integration belongs only under
`third_party/opus/openlola_bridge/`. Any upstream-tree edit requires origin and
patch rationale, notice review, and an updated release decision. JPEG XS remains
evaluation and testing material with unresolved distribution and patent posture;
it is not production-cleared.

Candidate hygiene proves source shape only. It does not establish physical
performance, compatibility, security, signing, installation, legal approval, or
permission to publish.
