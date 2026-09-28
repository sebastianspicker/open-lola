# Reverse-engineering boundary

Status: active publication boundary
Verdict: PARTIAL

This repository may contain independently written compatibility code and
sanitized behavioral contracts. It must not contain proprietary binaries,
decompiler output, extracted strings or binary excerpts, restricted manuals, raw
private captures, address-level notes, hashes, command transcripts, or private
lab paths.

## Evidence Labels

| Material | Label |
|---|---|
| Public specifications and APIs | `public standard` or `public API` |
| Independently authored source and synthetic fixtures | `original open-lola design` |
| Sanitized black-box behavior needed for compatibility | `experimentally derived requirement` |
| Unconfirmed interpretations | `implementation hypothesis` |

## Public repository rule

Public documentation may state the smallest independently reviewable behavior
needed for compatibility, its evidence class, and the validation still missing.
It may not expose private evidence, reproduce proprietary structure, or imply
reference-peer interoperability from source, synthetic, localhost, or historical
observations.

Private captures, binaries, extraction output, environment details, and lab notes
remain outside Git. Any sanitization must remove credentials, personal data,
hostnames, topology, payload content, and material whose publication rights are
unclear.

Current source does not close byte-for-byte reference-peer, Windows hardware and driver, or
publication approval gates. See
[clean-room design rules](clean-room-design-rules.md) for contributor practice
and [RELEASING.md](RELEASING.md) for release approval.

VERDICT: PARTIAL
