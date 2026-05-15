# Release Artifact Hygiene

Date: 2026-05-04  
Status: executable C12 artifact/dependency/generated-output hygiene gate  
Milestone: C12  
Verdict: PARTIAL

## Purpose

This document records the release artifact hygiene contract implemented for C12.
The repository checkout is not itself a public release artifact. Release
candidates must be curated exports and must pass the executable hygiene gate:

```bash
bash scripts/verify-release-hygiene.sh
```

To stage an allowlisted source candidate and scan it in one step:

```bash
bash scripts/export-release-candidate.sh /path/to/output-parent
```

To scan a prepared release candidate directory, pass the directory explicitly or
set `OPEN_LOLA_RELEASE_CANDIDATE`:

```bash
bash scripts/verify-release-hygiene.sh /path/to/release-candidate
OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh
```

## Repository Policy Checks

The script verifies that release-boundary files exist and stay aligned:

- `.gitignore`
- `Package.swift`
- `THIRD_PARTY_NOTICES.md`
- `docs/compliance/dependency-license-review.md`
- `docs/compliance/release-manifest.md`
- `docs/review/release-artifact-hygiene.md`

It also verifies that `Package.swift` still has no external SwiftPM package
dependency declarations. If a `.package(...)` dependency is added later, the
script fails until `docs/compliance/dependency-license-review.md` and
`THIRD_PARTY_NOTICES.md` are updated for the exact release contents.

## Release Candidate Exclusions

The C12 gate uses a hard exclusion list for release candidates. The following
paths and file classes must not appear in a candidate archive directory:

| Path or pattern | Reason |
|---|---|
| `.build/**` | SwiftPM generated output. |
| `.swiftpm/**` | SwiftPM workspace state. |
| `DerivedData/**` | Xcode generated output. |
| `win-compiled/**` | Internal Windows binary/static-evidence corpus. |
| `reverse-engineering/**` | Internal reverse-engineering evidence and generated analysis output. |
| `reverse-engineering/evidence-packages/**` | Generated evidence package output. |
| `docs/review/**` | Internal audit/planning material unless explicitly reviewed for publication. |
| `research/deprecated-research/**` | Deprecated research and stale assumptions. |
| `mac-port/reports/**` | Measured or operator-context evidence that requires redaction review. |
| `*.dSYM` | Debug symbols. |
| `*.xcarchive` | Xcode archive output. |
| `*.xcresult` | Xcode result bundles. |
| `*.app` | App bundle output. |
| `*.pkg` | Installer package output. |
| `*.dmg` | Disk image output. |
| `*.ipa` | Apple platform package output. |
| `*.profraw`, `*.profdata` | Coverage/profiling output. |
| `.DS_Store` | Generated macOS metadata. |
| `.env`, `.env.*` except `.env.example` | Local secrets and machine-specific environment files. |
| `*.log`, `*.tmp` | Generated logs and scratch files. |
| `build.db`, `debug.yaml`, `plugin-tools.yaml` | Build/debug metadata from analysis tooling. |
| `*.pcap`, `*.pcapng` | Network captures requiring explicit provenance and redaction review. |

## Release Readiness Integration

The C10 release-readiness entrypoint now runs the C12 hygiene gate:

```bash
bash scripts/verify-release-readiness.sh
```

That means the local and future CI release-readiness matrix fails if the
repository policy drifts. Candidate-directory scanning is also run by
`scripts/export-release-candidate.sh` after it stages the allowlisted source
candidate.

## Remaining Release Blockers

C12 is implemented as an executable hygiene contract, but product release
readiness remains `PARTIAL` until these separate gates are complete:

- final source and documentation license decisions;
- finalized third-party notices for the exact release allowlist;
- fixture provenance signoff;
- reviewer approval for any public `docs/review/**` inclusion;
- signed/notarized/clean-Mac package evidence if binary distribution is planned;
- real hardware and benchmark evidence for field-ready claims.

## Resume Here

Use `bash scripts/export-release-candidate.sh /path/to/output-parent` before
inspecting a source candidate. Do not publish the staged candidate until the
remaining license, notices, reviewer, signing, clean-Mac, hardware, and
benchmark gates close.

VERDICT: PARTIAL
