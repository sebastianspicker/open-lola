# Reverse-Engineering Boundary

Date: 2026-05-05  
Status: publication-safe boundary index  
Verdict: PARTIAL

This file is the public-safe reverse-engineering boundary for the current
product state. The
raw evidence store remains the top-level `reverse-engineering/` tree.

## Public Boundary

Public documentation may describe architecture-level lessons, clean-room
requirements, compatibility boundaries, and benchmark questions. It must not
publish proprietary message templates, private packet grammar, binary-derived
strings, addresses, hashes, or generated static-analysis packages.

Internal evidence remains outside this public docs lane. Treat it as maintainer
traceability input only. Implementation must flow through independent
requirements, public APIs, public standards, original open-lola tests, and own
measurements.

## Allowed Outputs

- sanitized architecture summaries;
- public API and public standard references;
- independent requirements;
- validation questions and benchmark plans;
- release redaction decisions.

## Blocked Outputs

- proprietary symbols or message templates;
- binary patching, bypass, exploit, or credential behavior;
- generated analysis packages;
- raw packet grammar or private capture identifiers.

Resume here: if a research finding needs to become public, convert it into an
independent requirement and cite the clean-room process before implementation.

VERDICT: PARTIAL
