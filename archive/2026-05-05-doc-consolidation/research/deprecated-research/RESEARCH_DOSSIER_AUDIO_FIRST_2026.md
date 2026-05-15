> Superseded research note (2026-05-02): this file is preserved for historical
> traceability. The canonical research entry point is
> [RESEARCH_COMPANION_2026.md](../RESEARCH_COMPANION_2026.md), with current
> decisions in the focused 2026 companion set.

# Audio-First Research Dossier 2026

Status: implementation research dossier  
Date: 2026-05-02  
Primary artifact: `RESEARCH_DOSSIER_AUDIO_FIRST_2026.md`  
Baseline documents: `MAC_PORT_PLAN.md`, `AUDIO_FIRST_LATENCY_PLAN.md`, `MAC_NATIVE_SOTA_AV_STRATEGY_2026.md`, `RESEARCH_SURVEY_2024_2026_DEEP.md`

## Scope And Hard Rule

This dossier studies the fastest audio path first. The conclusion priority is:

```text
audio latency/deadline safety > video > lighting > recording/UI
```

Hard rule: no PLC, codec, retransmission, QoS trick, video path, lighting feature, or UI/recording feature may increase default audio playout latency. A robustness feature is acceptable in fastest mode only if it acts inside a block that is already late or missing, or if its fixed cost is already included in the selected audio block target.

The current `MAC_PORT_PLAN.md` already points in the correct direction: macOS-native, Core Audio HAL/AUHAL or direct `AudioDeviceIOProc`, BSD UDP PCM, fixed tiny playout target, and video/lighting as subordinate timestamped paths. This research pass did not find a concrete architecture change that requires editing `MAC_PORT_PLAN.md`.

## Executive Decisions

1. Adopt now: direct Core Audio HAL/AUHAL or `AudioDeviceIOProc` for fastest mode, with explicit buffer-size probing and measured input/output/device/stream latency.
2. Adopt now: one UDP datagram per audio block in fastest mode, with sequence number, sender frame index, sender host timestamp, format id, channel count, sample format, and CRC/header guard.
3. Adopt now: dedicated audio callback, network receive, network send, and telemetry/control ownership. The audio callback must not call sockets, allocate, log, block on locks, or run codec/PLC work with unbounded CPU.
4. Adopt now: zero or one receive-block target as the default playout policy. If a block is late, output either silence or same-deadline concealment. Never wait for retransmission in fastest mode.
5. Benchmark: DSCP and macOS service-class marking. Treat `DSCP` as path-certified only. Outcomes must be classified as honored, rewritten, ignored, or harmful.
6. Benchmark: Audio Workgroups only for helper threads that demonstrably share the audio deadline. Core Audio already joins the framework-provided real-time render thread to the device workgroup.
7. Benchmark: Burg/AR PLC, Tilt Loss inspired models, and duplicate-current-block packets. None may grow the playout target.
8. Defer: Opus, WebRTC/browser, 5G/edge, AVB/TSN/AES67/RAVENNA/Dante, VideoToolbox video, UltraGrid, JPEG XS, embedded endpoints, and lighting/show-control until fastest UDP PCM audio is measured and stable.
9. Reject for fastest default: TCP, QUIC, retransmission waits, adaptive comfort-buffer growth, auto-jitter growth, codec-first mode, video-coupled audio scheduling, and lighting-triggered audio scheduling.

## Evidence Register

Source snapshots were kept outside the repo under `/tmp/open-lola-research-sources/`.

| Source | URL | Snapshot commit | Local path | Use |
|---|---|---:|---|---|
| JackTrip | https://github.com/jacktrip/jacktrip.git | `6b47162f5b16cf25098dd5f22087df7daa2b4451` | `/tmp/open-lola-research-sources/jacktrip` | UDP PCM, packet header, network thread, jitter/redundancy, QoS |
| AOO | https://git.iem.at/aoo/aoo.git | `dc2a5be2962ba02d6cebe297f31f2774f34e7bc7` | `/tmp/open-lola-research-sources/aoo` | process/send split, OSC/binary packet format, jitter, resend, dynamic resampling |
| SonoBus | https://github.com/sonosaurus/sonobus.git | `35f1062dab196b9838a4bb529c4bf6592b7f5987` | `/tmp/open-lola-research-sources/sonobus` | AOO integration, JUCE app thread model, auto-jitter policy, PCM/Opus choices |

External references used:

| Topic | Reference |
|---|---|
| Audio Workgroups | https://developer.apple.com/documentation/audiotoolbox/understanding-audio-workgroups |
| Core Audio IOProc APIs | https://developer.apple.com/documentation/coreaudio/audiodevicecreateioprocid and https://developer.apple.com/documentation/coreaudio/audiodevicestartattime%28_%3A_%3A_%3A_%3A%29 |
| AES67 | https://www.aes.org/publications/standards/search.cfm?docID=96 |
| AVB on macOS | https://support.apple.com/guide/audio-midi-setup/browse-your-network-for-an-avb-device-amsavb001/mac |
| RAVENNA/AES67 drivers | https://www.merging.com/products/alsa_ravenna_aes67_driver and https://merging.com/products/aes67-vad |
| Dante AES67 | https://www.getdante.com/support/faq/aes67-interoperability/ |
| Dante Virtual Soundcard latency | https://www.getdante.com/support/faq/what-is-the-latency-of-dante-virtual-soundcard/ |
| DSCP | https://www.rfc-editor.org/rfc/rfc2474.html |
| Expedited Forwarding | https://www.rfc-editor.org/rfc/rfc3246 |
| Tilt Loss | https://link.springer.com/article/10.1186/s13636-025-00442-1 |
| Burg PLC | https://link.springer.com/article/10.1007/s00779-024-01806-8 |
| Opus | https://www.rfc-editor.org/rfc/rfc6716 and https://www.opus-codec.org/docs/opus_api-1.6/group__opus__ctlvalues.html |
| WebRTC constraints | https://developer.mozilla.org/en-US/docs/Web/API/Media_Capture_and_Streams_API/Constraints |
| 5G NMP delay/quality | https://www.mdpi.com/1999-5903/17/8/337 and https://iris.unitn.it/handle/11572/400962 |
| Corelink Audio | https://www.researchgate.net/publication/390172710_Corelink_Audio_A_JUCE-based_Networked_Music_Performance_Solution |
| NetMusic3D | https://www.politesi.polimi.it/handle/10589/240954 |
| VideoToolbox real-time encode/decode | https://developer.apple.com/documentation/VideoToolbox/kVTCompressionPropertyKey_RealTime and https://developer.apple.com/documentation/videotoolbox/kvtdecompressionpropertykey_realtime |
| VideoToolbox frame reordering | https://developer.apple.com/documentation/videotoolbox/kvtcompressionpropertykey_allowframereordering |
| AVCapture late video frames | https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput |
| UltraGrid | https://github.com/CESNET/UltraGrid |
| JPEG XS | https://jpeg.org/jpegxs/ |
| JPEG XS RTP/FEC | https://www.rfc-editor.org/rfc/rfc9134.html and https://journal.smpte.org/periodicals/SMPTE%20Motion%20Imaging%20Journal/131/5/16/ |
| Dante 2025 ST 2110/AES67 update | https://www.audinate.com/press/dante-expands-st-2110-30-and-aes67-support-empowering-greater-interoperability-in-broadcast-workflows/ |
| TSN WCRT / AVB-aware scheduling | https://link.springer.com/article/10.1007/s11241-018-9321-z and https://orbit.dtu.dk/en/publications/avb-aware-routing-and-scheduling-of-time-triggered-traffic-for-ts/ |
| sACN / ANSI E1.31-2025 | https://webstore.ansi.org/standards/esta/ansie1312025 |
| Art-Net 4 | https://art-net.org.uk/art-net-specification/ |
| OLA | https://www.openlighting.org/ola/ and https://docs.openlighting.org/ola/conf/ola-e131.conf.html |
| QLC+ | https://www.qlcplus.org/ and https://docs.qlcplus.org/v5/plugins/art-net and https://docs.qlcplus.org/v4/plugins/e1-31-sacn |
| Open Fixture Library | https://open-fixture-library.org/ and https://github.com/OpenLightingProject/open-fixture-library |
| Chataigne | https://benjamin.kuperberg.fr/chataigne/en and https://github.com/benkuper/Chataigne |
| OpenFollow | https://openfollow.app/ |
| PSN / PosiStageNet | https://manual.stageprecision.com/stage.precision.beta/en/topic/posistagenet-psn and https://help.malighting.com/grandMA2/en/help/key_network_psn.html |
| WebRTC | https://webrtc.org/ and https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/WebRTC_codecs |

