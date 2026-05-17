# Simplification Audit

Date: 2026-05-16
Status: COMPLETE for the source-level simplification pass documented here.

This audit consolidates the live findings from
`docs/deprecation-and-simplification-audit.md` and
`docs/logic-and-correctness-audit.md` into the exact simplification review
shape requested for this task. The broader evidence and command transcripts
remain in those source audit documents and `docs/remediation-ledger.md`.

Scope covered:

- Swift package manifest, active Swift sources, CLI entry points, app support,
  tests, Python Linux connector, scripts, active docs, and release/verifier
  surfaces listed in `docs/code-index.md`.
- Public contracts and compatibility surfaces mapped in
  `docs/architecture-map.md`, including report schemas, CLI command names,
  `OpenLolaContracts`, LoLa compatibility paths, UDP PCM v1/v2, app storage,
  and release/readiness gates.

Scope not fully covered:

- Real hardware audio/video device behavior, Windows LoLa field
  interoperability, signing/notarization, clean-Mac install, and field
  readiness.
- Deep semantic inspection of every SwiftUI component, every realtime callback,
  vendored Opus/JPEG XS internals, and every archived generated artifact.

## Findings

| ID | Category | Location | Evidence | Why it is harmful | What could break if changed | Suggested action | Risk level | Verification needed |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DS-001 | dead code | `linux_connector/lola_connector/backends.py` | `ProcessBackendError` had no in-repo references and was not exported. | Adds unused API surface with no behavior. | External direct imports from `backends.py`. | delete | low | `rg`, ruff, mypy, Python connector pytest. |
| DS-002 | unnecessary abstraction | `linux_connector/lola_connector/backends.py` | `AudioBackend` protocol had no in-repo references; callers use `AudioCapture`/`VideoCapture`. | Makes backend surface look larger than it is. | External direct imports from `backends.py`. | delete | low | `rg`, ruff, mypy, Python connector pytest. |
| DS-003 | stale compatibility | `Sources/OpenLolaCore/Release/LoLaParityDeferredFeatures.swift` | Deprecated `LoLaParityDeferredSyntheticSmoke` delegates to the current fixture API; no active in-repo caller was found. | Preserves an old name that can confuse current release evidence. | External source importing the public deprecated symbol. | investigate | low-medium | source search, release notes/history, `LoLaParityDeferredFeaturesTests`, full Swift build. |
| DS-004 | stale compatibility | Direct P2P audio transport CLI/app/report paths | Hidden `--audio-compression`, `audioCompression`, and stored-default migration are still accepted and tested. | Keeps duplicate parser, report, and settings branches beside `audioTransport`. | Old CLI scripts, user defaults, JSON reports, fixtures, downstream consumers. | keep | medium-high | focused CLI/app/report tests and old-artifact inventory before deletion. |
| DS-005 | stale compatibility | `DirectPeerRealtimeAudioGraphTypes.swift` | Deprecated `audioDeviceUID` still decodes as input/output fallback. | Hides modern explicit input/output device intent in realtime config. | Old JSON configs and callers using one UID. | keep | high | config artifact search, graph tests, AV/session tests, Core Audio smoke. |
| DS-006 | stale compatibility | `linux_connector/lola_connector/cli.py`, `linux_connector/lola_connector/protocol.py`, `linux_connector/lola_connector/connector.py`, `linux_connector/lola_connector/runtime.py` | Python connector still supports `ascii`, `osc15`, and `auto` control dialects. | Keeps a second protocol dialect in the active connector. | LoLa 1.5/tester and archived capture reproduction. | investigate | medium | Python protocol/runtime tests and a fixture or live OSC15 decision. |
| DS-007 | stale compatibility | UDP PCM v1 capability and multichannel fallback paths | Capability output advertises v1/v2 and negotiation still falls back to v1. | Increases protocol surface while current runtime prefers v2. | v1-only peers, fixtures, route tests, capability consumers. | keep | high | multichannel/UDP/fixture tests and compatibility evidence. |
| DS-008 | unnecessary abstraction | `ReportValidatorSurface.swift`, `IntegratedAvReportValidation.swift` | `ReportValidationLifecycle` and `validateLifecycle()` had one adopter. | A one-use protocol hides direct validation order. | Integrated AV validation ordering/errors. | inline | low-medium | `IntegratedAvReportTests`, fixture validation. |
| DS-009 | duplication | CLI command parsers and `KeyValueArgumentParser.swift` | Several commands hand-roll key/value loops although a strict shared parser exists. | CLI error behavior can drift between commands. | Command-specific error text and dash-prefixed value handling. | simplify | medium | shared parser tests, command-specific tests, CLI probes. |
| DS-010 | duplication | `VideoCaptureHelpers.swift`, `ValidationPrimitives.swift`, video reports | Video helpers duplicated primitive non-empty, positive, non-negative, and finite checks. | Two validation styles can drift. | Exact `VideoCaptureValidationError` cases and packet-age semantics. | deduplicate | medium | video report/runner tests and fixture validation. |
| DS-011 | overengineering | milestone/network/validation command routers | Long repeated switch chains dispatch many report commands manually. | Command ownership is hard to audit and easy to desync. | CLI names, stdout, `VERDICT`, app/script calls. | investigate | medium-high | command inventory, schema inventory, release CLI probes. |
| DS-012 | dead code | generated cache paths | `__pycache__`, `.ruff_cache`, `.mypy_cache`, and `.DS_Store` residue make hygiene gates fail. | Generated files are not source and block release hygiene. | Local tool cache speed only. | delete | low | generated-file search and release hygiene. |
| DS-013 | dead code | archived generated reverse-engineering backup files | `~index.bak` files exist under archived Ghidra output. | Adds low-value archive noise. | Forensic traceability if intentionally preserved. | investigate | low | archive provenance, docs verifier, release hygiene. |
| DS-014 | stale compatibility | `OpenLolaContractsAliases.swift` | Public aliases intentionally preserve `OpenLolaCore` import compatibility. | Duplicates contract names across targets. | Existing Swift callers importing `OpenLolaCore` only. | keep | high | full Swift tests and external import/release evidence before removal. |
| DS-015 | misleading name | Direct P2P `Prototype` command/report/schema names | Active command/report contracts still use `Prototype` names by design. | Future cleanup may mistake active contracts for disposable prototype code. | Public commands, report IDs, schema inventory, app/supervisor artifacts. | keep | high | command/schema inventory and compatibility-aware rename plan. |
| DS-016 | duplication | `linux_connector/lola_connector/backends.py` | Process capture/playback/display classes repeated subprocess readiness, stdin, return-code, and cleanup logic. | Cleanup/error fixes could be missed in one backend. | Process cleanup, cancellation, and error text. | deduplicate | medium | process runtime tests, ruff, mypy. |
| LC-001 | unclear state | `AppExecutionController.swift`, `AppLatencyHeroMetrics.swift` | Direct Mac app validation could mark a `.partial` supervisor report as passed. | False-success UI state in a runtime evidence path. | App validation semantics for direct Mac runs. | replace | high | app-shell behavior tests and native app probe. |
| LC-002 | unclear state | `AppExecutionController.swift`, external connector reports | Windows LoLa validation accepted any valid connector report, including `.partial`/`.fail`. | False-success UI state for external endpoint evidence. | App validation semantics for Windows LoLa runs. | replace | high | app-shell Windows LoLa verdict tests and app probe. |
| LC-003 | weak error handling | `DirectP2PTwoPeerLocalRunCommandSupport.swift` | `try? writeAggregatePrototypeReport(...)` discarded aggregate write/load errors. | Operators lose why two-peer evidence became partial. | Two-peer supervisor report notes/output. | replace | medium | focused two-peer report tests and fixture validation. |
| LC-004 | weak error handling | process, LoLa control, raw-link, and UDP media waits | Wait loops used wall-clock `Date()` deadlines. | System clock changes can shorten or stretch bounded waits. | Timeout behavior for process, control, and media waits. | replace | medium | targeted process/LoLa tests and source search for wall-clock patterns. |
| LC-005 | unclear state | `UdpMediaTransport.swift` | Per-stream transit state fed one shared jitter EWMA. | Multi-stream jitter metrics could be contaminated. | Aggregate jitter semantics in UDP media metrics. | simplify | medium | deterministic multi-stream jitter tests. |
| LC-006 | weak error handling | `NetworkDiagnostics.swift` | Ping/traceroute parse and process failures collapsed into nil/default partial data. | Partial reports can omit why data is absent or untrusted. | Optional diagnostic report fields and parser behavior. | replace | low-medium | parser/report tests and fixture validation. |
| LC-007 | duplication | app-shell and contract tests | Some tests asserted file existence or source text instead of behavior. | Tests can stay green while report verdict semantics are wrong. | Test expectations around validation readiness. | simplify | medium | behavior-first app-shell test filters. |
| LC-008 | weak error handling | public runtime constructors in rings/buffers | Some constructors still trap with `precondition` on invalid sizes. | Future unvalidated caller could crash instead of returning validation errors. | Realtime buffer construction contracts. | investigate | high | call-chain audit and targeted runtime tests before changing. |

## Remediation Evidence

The implemented slices recorded in `docs/remediation-ledger.md` completed the
required remediation pass for the confirmed simplification/correctness scope:

- Completed deletion/inlining/deduplication slices: RP-09, RP-10, RP-11, RP-12,
  RP-14.
- Completed high-risk behavior-preservation slices: RP-01 through RP-08.
- Completed compatibility decision slice: RP-13.
- Completed verification blocker cleanup: RP-00.

Deferred or kept items are not silently preserved: DS-003, DS-004, DS-005,
DS-006, DS-007, DS-011, DS-013, DS-014, DS-015, and LC-008 are recorded as
keep/investigate because current evidence shows public API, report, protocol,
runtime, archive, or external-compatibility risk.
