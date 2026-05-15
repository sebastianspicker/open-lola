# C10 Verification Tooling And CI Parity

Date: 2026-05-04  
Status: implemented local/CI parity tooling  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- `scripts/verify-docs.sh` is the current non-mutating documentation gate.
- `scripts/verify_docs/*.py` verifies Markdown links, public planning
  contracts, release hardening docs, SOTA matrix coverage, TODO markers, and
  Windows static evidence docs.
- `.github/workflows/release-readiness.yml` now runs the same local release
  readiness script used by maintainers.
- `scripts/verify-release-readiness.sh` now runs the C11 app-shell surface
  probe and the C12 release hygiene gate.
- SwiftPM package gates exist through `swift build` and `swift test`.

## Objective

Make local verification and future CI prove the same release-readiness contract.

## Affected Files

- `scripts/verify-docs.sh`
- `scripts/verify_docs/*.py`
- `Package.swift`
- future `.github/workflows/*`
- release/public boundary docs

## Improvement Plan

1. Define the release-readiness verification matrix in one durable document.
   Done in [../verification-matrix.md](../verification-matrix.md).
2. Add script checks for generated-output leakage if release packaging work
   begins. Done through `scripts/verify-release-hygiene.sh`, which is called by
   `scripts/verify-release-readiness.sh`.
3. Add review/release boundary checks once `docs/review/` policy is decided.
   Partially done: CI cannot upload or publish `docs/review/`, but the final
   publication policy still belongs to C12/release manifest work.
4. Add CI only after the repository is in a Git worktree. Implemented as a
   workflow file in this filesystem snapshot; live CI read-back remains blocked
   because this folder is not currently a Git worktree.
5. Keep hardware/signing gates explicit manual gates unless CI has access to
   real hardware and signing material. Done; the script prints the manual gate
   boundary and does not sign, notarize, package, or publish.

## Acceptance Criteria

- Local verification command set is documented and reproducible. Done.
- Future CI mirrors local gates. Done through one script entrypoint.
- CI cannot publish or upload `.build/`, `win-compiled/`, raw
  `reverse-engineering/`, or unreviewed `docs/review/` content. Done in the
  workflow contract and test.
- Hardware/signing release gates remain manual unless explicitly provisioned.
  Done.

## Implemented Artifacts

- `scripts/verify-release-readiness.sh`
- `scripts/verify-release-hygiene.sh`
- `.github/workflows/release-readiness.yml`
- `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift`
- `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift`
- `docs/review/verification-matrix.md`
- `scripts/README.md`

## Verification

```bash
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
bash scripts/verify-release-hygiene.sh
swift build
swift test
bash scripts/verify-release-readiness.sh
```

## Resume Here

C10 local/CI parity tooling and C12 release artifact hygiene are implemented.
C11 app-shell source tooling is also wired into the parity gate. Live CI
read-back is still not available from this filesystem-only checkout. Keep
signing, notarization, Gatekeeper, clean-Mac, hardware, launched-app, and
benchmark gates manual.

VERDICT: PARTIAL
