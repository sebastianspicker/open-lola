# Publication Redactions

Date: 2026-05-03  
Status: publication-safety policy for public LoLa research docs  
Scope: what can be published, sanitized, kept internal, or omitted

## Redaction Classification

| Category | Publication decision | Sanitization |
|---|---|---|
| High-level AV TX/RX architecture | Safe to publish | Keep architecture-level; no function names, addresses, recovered implementation logic, or binary excerpts. |
| Audio/video pipeline behavior | Safe to publish | Describe stages and trade-offs; avoid private symbols and exact recovered implementation details. |
| Codec/raw-format findings | Safe after sanitization | Say CPU JPEG-like or raw/near-raw paths are strongly supported where evidence permits; avoid exact proprietary templates or binary strings. |
| Packetization/timing model | Safe after sanitization | Publish conceptual model only; no captured payload listings, byte maps, payload fields, or proprietary grammar. |
| Session/network behavior | Safe after sanitization | Describe "lightweight control/session layer" and "separate media path"; omit exact message templates, private strings, ports, and peer grammar unless maintainer approves. |
| Ghidra/radare2 outputs, function names, addresses | Internal only | Replace with "internal static analysis notes"; do not publish generated function names or address offsets. |
| Artifact hashes, PDB paths, build paths, file inventories | Internal only by default | Publish only if needed for reproducibility and maintainer-approved; otherwise summarize dependency categories. |
| Activation/licensing/host identity strings | Do not publish | Exclude entirely except a boundary statement: licensing/access-control analysis is out of scope. |
| Raw strings-of-interest dumps | Do not publish | Use paraphrased evidence categories only. |
| Packet captures or proprietary payloads | Do not publish unless sanitized and maintainer-approved | Use fixture-derived or synthetic examples only. |
| Compatibility claims | Requires maintainer review | Use `validated`, `strongly supported`, `inferred`, `hypothesis`, `future work`; never claim drop-in compatibility without peer tests. |

## Redaction Rules

- Public docs describe behavior classes, not private implementation artifacts.
- Public docs may refer to "internal static analysis notes" as an evidence
  label, not as a link to raw evidence.
- Public docs must not include proprietary message templates or byte-level
  protocol maps.
- Public docs must not include licensing/access-control reconstruction.
- Public docs must label Legacy Compatibility Mode as `PARTIAL` until controlled
  runtime, packet, and peer validation exists.

## Maintainer Review Gates

Maintainer review is required before publishing:

- any compatibility claim stronger than `strongly supported`;
- any sanitized packet analysis;
- any artifact inventory or reproducibility metadata;
- any statement that could be read as drop-in peer compatibility.

VERDICT: PARTIAL
