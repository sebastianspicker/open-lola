from __future__ import annotations

from .constants import (
    AUDIO_SURFACE_EXPORTS,
    AUDIO_SURFACE_MAIN_IMPORT_ORDINALS,
    AUDIO_SURFACE_STRINGS,
    CODEC_SPLIT_CPU_MJPEG_STRINGS,
    CODEC_SPLIT_GPUJPEG_IMPORTS,
    CODEC_SPLIT_IJG_EXPORTS,
    CODEC_SPLIT_RAW_VIDEO_STRINGS,
    CODEC_SPLIT_V15_CUDA_STRINGS,
    NETWORK_SURFACE_IMPORTS,
    NETWORK_SURFACE_STRINGS,
    ROOT,
    VIDEO_SURFACE_GDI_IMPORTS,
    VIDEO_SURFACE_OPENCV_IMPORT_FRAGMENTS,
    VIDEO_SURFACE_STRINGS,
    VIDEO_SURFACE_XIMEA_IMPORTS,
    WINDOWS_15_CORPUS,
    WINDOWS_20_CORPUS,
    WINDOWS_RUNTIME_ANALYSIS,
    WINDOWS_STATIC_ANALYSIS,
    XIMEA_COLOR_TOKENS,
    XIMEA_CONFIG_TOKENS,
)
from .windows_binary_checks import (
    file_contains_ascii,
    has_export,
    has_import,
    has_import_ordinal,
    import_libraries,
    rabin2_json_imports,
)

def check_windows_mc08_network_surfaces() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_RUNTIME_ANALYSIS.is_file():
        return [
            "missing Windows runtime-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/runtime-analysis.md"
        ]

    main_gui = WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe"
    if not main_gui.is_file():
        return ["missing Windows 2.0 main GUI: win-compiled/2-0/LolaGui_XIMEA_x64.exe"]

    static_text = WINDOWS_STATIC_ANALYSIS.read_text(encoding="utf-8")
    static_tokens = (
        "Adapter/reachability",
        "GetAdaptersInfo",
        "SendARP",
        "IcmpCreateFile",
        "IcmpSendEcho",
        "getaddrinfo",
        "getnameinfo",
        "inet_pton",
        "WinPcap setup",
        "pcap_findalldevs",
        "pcap_open",
        "pcap_compile",
        "pcap_setfilter",
        "pcap_setmintocopy",
        "BPF",
        "Audio TX/RX",
        "pcap_sendpacket",
        "pcap_next_ex",
    )
    for token in static_tokens:
        if token not in static_text:
            errors.append(f"MC08 static-analysis network anchor missing: {token}")

    runtime_text = WINDOWS_RUNTIME_ANALYSIS.read_text(encoding="utf-8")
    runtime_tokens = (
        "WinPcap send/sendqueue",
        "WinPcap next_ex",
        "BPF host/port filter",
        "Ethernet/IPv4/UDP",
        "pcap_sendpacket",
        "WinPcap send queues",
        "BPF filters select UDP traffic",
        "audio/video ports",
        "SetMinToCopy",
    )
    for token in runtime_tokens:
        if token not in runtime_text:
            errors.append(f"MC08 runtime-analysis network model missing: {token}")

    main_imports = rabin2_json_imports(main_gui)
    for library, names in NETWORK_SURFACE_IMPORTS.items():
        for name in names:
            if not has_import(main_imports, library, name):
                errors.append(f"MC08 main GUI missing {library} import: {name}")

    for token in NETWORK_SURFACE_STRINGS:
        if not file_contains_ascii(main_gui, token):
            errors.append(f"MC08 main GUI missing network string: {token}")

    return errors


