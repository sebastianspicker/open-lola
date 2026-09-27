# Alpha release status

Date: 2026-08-27
Proposed identifier: `v0.1.0-alpha.1`
Distribution: source-only alpha candidate
Status: not approved, tagged, or published
Verdict: PARTIAL

The repository has local Swift, Python, Rust, architecture, documentation, shell,
and release-boundary gates, with commands in [docs/testing.md](docs/testing.md).
Local success is not release provenance and does not authorize a commit, tag,
push, GitHub release, package, or binary distribution.

Publication remains blocked by:

- exact-tree third-party and JPEG XS approval;
- fixture and protocol provenance;
- independent clean-room and legal review;
- a pinned CI run from an approved clean revision; and
- explicit maintainer authorization.

Product claims additionally require applicable hardware, real-peer, security,
signing, notarization, Gatekeeper, and clean-machine evidence.

The release procedure is in [docs/RELEASING.md](docs/RELEASING.md), and the exact
source boundary is in [docs/release-manifest.md](docs/release-manifest.md).

VERDICT: PARTIAL
