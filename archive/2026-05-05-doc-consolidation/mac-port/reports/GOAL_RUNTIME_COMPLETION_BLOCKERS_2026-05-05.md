# GOAL Runtime Completion Blockers

Date: 2026-05-05  
Status: runtime completion audit; physical evidence blocked  
Verdict: PARTIAL

## Objective

This report audits the active `GOAL.md` completion request against real runnable
product behavior. It excludes source contracts, synthetic smokes,
localhost-only tests, and assumed measurements as PASS evidence.

Full real-world PASS requires:

- two real Macs;
- visible multichannel RME MADI or equivalent professional full-duplex audio;
- direct or measured campus route with packet capture;
- Blackmagic/ATEM/DeckLink/UltraStudio capture hardware;
- live OSC or lighting target where those claims are included;
- Developer ID signing identity, notarization, Gatekeeper assessment, and a
  clean-Mac field run.

## Current Local Probe Evidence

The current Mac cannot complete the runtime goal:

| Probe | Command | Result | Runtime implication |
|---|---|---|---|
| Git state | `git status --short` | `fatal: not a git repository` | Evidence is filesystem and command-output based. |
| Core Audio inventory | `.build/debug/open-lola device-inventory` outside the sandbox | Built-in iPhone microphone, DisplayLink StarTech Audio, built-in microphone, and built-in speakers only; no RME/MADI device and no multichannel full-duplex target. | RME MADI TX/RX, routing, low-buffer, RX-profile, drift, and MADI benchmark PASS are blocked. |
| Video inventory | `.build/debug/open-lola video-capture-inventory --output /private/tmp/open-lola-runtime-video-inventory.json` | `permissionStatus: denied`, `devices: []`, `blackmagicSdkStatus: notLinkedOptionalBoundary`, `VERDICT: PARTIAL`. | Blackmagic/ATEM/DeckLink/UltraStudio video PASS is blocked. |
| Video inventory validator | `.build/debug/open-lola validate-video-capture-inventory /private/tmp/open-lola-runtime-video-inventory.json` | `VERDICT: PARTIAL`. | The inventory report shape is valid, but not production video evidence. |
| Signing identities | `security find-identity -v -p codesigning` | One valid Apple Configurator identity; no Developer ID Application or Developer ID Installer identity observed. | Developer ID signing, notarization, stapling, Gatekeeper, and clean-Mac release PASS are blocked. |
| App surface | `.build/debug/open-lola native-app-shell-surface-probe` | Source-level SwiftUI surface report with `VERDICT: PARTIAL`; launched window evidence remains required. | App-shell field PASS is blocked. |

## Latest Local Verification

On 2026-05-05, `bash scripts/verify-release-readiness.sh` failed inside the
sandbox at `swift build` with the known SwiftPM
`sandbox-exec: sandbox_apply: Operation not permitted` manifest error. The same
wrapper passed outside the sandbox.

The unsandboxed release-readiness run covered:

- `bash scripts/verify-docs.sh`;
- `shellcheck scripts/*.sh`;
- `bash scripts/verify-release-hygiene.sh`;
- `swift build`;
- `swift test`, with 742 tests passing;
- release-readiness CLI probes.

The wrapper ended with `VERDICT: PASS` for local source readiness, while still
printing that Developer ID, notarization, Gatekeeper, clean-Mac, hardware, and
benchmark evidence remain manual gates. The GOAL codewise probe stayed
`VERDICT: PASS` with `real-world-verdict: partial`; realtime audio, network,
video-control, and native-app surface probes stayed `VERDICT: PARTIAL`.

## Prompt-To-Artifact Checklist

