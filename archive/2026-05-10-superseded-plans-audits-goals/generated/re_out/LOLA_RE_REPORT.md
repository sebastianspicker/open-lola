# Lola 2.0.0 XIMEA x64 Reverse Engineering Notes

Workspace: `C:\Users\sebastian\Desktop\LolaGuiPackage_2.0.0_XIMEA_x64_420`

## Artifacts Produced

- `re_out\pe_report.json`: PE metadata, imports, exports, hashes, interesting strings.
- `re_out\*.strings.json`: ASCII/UTF-16 strings per binary.
- `re_out\manual_text.txt`: extracted manual text.
- `re_out\summary_extract.txt`: string and decompiler keyword digest.
- `re_out\ghidra_proj\LolaGhidra`: analyzed Ghidra project.
- `re_out\decomp_*.c`: Ghidra decompilation of hot functions.
- `re_out\ghidra_hotspots_summary.txt`: hot function and import xref summary.
- `re_out\ghidra_import_refs.tsv`: resolved import-to-function cross references.
- `re_out\resources_summary.json`: PE resource/dialog/string summary.
- `re_out\LOLA_DEEP_STATIC_REPORT.md`: deeper call-neighborhood report covering AV fragmentation, RX/TX, audio callback, and config field mapping.
- `re_out\LOLA_CONNECTOR_PROTOCOL_RE.md`: connector-focused protocol report for control handshake, ACK/reject/chat, raw-pcap audio/video TX/RX, and implementation requirements.
- `re_out\LOLA_STATIC_SOURCE_RECON.md`: source-like reconstruction for structs, thread lifecycle, connect/disconnect state machines, and connector pseudocode.
- `re_out\rizin_protocol_deep_disasm.txt`: Rizin disassembly excerpt for the connection validator, chat sender, and raw packet builder.
- `re_out\rizin_lifecycle_disasm.txt`: Rizin disassembly excerpt for disconnect/reset and session lifecycle helpers.
- `re_out\rizin_control_helpers_disasm.txt`: Rizin disassembly excerpt for the semicolon control field extractor.
- `lola_packet_decoder.py`: capture parser scaffold for the recovered Lola AV fragmentation header.

## 2026-05-07 Deeper Static Source Pass

The second 2026-05-07 static pass added `LOLA_STATIC_SOURCE_RECON.md`. It reconstructs the connection subsystem as source-like modules rather than isolated packet facts:

- Two GUI session slots own per-session RX state; audio/video TX engines are shared and iterate over the active sessions.
- Outbound connect sends QuickConn, waits on control runtime flags for up to 2000 ms, copies ACK parameters into the session object, then starts display, audio TX, optional video TX, and pcap RX.
- Inbound QuickConn finds a free session matching the requested local IP, validates audio compatibility, sends ACK or Reject, then starts the same workers.
- Disconnect sends `/MESG_DISCONNECT`, clears RX run state, waits up to 1000 ms for RX shutdown, stops per-session audio/video TX, clears remote IP, and resets UI/session-active state.
- The control field extractor is semicolon-token based with no escaping layer, so connector chat/reject text should avoid semicolons.
- The source-like struct maps now identify the key runtime offsets used by connector behavior: control reply/success flags, remote AV parameter storage, RX counters, pcap handles, per-session active bytes, and TX event/run flags.

## 2026-05-07 Connector Static Pass

The 2026-05-07 static rerun regenerated the PE/resource/string-location artifacts, added a targeted Rizin disassembly pass, and consolidated the connector-facing protocol details in `re_out\LOLA_CONNECTOR_PROTOCOL_RE.md`. The most relevant implementation deltas are:

- Control messages use Winsock UDP on `socketport` and Lola sends fixed 1024-byte padded datagrams.
- QuickConnect/QuickConnect ACK negotiates session parameters and starts the local AV workers; rejection is textual via `/MESG_REJECT`.
- The receiver-side compatibility gate validates audio channels, sample rate, and bits per sample; video parameters are parsed but not rejected by the recovered validator.
- AV data is sent as raw Ethernet/IPv4/UDP frames through WinPcap/Npcap, not ordinary Winsock UDP.
- The normal LoLa media fragment header is 0x21 bytes and carries frame id, fragment count, fragment index, original offset, fragment length, and an end-of-frame flag byte.
- Video frames require a separate 0x40-byte prelude packet before normal fragments; the earlier decoder scaffold does not yet model that prelude.
- Audio is expected as one serialized 64-frame callback block per packet/fragment in the recovered receiver path.

## Refinement Pass Evidence

The 2026-05-06 static refinement pass expanded the Ghidra hotspot set to 41 functions and exported direct import cross references. The strongest deltas:

- Resource table: 71 resources, including 15 dialogs and 99 string resources. Dialog/resource strings confirm built-in panels named `Audio/Video/Network devices settings`, `Network monitor panel`, `Audio/Video buffers settings`, `Audio test signal`, `Audio/Video recording settings`, and `HW Color Correction for Digital Cameras`.
- WinPcap/Npcap xrefs are concentrated in AV functions: `pcap_next_ex` only in `FUN_1400152d0`, `pcap_compile`/`pcap_setfilter` only in `FUN_140016f20`, and queued transmit APIs in `FUN_1400115c0`/`FUN_140011c10`.
- `FUN_140020d70` is a small one-shot raw sender: it calls `pcap_open(..., 0xffff, 0x10)`, then `pcap_sendpacket(packet, packet_len + 0x2a)`, then `pcap_close`.
- `FUN_140020920` calls `pcap_findalldevs_ex("rpcap://", ...)`, so there is a remote-capable pcap enumeration path in addition to local `pcap_findalldevs` use.
- `FUN_140028af0` is another local adapter enumeration/UI path using `pcap_findalldevs` and `pcap_freealldevs`.
- `FUN_1400093a0` opens PortAudio with `Pa_OpenStream(..., sampleRate=DAT_140044198, framesPerBuffer=0x40, callback=FUN_14000acb0, userData=this)`. This confirms a 64-frame callback-driven stream open path.
- JPEG encode functions are now separated: `FUN_1400107c0`, `FUN_140011c10`, and `FUN_1400161a0` call the IJG compression pipeline. JPEG decode functions are `FUN_14000db70` and `FUN_1400152d0`.
- xiAPI xrefs confirm `xiGetImage` in `FUN_14000efc0`, `FUN_14000fb40`, and `FUN_140012ec0`; color/camera parameter helpers live in `FUN_140021cc0`, `FUN_140021dd0`, `FUN_140022670`, and `FUN_1400227d0`.

## Package Inventory

Primary binaries:

- `LolaGui_XIMEA_x64.exe` - main application, 613,888 bytes.
- `LolaGui_Tester\LolaGui_TESTER_x64.exe` - older test harness, 287,744 bytes.
- `LolaVideoConverter_x64.exe` - video conversion utility.
- `LolaWavSplitter_x64.exe` - audio split utility.

Important DLLs:

- `xiapi64.dll` - XIMEA camera API, 48 MB, 373 exports.
- `portaudio_x64.dll` - PortAudio/ASIO audio layer, 47 exports.
- `wpcap.dll` is loaded from system WinPcap/Npcap, not bundled.
- `jpeg62.dll` - IJG JPEG encode/decode.
- `gpujpeg.dll`, `cudart64_55.dll` - GPU JPEG/CUDA support; strings/manual suggest CUDA compression is not active in this Lola 2.0.0 release.
- `opencv_core249.dll`, `opencv_imgproc249.dll`, `opencv_highgui249.dll` - video transforms/render/write helpers.

Configs:

- `LolaGui.ini`: audio/video/network defaults.
- `LastSsn.ssn`: last remote session state.
- `CAMERAFILES\Ximea.ini`: supported XIMEA model/resolution/format presets.
- `XimeaColors.ini`: XIMEA white balance/gamma/correction values.

## PE/Build Facts

`LolaGui_XIMEA_x64.exe`:

- Compiler/toolchain: MSVC 2019, Visual Studio 2019 v16.2.
- MFC 14.0 GUI application.
- Compile timestamp from PE/rizin: 2019-10-18 12:28:26.
- PDB path embedded:
  `F:\000_LOLA OFFICIAL RELEASE\GuiProjects2\GUIProjects\NewLolaGUI\intermediate\x64\Release\LolaGui.pdb`
- Not packed. Ghidra analysis is clean enough for useful decompilation.
- Imports `WS2_32.dll`, `wpcap.dll`, `IPHLPAPI.DLL`, `portaudio_x64.dll`, `xiapi64.dll`, OpenCV, JPEG, Direct2D, MFC.

`LolaGui_TESTER_x64.exe`:

- Compiler/toolchain: MSVC 2010, MFC 10.0.
- Imports `WS2_32.dll`, `wpcap.dll`, `IPHLPAPI.DLL`, `jpeg62.dll`, `WINMM.dll`.
- Has extra Winsock imports like `connect`, `send`, `WSAEventSelect`, `ioctlsocket`, which differ from the main GUI control path.

## Configured Ports

From `LolaGui.ini` and confirmed by the manual:

- `socketport=7000`: control/service UDP.
- `audioport=19788`: audio stream UDP payloads.
- `videoport=19798`: video stream UDP payloads.

Manual section 3.9 says Lola uses UDP 7000, 19788, and 19798 by default.

## Control Plane

Control traffic is text over UDP. The receive thread creates:

- `socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)`
- binds to local `socketport`
- receives up to `0x1000` bytes with `recvfrom`
- accepts only messages beginning at offset 0 with `/MESG_`
- passes valid strings to parser `FUN_14001f390`

Hot functions:

- `FUN_14001ffa0`: UDP control sender.
- `FUN_140020110`: UDP control receiver/listener.
- `FUN_14001fb60`: control message formatter/sender.
- `FUN_14001f390`: control message parser/dispatcher.

Important quirk:

- `FUN_14001ffa0` formats the message into a 1024-byte stack buffer, then calls `sendto(..., 0x400, ...)`. So control packets are always sent as 1024-byte UDP datagrams, even when the text message is much shorter.

### Control Message IDs

Formatter `FUN_14001fb60` maps integer message IDs to text:

- `0x800c`: `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `0x800d`: `/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;`
- `0x800f`: `/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`
- `0x8010`: `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `0x8012`: `/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;`
- `0x8013`: `/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;`
- `0x8014`: `/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;`
- `0x8015`: `/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;`
- `0x8016`: `/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`
- `0x8017`: `/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`
- `0x8018`: `/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`

### Parser Behavior

Parser `FUN_14001f390`:

- tokenizes message name by `;`
- extracts `SRCIP:` and `DSTIP:`
- replies to `/MESG_CHECKLOLASTATUS` with `0x8013`
- handles `/MESG_CHECKLOLASTATUS_ACK` by setting status flag
- handles `/MESG_QUICKCONN` by posting UI/window message `0x8002`
- handles `/MESG_QUICKCONN_ACK` by parsing:
  - `CHNLS:`
  - `FPS:`
  - `BPP:`
  - `X:`
  - `Y:`
  - `SR:`
  - `BPS:`
  - `COMP:`
  - `BAYER:`
- handles `/MESG_DISCONNECT` by posting `0x8003`
- handles `/MESG_REJECT` by extracting `TXT:` and setting refusal/status fields
- handles bounce-back with window message `0x8005`
- handles chat with `TXT:` and window message `0x8006`
- handles audio test signal with `0x8007` and `0x8008`

## AV Transport

High-rate AV does not use normal Winsock `sendto`. It manually constructs Ethernet + IPv4 + UDP packets and injects them using WinPcap/Npcap.

Relevant imports:

- `pcap_findalldevs`
- `pcap_open`
- `pcap_setmintocopy`
- `pcap_compile`
- `pcap_setfilter`
- `pcap_next_ex`
- `pcap_sendpacket`
- `pcap_sendqueue_alloc`
- `pcap_sendqueue_queue`
- `pcap_sendqueue_transmit`
- `pcap_sendqueue_destroy`
- `pcap_close`

