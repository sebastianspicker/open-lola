# Open Lola Reverse Engineering: Security, Commands, And Confidence 2026
Verdict: PARTIAL

Back to private index:
[README.md](README.md)

Date: 2026-05-02  
Status: internal static-evidence ledger, current after public boundary restructure
Evidence:
[REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md](REVERSE_ENGINEERING_EVIDENCE_MATRIX_2026.md)

## Activation And Host Identity Boundary

Static fact: the GUI contains activation/user strings including `User Name`,
`Serial Number`, `Invalid serial number. Please try again.`, `TartiniLola`,
`LOLAGUI`, `Serial`, and `UserName`.

Static fact: the GUI references CPU/BIOS/mainboard metadata:
`HARDWARE\DESCRIPTION\System\CentralProcessor\0`, `ProcessorNameString`,
`Identifier`, `HARDWARE\DESCRIPTION\System\BIOS`, `BaseBoardManufacturer`, and
`BaseBoardProduct`.

Medium inference: serial/user data and host metadata participate in activation
or host identity.

Boundary: this documentation does not reconstruct, bypass, or patch serial
validation.

## Security-Relevant Static Observations

| Observation | Evidence level | Security meaning |
|---|---|---|
| Raw packet media path | Static fact | WinPcap send/receive can bypass ordinary socket-layer assumptions. |
| Plaintext control/chat strings | Static fact | `/MESG_*`, `SRCIP`, `DSTIP`, `SID`, and `TXT` are visible as embedded formats. |
| NIC and reachability helpers | Static fact | `GetAdaptersInfo`, `SendARP`, ICMP, and Winsock helpers are imported/called. |
| BPF filtering | Static fact | Media RX can filter by `ip and udp` or by peer host and audio/video UDP ports. |
| No visible TLS/auth surface | Static fact | Static string/import evidence does not show TLS, certificates, or authenticated key exchange. |
| Local working-directory writes | Static fact | `.ini`, `.ssn`, and `rwtest.txt` evidence imply write access expectations. |
| Custom LoLa binaries unsigned | Static fact | LIEF did not expose Authenticode signatures for LoLa-owned binaries. |
| Vendor/runtime age | Static fact | WinPcap 4.1.3, CUDA 5.5, OpenCV 2.4.9, and XIMEA API/SDK 4.20.0005 are bundled. |

Risk framing: these are deployment and trust-boundary concerns, not exploit
claims. Actual exposure depends on network topology, selected NIC, WinPcap
driver state, operator configuration, and runtime environment.

## Commands Used

The prior static reverse-engineering refresh used scratch paths under
`/private/tmp` and kept generated projects/summaries out of the repository.
Representative exact commands:

```sh
python3 /private/tmp/lola-origin-corpus/corpus_inventory.py /Users/sebastian/Git/open-lola /private/tmp/lola-origin-corpus-output
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-main -import archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-main-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-main -import archive/2026-05-11-win-compiled/win-compiled/1-5/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-main-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-cuda -import archive/2026-05-11-win-compiled/win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-cuda-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-tester -import archive/2026-05-11-win-compiled/win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-tester-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-tester -import archive/2026-05-11-win-compiled/win-compiled/1-5/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-tester-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-converter -import archive/2026-05-11-win-compiled/win-compiled/2-0/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-converter-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-converter -import archive/2026-05-11-win-compiled/win-compiled/1-5/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-converter-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v2-splitter -import archive/2026-05-11-win-compiled/win-compiled/2-0/LolaWavSplitter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v2-splitter-origin -deleteProject
JAVA_HOME=/opt/homebrew/opt/openjdk /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-origin-v15-splitter -import archive/2026-05-11-win-compiled/win-compiled/1-5/LolaWavSplitter_x64.exe -scriptPath /private/tmp/lola-origin-corpus -postScript LoLaCorpusOriginsDeepDive.java /private/tmp/lola-origin-corpus-output v15-splitter-origin -deleteProject
```

Earlier targeted audio/video/network commands and longer disassembly ranges are
preserved in
[deprecated-reverse-engineering/SECURITY_COMMANDS_CONFIDENCE.md](../../archive/2026-05-05-doc-consolidation/reverse-engineering/deprecated-reverse-engineering/SECURITY_COMMANDS_CONFIDENCE.md).

## Confidence Matrix

| Claim | Confidence | Evidence | Remaining gap |
|---|---|---|---|
| LoLa identity and corpus classification. | High | Strings, resources, hashes, LIEF inventory, Ghidra corpus-origin summaries. | None for static identity/classification. |
| v2.0 package is assembled around a newer main GUI. | High | Mixed timestamps/toolchains, byte-identical helpers/runtimes, v2.0-only runtime/config files. | Original packaging process. |
| Live media path is WinPcap-centered. | High | Imports/callers for `pcap_sendpacket`, `pcap_sendqueue_*`, `pcap_next_ex`, and BPF setup. | Byte-for-byte live packet capture. |
| Control/chat layer is plaintext at embedded format level. | High | `/MESG_*`, `SRCIP`, `DSTIP`, `SID`, `TXT` strings and builder/parser functions. | Exact runtime transport/framing. |
| Audio is callback-driven and bounded. | Medium/high | PortAudio/ASIO caller evidence and callback disassembly. | Hardware timing and exact clamp behavior. |
| Video is lower-priority best-effort relative to audio. | Medium/high | Thread/ring/sendqueue/reassembly design and Mac-port interpretation. | Runtime scheduling under load. |
| Registry/hardware metadata participates in activation or host identity. | Medium | Serial dialog, Registry imports, CPU/BIOS/mainboard strings. | Exact validation algorithm. |
| v2.0 active GPUJPEG acceleration. | Low | GPUJPEG strings exist, but no static v2.0 main import/caller cluster. | Dynamic-load/runtime proof. |
| PtGrey active runtime support in v2.0 XIMEA GUI. | Low | `PtGrey.ini` exists, but no PtGrey/FlyCapture import surface. | Dynamic-load/runtime/source proof. |
| 48 kHz Windows LoLa interop. | Low | Strings mention sample rate, but recovered open path uses 44.1 kHz. | Live peer test. |

## Verification Notes For This Restructure

The documentation restructure itself should be verified with:

```sh
find docs/reverse-engineering private/reverse-engineering -maxdepth 3 -type f -name '*.md' | sort
python3 -m scripts.verify_docs
rg -n "reverse-engineering/|private/reverse-engineering/" README.md docs research scripts Sources Tests THIRD_PARTY_NOTICES.md
bash scripts/verify-release-hygiene.sh
```

No application runtime tests are required for the restructure because it is
documentation-only.
