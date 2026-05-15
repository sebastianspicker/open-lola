# Reverse Engineering: Artifacts And Versioning

Back to index: [README.md](../README.md)

Scope: static artifact inventory for `../win-compiled/1-5` and
`../win-compiled/2-0`. `.DS_Store` files are ignored in counts and lineage
claims.

## Package Inventory

| Package | Files | Bytes | `.exe` | `.dll` | `.ini` | Camera payloads | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| `../win-compiled/1-5` | 72 | 179851761 | 7 | 15 | 6 | 43 | Contains CUDA GUI branch plus legacy `.kcxp` and `.anlg` camera files. |
| `../win-compiled/2-0` | 28 | 186732507 | 6 | 19 | 3 | 0 | Removes legacy camera payloads, adds VC++ 2015-2019 DLLs and root `XimeaColors.ini`. |

Lineage comparison by relative path:

| Class | Count | Evidence |
|---|---:|---|
| Common files | 23 | Same relative path exists in both package trees. |
| Byte-identical common files | 21 | SHA-256 equality. |
| Changed common files | 2 | `LolaGui_XIMEA_x64.exe`, `CAMERAFILES/Ximea.ini`. |
| v1.5-only files | 49 | CUDA GUI branch plus legacy Imperx/BitFlow/analog camera files and readme. |
| v2.0-only files | 5 | `XimeaColors.ini`, `concrt140.dll`, `mfc140.dll`, `msvcp140.dll`, `vcruntime140.dll`. |

## Primary Artifact Evidence

| Artifact | Size | SHA-256 | PE timestamp UTC | Linker | Runtime clue | Imports | Resources | Signed |
|---|---:|---|---|---|---|---:|---|---|
| `../win-compiled/1-5/LolaGui_XIMEA_x64.exe` | 428032 | `c19372600cb1b16c3a0d33682094c2c52d3716aa1364af60f0aa0d2716469cbb` | 2017-11-28 08:58:21 | 10.0 | VC++ 2010 / MFC100 | 21 | bitmap, icon, menu, dialog, string, accelerator, manifest | no |
| `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe` | 428544 | `2cc2519c5b9ffcfdd0581e04299fbe3f2ba5f0d604b6f27398227c341bf2de11` | 2017-11-28 09:00:11 | 10.0 | VC++ 2010 / MFC100 | 22 | bitmap, icon, menu, dialog, string, accelerator, manifest | no |
| `../win-compiled/2-0/LolaGui_XIMEA_x64.exe` | 613888 | `3132fda33c2c6cc71796e8dde882a9434dd42e4e29726d06a104348207d34c7f` | 2019-10-18 10:28:26 | 14.22 | VC++ 2015-2019 / MFC140 | 36 | bitmap, icon, menu, dialog, string, accelerator, manifest | no |
| `../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe` | 287744 | `aab0b718a04fb08d8bcfeb136fca8b14e649eb773c687ee482c33d82789644a8` | 2014-10-07 08:45:58 | 10.0 | VC++ 2010 / MFC100 | 12 | bitmap, icon, menu, dialog, string, accelerator, manifest | no |
| `../win-compiled/2-0/LolaVideoConverter_x64.exe` | 133632 | `89c927b5a5cdb01ac845e030547d528541cb137c5c07788d2c88e442455fdf87` | 2014-10-06 18:56:17 | 10.0 | VC++ 2010 / MFC100 | 15 | icon, dialog, version, manifest | no |
| `../win-compiled/2-0/LolaWavSplitter_x64.exe` | 55808 | `741e0c81297010f1f05bed4d92bbfd81f41cc54fe925eef7ba42389ea4c031d2` | 2014-10-06 18:56:24 | 10.0 | VC++ 2010 / MFC100 | 10 | icon, dialog, version, manifest | no |

All primary LoLa executables are PE32+ x86-64 Windows GUI binaries. The main
custom LoLa binaries and helper tools did not expose Authenticode signatures in
LIEF. Microsoft runtime DLLs and the WinPcap/XIMEA installers include signatures
where expected.