## Tier 1: Fastest Audio

### Core Audio HAL, AUHAL, And AudioDeviceIOProc

Core Audio decision:

- Fastest mode should target HAL/AUHAL/direct `AudioDeviceIOProc`, not AVAudioEngine.
- The default engine should be a headless real-time core. Swift/AppKit/SwiftUI may configure and observe, but must not own the audio deadline.
- The callback is the sole deadline-critical boundary. It reads already-arrived network blocks, writes the next output block, captures the input block, and publishes it to a lock-free handoff.

Implementation implications:

- Enumerate devices and streams with Core Audio object properties before opening the engine.
- Query supported frame-size ranges and attempt target frame sizes in this order: 32, 16, 64, 128 frames. The target is stable 32 frames; 16 frames is stretch; 64 frames is fallback; 128 frames is diagnostic.
- Set and verify `kAudioDevicePropertyBufferFrameSize` after selection. Do not assume a device accepted the requested value.
- Record `kAudioDevicePropertyLatency`, stream latency, safety offset where available, nominal sample rate, actual sample rate, input/output stream formats, and aggregate-device state.
- Use `AudioTimeStamp` host and sample times to tie callback cycles to network timestamps and drift telemetry.
- Measure round-trip analog latency with a loopback test. The API-reported latency is diagnostic, not the acceptance result.
- Use aggregate devices only as an explicit experiment, because drift correction and hidden buffering can change the latency budget.

Realtime callback constraints:

- Allowed: stack work, fixed-size preallocated buffers, atomic counters, SPSC ring push/pop, branch-bounded sample copy/convert/mix, timestamp capture, same-deadline silence or PLC substitute.
- Forbidden: heap allocation, Objective-C/Swift reference churn, ARC-heavy paths, locks, condition variables, logging, file I/O, sockets, DNS, codec allocation, unbounded resampler work, UI dispatch, blocking telemetry.
- If the callback cannot obtain a receive block by the deadline, it outputs silence or same-window PLC. It does not wait.
- If the callback cannot publish a send block, it drops that send block and increments an overrun counter. It does not block.

Audio Workgroups:

- Apple describes an audio workgroup as a set of real-time threads sharing a common audio deadline. Core Audio automatically joins framework-provided real-time render threads to the device workgroup.
- Use Audio Workgroups for helper real-time threads only when a helper has bounded deadline-coupled work that cannot be done in the callback and cannot be safely pushed to a normal network thread.
- Candidate use: a same-deadline packet preparation thread that wakes from the callback and serializes an already-copied input block. Reject this unless it beats a simpler SPSC network-send thread in missed-deadline measurements.
- Do not use Audio Workgroups to bless arbitrary network, UI, logging, or file threads as real-time.

Minimum measurement contract:

| Gate | Required output |
|---|---|
| Device acceptance | requested frames, accepted frames, sample rate, channel map |
| Deadline margin | callback duration p50/p95/p99/max and missed callback count |
| Audio latency | analog loopback one-way estimate or round-trip corrected by input/output device reports |
| Network coupling | receive age at playout, dropped-late count, send queue depth |
| Stability | 30-minute LAN run with no buffer growth in fastest mode |

### JackTrip Source Study

Studied snapshot: `6b47162f5b16cf25098dd5f22087df7daa2b4451`.

Relevant files and functions:

- `src/PacketHeader.h:56-64`: default header fields: timestamp, sequence number, buffer size, sampling rate, bit resolution, incoming channel count, outgoing channel count.
- `src/PacketHeader.h:125-161`, `src/PacketHeader.cpp:99-188`, `src/PacketHeader.cpp:205-265`: header fill, peer settings check, peer packet validation, sequence handling.
- `src/UdpDataProtocol.cpp:320-406`: socket QoS. On macOS it uses `SO_NET_SERVICE_TYPE` with `NET_SERVICE_TYPE_VO`; on Linux it uses `IP_TOS` or `IPV6_TCLASS` with EF-like marking plus `SO_PRIORITY`.
- `src/UdpDataProtocol.cpp:424-465`: UDP receive/send wrappers around `recv` and `sendto`.
- `src/UdpDataProtocol.cpp:486-890`: sender/receiver loop, nonblocking socket setup, preallocated packet buffers, platform polling with `epoll`, Windows events, or `kqueue`.
- `src/UdpDataProtocol.cpp:925-1010`: receive redundancy, sequence gap handling, out-of-order/loss tracking, and delivery into JackTrip audio buffers.
- `src/UdpDataProtocol.cpp:1060-1140`: send redundancy, current packet header/payload construction, previous packet copies, send, sequence increment.
- `src/AudioInterface.cpp:236-340`, `src/AudioInterface.cpp:439-487`: audio callback boundary and network-to-audio/audio-to-network copy.
- `src/JitterBuffer.cpp:120-250`: nonblocking insert/read with underrun zero fill and latency accounting.
- `src/JitterBuffer.cpp:315-358`: packet-loss handling and zero fill for missing regions.

Thread model:

- The audio callback is separate from UDP protocol loops.
- The UDP receiver validates packets and writes audio payloads toward the audio engine.
- The UDP sender obtains prepared audio payloads and transmits them with sequence/header data.
- Platform-specific polling avoids a tight blocking read loop.

Packet format:

- A compact header precedes raw audio payload.
- Sequence number and buffer-size/sample-rate/channel metadata are explicit.
- Redundancy mode sends current plus previous packet payloads in one datagram.

Buffer/playout policy:

- JackTrip supports jitter buffering and redundancy to trade bandwidth/buffer behavior against dropouts.
- Its jitter buffer can fill silence on underrun and can alter read/write positions for loss/skew behavior.

Failure behavior:

- Lost and out-of-order packets are detected by sequence gaps.
- Redundant packet copies can recover recently missing packets if they arrive in time.
- Underflow can produce zero fill.

Adopt:

- Header discipline: sequence number, frame count, sample rate, bit depth/sample format, channel count.
- Dedicated UDP network thread separate from the audio callback.
- Preallocated packet buffers and nonblocking/polled receive loops.
- Gap counters and per-peer telemetry.

Benchmark:

- JackTrip-style current-plus-previous redundancy only as an explicit experiment. It increases packet size and may increase jitter under constrained switching or Wi-Fi paths.
- macOS `SO_NET_SERVICE_TYPE` and IP DSCP marking. JackTrip's own macOS comment path is enough reason to measure rather than trust.

Reject for fastest default:

- Adaptive jitter buffer growth.
- Recovery that requires waiting beyond the selected playout block.
- Redundancy that increases packet serialization or queueing enough to harm p99 arrival.

### AOO Source Study

Studied snapshot: `dc2a5be2962ba02d6cebe297f31f2774f34e7bc7`.

Relevant files and functions:

- `doc/aoo_protocol.md:5-15`: AOO uses OSC with an alternative binary implementation and UDP peer-to-peer transport.
- `doc/aoo_protocol.md:27-51`: source-to-sink `/start` message includes stream id, sequence start, format, channels, sample rate, block size, codec name/extension, start time, reblock/resample latency, and codec delay.
- `doc/aoo_protocol.md:111-176`: `/data` message contains source id, stream id, sequence, optional timestamp, real sample rate, channel onset, data size, frame count, frame index, and blob payload.
- `doc/aoo_protocol.md:182-199`: sink-to-source data requests for missing sequence/frame data.
- `doc/aoo_protocol.md:257-294`: ping/pong timing with NTP-style timestamps and loss percentage.
- `include/aoo_source.h:41-50`, `include/aoo_source.h:160+`: process/send API and controls for buffer size, resampling, dynamic resampling, packet size, and resend buffer.
- `aoo/src/source.cpp:577-610`: `AooSource_send` sends pending start/data/resend/ping work.
- `aoo/src/source.cpp:669-846`: `AooSource_process` is callback-facing, avoids blocking by try-locking update state, handles timing and dynamic resampling, and queues audio.
- `aoo/src/source.cpp:1896-2117`: `Source::send_data` reads the audio queue, encodes PCM/codec data, increments sequence, splits frames, stores optional history, then sends outside the lock.
- `aoo/src/source.cpp:2117-2254`: `Source::resend_data` handles resend requests from history.
- `aoo/src/sink.cpp:8-31`: `BUFFER_PLC` note warns PLC can reduce artifacts but may quantize buffering to format block size and increase latency.
- `aoo/src/sink.cpp:508-584`: `AooSink_process` is callback-facing and writes output without socket receive.
- `aoo/src/sink.cpp:952-1074`, `aoo/src/sink.cpp:1541-1665`: network message parse and packet queue insertion.
- `aoo/src/sink.cpp:2136-2255`: jitter queue handling, gap tracking, placeholders, and resend/out-of-order tracking.
- `aoo/src/sink.cpp:2268-2455`: playout waits for latency samples/blocks, handles incomplete blocks, fills zeros or decodes, and writes resampler.
- `aoo/src/sink.cpp:2516-2561`: missing block checks and resend requests.
- `aoo/src/resampler.cpp:40-146`: resampler method latency and reset behavior.
- `aoo/src/time_dll.hpp:13-60`: delay-locked-loop timing filter and samplerate estimate.

Thread model:

- AOO cleanly separates callback-facing `process` from network-facing `send` and `handle_message`.
- The source process path queues audio; the send path serializes and transmits.
- The sink network path queues packets; the process path consumes complete or missing blocks at audio time.

Packet format:

- AOO has a rich stream format: stream id, sequence id, source/sink ids, sample rate, channel count, block size, codec id, timestamps, frame indexes, and blob payload.
- PCM and Opus are both supported.
- Packet splitting is supported when encoded blocks exceed packet size.

Buffer/playout policy:

- AOO supports explicit sink latency, jitter buffering, dynamic resampling, and resend.
- Dynamic resampling is the most relevant concept for open-lola, but only if its fixed latency is known and included in the target.

Failure behavior:

- Missing frames can trigger resend requests.
- Incomplete blocks can be dropped or concealed, depending on configuration.
- Packet loss, reordering, resend, and timing telemetry are first-class events.

Adopt:

- API split: audio process path must not own network I/O.
- NTP/host-time style telemetry for drift and RTT.
- Dynamic drift correction concept.
- Explicit codec/sample-format metadata.

Benchmark:

- AOO PCM/no-codec path as a reference design for packet metadata and drift telemetry.
- Dynamic resampling with a fixed, declared latency.

Reject for fastest default:

- Resend/retransmission.
- Sink latency that waits for missing blocks.
- PLC that increases buffering by block quantization.
- Opus as default fastest mode.

### SonoBus Source Study

Studied snapshot: `35f1062dab196b9838a4bb529c4bf6592b7f5987`.

Relevant files and functions:

- `README.md:4-12`: SonoBus is a peer-to-peer low-latency audio app with uncompressed PCM and Opus options.
- `README.md:22`: wired Ethernet is recommended for lowest latency because Wi-Fi jitter/loss requires a larger safety buffer.
- `README.md:91-104`: SonoBus is built with JUCE and AOO.
- `Source/SonobusPluginProcessor.h:123-130`: auto network buffer modes and codec enum.
- `Source/SonobusPluginProcessor.h:160-174`: PCM and Opus format metadata, including minimum preferred block size.
- `Source/SonobusPluginProcessor.cpp:374-410`: UDP send callbacks for peer and client traffic.
- `Source/SonobusPluginProcessor.cpp:414-446`: `SendThread`, highest priority, waits/signals and calls `doSendData`.
- `Source/SonobusPluginProcessor.cpp:448-470`: `RecvThread`, highest priority, waits for UDP readiness and calls `doReceiveData`.
- `Source/SonobusPluginProcessor.cpp:2265-2404`: `doReceiveData` reads UDP, parses AOO patterns, routes to sinks/sources/client, and notifies send thread.
- `Source/SonobusPluginProcessor.cpp:3231-3262`: `doSendData` drains AOO source/sink/client send queues.
- `Source/SonobusPluginProcessor.cpp:3889-4095`: packet-loss events increase buffer time by one block in auto modes, and auto-full can later decrease after a no-drop interval.
- `Source/SonobusPluginProcessor.cpp:5168-5176`: dynamic resampling is applied to peer source/sink.
- `Source/SonobusPluginProcessor.cpp:5999-6074`: per-peer buffer time, source/sink setup, packet size, compact AOO data, ping interval, and dynamic resampling setup.
- `Source/SonobusPluginProcessor.cpp:6313-6337`: format conversion maps PCM to AOO PCM and Opus to `OPUS_APPLICATION_RESTRICTED_LOWDELAY`.
- `Source/SonobusPluginProcessor.cpp:7330-8061`: audio `processBlock` collects local send mix, calls remote sink `process`, calls source `process`, and handles echo/latency test paths.
- `Source/OptionsView.cpp:113-142`: UI explains default jitter buffer and says PCM has least latency and CPU load, while Opus saves bandwidth at latency cost.
- `Source/OptionsView.cpp:337`: auto-drop threshold tooltip states the jitter buffer increases after dropouts.

Thread model:

- Audio callback: JUCE `processBlock`, source/sink `process`, mix, meters, recording hooks, effects.
- Network receive thread: UDP read and AOO message dispatch.
- Network send thread: AOO send queue drain.
- Event, client, and server threads handle non-audio control work.

Packet format:

- SonoBus uses AOO for audio/control payloads and supports PCM and Opus.
- PCM formats include 16-bit, 24-bit, 32-bit float, and 64-bit float in code.
- Opus is configured with restricted-low-delay application mode.

Buffer/playout policy:

- The default product behavior favors usability and robustness: automatic buffer adjustment can increase jitter buffer after dropouts.
- Manual and initial auto modes exist, but the general app UI guides users toward adaptive safety.

Failure behavior:

- AOO block-lost events update per-peer drop counters.
- Auto modes increase `buffertimeMs` by one block on drop threshold violations.
- Ping events and no-drop intervals can complete initial auto behavior or reduce buffer in auto-full mode.

Adopt:

- Separate send and receive network threads.
- Per-peer telemetry for drop count, resend count, fill ratio, ping, estimated latency, and buffer time.
- PCM as lowest-latency known-good user-facing quality mode.
- Explicit UI-level warning that Wi-Fi forces larger safety buffers.

Benchmark:

- Restricted-low-delay Opus only for bandwidth fallback.
- Dynamic resampling if it does not increase selected playout target.

Reject for fastest default:

- SonoBus-style auto-jitter growth. It is correct for a general public app, but it violates open-lola fastest-mode invariants.
- Recording/effects/metering inside the minimal fastest engine. Those can exist in later modes or outside the critical path.

### macOS BSD UDP Hot Path

Fastest mode should use BSD UDP directly before considering higher-level transports.

Socket design:

- One connected UDP socket per peer is preferred for fastest mode after discovery, because it avoids per-send address setup and filters unexpected inbound traffic at the socket layer where supported.
- Use nonblocking sockets.
- Use a dedicated receive thread and a dedicated send thread, or one network thread per peer only if measurement shows lower jitter without CPU contention.
- Preallocate datagram buffers per peer. Reuse them.
- Put exactly one audio block in one datagram for default fastest mode. Avoid cross-block aggregation because it couples deadline risk between blocks.
- Keep payload below path MTU. For LAN tests, still measure fragmentation counters; do not assume jumbo frames.

macOS batching:

- `sendmmsg`/`recvmmsg` are not portable baseline APIs on macOS. Design for `sendmsg`/`recvmsg` or `sendto`/`recvfrom` first.
- Batching must not delay a block just to collect more blocks.
- If batching is tested, it is an optimization for bursts of control/video packets, not for fastest audio.

Socket options to benchmark:

- `SO_RCVBUF` and `SO_SNDBUF`: set enough queue room for OS jitter but keep application playout fixed. Bigger kernel queues do not justify later playout.
- `IP_TOS` for IPv4 and `IPV6_TCLASS` for IPv6 DSCP marking where permitted.
- macOS `SO_NET_SERVICE_TYPE` / voice service class as an OS scheduling hint.
- Receive timestamps where available. If kernel receive timestamps are unavailable or too costly, timestamp immediately after `recvmsg`.

Scheduler interaction:

- Audio callback owns the hard deadline.
- Network receive thread should run high priority but not real-time unless Audio Workgroup benchmarking shows a clear benefit and no system starvation.
- Network send thread should wake from SPSC publish or eventfd/pipe/kqueue-compatible wakeup, drain available blocks, and return to wait.
- Never let network thread locks enter the audio callback.

Packet header sketch for open-lola fastest mode:

| Field | Purpose |
|---|---|
| magic/version | reject wrong traffic quickly |
| stream id | distinguish peer/session |
| sequence | detect loss, late, reorder |
| frame count | verify block size |
| sample rate | detect mismatch |
| sample format | PCM16/PCM24/float32 |
| channel count | verify payload size |
| sender sample index | drift and playout placement |
| sender host time | RTT/drift diagnostics |
| flags | duplicate-current-block, test markers |
| header crc or checksum | reject corrupt header |

Failure policy:

- Late packet: count it as late, optionally keep for diagnostics, never move playout later.
- Missing packet: silence or same-deadline PLC.
- Reordered packet: accept only if it still meets current playout deadline.
- Network burst: drop older-than-deadline audio first; protect current audio block; video and lighting drop before audio.

### DSCP And QoS Test Plan

DSCP is not an architecture guarantee. RFC 2474 defines the DS field and RFC 3246 defines Expedited Forwarding behavior, but campus switches, Wi-Fi controllers, routers, VPNs, and firewalls may rewrite, ignore, or police marks.

Implementation:

- Add CLI flags for DSCP off, EF, AF class, and site-specific value.
- Mark IPv4 with `IP_TOS` and IPv6 with `IPV6_TCLASS`.
- On macOS, test `SO_NET_SERVICE_TYPE` separately from DSCP.
- Capture on both endpoints and at one managed switch mirror port where possible.

Test matrix:

| Test | Measurement |
|---|---|
| no marking | baseline p50/p95/p99 one-way delay, jitter, drop, reorder |
| EF marking | same metrics plus packet capture DSCP value |
| site-approved marking | same metrics plus switch queue counters if IT can provide them |
| background load | audio metrics while iperf competes on same path |
| Wi-Fi path | only as negative control unless fastest mode explicitly excludes it |

Outcome classification:

| Outcome | Evidence | Decision |
|---|---|---|
| honored | DSCP preserved end to end and p99 jitter/drop improve under load | allow as optional profile |
| rewritten | sender mark differs from receiver/mirror mark | document and disable by default |
| ignored | mark preserved but no metric change | keep off by default |
| harmful | p99 delay/drop worsens or policing appears | reject and warn |

## Direct UDP PCM Versus Network-Audio Standards

| Mode | Clock model | Transport/setup | Latency implication | Setup burden | Campus/network implication | Decision |
|---|---|---|---|---|---|---|
| Direct UDP PCM | app-level sender/receiver drift telemetry | app UDP packets | lowest software control, no PTP dependency | low | works on ordinary IP LAN if path is quiet | adopt fastest default |
| AVB | link-local AVB clocking and reservation | Ethernet AVB device exposed in Audio MIDI Setup | can be deterministic on supported local Ethernet | medium/high | needs AVB-capable endpoint/switch path; not general routed campus IP | benchmark local lab mode |
| TSN | time-aware Ethernet scheduling family | switch/NIC feature set and configuration | potentially deterministic but operationally heavy | high | requires TSN-capable network design | defer until infrastructure exists |
| AES67 | PTPv2, RTP, SDP/session management | interoperable AoIP profile | designed for low-latency LAN/pro audio, often sub-10 ms class | medium/high | needs multicast/PTP/QoS competence | benchmark as interoperability mode |
| RAVENNA | PTP, RTP, discovery/session tooling | AES67-compatible ecosystem plus vendor drivers | can be strong with dedicated driver/hardware | high | macOS often via vendor VAD; Linux may use driver/daemon | defer or benchmark with hardware |
| Dante | proprietary ecosystem with AES67 bridge | Dante devices/DVS/Controller | DVS documented 4/6/10 ms settings before app path | medium | operationally easy but proprietary and driver-bound | later interoperability mode |

Conclusion: direct UDP PCM remains the default fastest architecture because it controls block size, playout policy, and failure behavior directly. AVB/TSN/AES67/RAVENNA/Dante are not rejected; they are later or benchmark modes when deterministic clocking, hardware interoperability, or institutional infrastructure matters more than minimal app-controlled latency.

## Tier 2: Robustness Without Latency Growth

### PLC Boundary

PLC may only replace the contents of a block that is already missing at the current playout deadline. PLC may not:

- increase default receive target from zero/one block to two or more blocks;
- wait for future packets;
- wait for retransmission;
- require lookahead beyond packets already available at the deadline;
- run unbounded inference inside the audio callback;
- allocate or lock in the audio callback;
- change callback buffer size or device buffer size.

PLC candidates:

| Candidate | Cost | Strength | Risk | Decision |
|---|---|---|---|---|
| zero fill | minimal | deterministic | audible click/gap | adopt baseline |
| last-block hold with short fade | tiny | better than zero on sustained tones | poor on rhythm/transients | benchmark |
| Burg/AR | low/medium | plausible for monophonic or harmonic material | unstable on transients; parameter sensitive | benchmark |
| Tilt Loss trained model | medium/high | listening-test improvement reported for some music | inference CPU, model size, unpitched instruments | offline benchmark first |
| packet replay from duplicate-current-block | network/CPU | masks isolated loss without waiting | more packet load can worsen jitter | benchmark |

### Burg / AR PLC

The 2024 Burg paper studies autoregressive PLC for real-time networked music performance. Its core relevance is not that open-lola should adopt Burg immediately; it is that AR PLC can be small enough for real-time constraints and can be parameterized against computation time.

Implementation implication:

- Implement a separate benchmark binary first, not callback code.
- Inputs: previous valid samples only, no future lookahead.
- Output: exactly one missing block.
- Test AR order, analysis window length, channel policy, and fade/crossfade boundary.
- Bound runtime to a strict fraction of block time. For a 32-frame block at 48 kHz, the whole block is about 0.667 ms; callback-side Burg is likely too tight unless optimized C/C++ and small order prove otherwise.
- If PLC runs outside callback, it must prepare a substitute before the same current playout deadline; it still cannot move playout later.

Acceptance:

- p99 PLC compute time below 20 percent of block time on target Macs.
- No heap allocation after warmup.
- No NaN/inf output under impulses, silence, clipped input, or noise.
- Better listening result than zero fill and last-block hold for at least sustained and mixed music cases.

### Tilt Loss 2026

The Tilt Loss paper presents a perceptual training loss for music PLC. The key claim for open-lola is useful but narrow: changing the loss function can improve perceived PLC quality without adding inference cost relative to the same model architecture. The paper also reports limits, including unsatisfactory behavior for unpitched instruments and the lack of a reliable objective music-PLC metric.

Implementation implication:

- Treat Tilt Loss as a training/evaluation idea, not a runtime feature.
- Do not ship a neural PLC in fastest mode until inference is bounded, CPU headroom is measured, and fallback to silence/hold is guaranteed.
- If explored, start with offline corpus tests, then a non-realtime CLI, then an opt-in runtime profile.
- Model input may only use already-available context. Any design needing future packets or added lookahead is rejected for fastest mode.

Acceptance:

- Inference p99 under the same-deadline PLC budget.
- No GPU dependency.
- No model load/allocation on audio path.
- Objective metrics plus human listening tests. Objective metrics alone are insufficient for music PLC.

### Music PLC Evaluation Limits

Speech PLC metrics do not transfer cleanly to networked music performance. Music has tighter timing salience, broader spectral content, sustained harmonic material, percussive transients, and musician interaction constraints.

Benchmark content:

