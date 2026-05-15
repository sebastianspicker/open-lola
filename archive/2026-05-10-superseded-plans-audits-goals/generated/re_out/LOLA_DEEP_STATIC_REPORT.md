# Lola Deep Static RE Report

Workspace: `C:\Users\sebastian\Desktop\LolaGuiPackage_2.0.0_XIMEA_x64_420`

## 2026-05-07 Connector-Focused Static Rerun

This pass updates the protocol understanding for connector implementation. The most complete connector-facing writeup is now:

- `LOLA_CONNECTOR_PROTOCOL_RE.md`
- `LOLA_STATIC_SOURCE_RECON.md`

New/updated static artifacts from this rerun:

- `pe_report.json`, `resources_summary.json`, and `string_locations.json` were regenerated.
- `rizin_protocol_deep_disasm.txt` was added to preserve fresh Rizin disassembly for functions that were not in the previous Ghidra export, especially:
  - `FUN_140029150`: QuickConn compatibility validator.
  - `FUN_1400329a0`: chat/remote-info chunk sender.
  - `FUN_140020ba0`: raw Ethernet/IPv4/UDP packet builder.
- `rizin_lifecycle_disasm.txt` was added for `FUN_14002c100`, `FUN_1400174e0`, `FUN_14000aaa0`, and related session lifecycle helpers.
- `rizin_control_helpers_disasm.txt` was added for `FUN_14001f270`, the semicolon field extractor used by control/chat parsing.

High-confidence deltas from the rerun:

- QuickConn acceptance checks audio compatibility only: channel count, sample rate, and bits per sample. Video settings are parsed and used, but they are not part of the static reject gate.
- Control messages are ordinary UDP text on `socketport`, but LoLa sends them as fixed 1024-byte datagrams.
- The control key/value parser tokenizes only on `;`, searches for a prefix inside each token, and removes the prefix. There is no escaping layer for `TXT`.
- The GUI owns two session slots. Outbound connect waits on control runtime flags for up to 2000 ms, then starts display, audio TX, optional video TX, and pcap RX. Inbound QuickConn starts the same workers after ACK.
- Disconnect sends `/MESG_DISCONNECT`, clears the RX run flag, waits up to 1000 ms for RX thread shutdown, stops per-session audio/video TX, clears the remote IP, and resets session-active state.
- Chat and remote monitor commands are normal `/MESG_CHAT` messages. Long text is chunked at `0x400` byte steps.
- Audio RX initializes reassembly with fragment count `1`; a connector should send one normal LoLa fragment per audio callback.
- Video RX requires a 0x40-byte prelude packet before normal fragments. Prelude magic is `fd fd fd fd df df df df aa aa aa aa`; RX uses prelude fields at offsets `0x10`, `0x14`, and `0x1c` for frame id, expected serialized size, and fragment count.
- The existing `lola_packet_decoder.py` understands the normal 0x21-byte fragment header, but not this video prelude yet.

## New Deep Artifacts

- `deep_functions.tsv`: 106 functions in the AV/audio call neighborhood.
- `deep_call_edges.tsv`: call edges for those functions.
- `deep_function_strings.tsv`: strings referenced from the deep functions.
- `deep_decomp_*.c`: expanded decompilations for packet framing, audio callback, RX, TX, JPEG, and pcap setup.
- `lola_packet_decoder.py`: first-pass capture decoder for the recovered Lola AV fragmentation header.

## System Model

Lola has three transport layers:

- Control: ordinary Winsock UDP text messages on `socketport`, default 7000.
- AV wrapper: raw Ethernet/IPv4/UDP frames built in-process and injected/captured with WinPcap/Npcap.
- AV payload: Lola's own fragmentation/reassembly format inside the UDP payload.

The GUI is the orchestrator. It reads config/session values, performs control negotiation, opens ASIO streams through PortAudio, captures camera frames through xiAPI, then starts pcap send/receive workers for each session.

## Control Plane

Static confidence is high:

- Sender: `FUN_14001ffa0`
- Receiver: `FUN_140020110`
- Formatter: `FUN_14001fb60`
- Parser: `FUN_14001f390`

Sender behavior:

- Builds semicolon-delimited ASCII messages.
- Sends with `sendto(..., 0x400, ...)`, so Lola-originated control datagrams are padded/fixed at 1024 bytes.

Receiver behavior:

- Binds UDP socket to configured `socketport`.
- Reads up to `0x1000` bytes.
- Dispatches only strings beginning with `/MESG_`.

Negotiation fields exposed by QuickConn:

- Audio: `SR`, `BPS`, `CHNLS`
- Video: `FPS`, `BPP`, `X`, `Y`, `COMP`, `BAYER`
- Addressing/session: `SRCIP`, `DSTIP`, `SID`

## Pcap/NIC Model

Pcap setup is centered at `FUN_140016f20`.

Inputs:

- Session RX object pointer.
- Session info object pointer.
- Remote IP string.
- Stream selector/mode value stored into RX object offsets `+0x250` and `+0x2dc`.

Adapter selection:

- Calls `pcap_findalldevs`.
- If `NicDevName` is non-empty, searches pcap device names with `strstr`.
- Calls `FUN_140020660` to correlate pcap device name with `GetAdaptersInfo`.
- `FUN_140020660` stores local/gateway IP metadata, copies adapter name/description strings, and calls `SendARP` for gateway MAC resolution.
- If adapter correlation fails, RX setup exits before opening pcap.

Pcap open/filter:

- `pcap_open(device_name, 0x10000, 8, 500, ...)`
- `pcap_setmintocopy(handle, config.WinPcap_SetMinToCopy)`
- Default BPF: `ip and udp`
- If `RxPacketFiltering != 0`: `ip and src host %s and dst host %s and (udp port %d or udp port %d)`
- Starts RX thread with `AfxBeginThread`, wrapper `FUN_1400160c0`, body `FUN_1400152d0`.

This is the deepest static explanation for the "no network interface" symptom: Lola is not asking Windows for a normal socket interface. It needs a pcap device whose string matches `NicDevName`, and that pcap device must correlate to a Windows adapter from `GetAdaptersInfo` so the app can recover local IP/MAC/gateway data for raw Ethernet injection.

## Raw Ethernet/IP/UDP Builder

`FUN_140020ba0` constructs the outer packet.

Signature shape:

- `param_1`: packet buffer object, where `*param_1` is the raw frame allocation and `param_1+8` stores payload length.
- `param_2`: source MAC pointer.
- `param_3`: destination MAC pointer.
- `param_4`: source IPv4 address.
- `param_5`: destination IPv4 address.
- `param_6`: source UDP port.
- `param_7`: destination UDP port.
- `param_8`: Lola AV payload pointer.
- `param_9`: Lola AV payload length.

Outer frame layout:

- Ethernet header: `0x00..0x0d`
- IPv4 header: `0x0e..0x21`
- UDP header: `0x22..0x29`
- Lola AV payload: `0x2a`

Constants:

- EtherType: IPv4
- IPv4 version/IHL: `0x45`
- IP ID: `0x1337`
- TTL: `0x80`
- Protocol: UDP
- IP checksum: `FUN_140020a10`
- UDP checksum: `FUN_140020a80`

## Lola AV Payload Fragmentation

This is the main new recovery.

`FUN_140006c50` constructs an object identified by RTTI/vtable as `flFMTDataEncoder`.

`FUN_140007250` sets the encoder packet size:

- minimum: `0x80`
- maximum: `0x2000`
- default constructor size: `0x400`
- video paths set it from `param_1 + 0x1204`, matching config `VideoPacketSize`

`FUN_1400070b0` fragments a serialized frame into chunks of:

- `packet_size - 0x21`

Each UDP payload begins with a 0x21-byte Lola fragmentation header:

| Offset | Size | Meaning |
| --- | ---: | --- |
| `0x00` | 8 | Magic bytes `fd fd fd fd df df df df` |
| `0x08` | 4 | Sentinel `ee ee ee ee` |
| `0x0c` | 4 | Frame/message sequence id |
| `0x10` | 4 | Total fragment count |
| `0x14` | 4 | Fragment index |
| `0x18` | 4 | Offset into original serialized frame |
| `0x1c` | 4 | Fragment data length |
| `0x20` | 1 | Flag byte |
| `0x21` | n | Fragment data |

Reassembly:

- `FUN_140006f00` initializes a receive/reassembly buffer from first fragment metadata.
- `FUN_140007200` validates frame id, fragment index, and duplicate bitmap, then copies bytes from payload offset `0x21` to original offset `0x18`.
- `FUN_140006e80` returns complete when received fragment count equals expected fragment count.
- `FUN_140006e90` returns reassembled buffer pointer and size.

