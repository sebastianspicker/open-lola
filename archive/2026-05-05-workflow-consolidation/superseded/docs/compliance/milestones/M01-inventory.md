# M01 Inventory Compliance-Relevant Files

Date: 2026-05-04
Status: implemented; maintainer/release-compliance signoff pending
Verdict: PARTIAL

## Objective

Create a reproducible inventory of every file that affects licensing,
clean-room boundaries, public documentation, release packaging, or evidence
traceability.

## Scope

Inventory source, tests, docs, research, reverse-engineering evidence, Windows
artifacts, package manifests, scripts, reports, fixtures, SDK references, TODOs,
diagrams, and benchmark notes.

## Affected Files

- `README.md`
- `MAC_PORT_PLAN.md`
- `Package.swift`
- `Sources/**`
- `Tests/**`
- `scripts/**`
- `docs/**`
- `mac-port/**`
- `research/**`
- `reverse-engineering/**`
- `win-compiled/**`
- future release manifest
- [../compliance-inventory.md](../compliance-inventory.md)
- [../release-manifest.md](../release-manifest.md)

## Actions

- Generate a file inventory grouped by release posture.
- Record file type, owner lane, public/internal status, and reason.
- Identify binaries, generated evidence, fixtures, packet captures, diagrams,
  screenshots, benchmark reports, and SDK references.
- Mark each file as include, exclude, review, or unknown for public release.
- Record missing root governance files: `LICENSE`, `THIRD_PARTY_NOTICES.md`,
  contributor rules, and release manifest.

## Acceptance Criteria

- Inventory covers every compliance-relevant path:
  [../compliance-inventory.md](../compliance-inventory.md).
- Each path has a release posture:
  [../release-manifest.md](../release-manifest.md).
- Binaries and generated evidence are explicitly flagged.
- Unknown provenance items are routed to
  [../open-questions.md](../open-questions.md).
- Maintainer can reproduce the inventory from documented commands.

## Risks

- A raw checkout may be mistaken for a public release artifact.
- Generated static-analysis evidence may be included accidentally.
- Deprecated docs may carry stale or unsafe claims.

## Required Reviewer

Maintainer plus release/compliance reviewer.

## Progress Checklist

- [x] File inventory generated.
- [x] Release posture assigned.
- [x] Binary and generated evidence list complete.
- [x] Fixture provenance list started.
- [x] Open questions updated.
- [ ] Reviewer signoff recorded.

## Resume Point

Resume with maintainer/release-compliance review of
[../release-manifest.md](../release-manifest.md). M01 remains `PARTIAL` until
the reviewer signoff line above is complete; then continue to M02 public versus
internal separation.

VERDICT: PARTIAL
