# Source-alpha release procedure

No command in this document grants publication authority. A release requires
explicit maintainer approval after every gate below succeeds.

1. Freeze an approved clean revision and record its commit ID.
2. Run `make verify` with the pinned macOS, Python, and Rust toolchains.
3. Confirm the manual hardware, peer, security, signing, and distribution gates
   applicable to the claims being made.
4. Finalize `THIRD_PARTY_NOTICES.md`, the JPEG XS disposition, and
   fixture/protocol provenance for the exact candidate.
5. Export outside the checkout:

   ```bash
   bash tools/export-release-candidate.sh /private/tmp/open-lola-release
   ```

6. Verify the exact exported tree:

   ```bash
   OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate \
     bash tools/verify-release-hygiene.sh
   ```

7. Record the candidate hash, toolchain versions, test results, independent
   clean-room/legal review, and maintainer approval.
8. Only after explicit authorization, create the approved tag and publication
   artifacts from that exact revision.

A dirty inspection export may be used for review with
`OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1`, but it is nonpublishable and cannot be
promoted into release provenance.
