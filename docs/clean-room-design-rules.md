# Clean-room design rules

Status: active interoperability and publication boundary
Verdict: PARTIAL

Open LoLa is independently implemented. Compatibility work may describe the
minimum externally observable behavior needed to interoperate, but it must not
copy or redistribute proprietary implementation material.

## Evidence Labels

| Input or decision | Label |
|---|---|
| Published protocol, networking, media, and platform specifications | `public standard` or `public API` |
| Independently chosen Open LoLa packet, report, UI, and session behavior | `original open-lola design` |
| Sanitized black-box observations needed for compatibility | `experimentally derived requirement` |
| Unverified explanations or proposed behavior | `implementation hypothesis` |

## Permitted inputs

- public standards and public platform APIs;
- original source, fixtures, tests, measurements, and designs created for this
  project;
- concise behavioral facts observed through lawful black-box operation;
- sanitized packet dimensions, field relationships, message identifiers, and
  state transitions that are necessary to implement compatibility; and
- material whose contributor has verified authority to share.

Interoperability facts must be restated in original language and reduced to a
testable contract. The shared `interop/lola2` corpus is a synthetic
reconstruction derived from current project code and documentation; it does not
claim original capture provenance.

## Prohibited material

Do not commit or publish proprietary source, copied decompiler output, binary
excerpts, installers, DLLs, restricted manuals, license keys, activation data,
raw private captures, confidential logs, real topology, personal data, or
unreviewed extracted assets. Do not use proprietary symbol names or internal
implementation structure when a behavioral description is sufficient.

Compatibility documentation may contain the small field names and byte
relationships required for an independently written implementation. That is not
permission to publish raw captures, copied templates, long binary-derived tables,
or an analysis diary. When rights or provenance are unclear, keep the material
outside the repository and request legal or maintainer review.

## Engineering rules

1. Record the source class for each requirement.
2. Convert observations into the smallest implementation-independent rule.
3. Add positive and negative fixtures without embedding private payloads.
4. Keep Open LoLa's own protocol separate from LoLa compatibility behavior.
5. Treat a passing synthetic or localhost case as evidence for that case only.
6. Route third-party code through the vendor and notice review in
   [RELEASING.md](RELEASING.md).

Public documentation uses `Open LoLa` for the project name. Code identifiers,
package names, commands, and environment variables retain their literal forms.

## Review checklist

- The contributor can explain the right to share every input.
- No private or proprietary artifact is required to understand the change.
- Behavioral details are no broader than the implemented compatibility need.
- Evidence is labeled as public, synthetic, localhost, measured hardware,
  reference peer, or not measured.
- The change does not claim affiliation, endorsement, field readiness, or
  publication approval.

The legal boundary is described in [LEGAL.md](../LEGAL.md), source contracts in
[source-contracts.md](source-contracts.md), and exact source-candidate policy in
[RELEASING.md](RELEASING.md).

VERDICT: PARTIAL
