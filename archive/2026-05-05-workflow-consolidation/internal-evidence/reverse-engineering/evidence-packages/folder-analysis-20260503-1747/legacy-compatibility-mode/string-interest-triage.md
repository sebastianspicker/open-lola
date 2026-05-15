# String Interest Triage

This document classifies the string categories already extracted in `../strings-of-interest.md`.
The goal is to decide which strings become compatibility contracts and which remain dependency noise.

| Category | Compatibility decision | Classification |
|---|---|---|
| `session` | Implement parser/generator for `/MESG_*`, `SRCIP`, `DSTIP`, `SID`, `TXT`, and quick-connection A/V fields. | confirmed |
| `network` | Implement defaults, BPF/filter expectations, packet envelope parser, and PCAP fixture reader. | confirmed/inferred |
| `audio` | Implement PortAudio-facing settings and PCM frame assumptions; validate callback scheduling later. | inferred |
| `video` | Implement camera profile import, raw frame metadata, XIMEA mode mapping, and display/recording formats. | observed/inferred |
| `codec` | Implement CPU MJPEG first; keep GPUJPEG optional until dynamic reachability is proven. | confirmed/inferred |
| `timing` | Treat as design hints: small buffers, sendqueues, counters, and ring depths; validate with captures. | inferred |
| `config` | Parse and round-trip LoLa INI keys that affect AV/session compatibility. | confirmed |
| `identity` | Use only for artifact identification, not runtime protocol behavior. | observed |
| `licensing_or_identity_surface` | Exclude from compatibility implementation except benign hardware identity display. | excluded |

## Per-Artifact String Counts

| Path | Tier | String categories |
|---|---|---|
| `win-compiled/2-0/.DS_Store` | metadata-only | none |
| `win-compiled/2-0/CAMERAFILES/PtGrey.ini` | profile-config | video=35 |
| `win-compiled/2-0/CAMERAFILES/Ximea.ini` | profile-config | video=35 |
| `win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe` | support-protocol-corpus | audio=29, codec=7, config=4, identity=35, licensing_or_identity_surface=3, network=35, session=16, timing=24, video=35 |
| `win-compiled/2-0/LolaGui_Tester/jpeg62.dll` | codec-critical | audio=16, codec=35, session=2, timing=1, video=1 |
| `win-compiled/2-0/LolaGui_Tester/mfc100.dll` | runtime-only | audio=18, codec=6, config=1, identity=2, network=8, session=35, timing=35, video=35 |
| `win-compiled/2-0/LolaGui_Tester/msvcp100.dll` | runtime-only | audio=4, licensing_or_identity_surface=22, session=2, timing=35, video=2 |
| `win-compiled/2-0/LolaGui_Tester/msvcr100.dll` | runtime-only | audio=5, session=1, timing=20, video=6 |
| `win-compiled/2-0/LolaGui_XIMEA_x64.exe` | protocol-critical | audio=35, codec=17, config=9, identity=35, licensing_or_identity_surface=8, network=35, session=34, timing=35, video=35 |
| `win-compiled/2-0/LolaVideoConverter_x64.exe` | operator-helper | audio=1, codec=3, identity=8, session=1, timing=11, video=24 |
| `win-compiled/2-0/LolaWavSplitter_x64.exe` | operator-helper | audio=15, identity=7, session=1, video=1 |
| `win-compiled/2-0/WinpcapSetup/WinPcap_4_1_3.exe` | installer-dependency | timing=8 |
| `win-compiled/2-0/XimeaColors.ini` | profile-config | none |
| `win-compiled/2-0/XimeaSetup/XIMEA_API_Installer.exe` | installer-dependency | audio=31, codec=21, config=2, network=27, session=19, timing=11, video=35 |
| `win-compiled/2-0/concrt140.dll` | runtime-only | audio=19, licensing_or_identity_surface=20, session=2, timing=35, video=2 |
| `win-compiled/2-0/cudart64_55.dll` | optional-codec-dependency | audio=29, codec=35, session=6, timing=35, video=1 |
| `win-compiled/2-0/gpujpeg.dll` | optional-codec-corpus | audio=10, codec=35, config=1, identity=5, licensing_or_identity_surface=13, session=2, timing=3 |
| `win-compiled/2-0/jpeg62.dll` | codec-critical | audio=16, codec=35, session=2, timing=1, video=1 |
| `win-compiled/2-0/mfc100.dll` | runtime-only | audio=18, codec=6, config=1, identity=2, network=8, session=35, timing=35, video=35 |
| `win-compiled/2-0/mfc140.dll` | runtime-only | audio=35, codec=6, config=1, identity=2, network=8, session=35, timing=35, video=35 |
| `win-compiled/2-0/msvcp100.dll` | runtime-only | audio=4, licensing_or_identity_surface=22, session=2, timing=35, video=2 |
| `win-compiled/2-0/msvcp140.dll` | runtime-only | audio=21, licensing_or_identity_surface=1, network=1, session=1, timing=30, video=2 |
| `win-compiled/2-0/msvcr100.dll` | runtime-only | audio=5, session=1, timing=20, video=6 |
| `win-compiled/2-0/opencv_core249.dll` | media-runtime | audio=35, codec=14, network=1, session=2, timing=35, video=35 |
| `win-compiled/2-0/opencv_highgui249.dll` | media-runtime | audio=35, codec=35, licensing_or_identity_surface=1, network=3, session=6, timing=35, video=35 |
| `win-compiled/2-0/opencv_imgproc249.dll` | media-runtime | audio=28, codec=1, session=4, timing=35, video=35 |
| `win-compiled/2-0/portaudio_x64.dll` | audio-io-critical | audio=35, licensing_or_identity_surface=1, network=1, session=3, timing=23, video=17 |
| `win-compiled/2-0/vcruntime140.dll` | runtime-only | audio=3, session=1, timing=4, video=6 |
| `win-compiled/2-0/xiapi64.dll` | camera-io-critical | audio=35, codec=35, config=1, identity=1, licensing_or_identity_surface=35, network=33, session=35, timing=35, video=35 |

## High-Value Strings For Legacy Compatibility

- `/MESG_CHECKLOLASTATUS;SRCIP:%s;DSTIP:%s;SID:%d;`
- `/MESG_CHECKLOLASTATUS_ACK;SRCIP:%s;DSTIP:%s;SID:%d;`
- `/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d`
- `/MESG_REJECT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`
- `/MESG_DISCONNECT;SRCIP:%s;DSTIP:%s;SID:%d;`
- `/MESG_SWITCH_ON_BB;SRCIP:%s;DSTIP:%s;SID:%d;`
- `/MESG_SWITCH_OFF_BB;SRCIP:%s;DSTIP:%s;SID:%d;`
- `/MESG_CHAT;SRCIP:%s;DSTIP:%s;SID:%d;TXT:%s`
- `/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`
- `/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d`
- `socketport`, `audioport`, `videoport`, `WinPcap_SetMinToCopy`, `RxPacketFiltering`, `VideoPacketSize`
- `SamplingRate`, `NumOfChannels`, `bitPerSample`, `FrameRate`, `bitPerPixel`, `FrameX`, `FrameY`, `Compression`, `CompressionQuality`, `BayerDec`
- `M-JPEG (CPU)`, `jpeg_CreateCompress`, `jpeg_mem_dest`, `jpeg_write_scanlines`, `jpeg_CreateDecompress`, `jpeg_mem_src`, `jpeg_read_scanlines`