def check_windows_mc09_audio_surfaces() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_RUNTIME_ANALYSIS.is_file():
        return [
            "missing Windows runtime-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/runtime-analysis.md"
        ]

    main_gui = WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe"
    portaudio = WINDOWS_20_CORPUS / "portaudio_x64.dll"
    if not main_gui.is_file():
        return ["missing Windows 2.0 main GUI: win-compiled/2-0/LolaGui_XIMEA_x64.exe"]
    if not portaudio.is_file():
        return ["missing Windows 2.0 PortAudio DLL: win-compiled/2-0/portaudio_x64.dll"]

    static_text = WINDOWS_STATIC_ANALYSIS.read_text(encoding="utf-8")
    static_tokens = (
        "PortAudio/ASIO",
        "Pa_OpenStream",
        "Pa_StartStream",
        "PaAsio_GetAvailableBufferSizes",
        "ASIO channel helpers",
        "Audio setup",
        "PortAudio imports",
        "ASIO strings",
        "Audio TX/RX",
        "Raw PCM audio",
        "32/64 sample buffer warning",
        "audio TX/RX frame counters",
    )
    for token in static_tokens:
        if token not in static_text:
            errors.append(f"MC09 static-analysis audio anchor missing: {token}")

    runtime_text = WINDOWS_RUNTIME_ANALYSIS.read_text(encoding="utf-8")
    runtime_tokens = (
        "PortAudio/ASIO opens low-buffer audio",
        "ASIO/PortAudio callback",
        "Audio callback",
        "32 or 64 sample buffer settings",
        "ASIO buffer size",
        "sample rate",
        "channel count",
        "callback cadence",
    )
    for token in runtime_tokens:
        if token not in runtime_text:
            errors.append(f"MC09 runtime-analysis audio model missing: {token}")

    main_imports = rabin2_json_imports(main_gui)
    main_libraries = import_libraries(main_imports)
    if "portaudio_x64.dll" not in main_libraries:
        errors.append("MC09 main GUI missing PortAudio import: portaudio_x64.dll")

    # The GUI imports PortAudio by ordinal; validate those ordinals against
    # named exports in the bundled DLL.
    for ordinal, name in AUDIO_SURFACE_MAIN_IMPORT_ORDINALS.items():
        if not has_import_ordinal(main_imports, "portaudio_x64.dll", ordinal):
            errors.append(f"MC09 main GUI missing PortAudio ordinal {ordinal}: {name}")
        if not has_export(portaudio, name):
            errors.append(f"MC09 PortAudio export missing for ordinal {ordinal}: {name}")

    for export in AUDIO_SURFACE_EXPORTS:
        if not has_export(portaudio, export):
            errors.append(f"MC09 PortAudio audio/ASIO export missing: {export}")

    for ordinal, name in ((29, "Pa_ReadStream"), (30, "Pa_WriteStream")):
        if has_import_ordinal(main_imports, "portaudio_x64.dll", ordinal):
            errors.append(f"MC09 main GUI unexpectedly imports blocking stream API: {name}")

    for token in AUDIO_SURFACE_STRINGS:
        if not file_contains_ascii(main_gui, token):
            errors.append(f"MC09 main GUI missing audio string: {token}")

    return errors