| GOAL requirement | Required artifact for PASS | Current state | Verdict |
|---|---|---|---|
| Multichannel audio TX/RX works in both directions | Two-Mac RME/MADI inventory, loopback matrix, full-duplex bidirectional report, packet captures, and validators for both directions. | No RME/MADI device and no second Mac visible here. The `madi-full-duplex-run` CLI is a source-level report writer, not a physical Core Audio plus UDP run. | PARTIAL |
| Receiver-side routing/mixing works | RME/MADI multichannel route plus receiver-local mix evidence with channel maps, mix revision, rendered output channels, underrun/overrun counters, and packet-capture correlation. | Source contract exists; no physical RME/MADI route or measured receiver mix report. | PARTIAL |
| Direct P2P setup and UDP media path work | Direct wired sender/receiver route reports, byte-exact loopback pair, packet captures, DSCP read-back, and route diagnostics. | Localhost and source surfaces exist; no two-Mac direct route evidence. | PARTIAL |
| Audio latency, jitter, loss, underruns, overruns measured | Accepted M03/M05/M06/F11 component reports plus latency benchmark and drift/PLC wrapper over real route data. | No accepted hardware route; no 60-minute physical drift/PLC run. | PARTIAL |
| RX buffer modes configurable and benchmarked | Direct, Small, Adaptive, and Stable/WAN reports under identical physical direct and impaired route conditions. | Source policies and synthetic impairment exist; no physical comparison matrix. | PARTIAL |
| Blackmagic/ATEM/DeckLink/UltraStudio video TX/RX works | Production capture inventory, video capture run, physical video transport run, ATEM read-only status, packet capture, and audio-impact comparison. | Video permission denied, no devices, no Blackmagic/ATEM target. | PARTIAL |
| Multiple video runtime supported or staged | Multi-video profile report with at least two measured streams or a staged profile that remains outside fastest audio PASS. | Source-level multi-video negotiation exists; no measured multi-video runtime. | PARTIAL |
| AV timing documented from real runs | Integrated A/V report, E2E benchmark report, and AV timestamp/alignment notes from real two-peer runs. | Source methodology exists; no measured integrated A/V run. | PARTIAL |
| OSC/lighting integration without audio-thread impact | OSC external-peer report, ATEM read-only report, lighting gate report, packet capture, and audio-on/control-on comparison. | Source and bounded PARTIAL handoff reports exist; no live external peer or lighting target. | PARTIAL |
| Packaging, signing, notarization, Gatekeeper, clean-Mac field test | Developer ID signed package, notarization acceptance and stapling, Gatekeeper assessment, clean-Mac app launch, CLI smoke, permissions, media/network access, report writing. | No Developer ID identity visible and no clean Mac available in this workspace. | PARTIAL |

## Required Measurement Commands

All output paths below are templates. Replace bracketed values with measured
hardware, IP, interface, route, and report paths. Do not use TEST-NET addresses,
fixtures, synthetic reports, or localhost reports as PASS evidence.

### 1. Inventory And RME Selection

Run on both Macs:

```bash
.build/debug/open-lola device-inventory > /private/tmp/open-lola-goal-runtime/<mac-id>/core-audio-inventory.json
```

Required report data:

- Mac model, OS build, host name, CPU architecture;
- RME model, driver, firmware, clock source, sample rate, channel layout;
- exact Core Audio input and output UIDs;
- TotalMix or documented public/user-provided routing state when used;
- route label and packet-capture point.

Current blocker: the 2026-05-05 inventory on this Mac shows no RME/MADI target.

### 2. RME Loopback, Low Buffers, And RX Profiles

Run the matrix for 8, 16, 32, 64, and 128 frames where the device reports
support. The 8-frame row must be explicit experimental evidence.

```bash
.build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 32 --channels <madi-channel-count> --sample-format float32 --input-channels <comma-separated-input-indices> --output-channels <comma-separated-output-indices> --latency-profile safeLowLatency --rx-buffer-profile direct --duration-seconds 1800 --output /private/tmp/open-lola-goal-runtime/audio/rme-loopback-48k-32f-direct.json

.build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 16 --channels <madi-channel-count> --sample-format float32 --latency-profile ultraLowLatency16 --rx-buffer-profile direct --duration-seconds 1800 --output /private/tmp/open-lola-goal-runtime/audio/rme-loopback-48k-16f-direct.json

.build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 8 --channels <madi-channel-count> --sample-format float32 --latency-profile extremeLowLatency8 --rx-buffer-profile direct --experimental-8-frame true --duration-seconds 7200 --output /private/tmp/open-lola-goal-runtime/audio/rme-loopback-48k-8f-direct.json
```

Repeat the accepted physical route with each RX profile:

```bash
.build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 32 --channels <madi-channel-count> --sample-format float32 --latency-profile safeLowLatency --rx-buffer-profile small --duration-seconds 1800 --output /private/tmp/open-lola-goal-runtime/audio/rme-loopback-48k-32f-small.json

.build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 32 --channels <madi-channel-count> --sample-format float32 --latency-profile safeLowLatency --rx-buffer-profile adaptive --duration-seconds 1800 --output /private/tmp/open-lola-goal-runtime/audio/rme-loopback-48k-32f-adaptive.json

.build/debug/open-lola audio-loopback-run --input-uid <rme-input-uid> --output-uid <rme-output-uid> --sample-rate 48000 --frames 32 --channels <madi-channel-count> --sample-format float32 --latency-profile safeLowLatency --rx-buffer-profile stableWan --duration-seconds 1800 --output /private/tmp/open-lola-goal-runtime/audio/rme-loopback-48k-32f-stable-wan.json
```

Acceptance notes:

- a single `audio-loopback-run` report is not allowed to emit PASS by design;
- promote the milestone only after the full matrix is compared and a higher
  milestone validator accepts the measured reports;
- built-in speakers, built-in microphones, aggregate devices, and placeholder
  UIDs are not RME/MADI evidence.

### 3. Direct P2P UDP Route And Byte-Exact Loopback

Start packet capture before the media commands.

Mac B receiver:

```bash
sudo tcpdump -i <mac-b-interface> -s 0 -vvv -w /private/tmp/open-lola-goal-runtime/network/mac-b-udp-55448.pcapng 'udp port 55448'

.build/debug/open-lola udp-pcm-route-run --role receiver --bind-host <mac-b-ip> --peer <mac-a-ip> --port 55448 --sample-rate 48000 --frames 32 --channels <channel-count> --duration-seconds 60 --output /private/tmp/open-lola-goal-runtime/network/udp-pcm-route-receiver.json --dscp 46 --route-kind directLink --sender-interface <mac-a-interface> --receiver-interface <mac-b-interface> --capture-point "receiver tcpdump capture" --capture-correlated true --dscp-observed <observed-dscp> --dscp-classification honored --verdict pass
```

Mac A sender:

```bash
sudo tcpdump -i <mac-a-interface> -s 0 -vvv -w /private/tmp/open-lola-goal-runtime/network/mac-a-udp-55448.pcapng 'udp port 55448'

.build/debug/open-lola udp-pcm-route-run --role sender --bind-host <mac-a-ip> --peer <mac-b-ip> --port 55448 --sample-rate 48000 --frames 32 --channels <channel-count> --duration-seconds 60 --output /private/tmp/open-lola-goal-runtime/network/udp-pcm-route-sender.json --dscp 46 --route-kind directLink --sender-interface <mac-a-interface> --receiver-interface <mac-b-interface> --capture-point "sender tcpdump capture" --capture-correlated true --dscp-observed <observed-dscp> --dscp-classification honored --verdict pass
```

Byte-exact loopback pair:

```bash
.build/debug/open-lola udp-pcm-loopback-run --session-id goal-runtime-direct-001 --role looper --bind-host <mac-b-ip> --peer <mac-a-ip> --port 55448 --sample-rate 48000 --frames 32 --channels <channel-count> --duration-seconds 60 --output /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-looper.json --diagnostics on --debug-output /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-looper.jsonl

.build/debug/open-lola udp-pcm-loopback-run --session-id goal-runtime-direct-001 --role sender --bind-host <mac-a-ip> --peer <mac-b-ip> --port 55448 --sample-rate 48000 --frames 32 --channels <channel-count> --duration-seconds 60 --output /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-sender.json --diagnostics on --debug-output /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-sender.jsonl

.build/debug/open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-sender.json
.build/debug/open-lola validate-udp-pcm-loopback-report /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-looper.json
.build/debug/open-lola validate-udp-pcm-loopback-session /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-sender.json /private/tmp/open-lola-goal-runtime/network/udp-pcm-loopback-looper.json
```

Diagnostics:

```bash
.build/debug/open-lola network-diagnostics-run --peer <mac-b-ip> --ping-count 5 --max-hops 8 --output /private/tmp/open-lola-goal-runtime/network/network-diagnostics.json
.build/debug/open-lola validate-network-diagnostics-report /private/tmp/open-lola-goal-runtime/network/network-diagnostics.json
```

### 4. Bidirectional MADI Runtime Report

The current `madi-full-duplex-run` command writes a source-level report from
operator-supplied configuration. It is useful as a report template and
validator input, but it is not physical Core Audio plus UDP media evidence.

