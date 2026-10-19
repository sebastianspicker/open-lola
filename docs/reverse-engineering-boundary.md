# Reverse-engineering boundary

The repository may contain independently written compatibility code and short,
sanitized descriptions of LoLa behavior. It must not contain proprietary
binaries, decompiler output, extracted strings or binary excerpts, restricted
manuals, raw private captures, address-level notes, hashes, command transcripts,
or private lab paths.

## Evidence labels

| Material | Label |
|---|---|
| Public specifications and APIs | `public standard` or `public API` |
| Independently written source and synthetic fixtures | `original open-lola design` |
| Sanitized black-box behavior needed for compatibility | `experimentally derived requirement` |
| Unconfirmed interpretations | `implementation hypothesis` |

## What public docs may say

A public doc may state the smallest behavior needed for compatibility that a
reviewer can check independently, its evidence label, and what validation is
still missing. It must not expose private evidence or reproduce proprietary
structure. It must not suggest interoperability with a reference peer based on
source, synthetic, localhost, or historical results.

Keep private captures, binaries, extraction output, environment details, and lab
notes out of Git. Sanitizing means removing credentials, personal data,
hostnames, topology, payload content, and anything whose publication rights are
unclear.

The `interop/lola2` corpus is a synthetic reconstruction. The current source has
not been shown to match a reference peer byte for byte, has not been tested on
Windows hardware and drivers, and has not been approved for publication. See
[clean-room design rules](clean-room-design-rules.md) for contributor practice
and [RELEASING.md](RELEASING.md) for release approval.
