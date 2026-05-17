# External Connector NMP Active Use Inventory

Date: 2026-05-17

Remediation slice: `SRP-027`

Source finding: `STC-MC-007`

## Decision

The external connector NMP stack is an active CLI/report verification surface,
not unused scaffolding. It should not be deleted or narrowed as a cleanup-only
change.

NMP remains active because it is routed by the CLI, advertised by the command
inventory, listed in report schema and source ownership inventories, documented
as an active comparison surface, and covered by focused plan/preflight/endpoint
run/workflow tests. No NMP CLI option was classified as unused from the current
evidence.

## Evidence Sources

- CLI run commands are routed in
  `Sources/open-lola/Commands/MilestoneCommands.swift`.
- Validator commands are routed in
  `Sources/open-lola/Commands/Validation/MilestoneValidationCommands.swift`.
- Command inventory rows live in
  `Sources/OpenLolaCore/Support/Inventories/CLICommandInventory.swift`.
- Report schema rows live in
  `Sources/OpenLolaCore/Evidence/ReportSchemaInventory.swift`.
- Source ownership rows live in
  `Sources/OpenLolaCore/Support/Inventories/SourceOwnershipInventory.swift`.
- Active docs classify JackTrip, UltraGrid/MVTP, and NMP as comparison or
  verification contracts in `docs/source-contracts/README.md`.
- App architecture docs keep JackTrip and UltraGrid out of the app-launchable
  path and point them at external connector/NMP contracts in
  `docs/architecture/p2p-networking.md`.
- Focused tests cover the NMP plan, preflight, endpoint run, and workflow in
  `Tests/OpenLolaCoreTests/ExternalConnectorNmp*Tests.swift`, with lower-level
  option behavior covered by `ExternalConnectorConnectionPlanTests`,
  `ExternalConnectorSessionTests`, and related external connector suites.

## Command And Report Surface

| Surface | Classification | Evidence | Notes |
|---|---|---|---|
| `external-connector-nmp-plan-run` | Active runtime and public contract | CLI route, command inventory, schema inventory, plan tests | Builds machine-readable per-connector endpoint plans. |
| `external-connector-nmp-preflight-run` | Active runtime and public contract | CLI route, command inventory, schema inventory, preflight tests | Runs executable preflights embedded in the plan; LoLa is intentionally skipped as an internal connector path. |
| `external-connector-nmp-endpoint-run` | Active runtime and public contract | CLI route, command inventory, schema inventory, endpoint-run tests | Consumes a plan, optionally consumes preflight evidence, and runs selected endpoint sides. |
| `external-connector-nmp-workflow-run` | Active runtime and public contract | CLI route, command inventory, schema inventory, workflow tests | Orchestrates plan, preflight, and endpoint run in one report. |
| `validate-external-connector-nmp-plan` | Active public contract | Validator route, command inventory, schema inventory | Validates `ExternalConnectorNmpPlanReport`. |
| `validate-external-connector-nmp-preflight` | Active public contract | Validator route, command inventory, schema inventory | Validates `ExternalConnectorNmpPreflightReport`. |
| `validate-external-connector-nmp-endpoint-run` | Active public contract | Validator route, command inventory, schema inventory | Validates `ExternalConnectorNmpEndpointRunReport`. |
| `validate-external-connector-nmp-workflow` | Active public contract | Validator route, command inventory, schema inventory | Validates `ExternalConnectorNmpWorkflowReport`. |

## Connector Values

| Value | Classification | Evidence | Notes |
|---|---|---|---|
| `lola` | Active runtime and public contract | Default connector in NMP plan parsing; NMP plan/workflow tests; LoLa raw-link guards | Internal connector path; no external executable preflight is required. |
| `mvtp-ultragrid` | Active comparison contract | NMP plan/preflight/workflow tests; UltraGrid launch/preflight command generation | Side-by-side comparison surface, not an app-launchable default route. |
| `mvtpUltraGrid` | Active public alias | Shared connector parser | Alias for `mvtp-ultragrid`. |
| `ultragrid` | Active public alias | Shared connector parser | Alias for `mvtp-ultragrid`. |
| `jacktrip` | Active comparison contract | NMP plan/preflight/workflow tests; JackTrip endpoint role mapping | JackTrip audio plus auxiliary UltraGrid video when video is requested. |
| `jackTrip` | Active public alias | Shared connector parser | Alias for `jacktrip`. |
| `mtvp-ultragrid` | Explicitly unsupported | NMP plan test rejects the typo alias | Do not preserve this typo without a compatibility requirement. |

## Plan And Workflow Options

These options are accepted by `external-connector-nmp-plan-run` and forwarded by
`external-connector-nmp-workflow-run` unless noted otherwise.

