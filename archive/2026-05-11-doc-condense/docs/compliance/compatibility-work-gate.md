# Compatibility Work Gate

Date: 2026-05-04
Milestone: [M04 Establish Clean-Room Requirement Translation](../../archive/2026-05-05-workflow-consolidation/superseded/docs/compliance/milestones/M04-clean-room-requirements.md)
Status: gate defined, pending reviewer signoff
Verdict: PARTIAL

## Purpose

This gate applies before any compatibility parser, compatibility packet format,
legacy-peer handshake, legacy-control message, or compatibility claim is added
to source code, tests, or public docs.

## Gate Checklist

- [ ] A `CRQ-*` requirement ID exists in
      [clean-room-requirement-ledger.md](clean-room-requirement-ledger.md).
- [ ] The internal observation is summarized without raw strings, packet byte
      maps, code, symbols, offsets, captures, or license/authentication logic.
- [ ] The engineering requirement is vendor-neutral or explicitly marked as a
      compatibility requirement.
- [ ] Compatibility is optional and disabled by default.
- [ ] Native open-lola packet/session defaults remain unchanged.
- [ ] Required captures or peer tests are authorized, sanitized, and retained
      outside public docs unless approved.
- [ ] Fixtures are synthetic or provenance-approved in
      [fixture-provenance.md](fixture-provenance.md).
- [ ] Public API and command names use open-lola-owned names unless a public
      standard name is required.
- [ ] Maintainer, clean-room reviewer, and legal reviewer sign off before source
      implementation.
- [ ] Public docs use confidence labels and avoid "drop-in compatible" wording
      until measured peer validation exists.

## Four-Layer Template

| Layer | Required content |
|---|---|
| Internal observation | Internal-only summary, source artifact class, evidence label, confidence, and reviewer. No raw details. |
| Engineering requirement | Independent behavior open-lola must achieve, with `CRQ-*` ID. |
| Clean implementation | Original code route using public APIs, public standards, own tests, and own fixtures. |
| Public documentation | Sanitized wording, confidence label, validation status, and no raw evidence links. |

## High-Risk Example: Legacy Wire Compatibility

| Layer | M04 conversion |
|---|---|
| Internal observation | Internal evidence indicates legacy peer compatibility is not proven and may require behavior outside the native Mac-fastest path. Evidence label: `observed` plus `requires validation`. Publication status: internal-only unless sanitized. |
| Engineering requirement | `CRQ-500`: Legacy compatibility remains optional, disabled by default, and separate from the fastest Mac-native path. `CRQ-501`: Any compatibility parser or packet work requires reviewer approval before source implementation. |
| Clean implementation | Keep the native UDP PCM/session defaults unchanged. If compatibility is promoted later, create a separate module, separate fixtures, separate CLI/report flag, explicit disabled-by-default runtime mode, and PASS guards that reject synthetic or unauthorized evidence. |
| Public documentation | "Legacy compatibility remains future optional work and requires authorized peer validation." |

No compatibility parser or packet implementation is authorized by this example.
It is a translation record only.

## Reviewer Signoff

| Role | Required before source work | Status |
|---|---|---|
| Maintainer | Confirms compatibility scope and default-off behavior. | Pending. |
| Clean-room reviewer | Confirms source work cites `CRQ-*`, not raw RE. | Pending. |
| Legal reviewer | Confirms captures, SDK terms, and publication wording are acceptable. | Pending. |

## Resume Here

Use this file as the first checklist for any future `compatibility`,
`legacy`, `parity`, or `wire-compatible` issue. If a proposed task cannot pass
this gate, keep it in the deferred parity ledger and do not implement it.

VERDICT: PARTIAL
