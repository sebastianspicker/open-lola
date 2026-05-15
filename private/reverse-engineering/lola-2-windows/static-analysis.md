# LoLa 2.0 Windows Static Analysis
Verdict: PARTIAL

Back to private index:
[../README.md](../README.md)

Date: 2026-05-03  
Status: internal static-evidence ledger, current after public boundary restructure
Primary corpus: `../../../archive/2026-05-11-win-compiled/win-compiled/2-0`  
Comparison corpus: `../../../archive/2026-05-11-win-compiled/win-compiled/1-5`

## Method

Mac-confirmable tools visible in this session:

| Tool | Status | Use |
|---|---|---|
| `file` | Available | File type and PE/container identification. |
| `shasum` | Available | SHA-256 artifact identity. |
| `strings` | Available | Control strings, config keys, driver/API strings, codec strings. |
| `rabin2` | Available | PE metadata, imports, exports, signing indicator. |
| `r2` | Available | Offline function-count/call-graph seed; v2.0 main yielded 1048 functions with `r2 -A`. |
| `ghidraRun` | Available | Ghidra launcher present. |
| `analyzeHeadless` | Not on `PATH` | Prior canonical docs cite the Homebrew Ghidra support path; current harness treats those prior outputs as existing static evidence. |

Static-only limitation: radare2 emitted missing SDB warnings for some imported
DLL metadata, but `rabin2` still returned parseable PE headers, imports, and
exports for the inventory below.

## M01 Artifact Inventory

Complete `archive/2026-05-11-win-compiled/win-compiled/2-0`
non-`.DS_Store` file inventory from `file`,
`stat`, and `shasum -a 256`:

| Path | Bytes | SHA-256 | Type |
|---|---:|---|---|
| `archive/2026-05-11-win-compiled/win-compiled/2-0/CAMERAFILES/PtGrey.ini` | 2885 | `0b69683b6b0fa42d8fb96c0031390ef2a37c3c2561732de7219c3acfe553aeb9` | ASCII text, CRLF |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/CAMERAFILES/Ximea.ini` | 2482 | `7b1721183da1176ed427fb1f4bf7b656df571635b5eeac7c26fd5f0b56da79f9` | ASCII text, CRLF |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LastSsn.ssn` | 149 | `a0e918c5b681e75c0aeeea9d941cf5100bcbd401bdc630fce590a1f3c1b2312a` | Generic INItialization configuration [Session] |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe` | 287744 | `aab0b718a04fb08d8bcfeb136fca8b14e649eb773c687ee482c33d82789644a8` | PE32+ GUI x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_Tester/jpeg62.dll` | 280064 | `8e9f453a35b599c2945b1131aa9edafe88ab2cd922f20453706e6f461db12c37` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_Tester/mfc100.dll` | 5574984 | `ef2e0df287af95855b6b13173259df847a2cb8a1872ba3d4573e82abd4fb9699` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_Tester/msvcp100.dll` | 608080 | `934d882efd3c0f3f1efbc238ef87708f3879f5bb456d30af62f3368d58b6aa4c` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_Tester/msvcr100.dll` | 829264 | `ae3cb6c6afba9a4aa5c85f66023c35338ca579b30326dd02918f9d55259503d5` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui.ini` | 1339 | `80788b463643d861e3d98d9718dcc14c2fa6ca6abb40f948b1f2fbe86d4a7164` | Generic INItialization configuration [Audio] |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_XIMEA_x64.exe` | 613888 | `3132fda33c2c6cc71796e8dde882a9434dd42e4e29726d06a104348207d34c7f` | PE32+ GUI x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaVideoConverter_x64.exe` | 133632 | `89c927b5a5cdb01ac845e030547d528541cb137c5c07788d2c88e442455fdf87` | PE32+ GUI x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/LolaWavSplitter_x64.exe` | 55808 | `741e0c81297010f1f05bed4d92bbfd81f41cc54fe925eef7ba42389ea4c031d2` | PE32+ GUI x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/WinpcapSetup/WinPcap_4_1_3.exe` | 915128 | `fc4623b113a1f603c0d9ad5f83130bd6de1c62b973be9892305132389c8588de` | PE32 GUI NSIS installer |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/XimeaColors.ini` | 156 | `48a6e1da6987332b7242f95297a661ecbdc7c32a6f9c7e651d5306f905f0adbd` | ASCII text, CRLF |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/XimeaSetup/XIMEA_API_Installer.exe` | 99107928 | `e09034610712c8b9ce6c149463c9b03ff749a31e584954936b7769d863dd7abb` | PE32 GUI NSIS installer |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/concrt140.dll` | 343184 | `99ee9a5050465027926bccaf5783a015e449996fc51d79a257b643c8ace47dbb` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/cudart64_55.dll` | 298272 | `40e12503920ec0343175c68a8f8f35a79a12b83d86818b7ede0a18f140d5ece5` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/gpujpeg.dll` | 7809024 | `07484cd6237a5e877288581d597210953f59ce1d0c2d132c93a8a3d2018d8141` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/jpeg62.dll` | 280064 | `8e9f453a35b599c2945b1131aa9edafe88ab2cd922f20453706e6f461db12c37` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/mfc100.dll` | 5574984 | `ef2e0df287af95855b6b13173259df847a2cb8a1872ba3d4573e82abd4fb9699` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/mfc140.dll` | 6060168 | `ac6f1675dee9d373d07d1d617d825a3b6a9fd76e00b1168514109f6727858413` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/msvcp100.dll` | 608080 | `934d882efd3c0f3f1efbc238ef87708f3879f5bb456d30af62f3368d58b6aa4c` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/msvcp140.dll` | 675984 | `dd922f9cfa98252a73fb032a4e083a3e5d88377cc39652da4e0670f7dab7688d` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/msvcr100.dll` | 829264 | `ae3cb6c6afba9a4aa5c85f66023c35338ca579b30326dd02918f9d55259503d5` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/opencv_core249.dll` | 2545152 | `48d6a5cd81577414cefcbd66c3f2f14e5bf23710ef58e5c07460264b57166d48` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/opencv_highgui249.dll` | 2360832 | `d5539d536321a474a1b14a7e6c4041124f6c15e85ed2fd80c9edca6ff43aed11` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/opencv_imgproc249.dll` | 2207744 | `a62885b068234c8ff5a0b57efbab525169920e243acc07054a890df388d67ce8` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/portaudio_x64.dll` | 176640 | `4d56b6305ffd20547d38b0592f3b8c6321b4f7122ef3cdee94b615070f2f44d8` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/vcruntime140.dll` | 89248 | `8f2eb2de78a5df1dca83c7be1b7ff194578545a1ecd2e16c52a0965737b28199` | PE32+ DLL x86-64 |
| `archive/2026-05-11-win-compiled/win-compiled/2-0/xiapi64.dll` | 48461824 | `32e13556096f5a1af9f9643d51b2967ca09618a09c36ad71882231ac70a0511b` | PE32+ DLL x86-64 |

