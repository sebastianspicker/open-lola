# LoLa 2.0 compatibility corpus

A versioned set of LoLa 2.0 wire-behavior cases that any implementation can
test against. `manifest.json` is kept small enough to review by hand: ASCII
control messages are stored as their meaningful prefix plus the NUL-padding
rule, and media vectors store the exact fixed fields and short payload bytes.

## Origin

The cases were rebuilt from the protocol reference of the former Python
connector and checked against that codec before it was retired. They are
synthetic, **not** captures of the original Windows LoLa software, and must not
be described as such. For capture guidance, see
[packet capture](../../docs/packet-capture.md).

## Versioning

The `version` field is the corpus version, not a LoLa product or protocol
version. Adding cases needs a minor version bump. Changing a case's expected
wire bytes or acceptance category needs a major bump. Once released, a case does
not change; add a replacement case instead.

## Using the corpus

A consumer loads every case, runs the listed encode or decode operation, and
compares the result with the normalized `accept` or `reject.*` category. Control
cases also check the exact 1024-byte NUL padding. SID vectors define how a
signed decimal is canonicalized, independent of the narrower session-ID range
each runtime accepts. Because the cases are fixed data rather than a hash of the
whole source, a divergence shows up in ordinary test runs.

`migration-control-oracle.json` holds 110 synthetic ASCII and OSC15 parser
observations recorded before the Python code was retired. Rust tests read this
frozen file; the Cargo package does not need Python to run or test. Device tests
and hardware measurements are separate.

Two test suites replay the corpus, one in the Rust station and one for the macOS
connector. Their sources are not published. The macOS test compares encoded
control datagrams, audio fragments, and video packets with the corpus byte for
byte, and decodes the corpus bytes back. It re-encodes every accepted ASCII
oracle observation. It skips the 55 OSC15 observations, because only the Rust
station implements that dialect, and checks that the skipped list is exactly
those.