Focused provenance note: `../win-compiled/2-0/xiapi64.dll` reports PE timestamp
2020-07-24 and XIMEA API/SDK version metadata `4.20.0005`, while the v2.0 main
GUI timestamp is 2019-10-18. Static fact: the runtime DLL postdates the GUI
binary. Strong inference: the `2-0` folder is an assembled runtime distribution,
not a single monolithic build snapshot from one compiler run.

## Ghidra Headless Refresh

Ghidra 12.0.4 headless analysis was run from a scratch project location under
`/private/tmp/lola-ghidra-projects` with concise summaries written under
`/private/tmp/lola-ghidra-output`. The generated projects were deleted after
each import. The runs used local Homebrew OpenJDK 25 because `java_home` was not
registered for the installed JDK.

Static limitation: the Windows system DLLs and PDBs were not available on this
Mac, so Ghidra could not resolve Windows SDK implementation bodies or original
source symbols. Bundled DLL export symbols were available for the libraries that
matter to this pass: `portaudio_x64.dll`, `jpeg62.dll`, OpenCV 2.4.9 DLLs,
`xiapi64.dll`, and for the CUDA branch `gpujpeg.dll`.

| Artifact | Ghidra result | Interpretation |
|---|---|---|
| `../win-compiled/2-0/LolaGui_XIMEA_x64.exe` | Resolved caller clusters for PortAudio, XIMEA, IJG/libjpeg, WinPcap, OpenCV, GDI/DIB, WinMM, control strings, and display/camera strings. | Active v2.0 main GUI path. |
| `../win-compiled/1-5/LolaGui_XIMEA_x64.exe` | Same broad PortAudio/XIMEA/IJG/WinPcap/GDI shape as v2.0, with MSVC 10/MFC100 runtime lineage. | Older non-CUDA main GUI lineage. |
| `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe` | Resolved `gpujpeg_*` import callers alongside XIMEA, IJG/libjpeg, WinPcap, and display functions. | Proven CUDA/GPUJPEG branch. |
| `../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe` | Resolved WinPcap/JPEG/tester strings, including `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`. | Supporting tester/emulator tool, not current XIMEA GUI. |

Focused corpus/origins refresh:

- Static fact: `/private/tmp/lola-origin-corpus/corpus_inventory.py` classified
  the full non-`.DS_Store` corpus as 3 LoLa-owned application binaries, 6
  LoLa-owned helper binaries, 34 third-party runtimes, 4 vendor installers, and
  53 configuration/camera payloads.
- Static fact: `/private/tmp/lola-origin-corpus/LoLaCorpusOriginsDeepDive.java`
  was run against all 9 LoLa-owned executables/helpers in the two package
  trees. Outputs stayed under `/private/tmp/lola-origin-corpus-output`;
  scratch Ghidra projects were deleted after each import.
- Static fact: the converter and splitter are byte-identical 2014 helpers in
  both trees. Ghidra resolves utility UI strings and offline conversion/split
  surfaces, but the corpus inventory shows no XIMEA, WinPcap, PortAudio, or
  GPUJPEG live-transport import surface for those helper binaries.
- Static fact: the tester is byte-identical in both trees and still carries
  `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`, older `/MESG_ACCEPT` and
  `/MESG_BOUNCEBACKCONN` strings, and OSC/socket class-like strings.
- Static fact: v2.0 retains byte-identical PortAudio, OpenCV 2.4.9,
  IJG/libjpeg, GPUJPEG, CUDA 5.5 runtime, WinPcap installer, XIMEA installer,
  and XIMEA runtime files from matching v1.5 paths.
- Strong inference: v2.0 is an assembled compatibility distribution around a
  new main GUI, an expanded XIMEA camera list, v2.0-only `XimeaColors.ini`, and
  added VC++ 2015-2019 runtime DLLs.

Focused video refresh:

- Static fact: `/private/tmp/lola-ghidra-scripts/LoLaVideoDeepDive.java` was
  run against the v2.0 main GUI, v1.5 CUDA GUI, v2.0 video converter, and
  v2.0 tester. Outputs stayed under `/private/tmp/lola-ghidra-output`.
