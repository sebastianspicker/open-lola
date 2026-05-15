# Clean-Room Rules

Date: 2026-05-04
Status: compliance rules for implementation and docs
Verdict: PARTIAL

## Core Rule

open-lola must implement original Mac-native behavior using original code,
public standards, public APIs, and open-lola-owned tests. Internal
reverse-engineering evidence may guide risk awareness and validation planning,
but it must not become a public protocol spec or source-level implementation
blueprint.

## Allowed Inputs

- Public standards: UDP, RTP where used, OSC, sACN/E1.31, Art-Net after terms
  review, AVB/AES67/RAVENNA where specifications and rights permit.
- Public Apple APIs: Core Audio, AVFoundation, CoreMedia, VideoToolbox, Network
  framework, AppKit/SwiftUI, and related public SDK documentation.
- Public vendor documentation and SDK manuals after license review.
- open-lola-owned measurements, tests, fixtures, benchmarks, and reports.
- Sanitized public research summaries with evidence labels.
- Internal RE observations rewritten as independent engineering requirements.

## Forbidden Inputs

Do not copy, publish, or implement from:

- proprietary or decompiled code;
- binary-derived source-like pseudocode;
- generated function names, symbol names, offsets, addresses, or disassembly;
- proprietary packet layouts, byte maps, control templates, or payload grammar;
- raw packet captures from proprietary peers unless explicitly authorized and
  sanitized;
- license, activation, authentication, host identity, serial, registry, or DRM
  behavior;
- vendor SDK files, headers, samples, or libraries unless redistribution is
  allowed and documented;
- unclear sample data or venue/customer data.

## Implementation Rules

1. Every implementation task must cite a clean engineering requirement, not a
   raw reverse-engineering file.
2. Protocol, packet, session, compatibility, benchmark, and release work must
   cite a `CRQ-*` ID from
   [clean-room-requirement-ledger.md](clean-room-requirement-ledger.md).
3. Source files must use open-lola naming for public APIs and wire contracts.
4. Native UDP PCM packet formats must remain original open-lola contracts.
5. Compatibility mode must be optional, disabled by default, and reviewed before
   implementation.
6. Public release builds must pass without Blackmagic Desktop Video SDK, RME
   proprietary files, Dante SDK files, or Windows LoLa artifacts installed.
7. Tests must use synthetic fixtures or open-lola-captured data with recorded
   provenance in [fixture-provenance.md](fixture-provenance.md).
8. Performance claims must require measured reports, not static inference.

## Documentation Rules

Public docs may say:

- "legacy systems suggest separate media and control responsibilities";
- "open-lola implements an original native UDP PCM transport";
- "compatibility mode remains future work and requires authorized captures";
- "claims are PARTIAL until measured hardware evidence exists".

Public docs must not say:

- exact recovered message names or templates;
- exact proprietary default ports or byte offsets;
- generated static-analysis function labels;
- activation, host identity, serial, or license-check behavior;
- "drop-in compatible" unless peer tests and maintainer/legal review approve it.

## Review Gate

Before code or docs are promoted:

- reviewer confirms the cited requirement is not raw RE content;
- reviewer confirms the cited `CRQ-*` ID exists and matches the task;
- source diff contains no copied strings, offsets, byte maps, or function names;
- fixtures have provenance;
- public docs contain confidence labels;
- the release packet excludes internal-only artifacts.

Compatibility parser, packet, or peer work must also pass
[compatibility-work-gate.md](compatibility-work-gate.md) before source changes.

## Resume here

Apply the conversion model in
[research-to-requirements-process.md](research-to-requirements-process.md) to
any future compatibility or protocol work.

VERDICT: PARTIAL
