# LoLa Static Source Reconstruction for Connector Work

Workspace: `C:\Users\sebastian\Desktop\LolaGuiPackage_2.0.0_XIMEA_x64_420`

Static pass date: 2026-05-07

Purpose: reconstruct source-like structure around LoLa connection setup, control messages, chat, audio/video TX/RX, pcap lifecycle, and teardown. This document complements `LOLA_CONNECTOR_PROTOCOL_RE.md`: that file is the byte/protocol contract; this file is the inferred source model behind it.

## Evidence Added In This Pass

New static artifacts:

- `re_out\rizin_lifecycle_disasm.txt`: targeted Rizin disassembly for disconnect/session reset helpers and UI/menu helpers.
- `re_out\rizin_control_helpers_disasm.txt`: targeted Rizin disassembly for the semicolon field extractor used by control/chat parsing.

Primary static inputs:

- `deep_decomp_14002b9b0_FUN_14002b9b0.c`: outbound connect path.
- `deep_decomp_14002f3d0_FUN_14002f3d0.c`: inbound QuickConn path.
- `decomp_14001f390_FUN_14001f390.c`: control parser.
- `decomp_14001fb60_FUN_14001fb60.c`: control formatter/sender dispatch.
- `decomp_14001ffa0_FUN_14001ffa0.c`: fixed-size UDP sender.
- `deep_decomp_140009bf0_FUN_140009bf0.c`: audio TX loop.
- `deep_decomp_1400115c0_FUN_1400115c0.c`: raw video TX loop.
- `deep_decomp_140011c10_FUN_140011c10.c`: JPEG video TX loop.
- `deep_decomp_1400152d0_FUN_1400152d0.c`: shared AV RX loop.
- `deep_decomp_140016f20_FUN_140016f20.c`: pcap RX setup.
- `decomp_14000a000_FUN_14000a000.c`: audio pcap TX setup.
- `decomp_140012490_FUN_140012490.c`: video pcap TX setup.
- `deep_decomp_140020660_FUN_140020660.c`: adapter/IP/MAC resolution.
- `deep_decomp_140020ba0_FUN_140020ba0.c`: Ethernet/IP/UDP packet builder.

## High-Confidence Module Map

The GUI object owns two session slots. Each session gets one RX object, shared audio/video TX engines, and a display/video sink object.

```text
Main dialog / controller
  +0x1908  control runtime pointer
  +0x1ae8  session[0] RX/session object pointer
  +0x1af0  session[1] RX/session object pointer
  +0x1af8  video TX engine pointer
  +0x1b00  audio TX engine pointer
  +0x1b08  session[0] display/video sink pointer
  +0x1b10  session[1] display/video sink pointer
  +0x1b18  session[0] connected/running byte
  +0x1b19  session[1] connected/running byte
  +0x1b38  video enabled/session count gate used before starting video TX
```

Observed local settings on the main dialog:

```text
+0x1938  local audio sample rate as double
+0x1940  local audio bits per sample
+0x1944  local audio channel count
+0x1988  local video FPS as double
+0x19b0  OptimizeJpegDecompression flag in remote info text
+0x19b8  IncompleteFramesThreshold
+0x19bc  SIMD acceleration flag in remote info text
+0x19c4  passed into display/video setup
+0x19c8  passed into display/video setup
+0x19cc  passed into display/video setup
+0x1a0c  video port
+0x1a10  audio port
+0x1a28  RxPacketFiltering flag in remote info text
+0x1a2c  VideoPacketSize
```

## Control Runtime Shape

`FUN_14001fb60` and `FUN_14001f390` operate on the control runtime at `main+0x1908`.

```c
struct LolaControlRuntime {
    // exact class header unknown
    uint16_t socket_port;          // local settings pointer +0xf8 feeds sender
    string last_remote_ip;         // +0x40, from incoming SRCIP/ACK
    string last_message;           // +0x58, full last /MESG_* text
    uint8_t replied_or_status;     // +0x60, set by ACK/reject/status
    uint8_t quickconn_success;     // +0x61, set 1 by ACK, 0 by reject

    uint32_t remote_channels;      // +0x64
    double remote_fps;             // +0x68
    uint32_t remote_bpp;           // +0x70
    uint32_t remote_width;         // +0x74
    uint32_t remote_height;        // +0x78
    double remote_sample_rate;     // +0x80
    uint32_t remote_bits;          // +0x88
    uint32_t remote_compression;   // +0x8c
    uint8_t remote_bayer;          // +0x90

    void *local_av_settings;       // +0x98, used for local SR/BPS/CHNLS/FPS/BPP/X/Y/COMP
    void *video_or_camera_state;   // +0xa0, BAYER reported true if +0x10dc == 8
    string last_chat_text;         // +0xa8
    string last_reject_text;       // +0xb0
};
```

