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
