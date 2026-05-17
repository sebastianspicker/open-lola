# Compatibility Decision Note

Date: 2026-05-16
Source slice: RP-13 from `docs/refactor-plan.md`

This note records evidence-backed keep/delete/defer decisions for legacy
compatibility paths. It does not change runtime code.

## Evidence Commands

- `rg -n "audioCompression|--audio-compression|audioDeviceUID|LoLaParityDeferredSyntheticSmoke|udpPcmV1|DirectPeerTwoPeerPrototype|OpenLolaContractsAliases" .`
- `rg -n "audioCompression|--audio-compression|audioDeviceUID|LoLaParityDeferredSyntheticSmoke|udpPcmV1|DirectPeerTwoPeerPrototype|OpenLolaContractsAliases" Tests/OpenLolaCoreTests/Fixtures Tests/OpenLolaCoreTests Sources README.md docs --glob '!docs/refactor-plan.md' --glob '!docs/deprecation-and-simplification-audit.md' --glob '!docs/code-index.md' --glob '!docs/testing/test-quality-audit.md'`
- `git log --all --stat -- Sources/OpenLolaCore/Audio/Realtime/DirectPeerRealtimeAudioGraphTypes.swift Sources/open-lola/Commands/Network Sources/OpenLolaCore/Network/P2P`

The git history available in this checkout has one broad backup commit for the
searched files, so it does not prove external compatibility safety by itself.

## Decisions

| Path | Decision | Evidence | Follow-up |
| --- | --- | --- | --- |
| `LoLaParityDeferredSyntheticSmoke` | DEFER deletion | Live source search finds the deprecated public symbol declaration but no active in-repo caller outside audit/archive text. Because it is public and git history is shallow, external imports cannot be ruled out. | If release/API notes confirm no external use, delete the deprecated alias in a dedicated slice and run `LoLaParityDeferredFeaturesTests` plus full fixture validation. |
| `--audio-compression` and `audioCompression` | KEEP for now | Active CLI parsing still accepts hidden `--audio-compression`; tests assert hidden migration behavior and conflict errors. The app still migrates `openLola.audioCompression` to `audioTransport`, and runtime reports still decode/encode legacy `audioCompression`. | Do not delete until a migration horizon is documented and old plans/reports/user defaults are inventoried. |
| `audioDeviceUID` fallback | KEEP for now | The realtime graph configuration marks `audioDeviceUID` deprecated, but tests and runtime/report code still use it as compatibility input. CLI parsing also maps `--audio-device-uid` to explicit input/output UIDs with conflict checks. | Delete only after old JSON configs and CLI callers are migrated to explicit `inputDeviceUID` and `outputDeviceUID`. |
| UDP PCM v1 (`udpPcmV1`) | KEEP | Multichannel transport still negotiates v1 when peers only share v1, capability output advertises v1 and v2, and tests intentionally cover v1 fallback. | Treat as a live wire/protocol contract. Removal needs a separate protocol-version deprecation plan and peer compatibility evidence. |
| `OpenLolaContractsAliases.swift` | KEEP | Public aliases preserve `OpenLolaCore` import compatibility after extracting `OpenLolaContracts`; tests and source ownership inventory explicitly assert this surface. | Delete only with a public API cleanup plan, release notes, and external package import verification. |
| `DirectPeerTwoPeerPrototype*` naming | KEEP / DEFER rename | The prototype report builder, validator, schema inventory, command support, and tests all treat this as the current measured report contract. The name is misleading, but it is active public surface. | Rename only in a compatibility-aware slice with schema/CLI aliases or a documented deprecation path. |

## Summary

Only `LoLaParityDeferredSyntheticSmoke` looks delete-ready from in-repo usage.
The other paths are active compatibility contracts and should not be removed as
cleanup. No production file was changed for this evidence pass.