- solo sustained strings/winds;
- piano with attacks and decay;
- percussion/unpitched instruments;
- mixed ensemble;
- speech only as a negative control;
- silence and room noise;
- metronome/click-like transient sequence.

Loss patterns:

- single isolated block;
- two consecutive blocks;
- periodic loss every 100 ms;
- burst loss under load;
- late-arriving packet that misses deadline by less than one block;
- reorder where later packet arrives before current packet.

Metrics:

- block replacement rate;
- click/onset discontinuity energy;
- spectral delta;
- p99 compute cost;
- human ABX or MUSHRA-like listening panel for final candidates;
- musician playability tests after audio engine exists.

Pass/fail rule:

- A PLC candidate passes only if it improves perceived quality over zero fill without increasing default playout target or causing deadline misses.

### Drift Correction Without Buffer Growth

Clock drift must not be corrected by slowly growing the receive buffer in fastest mode.

Required telemetry:

- sender sample index per block;
- receiver playout sample index;
- sender host timestamp or monotonic time;
- receiver arrival time;
- observed block inter-arrival;
- cumulative sequence gaps;
- device nominal and measured sample rates.

Strategies:

| Strategy | Latency impact | Artifact risk | Decision |
|---|---|---|---|
| tiny adaptive resampler | fixed known filter latency | low if high quality and slow ratio changes | benchmark/adopt if fixed cost accepted |
| single-sample slip/drop with crossfade | no buffer growth | rare small artifact | benchmark for fastest mode |
| stretch over short window | no buffer growth if in-place | possible modulation | benchmark |
| grow receive buffer | increases latency | fewer dropouts | reject fastest default |

Drift controller contract:

- Estimate drift slowly; do not chase network jitter.
- Apply correction only below a small parts-per-million threshold unless a hard discontinuity is detected.
- Expose drift ppm and correction events in telemetry.
- Never hide drift problems by increasing playout target.

### Duplicate-Current-Block Experiment

Goal: test whether sending the same current audio block twice inside the same send window masks isolated packet loss without increasing playout depth.

Rules:

- Duplicate only the current block, not an older block that implies delayed recovery.
- Receiver accepts the first valid copy that arrives before deadline.
- Receiver discards duplicate copies after the deadline.
- Sender must not delay the primary copy to prepare the duplicate.
- Experiment must run with and without DSCP marking, and under background load.

Measurements:

- packet rate increase;
- wire bandwidth;
- CPU per peer;
- receiver p99 inter-arrival jitter;
- switch queue drops if available;
- missed audio deadline count;
- audible dropout rate.

Decision:

- Adopt only if isolated dropout reduction is significant and p99 jitter/deadline misses do not worsen.
- Reject on Wi-Fi or constrained paths if the extra packets increase contention.

## Tier 3: Later Modes

Tier 3 contains modes that can be valuable in production but must not define the fastest architecture. Each Tier 3 mode is opt-in, benchmarked against the Tier 1 UDP PCM baseline, and allowed to degrade or disable itself before it changes audio playout latency.

### Opus

Opus is a strong low-latency codec, but it is not fastest mode. RFC 6716 defines algorithmic delay ranges and CELT/MDCT lookahead. The Opus API includes `OPUS_APPLICATION_RESTRICTED_LOWDELAY`, and SonoBus uses that for Opus, but PCM still avoids codec delay and CPU.

Recommended Opus profile:

- Use only as `low-bandwidth-audio` mode.
- Prefer CELT/restricted-low-delay behavior for music; do not use speech-tuned defaults for musical reference audio.
- Keep frame size explicit and visible in telemetry.
- Disable in-band FEC for fastest comparison unless a fallback profile explicitly accepts the extra dependency on later packets.
- Keep encoder and decoder outside the Core Audio callback unless profiling proves bounded runtime and no allocation after warmup.
- Report algorithmic delay, packetization delay, encode p99, decode p99, and final analog end-to-end latency.

Use Opus when:

- bandwidth is constrained;
- remote access matters more than minimum latency;
- the user explicitly selects a fallback mode;
- measured end-to-end latency remains acceptable for the musical use case.

Do not use Opus when:

- testing the fastest local LAN path;
- benchmarking Core Audio callback safety;
- comparing against LoLa-style uncompressed assumptions.

Opus acceptance gates:

| Gate | Pass condition |
|---|---|
| latency | measured analog end-to-end latency stays within the selected fallback profile, not the fastest profile |
| CPU | encode/decode p99 does not cause audio callback deadline misses |
| quality | musician listening test beats reduced-rate PCM at same bandwidth or provides a clear bandwidth win |
| failure | packet loss concealment does not increase playout target |

### 5G And Edge

5G/edge belongs to constrained-access mode, not baseline architecture.

Reasons:

- public 5G performance can vary by cell, slicing, backhaul, edge placement, carrier policy, and device radio state;
- private 5G SA with edge can be promising but requires institutional infrastructure;
- open-lola fastest mode should first prove local wired Ethernet behavior.

Implementation implication:

- Keep transport abstraction narrow enough to allow remote relay/edge experiments later.
- Do not design the fastest audio core around cellular jitter buffers.
- Use 5G only with an explicit latency profile and a visible warning that it is not the reference mode.

5G mode split:

| Mode | Intended use | Architecture | Decision |
|---|---|---|---|
| public 5G | ad hoc access | ordinary mobile network to peer or relay | defer; not deterministic enough for reference mode |
| private 5G SA | institutional experiment | local private core plus controlled radio and edge | benchmark when infrastructure exists |
| 5G slice/MEC | research deployment | slice plus nearby media relay | benchmark only with operator-visible metrics |
| 5G plus wired endpoint | outreach/classroom | one side mobile, reference side wired | fallback profile only |

5G benchmark contract:

- Report radio technology, SA/NSA, carrier/private core, edge location, device model, signal metrics, and background traffic.
- Measure one-way delay distribution, jitter, packet error ratio, missed packet bursts, handover events, and uplink/downlink asymmetry.
- Run the same audio block size and packet format as wired mode first; change codec only after the raw path is characterized.
- Treat any jitter buffer increase as fallback-mode latency, never as fastest-mode success.
- Mark 5G results as environment-specific. Do not generalize a lab slice to public campus behavior.

### WebRTC And Browser NMP

WebRTC is valuable for access, NAT traversal, and browser support. It is not the baseline for fastest networked music because browser audio pipelines, mandatory codec paths, echo/noise processing defaults, jitter buffers, and opaque scheduling reduce control over the audio deadline.

Browser constraints:

- Request `echoCancellation: false`, `noiseSuppression: false`, and `autoGainControl: false` for music.
- Confirm actual `MediaStreamTrack.getSettings()` values; requested constraints are not proof that the browser applied them.
- Treat browser sample rate and channel count as negotiated facts, not assumptions.
- Expect Opus/RTP/WebRTC jitter behavior and NAT traversal machinery to be opaque compared with the Tier 1 UDP PCM path.

Use WebRTC when:

- browser participation is required;
- ease of access outranks minimum latency;
- a fallback mode can tolerate codec/jitter-buffer behavior.

Reject for fastest default:

- browser-owned jitter buffering;
- mandatory Opus path for reference audio;
- echo cancellation/noise suppression in music-critical mode.

WebRTC acceptance gates:

| Gate | Pass condition |
|---|---|
| access | browser user can join without native install |
| music settings | browser reports music-safe capture settings or UI warns that they are not guaranteed |
| latency | measured browser-to-native path is labeled fallback and never compared as fastest |
| isolation | WebRTC code cannot share the Core Audio callback or fastest UDP socket queues |

### VideoToolbox, JPEG XS, UltraGrid, And Hardware Offload

Video rule: video degrades before audio.

VideoToolbox:

- Use real-time compression/decompression properties only in video mode.
- Prefer capture settings that can drop late frames.
- Do not share audio callback deadline with video encode/decode.
- If hardware encoding spikes CPU/GPU/thermal pressure enough to affect audio callback p99, reduce video or disable it.
- Set `kVTCompressionPropertyKey_RealTime` for real-time encode experiments.
- Set `kVTCompressionPropertyKey_AllowFrameReordering` to false for low-latency H.264/HEVC experiments; B-frame reordering is incompatible with minimal delay.
- Consider `kVTCompressionPropertyKey_AllowTemporalCompression` false only for intra-only diagnostics, because bitrate can explode.
- For capture, use `AVCaptureVideoDataOutput.alwaysDiscardsLateVideoFrames = true` so video cannot accumulate delay behind audio.
- Avoid BGRA capture defaults where native pixel formats avoid conversion overhead.