Template:

```bash
.build/debug/open-lola madi-full-duplex-run --session-id goal-runtime-madi-001 --local-peer <mac-a-peer-id> --remote-peer <mac-b-peer-id> --local-host <mac-a-ip> --remote-host <mac-b-ip> --port 55448 --sample-rate 48000 --frames 32 --channels <madi-channel-count> --sample-format float32 --duration-packets <packet-count> --input-uid <rme-input-uid> --output-uid <rme-output-uid> --output /private/tmp/open-lola-goal-runtime/audio/madi-full-duplex-mac-a.json

.build/debug/open-lola validate-madi-full-duplex-report /private/tmp/open-lola-goal-runtime/audio/madi-full-duplex-mac-a.json
```

Required before PASS:

- replace the source-level writer with or pair it with physical Core Audio
  capture/render and UDP TX/RX evidence;
- run both peer directions;
- include receiver mix revision, rendered channel count, underruns, overruns,
  late drops, completed blocks, rendered blocks, packet captures, and
  drift/correction fields;
- keep `videoStreamsEnabled` at zero for the fastest audio proof.

### 5. Drift, PLC, Latency, Jitter, Loss, Underruns, And Overruns

After an accepted physical route report exists:

```bash
.build/debug/open-lola drift-plc-run --route-report /private/tmp/open-lola-goal-runtime/network/udp-pcm-route-receiver.json --duration-seconds 3600 --policy boundedSubstitute --artifact-assessment-completed true --artifact-notes "60-minute direct RME/MADI route; artifacts reviewed by operator." --output /private/tmp/open-lola-goal-runtime/audio/drift-plc-60m.json

.build/debug/open-lola validate-drift-plc-report /private/tmp/open-lola-goal-runtime/audio/drift-plc-60m.json
```

Aggregate the benchmark after component reports exist:

```bash
.build/debug/open-lola e2e-benchmark-run --audio-benchmark <latency.json> --integrated-av <integrated-av.json> --video-transport <video-transport.json> --performance-audit <performance.json> --duration-seconds 1800 --output /private/tmp/open-lola-goal-runtime/benchmarks/e2e-audio-av.json

.build/debug/open-lola validate-e2e-benchmark-report /private/tmp/open-lola-goal-runtime/benchmarks/e2e-audio-av.json
```

### 6. Blackmagic/ATEM Capture And Video Transport

Capture inventory:

```bash
.build/debug/open-lola video-capture-inventory --output /private/tmp/open-lola-goal-runtime/video/video-capture-inventory.json
.build/debug/open-lola validate-video-capture-inventory /private/tmp/open-lola-goal-runtime/video/video-capture-inventory.json
```

Production capture run:

```bash
.build/debug/open-lola video-capture-run --device-id <blackmagic-avfoundation-id-or-auto> --duration-seconds 60 --stream-id 100 --queue-depth 1 --frame-rate 60 --baseline-callback-p99-us <audio-baseline-p99> --video-callback-p99-us <audio-with-video-p99> --baseline-callback-max-us <audio-baseline-max> --video-callback-max-us <audio-with-video-max> --baseline-playout-target-frames <baseline-target> --video-playout-target-frames <video-target> --audio-underruns 0 --hidden-audio-impact false --production-hardware atem --production-model <model> --production-manufacturer "Blackmagic Design" --production-connection usb-uvc --desktop-video-sdk-status not-linked --desktop-video-sdk-notes <notes> --verdict pass --output /private/tmp/open-lola-goal-runtime/video/video-capture-production.json

.build/debug/open-lola validate-video-capture-report /private/tmp/open-lola-goal-runtime/video/video-capture-production.json
```

Video route:

```bash
.build/debug/open-lola video-transport-run --mode raw --peer <receiver-ip> --port 5004 --duration-seconds 60 --output /private/tmp/open-lola-goal-runtime/video/video-transport-direct.json --stream-id 100 --source-role atemProgram --width 1920 --height 1080 --pixel-format bgra --frame-rate 60 --queue-depth 1 --max-packet-bytes 1200 --route-kind directWired --packet-capture-point <video-capture-point>

.build/debug/open-lola validate-video-transport-report /private/tmp/open-lola-goal-runtime/video/video-transport-direct.json
```

ATEM read-only status:

```bash
.build/debug/open-lola atem-readonly-probe --host <atem-ip> --port 9910 --timeout-milliseconds 250 --poll-interval-milliseconds 1000 --network-interface <video-or-control-interface> --same-network-as-audio false --output /private/tmp/open-lola-goal-runtime/video/atem-readonly.json

.build/debug/open-lola validate-atem-control-report /private/tmp/open-lola-goal-runtime/video/atem-readonly.json
```

### 7. Integrated A/V And Multi-Video Timing

Use accepted audio, video-capture, video-transport, OSC, and ATEM reports as
inputs. The integrated run must be at least 1,800 seconds for PASS.

```bash
.build/debug/open-lola integrated-av-run --audio-baseline <accepted-audio-report-id> --video-capture on --video-transport on --osc-control on --atem-readonly <atem-ip-or-off> --duration-seconds 1800 --output /private/tmp/open-lola-goal-runtime/av/integrated-av-30m.json

.build/debug/open-lola validate-integrated-av-report /private/tmp/open-lola-goal-runtime/av/integrated-av-30m.json
```

Required report data:

- audio is the master clock;
- A/V overlap seconds cover the run;
- video capture and transport report IDs are non-placeholder;
- packet-capture points are concrete;
- late video drops before audio latency changes;
- audio callback p99/max, playout target, underruns, and route verdict remain
  unchanged with video and multi-video enabled.

### 8. OSC And Lighting Without Audio Impact

OSC external peer:

```bash
.build/debug/open-lola osc-cue-external-run --audio-baseline <accepted-audio-report-id> --port 0 --count 100 --first-external-peer chataigne --external-host <external-osc-host> --external-port <external-osc-port> --external-available true --output /private/tmp/open-lola-goal-runtime/control/osc-external.json

.build/debug/open-lola validate-osc-cue-report /private/tmp/open-lola-goal-runtime/control/osc-external.json
```

Lighting gate:

```bash
.build/debug/open-lola lighting-gate-run --audio-baseline <accepted-audio-report-id> --osc-cue-report <accepted-osc-report-id> --protocol sacn --interop-target qlcPlus --universe <allowed-universe> --network-mode isolatedUnicast --destination <qlc-or-ola-host> --port 5568 --isolated-network true --explicitly-armed true --capture-tool tcpdump --capture-point <lighting-capture-point> --duration-seconds 60 --output /private/tmp/open-lola-goal-runtime/control/lighting-gate.json

.build/debug/open-lola validate-lighting-gate-report /private/tmp/open-lola-goal-runtime/control/lighting-gate.json
```

PASS requires packet capture, an isolated or explicitly approved network,
setup-only fixture metadata, no direct fixture streaming on the performance
link, unchanged audio callback p99/max, unchanged playout target, and zero
audio underruns.

### 9. Native App, Recording, Packaging, And Clean-Mac Field Readiness

Source-level app probe:

```bash
.build/debug/open-lola native-app-shell-surface-probe > /private/tmp/open-lola-goal-runtime/app/native-app-shell-surface-probe.json
```

Runtime handoff from a real integrated report:

```bash
.build/debug/open-lola native-app-runtime-smoke --headless-report /private/tmp/open-lola-goal-runtime/av/integrated-av-30m.json --output /private/tmp/open-lola-goal-runtime/app/native-app-runtime.json
.build/debug/open-lola validate-native-app-shell-report /private/tmp/open-lola-goal-runtime/app/native-app-runtime.json
```

Recording handoff:

```bash
.build/debug/open-lola recording-session-run --integrated-baseline /private/tmp/open-lola-goal-runtime/av/integrated-av-30m.json --duration-seconds 1800 --output-dir /private/tmp/open-lola-goal-runtime/recording/session --report /private/tmp/open-lola-goal-runtime/recording/recording-session.json
.build/debug/open-lola validate-recording-session-report /private/tmp/open-lola-goal-runtime/recording/recording-session.json
```

Field readiness chain:

