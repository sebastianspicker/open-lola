# Clean-Room Design Rules

Date: 2026-05-03  
Status: publication-safe clean-room requirements  
Verdict: PARTIAL

## Purpose

This document defines how open-lola can learn from LoLa-style low-latency
audio/video systems without copying proprietary implementation details.

The public design target is an original, open, macOS-first peer-to-peer AV
system for professional music and performance use. It is not a drop-in
implementation of any proprietary peer, packet grammar, control language, or
hardware bundle.

## Safe Inputs

Safe inputs for implementation:

- public standards such as UDP, RTP, OSC, Art-Net, and sACN;
- public Apple APIs such as Core Audio, AVFoundation, and VideoToolbox;
- public Blackmagic Design Desktop Video SDK material;
- public RME driver and device behavior visible through Core Audio;
- open-lola-owned tests, fixtures, measurements, and packet captures;
- high-level behavior lessons rewritten as independent requirements;
- publication-safe research summaries under
  [validation-methodology.md](validation-methodology.md).

## Forbidden Inputs

Do not copy or reproduce:

- proprietary source code or binary code;
- decompiled algorithms, control flow, function names, symbols, or addresses;
- private strings, control templates, packet fields, byte maps, or payload
  grammar;
- proprietary message ordering when it is only known from reverse-engineering;
- licensing, activation, host-identity, or access-control reconstruction;
- reverse-engineered vendor code;
- Windows LoLa wire compatibility as a default design constraint.

## Requirement Conversion

Reverse-engineering evidence may only become implementation work after it is
rewritten as an independent requirement.

Implementation-affecting requirements use `CRQ-*` IDs summarized in
[release-boundary.md](release-boundary.md). Compatibility parser or
packet work must also follow the release boundary in
[release-manifest.md](release-manifest.md).

| Internal observation class | Safe open-lola requirement |
|---|---|
| Separate media and control behavior is supported. | Keep media transport independent from control/session work. |
| Low buffering appears central. | Make fastest mode use zero or one receive block unless measurement rejects it. |
| Real-time audio deadlines dominate. | Audio callback work must be bounded, nonblocking, and allocation-free. |
| Video can consume bandwidth and CPU. | Video must degrade before it changes default audio latency. |
| Control data is useful for performance workflows. | Lighting/control runs on a secondary synchronized path. |

## Evidence Labels

Every design choice must be labeled as one of:

- `public standard`;
- `public API`;
- `original open-lola design`;
- `experimentally derived requirement`;
- `compatibility requirement`;
- `implementation hypothesis`.

Claims stronger than `implementation hypothesis` need a test, fixture, public
standard/API source, or measured report.

## Source Naming

Shared source-file suffixes carry narrow ownership meanings:

- `*Helpers` files hold validation helpers, parsing helpers, fixture builders, or
  domain-local transformations that are not CLI-facing command adapters.
- `*Support` files hold CLI argument shims, command adapters, process
  orchestration support, or module support that is intentionally exposed to a
  command/runtime surface.
- `*Utilities` is not a default suffix for new source. Prefer a domain noun and
  concrete responsibility; use `*Utilities` only when no narrower owner suffix
  fits.

Existing examples follow this boundary: `PackagingFieldTestHelpers.swift`,
`RecordingSessionHelpers.swift`, and `ReferenceRigHelpers.swift` are validation
or evidence helpers, while `DirectP2PSessionRunArgumentSupport.swift` and
`DirectP2PMeasuredEvidenceCommandSupport.swift` are CLI command support.

## Public Documentation Boundary

Public docs may describe architecture, trade-offs, metrics, and validation
methods. They must not expose raw reverse-engineering evidence.

Use [release-boundary.md](release-boundary.md) as the redaction and release
boundary policy. Internal evidence remains outside the public release surface
and must not be linked from publication docs.

## Review Checklist

- [x] Public docs describe behavior classes, not proprietary details.
- [x] Public protocol work is open-lola-owned unless a public standard is named.
- [x] Windows LoLa evidence is not treated as a packet or control spec.
- [x] Faster or more compatible modes remain measured and optional.
- [x] Implementation-affecting tasks cite `CRQ-*` clean-room requirements.
- [x] Fixture provenance is governed by the active
      [release manifest](release-manifest.md).
- [ ] Maintainer review before public release.

VERDICT: PARTIAL
