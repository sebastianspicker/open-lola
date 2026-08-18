# Alpha Release Status

Date: 2026-08-14
Proposed identifier: `v0.1.0-alpha.1`
Distribution: source-only alpha candidate
Status: not approved, tagged, or published
Verdict: PARTIAL

This document records the current release boundary. It does not authorize a
commit, tag, push, GitHub release, package, or binary distribution.

## Candidate scope

- SwiftPM and Python package metadata use version `0.1.0`.
- The proposed prerelease identifier applies to the Git tag and release title.
- The candidate is source-only. It does not include a supported `.app`, `.pkg`,
  `.dmg`, or other binary distribution.
- A candidate must be exported from an approved clean revision. The current
  dirty integration checkout is not release provenance.

## Current local evidence

The following evidence was collected from the dirty integration checkout on
2026-08-14. It is local source evidence, not release provenance:

| Gate | Result |
|---|---|
| Swift build, tests, and TSan | Pinned Xcode 26.6 (17F113) and Swift 6.3.3 full serialized Swift run passed 1,660 tests in 8 suites with 0 failures in 172.481 seconds. A separate fresh-scratch TSan run passed `SPSCAtomicRing` (3 tests), `DirectPeerAudioPayloadRing` (4 tests), and `VideoCaptureReport` (13 tests), 20 tests total, with no findings. |
| Locked primary Python suite | 307 tests passed. Ruff, strict mypy, lock checks, documentation, source-documentation, and the connector CLI self-test passed. |
| Standalone Rust compatibility workspace | 252 tests passed, 3 external-oracle tests remained intentionally ignored, and formatting, strict Clippy, the Windows target check, the live Python wire oracle, and both Python-connector directions passed. This is code-only companion evidence and is not part of the curated source candidate. |
| Documentation and source-documentation checks | Passed. |
| Shell and PowerShell | Shell syntax and ShellCheck passed. PSScriptAnalyzer and Pester passed 5 tests. |
| First-party Semgrep | B8 historical evidence only: it completed over 1,076 routed files without analyzer errors. It was not rerun as part of B10. |
| Tracked boundary | Passed. |
| Candidate inspection export | 1,585 allowlisted regular files; aggregate SHA-256 `80942af4f8f1aaac7f77d521e6d706a18f46466ba36d6fdc373fd30d62ac9fe4`; candidate hygiene `PASS`. Provenance is `DIRTY_INSPECTION_ONLY`, so it is nonpublishable. A fresh inspection export after the documentation update also passed hygiene; the full aggregate was not rerun against that documentation-only export. |
| Unified readiness aggregate and probes | The exact wrapper consumed that candidate and exited 0 in 215.65 seconds. `source-gate-verdict` passed; `product-runtime-verdict` and overall readiness remained `PARTIAL`; the headless interactive-app probe was explicitly skipped. |
| Static Signal Desk demo | The dependency-free `site/` artifact passed JavaScript syntax, internal-reference, forbidden-capability, and loopback HTTP checks. It is fixture-only. No browser interaction or GitHub Pages deployment was run. |
| Open-source readiness | `PARTIAL` with 6 blockers. |
| Raw checkout hygiene | Failed because preserved ignored `.DS_Store` and dirty/user residue remain in the integration checkout. |
| Native app smoke | An external ad-hoc app passed strict codesign, Launch Services status 0, process, and visible 1280×840-window checks. Two clean launch attempts reported `accessibilityWindows=0` and `frontmost=false`; screenshot capture failed. Visual and accessibility evidence therefore remains partial, and no accessibility hierarchy is claimed. |
| Product/runtime evidence | Partial. No current physical route, reference-peer, signed distribution, or field evidence was collected. |

See [docs/current-state.md](docs/current-state.md) and
[docs/testing.md](docs/testing.md) for the evidence boundary and commands.

## Publication blockers

Publication remains blocked until all applicable items are complete:

- approve `THIRD_PARTY_NOTICES.md`, including the JPEG XS redistribution
  decision;
- approve fixture provenance and the protocol-documentation boundary;
- complete independent source, clean-room, legal, and release review;
- run the exact candidate through the pinned CI matrix;
- freeze an approved commit and verify the exported tree from that revision;
- obtain explicit maintainer approval before any Git or GitHub publication
  action.

Production, binary, or field-readiness claims additionally require a reviewed
security disposition for unauthenticated direct-peer and LoLa traffic, native
low-latency Linux backends where Linux support is claimed, signing,
notarization, Gatekeeper, clean-Mac, hardware, route, and benchmark evidence.

## Approval checklist

- [x] First-party source and documentation licensed under Apache-2.0; LoLa
  attribution and educational-project boundary recorded in `NOTICE` and
  `LEGAL.md`.
- [ ] Third-party notices and JPEG XS disposition approved.
- [ ] Fixture provenance approved.
- [ ] Name, attribution, and independent-project wording approved.
- [ ] Clean-room and publication review complete.
- [ ] Pinned CI is green for the approved commit.
- [ ] Curated source export passes release hygiene.
- [ ] Maintainer explicitly approves commit, tag, push, and GitHub release.

The release procedure is in [docs/RELEASING.md](docs/RELEASING.md).

VERDICT: PARTIAL