- Static fact: Python/LIEF import checks show v2.0 main imports XIMEA, IJG
  JPEG, OpenCV, and WinPcap but not GPUJPEG; v1.5 CUDA imports GPUJPEG; the
  v2.0 converter imports OpenCV and IJG JPEG but not XIMEA, GPUJPEG, or
  WinPcap.
- Strong inference: the converter and tester are support utilities for
  recorded/offline or emulated workflows, while `LolaGui_XIMEA_x64.exe` remains
  the active v2.0 live camera/network/display lineage.

Focused network/session refresh:

- Static fact: `/private/tmp/lola-ghidra-scripts/LoLaNetworkSessionDeepDive.java`
  was run against the v2.0 main GUI, v1.5 main GUI, v1.5 CUDA GUI, and v2.0
  tester. Outputs stayed under `/private/tmp/lola-ghidra-output`; scratch
  Ghidra projects were deleted after each import.
- Static fact: v2.0 main resolves `FUN_140016f20` as the WinPcap
  discovery/open/min-copy/BPF-filter path; `FUN_14001fb60` as the v2.0
  semicolon/key-value message builder; `FUN_14001f390` as the parser/dispatcher;
  `FUN_14002a6e0` and `FUN_140031d70` as settings load/save surfaces; and
  `FUN_1400152d0` as the shared RX/reassembly/decode cluster.
- Static fact: v2.0 main imports Winsock address helpers (`getaddrinfo`,
  `freeaddrinfo`, `getnameinfo`, `inet_pton`) and IP Helper APIs
  (`GetAdaptersInfo`, `SendARP`, ICMP helpers). Ghidra caller evidence ties the
  IP Helper surface to adapter, ARP, and reachability functions.
- Static fact: the v1.5 main/CUDA and tester artifacts retain older
  OSC/parser/socket class evidence and older `/MESG_ACCEPT`,
  `/MESG_BOUNCEBACKCONN`, and `/MESG_BAYER_DECODING` names. The v2.0 main GUI
  adds the explicit `SRCIP`, `DSTIP`, and `SID:%d` builder/parser cluster.
- Strong inference: the network/session lineage changed at the control-message
  layer between v1.5 and v2.0 while preserving the broader WinPcap media
  transport shape.

RTTI/class-like strings help separate ownership and subsystem boundaries:

| Artifact | Class-like evidence | Interpretation |
|---|---|---|
| v2.0 main GUI | `ASIOAudio`, `CWriteSoundFile`, `CNetwMaster`, `CNetwMonitorDlg`, `CPropertySessionPage`, `CIni`, `CDspSurf`, `CBFVideoServ`, `CBFDisplayClient`, `XimeaColorCorrect`, `CLolaGuiDlg`. | LoLa-owned GUI/application layer around audio, network/session, display, XIMEA color, and recording objects. |
| v1.5 main GUI | v2-like media classes plus `UdpSocket`, `PacketListener`, `UdpTransmitSocket`, `UdpListeningReceiveSocket`, `OscPacketListener`, and `ControlMessageListener`. | Older lineage carries OSC/UDP parser/socket class evidence alongside the LoLa media objects. |
| v2.0 main GUI | `/MESG_*;SRCIP:%s;DSTIP:%s;SID:%d` builders and parsers, but no matching OSC class-string cluster found in the focused string scan. | v2.0 moved toward explicit semicolon/key-value control messages with session IDs. |

## LoLa Origins And Version Strings

Static strings identify the product and upstream project surface:

| Artifact | Strings |
|---|---|
| v1.5 main GUI | `1.5.0`, `150.012`, `LOLA Team:`, `lola.conts.it`, `TartiniLola`. |
| v2.0 main GUI | `2.0.0 - Beta 1`, `LOLA Team:`, `lola.conts.it`, `TartiniLola`. |
| Tester | `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`. |
| Video converter | `Lola Video Converter - Version 1.0.21`. |
| WAV splitter | `Lola Wav Splitter - Version 1.0.14`. |

