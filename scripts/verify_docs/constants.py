from __future__ import annotations

from pathlib import Path

from .archive_inventory import archive_doc_patterns

ROOT = Path.cwd()
ARCHIVE_TOPOLOGY_MANIFEST = Path(__file__).with_name("archive_topology.txt")


def _manifest_section(path: Path, section: str) -> tuple[str, ...]:
    if not path.is_file():
        return ()

    values: list[str] = []
    in_section = False
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_section = line == f"[{section}]"
            continue
        if in_section:
            values.append(line)
    return tuple(values)


ARCHIVED_TOPOLOGY_PATHS = _manifest_section(ARCHIVE_TOPOLOGY_MANIFEST, "archive-topology")

DOC_PATTERNS = (
    "README.md",
    "MAC_PORT_PLAN.md",
    *archive_doc_patterns(ROOT),
    "archive/2026-05-05-doc-consolidation/MANIFEST.md",
    "private/**/*.md",
    "docs/**/*.md",
)

DOC_IGNORE_PREFIXES = (
    (".build",),
    (".pytest_cache",),
    (".ruff_cache",),
    ("re_out",),
    *(tuple(path.split("/")) for path in _manifest_section(ARCHIVE_TOPOLOGY_MANIFEST, "doc-ignore-prefix")),
)

REQUIRED_TOPICS = (
    "Core Audio",
    "AudioDeviceIOProc",
    "AUHAL",
    "UDP PCM",
    "drift",
    "PLC",
    "AVB",
    "DSCP",
    "PTP",
    "AVFoundation",
    "VideoToolbox",
    "OSC",
    "sACN",
    "Art-Net",
    "validation",
    "risk",
    "progress",
    "Resume here",
)

ACTIVE_MAC_PORT_DOCS = (
    "docs/implementation-handoff.md",
    "docs/mac-to-mac-connection.md",
    "docs/open-questions.md",
    "docs/risk-register.md",
)

ARCHIVE_MANIFEST = ROOT / "archive" / "2026-05-05-doc-consolidation" / "MANIFEST.md"

IMPLEMENTATION_COMPANION_HEADINGS = (
    "Active Files",
    "File-by-File Disposition",
    "Implementation Stage",
    "Completed",
    "Missing",
    "Resume Here",
)

OPEN_QUESTIONS = ROOT / "docs" / "open-questions.md"
EVIDENCE_MATRIX = (
    ROOT
    / "archive"
    / "2026-05-11-research-archive"
    / "docs"
    / "research"
    / "RESEARCH_EVIDENCE_MATRIX_2026.md"
)
IMPLEMENTATION_COMPANION = ROOT / "docs" / "implementation-handoff.md"
RELEASE_HARDENING_REPORT = (
    ROOT / "archive" / "2026-05-05-doc-consolidation" / "mac-port" / "reports" / "M14_RELEASE_HARDENING_2026-05-03.md"
)
PUBLIC_ARCHITECTURE_DOCS = (
    "docs/clean-room-design-rules.md",
    "docs/latency-first-architecture.md",
    "docs/latency-budget.md",
    "docs/latency-profiles.md",
    "docs/p2p-networking.md",
    "docs/audio-rme-madi.md",
    "docs/audio-routing.md",
    "docs/multichannel-transport.md",
    "docs/rme-madi-routing.md",
    "docs/rx-buffering.md",
    "docs/video-blackmagic-atem.md",
    "docs/lighting-control.md",
    "docs/benchmark-methodology.md",
)
PUBLIC_PLANNING_DOCS = (
    "docs/current-state.md",
    *PUBLIC_ARCHITECTURE_DOCS,
)
PUBLIC_EVIDENCE_LABEL_HEADING = "Evidence Labels"
PUBLIC_EVIDENCE_LABELS = (
    "public standard",
    "public API",
    "original open-lola design",
    "experimentally derived requirement",
    "compatibility requirement",
    "implementation hypothesis",
)
PUBLIC_PLANNING_REQUIRED_TOKENS = (
    "clean-room",
    "public standard",
    "original open-lola design",
    "experimentally derived requirement",
    "implementation hypothesis",
    "AudioDeviceIOProc",
    "Core Audio",
    "UDP",
    "P2P",
    "RME",
    "Blackmagic",
    "ATEM",
    "OSC",
    "sACN",
    "Art-Net",
    "VERDICT: PARTIAL",
)
PUBLIC_PLANNING_FORBIDDEN_TOKENS = (
    "/MESG_",
    "pcap_",
    "xiGetImage",
    "xiOpenDevice",
    "PDB",
)
PUBLIC_RELEASE_FORBIDDEN_TOKENS = (
    "/MESG_",
    "pcap_",
    "xiGetImage",
    "xiOpenDevice",
)
PUBLIC_RELEASE_INTERNAL_LINK_PREFIXES = (
    "../reverse-engineering",
    "../../reverse-engineering",
    "../private",
    "../../private",
    "../archive/2026-05-11-win-compiled/win-compiled",
    "../../archive/2026-05-11-win-compiled/win-compiled",
)
PUBLIC_ACTIVE_STALE_REFERENCES = (
    "docs/milestones/",
    "milestones/",
    "docs/roadmap/mac-port-public-roadmap.md",
    "docs/source-contracts/MXX-",
    "docs/testing/verification-matrix.md",
    "docs/compliance/open-questions.md",
    "docs/compliance/release-artifact-hygiene.md",
    "docs/fixture-provenance.md",
    "docs/compliance/dependency-license-review.md",
    "docs/compliance/notices-attribution-register.md",
    "docs/compliance/sdk-license-notes.md",
    "architecture/implementation-roadmap.md",
    "M01-M14",
    "Public M01-M14",
)
WINDOWS_STATIC_ANALYSIS = (
    ROOT / "private" / "reverse-engineering" / "lola-2-windows" / "static-analysis.md"
)
WINDOWS_RUNTIME_ANALYSIS = (
    ROOT / "private" / "reverse-engineering" / "lola-2-windows" / "runtime-analysis.md"
)
WINDOWS_15_CORPUS = ROOT / "archive/2026-05-11-win-compiled/win-compiled/1-5"
WINDOWS_20_CORPUS = ROOT / "archive/2026-05-11-win-compiled/win-compiled/2-0"