Hot functions:

- `FUN_140016f20`: pcap adapter discovery/open/filter setup and receive-thread start.
- `FUN_140020660`: maps pcap adapter to `GetAdaptersInfo`, IP/gateway/MAC metadata, and uses `SendARP`.
- `FUN_140020ba0`: raw Ethernet/IP/UDP packet builder.
- `FUN_140009bf0`: one AV send path using `pcap_sendpacket`.
- `FUN_140020d70`: small one-shot AV/raw send path using `pcap_open`, `pcap_sendpacket`, and `pcap_close`.
- `FUN_140020920`: remote-capable pcap enumeration via `pcap_findalldevs_ex("rpcap://", ...)`.
- `FUN_140028af0`: local pcap adapter enumeration/UI list path.
- `FUN_1400115c0`: queued AV send path.
- `FUN_140011c10`: alternate queued AV send path, selected when field at `+0x1114 == 1`.
- `FUN_1400152d0`: pcap receive path using `pcap_next_ex`.

### Raw Packet Layout

`FUN_140020ba0` constructs:

- Ethernet header at offset `0x00`
  - `0x00..0x05`: destination MAC
  - `0x06..0x0b`: source MAC
  - `0x0c..0x0d`: EtherType `0x0800`
- IPv4 header at offset `0x0e`
  - version/IHL `0x45`
  - total length = payload length + `0x1c` (20-byte IP + 8-byte UDP)
  - IP ID = `0x1337`
  - TTL = `0x80`
  - protocol = `0x11` UDP
  - checksum computed by `FUN_140020a10`
  - source IP at `0x1a`
  - destination IP at `0x1e`
- UDP header at offset `0x22`
  - source port
  - destination port
  - UDP length = payload length + 8
  - UDP checksum computed by `FUN_140020a80`
- Payload at offset `0x2a`

Thus captured stream packets should decode as normal IPv4/UDP frames, but they are injected below Winsock through pcap.

### BPF Filter

`FUN_140016f20` starts with:

- default filter: `ip and udp`

If `RxPacketFiltering` is nonzero, it formats a stricter filter:

- `ip and src host %s and dst host %s and (udp port %d or udp port %d)`

The ports are expected to be the audio/video ports: 19788 and 19798.

### NIC Selection

The main app uses both:

- WinPcap/Npcap adapter list: `pcap_findalldevs`
- Windows adapter metadata: `GetAdaptersInfo`

It selects a pcap device whose device name contains configured `NicDevName`. Then it correlates this with `GetAdaptersInfo` and uses `SendARP` to resolve the gateway/remote MAC needed for raw Ethernet injection.

That explains why blank or stale `NicDevName=;;` and VPN/tunnel adapters can confuse Lola even if Windows has an active NIC.

## Audio

Main app imports `portaudio_x64.dll` by ordinal. Resolved ordinal names:

- `Pa_Initialize`
- `Pa_Terminate`
- `Pa_OpenStream`
- `Pa_StartStream`
- `Pa_StopStream`
- `Pa_CloseStream`
- `Pa_GetDeviceCount`
- `Pa_GetDeviceInfo`
- `Pa_GetHostApiCount`
- `Pa_GetHostApiInfo`
- `Pa_GetErrorText`
- `Pa_IsFormatSupported`
- `PaAsio_GetAvailableBufferSizes`

Audio assumptions from strings/config/manual:

- ASIO is expected.
- RME-style low buffer sizes are expected: 32 or 64 samples.
- Audio negotiation requires exact match on sample rate, bits per sample, and channel count.
- Config currently uses `SamplingRate=44100`, `bitPerSample=16`, `NumOfChannels=2`.

Refined static evidence:

- `FUN_140007980` initializes PortAudio, enumerates host APIs, searches for host API name `ASIO`, and enumerates ASIO devices.
- `FUN_1400093a0` calls `Pa_OpenStream` with callback `FUN_14000acb0`, sample rate from `DAT_140044198`, and `framesPerBuffer=0x40`.
- `FUN_14000a350` starts the stream with `Pa_StartStream`.
- `FUN_14000a710` stops the stream with `Pa_StopStream`.
- `FUN_1400086e0` terminates/cleans up PortAudio state.

