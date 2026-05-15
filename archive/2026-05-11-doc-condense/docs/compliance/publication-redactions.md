# Publication Redactions

Date: 2026-05-04
Status: compliance redaction guide
Verdict: PARTIAL

## Redaction Classes

| Content class | Decision | Replacement |
|---|---|---|
| Architecture-level behavior | Safe | Keep public and labeled. |
| Open-lola source contracts | Safe after review | State they are original open-lola designs. |
| Public standards/API references | Safe after terms review | Cite standards or official vendor pages. |
| Internal static-analysis summaries | Safe after sanitization | "Internal static analysis notes." |
| Generated function labels, offsets, addresses | Internal only | "Function-level detail withheld." |
| Binary strings and hashes | Internal only | "Artifact identity retained internally." |
| Packet captures, byte maps, payload grammar | Internal only unless sanitized and approved | "Protocol behavior requires authorized validation." |
| License/authentication/host identity behavior | Do not publish | "Licensing and access-control behavior is out of scope." |
| Vendor SDK files or sample code | Do not publish unless license permits | "Optional adapter requires installed vendor SDK." |
| Secrets, credentials, private endpoints | Do not publish | "Private operational data removed." |
| Compatibility claims | Requires review | "Compatibility remains PARTIAL until peer validation." |

## Redaction Procedure

1. Identify the target audience and release artifact.
2. Remove raw internal evidence links.
3. Replace binary-derived details with behavior classes.
4. Add confidence labels.
5. Add validation tasks for every unresolved claim.
6. Re-run documentation verification.
7. Get maintainer/legal review for compatibility, SDK, and redistribution
   claims.

## Public-Safe Replacement Examples

| Risky phrasing | Public-safe phrasing |
|---|---|
| Exact recovered control grammar | "Legacy control messages indicate a lightweight session lane." |
| Exact packet byte offset | "Legacy media packets suggest low-overhead transport; open-lola defines its own packet contract." |
| Exact generated function label | "Internal static evidence indicates this behavior." |
| Exact activation/host identity observation | "License and access-control behavior is out of scope and not published." |
| "Windows compatible" | "Compatibility mode is future work and requires authorized peer tests." |
| "Faster than LoLa" without measured evidence | "Faster-than-LoLa closure remains PARTIAL until measured baselines exist." |

## Resume here

Use this guide when preparing public docs or release notes from any material in
`background/`, `reverse-engineering/`, `mac-port/`, or `docs/historical/`.

VERDICT: PARTIAL