## M02 Binary Metadata And Dependencies

`rabin2` metadata for `LolaGui_XIMEA_x64.exe`:

| Field | Value |
|---|---|
| Type | PE32+ Windows GUI |
| Architecture | x86-64 |
| Compile timestamp | Fri Oct 18 11:28:26 2019 |
| Language/toolchain | MSVC |
| PDB path | `F:\000_LOLA OFFICIAL RELEASE\GuiProjects2\GUIProjects\NewLolaGUI\intermediate\x64\Release\LolaGui.pdb` |
| Protections | NX true, stack canary true, PIC true |
| Signing indicator | false |
| Imports / exports | 724 imports, 0 exports |

Complete PE import/export count and signing inventory:

| PE | Signed | Compiled | Imports | Exports | Static role |
|---|---|---|---:|---:|---|
| `LolaGui_Tester/LolaGui_TESTER_x64.exe` | false | Tue Oct 7 09:45:58 2014 | 573 | 0 | Older tester/emulator lineage; imports WinPcap, Winsock, WinMM, MFC100, JPEG. |
| `LolaGui_Tester/jpeg62.dll` | false | Fri Mar 21 12:11:48 2014 | 44 | 103 | IJG/libjpeg runtime copy. |
| `LolaGui_Tester/mfc100.dll` | true | Sat Jun 11 03:15:54 2011 | 1018 | 13945 | Microsoft MFC100 runtime. |
| `LolaGui_Tester/msvcp100.dll` | true | Sat Jun 11 01:54:26 2011 | 153 | 1676 | Microsoft C++ runtime. |
| `LolaGui_Tester/msvcr100.dll` | true | Sat Jun 11 01:54:04 2011 | 186 | 1591 | Microsoft C runtime. |
| `LolaGui_XIMEA_x64.exe` | false | Fri Oct 18 11:28:26 2019 | 724 | 0 | Primary v2.0 GUI; imports XIMEA, PortAudio, WinPcap, OpenCV, IJG/libjpeg, Winsock, IP Helper, MFC140. |
| `LolaVideoConverter_x64.exe` | false | Mon Oct 6 19:56:17 2014 | 459 | 0 | Offline video conversion helper; imports OpenCV and IJG/libjpeg, not WinPcap/PortAudio/XIMEA. |
| `LolaWavSplitter_x64.exe` | false | Mon Oct 6 19:56:24 2014 | 264 | 0 | Offline WAV helper; imports WinMM and MFC100, not live media stack. |
| `WinpcapSetup/WinPcap_4_1_3.exe` | true | Sat Dec 5 22:50:52 2009 | 155 | 0 | Signed WinPcap installer. |
| `XimeaSetup/XIMEA_API_Installer.exe` | true | Sat Dec 15 22:26:23 2018 | 159 | 0 | Signed XIMEA API installer. |
| `concrt140.dll` | true | Wed Dec 20 06:10:50 2017 | 132 | 291 | Microsoft concurrency runtime. |
| `cudart64_55.dll` | true | Fri Oct 18 03:53:40 2013 | 74 | 209 | NVIDIA CUDA runtime 5.5. |
| `gpujpeg.dll` | false | Mon Oct 6 15:16:34 2014 | 81 | 35 | GPUJPEG/CUDA runtime; active import path proven in v1.5 CUDA GUI only. |
| `jpeg62.dll` | false | Fri Mar 21 12:11:48 2014 | 44 | 103 | IJG/libjpeg runtime. |
| `mfc100.dll` | true | Sat Jun 11 03:15:54 2011 | 1018 | 13945 | Microsoft MFC100 runtime. |
| `mfc140.dll` | true | Wed Dec 20 06:37:48 2017 | 1027 | 14028 | Microsoft MFC140 runtime. |
| `msvcp100.dll` | true | Sat Jun 11 01:54:26 2011 | 153 | 1676 | Microsoft C++ runtime. |
| `msvcp140.dll` | true | Wed Dec 20 06:11:03 2017 | 193 | 1515 | Microsoft C++ runtime. |
| `msvcr100.dll` | true | Sat Jun 11 01:54:04 2011 | 186 | 1591 | Microsoft C runtime. |
| `opencv_core249.dll` | false | Tue Apr 15 09:57:28 2014 | 196 | 1453 | OpenCV 2.4.9 core runtime. |
| `opencv_highgui249.dll` | false | Tue Apr 15 09:58:18 2014 | 439 | 457 | OpenCV highgui/video I/O runtime. |
| `opencv_imgproc249.dll` | false | Tue Apr 15 09:58:07 2014 | 308 | 588 | OpenCV image processing runtime. |
| `portaudio_x64.dll` | false | Fri Apr 11 10:08:10 2014 | 141 | 62 | PortAudio runtime with ASIO/WASAPI exports. |
| `vcruntime140.dll` | true | Wed Dec 20 06:10:43 2017 | 44 | 71 | Microsoft VC runtime. |
| `xiapi64.dll` | false | Fri Jul 24 07:38:45 2020 | 154 | 373 | XIMEA API runtime. |