Team/origin strings include Massimo Parovel, Paolo Pachini, Stefano Bonetti,
Carlo Drioli, Claudio Allocchio (GARR), and in v1.5 also Nicola Buso. The main
GUI also embeds Independent JPEG Group and GPUJPEG/CESNET notices.

Version-resource ownership boundaries:

| Artifact | Version-resource owner/product evidence | Interpretation |
|---|---|---|
| `../win-compiled/2-0/LolaVideoConverter_x64.exe` | Company `Conservatorio G. Tartini, Trieste - Consortium GARR`, product `Lola Video Converter`, file/product version `1.0.0.0`; UI string says `Lola Video Converter - Version 1.0.21`. | LoLa-owned offline utility; resource version is generic while UI string carries the utility version. |
| `../win-compiled/2-0/LolaWavSplitter_x64.exe` | Company `Conservatorio G. Tartini, Trieste - Consortium GARR`, product `Lola Wav Splitter`, file/product version `1.0.0.0`; UI string says `Lola Wav Splitter - Version 1.0.14`. | LoLa-owned offline utility; unchanged across v1.5 and v2.0 package paths. |
| `../win-compiled/2-0/xiapi64.dll` | Company `XIMEA sro`, product/file version `4.20.0005`, original filename `m3Api.dll`. | Bundled third-party XIMEA runtime, not LoLa-owned application code. |
| `../win-compiled/2-0/XimeaSetup/XIMEA_API_Installer.exe` | Signed XIMEA installer, version `4.20.05.00`. | Vendor installer carried with the package. |
| `../win-compiled/2-0/WinpcapSetup/WinPcap_4_1_3.exe` | Signed Riverbed/WinPcap installer, file version `4.1.0.2980`. | Vendor packet-driver installer carried with the package. |

Build-path evidence:

| Artifact | Build/path clue |
|---|---|
| v2.0 main GUI | `F:\000_LOLA OFFICIAL RELEASE\GuiProjects2\GUIProjects\NewLolaGUI\intermediate\x64\Release\LolaGui.pdb` |
| v1.5 main/CUDA GUI | `C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\atlmfc\include\afxwin1.inl` |
| v2.0 video converter | `D:\LOLA OFFICIAL RELEASE\GUIProjects\NewLolaGUI\build\x64\Release_x64\LolaVideoConverter_x64.pdb` |
| v2.0 WAV splitter | `D:\LOLA OFFICIAL RELEASE\GUIProjects\NewLolaGUI\build\x64\Release_x64\LolaWavSplitter_x64.pdb` |
| GPUJPEG DLL | `D:\LOLA OFFICIAL RELEASE\LOLA_TOOLS\LOLA_GPUJPEG_CESNET\gpujpeg-code-26_04_2014\...\x64\Release\gpujpeg.pdb` |
| OpenCV DLLs | `C:\builds\2_4_PackSlave-win64-vc10-shared\build\opencv_build\bin\Release\opencv_*.pdb` |
| XIMEA DLL | `C:\Projects\Cameras3.x\bin\xiapi64.pdb` |

Static fact: these paths show LoLa application/helper build roots, vendor
runtime build roots, and GPUJPEG/CESNET dependency lineage as separate
ownership surfaces. Strong inference: not every PDB path in the package belongs
to LoLa-owned source code.

## Main Executables

### `LolaGui_XIMEA_x64.exe`

Primary LoLa GUI application.

Proven static capabilities:

- ASIO/PortAudio audio device setup and callback streaming.
- XIMEA camera capture through `xiapi64.dll`.
- Camera model and frame-rate selection from `CAMERAFILES/Ximea.ini`.
- Bayer decoding and color correction.
- CPU IJG/libjpeg video compression/decompression in the v2.0 main binary.
- UDP/WinPcap network transmission and receive.
- Remote host check/connect/disconnect workflow.
- Chat/control-message channel.
- Bounce-back mode.
- Local and remote audio/video recording.
- Session save/load through `.ssn` files.
- Activation/serial-number dialog.

