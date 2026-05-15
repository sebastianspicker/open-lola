# Lola Connector Protocol RE Notes

Workspace: `C:\Users\sebastian\Desktop\LolaGuiPackage_2.0.0_XIMEA_x64_420`

Static rerun date: 2026-05-07

Purpose: provide enough reverse-engineered protocol detail to build a connector that can establish a LoLa-compatible connection and exchange control, chat, audio, and video data with LoLa 2.0.0 XIMEA x64.

## Executive Model

LoLa uses three transport layers:

1. Control plane: ordinary Winsock UDP text messages on `socketport`, default `7000`.
2. AV wrapper: manually built Ethernet + IPv4 + UDP packets injected/captured with WinPcap/Npcap.
3. AV payload: LoLa's own stream serialization and fragmentation inside UDP payloads.

The control plane negotiates parameters and starts local workers. It does not provide media reliability. Audio/video frames are UDP/pcap streams with sequence counters and receive-side drop counters only.

Default ports from `LolaGui.ini` and manual section 3.9:

| Purpose | Config key | Default |
| --- | --- | ---: |
| Control/service UDP | `socketport` | `7000` |
| Audio stream UDP | `audioport` | `19788` |
| Video stream UDP | `videoport` | `19798` |

For a connector, the practical requirement is:

- Implement UDP 7000 `/MESG_*` messages exactly enough for QuickConn/ACK/Reject/Disconnect/Chat/status.
- Inject or send UDP packets that LoLa receives on `audioport` and `videoport` with the recovered payload format.
- If communicating at Layer 3 through a normal UDP socket, the inner LoLa payload format still applies, but LoLa itself transmits through pcap raw Ethernet frames and its RX path is pcap capture.
- Match audio parameters exactly: channels, sample rate, and bits per sample. Video parameters are negotiated/displayed, but the static validation gate checks only audio.

## Static Evidence Map

Primary functions:

| Area | Function | Evidence |
| --- | --- | --- |
| Control formatter | `FUN_14001fb60` | `/MESG_*` string formats and message IDs |
| Control UDP sender | `FUN_14001ffa0` | creates UDP socket and `sendto(..., 0x400, ...)` |
| Control UDP listener | `FUN_140020110` | binds socketport, receives up to `0x1000`, dispatches `/MESG_` |
| Control parser | `FUN_14001f390` | dispatches QuickConn, ACK, Reject, Chat, status |
| Outbound connect | `FUN_14002b9b0` | sends QuickConn, waits for ACK/reject flags, starts AV |
| Inbound QuickConn | `FUN_14002f3d0` | parses remote params, validates, sends ACK/reject, starts AV |
| Compatibility check | `FUN_140029150` | checks audio channels, sample rate, bits/sample only |
| Chat/remote commands | `FUN_14002d090`, `FUN_1400329a0` | parses chat commands, chunks responses as `/MESG_CHAT` |
| RX pcap setup | `FUN_140016f20` | adapter selection, BPF, pcap open, starts RX thread |
| RX thread | `FUN_1400152d0` | parses pcap frames, reassembles audio/video |
| Audio TX setup/thread | `FUN_14000a000`, `FUN_140009bf0` | opens pcap TX handle, serializes PCM, sends packets |
| Video TX setup/thread | `FUN_140012490`, `FUN_140011590`, `FUN_1400115c0`, `FUN_140011c10` | raw/JPEG video TX, prelude and fragments |
| Raw frame builder | `FUN_140020ba0` | Ethernet/IP/UDP header construction |
| Fragment encoder/reassembler | `FUN_140006c50`, `FUN_1400070b0`, `FUN_140006f00`, `FUN_140007200` | LoLa AV fragmentation format |

Fresh rerun artifacts:

- `pe_report.json`, `resources_summary.json`, and `string_locations.json` were regenerated.
- `rizin_protocol_deep_disasm.txt` was added for functions not covered by the previous Ghidra export, especially `FUN_140029150`, `FUN_1400329a0`, and `FUN_140020ba0`.
- `LOLA_STATIC_SOURCE_RECON.md` was added as the source-like reconstruction layer for structs, lifecycle, thread ordering, and connector pseudocode.
- `rizin_lifecycle_disasm.txt` and `rizin_control_helpers_disasm.txt` were added for disconnect/reset helpers and control field extraction.