## Video / XIMEA

Main XIMEA imports:

- `xiGetNumberDevices`
- `xiOpenDevice`
- `xiCloseDevice`
- `xiStartAcquisition`
- `xiStopAcquisition`
- `xiGetImage`
- `xiSetParamInt`
- `xiSetParamFloat`
- `xiGetParamInt`
- `xiGetParamFloat`
- `xiGetParamString`

Hot functions:

- `FUN_14000fb40`: XIMEA init/config/start acquisition.
- `FUN_14000efc0`: multi-camera image fetch loop.
- `FUN_140012ec0`: per-frame acquisition/copy/render/queue preparation.

XIMEA init behavior:

- sets `exposure`
- sets `imgdataformat`
- reads camera `width`/`height`
- sets ROI `width`, `height`, `offsetX`, `offsetY`
- disables `auto_wb`
- applies `wb_kr`, `wb_kg`, `wb_kb`, `gammaY`, `gammaC`
- reads `XimeaColors.ini` if present
- starts acquisition with `xiStartAcquisition`
- immediately pulls one image with `xiGetImage(..., timeout=1000, ...)`

`xiGetImage` writes into per-camera XIMEA image structures spaced by `0xe8` bytes from a base near `param + 0x38`.

Supported camera presets in `CAMERAFILES\Ximea.ini` include xiQ MQ013CG-E2, XiC MC023CG-SY, and generic xiQ modes up to 2048x2048, Mono8/RGB24, mostly 60 fps.

## JPEG / Compression

Main app imports IJG JPEG functions by ordinal:

- `jpeg_CreateCompress`
- `jpeg_CreateDecompress`
- `jpeg_mem_dest`
- `jpeg_mem_src`
- `jpeg_read_header`
- `jpeg_read_scanlines`
- `jpeg_write_scanlines`
- `jpeg_set_quality`
- `jpeg_start_compress`
- `jpeg_finish_compress`
- `jpeg_start_decompress`
- `jpeg_finish_decompress`

`gpujpeg.dll` exports encoder/decoder APIs, but `LolaGui_XIMEA_x64.exe` does not import `gpujpeg.dll` directly. It may be loaded dynamically or the GPU path is disabled. Strings say `- CUDA Disabled`, and the manual says CUDA compression is temporarily unavailable in 2.0.0.

Refined static evidence:

- `FUN_1400107c0`: local/source-frame JPEG compression path. Uses OpenCV Mat/InputArray handling, then `jpeg_std_error`, `jpeg_CreateCompress`, `jpeg_mem_dest`, `jpeg_set_defaults`, `jpeg_set_quality`, `jpeg_start_compress`, `jpeg_write_scanlines`, `jpeg_finish_compress`, and `jpeg_destroy_compress`.
- `FUN_1400161a0`: second JPEG compression path using another frame object layout.
- `FUN_140011c10`: queued send path that also includes the IJG compression pipeline.
- `FUN_14000db70`: standalone JPEG decompression path using `jpeg_mem_src`, `jpeg_read_header`, `jpeg_start_decompress`, `jpeg_read_scanlines`, and cleanup.
- `FUN_1400152d0`: receive path that includes JPEG decompression while processing captured pcap frames.

## Network Monitor / Scripting UI

The chat/network monitor dialog seeds command strings:

- `lola.GetRemoteSettings();`
- `lola.GetRemoteInfo();`
- `lola.ResetRemoteInfo();`
- `lola.ForceDisconnect();`
- `lola.SetRemoteAudioBuffer(0);`

The class string `LolaChatDlg` appears in RTTI/strings. This looks like a small built-in command surface rather than an external scripting engine.

## Practical Dynamic RE Plan

1. Start Wireshark/tshark on the selected physical NIC.
2. Capture filter:
   - `udp port 7000 or udp port 19788 or udp port 19798`