Relevant persistent files and settings observed in strings:

- `.\LolaGui.ini`
- `.\XimeaColors.ini`
- `.\LastSsn.ssn`
- `.\rwtest.txt`
- `InputAudioDevName`
- `OutputAudioDevName`
- `AudioIOSuggLat`
- `AudioInputOffset`
- `InputVideoCameraFile`
- `FrameRate`
- `Exposure`
- `FrameX`
- `FrameY`
- `Compression`
- `CompressionQuality`
- `socketport`
- `audioport`
- `videoport`
- `VideoTxWinPcap`
- `WinPcap_SetMinToCopy`

Ghidra refresh, static fact:

- Audio/ASIO callers: `FUN_140007980`, `FUN_140009010`, `FUN_1400093a0`.
- Camera/display callers: `FUN_14000fb40`, `FUN_140012ec0`,
  `FUN_140019c80`, `FUN_14001ac90`.
- Video/network callers: `FUN_1400115c0`, `FUN_140011c10`, `FUN_1400152d0`,
  `FUN_140016f20`.
- Recording callers: `FUN_1400214a0` for WinMM WAV writing,
  `FUN_1400107c0` and `FUN_1400161a0` for JPEG/OpenCV-backed image recording.

### `LolaGui_XIMEA_CUDA_x64.exe`

Present only in `../win-compiled/1-5`.

This is the v1.5 CUDA/GPU JPEG branch of the primary GUI. It imports
`gpujpeg.dll`; the non-CUDA v1.5 GUI and the v2.0 GUI do not.

Imported GPUJPEG functions include:

- `gpujpeg_init_device`
- `gpujpeg_encoder_create`
- `gpujpeg_encoder_encode`
- `gpujpeg_decoder_create`
- `gpujpeg_decoder_decode`
- `gpujpeg_encoder_destroy`
- `gpujpeg_decoder_destroy`

GPU-related strings include:

- `Jpeg decoding (GPU):`
- `Jpeg encoding (GPU):`
- `gpujpeg_encoder ERROR`
- `M-JPEG (GPU)`

Ghidra refresh, static fact: the CUDA binary has caller clusters where
`gpujpeg_init_device`, `gpujpeg_encoder_create`,
`gpujpeg_encoder_input_set_image`, `gpujpeg_encoder_encode`,
`gpujpeg_decoder_create`, `gpujpeg_decoder_output_set_custom`, and
`gpujpeg_decoder_decode` appear in the same encode/decode and network receive
functions as the video send/receive surface. This upgrades the CUDA branch from
"string/import evidence" to "import-caller evidence." No matching GPUJPEG
caller cluster exists in the v2.0 main summary.

### `LolaGui_Tester/LolaGui_TESTER_x64.exe`

Tester or emulator build based on LoLa 1.3.0.

Observed capabilities:

- Test-mode video emulation at several resolutions.
- Remote host check/connect workflow.
- UDP/WinPcap networking.
- Audio/video packet and jitter statistics.
- Chat and session UI.

This binary is byte-identical between `../win-compiled/1-5` and
`../win-compiled/2-0`. It is a supporting tool, not the v2.0 XIMEA lineage.

Ghidra refresh, static fact: the tester still resolves WinPcap send queues and
IJG/libjpeg caller clusters, but it does not resolve the v2.0 XIMEA import
surface. The embedded string `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`
remains the strongest lineage marker.

### `LolaVideoConverter_x64.exe`

Post-processing utility for recorded image sequences.

Observed functions:

- Color debayering for 8-bit BMP/JPG input.
- BGR-to-RGB conversion for 24-bit JPG.
- BMP-to-JPEG conversion.
- Writes converted output under `ConvertedFiles`.

This binary is byte-identical between v1.5 and v2.0.

### `LolaWavSplitter_x64.exe`

Utility for splitting multichannel PCM WAV files into per-track WAV files.

Observed behavior:

- Opens `*.wav`.
- Requires at least two audio channels.
- Writes output as `%s_Track_%d.wav`.

