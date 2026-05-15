# M02 Core Protocol And Session Model

Date: 2026-05-04  
Status: source-level implementation complete; no live media runtime included  
Verdict: PASS

## Objective

Define and implement the original open-lola peer identity, capability exchange,
session negotiation, stream descriptions, latency profile agreement, lifecycle
states, metrics messages, errors, and clean shutdown.

## Scope

In scope:

- control-channel message structures;
- peer identity;
- audio/video capability models;
- audio/video stream descriptions;
- stream IDs and payload type IDs;
- negotiated session configuration;
- session state machine;
- deterministic JSON or binary control codec tests;
- no media hot-path optimization yet.

Out of scope:

- live MADI sample capture;
- live Blackmagic frame capture;
- NAT traversal beyond existing route probes;
- proprietary formats or binary-derived packet layouts.

## Affected Files

Implemented new or changed files:

- `Sources/OpenLolaCore/PeerIdentity.swift`
- `Sources/OpenLolaCore/SessionProtocol.swift`
- `Sources/OpenLolaCore/SessionControlMessage.swift`
- `Sources/OpenLolaCore/SessionNegotiation.swift`
- `Sources/OpenLolaCore/AudioStreamDescription.swift`
- `Sources/OpenLolaCore/VideoStreamDescription.swift`
- `Sources/OpenLolaCore/CapabilitySummary.swift`
- `Sources/OpenLolaCore/OpenLolaCLI.swift`
- `Sources/open-lola/main.swift`
- `Tests/OpenLolaCoreTests/SessionProtocolTests.swift`
- `Tests/OpenLolaCoreTests/SessionNegotiationTests.swift`
- `docs/current-state.md`
- `docs/architecture/open-lola-protocol.md`
- `docs/architecture/e2e-p2p-session.md`

## Implementation Tasks

1. Add tests for `PeerIdentity`, `CapabilitySet`, `SessionProposal`, and
   `SessionConfiguration`.
2. Define clean-room control message types: hello, capabilities, proposal,
   accept, reject, start media, pause media, metrics, error, shutdown.
3. Define explicit audio stream descriptors: stream ID, sample rate, sample
   format, channel count, channel order, clock domain, packet duration.
4. Define explicit video stream descriptors: stream ID, role, resolution,
   frame rate, pixel format, transport format, source label.
5. Add latency profile descriptors for Direct Audio First, Balanced AV,
   Multi-Video Performance, and WAN Stable.
6. Implement validation that rejects unsupported sample rates, formats,
   channel counts, stream IDs, and profile combinations.
7. Wire a CLI command that can print local capabilities without starting media.

## Test Plan

Tests first:

- channel-count negotiation;
- sample-rate mismatch rejection;
- sample-format mismatch rejection;
- audio/video stream ID uniqueness;
- latency profile compatibility;
- deterministic control-message round trip;
- shutdown idempotency;
- error packet encoding without crashing the session state machine.

Closure verification for 2026-05-04:

- `swift test --filter SessionProtocolTests` passed.
- `swift test --filter SessionNegotiationTests` passed.
- `swift test` passed with 545 tests.
- `swift build` passed after an unsandboxed rerun; sandboxed SwiftPM manifest
  evaluation failed with `sandbox-exec: sandbox_apply: Operation not permitted`.
- `bash scripts/verify-docs.sh` passed.
- `swift run open-lola session-capabilities` passed after the same unsandboxed
  SwiftPM rerun and printed `VERDICT: PASS`.

## Benchmark Plan

Only control-plane benchmarks are required:

- control message encode/decode time;
- maximum capability document size;
- session negotiation latency over loopback TCP or UDP control channel.

## Acceptance Criteria

- Two peers can exchange capabilities and derive one deterministic session
  configuration in a test harness.
- The accepted configuration explicitly names audio channels, video streams,
  sample rate, sample format, frame format, latency profile, and media ports.
- Unsupported combinations fail with structured errors.
- No media implementation depends on proprietary packet structures.

## Risks

- Over-generalizing the protocol before the first real MADI path could create
  unused abstractions.
- A binary codec might be faster later, but JSON or a simple typed codec is
  easier to validate during initial clean-room protocol work.

## Blockers

- None for source-level implementation.
- Physical PASS still depends on M03-M13.

## Rollback Plan

Keep existing UDP PCM and NAT route probes unchanged. If the session model is
too broad, remove the new protocol files and keep only the validated stream
description structs used by the next audio milestone.

## Progress Checklist

- [x] Add protocol/session tests.
- [x] Implement peer identity.
- [x] Implement capability models.
- [x] Implement session proposal and acceptance.
- [x] Implement latency profile negotiation.
- [x] Add capability CLI surface.
- [x] Update protocol docs from the shipped source.

## Resume Point

M02 is closed at the source-contract level. Start M03 by using the accepted
`SessionConfiguration` audio stream fields to drive MADI TX packetization tests
without starting live Core Audio media.

VERDICT: PASS
