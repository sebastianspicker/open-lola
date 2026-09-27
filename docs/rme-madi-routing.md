# RME MADI routing

Status: source-level mapping and evidence model; physical routing open
Verdict: PARTIAL

This page specializes the general [audio routing](audio-routing.md) contract for
RME/MADI-class devices. It does not prescribe one TotalMix workspace or claim a
validated hardware matrix.

## Evidence Labels

| Input | Label |
|---|---|
| Core Audio device and stream properties | `public API` |
| MADI channel and clock terminology | `public standard` |
| Stable channel descriptors and route reports | `original open-lola design` |
| Interface-specific matrix and buffer settings | `experimentally derived requirement` |

## Mapping rules

- Discover the selected input and output devices by stable UID.
- Record physical stream and channel counts and the clock domain before applying a
  logical route.
- Preserve zero- and one-based numbering conventions explicitly at each UI or
  file boundary.
- Keep capture order, network order, and playback order visible in the report.
- Represent unused channels and any gain, mute, or matrix operation explicitly.
- Never infer a physical TotalMix route from a successful Core Audio inventory or
  source-level packet test.

The safest baseline is identity routing across the negotiated contiguous range.
Use an explicit matrix only when every source and destination mapping and gain is
validated and reported. A sample-rate or clock mismatch must fail preflight or
produce a visible non-passing result.

A physical validation record needs the RME model, driver and firmware, MADI mode,
optical or coax topology, clock source and lock, sample rate, channel count,
requested and accepted buffers, a matrix snapshot or sanitized description, and
sustained full-duplex evidence for the same build.

VERDICT: PARTIAL
