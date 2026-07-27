# Tools

The canonical packet-capture workflow is
[../docs/packet-capture.md](../docs/packet-capture.md). This file documents the
helper tools in `linux_connector/tools/`.

Small public helper tools for validating LoLa connector behavior.

## `lola_packet_decoder.py`

Offline decoder for LoLa audio/video UDP payloads in packet captures. It parses LoLa normal fragments, video preludes, audio payload metadata, and frame completeness.

Install the packet-capture dependency before using it:

```bash
python -m pip install "open-lola-linux-connector[pcap]"
```

From a local checkout, use:

```bash
python -m pip install ".[pcap]"
```

Example:

```bash
python tools/lola_packet_decoder.py capture.pcapng
```
