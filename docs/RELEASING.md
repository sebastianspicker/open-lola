# Source-alpha release procedure

A release is an explicitly approved source candidate built from a clean
revision.

## Candidate boundary

The source candidate includes root manifests, license and community files,
maintained public documentation, both runtimes, packaging tools, the static
demo, and public GitHub assets and workflows. It excludes private material,
tests, the synthetic corpus, redistributed codec source, credentials,
captures, caches, and build output.

`tools/release-boundary-policy.txt` records the path boundary. The exporter
copies allowlisted tracked files and the hygiene checker verifies the staged
tree.

## Procedure

1. Freeze an approved clean revision and record its commit ID.
2. Run `make verify` with the supported macOS and Rust toolchains.
3. Complete the hardware, peer, security, signing, and distribution checks
   required by the claims being made.
4. Review `THIRD_PARTY_NOTICES.md` and independent clean-room and legal
   evidence for that revision.
5. Export outside the checkout:

   ```bash
   bash tools/export-release-candidate.sh /private/tmp/open-lola-release
   ```

6. Verify the exact export with `tools/verify-release-hygiene.sh`.
7. Record the candidate hash, toolchain versions, results, review decisions,
   and explicit maintainer approval.
8. Only after separate authorization, create any tag or publication artifact
   from that exact revision.

`OPEN_LOLA_ALLOW_DIRTY_INSPECTION=1` permits an inspection export from a
dirty tree. That export is nonpublishable and cannot become release provenance.

Candidate hygiene proves source shape only. It does not establish physical
performance, compatibility, security, signing, installation, or legal approval.
