# LoLa 2.0 Legacy Compatibility Roadmap

Back to harness:
[README.md](README.md)

Date: 2026-05-03  
Status: internal static-evidence ledger, current after public boundary restructure
Mode: Mac-only static and offline reconstruction  
Verdict: PARTIAL

## Compatibility Principle

Implementation may proceed only from confirmed static contracts or explicitly
labeled hypotheses. No milestone may require Windows execution, Wine, QEMU,
ASIO runtime, XIMEA/PtGrey runtime, WinPcap driver timing, or packet capture
from a real Windows peer. Those items are validation gaps, not blockers for the
Mac-side dossier.

The architecture order is:

1. Passive decoder for captured or synthetic evidence.
2. Parser for reconstructed control and candidate media structures.
3. Synthetic replay for parser and timing-model tests.
4. Live interop only after future Windows/hardware validation.

## Milestones

| Milestone | Goal | Mac-only deliverable | Completion rule |
|---|---|---|---|
| M01 | Artifact inventory. | Complete v2.0 file/hash/type/signing/import/export inventory, with v1.5 comparison references. | Complete for Mac-side dossier. |
| M02 | Binary metadata/dependencies. | Compiler/runtime map, DLL ownership, installer/runtime boundaries. | Complete for Mac-side dossier. |
| M03 | Static analysis map. | Ghidra/radare2 call graph and function-cluster map. | Partial unless fresh headless Ghidra artifacts are regenerated. |
| M04 | Mac-only behavior reconstruction. | Config, session/control grammar, packet builder, fragmentation, TX/RX, timing assumptions. | Partial because packet bytes are not captured. |
| M05 | AV TX pipeline. | Capture/audio/video-to-WinPcap send path with confidence labels. | Partial until runtime timing exists. |
| M06 | AV RX pipeline. | WinPcap receive-to-playback/display path with confidence labels. | Partial until runtime loss/reorder behavior exists. |
| M07 | Codec confirmation. | Raw PCM, raw video, MJPEG/IJG, and v1.5-only GPUJPEG evidence. | Complete for static evidence; runtime performance remains future. |
| M08 | Network/protocol model. | Control messages, media ports, BPF filters, fragment header hypotheses, sequence/timestamp candidates. | Partial until captures confirm grammar. |
| M09 | Synthetic fixtures/tests plan. | Parser fixtures, synthetic packet samples, codec detection tests, replay tests. | Complete as plan; implementation separate. |
| M10 | Legacy compatibility architecture. | Passive decoder first, parser second, synthetic replay third, live interop deferred. | Complete as architecture. |
| M11 | Implementation roadmap. | Promote only sufficiently evidenced behavior; fence Windows-only proof gates. | Complete as roadmap; product proof remains partial. |

## Implementation Fences

Allowed now:

- Read-only parsing of PE metadata, strings, imports, exports, resources, and
  static call clusters.
- Markdown evidence ledgers and confidence labels.
- Synthetic control-message parser fixtures.
- Synthetic Ethernet/IPv4/UDP packet fixtures clearly labeled as hypotheses.
- Passive decoders that refuse to claim live compatibility without captured
  Windows LoLa packets.

Not allowed in this roadmap:

- Activation bypass or serial validation reconstruction.
- Binary patching.
- Credential extraction.
- Exploit development.
- Claiming byte-compatible media or control grammar without captures.
- Treating Wine/QEMU loader observation as proof of WinPcap/ASIO/XIMEA timing.

## Promotion Criteria

| Behavior | Minimum evidence before implementation claim |
|---|---|
| Control parser | Static string templates plus synthetic fixtures; live compatibility requires captured control packets. |
| Control builder | Static string templates plus exact delimiter/escaping proof; live compatibility requires Windows peer round trip. |
| Media envelope parser | Static WinPcap and port evidence plus synthetic frames; live compatibility requires captured audio/video packets. |
| Fragment reassembly | Static function cluster plus candidate tests; live compatibility requires capture with multi-fragment frames. |
| Audio payload decoder | Static audio format evidence plus sample-rate/channel proof; live compatibility requires capture and playback validation. |
| Video payload decoder | Static raw/MJPEG evidence plus JPEG detection; live compatibility requires raw and MJPEG captures. |
| Timing model | Static design interpretation only; PASS requires ASIO, WinPcap, camera, and peer timing traces. |

## Next Work Packages

| Work package | Scope | Output |
|---|---|---|
| WP01 control parser prototype | Parse visible `/MESG_*` grammar from synthetic fixtures. | Parser tests with confidence labels and delimiter ambiguity notes. |
| WP02 packet fixture generator | Generate Ethernet/IPv4/UDP frames for audio/video ports with candidate LoLa payload headers. | Implemented source-level as `lola-packet-fixture-run`; optional classic pcap output is labeled synthetic and round-tripped through `lola-capture-decode`. |
| WP03 passive capture decoder shell | Accept pcap/pcapng files, reject absent capture data cleanly, and decode only envelope facts until real packets exist. | Implemented source-level as `lola-capture-decode` plus `validate-lola-capture-report`; remains unable to overclaim compatibility. |
| WP04 codec detector | Distinguish raw candidates, JPEG SOI/EOI payloads, and unknown payloads. | Implemented source-level in `lola-capture-decode` as candidate raw-audio, raw-video, MJPEG, and unknown labels; unit tests use synthetic payloads and do not claim live compatibility. |
| WP05 Windows validation handoff | Define exact capture matrix for a future Windows/hardware session. | Checklist mapped to WV01-WV08 in [validation-checklist.md](validation-checklist.md). |

## Roadmap Verdict

The Mac-side roadmap is implementable and evidence-bounded, but compatibility
remains unproven until future Windows/hardware validation supplies live packet
captures and timing traces.

`VERDICT: PARTIAL`