## Source Reconstruction Companion

For implementation work, read this protocol contract together with `LOLA_STATIC_SOURCE_RECON.md`.

The deeper static pass recovered:

- Top-level session ownership: two session slots at main `+0x1ae8/+0x1af0`, shared video TX at `+0x1af8`, shared audio TX at `+0x1b00`, and per-session active bytes at `+0x1b18/+0x1b19`.
- Control runtime scratch fields used by outbound ACK/reject waiting: `+0x60` is the replied/status flag and `+0x61` is QuickConn success.
- Per-session RX fields: remote IP at `+0x48`, pcap RX handle at `+0x50`, run flag at `+0x24c`, stopped flag at `+0x24d`, remote AV parameters at `+0x2b0..+0x2e0`, RX stopped event at `+0x318`, and selected session/NIC config at `+0x328`.
- Exact stop behavior: disconnect sends `/MESG_DISCONNECT`, clears the RX run flag, waits up to 1000 ms for the RX stopped event, stops audio/video TX for that session, clears the remote IP, and resets UI/session-active state.
- The key/value parser tokenizes only on `;` and removes a requested prefix from the first matching token; there is no escaping layer for semicolons in `TXT`.

## Control Plane

Control messages are ASCII, semicolon-delimited, and begin with `/MESG_`.

LoLa-originated control sends are fixed-size UDP datagrams:

- Sender: `FUN_14001ffa0`
- Socket: `socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)`
- Destination port: configured `socketport`
- Source is explicitly bound to local `SRCIP`
- Buffer copied into a 1024-byte stack buffer
- Send call: `sendto(socket, buffer, 0x400, 0, ...)`

Receiver behavior:

- Listener: `FUN_140020110`
- Binds UDP `socketport` on `INADDR_ANY`
- `recvfrom(..., 0x1000, ...)`
- Converts receive buffer to `CString`
- Dispatches only if `/MESG_` is found at offset 0
- Parser: `FUN_14001f390`

Connector note: a connector should accept padded control datagrams and should be prepared to send datagrams of 1024 bytes for strict compatibility. The text portion is normal NUL-terminated or NUL-padded ASCII from LoLa's stack buffer.

## Control Message Catalog

`FUN_14001fb60` maps message IDs to strings:

| ID | Message |
| ---: | --- |
| `0x800c` | `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d` |
| `0x800d` | `/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;` |
| `0x800f` | `/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s` |
| `0x8010` | `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d` |
| `0x8012` | `/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;` |
| `0x8013` | `/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;` |
| `0x8014` | `/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;` |
| `0x8015` | `/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;` |
| `0x8016` | `/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s` |
| `0x8017` | `/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d` |
| `0x8018` | `/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d` |

Field meanings:

| Field | Meaning |
| --- | --- |
| `SRCIP` | sender IPv4 string |
| `DSTIP` | receiver IPv4 string |
| `SID` | session id/tab index, observed as small integer |
| `SR` | audio sample rate, formatted as integer from double |
| `BPS` | audio bits per sample |
| `CHNLS` | audio channel count |
| `FPS` | video frame rate, formatted as integer from double |
| `BPP` | video bits per pixel |
| `X` | video width |
| `Y` | video height |
| `COMP` | compression mode, `0` raw/uncompressed, `1` JPEG path |
| `BAYER` | Bayer flag as `0`/`1` |
| `TXT` | reject/chat text payload |

## Handshake State Machine

Outbound connector-to-LoLa connect:

1. Send `/MESG_QUICKCONN` to LoLa's `socketport`.
2. Use connector local IP as `SRCIP`, LoLa target IP as `DSTIP`.
3. Include the connector's intended audio/video parameters.
4. Wait for `/MESG_QUICKCONN_ACK` or `/MESG_REJECT`.
5. On ACK, start sending AV packets immediately and listen for LoLa's AV packets.

LoLa outbound connect to connector:

1. LoLa sends `/MESG_QUICKCONN`.
2. Connector must parse fields and decide whether to accept.
3. To accept, reply `/MESG_QUICKCONN_ACK` with `SRCIP`/`DSTIP` reversed from the incoming message and with connector media parameters.
4. To reject, reply `/MESG_REJECT;...;TXT:<reason>`.
5. After ACK, both sides are expected to start media TX/RX.