The listener object that calls the parser is separate. It has:

```text
+0x30  configured socketport
+0x38  pointer to LolaControlRuntime
+0x58  listener stopped event
+0x60  Winsock UDP socket handle
+0x64  listener stop flag byte/int region, tested as byte at +100
```

The control listener creates `socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)`, binds `INADDR_ANY:socketport`, receives up to `0x1000`, and dispatches only buffers whose `CString.Find("/MESG_", 0)` returns zero.

## Control Field Extraction

`FUN_14001f270` is the key/value extractor used across control, inbound QuickConn, and chat. Rizin confirms this shape:

```c
string extract_semicolon_field(string message, string prefix) {
    CString out = "";
    int token_pos = 0;

    do {
        CString token = message.Tokenize(";", token_pos);
        out = token;
        if (out.empty()) break;
        if (strstr(out.c_str(), prefix.c_str()) != NULL) {
            out.Replace(prefix, "");
            break;
        }
    } while (!out.empty());

    return out;
}
```

Connector implications:

- Message fields are semicolon-tokenized.
- There is no escaping layer in the recovered code.
- Do not put semicolons in `TXT` if you expect LoLa to parse or display the full value.
- Unknown or missing numeric fields flow through `atoi`, so missing values become `0`.

## Recovered Session/RX Object Shape

The per-session object is used by `FUN_140016f20` and `FUN_1400152d0`.

```c
struct LolaSessionRx {
    string remote_ip;              // +0x48, compared against IPv4 source text
    pcap_t *rx_pcap;               // +0x50
    pcap_if_t *rx_all_devs;        // +0x58
    NicInfo local_nic;             // +0x60, copied from FUN_140020660
    string local_ip_for_filter;    // +0x200, used in strict BPF dst host

    uint8_t rx_running;            // +0x24c
    uint8_t rx_stopped;            // +0x24d
    uint32_t video_mode;           // +0x250, 0 raw, 1 JPEG/compressed

    uint32_t audio_ok;             // +0x270
    uint32_t audio_bad;            // +0x274
    uint32_t audio_gap;            // +0x278
    uint32_t audio_buffer_overrun; // +0x27c, inferred from ring distance test

    uint32_t video_ok;             // +0x288
    uint32_t video_bad;            // +0x28c
    uint32_t video_frame_gap;      // +0x290
    uint32_t video_frame_id_mis;   // +0x294
    uint32_t video_frag_seq_mis;   // +0x298

    uint8_t inbound_accepted;      // +0x2ad, set after sending QuickConn ACK
    uint32_t remote_channels;      // +0x2b0
    double remote_fps;             // +0x2b8
    uint32_t remote_bpp;           // +0x2c0
    uint32_t remote_width;         // +0x2c4
    uint32_t remote_height;        // +0x2c8
    double remote_sample_rate;     // +0x2d0
    uint32_t remote_bits;          // +0x2d8
    uint32_t remote_compression;   // +0x2dc
    uint8_t remote_bayer;          // +0x2e0

    string rx_start_time;          // +0x2f0
    CWinThread *rx_thread;         // +0x310
    HANDLE rx_stopped_event;       // +0x318
    void *session_nic_config;      // +0x328, includes selected local IP/NIC
    void *audio_engine;            // +0x330
    void *video_sink;              // +0x340
    uint32_t session_index;        // +0x348
};
```

`remote_ip` and UDP source ports are hard filters in RX. `FUN_1400152d0` converts the incoming source IP at frame offset `0x1a` into a dotted string and compares it to `remote_ip`. Audio must arrive from `audioport`; video must arrive from `videoport`.

## NIC Information Shape

`FUN_140020660` resolves a pcap device back to Windows `IP_ADAPTER_INFO`.

