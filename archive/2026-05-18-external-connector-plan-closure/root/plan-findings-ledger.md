# UltraGrid and JackTrip Connector Plan Findings Ledger

Source: `plan.md`
Supporting audit: `plan-draft.md`
Generated: 2026-05-18
Goal reference: `GOAL.md`
Verdict: PARTIAL

## Inventory Reconciliation

- Active findings/slices: 14
- P1: 7
- P2: 7
- Done: 13
- Partial: 0
- Open: 0
- Deferred: 1 topology group remains blocked until direct reference-peer parity
  evidence exists.

## Findings

| ID | Priority | Subsystem | Status | Evidence | Remediation required | Verification |
| --- | --- | --- | --- | --- | --- | --- |
| CONN-00 | P1 | Verification trust | done | `ReportSchemaInventoryTests` now passes after release-hardening fixtures and synthetic-smoke generation stopped triggering unrelated private-evidence rejection. | None. | `swift test --filter ReportSchemaInventoryTests` |
| CONN-01 | P1 | Evidence/report contracts | done | External connector source reports now expose `observedEvidenceClasses` and `missingEvidenceClassesForRealWorldPass`, separating synthetic, local loopback, reference-peer, live-device, and field-route evidence. Fixture and validator tests passed. | None for the source-level report contract slice; measured parity evidence remains under CONN-07. | `ExternalConnectorReportTests`, `ReportFixtureValidationContractTests`, `ReportSchemaInventoryTests`, `SyntheticSmokeReportContractTests` |
| CONN-02 | P1 | JackTrip DEFAULT packet correctness | done | Channel sentinels, 16-bit-only validation, redundancy datagram framing, and stop-control accounting are implemented. `swift test --filter JackTripCompatibilityTests` passed with focused codec and runner coverage. | None for this bounded source-level slice. Real JackTrip peer evidence remains covered by CONN-07. | `JackTripCompatibilityTests` |
| CONN-03 | P1 | JackTrip UDP runtime semantics | done | Local UDP receiver tests prove source endpoint learning. Reports expose redundancy recovery, unrecovered gaps, duplicate packets, primary-packet reordering, and explicit network service-class status without promoting QoS evidence. `swift test --filter JackTripCompatibilityTests` passed. | None for this bounded source-level slice. Real reference-peer and route evidence remain under CONN-07. | `JackTripCompatibilityTests` and local UDP receiver coverage |
| CONN-04 | P1 | UltraGrid RTP/MVTP receive analysis | done | Receive analysis now reports RTP loss, duplicate packets, primary-packet reordering, SSRC changes, timestamp regressions, jitter-like timestamp delta changes, and raw-video frame reassembly failures. `swift test --filter UltraGridCompatibilityTests` passed. | None for this bounded receive-analysis slice. FEC/encryption/codec-specific modes remain under CONN-09. | `UltraGridCompatibilityTests` |
| CONN-05 | P2 | UltraGrid generated raw-video sizing | done | Generated UltraGrid video now uses the full configured raw frame byte count and reports audio/video/RTP payload byte counters. A 640x360 RGB frame test covers fragment count and byte-for-byte reassembly. | None for this generated-frame sizing slice. | `UltraGridCompatibilityTests` |
| CONN-06 | P1 | Live media providers | done | JackTrip builders accept injected audio providers, UltraGrid builders accept injected audio/video providers, and focused tests prove deterministic provider bytes reach encoded packets. | Optional CoreAudio/AVFoundation live-device smokes remain separate and must not claim real-world `PASS` without CONN-07 evidence. | `JackTripCompatibilityTests`, `UltraGridCompatibilityTests` |
| CONN-07 | P1 | Reference-peer interoperability | done | `scripts/run-reference-peer-parity-gate.sh` writes machine-readable readiness/command-plan artifacts for Swift-native-to-reference and reference-to-Swift directions, exits `77` with explicit missing prerequisites, and keeps verdict `PARTIAL`. | Actual external peer runs, route capture, live media, and field thresholds remain required before any real-world `PASS`. | `VerificationToolingPairScriptTests` |
| CONN-08 | P2 | App and docs truthfulness | done | Active docs and script index reflect the new connector runtime/report contracts. Focused app-shell tests preserve truthful CLI/planning status for JackTrip and UltraGrid. | Recheck whenever connector public contracts change again. | `AppShellSlice05Tests`, `bash scripts/verify-docs.sh` |
| CONN-09 | P2 | UltraGrid advanced modes | done | FEC, encryption, JPEG/H.264, dynamic payload modes, and advanced control APIs are listed as unsupported, and codec tests prove unsupported RTP payloads fail loud. | Implement any one advanced mode only after public packet evidence and scoped behavior tests exist. | `UltraGridCompatibilityTests` |
| CONN-10 | P2 | UltraGrid NAT/server-client topology | deferred | Current native path is direct peer only, and the reference-peer parity gate still has no measured direct-peer evidence. | Add endpoint-learning or server/client state machine only after direct peer parity passes. | Future local two-process topology tests |
| CONN-11 | P2 | JackTrip hub/TCP/auth modes | done | Hub, TCP handshake, TLS/auth, WebRTC, WebTransport, JACK backend, plugin, JamLink, and empty-header modes are listed as unsupported and covered by fail-loud report/contract tests. | Implement a deferred mode only with explicit scope, handshake fixtures, and public behavior tests. | `JackTripCompatibilityTests` |
| CONN-12 | P2 | JackTrip non-16-bit audio | done | First-slice validation rejects 8-bit, 24-bit, and 32-bit DEFAULT audio packet payloads instead of silently misparsing them. | Implement 8/24/32-bit conversion only with public behavior tests. | `JackTripCompatibilityTests` |
| CONN-13 | P2 | Release hygiene with active root plan docs | done | Release hygiene now allows a complete active root plan bundle in live `/goal` checkouts while rejecting root plan artifacts in release-candidate scans. The focused release hygiene tests and live script pass. | Archive the active root plan bundle when the `/goal` run is no longer active; do not include it in release artifacts. | `ReleaseArtifactHygieneContractTests`, `bash scripts/verify-release-hygiene.sh` |

## Next Finding To Work

No open connector-plan findings remain. Product status stays `PARTIAL` until
measured external peer, route, live media, and field evidence exists.