Practical consequence:

- A Wireshark capture can now be decoded without guessing. Filter UDP ports 19788/19798, then parse the UDP payload with the 0x21-byte header above.

## AV TX Paths

Audio one-shot/raw send:

- Thread wrapper: `FUN_140009be0`
- Body: `FUN_140009bf0`
- Uses `pcap_sendpacket` directly, not send queues.
- Serializes:
  - 4-byte sequence at stream object `+0x18e8`
  - 4-byte audio payload byte count
  - PCM/audio data from `+0x1288`
- Uses `flFMTDataEncoder` fragmentation.
- Sets first fragment flag byte at payload header offset `0x20` to `1`.
- Sends to two possible session slots at offsets around `+0x1d70/+0x1d80`.

Video send selector:

- Thread wrapper/selector: `FUN_140011590`
- If `stream+0x1114 == 1`: calls `FUN_140011c10`
- Else: calls `FUN_1400115c0`

Uncompressed video send:

- Body: `FUN_1400115c0`
- Serializes:
  - 4-byte sequence at `+0x1188`
  - 4-byte frame byte count
  - raw frame bytes from `+0x1838`
- Fragmented by `flFMTDataEncoder`.
- Uses `pcap_sendqueue_alloc`, `pcap_sendqueue_queue`, `pcap_sendqueue_transmit`.

JPEG video send:

- Body: `FUN_140011c10`
- String evidence: `Jpeg encoding:`
- Compresses `+0x1838` frame data with IJG JPEG.
- Source dimensions: `+0x10c8` width, `+0x10cc` height, `+0x10dc` bits-per-pixel.
- JPEG quality read from `*(stream+0x440)+0x9c`, consistent with `CompressionQuality`.
- Serializes:
  - 4-byte sequence at `+0x1188`
  - 4-byte compressed byte count
  - JPEG bytes
- Then uses the same 0x21-byte fragmentation header and pcap sendqueue path.

Queue behavior:

- Both video send paths prebuild pcap-sendqueue entries.
- If queueing fails or fills, Lola transmits the current queue, destroys it, allocates a new queue, then queues the current packet again.

## AV RX Path

Thread wrapper:

- `FUN_1400160c0`

Body:

- `FUN_1400152d0`

RX reads:

- `pcap_next_ex(rx+0x50, ...)`
- Reads UDP source/destination/length through `ntohs` at the packet UDP header.
- Builds source IP string with `%d.%d.%d.%d`.
- Compares packet source to configured remote IP string at RX object `+0x48`.

Port split:

- One branch checks against session/config port at `*(rx+600)+0x100`.
- One branch checks against session/config port at `*(rx+600)+0xfc`.
- Based on config order and behavior, these correspond to audio/video ports 19788/19798.

Audio RX:

- Initializes reassembly with expected size `rx+0x2b0 * 0x80 + 8`.
- Reassembles Lola fragments.
- Reads serialized fields with the `flInputByteStream` helper:
  - 4-byte sequence
  - 4-byte audio payload length
  - audio data
- Copies into audio ring buffers under the main/audio object at `rx+0x330`.
- Tracks incomplete/drop counters at `rx+0x270`, `+0x274`, `+0x278`, `+0x27c`.

Video RX:

- Reassembles Lola fragments.
- Reads serialized fields:
  - 4-byte sequence
  - 4-byte payload length
  - video/JPEG data
- If the mode indicates uncompressed data, copies the payload into the remote video frame ring.
- If JPEG data is received and decode is enabled, calls IJG decompression:
  - `jpeg_CreateDecompress`
  - `jpeg_mem_src`
  - `jpeg_read_header`
  - `jpeg_start_decompress`
  - `jpeg_read_scanlines`
  - `jpeg_finish_decompress`
  - `jpeg_destroy_decompress`
- String evidence: `Jpeg decoding (CPU):`
- Stores decode timing via `FUN_140020e20`/`FUN_140020e30`, formatted as `%.3f ms`.

## Audio Callback

PortAudio callback:

- `FUN_14000acb0`
- Immediately calls `FUN_14000ad00(userData, input, output, frameCount)` and returns 0.

`FUN_14000ad00` responsibilities:

- Applies input/output gain:
  - input path uses double at audio object `+0x8c8`
  - output path uses double at `+0x98`