```c
struct NicInfo {
    uint8_t valid;                 // +0x00
    uint32_t gateway_ip;           // +0x04, from adapter gateway list
    uint32_t local_ip;             // +0x08, from adapter IP address
    uint8_t next_hop_mac[6];       // +0x0c, SendARP(gateway_ip)
    uint8_t local_mac[6];          // +0x12, adapter MAC
    char adapter_name_and_more[];  // +0x18..., copied from IP_ADAPTER_INFO
};
```

`FUN_140020ba0` writes Ethernet destination MAC from the pointer passed as `param_3` and source MAC from `param_2`. The TX call sites pass adjacent fields from this `NicInfo`, so LoLa's raw TX sends to the resolved next hop and uses the adapter MAC as source.

Connector implication: if the connector sends raw Ethernet, use the correct next-hop MAC for the route to the LoLa host. If using normal UDP sockets, the OS will handle ARP and Ethernet.

## Outbound Connect Pseudocode

`FUN_14002b9b0(main, session_id)`:

```c
void outbound_connect(Main *main, int sid) {
    string remote_ip = ui.session[sid].remote_ip_edit;
    string local_ip = ui.session[sid].local_ip_combo_selected;

    if (session[sid].rx->rx_running == false && ui.button != "Disconnect") {
        reject duplicate remote_ip already connected on either session;
        reject remote_ip == local_ip;
        reject remote_ip == "127.0.0.1" or "localhost";
        reject local_ip == "0.0.0.0";

        control->replied_or_status = 0;
        control->quickconn_success = 0;
        control->last_reject_text = "";

        send_control(QUICKCONN, src=local_ip, dst=remote_ip, sid=sid);

        for (elapsed = 0; elapsed < 2000; elapsed += 100) {
            if (control->replied_or_status || control->quickconn_success) break;
            Sleep(100);
        }

        if (control->quickconn_success) {
            copy ACK remote fields from control runtime to session[sid].rx;
            init_display_for_remote_video();
            init_audio_pcap_tx(sid, remote_ip, local_session_nic, audioport, audio_buffers);
            if (video_enabled) init_video_pcap_tx(sid, remote_ip, local_session_nic, videoport, VideoPacketSize);
            init_rx_pcap(session[sid].rx, local_session_nic, remote_ip, remote_compression);
            mark session active and update UI;
        } else {
            stop_rx_thread_if_needed(session[sid].rx);
            show timeout or reject text;
        }
    } else {
        disconnect_session(main, sid);
    }
}
```

Important detail: the dialog text says "within 3 sec", but the loop waits 20 * 100 ms = 2000 ms.

## Inbound QuickConn Pseudocode

`FUN_14002f3d0(main)` handles an incoming `/MESG_QUICKCONN` already stored in `control->last_message`.

```c
void inbound_quickconn(Main *main) {
    string src = extract("SRCIP:");
    string dst = extract("DSTIP:");
    int sid = atoi(extract("SID:"));

    find a free session whose selected local IP equals dst;
    reject busy if no free slot;
    reject duplicate src/dst match if already present;

    rx->remote_channels = atoi(extract("CHNLS:"));
    rx->remote_fps = (double)atoi(extract("FPS:"));
    rx->remote_bpp = atoi(extract("BPP:"));
    rx->remote_width = atoi(extract("X:"));
    rx->remote_height = atoi(extract("Y:"));
    rx->remote_sample_rate = (double)atoi(extract("SR:"));
    rx->remote_bits = atoi(extract("BPS:"));
    rx->remote_compression = atoi(extract("COMP:"));
    rx->remote_bayer = atoi(extract("BAYER:")) != 0;

    if (!validate_audio_compat(main, rx, show_box=false, reject_text)) {
        send_control(REJECT, src=dst, dst=src, sid=sid, TXT=reject_text);
        return;
    }

    send_control(QUICKCONN_ACK, src=dst, dst=src, sid=sid);
    rx->inbound_accepted = 1;
    rx->remote_ip = src;

    init_display_for_remote_video();
    init_audio_pcap_tx(...);
    if (video_enabled) init_video_pcap_tx(...);
    init_rx_pcap(rx, selected_nic, src, rx->remote_compression);
    mark session active and update UI;
}
```

The compatibility validator at `FUN_140029150` checks only:

- local channels at main `+0x1944` vs remote `+0x2b0`
- local sample rate at main `+0x1938` vs remote `+0x2d0`
- local bits/sample at main `+0x1940` vs remote `+0x2d8`

Video width, height, FPS, compression, and BPP are parsed and used later, but this validator does not reject on video mismatch.

## Disconnect Pseudocode

`FUN_14002c100(main, sid)`:

```c
void disconnect_session(Main *main, int sid) {
    maybe_close_chat_or_remote_info_panel();

    string dst = session[sid].rx->remote_ip;
    string src = session[sid].rx->session_nic_config->local_ip_string;
    send_control(DISCONNECT, src=src, dst=dst, sid=sid);

    stop_rx_session(session[sid].rx);       // FUN_1400174e0
    stop_audio_tx_for_session(audio_engine, sid);  // FUN_14000a800
    if (video_engine && video_enabled) stop_video_tx_for_session(video_engine, sid);
    stop_display_or_video_sink_for_session();

    session[sid].rx->remote_ip = "";
    session[sid].rx->rx_stopped = 0;
    main->session_active[sid] = 0;
    reset UI button/status;
}
```

`FUN_1400174e0(rx)` is the core RX stop helper:

```c
rx->rx_running = 0;
if (rx->rx_stopped_event) WaitForSingleObject(rx->rx_stopped_event, 1000);
rx->rx_stopped = 0;
```

Connector implication: when LoLa disconnects, stop sending media promptly. LoLa expects the RX thread to exit within about 1 second after its run flag is cleared.

## Audio TX Engine Shape

`FUN_14000a000` starts audio pcap TX for a session. `FUN_140009bf0` is the worker loop.

Relevant fields:

```text
+0x30    audio callback data-ready event
+0x3a    channel count as uint16, used for serialized payload length = channels << 7
+0x54    channel count or equivalent channel scalar used for packet sizing
+0x1288  pointer to current PCM callback buffer
+0x18e8  audio sequence counter
+0x18ec  audio TX run flag
+0x1910  audio UDP port
+0x1914  configured normal fragment packet size
+0x1920  FragmentEncoder*
+0x1948  byte stream object for serialized audio frame
+0x1968  serialized PCM byte length, channels << 7
+0x196c  raw Ethernet packet buffer size
+0x1b60  raw packet builder buffer
+0x1b68 + sid*0x220  remote IP string for audio TX
+0x1b88 + sid*0x220  NicInfo copy for audio TX
+0x1d68 + sid*0x220  pcap device list/current device
+0x1d70 + sid*0x220  pcap TX handle
+0x1d80 + sid*0x220  pcap active byte
+0x1fb0  audio TX stopped event
+0x1fe8  fixed/test buffer flag; if nonzero, sends synthetic buffer
```

Audio TX loop source-like model:

```c
void audio_tx_loop(AudioTx *a) {
    a->running = 1;
    encoder = new FragmentEncoder(packet_size);
    set packet_size to either channels*0x80 + 0x2a or 0x42a;
    serialized_len = channels << 7;  // 64 frames * 16-bit samples * channels

    ResetEvent(audio_stopped_event);
    ResetEvent(audio_data_ready_event);

    while (a->running) {
        stream.reset();
        stream.write_u32(a->sequence++);
        WaitForSingleObject(audio_data_ready_event, INFINITE);
        if (!a->running) break;
        ResetEvent(audio_data_ready_event);

        if (fixed_buffer_enabled) a->pcm_ptr = generated_test_buffer;
        stream.write_u32(serialized_len);
        stream.write_bytes(a->pcm_ptr, serialized_len);

        encoder.fragment(stream.ptr, stream.len);
        encoder.fragment[0].end_flag = 1;   // audio expected as one fragment

        for each of 2 sessions:
            if session pcap is active and not disabled:
                build_eth_ip_udp(audioport, audioport, fragment0);
                pcap_sendpacket(handle, frame, payload_len + 0x2a);
    }
}
```

The recovered RX path initializes audio reassembly with `fragment_count=1` and `expected_size = remote_channels * 0x80 + 8`, so a connector should send one audio fragment per 64-frame block.

## Video TX Engine Shape

`FUN_140012490` starts video pcap TX. `FUN_140011590` selects raw or JPEG:

```c
if (video->compression_flag == 1) jpeg_video_tx_loop(video);
else raw_video_tx_loop(video);
```

Relevant fields:

```text
+0x430   CWinThread* for video TX
+0x450   video frame-ready event
+0x458   recording/copy event
+0x468   video TX stopped event
+0x10c8  width for JPEG
+0x10cc  height for JPEG
+0x10d0  raw frame byte length when mode 0
+0x10d4  raw frame byte length when mode 1/input alternates
+0x10dc  bits per pixel for JPEG input
+0x1110  source mode selector for raw byte length
+0x1114  compression selector used by FUN_140011590
+0x1188  video sequence counter
+0x118c  video TX run flag
+0x11b0  video UDP port
+0x11b4  normal fragment packet size
+0x11b8  FragmentEncoder*
+0x11c0..0x11dc  video prelude metadata copied into 0x40 prelude
+0x1204  VideoPacketSize
+0x13e8 + sid*0x220  remote IP string for video TX
+0x1408 + sid*0x220  NicInfo copy for video TX
+0x15e8 + sid*0x220  pcap device list/current device
+0x15f0 + sid*0x220  pcap TX handle
+0x15f8 + sid*0x220  pcap sendqueue handle
+0x1600 + sid*0x220  pcap active byte
+0x1828  raw packet builder buffer
+0x1838  raw frame source pointer
+0x1980  recording/copy enabled flag
+0x1988  copied frame/compressed buffer pointer
+0x1990  copied frame/compressed buffer length
```

Raw video TX loop:

```c
void raw_video_tx_loop(VideoTx *v) {
    v->seq = 0;
    encoder = new FragmentEncoder(VideoPacketSize);
    v->running = 1;

    while (v->running) {
        WaitForSingleObject(frame_ready_event, INFINITE);
        if (!v->running) break;
        ResetEvent(frame_ready_event);

        uint32_t image_len = select_raw_frame_length();
        stream.reset();
        stream.write_u32(v->seq++);
        stream.write_u32(image_len);
        stream.write_bytes(v->raw_frame_ptr, image_len);

        encoder.fragment(stream.ptr, stream.len);

        prelude.magic = fd fd fd fd df df df df aa aa aa aa;
        prelude.frame_id = encoder.current_frame_id;
        prelude.serialized_size = stream.len;
        prelude.fragment_count = encoder.fragment_count;

        for each active session:
            queue raw Ethernet/IPv4/UDP packet with 0x40-byte prelude;

        for each fragment:
            if last fragment, fragment[0x20] = 1;
            for each active session:
                queue raw Ethernet/IPv4/UDP packet with normal fragment payload;

        transmit and destroy each pcap sendqueue;
    }
}
```

JPEG video TX is the same transport path, but it first compresses `+0x1838` using IJG JPEG with quality from the video/display settings object (`video->+0x440 + 0x9c`), then serializes `seq`, `jpeg_len`, and JPEG bytes.

## AV RX Loop Source Model

`FUN_1400152d0(rx)` handles both audio and video through one pcap loop.

Startup:

```c
rx->rx_running = 1;
ResetEvent(rx->rx_stopped_event);
audio_reasm = new FragmentReassembler();
video_reasm = new FragmentReassembler();
pcap_sendqueue_alloc(100000); // allocated but not central to RX semantics
```

For every captured frame:

```c
if (pcap_next_ex(rx->rx_pcap, &hdr, &frame) <= 0) continue_or_exit;

ip = frame + 0x0e;
udp = ip + ((ip[0] & 0x0f) * 4);
src_port = ntohs(udp[0:2]);
dst_port = ntohs(udp[2:4]);
udp_len = ntohs(udp[4:6]);
payload = udp + 8;
src_ip_string = dotted(frame[0x1a..0x1d]);

if (src_ip_string != rx->remote_ip) ignore;
```

Audio receive branch:

```c
if (src_port == config.audioport) {
    reasm.init(frame_id=payload.u32[0x0c],
               expected_size=rx->remote_channels * 0x80 + 8,
               fragment_count=1);
    reasm.add_fragment(payload);

    stream.bind(reasm.buffer, reasm.size);
    uint32_t seq = stream.read_u32();
    uint32_t pcm_len = stream.read_u32();
    if (pcm_len valid and ring space available) {
        stream.read_bytes(audio_ring[next], pcm_len);
        counters/audio events updated;
    }
}
```

