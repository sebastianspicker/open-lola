# M04 Establish Clean-Room Requirement Translation

Date: 2026-05-04
Status: implemented clean-room gate draft, pending reviewer signoff
Verdict: PARTIAL

## Objective

Make every research-derived implementation task pass through a clean-room
translation step before it reaches source code, tests, or public docs.

## Scope

Applies to compatibility work, native UDP/media protocols, session/control,
video, lighting, benchmark claims, and any source contract influenced by
reverse-engineering evidence.

## Affected Files

- `docs/compliance/clean-room-rules.md`
- `docs/compliance/clean-room-requirement-ledger.md`
- `docs/compliance/research-to-requirements-process.md`
- `docs/compliance/compatibility-work-gate.md`
- `docs/compliance/fixture-provenance.md`
- `docs/architecture/clean-room-design-rules.md`
- `docs/source-contracts/**`
- `Sources/**`
- `Tests/**`
- `reverse-engineering/**`
- `research/**`

## Actions

- Adopt the four-layer model: internal observation, engineering requirement,
  clean implementation, public documentation.
- Add requirement IDs for future protocol and compatibility work.
- Forbid source references to raw RE details.
- Require fixture provenance and original test data.
- Add reviewer gate before compatibility parser or packet work.

## Acceptance Criteria

- No implementation task cites raw RE as its direct source.
- Public APIs use open-lola-owned naming.
- Native packet/session formats are documented as original open-lola contracts.
- Compatibility mode remains optional and disabled by default.
- Reviewer can trace code to a sanitized requirement.
- Compatibility work has a dedicated gate before source changes.
- Fixture provenance is recorded or explicitly blocked.

## Risks

- Developers who read raw internal notes may unintentionally copy structure.
- Test fixtures may encode legacy details without provenance.
- Compatibility work may turn hypotheses into claims too early.

## Required Reviewer

Maintainer, clean-room reviewer, and legal reviewer for compatibility work.

## Progress Checklist

- [x] Requirement translation template adopted as review draft.
- [x] Future compatibility work gate defined.
- [x] Fixture provenance rule adopted.
- [x] Public API naming rule adopted.
- [x] Review checklist added to release packet.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume with M05 by closing the repository license, dependency license, SDK, and
third-party notice questions. For future compatibility work, start from
`docs/compliance/compatibility-work-gate.md`.

VERDICT: PARTIAL
