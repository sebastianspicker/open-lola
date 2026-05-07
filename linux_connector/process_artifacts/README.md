# Process Artifacts

This directory is the local archive bucket for private lab material and reverse-engineering process output.

It currently holds:

- `re_out/`: generated reverse-engineering notes, extracted strings, and decompiler/process output.
- `re_scripts/`: local Ghidra/helper scripts used during protocol discovery.
- local archives of the same analysis output.

The public-facing connector lives one level up in the `linux_connector` root:

- `lola_connector/`
- `env/`
- `tools/`
- `tests/`
- the Markdown documentation files

This folder is ignored by `.gitignore` except for this README because it can contain private analysis output and environment-specific artifacts.

For the public-safe reverse-engineering method and redaction boundary, see `../docs/reverse-engineering-notes.md`.
