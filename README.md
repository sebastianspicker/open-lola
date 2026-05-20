# open-lola

Date: 2026-05-19
Status: Mac-native SwiftPM workspace with broad source-level runtime support
Verdict: PARTIAL

open-lola is a clean-room, Mac-native, audio-first implementation path for
low-latency networked audio/video. It targets professional remote performance,
teaching, rehearsal, and production workflows while keeping latency, buffering,
transport behavior, and evidence gaps visible.

The project goal is not to copy proprietary LoLa behavior. The goal is an
original implementation backed by public APIs, public standards, original tests,
source contracts, and measured reports.

## Current Verdict

The product and release verdict is still `PARTIAL`.

The source tree now contains substantial implementation coverage: SwiftPM
libraries, the `open-lola` CLI, a SwiftUI macOS app target, report validators,
release-readiness probes, direct P2P media reports, native LoLa comparison
surfaces, and native UltraGrid/MVTP and JackTrip connector runtimes.

That source-level breadth is not field readiness. `PASS` still requires measured
hardware, physical peer, packet-capture, timing, media-quality, signing,
notarization, Gatekeeper, clean-Mac, fixture-provenance, license/notices, and
reviewer evidence.

## What Works Today

- Swift Package Manager workspace with `OpenLolaCore`, `OpenLolaContracts`,
  `OpenLolaAppSupport`, the `open-lola` CLI, and the `open-lola-app` SwiftUI
  executable target.
- Core Audio inventory, UDP PCM packet contracts, RX-buffer profiles, direct P2P
  report surfaces, source validators, schema fixtures, and release-readiness
  reports.
- macOS app bundle assembly through the local build-and-run script, including a
  staged `dist/OpenLoLa.app` bundle.
- Linux LoLa compatibility seed under [linux_connector/](linux_connector/README.md),
  kept as a Python reference seed rather than merged into SwiftPM packaging.
- Swift Windows LoLa probing with constrained runtime evidence for UDP
  control/status handling and outbound generated AV. Full inbound Windows media
  decode remains unproven.
- Native UltraGrid/MVTP source-level runtime support for RTP/MVTP media reports,
  PT20 raw video, PT21 PCM audio, dynamic payload mappings, JPEG/H.264 packet
  validation, local FEC/encryption behavior, control-command modeling, provider
  selection, bounded media sinks, topology reporting, and evidence-gated
  validation.
- Native JackTrip source-level runtime support for DEFAULT, JAMLINK, EMPTY
  header, WebRTC data-channel, WebTransport datagram, hub/topology, TCP
  handshake, auth/TLS frame modeling, `coreaudio`/`jack-graph` backend
  selection, plugin-boundary reporting, Opus-extension payloads, PCM bit-depth
  variants, bounded media sinks, and evidence-gated validation.

## What Is Not Proven Yet

- Physical RME/MADI hardware identity, route labels, packet-capture points,
  DSCP/PTP policy, and accepted latency/loss thresholds.
- Physical two-Mac direct P2P runs with measured packet age, jitter, loss,
  underrun/overrun, and fastest audio-only baseline comparison.
- Blackmagic/ATEM or other reviewed video capture evidence proving video
  degrades before audio timing changes.
- Windows-originated LoLa media capture and Swift decode evidence.
- UltraGrid/MVTP reference-peer parity evidence. The current skip-loud gate is
  blocked by missing `OPEN_LOLA_REFERENCE_PEER_HOST`.
- JackTrip reference-peer parity evidence. The current skip-loud gate is blocked
  by missing `OPEN_LOLA_REFERENCE_PEER_HOST` and no local `jacktrip` executable.
- Measured JACK graph capture evidence for JackTrip `jack-graph` field claims.
- OSC, sACN, Art-Net, and lighting/control checks with explicit audio-impact
  evidence.
- Developer ID signing, notarization, Gatekeeper acceptance, clean-Mac launch,
  final license/notices, fixture provenance, release-candidate review, and
  maintainer approval.

Do not promote synthetic fixtures, localhost runs, built-in-device checks,
archived reports, skip-loud readiness reports, or placeholder hardware labels
to product `PASS`.

## Quickstart

Build the workspace:

```bash
swift build
```

Run the full Swift test suite:

```bash
swift test --no-parallel
```

Build the CLI product:

```bash
swift build --product open-lola
```

Build and verify the macOS app bundle:

```bash
bash script/build_and_run.sh --verify
```

SwiftPM may need to run outside strict sandboxing on this Mac if manifest
sandboxing fails with `sandbox-exec: sandbox_apply: Operation not permitted`.

## Release Validation Checklist

- Direct Audio First and Balanced AV remain documented latency profiles; see
  [docs/latency-profiles.md](docs/latency-profiles.md).
- The release-hardening synthetic smoke command is
  `.build/debug/open-lola release-hardening-synthetic-smoke`.

## Entry Points

- CLI after build: `.build/debug/open-lola <command>`
- App executable after build: `.build/debug/open-lola-app`
- Staged app bundle after app verification: `dist/OpenLoLa.app`
- Python LoLa seed:
  `PYTHONDONTWRITEBYTECODE=1 python -m linux_connector.lola_connector.cli ...`

Useful status probes:

```bash
.build/debug/open-lola session-capabilities
.build/debug/open-lola goal-runtime-preflight-run --output /tmp/open-lola-runtime.json
.build/debug/open-lola validate-goal-runtime-preflight-report /tmp/open-lola-runtime.json
.build/debug/open-lola open-source-release-readiness-run --output /tmp/open-lola-release.json
.build/debug/open-lola validate-open-source-release-readiness-report /tmp/open-lola-release.json
```

## Documentation Map

Start with the active public docs:

1. [docs/current-state.md](docs/current-state.md) for the publication-safe
   current state and evidence boundaries.
2. [docs/implementation-handoff.md](docs/implementation-handoff.md) for
   completed source work, missing evidence, and the resume point.
3. [docs/source-contracts.md](docs/source-contracts.md) for source-contract and
   connector boundaries.
4. [docs/testing.md](docs/testing.md) for verification commands, app checks, and
   real-world evidence gates.
5. [docs/release-boundary.md](docs/release-boundary.md) and
   [docs/release-manifest.md](docs/release-manifest.md) before any release or
   export work.
6. [docs/open-questions.md](docs/open-questions.md) for field-test, hardware,
   route, and human-input gates.
7. [docs/README.md](docs/README.md) for the complete active documentation map.

Historical plans, audits, ledgers, and superseded docs live under
[archive/](archive/README.md). Treat them as trace evidence, not active
implementation authority.

## Verification

For documentation-only edits:

```bash
bash scripts/verify-docs.sh
python3 -m scripts.verify_docs
git diff --check
bash scripts/verify-release-hygiene.sh
```

For source, CLI, verifier, report-schema, release, or user-facing runtime
changes, broaden to the relevant commands in [docs/testing.md](docs/testing.md),
including Swift build and tests.

## Release Boundary

The raw checkout is not a release artifact. Stage release candidates with:

```bash
bash scripts/export-release-candidate.sh /path/to/output-parent
```

Public release remains blocked until the release candidate, license, notices,
fixture provenance, public-doc review, implementation audit, reviewer signoff,
hardware benchmarks, signing, notarization, Gatekeeper, and clean-Mac evidence
are complete.

VERDICT: PARTIAL
