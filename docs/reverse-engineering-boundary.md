# Reverse-Engineering Boundary

Date: 2026-05-15
Status: public-safe reverse-engineering summary after consolidation
Verdict: PARTIAL

This file is the public-facing reverse-engineering boundary. It records
what can be said safely in the documentation tree without exposing raw Windows
binary evidence, extracted strings, address-level notes, hashes, command
transcripts, packet captures, or private lab paths.

Detailed reverse-engineering evidence, binaries, captures, and process notes
must remain outside Git. Only sanitized, independently reviewable summaries may
appear in public documentation.

## Current Implementation Stage

The LoLa connector is source-level implemented from local evidence and the
Linux compatibility prototype. It is not a real-world Windows LoLa compatibility
claim.

Completed:

- static Windows LoLa corpus classification and dependency boundary review;
- source-level LoLa control-message parser/builder behavior;
- source-level synthetic packet fixture generation and passive decode paths;
- source-level media envelope handling for the corrected Linux-seed audio and
  video layout;
- explicit `tx-rx` connector planning and post-control media TX/RX wiring;
- release hygiene rules that keep private evidence and Windows binaries out of
  public candidates.

Missing:

- current Windows-originated audio/video media capture;
- byte-for-byte validation of control and media packet grammar against real
  Windows LoLa sessions;
- ASIO, WinPcap, XIMEA/PtGrey, packet-loss, reconnect, and 48 kHz runtime
  evidence;
- maintainer/legal/reviewer approval for any public release wording that
  mentions reverse-engineering-derived behavior.

## Repository Disposition

- Public, independently written source and sanitized protocol documentation may
  be tracked.
- Proprietary binaries, raw extraction output, captures, decompiler material,
  internal notes, environment details, and workflow records must not be tracked.
- Local evidence must be stored outside the repository or under an ignored
  local-only path.

## Publication Rule

Public docs may state sanitized implementation status, evidence classes, and
remaining validation gates. They must not link to private evidence as public
authority, quote raw extracted strings, publish proprietary binary-derived
tables, or imply real-world Windows interoperability before captured media
evidence exists.

Update this page only when a publication-safe validation gate closes or release
wording changes.

VERDICT: PARTIAL
