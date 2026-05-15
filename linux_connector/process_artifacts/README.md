# Process Artifacts

This directory is the local archive bucket for private lab material and reverse-engineering process output.

Historical process output is now preserved under the root archive, not in this
folder:

- `../../archive/2026-05-10-superseded-plans-audits-goals/generated/re_out/`:
  generated reverse-engineering notes, extracted strings, and
  decompiler/process output.

This folder may still hold future local-only material such as:

- `re_scripts/`: local Ghidra/helper scripts used during protocol discovery.
- local archives of the same analysis output.

The public-facing connector lives one level up in the `linux_connector` root:

- `lola_connector/`
- `env/`
- `tools/`
- `tests/`
- the Markdown documentation files

This folder is for local-only process material because it can contain private
analysis output and environment-specific artifacts. Keep generated output out
of active docs and release candidates.

For the public-safe reverse-engineering method and redaction boundary, see `../docs/reverse-engineering-notes.md`.