- Maintains double-buffered local audio at `+0x8e0` with selector `+0x8f0`.
- Signals event at `+0x30`, which wakes `FUN_140009bf0` for audio TX.
- Copies remote audio ring data from buffers at `+0xc20`.
- Maintains 100-entry audio ring indices at `+0xf44`, `+0x15b0/+0x15b4`, and `+0x18d8/+0x18dc`.

`FUN_1400093a0` opens the stream:

- `Pa_OpenStream(..., sampleRate=DAT_140044198, framesPerBuffer=0x40, callback=FUN_14000acb0, userData=this)`

So the recovered audio path is callback-driven ASIO/PortAudio, with 64 frames per callback in the recovered open path.

## Config and UI Field Mapping

Static strings and decompiled UI-info formatting map these fields:

- `main+0x1988`: video frame rate.
- `main+0x19b0`: `OptimizeJpegDecompression`.
- `main+0x19b8`: `IncompleteFramesThreshold`.
- `main+0x19bc`: `SIMD_Acceleration`.
- `main+0x1a28`: `RxPacketFiltering`.
- `main+0x1a2c`: `VideoPacketSize`.

Confirmed config keys:

- `socketport`
- `audioport`
- `videoport`
- `NicDevName`
- `RxPacketFiltering`
- `VideoPacketSize`
- `WinPcap_SetMinToCopy`
- `Compression`
- `CompressionQuality`
- `OptimizeJpegDecompression`
- `UseGpuJpegDecOnCuda`
- `IncompleteFramesThreshold`
- `SamplingRate`
- `NumOfChannels`
- `bitPerSample`

Resource strings confirm GUI panels for:

- Audio/Video/Network devices settings
- Network monitor panel
- Audio/Video buffers settings
- Audio test signal
- Audio/Video recording settings
- Hardware color correction for digital cameras

## XIMEA / Video Capture

Static recovery remains consistent:

- `FUN_14000fb40`: XIMEA init/config/start.
- `FUN_14000efc0`: multi-camera image fetch loop.
- `FUN_140012ec0`: per-frame acquisition/copy/render/queue prep.

xiAPI evidence:

- `xiOpenDevice`, `xiStartAcquisition`, `xiStopAcquisition`
- `xiGetImage`
- `xiSetParamInt`, `xiSetParamFloat`
- `xiGetParamInt`, `xiGetParamFloat`, `xiGetParamString`

Video send paths consume frame pointers prepared around `+0x1838`; JPEG send uses configured dimensions and bpp from `+0x10c8/+0x10cc/+0x10dc`.

## Capture Decoder Target

`lola_packet_decoder.py` implements the recovered UDP payload header. Expected dynamic workflow:

1. Capture on the physical NIC with `udp port 19788 or udp port 19798`.
2. Run `python lola_packet_decoder.py capture.pcapng`.
3. Check frame id continuity, fragment completeness, flags, and payload sizes.
4. For complete frames, strip the 0x21-byte fragment headers, reassemble, then parse the first 8 bytes as:
   - uint32 stream sequence
   - uint32 serialized media payload length
5. Interpret remaining bytes as PCM/audio, raw frame, or JPEG depending on port and negotiated `COMP`.

## High-Confidence Full Picture

- Control is normal Winsock UDP text.
- AV media is raw pcap-injected Ethernet/IP/UDP.
- Each AV UDP payload contains Lola's own 0x21-byte fragmentation header.
- Audio TX is driven by the PortAudio callback event.
- Video TX has two paths: raw/uncompressed and IJG JPEG-compressed.
- Video send mode selector is `stream+0x1114`; value `1` selects JPEG path.
- RX reassembles Lola fragments before handing audio/video to ring buffers.
- JPEG decode is CPU/IJG in the recovered RX path.
- GPU JPEG remains present as a DLL/config option but not proven active from main executable imports.
- NIC failure is a pcap device matching/correlation failure, not a normal Windows "no IP interface" condition.

## Remaining Unknowns

- Exact class names for the large GUI/session/stream objects need PDB or more manual Ghidra struct recovery.
- Exact mapping of `*(rx+600)+0xfc` vs `+0x100` to audio/video should be confirmed with one live capture, though branch behavior strongly suggests they are the configured AV ports.
- The first 8 bytes of reassembled media payload are recovered as sequence and byte length, but any additional subheaders inside raw video or audio payloads need captures or more field naming.
- GPU JPEG dynamic loading remains unresolved; static imports and strings still point to CPU IJG as the active path.
