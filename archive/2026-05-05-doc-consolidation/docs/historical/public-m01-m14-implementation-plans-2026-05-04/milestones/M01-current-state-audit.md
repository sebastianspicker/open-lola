# M01 Current-State Audit

Date: 2026-05-04  
Status: complete; documentation verifier passed; runtime source unchanged  
Verdict: PASS

## Objective

Establish the live repository baseline for full MADI audio RX/TX, Blackmagic
video RX/TX, direct P2P session setup, latency profiles, tests, benchmarks, and
documentation before changing runtime source.

## Scope

This milestone is read-only for implementation code. It records what currently
exists and where the next implementation must begin.

## Current Assessment

Audio:

- Core Audio device inventory, RME classification, latency reports, and
  source-level loopback contracts exist.
- UDP PCM v1/v2 packet models, multichannel negotiation models, v2 fragment
  planning, RX buffering policy, and impairment simulation exist.
- Live IOProc loopback is still effectively stereo/fixed-channel in the
  callback configuration.
- The current realtime packet handoff can emit silence packets and metadata
  contracts, but it does not yet packetize captured MADI samples into live media.
- RX buffering and receiver mix contracts exist, but full live multichannel
  playback/routing from peer media is not complete.

Video:

- AVFoundation capture inventory and capture-report probes exist.
- Blackmagic-compatible devices can be classified through public macOS capture
  surfaces when exposed by the driver.
- Desktop Video SDK linkage is intentionally optional and not yet implemented.
- Raw synthetic video packetization/reassembly exists.
- Live Blackmagic capture TX, peer RX, render/output, and multi-stream runtime
  paths are not complete.

P2P:

- UDP PCM loopback, route certification, NAT-friendly route probes, rendezvous,
  and relay smoke paths exist.
- There is no full E2E peer session model with identity, capability exchange,
  audio/video stream negotiation, control/media channels, reconnect, metrics
  exchange, and clean shutdown.

## Affected Files

Read-only source and docs inspected:

- `Package.swift`
- `Sources/OpenLolaCore/AudioLoopbackRun.swift`
- `Sources/OpenLolaCore/RealtimeAudioPacketHandoff.swift`
- `Sources/OpenLolaCore/RealtimeAudioBuffers.swift`
- `Sources/OpenLolaCore/MultichannelTransport.swift`
- `Sources/OpenLolaCore/UdpPcmPacket.swift`
- `Sources/OpenLolaCore/UdpPcmV2Packet.swift`
- `Sources/OpenLolaCore/UdpPcmV2FragmentPlanner.swift`
- `Sources/OpenLolaCore/UdpPcmContinuousRouteRunner.swift`
- `Sources/OpenLolaCore/NatFriendlyRoute.swift`
- `Sources/OpenLolaCore/VideoCaptureAVFoundation.swift`
- `Sources/OpenLolaCore/VideoCaptureRunner.swift`
- `Sources/OpenLolaCore/VideoTransportPacket.swift`
- `Sources/OpenLolaCore/VideoTransportRunner.swift`
- `docs/current-state.md`
- `docs/architecture/*.md`
- `mac-port/**/*.md`
- `Tests/OpenLolaCoreTests/*.swift`

## Implementation Tasks

1. Keep the audit clean-room: no proprietary packet names, binary logic, copied
   packet shapes, or decompiled implementation details.
2. Treat all runtime code as read-only during M01.
3. Record exact gaps in the architecture docs.
4. Create milestone companion files for M02-M14.
5. Run the docs verifier.

## Test Plan

- No new runtime tests in M01.
- Verify documentation links, public-release constraints, and ASCII constraints
  with `bash scripts/verify-docs.sh`.
- Verification run on 2026-05-04: `bash scripts/verify-docs.sh` returned
  `Documentation verification passed.`

## Benchmark Plan

M01 defines benchmark targets only. No physical benchmark is claimed until M13
or a hardware-specific milestone supplies measured reports.

## Acceptance Criteria

- Repository baseline is documented.
- Current MADI, Blackmagic, and P2P status are explicit.
- Missing implementation surfaces are mapped to concrete future files.
- No runtime source implementation is changed.
- Docs verification passes.

## Risks

- Hardware availability may reveal different driver behavior than the source
  contracts assume.
- The repo is not a Git worktree in the current filesystem state, so branch and
  diff proof cannot be produced from this directory.

## Blockers

- Physical RME MADI evidence is absent.
- Physical Blackmagic/ATEM evidence is absent.
- A second peer machine/direct route is required for E2E PASS.

## Rollback Plan

Remove only the planning documents added for this milestone. No runtime state
needs rollback because no runtime implementation is part of M01.

## Progress Checklist

- [x] Inspect source and docs.
- [x] Identify current MADI state.
- [x] Identify current Blackmagic state.
- [x] Identify current P2P state.
- [x] Write architecture planning docs.
- [x] Write milestone planning docs.
- [x] Run docs verification.

## Resume Point

M01 is closed. Start M02 by adding tests for the clean-room peer session model
and original open-lola protocol structures.

VERDICT: PASS
