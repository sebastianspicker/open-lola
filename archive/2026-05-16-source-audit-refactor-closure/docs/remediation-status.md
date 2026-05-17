# Remediation Status

Source of truth: `docs/refactor-plan.md`
Ledger: `docs/remediation-ledger.md`

## Overall State

COMPLETE

## Current Slice

- Slice: Final verification
- Title: All planned slices complete
- State: COMPLETE
- Priority: Final verification

## Counts By Status

| Status | Count |
| --- | ---: |
| NOT_STARTED | 0 |
| IN_PROGRESS | 0 |
| BLOCKED | 0 |
| DEFERRED | 0 |
| IMPLEMENTED | 0 |
| VERIFIED | 0 |
| COMPLETE | 15 |

## Highest Remaining Priority

None. All planned slices are complete.

## Last Commands And Result

- `sed -n '1,220p' AGENTS.md`: inspected repository rules.
- `sed -n '1,140p' docs/refactor-plan.md`: inspected RP-00 and next high-risk slices.
- `sed -n '1,220p' docs/verification-baseline.md`: confirmed RP-00 blockers.
- `sed -n '1,220p' archive/2026-05-11-reverse-engineering-consolidation/README.md`: inspected broken archived link.
- `rg -n "DS_Store|__pycache__|ruff_cache|mypy_cache|cache" ...`: confirmed failing references and hygiene policy.
- `find . -path './.git' -prune -o -name '__pycache__' -print -o -name '.ruff_cache' -print -o -name '.mypy_cache' -print -o -name '.DS_Store' -print`: found `.ruff_cache`, `.mypy_cache`, and `scripts/verify_docs/__pycache__`.
- `bash scripts/verify-docs.sh`: PASS.
- `PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs`: PASS.
- `python3 -m scripts.verify_docs`: PASS; recreated `scripts/verify_docs/__pycache__`, which was removed before release hygiene.
- `swift test --build-path /private/tmp/open-lola2-rp00 --no-parallel --filter DocsVerifierPolicyTests`: PASS, 4 Swift Testing tests.
- `bash scripts/verify-release-hygiene.sh`: PASS, `VERDICT: PASS`.
- `bash scripts/verify-release-readiness.sh`: sandbox run reached SwiftPM manifest evaluation and failed with the known `sandbox-exec: sandbox_apply: Operation not permitted` policy blocker.
- `bash scripts/verify-release-readiness.sh` outside the sandbox: PASS as a wrapper; ended `VERDICT: PARTIAL`, `source-gate-verdict: pass`, `product-runtime-verdict: partial`.
- `swift test --build-path /private/tmp/open-lola2-rp01 --no-parallel --filter AppShellBehaviorTests`: PASS, 1 Swift Testing scenario.
- `swift test --build-path /private/tmp/open-lola2-rp01 --no-parallel --filter NativeAppShell`: PASS, 10 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp02 --no-parallel --filter 'AppShellBehaviorTests|NativeAppShellWindowsLoLaTests'`: PASS, 5 Swift Testing tests.
- `bash script/build_and_run.sh --verify`: sandbox run failed at known SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest policy.
- `bash script/build_and_run.sh --verify` outside the sandbox: built and launched, then failed accessibility evidence with `missing launched app UI label in accessibility evidence: Operator Plan`.
- `swift test --build-path /private/tmp/open-lola2-rp03 --no-parallel --filter DirectPeerTwoPeerRunPlanTests`: PASS, 1 Swift Testing test.
- `swift test --build-path /private/tmp/open-lola2-rp03 --no-parallel --filter ReportFixtureValidationContractTests`: PASS, 1 Swift Testing test.
- `swift test --build-path /private/tmp/open-lola2-rp04 --no-parallel --filter 'ManagedProcessRunnerTests|DirectPeerTwoPeerRunPlanTests'`: PASS, 3 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp04 --no-parallel --filter AppShellBehaviorTests`: PASS, 1 Swift Testing scenario.
- `rg -n "Date\\(\\)\\.addingTimeInterval|while Date\\(\\) < deadline|timeIntervalSinceNow" <RP-05 files>`: PASS, no affected wall-clock deadline patterns found.
- `swift test --build-path /private/tmp/open-lola2-rp05 --no-parallel --filter 'LoLaCompatibility|ExternalConnectorSessionTests|ExternalConnectorProcessGroupTests'`: PASS, 43 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp05 --no-parallel --filter LoLaUdpMediaSocketTests`: PASS, 3 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp06 --no-parallel --filter UdpMediaTransportTests`: PASS, 7 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp06 --no-parallel --filter 'UdpPcm|PeerSessionAVSupportTests'`: PASS, 8 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp07 --no-parallel --filter NetworkDiagnosticsTests`: initial build failed on Swift optional `flatMap` inference in the stricter parser; rerun PASS, 5 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp07 --no-parallel --filter ReportFixtureValidationContractTests`: PASS, 1 Swift Testing test.
- `swift test --build-path /private/tmp/open-lola2-rp08 --no-parallel --filter 'AppShellSlice05Tests|AppShellBehaviorTests|NativeAppShellWindowsLoLaTests'`: PASS, 11 Swift Testing tests.
- `rg -n "ProcessBackendError|AudioBackend" linux_connector`: PASS, no remaining in-repo references after deletion.
- `RUFF_CACHE_DIR=/private/tmp/open-lola2-rp09-ruff ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: PASS.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-rp09-mypy python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`: PASS, no issues in 22 source files.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`: PASS, 85 passed and 2 skipped.
- `rg -n "ReportValidationLifecycle|validateLifecycle" Sources Tests`: PASS, no remaining lifecycle protocol/helper references.
- `swift test --build-path /private/tmp/open-lola2-rp10 --no-parallel --filter IntegratedAvReportTests`: PASS, 6 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp10 --no-parallel --filter ReportFixtureValidationContractTests`: PASS, 1 Swift Testing test.
- `swift test --build-path /private/tmp/open-lola2-rp11 --no-parallel --filter 'VideoCaptureReportTests|VideoTransportReportTests|VideoTransportRunnerTests'`: PASS, 8 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp11 --no-parallel --filter ReportFixtureValidationContractTests`: PASS, 1 Swift Testing test.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py linux_connector/tests/test_runtime_contracts.py`: PASS, 47 passed and 2 skipped.
- `RUFF_CACHE_DIR=/private/tmp/open-lola2-rp12-ruff ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: PASS.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-rp12-mypy python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`: PASS, no issues in 22 source files.
- `rg -n "audioCompression|--audio-compression|audioDeviceUID|LoLaParityDeferredSyntheticSmoke|udpPcmV1|DirectPeerTwoPeerPrototype|OpenLolaContractsAliases" .`: PASS as evidence search.
- Targeted compatibility `rg` across `Tests/OpenLolaCoreTests/Fixtures`, `Tests/OpenLolaCoreTests`, `Sources`, `README.md`, and `docs`: PASS as evidence search.
- `git log --all --stat -- Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift Sources/open-lola/Commands/Network Sources/OpenLolaCore/Network/P2P`: PASS as evidence search; history is shallow and only shows the broad backup commit for these files.
- `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter KeyValueArgumentParserTests`: PASS, 4 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter DirectPeerTwoPeerRunPlanTests`: PASS, 1 Swift Testing test.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-rp14`: sandbox run failed at known SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest policy.
- `swift build --product open-lola --build-path /private/tmp/open-lola2-rp14` outside the sandbox: PASS.
- `/private/tmp/open-lola2-rp14/debug/open-lola direct-p2p-two-peer-prototype-report --help`: PASS, printed command usage.
- `/private/tmp/open-lola2-rp14/debug/open-lola direct-p2p-two-peer-prototype-report --bad value`: PASS as negative probe, exited 1 with `unknown --bad`.
- `/private/tmp/open-lola2-rp14/debug/open-lola direct-p2p-two-peer-prototype-report --peer-a-report a --peer-a-report b --peer-b-report c --output out`: PASS as negative probe, exited 1 with `duplicate --peer-a-report`.
- `/private/tmp/open-lola2-rp14/debug/open-lola direct-p2p-two-peer-prototype-report --peer-a-report --peer-b-report b --output out`: PASS as negative probe, exited 1 with `missing value for --peer-a-report`.
- `/private/tmp/open-lola2-rp14/debug/open-lola direct-p2p-two-peer-prototype-report --peer-a-report a --peer-b-report --dash --output out`: PASS as negative probe, exited 1 with `missing value for --peer-b-report`.
- `swift test --build-path /private/tmp/open-lola2-rp14 --no-parallel --filter CLICommandInventoryTests`: PASS, 1 Swift Testing test.
- `git diff --stat`: inspected final worktree diff.
- `git diff --name-only`: inspected changed-file inventory for final scope review.
- `find . -path './.git' -prune -o -name '__pycache__' -print -o -name '.ruff_cache' -print -o -name '.mypy_cache' -print -o -name '.DS_Store' -print`: initially found `./.DS_Store` and `./Tests/.DS_Store`; final rerun found no generated residue.
- `rm .DS_Store Tests/.DS_Store`: removed generated Finder residue discovered by final hygiene scan.
- `bash scripts/verify-docs.sh`: PASS.
- `bash scripts/verify-release-hygiene.sh`: PASS, `VERDICT: PASS`.
- `RUFF_CACHE_DIR=/private/tmp/open-lola2-final-ruff ruff check linux_connector scripts/verify_docs scripts/lib/*.py`: PASS.
- `MYPY_CACHE_DIR=/private/tmp/open-lola2-final-mypy python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py`: PASS, no issues in 22 source files.
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector`: PASS, 87 passed and 2 skipped.
- `swift test --build-path /private/tmp/open-lola2-final --no-parallel`: PASS, 458 Swift Testing tests.
- `swift test --build-path /private/tmp/open-lola2-current-completion-2 --no-parallel`: PASS, 461 Swift Testing tests after the final archive-contract and app line-budget cleanup.
- `bash scripts/verify-release-readiness.sh`: sandbox run failed only at known SwiftPM `sandbox-exec: sandbox_apply: Operation not permitted` manifest policy.
- `bash scripts/verify-release-readiness.sh` outside the sandbox: command PASS; source gate PASS; native app launch probe PASS; final wrapper `VERDICT: PARTIAL` because product-runtime/manual evidence gates remain partial.

## Uncertainty

Release readiness still reports manual/product runtime partial gates. That is
expected for this repo and does not block source-level remediation completion.
ThreadSanitizer remains blocked by the host/toolchain policy recorded in
`docs/verification-baseline.md`.
`Tests/OpenLolaCoreTests/AppShellBehaviorTests.swift` already had unrelated
worktree edits before RP-01; RP-01 and RP-02 worked with that current structure.
The RP-02 app surface probe initially exposed a separate UI/evidence failure
around the `Operator Plan` label outside RP-02's validation predicate. The final
release-readiness native app launch probe passed, but product runtime evidence
still remains partial.
RP-03 preserves aggregate failure details in `notes`, not a new structured JSON
field, to avoid a report schema migration.
RP-04 intentionally left LC-004 wall-clock deadlines in LoLa/external connector
runtime paths for RP-05.
RP-05 did not touch NAT or other wall-clock loops outside the named slice files.
RP-06 kept `UdpMediaMetrics.jitterMicroseconds` as one aggregate field; its
policy is now max current per-stream EWMA.
RP-07 added optional `pingError` and `tracerouteError` report fields; fixtures
decode without migration, but consumers need to read the new fields for
structured failure reasons.
RP-08 did not edit `NativeAppShellWindowsLoLaTests.swift`; its existing command
coverage stayed in the verification filter while validation behavior coverage
was strengthened in `AppShellBehaviorTests.swift`.
RP-09 verified no live in-repo uses of the deleted names. External direct imports
from `linux_connector.lola_connector.backends` remain the only compatibility
uncertainty, and the names were not exported from `__init__.py`.
RP-10 keeps Integrated AV validation order unchanged, but the order is now
explicit in `IntegratedAvReport.validate()` instead of hidden behind a one-use
protocol extension.
RP-11 kept video helper function names for stable call sites, but primitive
checks now route through `ValidationPrimitives`; packet-age ordering remains a
video-specific helper.
RP-12 preserves the process backend `start()` seam while reducing repeated
stdout/stdin readiness and cleanup logic under `ProcessLifecycleMixin`.
RP-13 did not change production code. It created
`docs/compatibility-decision-note.md`; only `LoLaParityDeferredSyntheticSmoke`
looks delete-ready in-repo, but deletion is deferred because external use cannot
be ruled out from the available history.
RP-14 changed one command parser. Direct parser-unit coverage is not available
because the parser helper is private to the executable target, so verification
uses shared parser tests plus executable CLI probes for command behavior.

## Next Slice

None. All planned slices are complete; remaining product-runtime gates require
manual/real-world evidence outside this refactor plan.
