# Process Artifacts

This ignored directory is a local-only bucket for private lab material and
reverse-engineering process output. Its contents must never be committed.

This folder may still hold future local-only material such as:

- `re_scripts/`: local Ghidra/helper scripts used during protocol discovery.
- local analysis output needed temporarily during development.

The public-facing connector lives one level up in the `linux_connector` root:

- `lola_connector/`
- `deployment/wsl/`
- `tools/`
- `tests/`
- the Markdown documentation files

This folder is for local-only process material because it can contain private
analysis output and environment-specific artifacts. Keep generated output out
of active docs and release candidates.

For the public-safe reverse-engineering method and redaction boundary, see
`../../docs/reverse-engineering-boundary.md`.
