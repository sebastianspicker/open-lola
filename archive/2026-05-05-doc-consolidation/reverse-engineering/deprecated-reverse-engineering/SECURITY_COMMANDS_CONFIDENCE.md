# Reverse Engineering: Security, Commands, And Confidence

Back to index: [README.md](../README.md)

Scope: security-relevant static observations and evidence commands for the
Windows artifacts. These are not exploit claims and do not include activation
bypass, binary patching, Windows execution, or hardware-dependent testing.

## Activation And Host Identity

The GUI contains an activation dialog with:

- `User Name`
- `Serial Number`
- `Invalid serial number. Please try again.`

It also references:

- `TartiniLola`
- `LOLAGUI`
- `Serial`
- `UserName`
- `HARDWARE\DESCRIPTION\System\CentralProcessor\0`
- `ProcessorNameString`
- `Identifier`
- `HARDWARE\DESCRIPTION\System\BIOS`
- `BaseBoardManufacturer`
- `BaseBoardProduct`

Likely interpretation: the application stores serial/user data in the Windows
Registry and reads CPU/BIOS/mainboard metadata as part of host identity or
support reporting.

Runtime/ethics boundary: this report does not attempt to reconstruct, bypass,
or patch serial validation.

## Security-Relevant Observations

Static observations:

- The primary app uses raw packet capture/transmission through WinPcap.
- v2.0 embeds plaintext control/chat formats with `SRCIP`, `DSTIP`, `SID`, and
  `TXT` fields.
- v2.0 imports Winsock address helpers (`getaddrinfo`, `freeaddrinfo`,
  `getnameinfo`, `inet_pton`) and IP Helper reachability/adapter helpers
  (`GetAdaptersInfo`, `SendARP`, `IcmpCreateFile`, `IcmpSendEcho`,
  `IcmpCloseHandle`).
- `FUN_140016f20` opens the selected WinPcap device, applies
  `WinPcap_SetMinToCopy`, and compiles/sets either `ip and udp` or a
  source/destination host plus audio/video UDP port BPF filter.
- `FUN_14001fb60` builds and `FUN_14001f390` parses v2.0 status, quick connect,
  reject, disconnect, bounce-back, chat, and generated-audio-signal messages.
- The static string surface does not show TLS, certificate validation, or
  authenticated key exchange.
- The app reads and writes local `.ini` and `.ssn` files in the working
  directory.
- The app expects write access to its installation directory and warns if it
  cannot create `rwtest.txt`.
- Custom LoLa binaries did not expose Authenticode signatures in LIEF.
- Microsoft runtime DLLs and the WinPcap/XIMEA installers expose signatures
  where expected.
- Full corpus classification shows 100 non-`.DS_Store` shipped artifacts: 9
  LoLa-owned executables/helpers, 34 third-party runtimes, 4 installers, and 53
  configuration/camera payloads.
- The v2.0 package keeps unchanged older helper tools and runtimes while adding
  newer VC++ runtime DLLs. This matters for hardening because the runtime trust
  boundary is a package assembly, not one uniform compiler/toolchain snapshot.
- Third-party runtime/install components are old:
  - WinPcap 4.1.3.
  - CUDA 5.5 runtime.
  - OpenCV 2.4.9.
  - XIMEA API/SDK 4.20.0005.

Risk framing:

- Plaintext control/chat is a compatibility and trust-boundary concern, but the
  exact runtime exposure depends on network topology, ports, and packet-driver
  behavior.
- WinPcap raw packet paths can bypass some ordinary socket-layer assumptions.
- Local working-directory writes matter for deployment hardening.

## Commands Used

Representative commands used from the repository root:

```sh
python3 /private/tmp/lola-origin-corpus/corpus_inventory.py /Users/sebastian/Git/open-lola /private/tmp/lola-origin-corpus-output
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-main-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-main -import win-compiled/1-5/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-main-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-cuda -import win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-cuda-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-tester -import win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-tester-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-tester -import win-compiled/1-5/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-tester-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-converter -import win-compiled/2-0/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-converter-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-converter -import win-compiled/1-5/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-converter-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-splitter -import win-compiled/2-0/LolaWavSplitter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-splitter-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-splitter -import win-compiled/1-5/LolaWavSplitter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-splitter-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-v2-main-net -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaNetworkSessionDeepDive.java /private/tmp/lola-ghidra-output v2-main-network -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-v15-main-net -import win-compiled/1-5/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaNetworkSessionDeepDive.java /private/tmp/lola-ghidra-output v15-main-network -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-v15-cuda-net -import win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaNetworkSessionDeepDive.java /private/tmp/lola-ghidra-output v15-cuda-network -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-v2-tester-net -import win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaNetworkSessionDeepDive.java /private/tmp/lola-ghidra-output v2-tester-network -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output v2-main -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v15-main -import win-compiled/1-5/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output v15-main -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v15-cuda -import win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output v15-cuda -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v2-tester -import win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output tester -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-audio-deep-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaAudioDeepDive.java /private/tmp/lola-ghidra-output v2-main-focused -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v2-main-video -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-v15-cuda -import win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v15-cuda-video -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-converter -import win-compiled/2-0/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v2-converter-video -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-tester -import win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v2-tester-video -deleteProject
find win-compiled -maxdepth 6 -type f -exec file {} +
find win-compiled -maxdepth 6 -type f -exec shasum -a 256 {} +
file win-compiled/1-5/LolaGui_XIMEA_x64.exe win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe win-compiled/2-0/LolaGui_XIMEA_x64.exe
shasum -a 256 win-compiled/1-5/LolaGui_XIMEA_x64.exe win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -p win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -p win-compiled/1-5/LolaGui_XIMEA_x64.exe
objdump -p win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe
objdump -p win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe
objdump -p win-compiled/2-0/portaudio_x64.dll
objdump -d --start-address=0x1400093a0 --stop-address=0x140009ac9 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140009bf0 --stop-address=0x140009ff5 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x14000ad00 --stop-address=0x14000b05f win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x1400152d0 --stop-address=0x1400160b6 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x14001f390 --stop-address=0x14001fe00 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x14002a6e0 --stop-address=0x14002af90 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140031d70 --stop-address=0x140032590 win-compiled/2-0/LolaGui_XIMEA_x64.exe
strings -a -n 4 win-compiled/2-0/LolaGui_XIMEA_x64.exe
strings -a -n 4 win-compiled/1-5/LolaGui_XIMEA_x64.exe
rg -a -o "SamplingRate|SampleRate|bitPerSample|NumOfChannels" win-compiled/2-0/LolaGui_XIMEA_x64.exe win-compiled/1-5/LolaGui_XIMEA_x64.exe
```

Python/LIEF checks used locally:

```sh
python -c "import lief; print(lief.__version__)"
python - <<'PY'
from pathlib import Path
import lief
for path in [
    "win-compiled/2-0/LolaGui_XIMEA_x64.exe",
    "win-compiled/2-0/WinpcapSetup/WinPcap_4_1_3.exe",
    "win-compiled/2-0/XimeaSetup/XIMEA_API_Installer.exe",
]:
    binary = lief.parse(path)
    print(path, binary.has_signatures, len(binary.signatures))
PY
python -c "from pathlib import Path; import lief; paths=['win-compiled/2-0/LolaGui_XIMEA_x64.exe','win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe','win-compiled/2-0/LolaVideoConverter_x64.exe']; [print(p, [lib.name for lib in lief.parse(p).imports]) for p in paths]"
```

Additional targeted LIEF/Python scripts extracted:

- Non-`.DS_Store` file counts and package byte totals.
- SHA-256 equality/difference by relative path.
- PE timestamp, linker version, subsystem, imports, exports, resource types,
  and signature presence.
- Embedded strings for `/MESG_*`, session IDs, chat, bounce-back, generated
  audio signal, monitor counters, version strings, and build paths.
- Version-resource ownership metadata for LoLa utilities, XIMEA DLL/installer,
  and WinPcap installer.
- PE timestamps showing the 2020 XIMEA runtime DLL inside the v2.0 package
  postdates the 2019 v2.0 main GUI.

Ghidra-specific notes:

- `analyzeHeadless` was not initially on `PATH`; installed path used:
  `/opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless`.
- The installed OpenJDK was not registered with `/usr/libexec/java_home`; the
  latest focused runs used `JAVA_HOME=/opt/homebrew/opt/openjdk`, while older
  runs used the resolved Cellar JDK path shown in the command log above.
- Ghidra wrote its normal user configuration and cached export symbols under
  `~/Library/ghidra/ghidra_12.0.4_PUBLIC`.
- The project location and concise summaries were under `/private/tmp`.
- PDB processing reported missing PDBs, so original C++ symbol names remain
  unavailable.
- Windows system DLL bodies were not available on this Mac, but bundled DLL
  export symbols were resolved for PortAudio, JPEG, OpenCV, XIMEA, and GPUJPEG.
- The first video Ghidra command in this pass needed approval because Ghidra
  writes normal user configuration under `~/Library/ghidra`; scratch projects
  and generated summaries still stayed under `/private/tmp`.
