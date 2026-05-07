# Tools

The canonical packet-capture workflow is now [../docs/packet-capture.md](../docs/packet-capture.md). This file remains as a local helper-tool reference for the `tools/` directory.

Small public helper tools for validating LoLa connector behavior.

## `lola_packet_decoder.py`

Offline decoder for LoLa audio/video UDP payloads in packet captures. It parses LoLa normal fragments, video preludes, audio payload metadata, and frame completeness.

Example:

```bash
python tools/lola_packet_decoder.py capture.pcapng
```
