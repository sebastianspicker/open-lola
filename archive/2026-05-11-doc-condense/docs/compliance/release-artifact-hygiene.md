# Release Artifact Hygiene

Date: 2026-05-10
Status: active C12 release hygiene contract after docs and generated-output cleanup
Verdict: PARTIAL

This file is the active release hygiene companion for
[release-manifest.md](release-manifest.md) and
`scripts/verify-release-hygiene.sh`. It replaces the archived review copy under
`archive/2026-05-05-doc-consolidation/docs/review/`.

## Required Exclusions

Release candidates must be produced from an allowlist, not by archiving the raw
checkout. The hygiene gate rejects:

| Path or pattern | Reason |
|---|---|
| `.build/**` | SwiftPM generated build output. |
| `.swiftpm/**` | SwiftPM generated metadata. |
| `DerivedData/**` | Xcode generated output. |
| `win-compiled/**` | Windows binary/vendor evidence corpus. |
| `re_out/**` | Generated reverse-engineering output; archived for traceability only. |
| `reverse-engineering/**` | Internal static evidence and generated analysis. |
| `reverse-engineering/evidence-packages/**` | Generated static-analysis package if a narrowed release excludes only subtrees. |
| `archive/**` | Superseded documentation and review snapshots. |
| `docs/review/**` | Restored legacy review lane; active review contracts now live in compliance, testing, or implementation companions. |
| `research/deprecated-research/**` | Deprecated research snapshots if restored from older trees. |
| `mac-port/reports/**` | Raw report notes or measured context if restored from older trees. |
| `*.dSYM`, `*.xcarchive`, `*.xcresult` | Build/debug artifacts. |
| `*.app`, `*.pkg`, `*.dmg`, `*.ipa` | Package artifacts. |
| `.DS_Store` | macOS generated metadata. |
| `.env`, `.env.*` except `.env.example` | Local secrets or machine-specific config. |
| `*.ssn`, `LolaGui.ini` | LoLa local session/config state that can contain private peer addresses and machine-specific defaults. |
| `*.log`, `*.tmp` | Local runtime noise. |
| `*.pcap`, `*.pcapng` | Packet captures requiring explicit redaction and provenance review. |

## Required Candidate Surfaces

The source candidate must stay testable and match the active public entry
points. The hygiene gate therefore requires `Package.swift`, `pyproject.toml`,
`.github/workflows/release-readiness.yml`, `Sources/**`, `Tests/**`,
`Tests/OpenLolaCoreTests/Fixtures/**`, `linux_connector/**`, `docs/testing/**`,
and `docs/diagrams/**`.

Fixture provenance still blocks public release approval. The C12 gate only
ensures that the candidate does not silently drop the fixtures needed by the
checked test target while claiming artifact hygiene PASS.

## Active Inputs

- [release-manifest.md](release-manifest.md)
- [dependency-license-review.md](dependency-license-review.md)
- [../../THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)
- [../../scripts/export-release-candidate.sh](../../scripts/export-release-candidate.sh)
- [../../scripts/verify-release-hygiene.sh](../../scripts/verify-release-hygiene.sh)

## Verification

```bash
bash scripts/verify-release-hygiene.sh
bash scripts/export-release-candidate.sh /path/to/output-parent
OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh
```

The candidate scan must pass before any archive inspection. Passing C12 does not
approve release: license, notices, fixture provenance, public-documentation
review, implementation audit, reviewer signoff, hardware evidence, benchmark
evidence, signing, notarization, Gatekeeper, and clean-Mac gates remain
separate blockers.

## Resume here

Resume here: keep this file, the release manifest, the export allowlist, and the
shell hygiene gate synchronized whenever the documentation topology changes.

VERDICT: PARTIAL