```bash
.build/debug/open-lola field-readiness-run --integrated-report /private/tmp/open-lola-goal-runtime/av/integrated-av-30m.json --duration-seconds 1800 --output-dir /private/tmp/open-lola-goal-runtime/field-readiness

.build/debug/open-lola validate-native-app-shell-report /private/tmp/open-lola-goal-runtime/field-readiness/m13-native-app-runtime-smoke.json
.build/debug/open-lola validate-recording-session-report /private/tmp/open-lola-goal-runtime/field-readiness/m14-recording-session.json
.build/debug/open-lola validate-packaging-field-report /private/tmp/open-lola-goal-runtime/field-readiness/m15-packaging-field.json
.build/debug/open-lola validate-field-runtime-proof /private/tmp/open-lola-goal-runtime/field-readiness/p05-field-runtime-proof.json
```

Developer ID and clean-Mac proof still require manual distribution commands
outside the current source package:

```bash
security find-identity -v -p codesigning

codesign --force --options runtime --timestamp --sign "Developer ID Application: <team-name> (<team-id>)" --entitlements <entitlements.plist> <Open-LoLa.app>
codesign --force --options runtime --timestamp --sign "Developer ID Application: <team-name> (<team-id>)" <package-dir>/bin/open-lola
codesign --display --verbose=4 <Open-LoLa.app>
codesign --verify --strict --deep --verbose=4 <Open-LoLa.app>

hdiutil create -volname "Open LoLa" -srcfolder <package-dir> -ov -format UDZO /private/tmp/open-lola-goal-runtime/field-readiness/OpenLoLa-<version>.dmg
shasum -a 256 /private/tmp/open-lola-goal-runtime/field-readiness/OpenLoLa-<version>.dmg > /private/tmp/open-lola-goal-runtime/field-readiness/OpenLoLa-<version>.dmg.sha256

xcrun notarytool store-credentials <notarytool-profile> --apple-id <apple-id> --team-id <team-id> --password <app-specific-password>
xcrun notarytool submit /private/tmp/open-lola-goal-runtime/field-readiness/OpenLoLa-<version>.dmg --keychain-profile <notarytool-profile> --wait --output-format json > /private/tmp/open-lola-goal-runtime/field-readiness/notarytool-submit.json
xcrun notarytool info <submission-id> --keychain-profile <notarytool-profile> --output-format json > /private/tmp/open-lola-goal-runtime/field-readiness/notarytool-info.json
xcrun stapler staple /private/tmp/open-lola-goal-runtime/field-readiness/OpenLoLa-<version>.dmg
xcrun stapler validate /private/tmp/open-lola-goal-runtime/field-readiness/OpenLoLa-<version>.dmg

spctl --assess --type open --verbose=4 /private/tmp/open-lola-goal-runtime/field-readiness/OpenLoLa-<version>.dmg
spctl --assess --type execute --verbose=4 <Open-LoLa.app>
```

Required release evidence:

- Developer ID Application signing identity and distribution decision;
- hardened runtime, entitlements, and secure timestamp;
- accepted notarization ticket and stapling for Developer ID release;
- Gatekeeper assessment on the clean Mac;
- SHA-256 package hash before transfer and hash verification after transfer;
- clean-Mac app launch, CLI smoke, permission prompts, media access, network
  access, and report write result.

Clean-Mac probe template:

```bash
shasum -a 256 <received-dmg>
spctl --assess --type open --verbose=4 <received-dmg>
hdiutil attach <received-dmg>
cp -R "/Volumes/Open LoLa/Open LoLa.app" /Applications/
spctl --assess --type execute --verbose=4 "/Applications/Open LoLa.app"
open "/Applications/Open LoLa.app"
"/Volumes/Open LoLa/bin/open-lola" field-readiness-run --integrated-report <accepted-integrated-report> --duration-seconds 1800 --output-dir /private/tmp/open-lola-clean-mac-field-readiness
```

Current blocker: the current keychain inventory shows no Developer ID identity.

## Completion Audit Verdict

The repo has many source-level contracts, validators, fixtures, synthetic
smokes, and bounded PARTIAL report writers. Those are useful preparation, but
they do not complete `GOAL.md` as real product behavior.

The active runtime goal is not achieved because the required hardware, second
Mac, production video device, lighting/control target, Developer ID identity,
notarization path, and clean-Mac field target are not available in this
workspace. Some remaining product behavior also still needs a physical
Core Audio plus UDP runtime proof rather than a source-level report writer.

Resume by making the hardware/signing environment available, then run the
templates above and attach the resulting reports. Keep this report at
`VERDICT: PARTIAL` until every listed requirement has measured evidence.

VERDICT: PARTIAL
