# Reverse-Engineering Notes

Use this page for the public-safe method and evidence map.

Procedure type: reference.

## Documentation Boundary

This project documents behavioral interoperability. Public docs may include:

- externally observable network behavior;
- command names and fields;
- packet sizes, byte offsets, and inferred field meanings;
- test procedures and validation evidence;
- connector source code written for this project.

Public docs should not include:

- long decompiled functions from the original executable;
- proprietary binary blobs;
- extracted resources;
- large copied manual sections;
- raw private process output.

Private analysis output belongs under `process_artifacts/`.

## Reproduction Method

The reverse-engineering workflow had three goals:

1. Recover the control messages and session state machine.
2. Recover the audio/video payload grammar.
3. Cross-check every static conclusion against live packet captures.

Tool-agnostic workflow:

1. Extract strings from the LoLa executable and bundled DLLs.
2. Search strings for `/MESG_`, port names, WinPcap/Npcap API names, audio/video settings, and UI text.
3. Follow cross-references from those strings to formatter, parser, sender, and receiver behavior.
4. Identify imports and call sites for Winsock, pcap, JPEG, and audio APIs.
5. Group code paths by behavioral responsibility.
6. Turn each recovered field into a testable hypothesis.
7. Implement the smallest Linux sender/receiver behavior needed to test the hypothesis.
8. Validate against Windows LoLa Network Monitor and packet captures.
9. Treat packet capture as the arbiter whenever GUI counters and static analysis disagree.

## Useful Hypotheses That Were Validated

```text
Control datagrams are 0x400 bytes.
Control uses UDP port 7000.
Audio uses UDP port 19788.
Video uses UDP port 19798.
Audio serialized payload is <u32 sequence><u32 pcm_len><pcm>.
Video needs a 0x40 prelude before normal fragments.
Audio RX expects one fragment.
QuickConn compatibility checks audio channel count, sample rate, and bits per sample.
Audio fragment frame_id must equal serialized sequence + 1.
```

## Evidence Map

| Behavior | Evidence path |
| --- | --- |
| `/MESG_*` message names and fields | String extraction, formatter/parser xrefs, live control captures |
| Control datagrams padded to `0x400` | Control send behavior and live capture |
| QuickConn audio compatibility gate | Reject text, field parser behavior, 1ch/2ch rejection |
| Media ports `19788` and `19798` | `LolaGui.ini`, pcap filter behavior, captures |
| WinPcap/Npcap media transport | Imports, adapter selection behavior, captures |
| Normal fragment header | Fragment behavior and UDP payload bytes |
| Video prelude | Video TX/RX behavior and `0x40` payloads before frame fragments |
| Audio single-fragment RX | Audio reassembly behavior and accepted one-fragment packets |
| Raw video size | Settings and serialized payload: `640 * 480 * 8bpp = 307200` bytes |
| Audio `frame_id = sequence + 1` | Live capture before/after incomplete audio fix |

## Redaction Rules

- Prefer behavioral names such as "control parser" or "audio TX worker" over raw decompiler labels.
- Publish short pseudocode only when it explains behavior better than prose.
- Keep raw process material local unless it has been reviewed and intentionally published.
- Do not turn private reverse-engineering notes into public documentation by copy/paste.
