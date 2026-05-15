from __future__ import annotations

from textwrap import dedent

from compatibility_model import OUT_DIR, fmt_counts, table_row

def write_readme(rows: list[dict[str, object]]) -> None:
    include_count = sum(1 for row in rows if str(row["scope"]).startswith("include"))
    protocol_count = sum(1 for row in rows if "protocol" in str(row["tier"]))
    codec_count = sum(1 for row in rows if "codec" in str(row["tier"]))
    runtime_count = sum(1 for row in rows if row["tier"] == "runtime-only")

    text = dedent(
        f"""\
        # LoLa 2.0 Legacy Compatibility Mode RE Base

        This addendum turns the static v2.0 folder analysis into an implementable
        base for a Windows Legacy Compatibility Mode. It is still static-only:
        no Windows EXE, DLL, installer, or helper was executed.

        ## Current Verdict

        - Legacy Compatibility Mode planning base: confirmed.
        - Session/control grammar base: confirmed statically.
        - Codec selection base: confirmed for PCM audio plus raw video/CPU MJPEG video.
        - Media packet envelope base: observed/inferred from packet-builder xrefs.
        - Byte-exact LoLa AV TX/RX compatibility: partial; requires isolated Windows peer captures.

        `VERDICT: PARTIAL`

        ## Corpus Coverage

        - Artifacts classified for compatibility scope: `{len(rows)}`
        - Included or included-after-main artifacts: `{include_count}`
        - Protocol-critical artifacts: `{protocol_count}`
        - Codec/optional-codec artifacts: `{codec_count}`
        - Runtime-only artifacts intentionally excluded from protocol logic: `{runtime_count}`

        ## Compatibility Layers

        | Layer | Static status | Implementation implication |
        |---|---|---|
        | L0 artifact/dependency map | confirmed | Every file has a compatibility tier and next validation step. |
        | L1 session/control text grammar | confirmed | Implement `/MESG_*` parser and generator first. |
        | L2 config/profile import | confirmed | Parse `LolaGui.ini` keys and shipped camera profile INI lines. |
        | L3 media envelope | inferred | Implement parser/builder behind PCAP fixtures, not live network first. |
        | L4 audio media | inferred | Start with PCM 16-bit frames, 64 samples/channel per packet hypothesis. |
        | L5 video media | inferred | Support raw frame chunks and CPU MJPEG chunks; GPUJPEG remains optional/unproven. |
        | L6 byte-exact peer interop | requires validation | Needs Windows LoLa peer, owned hardware or fixtures, and packet captures. |

        ## Files In This Addendum

        - [compatibility-artifact-map.md](compatibility-artifact-map.md)
        - [string-interest-triage.md](string-interest-triage.md)
        - [exe-deep-summary.md](exe-deep-summary.md)
        - [av-tx-rx-protocol-decoding.md](av-tx-rx-protocol-decoding.md)
        - [codec-and-media-findings.md](codec-and-media-findings.md)
        - [legacy-compatibility-roadmap.md](legacy-compatibility-roadmap.md)
        - [definition-of-done-ledger.md](definition-of-done-ledger.md)
        - [data/compatibility-artifacts.json](data/compatibility-artifacts.json)

        ## Safety Boundary

        Network use is not needed for this static addendum. Licensing, DRM,
        authentication, access-control bypass, and credential extraction are not
        part of this compatibility base.
        """
    )
    (OUT_DIR / "README.md").write_text(text, encoding="utf-8")


