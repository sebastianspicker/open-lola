# Current Status Matrix Implementation Companion

Date: 2026-05-11
Status: source-level implementation companion
Verdict: PARTIAL

## Objective

Implement the code-owned part of
[RESEARCH_CURRENT_STATUS_MATRIX_2026.md](RESEARCH_CURRENT_STATUS_MATRIX_2026.md):
make the current research/evidence/reverse-engineering/mac-port crosswalk
machine-readable, validate that every current lane and real-world task is
represented, and keep non-code gates explicit.

## Implemented Now

| Area | Artifact | State |
|---|---|---|
| Typed matrix report | `CurrentEvidenceStatusMatrixReport` in `Sources/OpenLolaCore/Release/CurrentEvidenceStatusMatrix.swift` | DONE |
| Current lane model | `CurrentEvidenceLaneID` covers the 11 current matrix lanes | DONE |
| Real-world task model | `CurrentRealWorldTestID` covers `RWT-001` through `RWT-011` | DONE |
| False-pass guard | Validator rejects `verdict: pass` for this source-level current-status report | DONE |
| CLI output | `open-lola current-evidence-status-matrix` prints the current report | DONE |
| CLI file generation | `open-lola current-evidence-status-matrix-run --output <path>` writes the report | DONE |
| Validator | `open-lola validate-current-evidence-status-matrix-report <path>` validates generated reports | DONE |
| Inventories | CLI command inventory and report schema inventory include the new report and validator | DONE |
| Tests | `CurrentEvidenceStatusMatrixTests` checks coverage, false-pass behavior, JSON round trip, and validator output | DONE |

## Current Source-Level State

The matrix is now represented as code and testable evidence. It maps:

- the current research matrix file,
- the original evidence matrix role,
- the Mac-port open questions,
- the private Windows LoLa validation checklist boundary,
- and the active implementation companion.

The source-level status remains `PARTIAL` because the matrix deliberately
contains real-world gates that cannot be closed by code edits alone.

## Still Missing Before PASS

| Gate | Missing evidence |
|---|---|
| `RWT-001` hardware baseline | Two reference Macs, visible RME MADI hardware, Blackmagic or ATEM identity, route identity, and witness artifacts |
| `RWT-002` Core Audio loopback | Physical RME loopback with accepted latency/callback evidence |
| `RWT-003` two-Mac UDP/P2P | Direct two-Mac sender/receiver reports with packet loss, jitter, and latency measurements |
| `RWT-004` RX buffer profiles | Same-route profile measurements proving no hidden playout growth |
| `RWT-005` PLC and drift | Fixed-target drift/PLC certification against real route and LoLa baseline |
| `RWT-006` network timing and AoIP | DSCP, PTP, AoIP, and same-path route measurements |
| `RWT-007` video | Real Blackmagic or ATEM video path, AV sync, and audio-impact evidence |
| `RWT-008` lighting and show control | Safe OSC/ATEM/lighting probes against isolated real devices |
| `RWT-009` Windows LoLa compatibility | Windows peer TX/RX/control/media evidence for the WV checklist |
| `RWT-010` release and field package | Developer ID signing, notarization, Gatekeeper, clean-Mac install, package hashes, and field run |
| `RWT-011` NAT/ISP route | Non-lab direct/rendezvous/relay measurements and fallback decision evidence |

## Verification Plan

Run:

```sh
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CurrentEvidenceStatusMatrixTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CLICommandInventoryTests --no-parallel
swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ReportSchemaInventoryTests --no-parallel
swift build --build-path /private/tmp/open-lola2-swiftpm-build
/private/tmp/open-lola2-swiftpm-build/debug/open-lola current-evidence-status-matrix-run --output /private/tmp/open-lola-current-evidence-status-matrix.json
/private/tmp/open-lola2-swiftpm-build/debug/open-lola validate-current-evidence-status-matrix-report /private/tmp/open-lola-current-evidence-status-matrix.json
```

## Verification Results

| Check | Result |
|---|---|
| `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CurrentEvidenceStatusMatrixTests --no-parallel` | PASS |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter CLICommandInventoryTests --no-parallel` | PASS |
| `swift test --build-path /private/tmp/open-lola2-swiftpm-build --filter ReportSchemaInventoryTests --no-parallel` | PASS |
| `swift build --build-path /private/tmp/open-lola2-swiftpm-build` | PASS after rerun outside the sandbox; the first sandboxed build failed while SwiftPM compiled the manifest with `sandbox-exec: sandbox_apply: Operation not permitted`. |
| `open-lola current-evidence-status-matrix-run --output /private/tmp/open-lola-current-evidence-status-matrix.json` | PASS; generated report with `VERDICT: PARTIAL`. |
| `open-lola validate-current-evidence-status-matrix-report /private/tmp/open-lola-current-evidence-status-matrix.json` | PASS; validator returned `VERDICT: PARTIAL`. |
| `bash scripts/verify-docs.sh` | PASS |

## Resume Point

After the source-level checks pass, continue with physical real-world testing in
`RWT-001` order. Do not mark release readiness `PASS` until generated reports
from the real hardware, Windows peer, signing/notarization, clean-Mac, and field
runs are attached.

VERDICT: PARTIAL
