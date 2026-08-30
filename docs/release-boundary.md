# Release boundary

Status: active source-alpha boundary
Verdict: PARTIAL

The raw checkout is not a release artifact. A source candidate is produced from
the allowlist in [release-manifest.md](release-manifest.md), outside the
checkout, and scanned with:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
OPEN_LOLA_RELEASE_CANDIDATE=/private/tmp/open-lola-release/open-lola-source-candidate \
  bash tools/verify-release-hygiene.sh
```

The repository keeps private evidence, archive payloads, reverse-engineering
material, credentials, captures, build output, caches, and machine-local tool
state outside the tracked/public surface. The canonical path policy is
`tools/release-boundary-policy.txt`.

## Vendor Fence And Patch Policy

No external SwiftPM package dependencies are declared. `Package.swift` compiles a
selected subset of `third_party/opus` and `third_party/jpeg-xs`.
First-party vendor code is limited to
`third_party/opus/openlola_bridge/**`. Changes elsewhere in the upstream trees
require origin/patch rationale, notice review, and an updated release-hygiene
decision.

The Opus notices must accompany a distributed source candidate. The JPEG XS
reference software is evaluation/testing material with unresolved distribution
and patent posture; it is not production-cleared.

## Publication blockers

- exact-tree third-party notice and JPEG XS distribution approval;
- fixture and protocol-corpus provenance review;
- independent clean-room, legal, and publication review;
- an approved clean revision and passing pinned CI;
- explicit maintainer authorization for any tag, push, or release.

Hardware, field, security, signing, notarization, Gatekeeper, and clean-machine
evidence are additional requirements for product or binary claims.

Candidate hygiene proves only that the staged source shape matches policy. It
does not grant publication approval or convert local software checks into field
evidence.

VERDICT: PARTIAL
