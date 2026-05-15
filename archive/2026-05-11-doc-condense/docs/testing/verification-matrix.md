# Verification Matrix

Date: 2026-05-11
Status: active verification matrix after docs cleanup
Verdict: PARTIAL

This file records the active local checks for this filesystem-only checkout.
Superseded review matrices and remediation ledgers are archived under
`archive/**`; they are trace evidence, not current verification authority.

## Local Gates

| Gate | Command | Expected result |
|---|---|---|
| Documentation | `bash scripts/verify-docs.sh` | Active docs, topology, links, public boundary, SOTA matrix, and archive indexes pass. |
| Shell | `shellcheck -x scripts/*.sh scripts/lib/*.sh` | All shell scripts and shared shell libraries are clean. |
| Python lint | `ruff check .` | Python source, tests, and helper scripts pass the repo `pyproject.toml` lint policy. |
| Python tests | `python -m pytest` | Linux connector tests pass from the repo root. |
| Python connector typing | `python -m mypy --strict linux_connector/lola_connector` | Production Linux connector package type-checks under strict mypy. |
| Release hygiene | `bash scripts/verify-release-hygiene.sh` | Repository policy and release-boundary docs are synchronized. |
| Candidate hygiene | `OPEN_LOLA_RELEASE_CANDIDATE=/path/to/release-candidate bash scripts/verify-release-hygiene.sh` | Staged candidates exclude generated, internal, archive, and vendor artifacts. |
| Swift build | `swift build` | Build passes outside the sandbox when SwiftPM manifest sandboxing is blocked. |
| Swift tests | `swift test --no-parallel` | Source, fixture, CLI, release hygiene, and docs contract tests pass without socket-heavy parallel-suite interference. |
| Release readiness | `bash scripts/verify-release-readiness.sh` | Docs, shellcheck, Python lint/tests/strict typing, hygiene, bounded Swift build/test, GOAL closure, open-source readiness preflight, and CLI probes pass where host permissions allow. |

CI parity is defined in
[../../.github/workflows/release-readiness.yml](../../.github/workflows/release-readiness.yml).
The workflow runs the same release-readiness script and must not publish or
upload artifacts.

## Connector Process Probes

Use the connector process probes only when the relevant local dependency is
available. They produce local process evidence and `PARTIAL` validation reports;
they do not prove physical bidirectional audio/video timing.

