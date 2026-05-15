# Open Lola Reverse Engineering: Artifacts And Origins 2026
Verdict: PARTIAL

Back to private index:
[README.md](README.md)

Date: 2026-05-02  
Status: internal static-evidence ledger, current after public boundary restructure
Evidence:
[REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)

## Corpus Snapshot

Static fact: ignoring `.DS_Store`, `../../archive/2026-05-11-win-compiled/win-compiled` contains 100 shipped
files: 72 under `../../archive/2026-05-11-win-compiled/win-compiled/1-5` and 28 under `../../archive/2026-05-11-win-compiled/win-compiled/2-0`.

| Class | Count | Role |
|---|---:|---|
| LoLa-owned application | 3 | v1.5 main GUI, v1.5 CUDA GUI, v2.0 main GUI. |
| LoLa-owned helper | 6 | Tester, video converter, and WAV splitter in both package trees. |
| Third-party runtime | 34 | Microsoft VC/MFC, PortAudio, IJG/libjpeg, OpenCV, XIMEA, CUDA, GPUJPEG. |
| Installer | 4 | WinPcap 4.1.3 and XIMEA API installers in both package trees. |
| Configuration/camera payload | 53 | INI files, XIMEA color defaults, legacy `.kcxp` and `.anlg` camera payloads. |

Static fact: 23 relative paths are common to v1.5 and v2.0. Of those, 21 are
byte-identical. The changed common paths are `LolaGui_XIMEA_x64.exe` and
`CAMERAFILES/Ximea.ini`.

Strong inference: v2.0 is an assembled runtime distribution, not a same-day
rebuild of every component. It updates the main GUI, XIMEA camera list,
`XimeaColors.ini`, and VC++ 2015-2019 runtime layer while preserving older
helpers and many vendor dependencies.

## LoLa Origin Evidence

Static fact: product strings identify the project as LoLa / Low Latency A/V
Streaming. Embedded strings include `LOLA Team:`, `lola.conts.it`,
`TartiniLola`, and team/name surfaces for Massimo Parovel, Paolo Pachini,
Stefano Bonetti, Carlo Drioli, Claudio Allocchio (GARR), and in older
v1.5/tester lineage Nicola Buso.

Static fact: LoLa-owned utility version resources identify
`Conservatorio G. Tartini, Trieste - Consortium GARR` for the video converter
and WAV splitter.

| Artifact | Static origin/version evidence | Role |
|---|---|---|
| v2.0 main GUI | `2.0.0 - Beta 1`; PE timestamp 2019-10-18; PDB path under `F:\000_LOLA OFFICIAL RELEASE\GuiProjects2\GUIProjects\NewLolaGUI`. | Current analyzed live XIMEA/audio/video/network GUI. |
| v1.5 main GUI | `1.5.0`, `150.012`; MSVC 10/MFC100 lineage. | Older non-CUDA live GUI lineage. |
| v1.5 CUDA GUI | v1.5 main lineage plus `gpujpeg.dll` imports and GPU JPEG caller evidence. | Proven older CUDA/GPUJPEG branch. |
| Tester | `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`. | Support/emulation lineage, byte-identical in both package trees. |
| Video converter | `Lola Video Converter - Version 1.0.21`; LoLa-owned version resource. | Offline recorded-image conversion helper. |
| WAV splitter | `Lola Wav Splitter - Version 1.0.14`; LoLa-owned version resource. | Offline WAV splitting helper. |

Static fact: PDB/build path evidence separates LoLa-owned GUI/helper build
roots from third-party runtime build roots. The v2.0 main GUI points to the
`GuiProjects2\GUIProjects\NewLolaGUI` release tree, while XIMEA and OpenCV
runtime DLLs carry vendor build paths.

## Package Deltas

