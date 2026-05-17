# Simplification Plan

Date: 2026-05-16
Status: COMPLETE for the planned remediation set.
Source audit: `docs/simplification-audit.md`
Implementation ledger: `docs/remediation-ledger.md`

This plan records small, independently reviewable remediation slices for the
overengineering, duplication, dead-code, stale-compatibility, and avoidable
complexity pass. The live implementation status and command results are in
`docs/remediation-ledger.md` and `docs/remediation-status.md`.

Ordering rules used:

1. Fix verification blockers first.
2. Fix false-success, weak-error, and high-risk runtime behavior before cosmetic
   cleanup.
3. Remove clearly unused code only when live references and tests agree.
4. Deduplicate only when duplicate behavior is the same.
5. Inline one-use abstractions before adding any new abstraction.
6. Keep compatibility deletions separate from compatibility evidence.

## Slices

| ID | Title | Findings addressed | Files affected | Exact intended simplification | Behavior affected | Public contracts affected | Tests to add/update | Verification commands | Rollback strategy | Risk level | Definition of Done |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| RP-00 | Restore docs and hygiene verification baseline | DS-012 and baseline failures | docs verifier policy, archived README, generated residue | Remove generated residue and make verifier policy match audit references. | No runtime behavior. | Docs and release hygiene gates. | Docs verifier policy coverage. | `bash scripts/verify-docs.sh`; `python3 -m scripts.verify_docs`; `bash scripts/verify-release-hygiene.sh`; `bash scripts/verify-release-readiness.sh`; focused docs policy test. | Restore archived link/verifier policy if evidence proves it was intentional. | low | Docs and hygiene gates pass or reach only real product-runtime partial blockers. |
| RP-01 | Direct Mac validation requires supervisor PASS evidence | LC-001, LC-007 | app execution metrics/tests | Require pass-level direct supervisor verdict before green app validation. | Prevents partial direct Mac evidence from showing validation passed. | App validation semantics. | Direct partial and pass supervisor report cases. | `swift test --build-path /private/tmp/open-lola2-rp01 --no-parallel --filter AppShellBehaviorTests`; `swift test --build-path /private/tmp/open-lola2-rp01 --no-parallel --filter NativeAppShell`. | Revert predicate and test expectation together. | high | Partial direct supervisor reports cannot produce `.validationPassed`; pass reports still can. |
| RP-02 | Windows LoLa validation requires pass-level connector evidence | LC-002, LC-007 | app execution controller/tests | Require `.pass` external connector verdict before green Windows LoLa validation. | Partial/fail reports remain visible but non-green. | App Windows LoLa validation semantics. | Missing, unreadable, partial, fail, and pass report cases. | `swift test --build-path /private/tmp/open-lola2-rp02 --no-parallel --filter 'AppShellBehaviorTests|NativeAppShellWindowsLoLaTests'`; `bash script/build_and_run.sh --verify`. | Revert predicate and app-shell tests. | high | Only pass-level connector evidence can mark validation passed. |
| RP-03 | Preserve two-peer aggregate failure reasons | LC-003 | two-peer local run command/report/tests | Replace silent `try?` with explicit aggregate failure capture in notes/output. | Partial two-peer evidence explains missing/corrupt aggregate artifacts. | Existing report notes only; no schema migration. | Missing/corrupt aggregate input behavior. | `swift test --build-path /private/tmp/open-lola2-rp03 --no-parallel --filter DirectPeerTwoPeerRunPlanTests`; `swift test --build-path /private/tmp/open-lola2-rp03 --no-parallel --filter ReportFixtureValidationContractTests`. | Revert explicit error capture and test. | medium | Aggregate write/load failures are visible without breaking successful aggregate reports. |
| RP-04 | Replace process wall-clock deadlines | LC-004 | process runner, two-peer command support, tests | Use elapsed monotonic deadlines for process supervision and readiness waits. | Timeout duration becomes stable under wall-clock changes. | Process timeout behavior. | Process timeout/readiness tests. | `swift test --build-path /private/tmp/open-lola2-rp04 --no-parallel --filter 'ManagedProcessRunnerTests|DirectPeerTwoPeerRunPlanTests'`; `swift test --build-path /private/tmp/open-lola2-rp04 --no-parallel --filter AppShellBehaviorTests`. | Restore previous deadline logic in touched files. | medium | Touched process waits no longer compare against wall-clock `Date()`. |
| RP-05 | Replace LoLa control/media wall-clock deadlines | LC-004 | LoLa/external connector wait loops and deadline helper | Centralize bounded waits on a monotonic deadline helper. | Timeout duration becomes stable for LoLa control/media waits. | LoLa compatibility timeout behavior. | Existing LoLa/external connector timeout tests. | `rg -n "Date\\(\\)\\.addingTimeInterval|while Date\\(\\) < deadline|timeIntervalSinceNow" <RP-05 files>`; `swift test --build-path /private/tmp/open-lola2-rp05 --no-parallel --filter 'LoLaCompatibility|ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests'`; `swift test --build-path /private/tmp/open-lola2-rp05 --no-parallel --filter LoLaUdpMediaSocketTests`. | Revert helper and LoLa wait-loop edits. | medium | Named LoLa wait loops use elapsed monotonic deadlines and focused tests pass. |
| RP-06 | Make UDP media jitter stream-aware | LC-005 | `UdpMediaTransport.swift`, tests | Keep jitter EWMA state per stream and expose an explicit max aggregate policy. | Multi-stream jitter no longer overwrites another stream's baseline. | `UdpMediaMetrics.jitterMicroseconds` aggregate policy. | Deterministic multi-stream jitter case. | `swift test --build-path /private/tmp/open-lola2-rp06 --no-parallel --filter UdpMediaTransportTests`; `swift test --build-path /private/tmp/open-lola2-rp06 --no-parallel --filter 'UdpPcm|PeerSessionAVSupportTests'`. | Revert accumulator and test changes. | medium | Interleaved streams cannot contaminate one shared jitter state. |
| RP-07 | Preserve network diagnostics failure reasons | LC-006 | network diagnostics parser/report/tests | Preserve ping/traceroute process and parse errors in optional report fields. | Partial diagnostics explain absent or untrusted data. | Additive optional report fields. | Malformed output, Linux output, process failure, unsupported traceroute. | `swift test --build-path /private/tmp/open-lola2-rp07 --no-parallel --filter NetworkDiagnosticsTests`; `swift test --build-path /private/tmp/open-lola2-rp07 --no-parallel --filter ReportFixtureValidationContractTests`. | Revert parser/schema/test changes. | low-medium | Diagnostic partial reports include the reason data is missing. |
| RP-08 | Replace misleading app validation tests with behavior tests | LC-007 | app shell tests | Remove file-existence-only readiness proof and assert report verdict behavior. | Test behavior only. | App validation contract as encoded by tests. | Invalid JSON, fail, partial, pass, missing path cases. | `swift test --build-path /private/tmp/open-lola2-rp08 --no-parallel --filter 'AppShellSlice05Tests|AppShellBehaviorTests|NativeAppShellWindowsLoLaTests'`. | Revert tests only. | low | Tests fail when malformed reports or wrong verdict semantics regress. |
| RP-09 | Delete proven-dead Python backend declarations | DS-001, DS-002 | `linux_connector/lola_connector/backends.py` | Delete unused exception/protocol and obsolete import. | No in-repo behavior change intended. | Possible external direct imports only. | None unless export docs prove public API. | `rg -n "ProcessBackendError|AudioBackend" linux_connector`; ruff; strict mypy; Python connector pytest. | Restore deleted declarations. | low | No in-repo references remain and Python checks pass. |
| RP-10 | Inline single-use report validation lifecycle | DS-008 | report validator surface, integrated AV validation | Remove one-use lifecycle protocol/helper and call validation steps directly. | No intended behavior change. | Internal validation structure; no schema change. | Existing validation-order/error tests. | `rg -n "ReportValidationLifecycle|validateLifecycle" Sources Tests`; `swift test --build-path /private/tmp/open-lola2-rp10 --no-parallel --filter IntegratedAvReportTests`; `swift test --build-path /private/tmp/open-lola2-rp10 --no-parallel --filter ReportFixtureValidationContractTests`. | Restore protocol and extension. | low-medium | One-use protocol is gone and Integrated AV validation still passes. |
| RP-11 | Deduplicate video validation primitives | DS-010 | validation primitives, video helpers/reports/tests | Route duplicate primitive checks through shared validation helpers while keeping video-specific checks local. | No intended behavior change. | Video validation error behavior. | Empty fields, non-positive sizes, non-finite metrics, counters, packet-age ordering. | `swift test --build-path /private/tmp/open-lola2-rp11 --no-parallel --filter 'VideoCaptureReportTests|VideoTransportReportTests|VideoTransportRunnerTests'`; `swift test --build-path /private/tmp/open-lola2-rp11 --no-parallel --filter ReportFixtureValidationContractTests`. | Restore local primitive helper implementations. | medium | Primitive duplicate logic is removed or reduced and video validation remains covered. |
| RP-12 | Simplify Python process backend lifecycle duplication | DS-016 | Python process backends/tests | Consolidate repeated subprocess readiness, stdin, return-code, and cleanup branches. | No intended behavior change. | Python connector backend runtime behavior and error text. | Early exit, stdout readiness, stdin failure, cleanup, normal termination. | `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py linux_connector/tests/test_runtime_contracts.py`; ruff; strict mypy. | Revert helper extraction and tests. | medium | Repeated lifecycle branches are reduced and process tests pass. |
| RP-13 | Compatibility evidence pass for legacy audio/report names | DS-003, DS-004, DS-005, DS-007, DS-014, DS-015 | docs only | Record keep/delete/defer decisions before any compatibility deletion. | No runtime behavior. | CLI, report, storage, protocol, and public alias decisions. | None; evidence-only. | `rg` for legacy names; targeted fixture/source/doc searches; `git log --all --stat` for relevant surfaces. | Delete or amend decision note if evidence is wrong. | low | Each legacy path has an evidence-backed keep/delete/defer decision. |
| RP-14 | Pilot one CLI parser consolidation | DS-009 | one direct P2P prototype command parser and network command routing | Replace one hand-rolled parser with existing `KeyValueArgumentParser`; do not touch other parsers. | Exact CLI parsing for one command. | Command flags and error text for that command. | Shared parser tests plus CLI probes for help, unknown, duplicate, missing, dash-prefixed value. | `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter KeyValueArgumentParserTests`; `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter DirectPeerTwoPeerRunPlanTests`; `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter CLICommandInventoryTests`; `swift build --product open-lola --build-path /private/tmp/open-lola2-rp14`; focused CLI probes. | Restore the hand-rolled parser for the command. | medium | One parser is simplified and command behavior probes still pass. |

