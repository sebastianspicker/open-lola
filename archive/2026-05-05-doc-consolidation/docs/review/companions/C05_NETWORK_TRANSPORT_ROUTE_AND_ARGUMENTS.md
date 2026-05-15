# C05 Network Transport Route And Arguments

Date: 2026-05-04  
Status: source-level implementation completed  
Priority: P1  
Verdict: PARTIAL

## Code Evidence

- `NetworkCommands.swift` handles UDP route runs, loopback, diagnostics, NAT
  rendezvous, relay, forwarder, and direct P2P smokes.
- `Sources/OpenLolaCore/UdpPcmRouteRunConfiguration.swift`,
  `UdpPcmLoopbackLatency.swift`, `NatFriendlyRoute.swift`,
  `NatFriendlyRouteHelpers.swift`, and `NetworkDiagnostics.swift` contain
  separate argument parsing helpers and route report contracts.
- Fastest direct-route claims and NAT/WAN-stable claims are different runtime
  modes but live near each other in command handling.
- `NetworkRouteCommandMatrix.swift` now provides an executable command,
  parser, output-report, route-mode, evidence-boundary, and test crosswalk.
- `NatFriendlyRouteReport.validate()` now rejects fastest PASS claims that use
  relay fallback, rendezvous-only mode, missing direct traversal, non-PASS
  nested loopback evidence, or missing raw-route baseline evidence.

## Objective

Clarify network route ownership, reduce parser duplication where it is real,
and keep direct-fastest and NAT/WAN-stable evidence separate.

## Implemented Changes

1. Added `Sources/OpenLolaCore/NetworkRouteCommandMatrix.swift`.
2. Added `open-lola network-route-command-matrix`.
3. Added `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift`.
4. Tightened `NatFriendlyRouteReport.validate()` PASS semantics.
5. Added NAT-friendly invalid-combination tests for rendezvous-only, relay,
   non-PASS loopback, and missing raw-route baseline.
6. Added [../network-route-command-matrix.md](../network-route-command-matrix.md)
   as the human-readable C05 matrix.

## Affected Files

- `Sources/open-lola/NetworkCommands.swift`
- `Sources/OpenLolaCore/UdpPcm*.swift`
- `Sources/OpenLolaCore/UdpMediaTransport.swift`
- `Sources/OpenLolaCore/Nat*.swift`
- `Sources/OpenLolaCore/NetworkDiagnostics.swift`
- `Sources/OpenLolaCore/MacToMacRouteCertification.swift`
- `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift`
- `Tests/OpenLolaCoreTests/NatFriendlyRouteTests.swift`
- [../network-route-command-matrix.md](../network-route-command-matrix.md)

## Improvement Plan

1. Done: route-command matrix now covers command, parser, output report, route
   mode, evidence boundary, representative command, owner source, and tests.
2. Done: direct route evidence contributors are limited to `udp-pcm-route-run`,
   `validate-route-report`, and `validate-route-certification-report`.
3. Done: parser duplication remains local where validation is route-specific;
   no shared parser was introduced because C05 found no safe cross-route helper
   that would reduce complexity without weakening validation.
4. Done: route-mode tests cover NAT relay, rendezvous-only, missing loopback
   PASS, missing raw-route baseline, diagnostics, packet-only, loopback, and
   direct-P2P partial boundaries.
5. Done: the new inventory probe is `open-lola network-route-command-matrix`;
   existing representative route smokes remain covered by the matrix.

## Acceptance Criteria

- Network command ownership is explicit.
- Route reports cannot be misread as faster-than-direct evidence.
- Parser deduplication does not weaken validation.
- Tests cover route mode boundaries.

## Source-Level Result

C05 is implemented as a release-readiness guard, not a product release claim.
The source now exposes a machine-readable route command matrix and rejects
NAT-friendly false PASS combinations. Real direct-route, NAT/WAN, relay,
hardware, and benchmark claims remain `PARTIAL` until measured evidence exists.

## Verification

```bash
swift test --filter NetworkRouteCommandMatrixTests
swift test --filter NatFriendlyRouteTests
swift test
.build/debug/open-lola network-route-command-matrix
.build/debug/open-lola nat-friendly-localhost-smoke
.build/debug/open-lola direct-p2p-localhost-smoke
bash scripts/verify-docs.sh
```

## Resume Here

Continue with
[C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md](C07_VIDEO_CONTROL_DEGRADE_FIRST_PATH.md).

VERDICT: PARTIAL
