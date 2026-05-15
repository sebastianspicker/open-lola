# Definition Of Done Ledger

User-level DoD: "LoLa AV TX/RX is fully decoded/understood."

Static RE can satisfy the compatibility base, but it cannot honestly satisfy
byte-exact AV TX/RX without runtime captures. The ledger separates those states.

| Requirement | Status | Evidence | Next validation |
|---|---|---|---|
| Every artifact classified | PASS | 29 artifacts mapped in `compatibility-artifact-map.md` and `data/compatibility-artifacts.json`. | Keep map updated if corpus changes. |
| Every important string triaged | PASS | `string-interest-triage.md` maps categories to implementation decisions; full strings remain in `../strings-of-interest.md`. | Add capture-derived strings if runtime logs appear. |
| Main live executable role understood | PASS | Main GUI imports PortAudio, XIMEA, WinPcap, OpenCV, IJG JPEG, MFC, Winsock/IP Helper. | Continue function naming in Ghidra. |
| DLL roles understood | PASS | Codec, camera, audio, OpenCV, GPUJPEG/CUDA, and MS runtime tiers separated. | Validate dynamic DLL loads on Windows later. |
| Session/control grammar decoded | PASS | Static templates and parser function identified. | Implement golden parser/generator tests. |
| Default control/audio/video ports decoded | PASS | Loader defaults: 7000, 19788, 19798. | Confirm against live `LolaGui.ini` if available. |
| WinPcap filter and transport surface decoded | PASS | `pcap_open`, `pcap_sendpacket`, sendqueue, `pcap_next_ex`, BPF filters identified. | PCAP fixtures needed for byte offsets beyond generic headers. |
| Audio media format decoded | PARTIAL | PCM/ASIO/WAV evidence plus `channels * 128` payload inference. | Capture mono/stereo packets and verify signedness, endian, and sequence fields. |
| Video codec selection decoded | PARTIAL | CPU MJPEG confirmed; raw video inferred; GPUJPEG optional/unproven. | Capture raw and MJPEG modes; record dynamic DLL loads. |
| Media packet envelope decoded | PARTIAL | Payload offset `0x2a` and send sizes identified. | Map LoLa payload header fields from PCAP bytes. |
| Timing/synchronization decoded | PARTIAL | 32/64 audio buffer warning, 30-slot video ring, sendqueue batching. | Measure with isolated peer/hardware. |
| Loss/drop/reassembly policy decoded | PARTIAL | RX/reassembly functions and counters identified. | Induce packet loss in lab captures. |
| Byte-exact LoLa AV TX/RX fully decoded | FAIL for static-only | Static analysis cannot prove complete wire grammar. | Requires isolated Windows runtime captures and replay/interoperability tests. |

## Honest Closure Criteria

Mark "LoLa AV TX/RX fully decoded" only when all of the following are true:

- Session parser/generator passes every static template and captured control message.
- Audio packet parser maps every byte for at least 44.1 kHz and 48 kHz, mono and stereo.
- Video packet parser maps every byte for raw and CPU MJPEG modes.
- Reassembly handles normal order, loss, and recovery exactly as observed.
- Generated packets are accepted by an owned LoLa 2.0 Windows peer in an isolated lab.
- Captured LoLa packets replay correctly in the compatibility runtime.
- GPUJPEG is either proven unused for v2.0 compatibility or implemented behind optional evidence.

Current final state: the Legacy Compatibility Mode base is ready; full AV TX/RX is not yet fully decoded.

`VERDICT: PARTIAL`