This binary is byte-identical between v1.5 and v2.0.

## Third-Party Runtime Components

Common bundled components include:

- OpenCV 2.4.9:
  - `opencv_core249.dll`
  - `opencv_imgproc249.dll`
  - `opencv_highgui249.dll`
- XIMEA API:
  - `xiapi64.dll`
  - version metadata: `4.20.0005`
- CUDA runtime:
  - `cudart64_55.dll`
- GPUJPEG:
  - `gpujpeg.dll`
- PortAudio:
  - `portaudio_x64.dll`
- Independent JPEG Group library:
  - `jpeg62.dll`
- Microsoft runtime DLLs:
  - VC++ 2010 runtime in both packages.
  - VC++ 2015-2019 runtime added in v2.0.
- WinPcap installer:
  - `WinpcapSetup/WinPcap_4_1_3.exe`
- XIMEA installer:
  - `XimeaSetup/XIMEA_API_Installer.exe`

`xiapi64.dll`, `portaudio_x64.dll`, OpenCV DLLs, `jpeg62.dll`, `gpujpeg.dll`,
the VC++ 2010 runtime DLLs, WinPcap installer, and XIMEA installer are
byte-identical across matching v1.5 and v2.0 relative paths.

This byte identity should not be read as "all built at the same time." The
third-party files carry their own vendor timestamps and version resources. The
strongest example is `xiapi64.dll`: it is byte-identical across the inspected
package paths, but its 2020 PE timestamp is newer than the 2019 v2.0 main GUI.

## Version Comparison

### Files That Are Byte-Identical Across v1.5 And v2.0

Representative unchanged components:

- `LolaGui_Tester/LolaGui_TESTER_x64.exe`.
- `LolaVideoConverter_x64.exe`.
- `LolaWavSplitter_x64.exe`.
- OpenCV DLLs.
- `jpeg62.dll`.
- `gpujpeg.dll`.
- `portaudio_x64.dll`.
- VC++ 2010 runtime DLLs.
- WinPcap installer.
- XIMEA installer.
- `xiapi64.dll`.

### Major v2.0 Changes

The meaningful functional delta is concentrated in
`../win-compiled/2-0/LolaGui_XIMEA_x64.exe` and the simplified XIMEA camera
configuration.

v1.5:

- Build timestamp: 2017-11-28.
- Linker: MSVC 10.0.
- Size: 428032 bytes for the non-CUDA main GUI.
- Runtime: VC++ 2010.
- Windows requirement string: Vista SP2 or later.
- Includes separate CUDA executable.
- Includes many legacy `.kcxp` and `.anlg` camera files.
- Control strings include `/MESG_ACCEPT`, `/MESG_BOUNCEBACKCONN`, and
  `/MESG_BAYER_DECODING`, plus OSC parser vocabulary.
- Contains OSC/UDP class-string evidence (`OscPacketListener`,
  `UdpTransmitSocket`, `UdpListeningReceiveSocket`, `ControlMessageListener`).

v2.0:

- Build timestamp: 2019-10-18.
- Linker: MSVC 14.22.
- Size: 613888 bytes.
- Runtime: VC++ 2015-2019 plus retained VC++ 2010 helper/runtime DLLs.
- Windows requirement string: Windows 7 or later.
- Adds multi-session strings for Session 1 through Session 4.
- Adds local camera preview surface strings.
- Adds `pcap_findalldevs_ex` and `rpcap://`.
- Adds structured control-message formatting with session IDs.
- Adds richer session status and network monitor strings.
- Adds `COMDLG32`, `COMCTL32`, `OLEAUT32`, and `gdiplus` imports.
- Uses root `XimeaColors.ini` and only `Ximea.ini` / `PtGrey.ini` under
  `CAMERAFILES`.
- Focused string and Ghidra scans prove `/MESG_QUICKCONN`,
  `/MESG_QUICKCONN_ACK`, `/MESG_SEND_AUDIO_SIGNAL`, and
  `/MESG_STOP_AUDIO_SIGNAL` builder/parser paths.
