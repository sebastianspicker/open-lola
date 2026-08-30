# Release manifest

Status: active source-candidate allowlist
Verdict: PARTIAL

## Include

- root manifests, locks, license/community files, and public documentation;
- `runtimes/**` and `Tests/**`;
- `interop/lola2/**`;
- the codec subset selected by `Package.swift`, required upstream headers and
  notices, and `third_party/opus/openlola_bridge/**`;
- active `tools/**`, `web/demo/**`, and public `.github/**` workflow/assets.

## Exclude

- private, internal, reverse-engineering, research, and local archive payloads;
- tool indexes and machine-local agent/editor state;
- credentials, captures, runtime reports, caches, build products, packages, and
  test output;
- uncompiled upstream CI, tests, training, demos, and build-system collateral
  not selected for the candidate.

The executable policy is `tools/release-boundary-policy.txt`. The exporter
starts from an explicit top-level allowlist and then strips unselected vendor
material. `tools/verify-release-hygiene.sh` independently rejects forbidden
items and verifies notices, compiled subsets, and the first-party bridge fence.

## Vendor Fence And Patch Policy

`COpus` compiles the selected Opus sources and the first-party
`third_party/opus/openlola_bridge/**` boundary. `CJpegXSReference` compiles the
selected JPEG XS reference sources. Upstream edits outside the bridge require
origin, patch, and notice review.

Generate an inspection candidate with:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
```

An inspection export from a dirty tree is nonpublishable. Publication requires
an approved clean revision, exact candidate verification, current notices and
provenance, independent review, and explicit maintainer authorization.

VERDICT: PARTIAL