LoLa's own outbound wait behavior:

- `FUN_14002b9b0` sends QuickConn.
- It waits in 100 ms increments until parser flags say ACK/success or reject/reply.
- Loop bound is 2000 ms in decompilation; UI error text says 3 seconds.
- Success flag is set by the parser when `/MESG_QUICKCONN_ACK` arrives.
- Reject flag/message is set by the parser when `/MESG_REJECT` arrives.

LoLa inbound QuickConn behavior:

- `FUN_14002f3d0` handles parser UI message `0x8002`.
- It extracts `SRCIP`, `DSTIP`, and `SID`.
- It searches session slots for a free/matching slot.
- If busy, sends `/MESG_REJECT` with:
  `Lola is running but it is currently busy.\nPlease retry later.`
- It parses `CHNLS`, `FPS`, `BPP`, `X`, `Y`, `SR`, `BPS`, `COMP`, `BAYER`.
- It calls `FUN_140029150` compatibility validation.
- If validation fails, sends `/MESG_REJECT` with generated text.
- If validation succeeds, sends `/MESG_QUICKCONN_ACK`, marks session connected, starts display/audio/video/RX workers.

Compatibility validation:

`FUN_140029150` checks only:

- local channel count vs remote `CHNLS`
- local sample rate vs remote `SR`
- local bits per sample vs remote `BPS`

Failure text is built from:

- `Unable to establish a valid connection due to the following reason(s):`
- `- Number of audio channels doesn't match (Loc. %d ch. - Rem. %d ch.)`
- `- Audio Sampling Rate doesn't match (Loc. %d Hz - Rem. %d Hz)`
- `- Audio Bits Per Sample don't match (Loc. %d bit - Rem. %d bit)`
- `Please correct your local settings and try again.`

Connector requirement: if the connector wants LoLa to accept its QuickConn, it must match LoLa's configured audio `NumOfChannels`, `SamplingRate`, and `bitPerSample`. Video dimensions/FPS/compression are parsed and used for remote display/RX setup, but they are not part of this static reject gate.

## Status, Disconnect, Chat, Remote Commands

Status:

- Incoming `/MESG_CHECKLOLASTATUS` causes LoLa to reply `/MESG_CHECKLOLASTATUS_ACK`.
- Incoming `/MESG_CHECKLOLASTATUS_ACK` sets a parser status flag.

Disconnect:

- Incoming `/MESG_DISCONNECT` posts UI message `0x8003`.
- Disconnect cleanup itself is in UI/session code beyond the parser.

Chat:

- Incoming `/MESG_CHAT;...;TXT:<text>` stores text and posts UI message `0x8006`.
- `FUN_1400329a0` sends chat text through message ID `0x8016`.
- Long outbound chat/remote-info text is chunked in `0x400` byte steps.
- First local display chunk is prefixed with `REMOTE: \r\n`.
- If a chunk text is <= `0x400`, CRLF/blank-line text may be appended before sending.

Built-in chat commands parsed in `FUN_14002d090`:

| Chat text | Behavior |
| --- | --- |
| `lola.GetRemoteInfo()` | Produce remote/session info response through chat |
| `lola.ResetRemoteInfo()` | Reset remote info state |
| `lola.GetRemoteSettings()` | Produce settings info through chat |
| `lola.SetRemoteAudioBuffer(<n>);` | Set remote audio buffer UI/control state, call audio buffer setter, respond with confirmation |
| `lola.ForceDisconnect(<name>);` | Force disconnect a session and respond with confirmation |

Connector note: these command strings travel as normal `TXT` in `/MESG_CHAT`. They are not a separate protocol layer.

## Pcap and NIC Model

LoLa does not use normal Winsock send for audio/video. It opens pcap devices and injects raw Ethernet frames.

RX pcap setup `FUN_140016f20`:

