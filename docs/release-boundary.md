# Release boundary

The raw checkout is not a release artifact. Build a source candidate outside
the checkout from the allowlist in [release-manifest.md](release-manifest.md),
then scan it:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate-<stamp>-<pid> \
  bash tools/verify-release-hygiene.sh
```

Use the directory the exporter prints after `release candidate staged at:`.

Private evidence, archives, reverse-engineering material, credentials, captures,
build output, caches and machine-local tool state stay out of the tracked tree
and the candidate. The path rules live in `tools/release-boundary-policy.txt`.

## Vendor Fence And Patch Policy

No external SwiftPM package dependencies are declared. `Package.swift` compiles a
selected subset of `third_party/opus` and `third_party/jpeg-xs`. First-party
vendor code is limited to `third_party/opus/openlola_bridge/**`. Any change
elsewhere in the upstream trees needs its origin and reason recorded, a notice
review, and a new release-hygiene decision.

A distributed source candidate must include the Opus notices. The JPEG XS
reference software is evaluation and test material; its distribution and patent
status are unresolved, so it is not cleared for production.

## Publication blockers

- third-party notices for the exact tree and approval to distribute JPEG XS;
- provenance review of fixtures and the protocol corpus;
- independent clean-room, legal and publication review;
- an approved clean revision with passing pinned CI;
- maintainer approval for any tag, push or release.

Claims about the product or binaries also need hardware, field, security,
signing, notarization, Gatekeeper and clean-machine results.

A passing hygiene check only shows that the candidate's files match the policy.
It does not approve publication.

VERDICT: PARTIAL
