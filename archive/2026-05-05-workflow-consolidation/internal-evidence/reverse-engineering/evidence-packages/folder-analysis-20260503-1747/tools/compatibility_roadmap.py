from __future__ import annotations

from textwrap import dedent

from compatibility_model import PACKAGE_DIR, OUT_DIR

def write_roadmap() -> None:
    text = dedent(
        """\
        # Legacy Compatibility Mode Roadmap

        The implementation path should be fixture-first. Do not start with live
        packet injection; start by parsing captured or synthetic bytes and proving
        round trips.

        ## R0 Static Evidence Freeze

        Deliverables:

        - Keep this timestamped package as the source evidence bundle.
        - Store future PCAP and runtime logs as separate fixtures with hashes.
        - Maintain a table mapping every parser field to a source address, string,
          capture byte offset, or test fixture.

        Acceptance:

        - Every compatibility claim is tagged confirmed, observed, inferred,
          hypothesis, or requires validation.

        ## R1 Session/Control Compatibility

        Deliverables:

        - `/MESG_*` parser and generator.
        - Quick-connect model with `SR`, `BPS`, `CHNLS`, `FPS`, `BPP`, `X`, `Y`,
          `COMP`, and `BAYER`.
        - Golden tests for every static template.

        Acceptance:

        - Formatting round trip preserves static strings exactly where templates are known.
        - Parser accepts both semicolon-terminated and non-terminated audio-signal messages.

        ## R2 Config And Profile Compatibility

        Deliverables:

        - `LolaGui.ini` compatibility schema for AV/session keys.
        - `CAMERAFILES/*.ini` parser for camera profile names.
        - `XimeaColors.ini` parser for color defaults.

        Acceptance:

        - Every shipped INI line parses without data loss.
        - Defaults match static loader evidence: control 7000, audio 19788, video 19798,
          `WinPcap_SetMinToCopy` 10, `RxPacketFiltering` 1.

        ## R3 Packet Envelope Compatibility

        Deliverables:

        - Ethernet/IPv4/UDP frame parser with LoLa payload at offset 42.
        - PCAP fixture reader/writer.
        - Packet-builder tests for audio/video port selection.

        Acceptance:

        - Synthetic frames round-trip header and payload bytes.
        - Captured LoLa frames classify as audio or video by UDP port.

        ## R4 Audio TX/RX Compatibility

        Deliverables:

        - PCM frame model.
        - Audio packet parser/generator using the inferred `channels * 128` payload size.
        - Clock/cadence model for 44.1 kHz and 48 kHz.

        Acceptance:

        - Fixture packets decode to expected sample counts.
        - Generated packets match captured LoLa audio bytes for at least mono and stereo.
        - Drift/drop counters are mapped to observable behavior.

        ## R5 Video TX/RX Compatibility

        Deliverables:

        - CPU MJPEG chunk parser/decoder.
        - Raw video chunk parser.
        - Frame ring/reassembly model for 30-slot behavior.

        Acceptance:

        - Captured MJPEG frames decode with a standard JPEG library.
        - Raw frame dimensions and pixel formats match quick-connect fields.
        - Fragment order, frame ID, sequence, and loss behavior are byte-mapped.

        ## R6 Isolated Windows Peer Validation

        Deliverables:

        - Offline lab plan for two owned LoLa peers or one LoLa peer plus harness.
        - Packet captures for connect, quick-connect ACK, audio-only, video-only,
          raw video, CPU MJPEG, disconnect, reject, and chat.
        - Runtime DLL load log to confirm or reject GPUJPEG use.

        Acceptance:

        - No public network exposure.
        - No bypass of licensing, DRM, authentication, or access controls.
        - Every capture has SHA256, LoLa settings, hardware notes, and time base.

        ## R7 Legacy Compatibility Mode Prototype

        Deliverables:

        - Read-only PCAP replay/import.
        - Session parser/generator.
        - Audio decode/playback from captured LoLa packets.
        - Video decode/render from captured LoLa packets.
        - Optional TX generator gated behind lab-only tests.

        Acceptance:

        - LoLa-origin PCAPs replay audio and video correctly.
        - Generated session/control messages are accepted by an owned LoLa peer.
        - Generated AV packets interoperate with an owned LoLa peer in isolated lab tests.

        ## Do Not Start Until Evidence Exists

        - GPUJPEG compatibility beyond documentation.
        - Public network interoperability.
        - Binary patching.
        - Licensing, DRM, authentication, or access-control bypass.
        - Credential or secret extraction.
        """
    )
    (OUT_DIR / "legacy-compatibility-roadmap.md").write_text(text, encoding="utf-8")


def write_dod() -> None:
    text = dedent(
        """\
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
        """
    )
    (OUT_DIR / "definition-of-done-ledger.md").write_text(text, encoding="utf-8")


def update_parent_readme() -> None:
    readme = PACKAGE_DIR / "README.md"
    text = readme.read_text(encoding="utf-8")
    marker = "- [legacy-compatibility-mode/](legacy-compatibility-mode/): compatibility-focused addendum for LoLa 2.0 Windows Legacy Compatibility Mode."
    if marker not in text:
        text = text.replace(
            "- [data/strings-interest.json](data/strings-interest.json): machine-readable filtered string evidence.\n",
            "- [data/strings-interest.json](data/strings-interest.json): machine-readable filtered string evidence.\n"
            f"{marker}\n",
        )
    closure = dedent(
        """\

        ## Legacy Compatibility Mode Addendum

        The compatibility addendum classifies every artifact for LoLa 2.0 Windows
        Legacy Compatibility Mode and turns the static AV/session evidence into an
        implementation roadmap. Static analysis reaches a strong compatibility base,
        but byte-exact LoLa AV TX/RX remains `PARTIAL` until isolated Windows peer
        packet captures validate the remaining media payload fields.
        """
    )
    if "## Legacy Compatibility Mode Addendum" not in text:
        text = text.replace("\nVERDICT: PARTIAL\n", closure + "\nVERDICT: PARTIAL\n")
    readme.write_text(text, encoding="utf-8")
