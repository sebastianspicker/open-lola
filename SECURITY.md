# Security Policy

## Supported status

Open LoLa is an experimental source alpha with a public `PARTIAL` verdict. It is
not production-ready, field-certified, or hardened for hostile networks, and it
is not distributed as a supported release.

## Network boundary

The current control and media protocols do not authenticate peers and do not
provide media confidentiality or integrity. Session identifiers correlate
traffic but are not credentials. Some listeners can bind to all interfaces when
configured to do so.

Run the software only on isolated networks with trusted operators and explicit
bind and peer addresses. Do not expose alpha listeners to the public internet or
an untrusted shared network. Host firewalls and a separately secured tunnel can
reduce exposure, but they do not change the protocol's evidence status.

Source addresses claimed in control traffic are untrusted input. The Rust
control and media receive paths filter against the negotiated peer and fixed
source ports, but that filtering is not authentication.

UltraGrid compatibility mode derives its reference-compatible key with MD5 and
may pass the shared secret through command or configuration surfaces visible to
local processes. Use it only for isolated interoperability testing, never for
confidential media or credential protection.

## Local code execution and files

The applications run with the current user's permissions.

- Linux uses native ALSA and V4L2 adapters. The retired Python media subprocess
  allowlist no longer exists. ALSA accepts direct hardware PCMs and loads only
  canonical root-owned, non-writable system libraries; V4L2 uses selected
  character-device nodes with bounded buffers and cancellation.
- The Rust station loads XIMEA, PortAudio, and Npcap only from canonical direct
  children of fixed system/vendor installation directories. Dependent DLL
  lookup is limited to the selected DLL directory and System32; PATH, current
  directory, executable-adjacent, build, and archive searches are excluded.
  Diagnostic copying follows the same source policy. No signature or digest
  trust is established, so keep installation-directory permissions controlled
  and supply lawfully licensed libraries. See
  [configuration](docs/configuration.md).
- The macOS local bundle helpers create ad-hoc-signed, unsandboxed test
  artifacts. They do not produce Developer ID, notarized, Gatekeeper-verified,
  or distribution-ready applications.
- SSH mode executes generated commands and copies selected artifacts on the
  configured hosts. Review the SSH/SCP executables, accounts, host keys, working
  directories, and paths, and use least-privilege test accounts.
- CLI and app output paths are operator-controlled. Reports, logs, captures,
  settings, and evidence bundles can reveal topology, device, path, or session
  information. Store them with appropriate permissions and sanitize them before
  sharing.

Never place credentials, private captures, personal data, real hostnames,
licensed binaries, or confidential topology in an issue, fixture, report, or
documentation change.

## Before broader deployment

Peer authentication, replay protection, media integrity and confidentiality,
secret handling, hostile-input testing, signed dependency and native-library
provenance, and clean-machine validation all remain required before any broader
deployment claim.

## Reporting a vulnerability

Report suspected vulnerabilities through this repository's
[private vulnerability reporting flow](../../security/advisories/new) or its
[Security tab](../../security). Do not disclose sensitive details in a public
issue.

If the private flow is unavailable, open only a minimal public request for a
private contact path. Do not attach credentials, private packet or media
captures, personal data, hostnames, access tokens, proprietary files, or
confidential reproduction material.

Include the affected revision and platform, concise reproduction steps, observed
and expected behavior, impact, and the evidence class. A source-level finding or
local test result does not establish a release or field-deployment verdict.