CONTROL_MESSAGE_TEMPLATES = {
    "/MESG_CHECKLOLASTATUS": "/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;",
    "/MESG_CHECKLOLASTATUS_ACK": "/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;",
    "/MESG_QUICKCONN": (
        "/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;"
        "SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d"
    ),
    "/MESG_QUICKCONN_ACK": (
        "/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;"
        "SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d"
    ),
    "/MESG_REJECT": "/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s",
    "/MESG_DISCONNECT": "/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;",
    "/MESG_SWITCH_ON_BB": "/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;",
    "/MESG_SWITCH_OFF_BB": "/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;",
    "/MESG_CHAT": "/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s",
    "/MESG_SEND_AUDIO_SIGNAL": "/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d",
    "/MESG_STOP_AUDIO_SIGNAL": "/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d",
}

CONTROL_MESSAGE_REQUIRED_FIELDS: dict[str, tuple[str, ...]] = {
    message: ("SRCIP", "DSTIP", "SID")
    for message in CONTROL_MESSAGE_TEMPLATES
}
CONTROL_MESSAGE_REQUIRED_FIELDS["/MESG_REJECT"] = ("SRCIP", "DSTIP", "SID", "TXT")
CONTROL_MESSAGE_REQUIRED_FIELDS["/MESG_CHAT"] = ("SRCIP", "DSTIP", "SID", "TXT")

NETWORK_SURFACE_IMPORTS = {
    "wpcap.dll": (
        "pcap_close",
        "pcap_compile",
        "pcap_findalldevs",
        "pcap_findalldevs_ex",
        "pcap_freealldevs",
        "pcap_next_ex",
        "pcap_open",
        "pcap_sendpacket",
        "pcap_sendqueue_alloc",
        "pcap_sendqueue_destroy",
        "pcap_sendqueue_queue",
        "pcap_sendqueue_transmit",
        "pcap_setfilter",
        "pcap_setmintocopy",
    ),
    "WS2_32.dll": (
        "WSACleanup",
        "WSAGetLastError",
        "WSAStartup",
        "bind",
        "closesocket",
        "freeaddrinfo",
        "getaddrinfo",
        "gethostname",
        "getnameinfo",
        "htonl",
        "htons",
        "inet_addr",
        "inet_pton",
        "ntohs",
        "recvfrom",
        "sendto",
        "socket",
    ),
    "IPHLPAPI.DLL": (
        "GetAdaptersInfo",
        "IcmpCloseHandle",
        "IcmpCreateFile",
        "IcmpSendEcho",
        "SendARP",
    ),
}

NETWORK_SURFACE_STRINGS = (
    "ip and udp",
    "ip and src host %s and dst host %s and (udp port %d or udp port %d)",
    "audioport",
    "videoport",
    "VideoTxWinPcap",
    "WinPcap_SetMinToCopy",
    "RxPacketFiltering",
)

AUDIO_SURFACE_MAIN_IMPORT_ORDINALS = {
    3: "Pa_GetErrorText",
    4: "Pa_Initialize",
    5: "Pa_Terminate",
    6: "Pa_GetHostApiCount",
    8: "Pa_GetHostApiInfo",
    10: "Pa_HostApiDeviceIndexToDeviceIndex",
    15: "Pa_GetDeviceInfo",
    17: "Pa_OpenStream",
    19: "Pa_CloseStream",
    21: "Pa_StartStream",
    22: "Pa_StopStream",
    24: "Pa_IsStreamStopped",
    25: "Pa_IsStreamActive",
    50: "PaAsio_GetAvailableBufferSizes",
}