Video receive branch, raw mode:

```c
if (src_port == config.videoport && rx->video_mode == 0) {
    if (!have_video_prelude) {
        if (udp_len == 0x48 && payload magic == fd fd fd fd df df df df aa aa aa aa) {
            frame_id = payload.u32[0x10];
            serialized_size = payload.u32[0x14];
            fragment_count = payload.u32[0x1c];
            video_reasm.init(frame_id, serialized_size, fragment_count);
            have_video_prelude = true;
        }
    } else {
        video_reasm.add_fragment(payload);
        if (complete || final_fragment_with_allowed_incomplete_threshold) {
            stream.bind(video_reasm.buffer, video_reasm.size);
            seq = stream.read_u32();
            image_len = stream.read_u32();
            stream.read_bytes(video_ring[next], image_len);
            SetEvent(video_frame_ready_event);
            have_video_prelude = false;
        }
    }
}
```

Video receive branch, JPEG mode:

```c
if (src_port == config.videoport && rx->video_mode == 1) {
    same prelude and fragment reassembly;
    stream.read_u32(seq);
    stream.read_u32(jpeg_len);

    if OptimizeJpegDecompression == 0:
        copy JPEG bytes, run IJG jpeg_mem_src/read_header/start_decompress/read_scanlines,
        write decompressed pixels to video ring.
    else:
        store compressed JPEG bytes in video sink and signal display/decoder path.
}
```

RX counters:

```text
audio:
  +0x270 good frames
  +0x274 invalid/dropped frames
  +0x278 sequence gaps
  +0x27c ring overrun/too-far-ahead condition

video:
  +0x288 good frames
  +0x28c invalid/dropped frames
  +0x290 frame id gaps
  +0x294 fragment frame id mismatch while assembling
  +0x298 unexpected fragment index/sequence while assembling
```

## Pcap Setup Source Model

RX setup `FUN_140016f20(rx, session_nic_config, remote_ip, compression)`:

```c
if (rx->rx_running) return;

rx->remote_ip = remote_ip;
rx->local_ip_for_filter = session_nic_config->local_ip_string;
rx->session_nic_config = session_nic_config;
rx->video_mode = compression;
rx->remote_compression = compression;

pcap_findalldevs(&rx->rx_all_devs);
if (NicDevName is configured) select pcap_if whose name contains it;
rx->local_nic = resolve_nic(rx->rx_all_devs);  // GetAdaptersInfo + SendARP
if (!rx->local_nic.valid) fail;

rx->rx_pcap = pcap_open(device_name, 0x10000, 8, 500, ...);
pcap_setmintocopy(rx->rx_pcap, config.WinPcap_SetMinToCopy);

filter = "ip and udp";
if (config.RxPacketFiltering != 0) {
    filter = format("ip and src host %s and dst host %s and (udp port %d or udp port %d)",
                    remote_ip, local_ip, videoport, audioport);
}
pcap_compile(..., optimize=1);
pcap_setfilter(...);

reset counters and start time;
AfxBeginThread(rx_loop, rx, priority=2);
```

TX setup for audio/video repeats the same pcap device selection per session and opens pcap TX handles with `pcap_open(device, 0xffff, ...)`, then starts the global TX worker if not already running.

## Raw Ethernet/IP/UDP Builder

`FUN_140020ba0(packet, src_mac, dst_mac, src_ip, dst_ip, src_port, dst_port, payload, payload_len)`:

```c
eth.dst = dst_mac;
eth.src = src_mac;
eth.type = 0x0800;

ip.version_ihl = 0x45;
ip.tos = 0;
ip.total_len = htons(payload_len + 0x1c);
ip.id = htons(0x1337);
ip.flags_frag = 0;
ip.ttl = 0x80;
ip.protocol = 0x11;
ip.checksum = 0 then computed;
ip.src = src_ip;
ip.dst = dst_ip;

udp.src_port = htons(src_port);
udp.dst_port = htons(dst_port);
udp.len = htons(payload_len + 8);
udp.checksum = computed;

memcpy(frame + 0x2a, payload, payload_len);
```

Both audio and video pass equal source and destination ports: `audioport` to `audioport`, `videoport` to `videoport`.

