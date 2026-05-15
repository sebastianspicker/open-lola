# LoLa 2.0 Windows Compatibility Validation Checklist

Back to private index:
[../README.md](../README.md)

Date: 2026-05-03  
Status: internal static-evidence ledger, current after public boundary restructure
Verdict: PARTIAL

## Mac-Confirmable Now

| ID | Check | Evidence target | Status |
|---|---|---|---|
| MC01 | Hash every `archive/2026-05-11-win-compiled/win-compiled/2-0` artifact. | SHA-256 table in [static-analysis.md](static-analysis.md). | Done |
| MC02 | Classify file type and role. | `file` output and role tables. | Done |
| MC03 | Extract PE metadata for v2.0 main GUI. | `rabin2 -I` metadata. | Done |
| MC04 | Extract PE imports and exports. | `rabin2 -i`, `rabin2 -E` counts and role summaries. | Done |
| MC05 | Record signing indicators. | `rabin2 -Ij .info.signed` table. | Done |
| MC06 | Confirm loader/dependency ownership. | Microsoft, PortAudio, XIMEA, WinPcap, OpenCV, IJG, CUDA/GPUJPEG boundaries. | Done |
| MC07 | Confirm control message strings. | `/MESG_*`, `SRCIP`, `DSTIP`, `SID`, `TXT`. | Done |
| MC08 | Confirm network surfaces. | WinPcap, Winsock, IP Helper imports and BPF strings. | Done |
| MC09 | Confirm audio surfaces. | PortAudio/ASIO imports, ASIO strings, 32/64 buffer warning. | Done |
| MC10 | Confirm video surfaces. | XIMEA imports, XIMEA config, OpenCV/IJG imports, display/recording strings. | Done |
| MC11 | Confirm codec split. | v2.0 CPU MJPEG/IJG, raw path evidence, v1.5-only GPUJPEG import proof. | Done |
| MC12 | Seed static call graph. | `r2 -A` function count and canonical Ghidra cluster references. | Done |
| MC13 | Write synthetic control grammar fixtures plan. | Message table in [runtime-analysis.md](runtime-analysis.md). | Done |
| MC14 | Write synthetic packet fixture plan. | Packet model in [runtime-analysis.md](runtime-analysis.md). | Done |
| MC15 | Preserve existing reverse-engineering docs. | New harness references existing docs and does not overwrite them. | Done |

## Future Windows/Hardware Validation

| ID | Gate | Required evidence | Why Mac-only static analysis is insufficient |
|---|---|---|---|
| WV01 | Real control packet captures. | Windows LoLa peer captures for every `/MESG_*` state. | Strings do not prove socket framing or escaping. |
| WV02 | Real media packet captures. | Audio, raw video, MJPEG captures with timestamps and payload bytes. | Static fragmenter evidence does not prove byte grammar. |
| WV03 | ASIO buffer timing. | Windows ASIO trace with 32/64 sample buffers, underruns, callback cadence. | Import/call evidence cannot prove driver timing. |
| WV04 | XIMEA runtime behavior. | Camera capture timing, format negotiation, dropped-frame behavior. | Imports/config do not prove hardware behavior. |
| WV05 | PtGrey reachability. | PtGrey/FlyCapture runtime proof or source evidence. | `PtGrey.ini` exists without visible import proof. |
| WV06 | WinPcap driver behavior. | `SetMinToCopy`, BPF, sendqueue, receive scheduling under load. | Import evidence cannot prove driver scheduling. |
| WV07 | 48 kHz interop. | Windows peer session at 48 kHz with audio capture and packet logs. | Static strings mention 48 kHz, but recovered path evidence favors 44.1 kHz. |
| WV08 | Loss/reconnect behavior. | Controlled loss/reorder/reconnect test against Windows peer. | Counters prove surfaces, not policies. |
| WV09 | Bounce-back and generated signal behavior. | Runtime observation for switch-on/off bounce-back and send/stop audio signal. | Message strings do not prove state transitions. |
| WV10 | Activation/host identity. | Authorized non-bypass observation only, if legally and operationally needed. | Static docs intentionally do not reconstruct activation. |

## M09 Synthetic Fixtures And Tests Plan

Synthetic fixtures are allowed only as reconstructed contracts with confidence
labels. They must not be presented as Windows-compatible captures.

| Fixture | Input | Expected assertion |
|---|---|---|
| Control status | `/MESG_CHECKLOLASTATUS;SRCIP:10.0.0.1;DSTIP:10.0.0.2;SID:1;` | Parser recognizes message, IP fields, and SID. |
| Quick-connect | `/MESG_QUICKCONN;SRCIP:10.0.0.1;DSTIP:10.0.0.2;SID:1;SR:44100;BPS:16;CHNLS:2;FPS:30;BPP:24;X:640;Y:480;COMP:0;BAYER:0` | Parser extracts media capabilities. |
| Reject/chat text | `/MESG_REJECT` and `/MESG_CHAT` with `TXT` | Parser preserves text and reports delimiter ambiguity. |
| Audio envelope | Ethernet/IPv4/UDP frame on port `19788` with candidate LoLa header. | Decoder labels payload as hypothesis, not capture. |
| Video envelope | Ethernet/IPv4/UDP frame on port `19798` with candidate raw/MJPEG payload. | Decoder separates stream type by port and codec hypothesis. |
| Fragment sequence | Multi-frame candidate with sequence/index fields. | Reassembler tests ordering assumptions and reports unknowns. |
| Codec detection | Raw, JPEG SOI/EOI, and random payload samples. | Detector marks raw/MJPEG/probably-unknown without claiming live LoLa compatibility. |

## Acceptance Rule

Mac-only acceptance can reach only:

`VERDICT: PARTIAL`

Promotion to `PASS` requires WV01-WV08 at minimum, with packet captures and
hardware/runtime traces attached to the dossier.