- The network/session Ghidra commands also required approval for the same
  Ghidra user-home log/config writes. The generated script, projects, and
  summaries stayed under `/private/tmp`; `find /private/tmp/lola-ghidra-projects -maxdepth 2 -type f -print`
  returned no project files after the runs.
- The corpus-origin Ghidra commands required the same approval pattern. They
  analyzed all 9 LoLa-owned executables/helpers and wrote only concise
  summaries under `/private/tmp/lola-origin-corpus-output`.

## Confidence Matrix

| Claim | Confidence | Evidence | Remaining gap |
|---|---|---|---|
| Package is LoLa low-latency A/V streaming software. | High | Product strings, dialogs, About/resources, LoLa team and website strings. | None for identity. |
| v2.0 lineage delta is mainly the main GUI plus camera config. | High | File counts, SHA-256 comparison, PE metadata. | None for static package lineage. |
| Full corpus role classification is known. | High | Scratch Python/LIEF inventory counted 100 files and classified LoLa applications/helpers, runtimes, installers, and config/camera payloads. | None for static shipped-file classification. |
| v2.0 package is an assembled runtime distribution, not one same-day build snapshot. | High | `xiapi64.dll` PE timestamp 2020-07-24 and XIMEA version metadata postdate the 2019-10-18 v2.0 main GUI; helper tools and many runtimes are byte-identical older binaries; v2.0 adds selected VC++ 2017 runtime files. | Original packaging process. |
| Tester is support/emulation lineage, not current v2.0 XIMEA GUI logic. | High | Tester is byte-identical in v1.5/v2.0 and embeds `Lola Tester 1.0.3 (based on Lola ver. 1.3.0)`, older `/MESG_ACCEPT`/`/MESG_BOUNCEBACKCONN`, and OSC/socket class strings. | Runtime tester behavior. |
| Converter and WAV splitter are offline helpers, not live transport paths. | High | Byte-identical 2014 helpers; Ghidra shows conversion/splitting UI strings; LIEF/Ghidra show no XIMEA/WinPcap/PortAudio live surface. | Exact recorded-file variants. |
| Main GUI captures XIMEA video and ASIO/PortAudio audio. | High | Imports, strings, objdump, and Ghidra caller clusters for `Pa_OpenStream`, `PaAsio_GetAvailableBufferSizes`, `xiOpenDevice`, `xiSetParam*`, and `xiGetImage`. | Hardware timing. |
| v2.0 local video workflow is XIMEA setup -> preview/capture -> 30-slot ring -> raw/MJPEG send. | High | Focused video Ghidra output for `FUN_14000fb40`, `FUN_14000efc0`, `FUN_140012c00`, `FUN_140012ec0`, `FUN_1400115c0`, and `FUN_140011c10`. | Camera buffer ownership and live timing. |
| v2.0 receive workflow reassembles fragments, then raw-copies or IJG-decodes frames for display/recording. | High | `FUN_1400152d0` calls `pcap_next_ex`, reassembly helpers, IJG decode calls, and event/counter paths. | Live marker bytes, packet loss behavior, and enum mapping. |
| WinPcap/UDP is central to packet transmission. | High | Imports, BPF filter strings, send/receive disassembly, and Ghidra caller clusters for `pcap_sendpacket`, `pcap_sendqueue_*`, and `pcap_next_ex`. | Byte-for-byte live capture. |
| Control/chat is plaintext at the embedded message-format layer. | High | `/MESG_*;SRCIP...;TXT...` strings. | Exact runtime transport/framing. |
| v2.0 supports multi-session control surface. | High | `SID:%d`, `Session %d`, Session 1-4 resources, monitor strings. | Runtime concurrency limits. |
| v2.0 status, quick-connect, reject, disconnect, chat, bounce-back, and generated-audio-signal messages have builder/parser code. | High | `FUN_14001fb60` builds the message formats; `FUN_14001f390` parses matching names and dispatches UI/control messages. | Exact UI action and live state transition. |
| `LolaGui.ini` audio/network settings are loaded and saved. | High | Loader `FUN_14002a6e0` and saver `FUN_140031d70` reference the same audio/network keys. | User-specific generated INI contents. |
| Default media ports are socket/control 7000, audio 19788, and video 19798. | High | Immediate defaults in the `LolaGui.ini` loader for `socketport`, `audioport`, and `videoport`. | Runtime overrides in existing INI files. |
| Adapter and reachability support exists. | High | Imports and Ghidra caller evidence for `GetAdaptersInfo`, `SendARP`, `IcmpCreateFile`, `IcmpSendEcho`, and `IcmpCloseHandle`. | Actual network environment, routing, and firewall behavior. |
| v2.0 imports Winsock name/address helpers. | High | Import table shows `getaddrinfo`, `freeaddrinfo`, `getnameinfo`, and `inet_pton`; strings show WSA/bind/listening errors. | Exact control socket lifecycle and framing. |
| v2.0 receive filtering can narrow to peer hosts and audio/video UDP ports. | High | `FUN_140016f20` builds `ip and udp` or `ip and src host %s and dst host %s and (udp port %d or udp port %d)`, then calls `pcap_compile` and `pcap_setfilter`. | Runtime value substitution and behavior when filtering is disabled. |
| Local audio processing is simple int16 gain/copy/ring work. | Medium | Callback disassembly applies capture/monitor gains and shows copy/zero/ring operations with no explicit DSP stack. | Exact overflow/clamp behavior under runtime execution. |
| Registry and hardware metadata participate in activation or host identity. | Medium | Serial dialog, Registry imports, CPU/BIOS/mainboard strings. | Exact validation algorithm. |
| v2.0 camera packaging is XIMEA/PtGrey-centered while v1.5 carried broad legacy payloads. | High | v1.5 has 36 `.kcxp`, 7 `.anlg`, and several camera INI/readme payloads; v2.0 has expanded `Ximea.ini`, unchanged `PtGrey.ini`, and `XimeaColors.ini`. | Hardware reachability for non-XIMEA profiles. |
| PtGrey support is active in this v2.0 XIMEA GUI. | Low | `PtGrey.ini` and UI strings exist, but no SDK imports were visible. | Requires runtime/dynamic-load proof. |
| 48 kHz operation works against Windows LoLa. | Low | Strings/protocol fields mention sample rate; recovered open path uses `44100.0`. | Requires live peer test. |
| v2.0 main GUI has active GPUJPEG acceleration. | Low | GPUJPEG strings exist, but LIEF and Ghidra show no `gpujpeg.dll` import/caller cluster in v2.0 main; the active GPUJPEG callers are in v1.5 CUDA only. | Requires dynamic-load or runtime proof if someone claims v2.0 GPU use. |
| v2.0 main GUI uses GDI/DIB display surfaces. | High | GDI imports, display strings, and Ghidra caller clusters for `CreateDIBSection`, `SetDIBColorTable`, and `StretchBlt`. | Runtime rendering timing. |
| `LolaVideoConverter_x64.exe` is an offline video utility, not a live transport path. | High | Focused Ghidra and LIEF import checks show OpenCV/IJG image conversion signals but no XIMEA, WinPcap, or GPUJPEG imports. | Exact recorded-file format variants. |