## Control Chat/Remote Commands

Incoming `/MESG_CHAT` stores `TXT:` in `control->last_chat_text` and posts UI message `0x8006`. The chat handler then:

1. Prepends a display label using the sender IP and session index.
2. Checks whether the received text contains known `lola.*` command strings.
3. Sends responses back through `/MESG_CHAT` via `FUN_1400329a0`.

Recognized commands:

```text
lola.GetRemoteInfo()
lola.ResetRemoteInfo()
lola.GetRemoteSettings()
lola.SetRemoteAudioBuffer(<n>);
lola.ForceDisconnect(<text-or-session>);
```

`lola.GetRemoteSettings()` returns a multi-section text block including:

```text
=== [Lola Info] ===
=== [HW/SW Info] ===
NICs:
OS:
=== [HW/SW Settings] ===
ASIO Buffer size
Camera File
Video FpS
Optimize JPEG decompression
SIMD Acceleration
Incomplete frame threshold
IP and UDP Advanced Filtering
VideoPacketSize
=== [A/V Buffers] ===
Audio
Video
```

`lola.SetRemoteAudioBuffer(n);` maps to a local audio buffer count of `max(1, n + 1)` internally, writes UI state, and calls `FUN_14000aaa0(audio_engine, sid, count)` if `count - 1 < 0x15`. `FUN_14000aaa0` stores `count` at `audio+0x1280+sid*4` and adjusts the audio ring write index modulo 100.

`lola.ForceDisconnect(...)` calls the same disconnect routine as a local user disconnect when it can map the remote text/session to a connected session, then replies with a confirmation chat string.

Chat sender `FUN_1400329a0` chunks long responses in 1024-byte units and sends each chunk as message ID `0x8016`. Because `FUN_14001fb60` treats chat specially, chat sends are dispatched through a detached helper thread that ultimately calls the same 1024-byte UDP sender.

## Source-Like Connector Contract

Minimum stable connector behavior inferred from static source reconstruction:

1. Start a UDP control listener on connector `socketport` before initiating QuickConn.
2. Send fixed-compatible control datagrams: ASCII `/MESG_*` text, NUL padded to 1024 bytes.
3. Implement the semicolon key/value parser exactly enough for missing-field-as-zero behavior and unescaped `TXT`.
4. On inbound LoLa QuickConn, parse `SRCIP`, `DSTIP`, `SID`, `SR`, `BPS`, `CHNLS`, `FPS`, `BPP`, `X`, `Y`, `COMP`, `BAYER`.
5. ACK only if connector audio settings match LoLa: channels, sample rate, bits/sample.
6. After ACK, be ready immediately for pcap-visible audio/video UDP packets from LoLa.
7. Send media with source IP equal to the `SRCIP` used in control and source ports equal to the target stream ports.
8. For audio, send one normal LoLa fragment containing serialized `uint32 seq`, `uint32 pcm_len`, `pcm bytes`.
9. For video, send one 0x40-byte prelude before normal fragments for each frame.
10. For raw video, serialize `uint32 seq`, `uint32 image_len`, raw bytes.
11. For JPEG video, serialize `uint32 seq`, `uint32 jpeg_len`, JPEG bytes.
12. On disconnect, send `/MESG_DISCONNECT` and stop streams quickly.

## Remaining Static Uncertainties

- The original C++ class names are not recoverable from these exports; names above are source-like labels.
- Audio TX length is clearly `channels << 7` in the recovered loop, which corresponds to 64 frames of 16-bit samples per channel. If LoLa supports non-16-bit runtime audio elsewhere, this specific TX path needs dynamic confirmation.
- The raw Ethernet builder uses the adapter/default-gateway next-hop MAC resolved by `SendARP`. For routed vs same-subnet deployments, dynamic packet capture should confirm which MAC LoLa actually emits and accepts.
- Normal UDP transmission from a connector should be visible to LoLa's pcap RX on the selected NIC, but same-host loopback is explicitly rejected by the GUI and not a valid test path.
- The tester binary contains older strings such as `/MESG_ACCEPT` and `/MESG_BOUNCEBACKCONN`; the 2.0.0 XIMEA GUI path analyzed here uses `/MESG_QUICKCONN` and `/MESG_QUICKCONN_ACK`.

