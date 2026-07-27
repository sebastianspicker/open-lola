# Alpha Release Status

Date: 2026-07-24
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

The following evidence was collected on 2026-07-24:

| Gate | Result |
|---|---|
| Swift build | Passed with Swift 6.2.4 and Xcode 26.3. CI pins Swift 6.3.3 and Xcode 26.6. |
| Swift tests | 1,094 tests passed in a serialized run. |
| Python tests | 147 tests passed with Python 3.11.14 and pytest 8.4.2 from an existing external environment. The locked CI environment was unavailable offline. |
| Python type checking | Passed for 25 source files with locally installed mypy 2.3.0. CI pins mypy 1.14.1. |
| Documentation and source-documentation checks | Passed. |
| Tracked-boundary and release-hygiene checks | Passed. |
| ShellCheck | Passed for repository shell scripts. |
| Locked Python environment | Not recreated offline because the locked `ruff==0.15.20` wheel was absent from the local cache. |
| Ruff | Ruff 0.16.0 reported 50 lint findings in the dirty checkout. |
| Product/runtime evidence | Partial. No current physical route, reference-peer, distribution, or field evidence was collected. |

See [docs/current-state.md](docs/current-state.md) and
[docs/testing.md](docs/testing.md) for the evidence boundary and commands.

## Publication blockers

Publication remains blocked until all applicable items are complete:

- replace the current no-license notice with approved source and documentation
  license text;
- approve `THIRD_PARTY_NOTICES.md`, including the JPEG XS redistribution
  decision;
- approve fixture provenance and the protocol-documentation boundary;
- complete independent source, clean-room, legal, and release review;
- run the exact candidate through the pinned CI matrix;
- freeze an approved commit and verify the exported tree from that revision;
- obtain explicit maintainer approval before any Git or GitHub publication
  action.

Binary or field-readiness claims additionally require signing, notarization,
Gatekeeper, clean-Mac, hardware, route, and benchmark evidence.

## Approval checklist

- [ ] Source and documentation licenses approved.
- [ ] Third-party notices and JPEG XS disposition approved.
- [ ] Fixture provenance approved.
- [ ] Name, attribution, and independent-project wording approved.
- [ ] Clean-room and publication review complete.
- [ ] Pinned CI is green for the approved commit.
- [ ] Curated source export passes release hygiene.
- [ ] Maintainer explicitly approves commit, tag, push, and GitHub release.

The release procedure is in [docs/RELEASING.md](docs/RELEASING.md).

VERDICT: PARTIAL