## Deferred Follow-Up Risks

- LC-008 remains a separate runtime constructor audit. Changing traps to typed
  validation in realtime buffer/ring paths needs call-chain proof and targeted
  tests.
- DS-011 remains a future command-router refactor. It is too broad for this
  remediation pass without a separate command-surface migration plan.
- DS-003, DS-004, DS-005, DS-006, DS-007, DS-014, and DS-015 are not deleted
  because they carry public API, storage, report, protocol, or external
  compatibility risk.
- Real hardware, Windows LoLa peer, signing/notarization, clean-Mac install,
  and field-readiness evidence remain outside this source-level simplification
  plan.

## Final Verification For This Wrapper

After creating `docs/simplification-audit.md` and this plan, the docs wrapper
pass ran:

- `bash scripts/verify-docs.sh`: PASS.
- `bash scripts/verify-release-hygiene.sh`: PASS, `VERDICT: PASS`.
- `find . -path './.git' -prune -o -name '__pycache__' -print -o -name '.ruff_cache' -print -o -name '.mypy_cache' -print -o -name '.DS_Store' -print`: PASS, no generated residue printed after removing generated `.DS_Store` files.

The source-remediation verification matrix remains recorded slice-by-slice in
`docs/remediation-ledger.md`, with the final broader results summarized in
`docs/remediation-status.md`: Python ruff/mypy/pytest passed, the final full
Swift Testing refresh passed with 461 tests, release readiness passed as a
wrapper/source gate and ended `VERDICT: PARTIAL` only because
manual/product-runtime evidence remains outside this source-level
simplification scope.