JPEG XS:

- Useful later for visually lossless, low-latency professional IP video.
- Requires codec availability, licensing/tooling review, and likely hardware or optimized implementation.
- Treat as a video-lab path, not a first audio milestone.
- Evaluate only on links with sufficient bandwidth and predictable packet behavior.
- Prefer hardware or proven library paths; a slow software encoder is worse than a lower-quality VideoToolbox path for audio safety.

UltraGrid:

- Mature low-latency audio/video network transmission system worth studying for video transport, capture, and hardware paths.
- Do not import its architecture wholesale into fastest audio. Use it as a comparison and possible interop/prototype tool.
- Run as an external comparison tool first, not as an embedded dependency.
- Compare capture-to-display video latency and CPU load while open-lola audio runs independently.
- If UltraGrid audio is used in experiments, keep it separate from open-lola fastest-mode results.

Hardware offload:

- Accept only if measured audio callback p99 improves or video load no longer affects audio.
- Reject if driver latency, thermal pressure, or scheduling opacity hurts audio.

Video degradation ladder:

1. Drop late video frames.
2. Reduce video frame rate.
3. Reduce resolution.
4. Increase video compression.
5. Disable preview/render.
6. Disable video send.

Audio is never step 7. If video cannot coexist with audio at a given profile, the video profile fails.

### Embedded And Network-Audio Endpoints

Embedded endpoints are useful only if they reduce measured analog end-to-end latency or improve deterministic clocking.

Adopt/benchmark cases:

- dedicated audio interface with stable low Core Audio buffer support;
- AVB/AES67/RAVENNA endpoint with better clocking than Mac built-in paths;
- FPGA or embedded endpoint that proves lower analog latency in loopback tests.

Reject cases:

- endpoint adds driver/control software with opaque buffering;
- endpoint requires cloud services;
- endpoint improves setup aesthetics but not measured latency or determinism.

Tier 3 decision matrix:

| Mode | First experiment | Success metric | Default state |
|---|---|---|---|
| Opus | native low-bandwidth peer mode | acceptable musician QoE at constrained bandwidth | off |
| 5G/edge | private 5G or slice lab run | bounded packet delay and burst loss without buffer growth | off |
| WebRTC | browser-to-native fallback bridge | usable access with labeled latency cost | off |
| VideoToolbox | local camera send/receive while audio runs | no audio callback p99 regression | off until audio green |
| JPEG XS | lab video transport | lower video delay than VideoToolbox at acceptable CPU/link cost | defer |
| UltraGrid | external comparison | useful video baseline without touching audio core | external |
| embedded endpoint | analog loopback against Mac interface | lower measured e2e latency or better clocking | benchmark |

## Tier 4: Research Backlog And Interop Foundations

Tier 4 is the required research backlog before later implementation. It contains source-code studies, paper/standard reviews, and interoperability references that may inform Tier 1, Tier 2, and Tier 3. Tier 4 features do not enter fastest mode unless they pass the hard audio-latency rule.

### Tier 4 Checklist

| Item | Current dossier status | Decision |
|---|---|---|
| Read JackTrip packet and playout code | completed in source study | adopt compact header/thread boundary ideas; reject adaptive jitter as fastest default |
| Read AOO network and jitter code | completed in source study | adopt process/send split and telemetry; reject resend/jitter growth for fastest mode |
| Read SonoBus network and jitter code | completed in source study | adopt Opus fallback lessons and channel metadata; reject codec-first fastest mode |
| Read Corelink Audio paper and compare relay topology against direct UDP | added below | benchmark relay/fallback topology; reject as fastest default until analog e2e beats direct UDP PCM |
| Read NetMusic3D for multichannel/drift design | added below | benchmark channel metadata, drift telemetry, and multichannel packet sizing; reject dynamic jitter growth in fastest mode |
| Read Burg PLC and Tilt Loss papers | completed in Tier 2 | benchmark only inside already-missing block window |
| Build PLC benchmark that forbids added playout latency | completed in Tier 2 | required before PLC adoption |
| Read AES67-2023 and Dante 2025 ST 2110/AES67 update | added below and in Tier 1 comparison | benchmark interop mode; no fastest-mode dependency |
| Compare AES67/RAVENNA/AVB setup burden with direct UDP PCM | completed in Tier 1 matrix, expanded below | use as explicit setup-cost tradeoff |
| Study TSN WCRT/AVB-aware scheduling papers for worst-case metrics | added below | defer until controlled TSN infrastructure exists |
| Read JPEG XS RTP/FEC papers for later video | added below and in Tier 3 video | defer to video mode; video FEC must not harm audio packets |
| Read ANSI E1.31-2025 before implementing sACN | lighting subsection below | implementation gate |
| Read Art-Net 4 before implementing Art-Net | lighting subsection below | implementation gate |
| Study OLA and QLC+ as lighting interop references | lighting subsection below | use for interoperability tests |
| Study Open Fixture Library before inventing fixture metadata | lighting subsection below | defer import until real fixture patch use case |
| Study Chataigne/OpenFollow/PSN for show-control workflows | lighting subsection below | OSC/PSN bridge later; not audio path |

### Corelink Audio Relay Comparison

Corelink Audio is relevant because it is a JUCE-based NMP system that uses Corelink as a server-mediated routing layer. The public paper describes Corelink as data-agnostic and platform-neutral, with server/client components that support routing patterns such as pipelines, broadcasts, and multicasts. That is useful for multi-participant and multi-modal research sessions, but it is structurally different from the fastest direct UDP PCM target.

Observed implications:

- Corelink Audio uses JUCE audio processing plus a separate Corelink networking layer.
- The paper describes UDP transport and a jitter buffer between the network thread and JUCE audio processing thread.
- The reported latency table makes buffer count visible: a 64-sample audio buffer with a 10-buffer jitter buffer and a 128-sample audio buffer with a 5-buffer jitter buffer both land around 20 ms in that setup; larger jitter buffers push latency higher.
- The paper notes packet-drop and data-integrity artifacts and future quality-of-service tracking.
- The topology is valuable for routing and multi-modal collaboration, but its relay/server hop and jitter buffer make it a fallback/research topology, not the fastest local baseline.

Relay comparison:

| Topology | Path | Strength | Latency risk | open-lola decision |
|---|---|---|---|---|
| direct UDP PCM | Mac A to Mac B over controlled LAN | minimum moving parts, app owns packet deadline | no relay help; NAT/unicast setup burden | fastest default |
| Corelink relay | sender to Corelink server to receiver | dynamic routing, scalable group topology, multi-modal sessions | extra hop, central dependency, jitter buffer policy | benchmark as relay/fallback mode |
| rendezvous plus direct UDP | control server only, media direct | easier session setup while preserving direct media path | NAT and firewall complexity | best later compromise if direct peer setup is painful |

Hard rule: a relay cannot become fastest default unless measured analog end-to-end latency beats direct UDP PCM on the same devices, switches, sample rate, and block size. That outcome is unlikely, so Corelink Audio is an architecture comparison and fallback-mode reference.

### NetMusic3D Multichannel And Drift Notes

NetMusic3D is relevant for immersive networked music performance rather than the first stereo LAN milestone. The public thesis abstract describes real-time multichannel/spatial audio, Ambisonics, support for up to 64 channels, Corelink/JUCE implementation, Opus and LZMA compression options, dynamic jitter buffering, clock drift compensation through real-time resampling, and monitoring through a web UI.

Adopt for design:

- explicit channel layout metadata in packet/session descriptions;
- per-stream channel count, sample rate, sample format, and spatial layout telemetry;
- drift telemetry with sender and receiver sample clocks visible;
- adaptive resampling as a benchmarked fixed-latency drift correction path;
- multichannel MTU tests before assuming one-block-per-datagram still fits all channel counts;
- monitoring that shows jitter-buffer depth, drift ppm, late blocks, and resampling events.

