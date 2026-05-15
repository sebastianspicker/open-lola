# SDK License Notes

Date: 2026-05-04
Status: SDK/API compliance notes, pending maintainer/legal approval
Source type: official public vendor pages checked 2026-05-04
Verdict: PARTIAL

## Boundary

These are engineering compliance notes, not legal advice. The binding terms are
the actual agreements accepted by the maintainer or institution.

## Apple SDKs

Official source:

- https://developer.apple.com/support/terms/

Apple lists the Apple Developer Program License Agreement, Apple Developer
Agreement, Xcode and Apple SDKs Agreement, App Store Connect terms, TestFlight
terms, and related agreements. Apple states that the English version accepted
in the developer account is the binding and most current version. The Apple
Developer Program License Agreement entry reviewed during M05 showed a
2026-03-12 last-update date.

open-lola action:

- record which Apple developer account and agreement state applies to release;
- keep use of `AVFoundation`, `CoreAudio`, and `CoreMedia` within public SDK
  APIs;
- do not include Apple SDK headers, samples, or documentation text in the repo;
- review distribution mode separately for CLI binaries, app bundles, Developer
  ID signing, notarization, and App Store if ever relevant.

## Blackmagic Desktop Video SDK

Official source:

- https://www.blackmagicdesign.com/developer/products/capture-and-playback/sdk-and-software

Blackmagic publishes Desktop Video SDK and DeckLink SDK manual downloads, and
the SDK download is registration-based. The page reviewed on 2026-05-04 listed
Desktop Video 16.0 SDK and SDK manual releases dated 2026-04-08.

open-lola action:

- do not commit Desktop Video SDK files unless redistribution is explicitly
  permitted and documented;
- keep Blackmagic support optional and buildable without the SDK;
- prefer AVFoundation/UVC capture paths where sufficient;
- if an SDK adapter is added, document SDK version, installed path assumption,
  license review, and notice obligations.

## RME Drivers And TotalMix

Official sources:

- https://docs.rme-audio.com/aoxm/711-1c_drivers_mac/
- https://www.rme-usa.com/downloads.html

RME documentation states that relevant hardware requires an installed macOS
driver and that drivers are downloaded from the official RME website. The
downloads page lists current drivers and TotalMix FX packages.

open-lola action:

- treat RME drivers and TotalMix as user-installed external software;
- do not vendor RME driver packages, apps, firmware tools, or manuals;
- record RME model, driver version, firmware, Core Audio UID, and TotalMix state
  in measured reports;
- keep source behavior based on Core Audio public APIs and user-provided
  metadata.

## Art-Net

Official source:

- https://art-net.org.uk/

The official Art-Net site says Art-Net is available royalty-free subject to
conditions, requires product/user-guide credit, and requires an OEM Code for
products implementing Art-Net.

open-lola action:

- do not mark Art-Net output release-ready until credit and OEM-code
  disposition are recorded;
- include required credit in product docs if Art-Net is implemented;
- keep Art-Net behind explicit lighting safety gates and isolated-network
  tests.

## Dante And Proprietary AoIP

Official source:

- https://www.audinate.com/legal/software-licensing/

Audinate documents proprietary and open-source components for Dante software
and states that proprietary components are covered by relevant Audinate license
terms.

open-lola action:

- do not integrate Dante SDKs without maintainer/legal review;
- document whether the path uses user-installed Dante Virtual Soundcard,
  licensed SDK/API integration, or no Dante dependency;
- do not publish activation/license behavior or embed credentials.

## Standards And Protocols

For sACN/E1.31, DMX/RDM/RDMnet, AVB/TSN, AES67, RAVENNA, ST 2110, OSC, and
other standards:

- identify the current standard version;
- record access/license terms;
- cite public standards, not internal vendor behavior;
- keep implementation tests original and fixture provenance clear.

M05 note: standards stores reviewed during M05 list ANSI E1.31:2025 as the
current sACN/E1.31 edition, replacing older E1.31 versions. Do not implement or
claim sACN release readiness from stale notes; record the authorized standards
copy and terms before source work or public claims.

## Resume here

Before implementing any optional SDK adapter, add a row to
[notices-attribution-register.md](notices-attribution-register.md) and update
[risk-register.md](risk-register.md).

VERDICT: PARTIAL