| Area | v1.5 | v2.0 | Interpretation |
|---|---|---|---|
| Main GUI | MSVC 10/MFC100, 2017 timestamp. | MSVC 14.22/MFC140, 2019 timestamp. | Current GUI was rebuilt and expanded. |
| CUDA branch | Includes `LolaGui_XIMEA_CUDA_x64.exe`. | No analyzed v2.0 CUDA GUI. | GPUJPEG active path belongs to v1.5 CUDA branch. |
| Runtime DLLs | MSVC 2010 support plus shared third-party DLLs. | Adds `concrt140.dll`, `mfc140.dll`, `msvcp140.dll`, `vcruntime140.dll`. | v2.0 carries newer Microsoft runtime support. |
| Camera payloads | 50 configuration/camera payloads, including 43 legacy `.kcxp`/`.anlg` binary camera files. | `CAMERAFILES/Ximea.ini`, `CAMERAFILES/PtGrey.ini`, and `XimeaColors.ini`. | v2.0 narrows shipped camera payloads toward XIMEA/PtGrey. |
| Helpers | Tester, converter, splitter. | Same helpers, byte-identical. | Helpers are preserved support/offline tools. |
| Vendor installers | WinPcap and XIMEA installers. | Same installers, byte-identical. | Deployment prerequisites are carried forward. |

## Ownership Boundaries

Static fact: third-party ownership boundaries are visible in imports, exports,
version resources, signatures, and PDB paths.

| Boundary | Evidence | Reverse-engineering meaning |
|---|---|---|
| Microsoft VC/MFC | MSVC 2010 DLLs in both trees; MSVC 2017 14.13 DLLs added in v2.0. | Runtime support, not LoLa application logic. |
| PortAudio | `portaudio_x64.dll` byte-identical in both trees; GUI imports PortAudio/ASIO functions. | Audio driver abstraction boundary. |
| IJG/libjpeg | `jpeg62.dll` byte-identical across top-level and tester copies. | CPU JPEG encode/decode boundary. |
| OpenCV 2.4.9 | `opencv_core249.dll`, `opencv_highgui249.dll`, `opencv_imgproc249.dll` byte-identical. | Image processing/display/recording support. |
| XIMEA | `xiapi64.dll` version resource says XIMEA API/SDK `4.20.0005`; PDB path `C:\Projects\Cameras3.x\bin\xiapi64.pdb`. | XIMEA hardware-driver boundary. |
| CUDA/GPUJPEG | `cudart64_55.dll` and `gpujpeg.dll` byte-identical; GPUJPEG PDB path references `LOLA_GPUJPEG_CESNET`. | GPU JPEG dependency, statically proven called by v1.5 CUDA GUI only. |
| Installers | WinPcap 4.1.3 and XIMEA API installer `4.20.05.00`, signed and byte-identical. | Deployment prerequisites. |

## Helper Roles

Static fact: the tester is not current v2.0 XIMEA GUI logic. It is
byte-identical in v1.5 and v2.0, identifies itself as based on LoLa 1.3.0, and
preserves older `/MESG_ACCEPT`, `/MESG_BOUNCEBACKCONN`, OSC/socket class
strings, `CNetwMaster`, `CNetwMonitorDlg`, `CIni`, and WinPcap surfaces.

Static fact: the video converter is a byte-identical 2014 helper. It exposes
OpenCV/IJG conversion strings and `jpeg_CreateCompress` caller evidence, but no
XIMEA, WinPcap, PortAudio, or GPUJPEG live transport import surface.

Static fact: the WAV splitter is a byte-identical 2014 helper. It exposes WAV
conversion/splitting UI strings and WinMM import surface, but no live transport
surface.

Strong inference: the complete shipped product shape is one current live GUI,
one older tester/emulator, two offline post-processing helpers, vendor
runtimes/installers, and camera/config payloads.

## Camera And Configuration Payloads

Static fact: v1.5 ships 50 configuration/camera payloads across
`CAMERAFILES`, including 36 Imperx `.kcxp` payloads and 7 analog `.anlg`
payloads for legacy frame-grabber/analog profiles. Embedded strings identify
makers/models such as Imperx, ICX-B1410C, Sony XC-HR70, and BitFlow.

Static fact: v2.0 `CAMERAFILES/Ximea.ini` expands from 28 nonblank v1.5
entries to 54 nonblank entries. It adds xiQ/XiC and generic XIMEA profiles up
to 2048x2048, with Mono8 and RGB24 variants.

Static fact: `CAMERAFILES/PtGrey.ini` is byte-identical between v1.5 and v2.0
and lists FL3/GS3 USB3 Point Grey profiles. `XimeaColors.ini` is v2.0-only and
contains red/green/blue gains, global gain, luminosity, chromaticity,
bad-pixel correction, and raw color correction.

Runtime gap: PtGrey runtime reachability remains unproven in the analyzed v2.0
XIMEA GUI because no PtGrey/FlyCapture import surface was found.
