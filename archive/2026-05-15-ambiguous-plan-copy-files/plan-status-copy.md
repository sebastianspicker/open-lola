# Plan Remediation Status

Status: ACTIVE
Source of truth: `plan.md` and `plan-findings-ledger.md`.
Last updated: 2026-05-14.

Repository note: this checkout currently has no Git metadata. Treat filesystem state, command output, and verification transcripts as the available evidence surface.

## Current Scope

- Total normalized findings: 104
- Closed findings: 104
- Remaining findings: 0
- Remaining P0: 0
- Remaining P1: 0
- Remaining P2: 0

## Current Batch

- Batch: P2 final structure/release/tooling/runtime/UI tranche.
- Batch status: completed for F-089 through F-104. F-098 was already closed and retained as-is. The final tranche removes the pinned source TODO, tightens line budgets/ownership/tooling policy, fixes Python connector payload/TXT contracts, closes Swift Testing discovery gaps, repairs app port persistence and UI state/readability issues, merges video reassembly metrics, and drains diagnostics/preflight process pipes while helpers run.
- Next remediation order: none. All normalized `plan.md` rows are closed; final verification is documented below with a scoped partial verdict because the aggregate Swift suite did not complete.

## Last Verification

- `grep -c '^| F-' plan-findings-ledger.md` -> 104
- `grep -c '| addressed |' plan-findings-ledger.md` -> 103
- `grep -c '| stale |' plan-findings-ledger.md` -> 1
- `grep -c '| open |' plan-findings-ledger.md` -> 0
- `grep -c '| P1 |' plan-findings-ledger.md` -> 46
- `grep -c '| P2 |' plan-findings-ledger.md` -> 58
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS
- `swift test --no-parallel --filter 'DirectPeerRealtimeAudioGraphTests|RealtimeAudioPacketHandoffTests|RealtimeAudioEngineTests|MadiReceiveTests|DirectAudioMediaRouterTests|AppShellSourceContractTests'` -> PASS, 113 tests
- `swift test --no-parallel --filter 'PeerSessionRunnerTests|UdpPcmRouteReportTests|PeerSessionAVSupportTests'` -> PASS, 93 tests
- `swift test --no-parallel --filter 'PeerSessionRunnerTests|UdpPcmRouteReportTests|PeerSessionAVSupportTests|DirectPeerSessionCLITests|NatFriendlyRouteTests'` -> PASS, 132 tests
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-009 through F-012 ledger/status update
- `swift test --no-parallel --filter 'AVTimestampAlignmentTests|PeerSessionAVSupportTests|DirectPeerSessionProductionAVRegressionTests|VideoCaptureReportTests|RecordingSessionArtifactTests|DirectPeerSessionReportAVPassTests'` -> PASS, 112 tests
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-014 through F-016 ledger/status update
- `swift test --no-parallel --filter 'ExternalConnectorProcessGroupTests|ExternalConnectorSessionTests|ExternalConnectorExecutablePreflightTests|ExternalConnectorReportTests'` -> PASS, 49 tests
- `ruff check linux_connector` -> PASS
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest linux_connector` -> PASS, 61 passed and 2 skipped
- `python -m mypy --strict linux_connector/lola_connector` -> PASS
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-017 through F-019 ledger/status update
- `swift test --no-parallel --filter 'AppShellBehaviorTests|AppShellSourceContractTests|NativeAppShellArtifactTests|NativeAppShellTests|NativeAppShellPolicyTests'` -> PASS before the app behavior test split, with current app behavior coverage passing in the F-030/F-078 suite
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-020 through F-024 ledger/status update
- `bash -n scripts/verify-release-hygiene.sh` -> PASS
- `bash -n scripts/verify-release-readiness.sh` -> PASS
- `bash -n scripts/export-release-candidate.sh` -> PASS
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh` -> PASS
- `swift test --no-parallel --filter 'ReleaseArtifactHygieneContractTests|SourceOwnershipInventoryTests'` -> PASS, 20 tests
- `swift test --no-parallel --filter VerificationToolingContractTests` -> PASS, 10 tests
- `bash scripts/export-release-candidate.sh /private/tmp/open-lola-release-candidate-check` -> PASS
- `swift build --target OpenLolaContracts` -> PASS
- `swift test --no-parallel --filter 'OpenLolaContractsTargetTests|SourceOwnershipInventoryTests|ReportSchemaInventoryTests|SessionProtocolTests|RxBufferingTests'` -> PASS, 64 tests
- `PYTHONDONTWRITEBYTECODE=1 python3 -m scripts.verify_docs` -> PASS
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-025, F-026, F-027, F-028, F-029, F-031, F-032, and F-076
- `bash scripts/verify-release-hygiene.sh` -> PASS with `VERDICT: PASS`
- `swift build --product open-lola-app` -> PASS
- `swift build --product open-lola` -> PASS
- `swift test --no-parallel --filter 'AppShellBehaviorTests|AppShellSourceContractTests|AppBundleScriptSourcePolicyTests|CLICommandInventoryTests|DirectPeerSessionCLITests|DirectPeerSessionOpusCLITests|SourceOwnershipInventoryTests'` -> PASS, 41 tests
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-030, F-077, and F-078 ledger/status update
- `bash scripts/verify-release-hygiene.sh` -> PASS with `VERDICT: PASS`
- generated-residue `find` probe excluding `.build`, `archive`, `dist`, and `private` -> clean
- `bash -n script/build_and_run.sh` -> PASS
- `bash -n scripts/verify-release-readiness.sh` -> PASS
- `shellcheck -x script/build_and_run.sh scripts/verify-release-readiness.sh` -> PASS
- `swift test --no-parallel --filter 'AppShellBehaviorTests|NativeAppShellTests|NativeAppShellWindowsLoLaTests|AppShellSourceContractTests|AppBundleScriptSourcePolicyTests|VerificationToolingContractTests'` -> PASS, 56 tests
- `script/build_and_run.sh --verify` with `OPEN_LOLA_APP_LAUNCH_EVIDENCE_DIR=/private/tmp/open-lola-app-launch-evidence` -> NOT RUN; escalation rejected because Accessibility and screenshot capture collect local screen/UI data
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-079, F-080, F-081, and F-088 ledger/status update
- generated-residue `find` probe found Python `__pycache__` residue after docs verification; generated caches were removed
- `bash scripts/verify-release-hygiene.sh` -> PASS with `VERDICT: PASS` after cache cleanup
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py linux_connector/tests/test_process_runtime.py` -> PASS, 85 passed and 2 skipped
- `env RUFF_CACHE_DIR=/private/tmp/open-lola2-ruff-cache ruff check linux_connector` -> PASS
- `env MYPY_CACHE_DIR=/private/tmp/open-lola2-mypy-cache python -m mypy --strict linux_connector/lola_connector` -> PASS
- `PYTHONDONTWRITEBYTECODE=1 python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 --channels 9 connect 127.0.0.2` -> expected FAIL, exit 2 with bounded audio callback block validation before network/runtime startup
- `PYTHONDONTWRITEBYTECODE=1 python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25` -> BLOCKED by local environment; `127.0.0.2` loopback alias is not bound on this Mac
- `swift test --no-parallel --filter 'PeerSessionAVSupportTests|AudioOpusCeltLowDelayPacketTests|AES67ST2110L24TransportTests|DirectPeerSessionReportAVPassTests|PeerSessionRunnerTests|LoLaCompatibilityMediaSessionTests|LoLaUdpMediaSocketTests'` -> PASS, 119 tests
- `swift test --no-parallel --filter 'MadiReceiveTests|MultichannelTransportTests|DirectPeerRealtimeAudioGraphTests|AudioLoopbackRunTests|OpusCELTLowDelayCodecTests|PeerSessionAVSupportTests|MadiFullDuplexSessionTests|RealtimeAudioEngineTests|RxBufferingTests|RealtimeAudioPacketHandoffTests|AudioOpusCeltLowDelayPacketTests'` -> PASS, 233 tests
- `swift test --no-parallel --filter 'UdpMediaTransportTests|PeerSessionAVSupportTests|NatFriendlyRouteTests|PeerSessionRunnerTests|VideoTransportReportTests|LoLaCompatibilityMediaCodecTests|LoLaCompatibilityMediaSessionTests|SessionProtocolTests'` -> PASS, 202 tests
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-042 through F-050 and F-098 ledger/status update
- `swift test --no-parallel --filter 'PackagingFieldTestTests|ExternalConnectorSessionTests|VerificationToolingContractTests|ReleaseArtifactHygieneContractTests|AppBundleScriptSourcePolicyTests'` -> PASS, 83 tests
- `env RUFF_CACHE_DIR=/private/tmp/open-lola2-ruff-plan-051-057 ruff check linux_connector scripts/verify_docs scripts/lib/*.py` -> PASS
- `env MYPY_CACHE_DIR=/private/tmp/open-lola2-mypy-plan-051-057 python -m mypy --strict linux_connector/lola_connector scripts/verify_docs scripts/lib/*.py` -> PASS, 21 source files
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_process_runtime.py linux_connector/tests/test_codec.py` -> PASS, 86 passed and 2 skipped
- `shellcheck -x script/build_and_run.sh scripts/run-local-jacktrip-rxtx-docker.sh scripts/verify-release-readiness.sh scripts/build-local-ultragrid-docker.sh linux_connector/env/*.sh` -> PASS
- `docker build --target build --build-arg ULTRAGRID_SOURCE_SHA256=0000000000000000000000000000000000000000000000000000000000000000 -t open-lola-ultragrid-checksum-negative scripts/ultragrid-docker` -> EXPECTED FAIL at `sha256sum -c -`
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-051 through F-057 ledger/status update
- `swift test --no-parallel --filter 'AppShellBehaviorTests|AppShellSourceContractTests|NativeAppShellTests|NativeAppShellOpusCommandTests'` -> PASS, 46 tests
- `wc -l Sources/open-lola-app/AppShellSettingsView.swift Sources/open-lola-app/AppShellSettingsTabs.swift Sources/open-lola-app/OpenLolaApp.swift Sources/open-lola-app/AppPacketMonitorView.swift` -> 438, 266, 204, and 266 lines respectively
- `swift test --no-parallel --filter CodeLineBudgetTests` -> FAIL on remaining oversized files tracked by open F-069: `PeerSessionAVSupportTests.swift`, `PeerSessionRunnerTests.swift`, `PeerSessionRunner.swift`, `linux_connector/tests/test_codec.py`, `LoLaCompatibilityMediaSessionTests.swift`, and `MadiReceiveTests.swift`
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-058 through F-068 ledger/status update
- `swift test --no-parallel --filter 'CodeLineBudgetTests|PeerSessionAVSupportTests|PeerSessionAVSupportVideoTests|PeerSessionRunnerTests|PeerSessionMetricsAndControlTests|LoLaCompatibilityMediaSessionTests|LoLaCompatibilityRawLinkAndUdpMediaTests|MadiReceiveTests|MadiReceiveSourceAndReportTests'` -> PASS, 120 tests
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py linux_connector/tests/test_runtime_contracts.py` -> PASS, 50 tests
- `env RUFF_CACHE_DIR=/private/tmp/open-lola2-ruff-plan-069 ruff check linux_connector/tests/test_codec.py linux_connector/tests/test_runtime_contracts.py` -> PASS
- `swift test --no-parallel --filter SourceOwnershipInventoryTests` -> PASS, 11 tests
- `bash scripts/verify-release-hygiene.sh` -> PASS with `VERDICT: PASS` after root `.DS_Store` cleanup
- `swift test --no-parallel --filter releaseHygieneNoCandidateModeScansLiveGeneratedResidue` -> PASS
- `swift test --no-parallel --filter 'BoundedFileReaderTests|AppShellBehaviorTests|NativeAppShellArtifactTests|ExternalConnectorSessionTests|RecordingSessionArtifactTests|PackagingFieldTestTests|E2EBenchmarkReportTests|DirectPeerTwoPeerRunPlanTests|NetworkRouteCommandMatrixTests'` -> PASS, 154 tests
- `swift test --no-parallel --filter 'ManagedProcessRunnerTests|AppShellBehaviorTests|ExternalConnectorProcessGroupTests|DirectPeerTwoPeerRunPlanTests|NativeAppShellTests'` -> PASS, 77 tests
- `swift test --no-parallel --filter 'ReleaseArtifactHygieneContractTests|SourceOwnershipInventoryTests'` -> PASS, 22 tests
- `bash scripts/export-release-candidate.sh /private/tmp/open-lola-release-check` -> PASS with candidate and hygiene `VERDICT: PASS`
- `bash -n scripts/export-release-candidate.sh scripts/verify-release-hygiene.sh` -> PASS
- `shellcheck -x scripts/export-release-candidate.sh scripts/verify-release-hygiene.sh` -> PASS
- `swift test --no-parallel --filter CodeLineBudgetTests` -> PASS
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after F-069 through F-074 ledger/status update
- `swift test --no-parallel --filter SourceNamingConventionTests` -> PASS, 3 tests
- `swift test --no-parallel --filter CodeLineBudgetTests` -> PASS after expanded first-party file-class coverage
- `swift test --no-parallel --filter pythonToolingManifestDefinesLintTestAndAsyncioPolicy` -> PASS
- `python -c 'import tomllib; print(tomllib.load(open("pyproject.toml","rb"))["dependency-groups"]["dev"])'` -> PASS, bounded pyproject dev dependencies printed
- `swift test --no-parallel --filter 'NativeAppShellPolicyTests|SwiftTestingDiscoveryTests|SourceOwnershipInventoryTests|PeerSessionAVSupportTests|VideoTransportReportPolicyTests'` -> PASS, 64 tests
- `swift test --no-parallel --filter 'VerificationToolingContractTests|ReleaseArtifactHygieneContractTests'` -> PASS, 20 tests
- `swift test --no-parallel --filter 'AppShellBehaviorTests|AppShellSourceContractTests'` -> PASS, 17 tests
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector/tests/test_codec.py -q` -> PASS, 41 tests
- `RUFF_CACHE_DIR=/tmp/open-lola-ruff-cache ruff check linux_connector scripts/verify_docs scripts/lib/*.py` -> PASS
- `swift test --no-parallel --filter 'PeerSessionAVSupportVideoTests|DirectPeerSessionReportAVPassTests|PeerSessionAVFastestTests'` -> PASS, 31 tests
- `swift test --no-parallel --filter 'NetworkDiagnosticsTests|GoalRuntimePreflightTests'` -> PASS, 17 tests
- `swift test --no-parallel --filter CodeLineBudgetTests` -> PASS after F-103/F-104
- `PYTHONDONTWRITEBYTECODE=1 bash scripts/verify-docs.sh` -> PASS after final F-089 through F-104 ledger/status updates
- `PYTHONDONTWRITEBYTECODE=1 python -m pytest -p no:cacheprovider linux_connector` -> PASS, 88 passed and 2 skipped
- `RUFF_CACHE_DIR=/tmp/open-lola2-ruff-final ruff check linux_connector scripts/verify_docs scripts/lib/*.py` -> PASS
- `shellcheck -x scripts/*.sh scripts/lib/*.sh script/*.sh linux_connector/env/*.sh` -> PASS
- `swift build --product open-lola` -> PASS after sandbox escalation for SwiftPM build writes/locks
- `swift build --product open-lola-app` -> PASS after sandbox escalation for SwiftPM build writes/locks
- `bash scripts/verify-release-readiness.sh` -> PARTIAL: docs, shellcheck, ruff, pytest, mypy, and release hygiene passed before the script hit the local SwiftPM sandbox; rerunning the full script with escalation was rejected because the native app launch probe includes Accessibility UI capture and screenshot capture
- `python -c "import subprocess; subprocess.run(['swift','test','--no-parallel','--filter','NatFriendlyRouteTests'], timeout=180, check=True)"` -> PASS, 27 tests
- `swift test --no-parallel` -> PARTIAL/BLOCKED: the aggregate suite passed a large prefix of tests but went quiet for several minutes around the NAT route tranche and was stopped to avoid leaving a hung verifier; `NatFriendlyRouteTests` passed alone afterward
- `swift test --no-parallel --filter 'NativeAppShell|Network|OpenLola|Opus|Osc|Packaging|PeerSession|Performance|Placeholder'` -> PARTIAL/BLOCKED: Swift Testing filter semantics made the run broad again, and it reproduced the same quiet aggregate hang around the NAT tranche
- `.build/debug/open-lola session-capabilities` -> PASS, emitted JSON and `VERDICT: PASS`
- `.build/debug/open-lola command-inventory` -> PASS/PARTIAL, emitted the command inventory and expected source-level `VERDICT: PARTIAL`
- `bash scripts/verify-release-hygiene.sh` -> PASS with `VERDICT: PASS` after final probes

## Known Blockers And Constraints

- No Git metadata is present in this checkout, so Git status/diff proof is unavailable.
- Real hardware, signing, and cross-machine runtime evidence may remain external unless local hardware is available; source-level and simulated/local checks still remain in scope.
- F-079 actual launched-window evidence remains blocked until the user explicitly approves a macOS app launch plus Accessibility UI capture and screenshot capture; the code-owned verifier path is now present and fail-closed.
- Python connector positive self-test remains blocked until the local `127.0.0.2` loopback alias is available; negative CLI validation and focused runtime tests passed.
- All `plan.md` rows are closed in the ledger. Final completion remains `PARTIAL` because the aggregate Swift suite did not complete in this environment and the full release-readiness app launch evidence path needs explicit user approval.

VERDICT: PARTIAL
