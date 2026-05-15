# Reverse Engineering: Corpus Origins And Integration

Back to index: [README.md](../README.md)

Scope: full static corpus pass over `../win-compiled/1-5` and
`../win-compiled/2-0`. This pass classifies every shipped non-`.DS_Store`
artifact and ties the package assembly back to the already mapped LoLa
audio/video/network/session system. No Windows executable was run. No Wine,
activation bypass, hardware probing, packet capture, or binary patching was
used.

Evidence labels:

- Static fact: directly visible in file inventory, hashes, PE metadata,
  imports, exports, version resources, strings, resources, disassembly, or
  Ghidra caller/decompiler output.
- Strong inference: multiple static facts point to one package or runtime
  role, but the original source tree or live runtime was not observed.
- Medium inference: the static evidence is real, but the semantic label or
  live branch is not fully pinned down.
- Runtime gap: requires Windows execution, hardware, packet capture, a peer,
  original symbols, or source code.

## Fresh Corpus Evidence

Static fact: scratch tooling for this pass stayed under
`/private/tmp/lola-origin-corpus` and `/private/tmp/lola-origin-corpus-output`.
The inventory script wrote `corpus-inventory.md` and `corpus-inventory.json`.
The Ghidra script `LoLaCorpusOriginsDeepDive.java` wrote one concise
`*.corpus-origins.md` summary for each LoLa-owned executable/helper.

Static fact: Ghidra 12.0.4 headless corpus-origin runs completed for:

- `../win-compiled/2-0/LolaGui_XIMEA_x64.exe`
- `../win-compiled/1-5/LolaGui_XIMEA_x64.exe`
- `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe`
- `../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe`
- `../win-compiled/1-5/LolaGui_Tester/LolaGui_TESTER_x64.exe`
- `../win-compiled/2-0/LolaVideoConverter_x64.exe`
- `../win-compiled/1-5/LolaVideoConverter_x64.exe`
- `../win-compiled/2-0/LolaWavSplitter_x64.exe`
- `../win-compiled/1-5/LolaWavSplitter_x64.exe`

Runtime gap: Windows system DLL bodies and PDBs were still unavailable on this
Mac. Ghidra recovered surfaces from imports, strings, resources, bundled export
symbols, and decompiler output, but not original C++ source names.

## Whole Corpus Classification

Static fact: ignoring `.DS_Store`, the full corpus contains 100 shipped files:
72 in `1-5` and 28 in `2-0`.

| Class | Count | Role |
|---|---:|---|
| LoLa-owned application | 3 | v1.5 main GUI, v1.5 CUDA GUI, v2.0 main GUI. |
| LoLa-owned helper | 6 | Tester, video converter, WAV splitter in both package trees. |
| Third-party runtime | 34 | Microsoft VC/MFC, PortAudio, IJG/libjpeg, OpenCV, XIMEA, CUDA, GPUJPEG. |
| Installer | 4 | WinPcap 4.1.3 and XIMEA API installers in both package trees. |
| Configuration/camera payload | 53 | Camera lists, legacy camera payloads, and XIMEA color defaults. |

Static fact: 23 relative paths are common to v1.5 and v2.0. Of those, 21 are
byte-identical. The two changed common paths are `LolaGui_XIMEA_x64.exe` and
`CAMERAFILES/Ximea.ini`.

Static fact: v1.5-only payloads are the CUDA GUI and 48 legacy camera/config
files. v2.0-only payloads are `XimeaColors.ini` and four VC++ 2015-2019 runtime
DLLs: `concrt140.dll`, `mfc140.dll`, `msvcp140.dll`, and `vcruntime140.dll`.

Strong inference: v2.0 is an assembled distribution around a newer main GUI,
newer Microsoft runtime layer, expanded XIMEA camera list, and XIMEA color
defaults. It is not a full rebuild of all LoLa-owned helper tools or bundled
vendor dependencies.

## Origin And Ownership Boundaries

Static fact: the main GUI strings identify the project as LoLa / Low Latency
A/V Streaming. Origin strings include `LOLA Team:`, `lola.conts.it`,
`TartiniLola`, and the named team surface: Massimo Parovel, Paolo Pachini,
Stefano Bonetti, Carlo Drioli, Claudio Allocchio (GARR), and in v1.5/tester
lineage Nicola Buso.

Static fact: LoLa-owned helper version-resource metadata names
`Conservatorio G. Tartini, Trieste - Consortium GARR` as owner for the video
converter and WAV splitter. Their UI strings carry the specific utility
versions:

