# Literal-Only Test Inventory

Date: 2026-05-17

Source slice: `SRP-018` in `docs/simplicity-remediation-plan.md`.

Scope: tests called out by `STC-TI-003`: inventory/matrix tests, release
hygiene tests, verification tooling tests, and runtime evidence template tests.
This is an investigation-only inventory. It does not change production code or
tests.

## Classification Rules

- Public contract: keep until an equally explicit public-surface contract
  exists elsewhere.
- Behavior proxy: keep for now because it runs a command, parses a generated
  structure, checks an exit code, or rejects a broken input.
- Replace with behavior: create a follow-up implementation slice before
  deleting or weakening the assertion.
- Removable trivia: delete only after the replacement behavior is in place.

## Candidate Inventory

| Candidate | Current assertion shape | Classification | Follow-up action |
|---|---|---|---|
| `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift:14-37` | Cross-checks `.gitignore`, release manifest, compliance docs, notices, scripts docs, and testing docs with path and substring assertions. | Mixed public contract and replace with behavior. | Keep policy-manifest path checks. Replace free-form doc substring checks with a structured docs verifier rule or a manifest-driven release-boundary docs check. |
| `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift:52-143` | Runs export, hygiene, and docs scripts, then checks exit codes, candidate paths, candidate contents, and visible verdict lines. | Behavior proxy. | Keep. If touched later, parse the script output into explicit fields instead of weakening the command execution. |
| `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift:172-226` | Checks archived plan relocation, Python dependency pins, workflow install snippet, and testing-doc command substrings. | Mixed public contract and replace with behavior. | Keep dependency bounds as public contract. Replace testing-doc command substrings with a workflow/script parity parser that proves the commands execute or are invoked by `verify-release-readiness.sh`. |
| `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift:270-280` | Parses Dockerfile instructions and pins base image digests, checksum verification, and user. | Public security contract. | Keep. A later cleanup can move expected image digests into a release-boundary manifest, but should not remove digest pinning. |
| `Tests/OpenLolaCoreTests/ReleaseArtifactHygieneContractTests.swift:295-396` | Runs release hygiene against clean and contaminated live/candidate roots. | Behavior proxy. | Keep. This is the strongest release-hygiene coverage in this file. |
| `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift:13-74` | Sources `verify-release-readiness.sh`, stubs helper functions, runs `main`, and checks emitted gate calls and verdict lines. | Behavior proxy. | Keep. If simplified later, preserve execution of `main`; do not downgrade to script text checks. |
| `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift:76-88` | Executes `manual_hardware_signing_gate` and checks output boundaries. | Behavior proxy. | Keep; these lines prove manual gates remain visible and do not run the docs gate accidentally. |
| `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift:90-103` | Reads CI workflow YAML and checks literal workflow/security substrings. | Public contract, but replace with behavior when possible. | Follow up with a small workflow parser that validates job permissions, setup steps, and the exact release-readiness command structurally instead of through raw substring checks. |
| `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift:105-163` | Runs JackTrip Docker helper scripts with missing/latest image values and a fake Docker binary. | Behavior proxy. | Keep. These assertions prove failure modes and generated Docker arguments. |
| `Tests/OpenLolaCoreTests/VerificationToolingContractTests.swift:165-213` | Runs the WSL helper with PowerShell when available; otherwise falls back to source-text checks. | Mixed behavior proxy and replace with behavior. | Keep the PowerShell dry-run branch. Follow up with a deterministic fake-`pwsh` or parser path so non-Windows CI does not rely on source-text fallback. |
| `Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift:7-30` | Checks command-template and validator command substrings in the runtime evidence template. | Replace with behavior. | Cross-check command names against `CLICommandInventory` and validator commands against the report validator surface; keep notarization/codesign manual commands as public contract. |
| `Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift:33-41` | Ensures every advertised local runnable surface appears in a command template. | Behavior proxy. | Keep; this connects two fields in the generated report rather than checking an unrelated literal. |
| `Tests/OpenLolaCoreTests/GoalRuntimeEvidenceTemplateTests.swift:45-71` | Rejects false `PASS` and checks validator output. | Behavior proxy. | Keep. |
| `Tests/OpenLolaCoreTests/CLICommandInventoryTests.swift:20-42` | Runs built `open-lola`, decodes command-inventory JSON, and probes `direct-p2p-session-run --help`. | Behavior proxy with public CLI surface literals. | Keep. The option names are intentional CLI contract. If flaky, replace with parser metadata from the executable, not docs strings. |
| `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift:52-99` | Cross-checks schema inventory against validators, fixture groups, smoke commands, file existence, and schema policy text. | Mixed behavior proxy and replace with behavior. | Keep validator/fixture/smoke/file existence checks. Replace `schemaChangePolicy` substring checks with structured policy fields. |
| `Tests/OpenLolaCoreTests/ReportSchemaInventoryTests.swift:101-153` | Checks LoLa UDP/parity schema entries and runs false-pass fixtures through validators. | Behavior proxy. | Keep. False-pass validator execution is the desired replacement pattern. |
| `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift:7-31` | Checks non-empty matrix fields, file existence, and CLI inventory coverage. | Replace with behavior in `SRP-024`. | Keep until `SRP-024` backs matrix rows with executable behavior. Do not delete without CLI/parser/report checks. |
| `Tests/OpenLolaCoreTests/NetworkRouteCommandMatrixTests.swift:34-56` | Checks fastest-evidence eligibility rules over typed matrix fields. | Public contract. | Keep; these are policy assertions, not mere literals. |
| `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift:7-29` | Checks ownership entries have paths and those paths exist. | Public docs/inventory hygiene. | Keep until `SRP-026` classifies the source ownership inventory as contract or docs. |
| `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift:31-73` | Walks `Sources/` and checks ownership resolution, unknowns, and match kinds. | Behavior proxy. | Keep. |
| `Tests/OpenLolaCoreTests/SourceOwnershipInventoryTests.swift:76-150` | Pins selected ownership groups, vendor fences, deferred groups, and CLI registration. | Mixed public contract and `SRP-026` follow-up. | Keep until `SRP-026`; split public ownership policy from cleanup-tracking trivia before editing. |
| `Tests/OpenLolaCoreTests/RealtimeAudioPathInventoryTests.swift:7-45` | Checks realtime path entries, file existence, selected source paths, CLI registration, summary counts, and notes. | Mixed public contract and replace with behavior. | Keep current safety labels. A follow-up should derive critical path coverage from runtime/report tests instead of hand-pinned source paths where possible. |
| `Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift:7-30` | Checks matrix entries, file existence, and CLI registration. | Replace with behavior in `SRP-025`. | Keep until `SRP-025` backs rows with policy tests and executable behavior. |
| `Tests/OpenLolaCoreTests/VideoControlDegradeMatrixTests.swift:34-64` | Checks typed degrade-first and disarmed-control policy fields. | Public contract. | Keep; these assertions encode safety policy. |

## Follow-Up Slice Map

- `SRP-023`: replace report schema inventory duplication and policy text
  substring checks with validator proof and structured policy fields.
- `SRP-024`: back network route matrix rows with executable command/parser/report
  behavior.
- `SRP-025`: back video control degrade matrix rows with policy tests and
  executable behavior.
- `SRP-026`: decide whether source ownership inventory remains a public
  contract or becomes docs-only cleanup guidance.
- New verification-tooling follow-up: replace CI workflow YAML substring checks
  with a minimal workflow parser and replace the PowerShell-unavailable
  source-text fallback with deterministic dry-run coverage.
- New runtime-template follow-up: cross-check template command and validator
  names against active CLI and validator registries while preserving manual
  signing/notarization commands as public contract.
- New release-hygiene-docs follow-up: move free-form docs/matrix substring
  checks into a structured release-boundary docs contract.

## Do Not Remove Yet

- Do not remove release hygiene script execution tests; they are behavior
  coverage.
- Do not remove false-pass fixture validator tests; they are the target pattern.
- Do not remove manual signing, notarization, Gatekeeper, or clean-Mac public
  gate wording until another public contract preserves those gates.
- Do not delete inventory path checks before the related implementation slice
  proves command, parser, validator, or ownership behavior another way.
