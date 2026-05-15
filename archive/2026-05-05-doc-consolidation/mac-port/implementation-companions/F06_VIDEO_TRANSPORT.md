# F06 Video Transport

Date: 2026-05-03
Status: required best-effort video transport
Verdict: PARTIAL

## Finding

The current source layer validates raw video packetization, bounded
fragmentation/reassembly accounting, and latest-frame receiver accounting, but
production video transport still needs physical route evidence and audio-first
degradation proof. Video must drop or degrade before audio timing changes.

## Current Surface

- [../../Sources/OpenLolaCore/VideoTransportProbe.swift](../../Sources/OpenLolaCore/VideoTransportProbe.swift)
  defines raw/intra-frame/VideoToolbox modes, encoded bounded fragments,
  route evidence, fragmentation and reassembly metrics, latest-frame receiver
  behavior, and PASS guards.
- `open-lola video-transport-run --mode raw ...` writes bounded raw transport
  reports through the fragment encoder/reassembler path with computed raw
  fragment counts.

## Required Transport Shape

- Raw or simple intra-frame mode is the first baseline.
- Frame fragmentation must bound packet size and include reassembly accounting.
- Malformed encoded fragments must fail before they enter reassembly.
- Incomplete older frames must be dropped when a newer frame starts.
- Receiver uses latest-frame semantics and may drop stale frames.
- Reliable retransmission is absent from the fastest local path.
- VideoToolbox H.264/HEVC is measured only after raw/intra-frame baseline.
- Video transport and capture run outside audio callback resources.

## Required Evidence

- F03 accepted audio route or an explicitly separate video route label.
- Packet capture on the physical video route.
- Frame sequence, fragment counts, missing fragments, reassembled frames,
  dropped frames, and frame age.
- Audio route verdict with video off and video on.
- Video degradation action taken before any audio target change.

## PASS Criteria

- Physical raw or intra-frame run validates with packet capture.
- Fragment payload size is bounded by the report's max packet size, and
  reassembly has no missing, late, or incomplete fragments.
- No video packet or queue policy changes audio playout target.
- Late or incomplete video frames are dropped, not waited for.
- VideoToolbox is not accepted until realtime mode, reordering, queue depth,
  CPU/GPU contention, and glass-to-glass latency are measured.

## Resume here

After F05 identifies the capture source, add physical raw/intra-frame transport
evidence. Use the existing narrow M09 fragmentation/reassembly metrics, then
validate audio-off/video-on and audio-on/video-on behavior.

VERDICT: PARTIAL
