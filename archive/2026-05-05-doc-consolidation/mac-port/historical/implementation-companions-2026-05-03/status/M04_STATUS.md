# M04 Status

## Current status

- Status: Complete.
- Canonical milestone: [M04 UDP PCM Packet Contract](../milestones/M04_UDP_PCM_PACKET_CONTRACT.md)

Canonical objective:

Define and test the native UDP PCM packet contract: header, sequence, timestamp,
sample format, frames per packet, channel count, and header guard or CRC.

Canonical assumptions:

- BSD UDP sockets are the first transport API.
- One packet equals one audio block in fastest mode.
- The packet contract is versioned from day one.

Canonical dependencies:

- M00 scaffold.
- M01 report/fixture schema.
- M03 selected frame sizes and sample formats.

Canonical affected modules/files:

- Future UDP PCM packet module.
- Future packet parser and serializer tests.
- Future fixture files for valid and invalid packets.
- [../EVIDENCE_AND_CONFLICTS.md](../EVIDENCE_AND_CONFLICTS.md)

Canonical implementation sequence:

1. Write packet parser tests for invalid magic, version, length, frame count,
   sample rate, channel count, sample format, sequence, and guard/CRC.
2. Define a fixed-size header.
3. Implement serializer and parser with strict length checks.
4. Add fixtures for supported sample formats.
5. Keep network send/receive threads separate from callback code.

Canonical acceptance criteria:

- Packet format is documented and versioned.
- Parser rejects truncated, oversized, wrong-version, wrong-format, and
  wrong-guard packets.
- No packet logic blocks or allocates in the audio callback.

Rollback/recovery notes:

- Documentation-only changes: restore the preserved historical copy when one exists, or revert the specific changed file.
- Source changes: revert the smallest affected change set and rerun `swift test`.
- Hardware, network, audio, video, lighting, recording, or packaging reports: mark the report invalid rather than deleting it, then rerun measurement.

## Completed work

- Added a strict `UdpPcmPacket` binary contract with 48-byte header, `OLPC`
  magic, version `1`, sample format, channel count, frames per packet, sample
  rate, sequence number, sender frame index, sender host timestamp, payload
  byte count, and fixed header guard.
- Added int16 little-endian and float32 little-endian sample format support.
- Added serializer and parser with strict length, version, format, guard,
  payload-size, sample-rate, channel-count, frame-count, and sequence checks.
- Added valid int16 and float32 hex packet fixtures plus an invalid wrong-guard
  fixture.
- Added localhost UDP smoke support that sends one encoded packet over loopback
  and decodes the received datagram.
- Added `open-lola validate-udp-pcm-packet <path>` and
  `open-lola udp-pcm-localhost-smoke` CLI commands.
- Added [../reports/M04_UDP_PCM_PACKET_CONTRACT_2026-05-02.md](../reports/M04_UDP_PCM_PACKET_CONTRACT_2026-05-02.md).

## Verified work

- Red test run before implementation failed on missing UDP PCM packet types.
- `swift test` passed with 25 tests after implementation.
- `swift build` passed.
- Valid int16 and float32 packet fixtures passed CLI validation.
- Invalid wrong-guard packet fixture failed as expected with `invalidHeaderGuard`.
- `swift run open-lola udp-pcm-localhost-smoke` passed.
- `bash scripts/verify-docs.sh` passed.
- `shellcheck scripts/*.sh` passed.

## Partially completed work

- None for the M04 packet-contract milestone.

## Deferred work

- Mac-to-Mac route certification, DSCP behavior, packet age, jitter, and loss
  measurements remain M05 work.
- Final fastest-mode sample-format selection remains tied to the unresolved M03
  physical loopback result, but the M04 contract supports the current int16 and
  float32 fixture formats.

## Open tasks

Canonical progress checklist:

- [x] Add failing packet tests.
- [x] Define header.
- [x] Implement serializer.
- [x] Implement parser.
- [x] Add packet fixtures.
- [x] Add localhost UDP smoke test.
- [x] Update [../PROGRESS.md](../PROGRESS.md).

