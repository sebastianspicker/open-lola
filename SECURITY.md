# Security Policy

## Source-alpha status

open-lola is an experimental source alpha with a public `PARTIAL` verdict. It
is not represented as suitable for production, field-certified, or a shipped
release.

## Deployment boundary

Current control and media protocols do not authenticate peers. Session
identifiers correlate traffic but are not credentials, and several listeners
can bind to all interfaces when configured that way. Run the software only on
an isolated network with trusted operators and explicitly configured peer and
bind addresses. Do not expose alpha listeners to the public internet or an
untrusted shared network.

The Linux compatibility connector accepts a claimed source address as part of
its control exchange. Treat that value as untrusted network input and restrict
the connector with host firewall rules. Process-backed media adapters execute
operator-supplied allowlisted commands from the ambient executable search path;
they are not a process sandbox. Use reviewed absolute executable paths on a
controlled host.

UltraGrid compatibility mode passes its shared secret through command-line and
configuration surfaces and derives the compatibility key using MD5 because the
reference protocol expects it. Command-line arguments may be visible to other
local processes. This mode is for isolated interoperability testing, not for
protecting confidential media or credentials.

Peer authentication, integrity protection, secret handling, and hostile-network
testing are required before any broader deployment claim.

## Reporting a vulnerability

Please report suspected vulnerabilities through this repository's
[private vulnerability reporting flow](../../security/advisories/new) or its
[Security tab](../../security). Do not report vulnerabilities in public issues.

Do not include credentials, private packet or media captures, personal data,
hostnames, access tokens, or other sensitive material in a public report. Use
only sanitized, minimal reproductions in public discussion. If the private
reporting flow is unavailable, do not disclose sensitive details publicly;
open a minimal public issue only to request a private reporting path.

## Report contents

In a private report, include the affected source revision, platform, concise
reproduction steps, observed and expected behavior, impact, and any relevant
evidence classification. Label evidence precisely (for example `source`,
`synthetic`, `localhost`, `measured hardware`, or `not measured`) and separate
facts from hypotheses.

Please do not claim a release, field deployment, or product `PASS` from a
source-level finding. We will coordinate follow-up through the private report
where that facility is available.