| Artifact | Static origin/version evidence | Role |
|---|---|---|
| v2.0 main GUI | `2.0.0 - Beta 1`; PDB path under `F:\000_LOLA OFFICIAL RELEASE\GuiProjects2\GUIProjects\NewLolaGUI`. | Current live XIMEA/audio/video/network GUI target. |
| v1.5 main GUI | `1.5.0`, `150.012`; MSVC 10/MFC100 lineage. | Older non-CUDA live GUI lineage. |
| v1.5 CUDA GUI | v1.5 main lineage plus `gpujpeg.dll` imports and GPU JPEG encode/decode callers. | Proven older CUDA/GPUJPEG branch. |
| Tester | `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`. | Test/emulation lineage, byte-identical in both package trees. |
| Video converter | Version-resource product `Lola Video Converter`; UI string `Version 1.0.21`; PDB path under `D:\LOLA OFFICIAL RELEASE\GUIProjects\NewLolaGUI\build`. | Offline recorded-image conversion helper. |
| WAV splitter | Version-resource product `Lola Wav Splitter`; UI string `Version 1.0.14`; same helper build root. | Offline WAV splitting helper. |

Static fact: third-party runtime ownership boundaries are visible from imports,
exports, version resources, and PDB paths:

| Runtime/install class | Static evidence | Boundary |
|---|---|---|
| Microsoft VC/MFC | MSVC 2010 DLLs in both trees; MSVC 2017 14.13 DLLs added in v2.0. Most are signed. | Runtime support, not LoLa logic. |
| PortAudio | `portaudio_x64.dll` byte-identical in both trees; GUI imports PortAudio/ASIO ordinals. | Audio driver abstraction boundary. |
| IJG/libjpeg | `jpeg62.dll` byte-identical across top-level and tester copies. | CPU JPEG encode/decode boundary. |
| OpenCV 2.4.9 | `opencv_core249.dll`, `opencv_highgui249.dll`, `opencv_imgproc249.dll` byte-identical in both trees. | Image processing/display/recording support. |
| XIMEA | `xiapi64.dll` byte-identical in both trees; version resource says XIMEA API/SDK `4.20.0005`; PDB path `C:\Projects\Cameras3.x\bin\xiapi64.pdb`. | XIMEA hardware-driver boundary. |
| CUDA/GPUJPEG | `cudart64_55.dll` and `gpujpeg.dll` byte-identical in both trees; GPUJPEG PDB path points to `LOLA_GPUJPEG_CESNET`. | GPU JPEG dependency, proven called only by the v1.5 CUDA GUI. |
| Installers | WinPcap `4.1.3` installer and XIMEA API installer `4.20.05.00` are byte-identical in both trees and signed. | Deployment prerequisites. |

Medium inference: the included `gpujpeg.dll` and `cudart64_55.dll` in v2.0 are
packaging carryover or support for another build variant. The v2.0 analyzed
main GUI has GPUJPEG strings and settings keys but no static `gpujpeg.dll`
import or caller cluster.

## Executable Roles In The System

Static fact: the v2.0 main GUI is the only analyzed current-generation live
camera/audio/network binary. Its imports and Ghidra caller clusters cover:

- MFC GUI, resources, dialogs, `.ini` settings, `.ssn` session files, and
  registry-backed serial/user data.
- PortAudio/ASIO setup, 64-frame callback blocks, recording side rings, and
  WAV writing.
- XIMEA camera setup, `CAMERAFILES/Ximea.ini`, `XimeaColors.ini`, preview,
  capture, color correction, and display surfaces.
- WinPcap media TX/RX, Winsock/IP Helper address and reachability helpers,
  plaintext `/MESG_*` control/chat/session messages, and monitor counters.
- CPU IJG/libjpeg raw/MJPEG encode/decode; no static active GPUJPEG import.

Static fact: the v1.5 main and v1.5 CUDA GUIs preserve the older control
lineage. Ghidra sees `UdpSocket`, `UdpTransmitSocket`,
`UdpListeningReceiveSocket`, `PacketListener`, `OscPacketListener`, and
`ControlMessageListener` class-like strings in v1.5/tester outputs. The v2.0
main corpus-origin output has `CNetwMaster`, `CNetwMonitorDlg`,
`CPropertySessionPage`, and semicolon/key-value `/MESG_*` strings with `SRCIP`,
`DSTIP`, and `SID`, but the focused scan did not recover the older OSC class
cluster in v2.0.