def check_windows_mc10_video_surfaces() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_RUNTIME_ANALYSIS.is_file():
        return [
            "missing Windows runtime-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/runtime-analysis.md"
        ]

    main_gui = WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe"
    xiapi = WINDOWS_20_CORPUS / "xiapi64.dll"
    ximea_config = WINDOWS_20_CORPUS / "CAMERAFILES" / "Ximea.ini"
    ximea_colors = WINDOWS_20_CORPUS / "XimeaColors.ini"
    for path, label in (
        (main_gui, "Windows 2.0 main GUI"),
        (xiapi, "Windows 2.0 XIMEA DLL"),
        (ximea_config, "Windows 2.0 XIMEA camera config"),
        (ximea_colors, "Windows 2.0 XIMEA color config"),
    ):
        if not path.is_file():
            return [f"missing {label}: {path.relative_to(ROOT)}"]

    static_text = WINDOWS_STATIC_ANALYSIS.read_text(encoding="utf-8")
    static_tokens = (
        "XIMEA",
        "xiGetImage",
        "xiOpenDevice",
        "xiSetParam*",
        "xiStartAcquisition",
        "OpenCV/IJG",
        "CreateDIBSection",
        "SetDIBColorTable",
        "StretchBlt",
        "BMP/JPG sequence strings",
        "XIMEA camera setup",
        "Raw video TX",
        "MJPEG video TX/RX",
        "Display/recording",
    )
    for token in static_tokens:
        if token not in static_text:
            errors.append(f"MC10 static-analysis video anchor missing: {token}")

    runtime_text = WINDOWS_RUNTIME_ANALYSIS.read_text(encoding="utf-8")
    runtime_tokens = (
        "XIMEA capture feeds local ring",
        "raw or CPU MJPEG",
        "IJG/libjpeg",
        "displayed with",
        "Video TX",
        "RX video",
        "video raw",
        "video MJPEG",
        "Observe XIMEA and PtGrey camera behavior",
    )
    for token in runtime_tokens:
        if token not in runtime_text:
            errors.append(f"MC10 runtime-analysis video model missing: {token}")

    main_imports = rabin2_json_imports(main_gui)
    main_libraries = import_libraries(main_imports)
    for library in (
        "xiapi64.dll",
        "opencv_core249.dll",
        "opencv_highgui249.dll",
        "opencv_imgproc249.dll",
        "jpeg62.dll",
    ):
        if library not in main_libraries:
            errors.append(f"MC10 main GUI missing video library import: {library}")

    for name in VIDEO_SURFACE_XIMEA_IMPORTS:
        if not has_import(main_imports, "xiapi64.dll", name):
            errors.append(f"MC10 main GUI missing XIMEA import: {name}")
        if not has_export(xiapi, name):
            errors.append(f"MC10 XIMEA export missing: {name}")

    for library, fragments in VIDEO_SURFACE_OPENCV_IMPORT_FRAGMENTS.items():
        for fragment in fragments:
            if not any(
                str(item.get("libname", "")).lower() == library
                and fragment in str(item.get("name", ""))
                for item in main_imports
            ):
                errors.append(f"MC10 main GUI missing {library} import fragment: {fragment}")

    if not any(str(item.get("libname", "")).lower() == "jpeg62.dll" for item in main_imports):
        errors.append("MC10 main GUI missing IJG import entries from jpeg62.dll")

    for name in VIDEO_SURFACE_GDI_IMPORTS:
        if not has_import(main_imports, "GDI32.dll", name):
            errors.append(f"MC10 main GUI missing GDI display import: {name}")

    for token in VIDEO_SURFACE_STRINGS:
        if not file_contains_ascii(main_gui, token):
            errors.append(f"MC10 main GUI missing video string: {token}")
    for token in XIMEA_CONFIG_TOKENS:
        if not file_contains_ascii(ximea_config, token):
            errors.append(f"MC10 XIMEA config missing token: {token}")
    for token in XIMEA_COLOR_TOKENS:
        if not file_contains_ascii(ximea_colors, token):
            errors.append(f"MC10 XIMEA color config missing token: {token}")

    return errors