Reject for fastest default:

- dynamic jitter-buffer growth;
- compression-first multichannel transport;
- web UI or relay control in the audio callback path.

Benchmark plan:

| Test | Constraint | Metric |
|---|---|---|
| stereo PCM | direct UDP baseline | analog e2e latency and missed deadlines |
| 4/8-channel PCM | same block deadline | packets per block, MTU fragmentation risk, p99 arrival age |
| Ambisonics payload | explicit channel layout metadata | CPU, bandwidth, late-block rate |
| drift correction | fixed playout target | ppm tracking error and audible artifacts |
| compressed fallback | opt-in only | bandwidth saved versus added codec delay |

### AES67, Dante 2025, And ST 2110 Notes

AES67-2023 remains the professional interoperability reference for high-performance audio-over-IP, but it is not a replacement for the direct UDP PCM fastest baseline. AES67 targets interoperability among existing AoIP systems and depends on a professional IP media-network environment, typically including PTP clocking, RTP streams, multicast/network configuration, SDP/session information, and device-specific setup.

Dante's 2025 ST 2110/AES67 update matters because it lowers some practical interoperability burden in Dante deployments. Audinate announced ST 2110-30 and AES67 configuration directly in Dante Controller, 96 kHz support, ST 2110-30 AX/BX/CX conformance support, broader multicast address configuration, custom RTP payload IDs, and PTPv2 clock DSCP settings. That improves Dante/AES67/ST 2110 interop as a later mode, but it still depends on Dante devices, firmware/software support, PTP behavior, and controller workflows.

Expanded setup-burden comparison:

| Path | Setup burden | Determinism lever | Fastest-mode issue | Decision |
|---|---|---|---|---|
| direct UDP PCM | choose peer IP, device, sample rate, block size, DSCP test | app-owned deadline and playout policy | no standards interop | fastest default |
| AES67-2023 | PTP domain, RTP stream, SDP/session config, multicast policy, AES67-capable endpoint | professional media clocking | app loses direct playout ownership | interop benchmark |
| RAVENNA | AES67 plus RAVENNA/AES67 device profile and tooling | professional AoIP clocking and routing | setup/tooling burden | interop benchmark |
| Dante/AES67/ST 2110 | Dante Controller, device firmware, AES67/ST 2110 settings, PTPv2/DSCP/multicast tuning | integrated device ecosystem | proprietary control plane and endpoint buffering | interop benchmark |
| AVB/TSN | AVB-capable NIC/switch/endpoints, gPTP, stream reservation, class setup | link-layer reservation and clocking | hardware and switch dependence | local lab benchmark |

Architecture implication: AES67/RAVENNA/Dante/AVB can be valuable endpoints or bridge modes, especially in professional venues. They do not replace the direct UDP PCM baseline until analog loopback plus network measurement proves a lower or more deterministic end-to-end result.

### TSN WCRT And AVB-Aware Scheduling

TSN and AVB scheduling papers are useful because they provide worst-case metrics instead of only average jitter. The AVB-aware TSN literature models Scheduled Traffic or Time-Triggered traffic, AVB shaped traffic, and Best Effort traffic sharing Ethernet infrastructure. Relevant mechanisms include global time synchronization, gate control lists, IEEE 802.1Qbv time-aware scheduling, credit-based shaping for AVB classes, frame preemption, and WCRT/WCD analysis.

For open-lola, these papers should shape the measurement language:

- report p50, p95, p99, max, and worst-case response time where the network model supports it;
- identify queue class, switch path, hop count, background traffic, and gate/shaper configuration;
- distinguish measured maximum delay from a proven bound;
- use AVB/TSN claims only when the actual switches/NICs/endpoints expose the relevant configuration;
- treat TSN scheduling as infrastructure mode, not an app-side substitute for audio deadline discipline.

TSN acceptance gates:

| Gate | Pass condition |
|---|---|
| topology | every switch and endpoint in the path is documented and TSN/AVB-capable where claimed |
| clocking | gPTP/PTP state and grandmaster are visible |
| load | tests include best-effort background load and competing AVB/media flows |
| bound | report measured max and, if possible, WCRT/WCD assumptions |
| isolation | TSN configuration does not require increasing audio playout depth |

### JPEG XS RTP/FEC Later Video

JPEG XS belongs to later video work. RFC 9134 defines RTP payload transport for ISO/IEC 21122 JPEG XS and describes JPEG XS as a low-latency, lightweight coding system with encode/decode latency confined to a fraction of a video frame. SMPTE/IP literature connects JPEG XS transport to RTP, ST 2110-22, and professional media workflows.

JPEG XS RTP/FEC implications:

- Use JPEG XS only for video profiles, never as an audio dependency.
- Keep video RTP queues separate from audio UDP queues.
- Treat any FEC, retransmission, or stream redundancy as video-only unless an audio-specific benchmark proves no playout increase.
- Measure whether FEC packet overhead increases audio p99 arrival age under shared-link load.
- Disable or degrade video FEC before audio latency changes.

Acceptance gates:

| Gate | Pass condition |
|---|---|
| video latency | capture-to-display latency is lower or more stable than the VideoToolbox path for the target profile |
| audio isolation | audio callback p99 and missed-deadline count do not regress when JPEG XS RTP/FEC is active |
| network | video packet rate, FEC overhead, multicast/unicast policy, and switch queue behavior are visible |
| fallback | video can drop frames or disable FEC without changing audio playout target |

### Lighting And Show-Control Follow-Up

Lighting is timestamped control data. It is never a dependency of the audio real-time path.

Standards and tools:

- Read ANSI E1.31-2025 before implementing sACN. The public ANSI page says E1.31-2025 revises 2018 and covers DMX512A transport over IP using an ACN subset, addressing, data format, network management, synchronization, and IPv4/IPv6.
- Read Art-Net 4 before implementing Art-Net. The official Art-Net page provides the Art-Net 4 Ethernet Communication Protocol specification.
- Study OLA for protocol/device interoperability. OLA includes Art-Net and E1.31/sACN plugins.
- Study QLC+ for operator workflows, fixture patching, Art-Net, sACN, OSC, MIDI, and cross-platform behavior.
- Study Open Fixture Library before fixture metadata. Use its JSON fixture model as reference instead of inventing a fixture schema first.
- Study Chataigne for show-control routing. It supports OSC, MIDI, DMX, Art-Net, sACN/E1.31, UDP/TCP, HTTP, MQTT, WebSockets, Ableton Link, and PosiStageNet.
- Study OpenFollow and PSN for tracking workflows. OpenFollow outputs PosiStageNet and OSC; PSN is position tracking data used by lighting/media systems.

Tier 4 product boundary:

- open-lola should not become a lighting console.
- open-lola may emit timing, transport, cue, level, and tracking-adjacent control data to lighting/show-control systems.
- Fixture patching, moving-light safety, cue programming, visualizer operation, and operator overrides belong to dedicated tools unless a later project explicitly changes scope.
- Lighting can follow audio timing, but audio cannot follow lighting scheduling.

Internal model:

- Lighting events are timestamped against the same monotonic show clock used for telemetry.
- Lighting scheduler runs outside audio callback.
- Audio can publish readonly timing state to a control queue; lighting cannot call back into audio.
- If CPU/network contention appears, lighting packets drop or coalesce before audio packets are affected.
- Lighting has its own bounded send queue with oldest-noncritical-drop behavior.
- Show-control events are idempotent where possible. Repeated state updates are coalesced; edge-triggered cues are acknowledged or explicitly marked best-effort.

sACN / Art-Net implementation constraints:

- No DMX universe send from audio callback.
- No fixture interpolation in audio callback.
- Use bounded queues between audio/show-clock state and lighting output.
- Prefer multicast/unicast mode based on network measurement and venue switch policy.
- Expose "audio protected" mode that rate-limits lighting output under load.

Protocol defaults to verify before implementation:

| Protocol | Transport defaults from public docs | Implication |
|---|---|---|
| sACN / ANSI E1.31 | UDP, default port 5568 in QLC+ docs, multicast examples `239.255.0.x`, universe id normally 1-based in QLC+ mapping, source priority 0-200 | good for standards-aligned DMX-over-IP; requires multicast policy review |
| Art-Net 4 | UDP, default port 6454 in QLC+ docs, broadcast by default with unicast option, universe mapping commonly 0-based for Art-Net | easy device compatibility; broadcast can be noisy and should be avoided on shared networks when unicast works |
| OSC | UDP or TCP depending implementation | best first show-control surface because messages are semantic and sparse |
| PSN / PosiStageNet | UDP tracking data, common multicast/client workflows | useful for position data, not for raw DMX output |

Implementation sequence:

1. OSC-only show clock and cue telemetry.
2. External interop with Chataigne and QLC+ using OSC.
3. Read ANSI E1.31-2025 and Art-Net 4 fully before direct DMX-over-IP output.
4. Add sACN output behind an `--experimental-lighting` flag.
5. Add Art-Net output only after unicast/broadcast behavior and node discovery are tested.
6. Add Open Fixture Library import only after a real fixture patching use case exists.
7. Add PSN/OpenFollow input only after video/tracking is needed for a concrete production.

Data model:

| Object | Fields | Owner |
|---|---|---|
| show clock | monotonic time, optional bar/beat, offset to audio sample index | open-lola telemetry |
| cue event | id, timestamp, label, payload, reliability class | show-control bridge |
| universe frame | protocol, universe, priority, 1-512 channel values, timestamp | lighting scheduler |
| fixture definition | manufacturer, model, modes, channels, capabilities | Open Fixture Library import |
| patch | fixture id, mode, universe, address, orientation metadata | operator/tool |
| tracking target | id/name, position, orientation, confidence, timestamp | PSN/OpenFollow bridge |

Reliability classes:

| Class | Example | Behavior under load |
|---|---|---|
| critical cue edge | start/stop cue, blackout command | send promptly, log failure, never block audio |
| continuous state | dimmer/color/pan/tilt stream | coalesce to latest value |
| telemetry | meters, network stats, performer position preview | drop first |
| discovery | ArtPoll, fixture scan | disable during fastest audio test |

Safety constraints:

- No automatic moving-light tracking in open-lola without an explicit human-operated show-control system downstream.
- No fixture metadata import from unreviewed sources into a live patch without operator confirmation.
- No lighting network discovery during audio latency benchmarks unless discovery itself is the test.
- No broadcast Art-Net on a shared academic network without prior network approval.
- No sACN multicast on unmanaged Wi-Fi for fastest-mode audio demonstrations.

Tier 4 acceptance gates:

| Gate | Pass condition |
|---|---|
| isolation | enabling lighting does not change audio callback p99 or playout target |
| network | lighting packet rate and multicast/broadcast behavior are visible and bounded |
| interoperability | QLC+ or OLA receives expected test universes/cues |
| operator control | lighting output has an obvious enable/disable and panic/off path |
| documentation | venue network assumptions and universe mappings are explicit |

## Implementation-Ready Architecture Contract

### Threads

| Thread | Owns | Cannot do |
|---|---|---|
| Core Audio callback | input capture, output playout, SPSC push/pop, timestamp, counters | sockets, locks, allocation, logging, UI, file, codec waits |
| UDP receive | socket read, timestamp, header validation, per-peer receive ring write | block audio callback, grow playout target |
| UDP send | read send ring, serialize header/payload, send datagram | wait for video/lighting, batch audio late |
| Drift/telemetry | drift estimate, stats aggregation, logs | mutate callback data without atomics/rings |
| Video | capture/encode/decode/render | block audio or own audio playout clock |
| Lighting | timestamped DMX/show-control output | call audio callback or force audio schedule |
| UI/recording | observe/configure, disk writes | hold real-time locks |

### Fastest Packet Contract

One block per UDP datagram:

```text
header(version, stream, seq, frame_count, sample_rate, channels,
       sample_format, sender_sample_index, sender_host_time, flags, crc)
payload(interleaved_or_planar_pcm)
```

Default payload format:

- PCM 24-bit or float32 for first benchmark, plus PCM16 if bandwidth tests need it.
- 48 kHz first; 96 kHz and 192 kHz as explicit benchmark modes.
- 1, 2, and multichannel measured separately.

### Fastest Playout Contract

- Receiver maintains a target of zero or one blocks.
- A block is playable only if sequence and format match and arrival beats the callback deadline.
- Missing block policy is silence first, then same-deadline PLC only after benchmark acceptance.
- No default adaptive jitter growth.

### Verification Contract For Future Implementation

Before a feature enters fastest mode:

- prove no callback allocation after warmup;
- prove no callback lock contention;
- run fixed 32-frame and fallback 64-frame tests;
- measure analog end-to-end latency;
- measure p99 callback duration and network arrival age;
- show late/missing block behavior without buffer growth;
- run with video and lighting disabled, then enabled as subordinate stress tests.

## Decision Table

| Bucket | Decision |
|---|---|
| adopt now | Core Audio HAL/AUHAL/direct `AudioDeviceIOProc`; BSD UDP PCM; fixed tiny playout target; per-peer sequence/timestamp header; SPSC audio/network handoff; silence on missing block; analog loopback measurement; video/lighting subordinate |
| benchmark | Audio Workgroups helper threads; DSCP and macOS service class; Burg/AR PLC; Tilt Loss inspired PLC; duplicate-current-block packets; adaptive resampling with fixed known latency; Corelink Audio relay/fallback mode; NetMusic3D-style multichannel/drift experiments; AVB local lab mode; AES67/RAVENNA/Dante/ST 2110 interoperability mode; VideoToolbox video path |
| defer | Opus fallback; 5G/edge; WebRTC/browser; TSN WCRT infrastructure claims; JPEG XS RTP/FEC; UltraGrid video integration; embedded endpoints; sACN; Art-Net; OLA/QLC+ interoperability; Open Fixture Library import; Chataigne/OpenFollow/PSN workflows |
| reject | retransmission waits; TCP/QUIC fastest transport; adaptive receive-buffer growth in fastest mode; codec-first fastest mode; PLC needing future lookahead; video-driven audio clock; lighting in audio callback; UI/recording on critical path |

## Open Questions

1. Which initial interface should be the reference device: built-in Mac audio, a specific USB/Thunderbolt interface, or an AVB/AES67/RAVENNA endpoint?
2. Is the first performance target 48 kHz at 32 frames, or should 96 kHz at 32 frames be measured in the same first milestone?
3. Should fastest-mode PCM be float32 for implementation simplicity or PCM24 for bandwidth realism?
4. Will HfMT network staff provide switch mirror/QoS counters for DSCP tests?
5. Should lighting be OSC-first for the first show-control prototype, with sACN and Art-Net after standards review?

## Acceptance Checklist

- Tier 1 Core Audio HAL/AUHAL, `AudioDeviceIOProc`, buffer sizing, latency properties, Audio Workgroups, and real-time callback constraints are covered.
- JackTrip, AOO, and SonoBus source studies include URL, commit hash, relevant files/functions, thread model, packet/buffer policy, failure behavior, and adopt/reject/defer conclusions.
- macOS BSD UDP hot path covers socket design, QoS/DSCP, queueing, timestamps, batching limits, and scheduler interaction.
- Direct UDP PCM is compared against AVB, TSN, AES67, RAVENNA, and Dante.
- Tier 2 covers Tilt Loss, Burg/AR PLC, PLC benchmark rules, drift correction without buffer growth, duplicate-current-block experiments, and QoS/DSCP outcomes.
- Tier 3 covers Opus, 5G/edge, WebRTC/browser, VideoToolbox, JPEG XS, UltraGrid, hardware offload, and embedded/network-audio endpoints.
- Tier 4 covers JackTrip/AOO/SonoBus code study follow-up, Corelink Audio relay comparison, NetMusic3D multichannel/drift design, AES67-2023 and Dante 2025 ST 2110/AES67 notes, TSN WCRT/AVB-aware scheduling metrics, and JPEG XS RTP/FEC later-video constraints.
- Lighting/show-control inside Tier 4 covers ANSI E1.31-2025 / sACN, Art-Net 4, OLA, QLC+, Open Fixture Library, Chataigne, OpenFollow, and PSN.
- The hard rule is preserved throughout: no robustness, video, or lighting mechanism may increase default audio playout latency.
