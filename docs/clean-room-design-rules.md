# Clean-room design rules

Open LoLa is written independently. Compatibility work may describe the minimum
externally visible behavior needed to interoperate with LoLa. It must not copy or
redistribute proprietary implementation material.

## Evidence Labels

Tag every requirement with where it came from:

| Input or decision | Label |
|---|---|
| Published protocol, networking, media, and platform specifications | `public standard` or `public API` |
| Packet, report, UI, and session behavior chosen by Open LoLa | `original open-lola design` |
| Sanitized black-box observations needed for compatibility | `experimentally derived requirement` |
| Unverified explanations or proposed behavior | `implementation hypothesis` |

## Allowed inputs

- public standards and public platform APIs;
- source, fixtures, tests, measurements, and designs written for this project;
- short behavioral facts observed through lawful black-box operation;
- sanitized packet sizes, field relationships, message identifiers, and state
  transitions that compatibility actually needs;
- material the contributor has confirmed they may share.

Restate interoperability facts in your own words and reduce each one to a
testable rule. The `interop/lola2` corpus is a synthetic reconstruction built from
current project code and docs. It is not derived from original captures.

## Prohibited material

Do not commit or publish:

- proprietary source, copied decompiler output, or binary excerpts;
- installers, DLLs, restricted manuals, license keys, or activation data;
- raw private captures, confidential logs, real network topology, or personal
  data;
- extracted assets that have not been reviewed.

Do not use proprietary symbol names or internal structure when a description of
the behavior is enough.

Compatibility docs may name the few fields and byte relationships an independent
implementation needs. That does not allow raw captures, copied templates, long
tables derived from binaries, or analysis diaries. If rights or provenance are
unclear, keep the material out of the repository and ask a maintainer or legal
reviewer.

## Engineering rules

1. Record the source class of each requirement.
2. Reduce each observation to the smallest rule that does not depend on any one
   implementation.
3. Add positive and negative fixtures without private payloads.
4. Keep Open LoLa's own protocol separate from LoLa compatibility behavior.
5. A passing synthetic or localhost case is evidence for that case only.
6. Send third-party code through the vendor and notice review in
   [RELEASING.md](RELEASING.md).

Public docs call the project `Open LoLa`. Code identifiers, package names,
commands, and environment variables keep their literal spelling.

## Review checklist

- The contributor can explain why they may share every input.
- No private or proprietary artifact is needed to understand the change.
- Behavioral details go no further than the compatibility the code implements.
- Evidence is labeled as public, synthetic, localhost, measured hardware,
  reference peer, or not measured.
- The change does not claim affiliation, endorsement, field readiness, or
  approval to publish.

See [LEGAL.md](../LEGAL.md) for the legal position,
[source-contracts.md](source-contracts.md) for compatibility promises, and
[RELEASING.md](RELEASING.md) for the release file policy.

VERDICT: PARTIAL