- Stores remote IP at RX object `+0x48`.
- Stores configured NIC name at RX object `+0x320`/`+800`.
- Stores session/config pointer at RX object `+0x328`.
- Stores stream mode/compression selector at `+0x250` and `+0x2dc`.
- Calls `pcap_findalldevs`.
- If `NicDevName` is non-empty, selects a pcap device whose name contains that string.
- Calls `FUN_140020660` to correlate pcap device name with `GetAdaptersInfo`.
- Opens capture handle:
  `pcap_open(device_name, 0x10000, 8, 500, ...)`
- Calls:
  `pcap_setmintocopy(handle, WinPcap_SetMinToCopy)`
- Default BPF:
  `ip and udp`
- If `RxPacketFiltering != 0`, BPF format:
  `ip and src host %s and dst host %s and (udp port %d or udp port %d)`
- Compiles/sets filter, then starts RX thread `FUN_1400160c0` -> `FUN_1400152d0`.

Adapter metadata `FUN_140020660`:

- Allocates `GetAdaptersInfo` buffer.
- Finds Windows adapter whose `AdapterName` occurs inside the pcap device name.
- Stores local IP, gateway IP, local MAC, gateway MAC, adapter name/description.
- Gateway MAC is resolved with `SendARP(gatewayIP, 0, ...)`.
- If `SendARP` fails, it logs `SendARP Failed. No default gateway` but can still mark adapter valid.

Connector note: LoLa TX uses the resolved gateway MAC as destination MAC when sending off-LAN. Same-LAN behavior may depend on ARP/gateway configuration as recovered through the adapter info structure. If the connector is not on the same L2 domain, normal routed UDP to LoLa may still be captured by LoLa's pcap RX if the host receives it on the chosen NIC and BPF matches.

## Outer AV Packet Layout

`FUN_140020ba0` builds a complete Ethernet/IPv4/UDP frame. Payload starts at byte offset `0x2a`.

Ethernet:

| Offset | Size | Meaning |
| ---: | ---: | --- |
| `0x00` | 6 | destination MAC |
| `0x06` | 6 | source MAC |
| `0x0c` | 2 | EtherType IPv4, bytes on wire should be `08 00` |

IPv4 header at frame offset `0x0e`:

| Frame offset | IP field | Value |
| ---: | --- | --- |
| `0x0e` | version/IHL | `0x45` |
| `0x10` | total length | `payload_len + 0x1c`, network order |
| `0x12` | identification | `0x1337`, network order |
| `0x14` | flags/fragment offset | `0` |
| `0x16` | TTL | `0x80` |
| `0x17` | protocol | `0x11` UDP |
| `0x18` | IP checksum | computed by `FUN_140020a10` |
| `0x1a` | source IPv4 | 4 bytes |
| `0x1e` | destination IPv4 | 4 bytes |

UDP header at frame offset `0x22`:

| Frame offset | UDP field | Value |
| ---: | --- | --- |
| `0x22` | source port | audio/video port, network order |
| `0x24` | destination port | same audio/video port, network order |
| `0x26` | UDP length | `payload_len + 8`, network order |
| `0x28` | UDP checksum | computed by `FUN_140020a80` |
| `0x2a` | LoLa payload | audio/video payload |

Static TX paths pass identical source and destination UDP ports for each stream: audio uses audio port, video uses video port.

## LoLa Byte Streams

LoLa serializes frame payloads through simple byte-stream helpers:

- `FUN_140004ff0(stream, ptr, n)` writes `n * 4` bytes.
- `FUN_140004e40(stream, ptr, n)` writes `n` bytes.
- `FUN_140004d60(stream, ptr, n)` reads `n * 4` bytes.
- `FUN_140004c40(stream, ptr, n)` reads `n` bytes.

Fields written this way are host-order/little-endian in the serialized LoLa payload, not network-order.

Serialized media payload for both audio and video:

```text
uint32_le sequence
uint32_le media_payload_length
byte[media_payload_length] media_payload
```

For audio, `media_payload` is PCM callback data.

For raw video, `media_payload` is raw frame bytes.

For compressed video, `media_payload` is JPEG bytes from IJG `jpeg_mem_dest`.

## Normal Fragment Payload Header

`FUN_140006c50` constructs `flFMTDataEncoder`. Default packet size is `0x400`.

`FUN_140007250` clamps packet size:

- minimum `0x80`
- maximum `0x2000`