3. For control-only testing, send a status probe:
   - `/MESG_CHECKLOLASTATUS;SRCIP:<local>;DSTIP:<remote>;SID:0;`
   - pad to 1024 bytes if mimicking Lola exactly.
4. In x64dbg/API Monitor, break on:
   - `WS2_32!sendto`
   - `WS2_32!recvfrom`
   - `wpcap!pcap_open`
   - `wpcap!pcap_compile`
   - `wpcap!pcap_setfilter`
   - `wpcap!pcap_sendpacket`
   - `wpcap!pcap_sendqueue_queue`
   - `wpcap!pcap_sendqueue_transmit`
   - `wpcap!pcap_next_ex`
   - `xiapi64!xiGetImage`
   - `portaudio_x64!Pa_OpenStream`
5. First static labels to apply in Ghidra:
   - `FUN_14001ffa0` -> `ControlSendUdp`
   - `FUN_140020110` -> `ControlRecvThread`
   - `FUN_14001fb60` -> `FormatAndSendControlMessage`
   - `FUN_14001f390` -> `ParseControlMessage`
   - `FUN_140020ba0` -> `BuildEtherIpUdpPacket`
   - `FUN_140020a10` -> `Ipv4Checksum`
   - `FUN_140020a80` -> `UdpChecksum`
- `FUN_140016f20` -> `OpenPcapAdapterAndStartRx`
- `FUN_140020660` -> `ResolveAdapterIpMacGateway`
- `FUN_1400152d0` -> `PcapRxThread`
- `FUN_140020d70` -> `PcapOneShotSendPacket`
- `FUN_140020920` -> `EnumRemotePcapAdapters`
- `FUN_140028af0` -> `EnumLocalPcapAdaptersForUi`
- `FUN_1400093a0` -> `PortAudioOpenStream`
- `FUN_14000acb0` -> `PortAudioCallback`
- `FUN_1400107c0` -> `JpegCompressLocalFrame`
- `FUN_1400161a0` -> `JpegCompressFrameVariant`
- `FUN_14000db70` -> `JpegDecompressBuffer`
   - `FUN_14000fb40` -> `XimeaInitAndStart`
   - `FUN_140012ec0` -> `XimeaFrameCaptureAndQueue`

## High-Confidence Conclusions

- Lola uses three UDP ports by design: 7000 control, 19788 audio, 19798 video.
- Control messages are semicolon-delimited ASCII strings over normal UDP sockets.
- AV packets are manually formed Ethernet/IPv4/UDP frames and injected/captured through WinPcap/Npcap.
- The raw AV packet builder uses IP ID `0x1337`, TTL 128, UDP checksums, and payload offset 42.
- Lola depends on a pcap adapter matching a Windows adapter so it can get IP and MAC/gateway information; this is the root of many "no network interface" failures.
- Lola has both local and `rpcap://` pcap enumeration code paths, but the send/receive paths still depend on a usable local WinPcap/Npcap device for raw packet capture/injection.
- XIMEA is controlled directly through xiAPI, not through DirectShow/webcam APIs.
- Audio goes through PortAudio with ASIO-oriented enumeration, callback-driven `Pa_OpenStream`, 64-frame buffers in the recovered open path, and strict format matching.
- JPEG compression/decompression uses IJG `jpeg62.dll`; GPU JPEG remains unproven in the main executable and appears disabled for this release.

## What Is Not Yet Fully Recovered

- Exact AV payload header fields inside the UDP payload. The packet wrapper is known, but the payload schema needs live captures or deeper structure recovery around buffers passed to `FUN_140020ba0`.
- Exact distinction between `FUN_1400115c0` and `FUN_140011c10`. The selector at `+0x1114 == 1` chooses one path; `FUN_140011c10` includes JPEG compression, but the user-facing mode name still needs labeling.
- Full ring-buffer object layout. Offsets are visible, but class/field names need more Ghidra labeling or a matching PDB.
- Live PortAudio callback semantics. `FUN_14000acb0` is now identified as the callback target, but its buffer layout and packetization relationship still need a focused pass.