def write_artifact_map(rows: list[dict[str, object]]) -> None:
    lines = [
        "# Compatibility Artifact Map",
        "",
        "Every source artifact is mapped to its Legacy Compatibility Mode relevance.",
        "The full import/export/hash inventory remains in `../artifact-inventory.md` and `../data/artifacts.json`.",
        "",
        table_row(["Path", "Tier", "Scope", "String categories", "Compatibility use", "Next validation"]),
        "|---|---|---|---|---|---|",
    ]
    for row in rows:
        lines.append(
            table_row(
                [
                    f"`{row['path']}`",
                    row["tier"],
                    row["scope"],
                    fmt_counts(row["string_category_counts"]),
                    row["compatibility_use"],
                    row["next_validation"],
                ]
            )
        )
    lines.extend(
        [
            "",
            "## Implementation Scope Decision",
            "",
            "| Decision | Artifacts | Rationale |",
            "|---|---|---|",
            "| Implement directly | `LolaGui_XIMEA_x64.exe`, profile INIs, session grammar, packet parser/builder fixtures | These define LoLa wire/session compatibility. |",
            "| Model as API boundary | `portaudio_x64.dll`, `xiapi64.dll`, `jpeg62.dll`, OpenCV DLLs | These define media I/O and codec behavior but should not be cloned as binaries in a native compatibility layer. |",
            "| Keep optional until proven | `gpujpeg.dll`, `cudart64_55.dll` | GPUJPEG exists, but the main v2.0 GUI does not statically link it. |",
            "| Exclude from protocol logic | MFC/MSVC runtime DLLs, `.DS_Store`, installers | They are deployment or metadata artifacts, not LoLa TX/RX grammar. |",
        ]
    )
    (OUT_DIR / "compatibility-artifact-map.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_string_triage(rows: list[dict[str, object]]) -> None:
    lines = [
        "# String Interest Triage",
        "",
        "This document classifies the string categories already extracted in `../strings-of-interest.md`.",
        "The goal is to decide which strings become compatibility contracts and which remain dependency noise.",
        "",
        "| Category | Compatibility decision | Classification |",
        "|---|---|---|",
        "| `session` | Implement parser/generator for `/MESG_*`, `SRCIP`, `DSTIP`, `SID`, `TXT`, and quick-connection A/V fields. | confirmed |",
        "| `network` | Implement defaults, BPF/filter expectations, packet envelope parser, and PCAP fixture reader. | confirmed/inferred |",
        "| `audio` | Implement PortAudio-facing settings and PCM frame assumptions; validate callback scheduling later. | inferred |",
        "| `video` | Implement camera profile import, raw frame metadata, XIMEA mode mapping, and display/recording formats. | observed/inferred |",
        "| `codec` | Implement CPU MJPEG first; keep GPUJPEG optional until dynamic reachability is proven. | confirmed/inferred |",
        "| `timing` | Treat as design hints: small buffers, sendqueues, counters, and ring depths; validate with captures. | inferred |",
        "| `config` | Parse and round-trip LoLa INI keys that affect AV/session compatibility. | confirmed |",
        "| `identity` | Use only for artifact identification, not runtime protocol behavior. | observed |",
        "| `licensing_or_identity_surface` | Exclude from compatibility implementation except benign hardware identity display. | excluded |",
        "",
        "## Per-Artifact String Counts",
        "",
        table_row(["Path", "Tier", "String categories"]),
        "|---|---|---|",
    ]
    for row in rows:
        lines.append(table_row([f"`{row['path']}`", row["tier"], fmt_counts(row["string_category_counts"])]))
    lines.extend(
        [
            "",
            "## High-Value Strings For Legacy Compatibility",
            "",
            "- `/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;`",
            "- `/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;`",
            "- `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`",
            "- `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`",
            "- `/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`",
            "- `/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;`",
            "- `/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;`",
            "- `/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;`",
            "- `/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`",
            "- `/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`",
            "- `/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`",
            "- `socketport`, `audioport`, `videoport`, `WinPcap_SetMinToCopy`, `RxPacketFiltering`, `VideoPacketSize`",
            "- `SamplingRate`, `NumOfChannels`, `bitPerSample`, `FrameRate`, `bitPerPixel`, `FrameX`, `FrameY`, `Compression`, `CompressionQuality`, `BayerDec`",
            "- `M-JPEG (CPU)`, `jpeg_CreateCompress`, `jpeg_mem_dest`, `jpeg_write_scanlines`, `jpeg_CreateDecompress`, `jpeg_mem_src`, `jpeg_read_scanlines`",
        ]
    )
    (OUT_DIR / "string-interest-triage.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_exe_summary() -> None:
    text = dedent(
        """\
        # EXE Deep Summary

        This summary incorporates the Ghidra static summaries for every LoLa-owned
        EXE in the v2.0 folder. Installers remain static inventory items and were
        not executed.

        | EXE | Static role | AV/TX/RX relevance | Ghidra evidence | Compatibility decision |
        |---|---|---|---|---|
        | `LolaGui_XIMEA_x64.exe` | Primary v2.0 GUI/runtime | Live audio capture/playback, XIMEA video capture/rendering, session control, WinPcap AV media TX/RX | `v2-main.*.md`: PortAudio, XIMEA, WinPcap, JPEG, control templates, packet builder | Implement compatibility model from this binary first. |
        | `LolaGui_Tester/LolaGui_TESTER_x64.exe` | Tester/support GUI | Corroborates WinPcap send/receive/sendqueue and JPEG compression in a smaller support corpus | `v2-tester.ghidra-summary.md`: `pcap_next_ex`, `pcap_sendpacket`, sendqueue functions, `pcap_setfilter`, `jpeg_CreateCompress`, `jpeg_mem_dest`, `jpeg_write_scanlines` | Use as cross-check for packet/sendqueue behavior after the main field map is named. |
        | `LolaVideoConverter_x64.exe` | Offline video conversion/view helper | No live AV TX/RX role; confirms OpenCV/IJG/GDI image handling and saved-frame lineage | `v2-video-converter.ghidra-summary.md`: OpenCV `Mat`/`InputArray`, GDI `CreateDIBSection`/`StretchBlt`, JPEG/OpenCV dependency surface | Use for saved-frame/import/export compatibility only. |
        | `LolaWavSplitter_x64.exe` | Offline WAV split/conversion helper | No live AV TX/RX role; confirms multichannel WAV handling and WINMM/mmio file workflow | `v2-wav-splitter.ghidra-summary.md`: `mmioOpenA`, `mmioRead`, `mmioWrite`, `mmioCreateChunk`, string says input must contain at least 2 channels | Use for legacy recording import/split behavior only. |

        ## EXE-Level Findings

        - The main GUI is the only artifact that combines PortAudio, XIMEA,
          WinPcap, OpenCV, IJG JPEG, Winsock/IP Helper, and session/control strings.
        - The tester GUI independently proves the LoLa codebase has a smaller
          WinPcap sendqueue/receive corpus with JPEG compression. This is useful
          for naming packet helper behavior, but it is not the primary v2.0 XIMEA runtime.
        - The video converter does not add live network protocol evidence. It is
          relevant for file-format compatibility and rendering/saved-frame behavior.
        - The WAV splitter does not add live network protocol evidence. It is
          relevant for legacy recording import and multichannel-to-mono workflows.

        ## Static Depth Boundary

        Third-party DLLs were analyzed at file type, hash, architecture, import,
        export, resource, and string-interest depth. They are intentionally treated
        as API/dependency boundaries unless a LoLa-owned EXE calls into them in a
        compatibility-relevant way.
        """
    )
    (OUT_DIR / "exe-deep-summary.md").write_text(text, encoding="utf-8")


def write_protocol_doc() -> None:
    text = dedent(
        """\
        # AV TX/RX Protocol Decoding

        ## Static Ground Truth

        | Finding | Status | Evidence |
        |---|---|---|
        | Control/session messages are plaintext `/MESG_*` strings. | confirmed | `FUN_14001fb60` builds the templates; `FUN_14001f390` parses command strings and dispatches UI messages. |
        | Quick connection negotiates A/V format. | confirmed | `SR`, `BPS`, `CHNLS`, `FPS`, `BPP`, `X`, `Y`, `COMP`, and `BAYER` are in quick-connect and quick-connect ACK templates. |
        | Default ports are control 7000, audio 19788, video 19798. | confirmed | `FUN_14002a6e0` reads `socketport` default `7000`, `audioport` default `0x4d4c`, `videoport` default `0x4d56`. |
        | Receive filtering targets UDP from peer source to local destination and audio/video ports. | confirmed | `FUN_140016f20` compiles `ip and src host %s and dst host %s and (udp port %d or udp port %d)`. |
        | Media packets are built as Ethernet + IPv4 + UDP style frames with payload at offset `0x2a`. | observed/inferred | `FUN_140020ba0` copies payload to `*param_1 + 0x2a`; callers send `payload_length + 0x2a`. |
        | Audio packet size formula is `0x2a + channels * 0x80`. | inferred | `FUN_140009bf0` computes `*(int *)(param_1 + 0x54) * 0x80 + 0x2a`. |
        | Raw video and CPU MJPEG both use WinPcap sendqueue batching. | confirmed | `FUN_1400115c0` and `FUN_140011c10` call `pcap_sendqueue_alloc`, `pcap_sendqueue_queue`, `pcap_sendqueue_transmit`, and `pcap_sendqueue_destroy`. |
        | CPU MJPEG receive path exists. | confirmed | `FUN_1400152d0` calls `jpeg_CreateDecompress`, `jpeg_mem_src`, and `jpeg_read_scanlines` after `pcap_next_ex`. |

        ## Session Grammar Base

        ```text
        check_status      = /MESG_CHECKLOLASTATUS;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;
        check_status_ack  = /MESG_CHECKLOLASTATUS_ACK;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;
        quickconn         = /MESG_QUICKCONN;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;SR:<int>;BPS:<int>;CHNLS:<int>;FPS:<int>;BPP:<int>;X:<int>;Y:<int>;COMP:<int>;BAYER:<int>
        quickconn_ack     = /MESG_QUICKCONN_ACK;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;SR:<int>;BPS:<int>;CHNLS:<int>;FPS:<int>;BPP:<int>;X:<int>;Y:<int>;COMP:<int>;BAYER:<int>
        reject            = /MESG_REJECT;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;TXT:<text>
        disconnect        = /MESG_DISCONNECT;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;
        switch_on_bb      = /MESG_SWITCH_ON_BB;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;
        switch_off_bb     = /MESG_SWITCH_OFF_BB;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;
        chat              = /MESG_CHAT;SRCIP:<ip>;DSTIP:<ip>;SID:<int>;TXT:<text>
        send_audio_signal = /MESG_SEND_AUDIO_SIGNAL;SRCIP:<ip>;DSTIP:<ip>;SID:<int>
        stop_audio_signal = /MESG_STOP_AUDIO_SIGNAL;SRCIP:<ip>;DSTIP:<ip>;SID:<int>
        ```

        Compatibility parser rule: parse by command prefix first, then semicolon-separated
        key/value fields. Preserve original command spelling and tolerate absent trailing
        semicolon for the two audio-signal messages because the static templates omit it.

        ## Media Envelope Model

        ```text
        wire_frame =
          ethernet_header[14]
          ipv4_header[20]
          udp_header[8]
          lola_payload[n]

        lola_payload starts at wire offset 0x2a.
        ```

        `0x2a` is exactly 42 decimal, matching Ethernet + IPv4 + UDP without options.
        The packet builder also calls a Winsock ordinal with `0x1337`; this is most
        likely a network-byte-order conversion for a fixed field, but the specific
        field must not be named without a byte-level packet fixture.

        ## Audio TX/RX Base

        Static inference:

        ```text
        audio_wire_size = 42 + channels * 128
        audio_payload_size = channels * 128
        likely samples_per_packet_per_channel = 64 when BPS == 16
        ```

        Implications:

        - 1 channel, 16-bit: 128 byte payload, 170 byte wire frame.
        - 2 channels, 16-bit: 256 byte payload, 298 byte wire frame.
        - 8 channels, 16-bit: 1024 byte payload, 1066 byte wire frame.
        - At 48 kHz and 64 samples/packet, the sender emits 750 audio packets/s.
        - At 44.1 kHz and 64 samples/packet, the cadence is 689.0625 packets/s.

        This is enough to design the compatibility-mode audio frame abstraction,
        but not enough to mark the payload byte order, sequence fields, or drift policy
        as confirmed. The expected payload is PCM because `BPS`, channel count,
        PortAudio/ASIO, and WAV recording paths align; exact endianness is still a
        validation item, with little-endian as the Windows-native hypothesis.

        ## Video TX/RX Base

        Confirmed paths:

        - `FUN_1400115c0`: raw video sendqueue TX.
        - `FUN_140011c10`: CPU MJPEG encode plus sendqueue TX.
        - `FUN_1400152d0`: receive, reassembly, optional CPU JPEG decode.
        - `FUN_140012ec0`: XIMEA acquisition loop with a 30-slot ring modulo `0x1e`.

        Static sendqueue hints:

        ```text
        sendqueue_budget = (chunk_or_encoded_size + 0x32) * 0x1e
        packet_payload_offset = 0x2a
        video_ring_slots = 0x1e
        ```

        The `0x1e` value is confirmed as 30 in capture/ring logic and sendqueue
        sizing. The exact fragment count, sequence numbering, and per-fragment LoLa
        header remain to be recovered from byte-level packet fixtures or deeper
        decompiler variable recovery.

        ## Suspected TX/RX Pipeline

        ```mermaid
        flowchart LR
          AudioIn[PortAudio ASIO input] --> AudioFrame[64-sample/ch PCM frame hypothesis]
          AudioFrame --> PacketBuilder[FUN_140020ba0 payload at 0x2a]
          Camera[XIMEA xiGetImage] --> VideoRing[30-slot frame ring]
          VideoRing --> RawVideo[raw video chunks]
          VideoRing --> Mjpeg[jpeg_mem_dest CPU MJPEG]
          RawVideo --> PacketBuilder
          Mjpeg --> PacketBuilder
          PacketBuilder --> PcapTx[WinPcap sendpacket/sendqueue]
          PcapRx[pcap_next_ex + BPF] --> Reassembly[fragment/reassembly buffers]
          Reassembly --> AudioOut[PortAudio output]
          Reassembly --> JpegDecode[jpeg_mem_src CPU decode]
          JpegDecode --> Display[OpenCV/GDI/D2D display]
        ```

        ## Known Unknowns Blocking "Fully Decoded"

        - LoLa media payload header field order and size.
        - Sequence number, timestamp, frame ID, and channel marker locations.
        - Audio byte order and signedness as observed on the wire.
        - Video fragmentation boundary rules for raw and MJPEG modes.
        - Drop, realignment, buffer underrun, and clock-drift policy.
        - Dynamic loading of `gpujpeg.dll`, if any.
        """
    )
    (OUT_DIR / "av-tx-rx-protocol-decoding.md").write_text(text, encoding="utf-8")


def write_codec_doc() -> None:
    text = dedent(
        """\
        # Codec And Media Findings

        ## Audio Codec

        | Finding | Classification | Compatibility decision |
        |---|---|---|
        | Audio uses PortAudio/ASIO and negotiates `SR`, `BPS`, and `CHNLS`. | confirmed | Implement an internal PCM stream model keyed by sample rate, bits per sample, and channels. |
        | Audio packet payload size is `channels * 128`. | inferred | Start with 64 samples/channel/packet for 16-bit PCM. |
        | WAV recording helpers exist. | confirmed | Use WAV fixtures to validate sample interpretation, not network timing. |
        | ASIO buffers must be 32 or 64 samples. | observed | Build low-latency buffering around small fixed audio quanta. |

        The compatibility-mode starting point should be signed 16-bit PCM in Windows
        little-endian order. That is a hypothesis until packet captures prove the wire
        order, but it is the most coherent assumption from `BPS`, PortAudio, Windows,
        and WAV evidence.

        ## Video Codecs

        | Codec path | Classification | Evidence | Compatibility decision |
        |---|---|---|---|
        | Raw/uncompressed video | inferred | Raw TX function `FUN_1400115c0`, `BPP`, `X`, `Y`, `BAYER`, camera profiles. | Implement after packet fragment header is mapped. |
        | CPU MJPEG | confirmed | `jpeg62.dll`, `jpeg_CreateCompress`, `jpeg_mem_dest`, `jpeg_write_scanlines`, `jpeg_CreateDecompress`, `jpeg_mem_src`, `jpeg_read_scanlines`. | Implement first compressed-video path. |
        | GPUJPEG/CUDA | observed/unproven | `gpujpeg.dll` and `cudart64_55.dll` are present, but the main GUI does not statically import them. | Keep optional; do not block LCM v1 on GPUJPEG. |

        ## Camera And Pixel Formats

        Confirmed profile evidence:

        - XIMEA profiles include Mono8 and RGB24 at 60 FPS across xiQ/XiC/generic modes.
        - PtGrey profiles include Mono8 and RGB24, many at 120 FPS, but the v2.0 XIMEA GUI does not statically link a PtGrey SDK.
        - Quick-connect format fields carry `FPS`, `BPP`, `X`, `Y`, `COMP`, and `BAYER`.
        - XIMEA setup touches `imgdataformat`, `RGB24`, `width`, `height`, `offsetX`, `offsetY`, `auto_wb`, `wb_kr`, `wb_kg`, `wb_kb`, `gammaY`, and `gammaC`.

        Compatibility decision: treat camera hardware as an adapter behind a LoLa
        frame model. The wire/profile parser should not depend on XIMEA-specific APIs,
        but it must preserve all negotiated fields.

        ## Codec Implementation Order

        1. Session `COMP` field parser with explicit enum names only after capture confirms values.
        2. PCM audio frame abstraction and packet fixture parser.
        3. CPU MJPEG decode/encode using a standard JPEG library.
        4. Raw video chunk parser once frame/fragment header fields are recovered.
        5. GPUJPEG bridge only if dynamic-load or capture evidence proves LoLa v2.0 uses it.
        """
    )
    (OUT_DIR / "codec-and-media-findings.md").write_text(text, encoding="utf-8")
