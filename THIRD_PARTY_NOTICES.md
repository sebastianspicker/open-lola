# Third-Party Notices

Open LoLa's own code and documentation are licensed under the Apache License,
Version 2.0 (see [LICENSE](LICENSE) and [NOTICE](NOTICE)). The components below
keep their own licenses.

## Included in this repository

### Opus

- Location: `third_party/opus/`
- Version: 1.5.2
- Copyright: Xiph.Org, Skype Limited, Octasic, Jean-Marc Valin, Timothy B.
  Terriberry, CSIRO, Gregory Maxwell, Mark Borgerding, Erik de Castro Lopo,
  Mozilla, Amazon
- License: BSD 3-clause, see `third_party/opus/COPYING`
- Patents: see `third_party/opus/LICENSE_PLEASE_READ.txt` for the IETF patent
  declarations
- Use: compiled into the macOS package through the `COpus` target for the Opus
  CELT low-delay audio mode

Binary distributions must reproduce the copyright notice and disclaimer from
`COPYING`.

### JPEG XS reference software (ISO/IEC 21122-5, second edition)

- Location: `third_party/jpeg-xs/`
- Copyright: intoPIX SA, Fraunhofer IIS and Canon Inc.
- License: evaluation and conformance testing only, no patent licence; see
  `third_party/jpeg-xs/LICENSE.md`
- Use: compiled only when the package is resolved with
  `OPEN_LOLA_ENABLE_JPEG_XS=1`. The default build contains none of it.

Do not distribute binaries built with JPEG XS enabled. Using JPEG XS in a
product requires a separate licence from the copyright holders and the
relevant patent holders.

The bridge files `third_party/jpeg-xs/libjxs/public/open_lola_jxs_bridge.h` and
`third_party/jpeg-xs/libjxs/src/open_lola_jxs_bridge.c` are Open LoLa code
under Apache-2.0. They live in the vendored tree so they compile with it.

### Vendor Fence And Patch Policy

Upstream files in `third_party/` are kept unmodified. Open LoLa code inside
those trees is limited to `third_party/opus/openlola_bridge/**` and the two
JPEG XS bridge files above. `Package.swift` defines which files are compiled;
the release exporter keeps the compiled Opus sources, headers and upstream
notices and strips the other upstream extras listed in
`tools/release-boundary-policy.txt`. Any change to an upstream file needs a
recorded reason and an update to this file.

## Swift package dependencies

No external SwiftPM package dependencies. The macOS targets link Apple system
frameworks (AVFoundation, CoreAudio, CoreMedia, AppKit) from the SDK; no Apple
SDK files are included.

## Rust station dependencies

The Rust station (`runtimes/rust-station`, crate `rusty-lola`) depends on
crates from crates.io, pinned in `Cargo.lock`. They are downloaded at build
time and are not part of this repository. Their licenses are permissive: MIT,
Apache-2.0, BSD-2-Clause, BSD-3-Clause, ISC, Zlib, 0BSD, BSL-1.0, Unlicense and
Unicode-3.0. Where a crate offers a choice, the permissive option applies.

The optional egui interface embeds fonts from `epaint_default_fonts`, licensed
under the SIL Open Font License 1.1 and the Ubuntu Font Licence 1.0.

The crates are linked statically. A binary distribution must include each
crate's license text and copyright notice; generate that file from
`Cargo.lock` (for example with `cargo about`) for each release.

## Loaded at runtime, not included

The Rust station on Windows can load these libraries if the user has installed
them. Open LoLa does not include or redistribute them; their own licenses
apply.

| Library | Used for | License |
|---|---|---|
| PortAudio (with ASIO host API) | Audio I/O | MIT-style |
| Npcap | Diagnostic packet capture | Npcap License (proprietary; redistribution needs a licence from Nmap Software) |
| XIMEA xiAPI | XIMEA camera capture | XIMEA proprietary license |

Steinberg ASIO is a trademark of Steinberg Media Technologies GmbH. The ASIO
SDK is not included.

## Original LoLa

Open LoLa contains no code, binaries or documentation from the original LoLa
system. See [LEGAL.md](LEGAL.md).

## Trademarks

Product and standard names are used only to describe compatibility. No
affiliation or endorsement is implied.
