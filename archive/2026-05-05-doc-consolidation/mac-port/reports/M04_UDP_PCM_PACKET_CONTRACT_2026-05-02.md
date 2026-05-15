# M04 UDP PCM Packet Contract Validation Report

Date: 2026-05-02  
Milestone: [M04 UDP PCM Packet Contract](../milestones/M04_UDP_PCM_PACKET_CONTRACT.md)  
Status: PASS

## Scope

This report validates the native UDP PCM packet contract. It does not certify
Mac-to-Mac route behavior, DSCP behavior, jitter, loss, or packet age; those
remain M05 work.

## Packet Contract

The current packet header is 48 bytes:

- magic: `OLPC`
- version: `1`
- sample format: `1` for int16 little-endian, `2` for float32 little-endian
- channel count
- frames per packet
- sample rate
- sequence number
- sender frame index
- sender host timestamp in nanoseconds
- payload byte count
- fixed header guard: `LPC1`

The payload is raw PCM and one packet represents one audio block. Parser and
serializer code run outside any realtime Core Audio callback.

## Commands

```bash
swift test
swift build
swift run open-lola validate-udp-pcm-packet Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex
swift run open-lola validate-udp-pcm-packet Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-float32.hex
swift run open-lola validate-udp-pcm-packet Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/invalid/wrong-guard.hex
swift run open-lola udp-pcm-localhost-smoke
bash scripts/verify-docs.sh
shellcheck scripts/*.sh
```

## Results

- `swift test` passed with 25 tests.
- Valid int16 and float32 packet fixtures passed CLI validation.
- The wrong-guard fixture failed with the expected `invalidHeaderGuard` error.
- The localhost UDP smoke command sent and received one packet on loopback.
- Documentation and shell verification passed.

## Verdict

M04 satisfies the strict, versioned, one-block UDP PCM packet contract gate.

VERDICT: PASS

## Resume here

Start [M05](../milestones/M05_MAC_TO_MAC_ROUTE_CERTIFICATION.md) by using the
M04 packet fixtures and localhost smoke path as the source contract, then add
direct-link route reports for packet age, loss, and jitter.
