# Security policy

## Support status

Open LoLa is an experimental source alpha with a `PARTIAL` verdict. It is not
production-ready, not hardened for hostile networks, and not shipped as a
supported release.

## Network exposure

The control and media protocols do not authenticate peers, and media has no
encryption or integrity protection. Session identifiers correlate traffic; they
are not credentials. Some listeners bind to all interfaces if configured to.

Run the software only on isolated networks with trusted operators, and set the
bind and peer addresses yourself. Do not expose alpha listeners to the internet
or an untrusted shared network. A host firewall or a separately secured tunnel
reduces exposure but does not make the protocol secure.

Treat source addresses in control traffic as untrusted. The Rust control and
media receive paths drop datagrams that do not come from the negotiated peer and
fixed source ports, but that is filtering, not authentication.

UltraGrid compatibility mode derives its key with MD5, as the reference does,
and may expose the shared secret to local processes through command lines or
configuration. Use it only for isolated interoperability tests, never to protect
confidential media or credentials.

## Local code execution and files

The applications run with the current user's permissions.

- Linux uses native ALSA and V4L2 adapters; there is no longer a Python media
  subprocess. ALSA opens hardware PCMs directly and loads only root-owned,
  non-writable system libraries. V4L2 opens only the selected device nodes, with
  bounded buffers and cancellation.
- The Rust station loads XIMEA, PortAudio, and Npcap only from fixed system and
  vendor install directories. As a last resort it loads the known library file
  names from the running executable's directory, but never from a UNC or network
  path. Media Foundation loads from System32 only. These rules cover only the
  top-level DLL. Its imports resolve from that DLL's directory
  (`LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR`) and System32. `PATH`, the current
  directory, other files beside the executable, build directories, and
  archives are never searched. Diagnostic
  copying uses the same rules. Signatures and digests are not checked, so keep
  install-directory permissions tight and use properly licensed libraries. See
  [configuration](docs/configuration.md).
- The macOS local bundle helpers produce ad-hoc-signed, unsandboxed test apps.
  They are not Developer ID signed, notarized, or fit for distribution.
- SSH mode runs generated commands and copies selected files on the configured
  hosts. Check the SSH/SCP executables, accounts, host keys, working directories,
  and paths, and use low-privilege test accounts.
- The operator chooses where the CLI and app write output. Reports, logs,
  captures, settings, and evidence bundles can reveal network layout, devices,
  paths, or session details. Restrict their permissions and clean them before
  you share them.

Never put credentials, private captures, personal data, real hostnames, licensed
binaries, or confidential network details in an issue, fixture, report, or
documentation change.

## Before wider deployment

Wider deployment would first need peer authentication, replay protection, media
integrity and encryption, secret handling, hostile-input testing, verified
dependency and native-library sources, and testing on clean machines.

## Reporting a vulnerability

Report suspected vulnerabilities through the repository's
[private vulnerability reporting](../../security/advisories/new) or its
[Security tab](../../security). Do not post details in a public issue.

If private reporting is unavailable, open a short public issue that only asks
for a private contact. Do not attach credentials, packet or media captures,
personal data, hostnames, access tokens, proprietary files, or confidential
reproduction material.

Include the revision and platform, short reproduction steps, observed and
expected behavior, the impact, and what kind of evidence you have (for example
source reading, a local test, or a hardware run).