`FUN_1400070b0` fragments the serialized media payload into chunks of:

```text
chunk_capacity = packet_size - 0x21
```

Each normal UDP payload begins with a 0x21-byte LoLa fragment header:

| Payload offset | Size | Value/meaning |
| ---: | ---: | --- |
| `0x00` | 4 | magic `fd fd fd fd` |
| `0x04` | 4 | magic `df df df df` |
| `0x08` | 4 | sentinel `ee ee ee ee` |
| `0x0c` | 4 | `uint32_le frame_id` |
| `0x10` | 4 | `uint32_le total_fragment_count` |
| `0x14` | 4 | `uint32_le fragment_index` |
| `0x18` | 4 | `uint32_le original_payload_offset` |
| `0x1c` | 4 | `uint32_le fragment_payload_length` |
| `0x20` | 1 | flag byte |
| `0x21` | n | fragment payload bytes |

The encoder writes the first two magic dwords as one 64-bit constant in little-endian:

```text
fd fd fd fd df df df df
```

Reassembly:

- `FUN_140006f00(reasm, frame_id, expected_size, fragment_count)` allocates/clears output buffer and duplicate bitmap.
- `FUN_140007200(reasm, fragment_payload)` checks matching `frame_id`, fragment index, duplicate bitmap, then copies bytes from payload offset `0x21` to `original_payload_offset`.
- `FUN_140006e80(reasm)` returns complete when received fragment count equals expected count.
- `FUN_140006e90(reasm, &ptr, &size)` returns the reassembled serialized media payload.

## Video Prelude Packet

Video has an extra packet before normal 0x21 fragments. This is the most important connector detail not represented by the first-pass decoder.

Before each video frame's normal fragments, LoLa sends one UDP payload of length `0x40`. The corresponding UDP length is `0x48` including the 8-byte UDP header.

Prelude magic at payload offsets:

| Payload offset | Size | Value |
| ---: | ---: | --- |
| `0x00` | 4 | `0xfdfdfdfd` |
| `0x04` | 4 | `0xdfdfdfdf` |
| `0x08` | 4 | `0xaaaaaaaa` |

Recovered fields used by RX:

| Payload offset | Size | Meaning |
| ---: | ---: | --- |
| `0x10` | 4 | `uint32_le frame_id` |
| `0x14` | 4 | `uint32_le expected_serialized_payload_size` |
| `0x1c` | 4 | `uint32_le total_fragment_count` |

TX evidence:

- Raw video TX copies 0x20 bytes from video object fields around `+0x11c0` into a stack prelude and sends it with payload length `0x40`.
- JPEG video TX does the same.
- The constructor initializes prelude magic at video object offsets:
  `0x11c0 = 0xfdfdfdfd`, `0x11c4 = 0xdfdfdfdf`, `0x11c8 = 0xaaaaaaaa`.

RX evidence:

- In raw and JPEG modes, RX checks:
  first dword `0xfdfdfdfd`, second `0xdfdfdfdf`, third `0xaaaaaaaa`, UDP length `0x48`.
- RX then calls:
  `FUN_140006f00(video_reasm, frame_id, expected_size, fragment_count)`.
- Only after this prelude does RX accept normal 0x21 fragment packets for the frame.

Connector requirement: to send video to LoLa, send the 0x40 prelude first, then all normal fragment packets for that frame. Audio does not use this video prelude in the recovered RX path.

## Audio TX Format

Audio TX thread: `FUN_140009bf0`.

Trigger:

- PortAudio callback `FUN_14000ad00` writes local audio into a double buffer and signals event at audio object `+0x30`.
- Audio TX waits on that event.

Serialization per callback:

```text
uint32_le sequence      // audio object +0x18e8, incremented per callback
uint32_le pcm_len       // recovered as *(ushort *)(audio+0x3a) << 7
byte[pcm_len] pcm_data  // from audio object +0x1288 or generated/silence buffer
```

With the usual 64-frame callback and 16-bit samples, `pcm_len` is:

```text
channels * 64 frames * 2 bytes = channels << 7
```

The thread fragments this serialized payload with `flFMTDataEncoder`.

Important audio fragment behavior:

- It obtains fragment 0 and sets header flag byte `0x20` to `1`.
- It sends through `pcap_sendpacket`, not pcap send queues.
- It sends to each active session slot.
- UDP source and destination ports are both `audioport`.

RX expects one audio fragment:

- Audio RX initializes reassembly using frame id from fragment offset `0x0c`.
- Expected serialized size is `remote_channels * 0x80 + 8`.
- Fragment count is hard-coded as `1`.

Connector requirement: send audio as a single normal fragment per callback if you want to match LoLa RX. A multi-fragment audio packet may not be accepted because RX initializes audio reassembly with fragment count 1.

## Audio RX Behavior

In `FUN_1400152d0`, audio packets are recognized when:

- UDP source port equals config/session port at offset `+0x100`, strongly mapped to `audioport`.
- Captured source IP string equals the negotiated remote IP stored at RX object `+0x48`.

RX flow:

1. Initialize audio reassembly with expected size `channels * 0x80 + 8`, fragment count `1`.
2. Apply `FUN_140007200` to the received normal fragment.
3. Read `uint32_le sequence`.
4. Read `uint32_le pcm_len`.
5. Read `pcm_len` bytes into the remote audio ring buffer.
6. Track sequence gaps, complete frames, incomplete/drop counts, and ring-buffer realignment/overflow.

The remote audio ring is 100 entries. `RemoteAudioBuffers` from `LastSsn.ssn` drives buffering; chat command `lola.SetRemoteAudioBuffer(n);` can change it.

## Video TX Format

Selector:

- `FUN_140011590`
- If `video+0x1114 == 1`, use JPEG TX `FUN_140011c10`.
- Otherwise use raw TX `FUN_1400115c0`.

Common serialized payload:

```text
uint32_le sequence
uint32_le video_payload_length
byte[video_payload_length] video_payload
```

Raw mode:

- Waits for frame-ready event at `video+0x450`.
- Serializes sequence at `video+0x1188`.
- Serializes raw frame length.
- Serializes raw frame bytes from `video+0x1838`.

JPEG mode:

- Compresses frame bytes from `video+0x1838` using IJG JPEG.
- Source dimensions:
  - width `video+0x10c8`
  - height `video+0x10cc`
  - bits per pixel `video+0x10dc`
- JPEG quality from config object field `+0x9c`, matching `CompressionQuality`.
- Serializes sequence, compressed byte count, compressed bytes.

Per frame TX order:

1. Serialize media payload.
2. Fragment serialized payload with normal LoLa 0x21 fragment headers.
3. Fill prelude fields:
   - frame id from encoder
   - expected serialized byte size
   - packet/fragment sizing metadata
   - fragment count
4. Queue/send the 0x40 prelude packet.
5. Queue/send every normal fragment packet.
6. Set normal fragment flag byte `0x20 = 1` on the last fragment.
7. Transmit pcap send queues.

Video TX uses pcap send queues:

- `pcap_sendqueue_alloc((packet_size + 0x32) * 0x1e)`
- `pcap_sendqueue_queue`
- `pcap_sendqueue_transmit`
- `pcap_sendqueue_destroy`

If queueing fails/fills, LoLa transmits the current queue, destroys it, allocates a new queue, and queues the current packet again.

## Video RX Behavior

In `FUN_1400152d0`, video packets are recognized when:

- UDP source port equals config/session port at offset `+0xfc`, strongly mapped to `videoport`.
- Captured source IP string equals the negotiated remote IP stored at RX object `+0x48`.
- RX mode `+0x250` selects raw (`0`) or compressed/JPEG (`1`).

Raw mode flow:

1. Wait for video prelude magic and UDP length `0x48`.
2. Initialize video reassembler from prelude `frame_id`, `expected_size`, `fragment_count`.
3. For subsequent normal fragments, apply `FUN_140007200`.
4. If complete, parse serialized payload:
   - `uint32_le sequence`
   - `uint32_le frame_len`
   - raw frame bytes
5. Copy raw bytes into remote video frame ring.
6. Signal remote video display event.

JPEG mode flow:

1. Same prelude and reassembly as raw mode.
2. Parse serialized payload:
   - `uint32_le sequence`
   - `uint32_le jpeg_len`
   - JPEG bytes