Dependency ownership:

| Boundary | Static evidence | Compatibility meaning |
|---|---|---|
| LoLa-owned GUI | `LolaGui_XIMEA_x64.exe`, 2019 PDB path, unsigned indicator. | Primary artifact to reconstruct. |
| LoLa-owned helpers | Tester, converter, splitter, all older timestamps. | Comparison/support evidence, not live v2.0 media proof. |
| Microsoft runtime | MFC/VC 100 and 140 DLLs, several signed indicators. | Loader/runtime boundary. |
| PortAudio/ASIO | GUI imports `portaudio_x64.dll`; DLL exports `Pa_OpenStream`, `Pa_StartStream`, `PaAsio_GetAvailableBufferSizes`, ASIO channel helpers, and WASAPI helpers. | Audio driver abstraction; real ASIO timing remains future validation. |
| XIMEA | GUI imports `xiGetImage`, `xiOpenDevice`, `xiSetParam*`, `xiStartAcquisition`; `xiapi64.dll` exports 373 symbols. | Camera API boundary; real camera timing remains future validation. |
| WinPcap | GUI imports `wpcap.dll` functions including send, receive, send queues, BPF compile/filter, and minimum-copy configuration. | Raw-packet media boundary; driver timing remains future validation. |
| OpenCV/IJG | GUI imports OpenCV 2.4.9 and `jpeg62.dll`; strings cite Independent JPEG Group. | Image processing, MJPEG encode/decode, display/recording support. |
| CUDA/GPUJPEG | v2.0 ships `cudart64_55.dll` and `gpujpeg.dll`, but v2.0 main has no static `gpujpeg.dll` import. | GPUJPEG is comparison evidence unless dynamic loading is later proven. |

