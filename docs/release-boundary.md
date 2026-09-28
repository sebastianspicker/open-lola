# Release boundary

Status: active source-alpha boundary
Verdict: PARTIAL

A source candidate is produced from the allowlist in
[release-manifest.md](release-manifest.md), outside the checkout, and scanned
with:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
```

Private evidence, archives, credentials, captures, build output, and
machine-local tool state stay outside the tracked public surface. The path
policy is `tools/release-boundary-policy.txt`.

## Codec boundary

No external SwiftPM package dependencies are declared. The public SwiftPM
package has no bundled Opus or JPEG XS implementation. Raw media paths remain
available; codec-backed selections are rejected before media execution.

## Publication boundaries

- independent clean-room, legal, and publication review;
- an approved clean revision and passing build CI;
- explicit maintainer authorization for any tag, push, or release.

Hardware, field, security, signing, notarization, Gatekeeper, and clean-machine
evidence are additional requirements for product or binary claims.

Candidate hygiene proves only that the staged source shape matches policy. It
does not convert local software checks into field evidence.

VERDICT: PARTIAL
