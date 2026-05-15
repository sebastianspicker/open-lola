# Evidence Governance

Date: 2026-05-04
Status: evidence labeling and traceability model
Verdict: PARTIAL

## Evidence Labels

Every finding must use one or more of these labels:

| Label | Meaning | Publication status |
|---|---|---|
| `confirmed` | Proven by public standard/API, open-lola test, fixture, or measured report. | Public-safe if sanitized. |
| `observed` | Seen in internal research or static evidence. | Public-safe only as a sanitized claim. |
| `inferred` | Reasonable conclusion from evidence, but not directly proven. | Public-safe with caution label. |
| `hypothesis` | Candidate explanation or implementation idea. | Public-safe only as future work. |
| `contradicted` | Evidence conflicts with this claim. | Public-safe if useful and sanitized. |
| `obsolete` | Superseded by later roadmap or evidence. | Internal or historical only. |
| `requires validation` | Needs hardware, peer, packet capture, standard, SDK, or legal review. | Public-safe if no raw details leak. |
| `internal-only` | Contains raw RE, proprietary, binary, private, security, or license-sensitive content. | Do not publish. |

## Required Fields

Every finding should include:

- finding ID;
- related `CRQ-*` requirement ID where implementation is affected;
- short title;
- source artifact path;
- evidence type;
- evidence label;
- confidence;
- implementation relevance;
- publication status;
- sanitization status;
- validation task;
- owner/reviewer;
- last reviewed date.

## Source Artifact Classes

| Source artifact | Evidence type | Default publication status |
|---|---|---|
| `Sources/`, `Tests/` | Original implementation/test evidence | Public-safe after license review. |
| `docs/architecture/`, `docs/source-contracts/` | Sanitized design evidence | Public-safe after review. |
| `mac-port/reports/` | Report evidence | Public-safe after private data audit. |
| `background/` | Research planning evidence | Internal until sanitized. |
| `reverse-engineering/` | Internal static evidence | Internal-only. |
| `archive/2026-05-05-workflow-consolidation/internal-evidence/reverse-engineering/evidence-packages/` | Generated evidence | Internal-only. |
| `win-compiled/` | Binary corpus | Internal-only. |
| Public vendor docs | Public API/SDK/standard evidence | Public-safe as citation, subject to terms. |

## Finding Template

```markdown
## FINDING-ID Title

- Source artifact:
- Evidence type:
- Evidence label:
- Confidence:
- Implementation relevance:
- Publication status:
- Sanitization status:
- Validation task:
- Owner/reviewer:
- Last reviewed:

### Sanitized Requirement

### Clean Implementation Route

### Public Wording
```

## Traceability Rule

Internal evidence can support a requirement only through an intermediate
sanitized requirement. Source commits, tests, public docs, and release notes
must cite the sanitized requirement or measured report, not raw evidence.

For implementation-affecting findings, the sanitized requirement is recorded in
[clean-room-requirement-ledger.md](clean-room-requirement-ledger.md). For
compatibility work, the gate is
[compatibility-work-gate.md](compatibility-work-gate.md).

## Resume here

Convert the current reverse-engineering evidence matrix into this structure
only if maintainers decide the traceability work is worth the maintenance cost.

VERDICT: PARTIAL