AUDIO_SURFACE_EXPORTS = tuple(AUDIO_SURFACE_MAIN_IMPORT_ORDINALS.values()) + (
    "PaAsio_GetInputChannelName",
    "PaAsio_GetOutputChannelName",
)

AUDIO_SURFACE_STRINGS = (
    "ASIO",
    "ASIOAudio",
    "ASIOAudio: dev open stream error (+%s)",
    "No ASIO devices available!",
    "ASIO Buffer size: %d samples",
    "It seems that your audio card has been configured with a Buffer Size of %d samples.",
    "32 or 64 samples",
    "AudioBuffersWarning",
    "AudioTxFixedBuffer",
    "SamplingRate",
    "_Local.wav",
    "_Remote.wav",
    "AudSndThreadEnded",
    "AudioRxEvent%d",
)

VIDEO_SURFACE_XIMEA_IMPORTS = (
    "xiGetImage",
    "xiStopAcquisition",
    "xiStartAcquisition",
    "xiCloseDevice",
    "xiOpenDevice",
    "xiGetNumberDevices",
    "xiSetParamFloat",
    "xiGetParamInt",
    "xiGetParamString",
    "xiSetParamInt",
    "xiGetParamFloat",
)

VIDEO_SURFACE_OPENCV_IMPORT_FRAGMENTS = {
    "opencv_core249.dll": (
        "?rectangle@cv@@",
        "?putText@cv@@",
    ),
    "opencv_highgui249.dll": (
        "?imwrite@cv@@",
    ),
    "opencv_imgproc249.dll": (
        "?cvtColor@cv@@",
        "?resize@cv@@",
    ),
}

VIDEO_SURFACE_GDI_IMPORTS = (
    "CreateDIBSection",
    "SetDIBColorTable",
    "StretchBlt",
)

VIDEO_SURFACE_STRINGS = (
    ".\\CAMERAFILES\\Ximea.ini",
    ".\\XimeaColors.ini",
    "Ximea API: %s (Driver: %s)",
    "Lola was unable to initialize your USB3 Ximea camera.",
    "Ximea SDK",
    "exposure",
    "imgdataformat",
    "RGB24",
    "width",
    "height",
    "offsetX",
    "offsetY",
    "M-JPEG (CPU)",
    "This software is based in part on the work of the Independent JPEG Group.",
    "VideoFrameReady%d",
    "VideoWriteEvent",
    "RecFrameReadyEvent",
    "FrameDoneThreadEnded",
    "LocRecVideoThreadEnded",
    "LolaVideoRec",
    "Video Recording: ",
    "_Local_%07d.bmp",
    "_Local_%07d.jpg",
    "_Remote_%07d.bmp",
    "_Remote_%07d.jpg",
    "Video RX frames",
    "Video Dropped frames",
    "Video Sent FpS: %2.2f",
)

XIMEA_CONFIG_TOKENS = (
    "Ximea",
    "xiQ_MQ013CG_E2",
    "XiC_MC023CG_SY",
    "Mono8",
    "RGB24",
    "Fps60",
    "2048x2048",
)

XIMEA_COLOR_TOKENS = (
    "[Colors]",
    "m_RedGain",
    "m_GreenGain",
    "m_BlueGain",
    "m_BadPixelsCorrection",
    "m_RawColorCorrection",
)

CODEC_SPLIT_IJG_EXPORTS = (
    "jpeg_CreateCompress",
    "jpeg_write_scanlines",
    "jpeg_finish_compress",
    "jpeg_CreateDecompress",
    "jpeg_read_scanlines",
    "jpeg_finish_decompress",
)

CODEC_SPLIT_CPU_MJPEG_STRINGS = (
    "M-JPEG (CPU)",
    "This software is based in part on the work of the Independent JPEG Group.",
    "Optimize JPEG decompression: %s",
)

CODEC_SPLIT_RAW_VIDEO_STRINGS = (
    "VideoTxWinPcap",
    "VideoPacketSize",
    "Frame Size (byte): %i",
    "Sent Frames: %d",
    "Video Sent FpS: %2.2f",
)

CODEC_SPLIT_GPUJPEG_IMPORTS = (
    "gpujpeg_init_device",
    "gpujpeg_encoder_create",
    "gpujpeg_encoder_encode",
    "gpujpeg_decoder_create",
    "gpujpeg_decoder_decode",
    "gpujpeg_encoder_destroy",
)

CODEC_SPLIT_V15_CUDA_STRINGS = (
    "M-JPEG (GPU)",
    "UseGpuJpegDecOnCuda",
    "gpujpeg.dll",
    "gpujpeg_encoder_encode",
    "gpujpeg_decoder_decode",
)
