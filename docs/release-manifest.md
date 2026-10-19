# Release manifest

What goes into a source candidate. The exporter and hygiene checker enforce
this list.

## Include

- root manifests, lockfiles, license and community files, and public
  documentation;
- `runtimes/**`;
- `interop/lola2/**`;
- the codec subset selected by `Package.swift`, the required upstream headers
  and notices, and `third_party/opus/openlola_bridge/**`;
- active `tools/**`, `web/demo/**`, and public `.github/**` workflows and
  assets.

## Exclude

- private, internal, reverse-engineering, research and local archive material;
- tool indexes and machine-local editor and tool state;
- credentials, captures, runtime reports, caches, build products, packages and
  test output;
- upstream CI, tests, training data, demos and build-system files that are not
  compiled into the candidate.

The path rules live in `tools/release-boundary-policy.txt`. The exporter starts
from a top-level allowlist and then strips unselected vendor material.
`tools/verify-release-hygiene.sh` separately rejects forbidden items and checks
notices, compiled subsets and the bridge fence.

## Vendor Fence And Patch Policy

`COpus` compiles the selected Opus sources and the first-party
`third_party/opus/openlola_bridge/**` code. `CJpegXSReference` compiles the
selected JPEG XS reference sources. Any upstream edit outside the bridge needs
origin, patch and notice review.

To generate an inspection candidate:

```bash
bash tools/export-release-candidate.sh /private/tmp/open-lola-release
```

An export from a dirty tree must not be published. Publication needs an
approved clean revision, verification of that exact candidate, current notices
and provenance, independent review, and maintainer approval. See
[RELEASING.md](RELEASING.md).

VERDICT: PARTIAL
