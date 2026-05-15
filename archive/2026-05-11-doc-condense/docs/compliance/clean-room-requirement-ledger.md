# Clean-Room Requirement Ledger

Date: 2026-05-04
Milestone: [M04 Establish Clean-Room Requirement Translation](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M04-clean-room-requirements.md)
Status: initial requirement ledger, pending reviewer signoff
Verdict: PARTIAL

## Purpose

This ledger gives implementation, tests, and public docs stable clean-room
requirement IDs to cite instead of raw research or reverse-engineering evidence.
It is an engineering governance artifact, not legal advice.

## Requirement ID Rule

Use `CRQ-###` IDs for clean-room requirements:

- `CRQ-001` through `CRQ-099`: cross-cutting clean-room and publication rules;
- `CRQ-100` through `CRQ-199`: protocol, packet, and session rules;
- `CRQ-200` through `CRQ-299`: audio, timing, and route rules;
- `CRQ-300` through `CRQ-399`: video and SDK-adapter rules;
- `CRQ-400` through `CRQ-499`: lighting, show-control, and standards rules;
- `CRQ-500` through `CRQ-599`: compatibility and parity rules;
- `CRQ-600` through `CRQ-699`: benchmark and release-claim rules.

Every new protocol or compatibility task must cite at least one `CRQ-*` ID
before source code, tests, or public docs are added.

## Ledger

| ID | Requirement | Source class | Clean implementation route | Public wording | Status |
|---|---|---|---|---|---|
| CRQ-001 | Implementation work cites sanitized requirements, public APIs, public standards, original tests, or measured reports, not raw RE artifacts. | Governance. | Require requirement IDs in implementation handoffs and release review. | "Implementation follows clean-room requirements." | Active draft. |
| CRQ-002 | Public API, command, report, and wire names use open-lola-owned naming unless a public standard name is required. | Governance. | Name native contracts from open-lola behavior and public standards. | "open-lola exposes original protocol and report contracts." | Active draft. |
| CRQ-003 | Test fixtures must be synthetic, open-lola-generated, public-standard examples, or provenance-approved measured data. | Governance. | Maintain fixture provenance before public release. | "Tests use original fixtures with recorded provenance." | Active draft. |
| CRQ-100 | Native UDP PCM and direct media packet contracts are original open-lola contracts. | Sanitized architecture and source contracts. | Implement strict versioned packet parsers and serializers from open-lola tests. | "The native media contract is open-lola-owned." | Implemented source gate; physical evidence separate. |
| CRQ-101 | Media transport and control/session exchange remain separate lanes. | Sanitized research summary. | Keep UDP media packets independent from JSON/session control. | "Media and control are separate open-lola lanes." | Implemented source gate; runtime evidence partial. |
| CRQ-200 | Fastest audio mode must expose every added buffer and reject hidden latency growth. | Sanitized research summary and measured-report design. | Use explicit latency/RX profiles and PASS guards. | "Direct Audio First is measurement-gated." | Implemented source gate; hardware evidence partial. |
| CRQ-300 | Video must degrade, drop, or disable before it changes audio playout latency. | Sanitized research summary. | Latest-frame queues, degradation policies, and audio-impact report fields. | "Video is best effort and subordinate to audio." | Implemented source gate; physical evidence partial. |
| CRQ-301 | Blackmagic/ATEM support uses public macOS APIs first; Desktop Video SDK work is optional and license-gated. | Public API/SDK documentation plus compliance review. | Keep default builds free of SDK headers/libs; add adapter only after review. | "Blackmagic capture is tested through public macOS surfaces first." | Active draft. |
| CRQ-400 | Lighting output requires standards review, explicit arm, isolated route, allowed universe, packet capture, and no audio impact. | Public standards/vendor docs plus compliance review. | Gate sACN/Art-Net output behind safety reports and provenance checks. | "Lighting is standards-gated and isolated." | Implemented source gate; standards/review evidence partial. |
| CRQ-500 | Legacy compatibility remains optional, disabled by default, and separate from the fastest Mac-native path. | Sanitized internal observation and public roadmap. | Keep parity ledger and compatibility gates separate from native protocol defaults. | "Legacy compatibility is future optional work." | Active draft. |
| CRQ-501 | Compatibility parser, packet, or peer work requires reviewer approval before source implementation. | Governance. | Use [compatibility-work-gate.md](compatibility-work-gate.md) before any compatibility parser or packet code. | "Compatibility claims require authorized peer validation." | Active draft. |
| CRQ-600 | Performance superiority claims require measured same-hardware, same-route reports and cannot be inferred from static evidence. | Benchmark governance. | Use benchmark ledgers and PASS guards. | "Performance claims stay PARTIAL until measured." | Implemented source gate; measured evidence partial. |
| CRQ-601 | Public releases are created from an allowlist and exclude raw internal evidence unless explicitly approved. | Release governance. | Use the release manifest and M10 review packet. | "Public releases are curated." | Active draft. |

## M04 Audit Snapshot

The M04 source/test scan found no implementation file citing
`reverse-engineering/**`, `win-compiled/**`, or root `research/RESEARCH_*.md`
as direct implementation authority. Matches in source were ordinary original
packet offsets, release-hardening guard tests, or deferred LoLa parity and
benchmark naming. Those areas remain governed by `CRQ-100`, `CRQ-500`, and
`CRQ-600`.

## M08 Implementation Audit Snapshot

The superseded M08 implementation audit is archived under
[../../archive/2026-05-10-superseded-plans-audits-goals/](../../archive/2026-05-10-superseded-plans-audits-goals/).
Current release review must use [release-manifest.md](release-manifest.md) and
fresh verification over `Sources/**`, `Tests/**`, `docs/source-contracts/**`,
and `docs/architecture/**` for raw RE references, copied packet grammar,
binary-derived names, proprietary templates, fixture provenance gaps, optional
SDK boundaries, and public API naming.

Audit disposition:

- native UDP PCM, direct media, video fragment, and session contracts remain
  original open-lola source contracts under `CRQ-100` and `CRQ-101`;
- the only raw internal evidence path under `Tests/**` is an intentional
  release-hardening negative test that rejects internal evidence as claim
  authority;
- compatibility and parity labels remain deferred and governed by `CRQ-500` and
  `CRQ-501`;
- fixture provenance remains blocked by CQ019 before public release;
- generated `.DS_Store` metadata was removed from the release/source surface.

## Review Rule

A `CRQ-*` ID can support implementation only when:

- the internal observation is summarized without raw detail;
- the engineering requirement is vendor-neutral or public-standard based;
- the clean implementation route uses original code and tests;
- fixture provenance is recorded;
- public wording is sanitized and confidence-labeled;
- reviewer signoff is recorded for compatibility work.

## Resume Here

For new protocol work, cite `CRQ-100` or `CRQ-101` and link the original
open-lola packet/session tests. For compatibility work, start with `CRQ-500`
and `CRQ-501`, then complete [compatibility-work-gate.md](compatibility-work-gate.md)
before source changes. For release work, rerun
[release-manifest.md](release-manifest.md) and current verification before M10.

VERDICT: PARTIAL