SOTA 2026 routing:

- Rows: SOTA005, SOTA016, SOTA018, SOTA019 in [../SOTA_2026_OPEN_QUESTION_MATRIX.md](../SOTA_2026_OPEN_QUESTION_MATRIX.md).
- Closure rule: one-block UDP PCM packet contract stays strict, versioned, and independent of relay or adaptive-buffer policies.

## Known blockers

- No M04 blockers remain.
- M03 still owns final fastest-mode sample-format selection.
- M05 still owns route performance and packet-rate stress validation.

## Test coverage status

Canonical test plan:

Before: packet parser tests fail or do not exist.

After:

- serializer/parser tests pass;
- fixture tests pass;
- malformed packet tests reject bad input;
- `swift build` and `swift test` pass.

Coverage state: Swift tests cover valid int16 and float32 fixture decoding,
serializer round-trip, invalid magic, unsupported version, truncated packet,
oversized packet, invalid sample rate, invalid channel count, unsupported
sample format, wrong header guard, payload length mismatch, skipped sequence,
and localhost UDP round trip.

## Relevant files touched

Planned affected modules/files:

- Future UDP PCM packet module.
- Future packet parser and serializer tests.
- Future fixture files for valid and invalid packets.
- [../EVIDENCE_AND_CONFLICTS.md](../EVIDENCE_AND_CONFLICTS.md)

Live files touched:

- [../../Sources/OpenLolaCore/UdpPcmPacket.swift](../../Sources/OpenLolaCore/UdpPcmPacket.swift)
- [../../Sources/open-lola/main.swift](../../Sources/open-lola/main.swift)
- [../../Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift](../../Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift)
- [../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex](../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex)
- [../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-float32.hex](../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-float32.hex)
- [../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/invalid/wrong-guard.hex](../../Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/invalid/wrong-guard.hex)
- [../reports/M04_UDP_PCM_PACKET_CONTRACT_2026-05-02.md](../reports/M04_UDP_PCM_PACKET_CONTRACT_2026-05-02.md)
- [../milestones/M04_UDP_PCM_PACKET_CONTRACT.md](../milestones/M04_UDP_PCM_PACKET_CONTRACT.md)
- [../PROGRESS.md](../PROGRESS.md)
- [../STATUS_INDEX.md](../STATUS_INDEX.md)
- [../../MAC_PORT_PLAN.md](../../MAC_PORT_PLAN.md)
- [../VALIDATION_CHECKLIST.md](../VALIDATION_CHECKLIST.md)
- [../EVIDENCE_AND_CONFLICTS.md](../EVIDENCE_AND_CONFLICTS.md)
- [../RISK_REGISTER.md](../RISK_REGISTER.md)
- [../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md)
- [M05_STATUS.md](M05_STATUS.md)

## Latest verification

- 2026-05-02: `swift test` passed with 25 tests.
- 2026-05-02: `swift build` passed.
- 2026-05-02: `swift run open-lola validate-udp-pcm-packet
  Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex`
  passed.
- 2026-05-02: `swift run open-lola validate-udp-pcm-packet
  Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-float32.hex`
  passed.
- 2026-05-02: invalid wrong-guard packet fixture failed with the expected
  `invalidHeaderGuard` error.
- 2026-05-02: `swift run open-lola udp-pcm-localhost-smoke` passed.
- 2026-05-02: `bash scripts/verify-docs.sh` passed.
- 2026-05-02: `shellcheck scripts/*.sh` passed.
- VERDICT: PASS

## Next recommended steps

Start M05 route certification using the M04 packet fixtures and localhost smoke
path as the packet-contract baseline.

## Resume here

Use `swift run open-lola validate-udp-pcm-packet` and
`swift run open-lola udp-pcm-localhost-smoke` as M05 preflight checks before
adding direct-link packet age, loss, and jitter reports.
