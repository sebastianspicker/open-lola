# Public And Internal Boundary

Date: 2026-05-04
Milestone: [M02 Separate Internal RE Notes From Public Docs](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M02-internal-vs-public-separation.md)
Status: implemented boundary draft, pending reviewer signoff
Verdict: PARTIAL

## Purpose

This file defines the M02 publication boundary for the Mac port. It is an
engineering governance control, not legal advice.

The repository is not a public release artifact as checked out. Public
publication must be assembled from an allowlist and must not include raw
reverse-engineering evidence, bundled third-party binaries, generated static
analysis output, private captures, secrets, or unclear sample data.

## Lane Map

| Lane | Paths | Publication posture | Rule |
|---|---|---|---|
| Public implementation | `Sources/**`, `Tests/**/*.swift`, `Package.swift`, `scripts/**` | Include by default after normal verification and license review. | Must be original open-lola work using public APIs, standards, and original tests. |
| Public documentation | `README.md`, `docs/README.md`, `docs/current-state.md`, `docs/roadmap/**`, `docs/architecture/**`, `docs/benchmarks/**`, `docs/source-contracts/**`, `docs/background/**` | Curated public surface after M06/M08 review. | Must describe requirements, architecture, validation, and confidence without raw proprietary evidence. |
| Governance documentation | `docs/compliance/**` | Review before public export. | Useful for release review, but may disclose internal process, unresolved legal questions, or exclusion rules. |
| Mixed roadmap and handoff | `mac-port/**`, archived mixed-roadmap snapshots, `docs/historical/**` | Review before including. | May contain stale claims, internal links, route context, or planning language that needs public wording review. |
| Evidence reports | `mac-port/reports/**` | Exclude by default. | Publish only selected redacted summaries; raw reports may contain route context, command lines, captures, endpoint examples, or measured-run detail. |
| Internal research notes | `research/RESEARCH_*.md` | Internal or sanitized-copy only by default. | Use as source context for requirements, not as public release docs. |
| Deprecated research | `research/deprecated-research/**` | Exclude by default. | Do not publish stale assumptions. |
| Reverse-engineering evidence | `reverse-engineering/**` | Exclude by default. | Keep internal for traceability only; do not publish raw static-analysis detail. |
| Windows binary corpus | `win-compiled/**` | Exclude by default. | Treat as internal evidence and benchmark context with unclear redistribution rights. |
| Generated or private artifacts | `.build/**`, `.swiftpm/**`, `DerivedData/**`, captures, media, screenshots, local env files | Exclude by default. | Include only if sanitized, provenance-labeled, and explicitly approved. |

## Research Publication Decision

For M02, `docs/background/**` is the curated public research lane. It may be
included in a public source release after the normal M06 public-documentation
review checks for private evidence, unsupported compatibility claims, stale
confidence labels, and attribution gaps.

Root `research/RESEARCH_*.md` remains internal/review-only. If a finding from
root `research/` is useful publicly, create or update a sanitized file under
`docs/background/` rather than linking to the root note.

## Public Documentation Rules

- Public docs may explain goals, architecture, validation methodology,
  confidence levels, and independently written open-lola requirements.
- Public docs must not link directly to `win-compiled/**`,
  `reverse-engineering/**`, archived internal evidence packages, or root
  `research/RESEARCH_*.md`.
- Public docs must not include decompiled code, binary excerpts, raw packet
  captures, packet byte maps, generated static-analysis labels, proprietary
  strings, license/authentication behavior, secrets, credentials, or private
  endpoints.
- Public docs must distinguish confirmed evidence from observed, inferred,
  hypothetical, contradicted, obsolete, and requires-validation claims.
- Public docs must avoid claiming wire compatibility, device compatibility, or
  release readiness unless the corresponding public validation report exists.

## Internal Evidence Rules

- Internal evidence may be retained for traceability, but it is not a public
  source release lane.
- Internal evidence may support an internal observation. It must be translated
  into an open engineering requirement before implementation work uses it.
- Implementation docs and source comments must reference public requirements,
  standards, public APIs, and original tests, not proprietary implementation
  artifacts.
- Any compatibility-mode work needs maintainer/legal review before publication
  if it depends on non-public observations.

## Public-Safe Replacement Pattern

Use this transformation when converting internal research into public material:

| Internal-only wording pattern | Public-safe replacement |
|---|---|
| "The proprietary binary does X at address/symbol/string Y." | "Internal observation indicates this behavior class exists; open-lola independently requires equivalent user-visible capability." |
| "Packet field A/B/C has this byte layout." | "The implementation needs a versioned, testable message contract with explicit validation and failure behavior." |
| "License/authentication logic behaves as follows." | "License/authentication behavior is out of public scope and must not be implemented or documented as bypass logic." |
| "This vendor implementation uses algorithm Z." | "open-lola will use an independently selected algorithm justified by public standards, measurements, and original tests." |

## Resume Here

Before any public export, use [release-manifest.md](release-manifest.md),
[public-documentation-safety.md](public-documentation-safety.md), and fresh
documentation verification together. The manifest defines the allowlist and
exclusion posture; the safety document records the active public-doc rules.

VERDICT: PARTIAL