3. If CPU decode is enabled (`OptimizeJpegDecompression` path indicates normal CPU decode when config field `+0xa0 == 0`):
   - `jpeg_CreateDecompress`
   - `jpeg_mem_src`
   - `jpeg_read_header`
   - `jpeg_start_decompress`
   - `jpeg_read_scanlines`
   - `jpeg_finish_decompress`
   - `jpeg_destroy_decompress`
4. Store decoded scanlines into remote video ring and signal display.
5. In the optimized path, LoLa can store compressed payload bytes instead of immediately decoding.

Incomplete frame handling:

- RX tracks complete frames, incomplete/lost frames, sequence gaps, frame-id mismatch, and fragment-index anomalies.
- In raw mode, if the final-fragment flag arrives but reassembly is incomplete, LoLa may accept partial/incomplete frames if `IncompleteFramesThreshold` is configured.
- Current default config has `IncompleteFramesThreshold=0`, so incomplete video should be treated as dropped.

## Minimal Connector Implementation Contract

To accept an incoming LoLa connection:

1. Listen UDP `7000`.
2. Parse `/MESG_QUICKCONN`.
3. Validate or accept audio settings.
4. Reply with `/MESG_QUICKCONN_ACK;SRCIP:<connector_ip>;DSTIP:<lola_ip>;SID:<sid>;SR:<sr>;BPS:<bps>;CHNLS:<channels>;FPS:<fps>;BPP:<bpp>;X:<w>;Y:<h>;COMP:<0-or-1>;BAYER:<0-or-1>`.
5. Start receiving LoLa audio/video UDP payloads on ports `19788`/`19798`.
6. Start sending connector audio/video payloads to LoLa's same ports.

To initiate a connection to LoLa:

1. Send `/MESG_QUICKCONN` to LoLa UDP `7000`, preferably as a 1024-byte datagram.
2. Use audio settings matching LoLa's local configuration.
3. Wait for `/MESG_QUICKCONN_ACK` or `/MESG_REJECT`.
4. If ACK arrives, use the ACK's remote media fields to configure RX.
5. Start AV TX/RX.

For audio TX to LoLa:

1. Every 64-frame callback interval, build serialized audio:
   `seq`, `pcm_len`, `pcm_bytes`.
2. Wrap in one normal 0x21 LoLa fragment.
3. Set flag byte `0x20 = 1`.
4. Send UDP payload to LoLa `audioport`.

For video TX to LoLa:

1. Build serialized video:
   `seq`, `payload_len`, raw-frame or JPEG bytes.
2. Fragment with normal 0x21 LoLa headers using configured packet size, default `VideoPacketSize=1000`.
3. Send 0x40 video prelude first.
4. Send all normal fragments after the prelude.
5. Set flag byte `0x20 = 1` on the last normal fragment.
6. Use UDP `videoport`.

For LoLa audio RX:

1. Match source IP and `audioport`.
2. Parse one normal fragment.
3. Reassemble/validate frame id.
4. Read `seq`, `pcm_len`, `pcm_bytes`.
5. Maintain gap/drop counters.

For LoLa video RX:

1. Match source IP and `videoport`.
2. Wait for 0x40 prelude.
3. Initialize expected frame state from prelude.
4. Collect normal fragments by frame id/index.
5. Reassemble serialized payload.
6. Read `seq`, `payload_len`, payload bytes.
7. Treat payload as raw frame if `COMP=0`, JPEG if `COMP=1`.

## Open Issues / Cautions

- Function and field names are recovered from offsets; no PDB is present.
- LoLa uses pcap raw Ethernet for its own TX. A connector may send normal UDP packets, but LoLa receives through pcap and BPF, so packets must arrive on the selected NIC and match source IP/ports.
- `FUN_140020660` resolves gateway MAC, so exact L2 destination behavior may differ on same-LAN vs routed paths.
- Audio RX hard-codes fragment count 1. Do not send multi-fragment audio unless later dynamic testing proves it works.
- Control datagrams should be padded to 1024 bytes for closest compatibility.
- Parser extraction is simple string token scanning. Avoid semicolons inside `TXT` unless tested.
- The current first-pass `lola_packet_decoder.py` does not yet decode the video prelude; update it before relying on it for video captures.
