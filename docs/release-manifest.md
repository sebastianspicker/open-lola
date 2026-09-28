# Release manifest

Status: active source-candidate allowlist
Verdict: PARTIAL

## Include

- root manifests, locks, license and community files, and public documentation;
- `runtimes/**`;
- active packaging tools, `web/demo/**`, and public `.github/**` workflows and assets.

## Exclude

- private, internal, reverse-engineering, research, and local archive payloads;
- agent and editor state, credentials, captures, runtime reports, caches, build
  products, packages, and test output;
- test suites, synthetic compatibility corpus, and redistributed upstream
  Opus and JPEG XS source.

The path policy is `tools/release-boundary-policy.txt`. The exporter
copies allowlisted tracked paths and `tools/verify-release-hygiene.sh` checks
the candidate.

## Codec boundary

The public source does not bundle the Opus or JPEG XS implementations. Their
wire and preference values remain recognizable, but codec-backed modes are
unavailable. Raw direct-peer audio and video remain buildable.

Generate an inspection candidate with:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
```

An inspection export from a dirty tree is nonpublishable. Publication requires an
approved clean revision, exact candidate verification, current notices and
provenance, independent review, and explicit maintainer authorization.

VERDICT: PARTIAL