Static fact: the tester is byte-identical in v1.5 and v2.0 and still exposes
older `/MESG_ACCEPT`, `/MESG_BOUNCEBACKCONN`, OSC/socket class strings,
`CNetwMaster`, `CNetwMonitorDlg`, `CIni`, and WinPcap caller surfaces. It is a
support/emulation tool, not the v2.0 XIMEA live-camera GUI.

Static fact: the video converter is byte-identical in v1.5 and v2.0. Its
Ghidra output shows `Lola Video Converter - Version 1.0.21`, OpenCV DLL
strings, `jpeg62.dll`, conversion warnings, JPEG preview warnings, and
`jpeg_CreateCompress` calls. It has no XIMEA, WinPcap, PortAudio, or GPUJPEG
import surface in the corpus inventory. It belongs to recorded/offline video
workflows.

Static fact: the WAV splitter is byte-identical in v1.5 and v2.0. Its Ghidra
output shows `Lola Wav Splitter - Version 1.0.14`, conversion-complete/exit
warning strings, WinMM import surface, and no live network/camera/audio driver
surface. It belongs to offline audio-file post-processing.

Strong inference: the complete shipped product is one live GUI plus support
utilities and prerequisites. Live low-latency behavior is concentrated in the
main GUI/tester family; conversion/splitting tools consume artifacts after a
session rather than participating in realtime transport.

## Camera And Configuration Payloads

Static fact: v1.5 ships 50 configuration/camera payloads when counted across
its `CAMERAFILES` directory, including 43 legacy binary `.kcxp`/`.anlg`
camera payloads. v2.0 ships `CAMERAFILES/Ximea.ini`,
`CAMERAFILES/PtGrey.ini`, and root `XimeaColors.ini`.

Static fact: v1.5 legacy camera payloads include:

- 36 Imperx `.kcxp` payloads for CXP/ICX families and multiple mono/RGB
  resolutions.
- 7 analog `.anlg` payloads for Hitachi, Sony, and Toshiba camera profiles.
- INI files for Adimec, Imperx CXP/ICX, PtGrey, XIMEA, and a Sony readme.

Static fact: `.kcxp` and `.anlg` payloads are binary camera files. Short string
samples inside them identify camera makers/models such as Imperx, ICX-B1410C,
Sony XC-HR70, and BitFlow. These are not generic text preferences.

Static fact: v2.0 `CAMERAFILES/Ximea.ini` expands from 28 nonblank entries in
v1.5 to 54 nonblank entries. It adds xiQ/XiC model entries and generic XIMEA
profiles from 640x360 up to 2048x2048, with Mono8 and RGB24 variants.

Static fact: `CAMERAFILES/PtGrey.ini` is byte-identical between v1.5 and v2.0
and lists FL3/GS3 USB3 Point Grey profiles, including 120 FPS mono modes and
lower-FPS RGB modes.

Static fact: `XimeaColors.ini` is v2.0-only and contains color defaults:
red/green/blue gains, global gain, luminosity, chromaticity, bad-pixel
correction, and raw color correction.

Strong inference: the camera corpus evolved from broad legacy frame-grabber and
analog support in v1.5 toward a v2.0 package centered on XIMEA, with PtGrey
configuration retained but not statically proven active in the analyzed
`LolaGui_XIMEA_x64.exe`.

Runtime gap: PtGrey runtime reachability remains unproven. The config file is
shipped and UI/config strings exist, but the analyzed v2.0 XIMEA GUI does not
show a PtGrey/FlyCapture import surface. Dynamic loading or another GUI build
would need runtime/source proof.

## Integration Picture

Static fact: the corpus has three integration layers:

1. LoLa-owned executables: main GUI, CUDA GUI lineage, tester, video converter,
   and WAV splitter.
2. Third-party runtime DLLs and installers: audio, camera, image processing,
   raw packet capture, CUDA/GPUJPEG, JPEG, and Microsoft runtime support.
3. Configuration/session/camera payloads: `.ini`, `.ssn`, XIMEA/PtGrey lists,
   legacy `.kcxp`/`.anlg`, and XIMEA color defaults.

Static fact: the v2.0 main GUI ties the layers together through local files and
settings: `.\LolaGui.ini`, `.\LastSsn.ssn`, `.\XimeaColors.ini`,
`CAMERAFILES/Ximea.ini`, `InputAudioDevName`, `InputVideoCameraFile`,
`UseGpuJpegDecOnCuda`, `OptimizeJpegDecompression`, `socketport`, `audioport`,
`videoport`, `VideoTxWinPcap`, `WinPcap_SetMinToCopy`, and
`RxPacketFiltering`.

Strong inference: the v2.0 package should be read as a compatibility-preserving
distribution:

- Live operation: v2.0 main GUI.
- Peer/test operation: unchanged tester.
- Recorded media post-processing: unchanged converter and splitter.
- Driver/runtime prerequisites: unchanged WinPcap, XIMEA, PortAudio, OpenCV,
  IJG/libjpeg, CUDA/GPUJPEG, and added MSVC 2017 runtime files.
- Camera compatibility: expanded XIMEA list, retained PtGrey list, removed
  shipped legacy `.kcxp`/`.anlg` payloads from v2.0.

Medium inference: `UseGpuJpegDecOnCuda` and GPUJPEG copyright/settings strings
in the v2.0 main GUI are source-lineage residue or dormant UI/config
compatibility. Static analysis did not prove a v2.0 runtime call path into
`gpujpeg.dll`.

## Previous Gaps Revisited

| Gap from prior runs | New corpus result | Status |
|---|---|---|
| Are helper tools part of v2.0 live transport? | Converter/splitter are byte-identical 2014 helpers with offline conversion/splitting strings and no WinPcap/XIMEA/PortAudio live surface. | Narrowed: helpers are offline/support, not live transport. |
| Is tester current v2.0 logic? | Tester is byte-identical across v1.5/v2.0 and identifies itself as based on LoLa 1.3.0. | Closed statically for lineage: tester is support/emulation lineage. |
| Is v2.0 a same-day build snapshot? | XIMEA DLL timestamp/version postdates the 2019 GUI; helpers and many runtimes are unchanged older binaries; v2.0 adds selected VC++ 2017 runtimes. | Closed statically: assembled distribution. |
| Is GPUJPEG active in v2.0 main? | v2.0 includes GPUJPEG DLL and strings/settings but has no static GPUJPEG import/caller cluster; v1.5 CUDA has both. | Still runtime/dynamic-load gap only if someone claims v2.0 GPU use. |
| Is PtGrey active in v2.0 XIMEA GUI? | PtGrey config is shipped unchanged, but no PtGrey/FlyCapture import was found in the analyzed GUI. | Still runtime/source gap. |
| Does static analysis prove exact packet grammar? | Corpus pass adds no packet capture or Windows peer. Existing fragment/BPF/control evidence remains the static limit. | Still runtime gap. |
| Does static analysis prove activation algorithm? | Corpus pass confirms registry/user/serial/hardware strings but intentionally does not reconstruct or bypass validation. | Still out of scope/runtime gap. |
| Is 48 kHz compatibility proven? | Corpus pass adds no audio runtime execution. Existing 44.1 kHz open-path evidence and 48 kHz strings remain. | Still runtime gap. |

## Current Full Picture

Static fact: LoLa in `win-compiled/` is a Windows/MFC low-latency A/V package
from the Tartini/GARR LoLa project. The active analyzed v2.0 live target is
`LolaGui_XIMEA_x64.exe`, a newer MSVC 14.22 GUI that combines ASIO/PortAudio
audio, XIMEA camera capture, CPU JPEG/OpenCV/GDI video, WinPcap raw packet
media transport, plaintext control/chat/session messages, settings/session
files, and registry-backed serial/user state.

Static fact: v1.5 supplies the historical branch evidence: non-CUDA and CUDA
main GUIs, older OSC/socket class strings, broad camera payload coverage, and
the proven GPUJPEG caller path in `LolaGui_XIMEA_CUDA_x64.exe`.

Static fact: v2.0 preserves several older artifacts unchanged: tester, video
converter, WAV splitter, PortAudio, OpenCV 2.4.9, IJG/libjpeg, GPUJPEG, CUDA
5.5 runtime, WinPcap installer, XIMEA installer, and XIMEA runtime. Its actual
package delta is the current main GUI, changed XIMEA camera list, v2.0-only
XIMEA color defaults, and added VC++ 2015-2019 runtime DLLs.

Strong inference: the system design is stable across versions at the media
transport level: low-latency audio/video is WinPcap-centered, session/control
is LoLa-owned application logic, and helper tools are post-processing or
emulation surfaces. The main architectural evolution visible in this corpus is
v2.0's newer main GUI, explicit `SID`/`SRCIP`/`DSTIP` control-message builder,
expanded XIMEA support, and removal of shipped legacy camera payloads.

Runtime gaps: exact live control framing, exact media packet grammar, timing,
packet loss behavior, hardware-specific XIMEA/PtGrey/ASIO behavior, activation
validation, and 48 kHz interoperability remain beyond what can be proved on
this Mac without Windows execution, hardware, a peer, or packet capture.