## Current Confidence

High confidence:

- This is a Windows LoLa low-latency A/V streaming package.
- The main executable captures XIMEA video and ASIO/PortAudio audio.
- WinPcap/UDP is central to packet transmission.
- v2.0 main uses GDI/DIB display surfaces and CPU IJG/libjpeg for its proven
  live MJPEG path.
- v2.0 is primarily an updated main GUI plus updated XIMEA camera config, not a
  full package rebuild; bundled runtime files carry their own vendor timestamps.
- Helper utilities are unchanged between v1.5 and v2.0 and are offline/support
  surfaces rather than live transport paths.
- The tester is unchanged older emulation/control lineage based on LoLa 1.3.0.
- v2.0 camera packaging is XIMEA/PtGrey-centered while v1.5 carried the broader
  legacy camera payload corpus.
- v2.0 embeds plaintext control/chat message formats with session IDs.
- v2.0 loads and saves audio/network settings including default media ports.
- GPUJPEG is proven active in the v1.5 CUDA branch, not in the v2.0 main GUI.

Medium confidence:

- Registry and hardware metadata are part of serial/activation binding.
- `socketport` is the control-port setting while `audioport` and `videoport`
  cover media packet paths.
- `AudioTxFixedBuffer` is a compatibility mode for fixed-size audio payload
  capacity.
- Generated audio signal is control-message-driven and swaps the send-thread
  PCM source, but exact UI semantics still need runtime proof.
- The callback-local processing loop has no visible high-level DSP or explicit
  limiter in the recovered block.

Not yet verified:

- Runtime behavior on Windows.
- Exact packet payload formats beyond embedded control-message strings and
  static fragment reconstruction.
- Exact serial validation algorithm.
- Behavior with real XIMEA/PtGrey/ASIO/WinPcap hardware present.
- 48 kHz interop.
