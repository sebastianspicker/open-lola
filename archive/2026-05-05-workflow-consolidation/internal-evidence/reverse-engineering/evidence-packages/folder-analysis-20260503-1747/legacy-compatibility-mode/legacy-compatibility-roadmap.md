# Legacy Compatibility Mode Roadmap

The implementation path should be fixture-first. Do not start with live
packet injection; start by parsing captured or synthetic bytes and proving
round trips.

## R0 Static Evidence Freeze

Deliverables:

- Keep this timestamped package as the source evidence bundle.
- Store future PCAP and runtime logs as separate fixtures with hashes.
- Maintain a table mapping every parser field to a source address, string,
  capture byte offset, or test fixture.

Acceptance:

- Every compatibility claim is tagged confirmed, observed, inferred,
  hypothesis, or requires validation.

## R1 Session/Control Compatibility

Deliverables:

- `/MESG_*` parser and generator.
- Quick-connect model with `SR`, `BPS`, `CHNLS`, `FPS`, `BPP`, `X`, `Y`,
  `COMP`, and `BAYER`.
- Golden tests for every static template.

Acceptance:

- Formatting round trip preserves static strings exactly where templates are known.
- Parser accepts both semicolon-terminated and non-terminated audio-signal messages.

## R2 Config And Profile Compatibility

Deliverables:

- `LolaGui.ini` compatibility schema for AV/session keys.
- `CAMERAFILES/*.ini` parser for camera profile names.
- `XimeaColors.ini` parser for color defaults.

Acceptance:

- Every shipped INI line parses without data loss.
- Defaults match static loader evidence: control 7000, audio 19788, video 19798,
  `WinPcap_SetMinToCopy` 10, `RxPacketFiltering` 1.

## R3 Packet Envelope Compatibility

Deliverables:

- Ethernet/IPv4/UDP frame parser with LoLa payload at offset 42.
- PCAP fixture reader/writer.
- Packet-builder tests for audio/video port selection.

Acceptance:

- Synthetic frames round-trip header and payload bytes.
- Captured LoLa frames classify as audio or video by UDP port.

## R4 Audio TX/RX Compatibility

Deliverables:

- PCM frame model.
- Audio packet parser/generator using the inferred `channels * 128` payload size.
- Clock/cadence model for 44.1 kHz and 48 kHz.

Acceptance:

- Fixture packets decode to expected sample counts.
- Generated packets match captured LoLa audio bytes for at least mono and stereo.
- Drift/drop counters are mapped to observable behavior.

## R5 Video TX/RX Compatibility

Deliverables:

- CPU MJPEG chunk parser/decoder.
- Raw video chunk parser.
- Frame ring/reassembly model for 30-slot behavior.

Acceptance:

- Captured MJPEG frames decode with a standard JPEG library.
- Raw frame dimensions and pixel formats match quick-connect fields.
- Fragment order, frame ID, sequence, and loss behavior are byte-mapped.

## R6 Isolated Windows Peer Validation

Deliverables:

- Offline lab plan for two owned LoLa peers or one LoLa peer plus harness.
- Packet captures for connect, quick-connect ACK, audio-only, video-only,
  raw video, CPU MJPEG, disconnect, reject, and chat.
- Runtime DLL load log to confirm or reject GPUJPEG use.

Acceptance:

- No public network exposure.
- No bypass of licensing, DRM, authentication, or access controls.
- Every capture has SHA256, LoLa settings, hardware notes, and time base.

## R7 Legacy Compatibility Mode Prototype

Deliverables:

- Read-only PCAP replay/import.
- Session parser/generator.
- Audio decode/playback from captured LoLa packets.
- Video decode/render from captured LoLa packets.
- Optional TX generator gated behind lab-only tests.

Acceptance:

- LoLa-origin PCAPs replay audio and video correctly.
- Generated session/control messages are accepted by an owned LoLa peer.
- Generated AV packets interoperate with an owned LoLa peer in isolated lab tests.

## Do Not Start Until Evidence Exists

- GPUJPEG compatibility beyond documentation.
- Public network interoperability.
- Binary patching.
- Licensing, DRM, authentication, or access-control bypass.
- Credential or secret extraction.