| Option | Classification | Evidence | Notes |
|---|---|---|---|
| `--local-host` | Active runtime and public contract | Required by NMP plan parsing and covered by plan/workflow tests | Seeds local endpoint peer planning. |
| `--remote-host` | Active runtime and public contract | Required by NMP plan parsing and covered by plan/workflow tests | Seeds remote endpoint peer planning. |
| `--output` | Active public contract | Required by plan and workflow parsing | Plan uses it for the emitted plan path; workflow uses it for the top-level report path. |
| `--run-dir` | Active public contract | Plan/workflow parsing and workflow report path generation | Controls subordinate plan, preflight, and endpoint-run artifact locations. |
| `--connectors` | Active public contract | NMP plan/workflow tests cover all three connectors, default LoLa, and invalid typo rejection | Drives per-connector plan generation. |
| `--ultragrid-executable` | Active runtime and public contract | NMP plan/preflight/workflow tests | Overrides UltraGrid executable used by preflight and endpoint execution. |
| `--jacktrip-executable` | Active runtime and public contract | NMP plan/preflight/workflow tests | Overrides JackTrip executable used by preflight and endpoint execution. |
| `--jacktrip-video-executable` | Active runtime and public contract | NMP plan/workflow tests | Overrides the auxiliary UltraGrid video executable for JackTrip video mode. |
| `--media` | Active public contract | NMP plan tests cover `audio-video`; shared parser and lower-level connector tests cover `audio`, `video`, `audioVideo`, and `av` aliases | Connector support limits still apply: UltraGrid does not support audio-only and JackTrip does not support video-only. |
| `--control-transport` | Active public contract | NMP plan parser and lower-level connector tests | NMP applies this to LoLa plans; non-LoLa connectors retain connector defaults. |
| `--duration-seconds` | Active runtime and public contract | NMP parser and lower-level connection/session tests | Controls endpoint process duration. |
| `--channels` | Active public contract | NMP parser and lower-level connection/session tests | Propagates audio channel count into connector plans. |
| `--sample-rate` | Active public contract | NMP parser and lower-level connection/session tests | Optional override; default remains connector-specific. |
| `--frames` | Active public contract | NMP parser and lower-level connection/session tests | Optional frames-per-packet override. |
| `--video-width` | Active public contract | NMP parser and lower-level connection/session tests | Propagates video geometry. |
| `--video-height` | Active public contract | NMP parser and lower-level connection/session tests | Propagates video geometry. |
| `--video-fps` | Active public contract | NMP parser and lower-level connection/session tests | Propagates video frame rate. |
| `--video-bpp` | Active public contract | NMP parser and lower-level LoLa/session tests | Propagates LoLa video bit depth where applicable. |
| `--audio-capture` | Active runtime and public contract | NMP plan tests and lower-level connection tests | Propagates local capture device selection. |
| `--audio-playback` | Active runtime and public contract | NMP plan tests and lower-level connection tests | Propagates receive-side playback selection. |
| `--video-capture` | Active runtime and public contract | NMP plan tests and lower-level connection tests | Propagates local video capture selection. |
| `--video-display` | Active runtime and public contract | NMP plan tests and lower-level connection tests | Propagates receive-side display selection. |
| `--session-id` | Active public contract | NMP parser and lower-level connection/session tests | Propagates LoLa session ID. |
| `--media-packets` | Active runtime and public contract | NMP parser and lower-level raw-link/session tests | Used by LoLa raw-link media TX/RX command generation. |

## Raw-Link Options

| Option | Classification | Evidence | Notes |
|---|---|---|---|
| `--local-raw-link-interface` | Active LoLa runtime contract | NMP plan/workflow tests; raw-link validation in NMP plan | Rejected unless LoLa is selected. |
| `--remote-raw-link-interface` | Active LoLa runtime contract | NMP plan/workflow tests; raw-link validation in NMP plan | Rejected unless LoLa is selected. |
| `--local-mac` | Active LoLa runtime contract | NMP plan/workflow tests; raw-link validation in NMP plan | Rejected unless LoLa is selected. |
| `--remote-mac` | Active LoLa runtime contract | NMP plan/workflow tests; raw-link validation in NMP plan | Rejected unless LoLa is selected. |

## Preflight And Endpoint Options

| Option | Classification | Evidence | Notes |
|---|---|---|---|
| `--plan` | Active public contract | Preflight and endpoint-run parsing; CLI reads validated plan reports | Input plan path for preflight and endpoint stages. |
| `--output` | Active public contract | Preflight and endpoint-run parsing | Output report path for the stage. |
| `--side local` | Active runtime and public contract | Endpoint-run and workflow tests | Runs local endpoint rows only. |
| `--side remote` | Active public contract with indirect NMP coverage | Endpoint selection supports the enum value; `both` tests require remote rows | Add direct NMP coverage before changing remote-only behavior. |
| `--side both` | Active runtime and public contract | Workflow tests | Runs local and remote endpoint rows. |
| `--dry-run` | Active runtime and public contract | Endpoint-run and workflow tests cover dry-run and non-dry failure paths | Overrides endpoint execution mode. |
| `--preflight` | Active CLI contract | Endpoint-run CLI route reads the preflight report and passes it to the runner; workflow tests prove discovered executables feed endpoint execution | The direct `run(configuration:plan:)` overload rejects `preflightPath`; standalone callers must use the CLI route or the overload that accepts the decoded report. |

## Docs-Only Boundary

JackTrip and UltraGrid are documented as unavailable from the app-launchable path
and available only through external connector/NMP contracts. That app boundary
is docs/UI behavior, not evidence that the NMP CLI/report surface is unused.

## Unused Or Stale Surface

No currently accepted NMP CLI option was classified as unused.

The only unsupported value found in this slice is the typo connector alias
`mtvp-ultragrid`, which is intentionally rejected by tests. Do not add
compatibility for it without downstream evidence.

## Follow-Up Guardrails

Any future simplification should be a separate implementation slice and should
first add focused behavior coverage for the option being removed or narrowed.
Useful follow-up tests before changing this surface:

- A direct endpoint-run test for `--preflight` through the file/CLI-style path.
- A direct NMP test for `--side remote`, rather than relying on `both` coverage.
- NMP-specific coverage for media aliases and `--control-transport tcp` if those
  values are narrowed or moved.
- A split between app-not-launchable docs and active CLI comparison contracts if
  the app surface is simplified.

## Verification

Run before marking this investigation complete:

```bash
rg -n "NMP|nmp|ExternalConnectorNmp|external connector" Sources Tests docs scripts linux_connector
swift test --filter ExternalConnector
bash scripts/verify-docs.sh
```