## M03 Static Analysis Map

Current `r2 -A` over `LolaGui_XIMEA_x64.exe` recovered 1048 functions. The
canonical Ghidra/radare2 companion set identifies these static clusters:

| Cluster | Static anchors | Confidence | Remaining gap |
|---|---|---|---|
| Settings and session | `LolaGui.ini`, `LastSsn.ssn`, `XimeaColors.ini`, `GetPrivateProfileStringA`, `WritePrivateProfileStringA`. | Static fact | Runtime user overrides. |
| Control/session grammar | `/MESG_CHECKLOLASTATUS`, `/MESG_QUICKCONN`, `/MESG_REJECT`, `/MESG_DISCONNECT`, `/MESG_CHAT`, `SRCIP`, `DSTIP`, `SID`; builder `FUN_14001fb60`, parser `FUN_14001f390`. | Static fact | Exact transport/framing. |
| Adapter/reachability | `GetAdaptersInfo`, `SendARP`, `IcmpCreateFile`, `IcmpSendEcho`, `getaddrinfo`, `getnameinfo`, `inet_pton`. | Static fact | Selected NIC behavior. |
| WinPcap setup | `pcap_findalldevs*`, `pcap_open`, `pcap_compile`, `pcap_setfilter`, `pcap_setmintocopy`; `FUN_140016f20`. | Static fact | Real driver timing and BPF behavior. |
| Audio setup | PortAudio imports, ASIO strings, `PaAsio_GetAvailableBufferSizes`, `Pa_OpenStream`. | Static fact | Real ASIO hardware timing. |
| Audio TX/RX | `FUN_140009bf0`, `pcap_sendpacket`, `pcap_next_ex`, remote playback ring evidence. | Static fact | Packet bytes and loss behavior. |
| XIMEA camera setup | `xiOpenDevice`, `xiSetParamFloat`, `xiSetParamInt`, `xiStartAcquisition`, `xiGetImage`; `exposure`, `imgdataformat`, `RGB24`, `width`, `height`, `offsetX`, `offsetY`. | Static fact | Hardware timing and PtGrey reachability. |
| Raw video TX | `FUN_1400115c0` and adjacent raw send-queue path. | Static fact | Packet bytes. |
| MJPEG video TX/RX | `FUN_140011c10`, `FUN_1400152d0`, `jpeg62.dll`, IJG strings. | Static fact | Runtime quality/timing. |
| Fragment/reassembly | Shared audio/video packet builder and RX fragment reassembly in canonical E2E notes. | Static fact | Exact payload grammar. |
| Display/recording | `CreateDIBSection`, `SetDIBColorTable`, `StretchBlt`, `_Local.wav`, `_Remote.wav`, BMP/JPG sequence strings. | Static fact | Runtime scheduling under load. |

## M07 Codec Confirmation

| Codec or media shape | Evidence | Status |
|---|---|---|
| Raw PCM audio | PortAudio/ASIO imports, channel/bits-per-sample strings, 32/64 sample buffer warning, audio TX/RX frame counters. | Strong inference; exact on-wire payload remains unproven. |
| Raw video | Raw video TX cluster and shared WinPcap sendqueue path. | Static fact for path, runtime packet bytes unproven. |
| MJPEG/IJG | `jpeg62.dll` import, IJG strings, `M-JPEG (CPU)`, encode/decode clusters. | Static fact. |
| GPUJPEG/CUDA | v1.5 CUDA GUI imports `gpujpeg_encoder_*`, `gpujpeg_decoder_*`, and `gpujpeg_init_device`; v2.0 main has no static `gpujpeg.dll` import. | Static fact for v1.5 CUDA only; v2.0 active use remains unproven. |
| 48 kHz | `44100` and `48000` strings exist; canonical notes recover 44.1 kHz in the open/WAV path. | Future validation for Windows peer interop. |

## Evidence References

Use the existing evidence register for claim IDs and older address-level detail:

- [../REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](../REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)
- [../REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md](../REVERSE_ENGINEERING_LOLA_E2E_WORKFLOW_2026.md)
- [../REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md](../REVERSE_ENGINEERING_SECURITY_COMMANDS_CONFIDENCE_2026.md)