def check_windows_mc11_codec_split() -> list[str]:
    errors: list[str] = []
    if not WINDOWS_STATIC_ANALYSIS.is_file():
        return [
            "missing Windows static-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/static-analysis.md"
        ]
    if not WINDOWS_RUNTIME_ANALYSIS.is_file():
        return [
            "missing Windows runtime-analysis inventory: "
            "private/reverse-engineering/lola-2-windows/runtime-analysis.md"
        ]

    main_gui = WINDOWS_20_CORPUS / "LolaGui_XIMEA_x64.exe"
    jpeg = WINDOWS_20_CORPUS / "jpeg62.dll"
    gpujpeg = WINDOWS_20_CORPUS / "gpujpeg.dll"
    v15_cuda_gui = WINDOWS_15_CORPUS / "LolaGui_XIMEA_CUDA_x64.exe"
    required_paths = (
        (main_gui, "Windows 2.0 main GUI"),
        (jpeg, "Windows 2.0 IJG JPEG DLL"),
        (gpujpeg, "Windows 2.0 shipped GPUJPEG DLL"),
        (v15_cuda_gui, "Windows 1.5 CUDA GUI"),
    )
    for path, label in required_paths:
        if not path.is_file():
            return [f"missing {label}: {path.relative_to(ROOT)}"]

    static_text = WINDOWS_STATIC_ANALYSIS.read_text(encoding="utf-8")
    static_tokens = (
        "Raw video",
        "Raw video TX",
        "shared WinPcap sendqueue path",
        "MJPEG/IJG",
        "M-JPEG (CPU)",
        "encode/decode clusters",
        "GPUJPEG/CUDA",
        "v1.5 CUDA GUI imports",
        "gpujpeg_encoder_*",
        "gpujpeg_decoder_*",
        "v2.0 main has no static `gpujpeg.dll` import",
    )
    for token in static_tokens:
        if token not in static_text:
            errors.append(f"MC11 static-analysis codec anchor missing: {token}")

    runtime_text = WINDOWS_RUNTIME_ANALYSIS.read_text(encoding="utf-8")
    runtime_tokens = (
        "raw or CPU MJPEG",
        "raw or MJPEG",
        "IJG/libjpeg",
        "video raw",
        "video MJPEG",
    )
    for token in runtime_tokens:
        if token not in runtime_text:
            errors.append(f"MC11 runtime-analysis codec model missing: {token}")

    main_imports = rabin2_json_imports(main_gui)
    main_libraries = import_libraries(main_imports)
    for library in (
        "jpeg62.dll",
        "opencv_core249.dll",
        "opencv_highgui249.dll",
        "opencv_imgproc249.dll",
    ):
        if library not in main_libraries:
            errors.append(f"MC11 v2.0 main missing CPU MJPEG/IJG library: {library}")
    for export in CODEC_SPLIT_IJG_EXPORTS:
        if not has_export(jpeg, export):
            errors.append(f"MC11 IJG JPEG export missing: {export}")
    for token in CODEC_SPLIT_CPU_MJPEG_STRINGS:
        if not file_contains_ascii(main_gui, token):
            errors.append(f"MC11 v2.0 main missing CPU MJPEG/IJG string: {token}")

    for token in CODEC_SPLIT_RAW_VIDEO_STRINGS:
        if not file_contains_ascii(main_gui, token):
            errors.append(f"MC11 v2.0 main missing raw-video string: {token}")
    for name in (
        "pcap_sendqueue_alloc",
        "pcap_sendqueue_queue",
        "pcap_sendqueue_transmit",
        "pcap_sendpacket",
    ):
        if not has_import(main_imports, "wpcap.dll", name):
            errors.append(f"MC11 v2.0 main missing raw/MJPEG WinPcap import: {name}")

    if "gpujpeg.dll" in main_libraries:
        errors.append("MC11 v2.0 main unexpectedly imports gpujpeg.dll")
    if "cudart64_55.dll" in main_libraries:
        errors.append("MC11 v2.0 main unexpectedly imports cudart64_55.dll")
    if not file_contains_ascii(
        main_gui,
        "GPUJPEG Library (CUDA-JPEG) is Copyright (c) 2011 by CESNET z.s.p.o.",
    ):
        errors.append("MC11 v2.0 main missing GPUJPEG legacy/residue copyright string")

    v15_main_gui = WINDOWS_15_CORPUS / "LolaGui_XIMEA_x64.exe"
    if v15_main_gui.is_file():
        v15_main_libraries = import_libraries(rabin2_json_imports(v15_main_gui))
        if "gpujpeg.dll" in v15_main_libraries:
            errors.append("MC11 v1.5 non-CUDA GUI unexpectedly imports gpujpeg.dll")

    v15_cuda_imports = rabin2_json_imports(v15_cuda_gui)
    v15_cuda_libraries = import_libraries(v15_cuda_imports)
    if "gpujpeg.dll" not in v15_cuda_libraries:
        errors.append("MC11 v1.5 CUDA GUI missing gpujpeg.dll import")
    for name in CODEC_SPLIT_GPUJPEG_IMPORTS:
        if not has_import(v15_cuda_imports, "gpujpeg.dll", name):
            errors.append(f"MC11 v1.5 CUDA GUI missing GPUJPEG import: {name}")
        if not has_export(gpujpeg, name):
            errors.append(f"MC11 shipped GPUJPEG DLL missing export: {name}")
    for token in CODEC_SPLIT_V15_CUDA_STRINGS:
        if not file_contains_ascii(v15_cuda_gui, token):
            errors.append(f"MC11 v1.5 CUDA GUI missing GPUJPEG string: {token}")

    return errors