| Probe family | Detailed procedure |
|---|---|
| JackTrip Docker and local RX/TX parity | [../../scripts/README.md](../../scripts/README.md#local-jacktrip-docker-helpers) |
| UltraGrid Docker, native UltraGrid, and parity stress | [../../scripts/README.md](../../scripts/README.md#local-ultragrid-docker-helpers) |
| Release/documentation gates | [../../scripts/README.md](../../scripts/README.md#verify-release-readinesssh) and [../../scripts/README.md](../../scripts/README.md#verify-docssh) |

Representative connector surface probes:

```bash
.build/debug/open-lola external-connector-synthetic-smoke
.build/debug/open-lola external-connector-executable-preflight-run --output /private/tmp/open-lola-external-connector-executable-preflight.json
.build/debug/open-lola validate-external-connector-executable-preflight-report /private/tmp/open-lola-external-connector-executable-preflight.json
.build/debug/open-lola external-connector-nmp-workflow-run --local-host 127.0.0.1 --remote-host 127.0.0.2 --output /private/tmp/open-lola-nmp-workflow/workflow.json --side both --dry-run true --connectors lola,mtvp-ultragrid,jacktrip --audio-capture coreaudio --audio-playback coreaudio --video-capture testcard:1920:1080:30:RGB --video-display gl --local-raw-link-interface en10 --remote-raw-link-interface en11 --local-mac 02:00:00:00:00:0a --remote-mac 02:00:00:00:00:0b
.build/debug/open-lola validate-external-connector-nmp-workflow /private/tmp/open-lola-nmp-workflow/workflow.json
```

## Release And Goal Probes

Run focused probes after relevant source or release-surface changes:

```bash
.build/debug/open-lola device-inventory
.build/debug/open-lola udp-pcm-localhost-smoke
.build/debug/open-lola video-capture-inventory --output /private/tmp/open-lola-video-inventory.json
.build/debug/open-lola release-hardening-synthetic-smoke
.build/debug/open-lola goal-codewise-closure-run --output /private/tmp/open-lola-goal-codewise-closure.json
.build/debug/open-lola validate-goal-codewise-closure-report /private/tmp/open-lola-goal-codewise-closure.json
.build/debug/open-lola goal-runtime-preflight-run --output /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola validate-goal-runtime-preflight-report /private/tmp/open-lola-goal-runtime-preflight.json
.build/debug/open-lola goal-completion-audit-run --output /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola validate-goal-completion-audit-report /private/tmp/open-lola-goal-completion-audit.json
.build/debug/open-lola open-source-release-readiness-run --output /private/tmp/open-lola-open-source-release-readiness.json
.build/debug/open-lola validate-open-source-release-readiness-report /private/tmp/open-lola-open-source-release-readiness.json
```

These probes do not close physical runtime gates. They only prove local source
shape, host-visible surfaces, and the current release/legal blocker ledger. The
completion audit's `nextActions` field maps each blocker to its owner, evidence
paths, run commands, and validators.

## Direct P2P AV Prototype Probe

Run this as a paired two-process probe on one host for source-level smoke, or on
two Macs by replacing the loopback hosts with the two peer addresses and using
the real device UIDs from `device-inventory`. The v1 AV runtime still requires
`--input-uid` and `--output-uid` to name the same full-duplex Core Audio device.

```bash
.build/debug/open-lola direct-p2p-two-peer-plan-run --output /private/tmp/open-lola-direct-p2p-av-plan.json --run-dir /private/tmp --mac-a-peer mac-a --mac-a-host 127.0.0.1 --mac-a-port-base 57000 --mac-a-input-uid <full-duplex-input-uid> --mac-a-output-uid <same-full-duplex-output-uid> --mac-a-video-device-id <camera-id-or-auto> --mac-b-peer mac-b --mac-b-host 127.0.0.1 --mac-b-port-base 57010 --mac-b-input-uid <full-duplex-input-uid> --mac-b-output-uid <same-full-duplex-output-uid> --mac-b-video-device-id <camera-id-or-auto> --duration-seconds 2 --channels 2 --frames 32 --preview on
.build/debug/open-lola direct-p2p-session-run --media audio-video --av-profile fastest --role responder --local-peer mac-b --remote-peer mac-a --local-host 127.0.0.1 --remote-host 127.0.0.1 --control-port 57010 --remote-control-port 57000 --audio-port 57011 --video-port 57012 --metrics-port 57013 --channels 2 --duration-seconds 2 --input-uid <full-duplex-input-uid> --output-uid <same-full-duplex-output-uid> --sample-rate 48000 --frames 32 --sample-format float32 --input-channels 0,1 --output-channels 0,1 --video-device-id <camera-id-or-auto> --video-frame-rate 30 --video-stream-id 100 --timeout-seconds 30 --output /private/tmp/open-lola-direct-p2p-av-mac-b.json
.build/debug/open-lola direct-p2p-session-run --media audio-video --av-profile fastest --role initiator --local-peer mac-a --remote-peer mac-b --local-host 127.0.0.1 --remote-host 127.0.0.1 --control-port 57000 --remote-control-port 57010 --audio-port 57001 --video-port 57002 --metrics-port 57003 --channels 2 --duration-seconds 2 --input-uid <full-duplex-input-uid> --output-uid <same-full-duplex-output-uid> --sample-rate 48000 --frames 32 --sample-format float32 --input-channels 0,1 --output-channels 0,1 --video-device-id <camera-id-or-auto> --video-frame-rate 30 --video-stream-id 100 --timeout-seconds 30 --output /private/tmp/open-lola-direct-p2p-av-mac-a.json
.build/debug/open-lola validate-direct-p2p-session-report /private/tmp/open-lola-direct-p2p-av-mac-a.json
.build/debug/open-lola validate-direct-p2p-session-report /private/tmp/open-lola-direct-p2p-av-mac-b.json
```

Expected result: both reports validate as `PARTIAL`, identify the selected
Core Audio UID path, record selected buffer frames and preview mode, and show
non-zero routed audio and video packet counters. The project verdict remains
`PARTIAL` until the physical two-Mac run is captured with route labels, packet
capture, timing comparison against the audio-only fastest baseline, raw video
receive evidence, and measured-evidence fields.

## Manual Evidence Gates

Manual evidence remains required for:

- RME/MADI hardware inventory, loopback, and realtime callback ownership.
- Two-Mac direct route, direct-p2p AV, packet capture, DSCP, ICMP, traceroute,
  UDP echo comparison, and audio-only fastest baseline comparison.
- 60-minute drift/PLC and same-hardware LoLa baseline.
- Blackmagic/ATEM capture, VideoToolbox route, OSC peer, ATEM read-only status,
  and lighting output.
- Launched app bundle, physical raw recording stress with recording-off/on
  comparison, signed/notarized package, Gatekeeper, and clean-Mac field test.

## Resume here

Resume here: for docs-only topology changes, run docs and shellcheck. For
source or release-surface changes, also run release hygiene, focused Swift
contract tests, full `swift test --no-parallel`, and release readiness.

VERDICT: PARTIAL
