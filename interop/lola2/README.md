# LoLa 2.0 Compatibility Corpus

This is an implementation-neutral, versioned wire-behaviour corpus for the
LoLa 2.0 compatibility surface. `manifest.json` is intentionally small enough
to review: ASCII controls are represented as their exact useful prefix plus
the required NUL-padding rule, and media vectors record the exact fixed fields
and compact payload bytes.

## Provenance and status

The corpus was recovered from the behaviour described in
`runtimes/linux-compat-connector/linux_connector/docs/protocol-reference.md` and checked against the current
Python codec. Its vectors are synthetic reconstructions. They are **not**
original Windows LoLa captures and must not be represented as such.

The `version` field is the compatibility-corpus version, not a LoLa product or
wire-protocol version. Additive cases require a minor version bump; changing a
case's expected wire bytes or acceptance category requires a major bump. Keep
each case immutable after release and add a replacement case instead.

## Consumer contract

Consumers load every case, perform the listed encode/decode operation, and
compare it to the normalized `accept` or `reject.*` category. Control cases
also verify exact 1024-byte NUL padding. SID vectors define lexical signed
decimal canonicalization independently of each runtime's narrower operational
session-ID range. This keeps compatibility evidence independent of a mutable
whole-source hash while still making divergences visible in ordinary test
runs.
