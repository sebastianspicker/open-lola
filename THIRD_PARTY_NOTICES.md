# Third-Party Notices And Attribution

Date: 2026-10-20
Status: active notice inventory; redistribution review remains open
Verdict: PARTIAL

First-party Open LoLa source code and documentation are licensed under the
Apache License, Version 2.0 in `LICENSE`. The distribution attribution and
educational-project statement are in `NOTICE`; the original LoLa licensing and
independent-project boundary are reviewed in `LEGAL.md`.

This inventory does not replace any component's license. Current release
readiness remains `PARTIAL`: the exact third-party notice packet, JPEG XS
distribution decision, fixture provenance, reviewer signoff, and public release
approval remain blocking.

Maintainer decision required: finalize this notice file against the selected
release allowlist, fixture provenance, JPEG XS disposition, and reviewer
signoff before publication.

## Current Package Inventory

`Package.swift` currently declares no external SwiftPM package dependencies.
The source tree vendors the ISO/IEC 21122-5 JPEG XS reference software under
`third_party/jpeg-xs/` for evaluation/testing integration. It is evaluation-only
and is not part of the default build: the `CJpegXSReference` target is compiled
only when the package is resolved with `OPEN_LOLA_ENABLE_JPEG_XS=1`. The SwiftPM
targets link Apple platform frameworks:

- `AVFoundation`
- `CoreAudio`
- `CoreMedia`

No external SwiftPM package dependencies are currently part of the release
notice scope.

The release-hygiene gate keeps this draft aligned with the package manifest:

```bash
bash tools/verify-release-hygiene.sh
```

## Current Release Notice Scope

| Content class | Current state | Notice posture |
|---|---|---|
| Project source and tests | Project-authored SwiftPM source, focused tests, and scripts. | Apache-2.0, except separately identified third-party material. |
| Project documentation | Curated public docs and compliance governance docs. | Apache-2.0, except separately identified third-party material. |
| Generated build outputs | `.build/**`, `.swiftpm/**`, packages, app bundles, archives. | Excluded from source release. |

## Notice Table

| Item | Current repo use | Redistribution posture | Notice action |
|---|---|---|---|
| Apple Core Audio | Linked Apple framework via public SDK API. | Do not redistribute Apple SDK files. Distribution must follow the accepted Apple developer agreements. | Keep SDK note; no copied Apple docs. |
| Apple AVFoundation/CoreMedia | Linked Apple frameworks via public SDK APIs. | Do not redistribute Apple SDK files. Distribution must follow the accepted Apple developer agreements. | Keep SDK note; no copied Apple docs. |
| Swift toolchain/runtime | Build toolchain only; no vendored Swift toolchain files. | Review binary distribution form separately. | Note Swift toolchain license if distributing binaries with embedded runtime pieces. |
| Opus 1.5.2 reference implementation | Vendored C codec under `third_party/opus/` and linked through the `COpus` SwiftPM target for opt-in Direct AV Opus CELT restricted low-delay audio. | Keep the upstream BSD-style copyright notice and disclaimer from `third_party/opus/COPYING` and the patent references in `third_party/opus/LICENSE_PLEASE_READ.txt`; Opus patent/license posture still needs release review before product distribution. | Include both Opus notices and patent review in the final release packet. |
| ISO/IEC 21122-5 JPEG XS reference software, second edition | Vendored C reference codec under `third_party/jpeg-xs/` and linked through the `CJpegXSReference` SwiftPM target, which is built only when `OPEN_LOLA_ENABLE_JPEG_XS=1` is set at package resolution (off by default). | The bundled license grants copyright use for evaluation/testing and conformance work only; it grants no patent license. Binaries built with JPEG XS enabled must not be distributed; distribution or production/commercial use requires separate legal review. The default build contains none of this code. | Keep `third_party/jpeg-xs/LICENSE.md`; do not mark JPEG XS as production-cleared. |
| Blackmagic Desktop Video SDK / DeckLink SDK | Optional future adapter; not vendored and not required for default build. | Do not commit or redistribute SDK headers, libraries, samples, installers, or manuals unless terms permit. | Add adapter-specific notice only if SDK-backed code lands. |
| RME drivers and TotalMix FX | User-installed external driver/software for measured hardware runs. | Do not redistribute driver packages, apps, firmware tools, or manuals. | Document user prerequisite and measured driver/version fields. |
| Art-Net | Source-level safety and report models; no physical bridge or fixture claim. | No release-ready product claim until credit and OEM-code disposition are recorded. | Complete attribution review before enabling a distributable implementation. |
| sACN / ANSI E1.31 | Source-level safety and report models; no physical bridge or fixture claim. | Any distributable implementation requires an authorized standards basis and recorded version/terms. | Complete standards and attribution review before enabling a distributable implementation. |
| Dante / Audinate | Optional AoIP lane; no SDK integrated. | No SDK or activation integration without license review. | Add only for the actual licensed integration used. |
| PortAudio | Loaded at runtime by the Rust station on Windows if the user has installed a PortAudio DLL (with the ASIO host API) in a fixed trusted directory. Not vendored, linked at build time, or shipped. | MIT-style license (PortAudio). Not redistributed by this project. | Users obtain PortAudio from its upstream project and follow its license. |
| Npcap | Loaded at runtime by the Rust station on Windows for diagnostic packet capture if the user has installed Npcap. Not vendored or shipped. | Proprietary; free for limited use under the Npcap license, and redistribution needs a separate license from its owner. Not redistributed by this project. | Users install Npcap themselves and accept its license. |
| XIMEA API (xiAPI) | Loaded at runtime by the Rust station on Windows if the user has installed the XIMEA software package. Not vendored or shipped. | Proprietary XIMEA license. Not redistributed by this project. | Users install the XIMEA API themselves and accept its license. |
| Windows LoLa corpus and bundled vendor binaries | Not version-controlled; any lawfully held evidence remains outside the repository. | Excluded from public release unless rights are documented. | Do not list as redistributable third-party content. |
| Synthetic test fixtures | Local tests and validation fixtures. | Include only after provenance confirmation. | Link fixture provenance in release packet. |

## Vendor Fence And Patch Policy

Vendored codec/reference trees are third-party lanes. `Package.swift` is the
compiled-subset authority for `COpus` and `CJpegXSReference`; the release
exporter retains only the selected Opus C files, headers, and required upstream
notices. The exporter and `tools/release-boundary-policy.txt` define the other
upstream extras stripped from staged candidates.

Open-lola-local vendor code is limited to
`third_party/opus/openlola_bridge/**` and the JPEG XS bridge
`third_party/jpeg-xs/libjxs/public/open_lola_jxs_bridge.h` and
`third_party/jpeg-xs/libjxs/src/open_lola_jxs_bridge.c`. The JPEG XS bridge is
first-party Apache-2.0 code that lives inside the vendored tree only so that it
compiles into the `CJpegXSReference` target; it is built only with
`OPEN_LOLA_ENABLE_JPEG_XS=1`, like the rest of that tree. Any future edit to upstream Opus or
JPEG XS files outside that bridge boundary requires maintainer/legal review,
origin or patch rationale, and this notice table to be refreshed before
publication.

## Rust Station Cargo Dependencies

The Rust station (`runtimes/rust-station`, crate `rusty-lola`, Apache-2.0)
resolves 438 external crates from crates.io in the root `Cargo.lock`. The
crates are linked statically into the station binary, so their license terms
apply to any binary distribution; each crate's own license text and copyright
notice must be included in a distributed binary packet.

The inventory below was generated from `Cargo.lock` and the `license` field of
each crate's `Cargo.toml` in the local Cargo registry cache. License
expressions are shown as the crates declare them; for `OR` expressions this
project relies on the permissive alternative. `cargo metadata --offline` cannot
resolve the full graph without network access, so coverage is partial:

- 356 of 438 crates are listed below with their declared license.
- 82 crates are platform-specific (Linux/Wayland/X11, Android, Redox, wasm, and
  extra Windows targets) and are not in the local cache, so their licenses are
  not recorded here: `accesskit_atspi_common`, `accesskit_consumer 0.36.0`,
  `accesskit_unix`, `android-activity`, `android-properties`, `arrayref`,
  `as-raw-xcb-connection`, `async-channel`, `async-executor`, `async-io`,
  `async-lock`, `async-process`, `async-signal`, `async-task`, `atspi`,
  `atspi-common`, `atspi-proxies`, `blocking`, `calloop` (0.13.0 and 0.14.4),
  `calloop-wayland-source` (0.3.0 and 0.4.1), `concurrent-queue`,
  `glutin_glx_sys`, `hermit-abi`, `jni`, `jni-macros`, `libredox`,
  `linux-raw-sys 0.4.15`, `ndk-context`, `objc2-cloud-kit`, `objc2-contacts`,
  `objc2-core-location`, `objc2-link-presentation`, `objc2-symbols`,
  `objc2-ui-kit 0.2.2`, `objc2-uniform-type-identifiers`,
  `objc2-user-notifications`, `orbclient`, `pin-project`,
  `pin-project-internal`, `piper`, `plain`, `polling`, `redox_syscall` (0.4.1
  and 0.9.2), `rustix 0.38.44`, `scoped-tls`, `sctk-adwaita`, `simd_cesu8`,
  `simdutf8`, `siphasher`, `slotmap`, `smithay-client-toolkit` (0.19.2 and
  0.20.0), `smithay-clipboard`, `strict-num`, `tiny-skia`, `tiny-skia-path`,
  `wasm-bindgen-futures`, `wayland-backend`, `wayland-csd-frame`,
  `wayland-cursor`, `wayland-protocols-experimental`,
  `wayland-protocols-misc`, `wayland-protocols-plasma`, `web-sys`,
  `wgpu-core-deps-emscripten`, `wgpu-core-deps-wasm`, the seven `windows_*`
  0.53.1 target crates other than `windows_x86_64_msvc 0.53.1` (listed below),
  `xcursor`, `xkbcommon-dl`, `xkeysym`, `zbus-lockstep`,
  `zbus-lockstep-macros`, and `zbus_xml`. Regenerate this inventory with
  network access (`cargo metadata --format-version 1`) before any binary
  release.

#### MIT OR Apache-2.0 (192)

accesskit 0.24.1, accesskit_consumer 0.35.0, accesskit_consumer 0.38.0, accesskit_macos 0.26.3, accesskit_windows 0.32.1, ahash 0.8.12, allocator-api2 0.2.21, android_system_properties 0.1.6, anstream 1.0.0, anstyle 1.0.14, anstyle-parse 1.0.0, anstyle-query 1.1.5, anstyle-wincon 3.0.11, arboard 3.6.1, arrayvec 0.7.8, ash 0.38.0+1.3.281, async-broadcast 0.7.2, async-recursion 1.1.1, async-trait 0.1.92, bitflags 1.3.2, bitflags 2.13.1, bumpalo 3.20.3, cc 1.4.2, cfg-if 1.0.4, cgl 0.3.2, clap 4.6.7, clap_builder 4.6.7, clap_derive 4.6.7, clap_lex 1.1.0, colorchoice 1.0.5, core-foundation 0.9.4, core-foundation-sys 0.8.7, core-graphics 0.23.2, core-graphics-types 0.1.3, crc32fast 1.5.0, crossbeam-utils 0.8.22, displaydoc 0.2.7, document-features 0.2.12, downcast-rs 1.2.1, ecolor 0.36.2, eframe 0.36.2, egui 0.36.2, egui-wgpu 0.36.2, egui-winit 0.36.2, egui_glow 0.36.2, either 1.18.0, emath 0.36.2, enumflags2 0.7.12, enumflags2_derive 0.7.12, epaint 0.36.2, errno 0.3.14, euclid 0.22.14, fdeflate 0.3.7, find-msvc-tools 0.1.10, flate2 1.1.9, font-types 0.12.6, foreign-types 0.5.0, foreign-types-macros 0.2.4, foreign-types-shared 0.3.1, form_urlencoded 1.2.2, futures-core 0.3.34, futures-io 0.3.33, futures-macro 0.3.33, futures-task 0.3.34, futures-util 0.3.33, getrandom 0.3.4, getrandom 0.4.3, gpu-allocator 0.28.0, guillotiere 0.7.0, half 2.7.1, hashbrown 0.16.1, hashbrown 0.17.1, heck 0.5.0, hex 0.4.3, idna 1.1.0, image 0.25.10, is_terminal_polyfill 1.70.2, itertools 0.15.0, itoa 1.0.18, jni-sys 0.3.1, jni-sys 0.4.1, jni-sys-macros 0.4.1, jobserver 0.1.35, js-sys 0.3.104, khronos-egl 6.0.0, libc 0.2.189, litrs 1.0.0, lock_api 0.4.14, log 0.4.33, memmap2 0.9.11, naga 30.0.1, naga-types 30.0.1, ndk 0.9.0, ndk-sys 0.6.0+11769913, num-traits 0.2.19, once_cell 1.21.4, once_cell_polyfill 1.70.2, ordered-stream 0.2.0, parking_lot 0.12.5, parking_lot_core 0.9.12, percent-encoding 2.3.2, pkg-config 0.3.33, png 0.18.1, polycool 0.4.0, presser 0.3.1, proc-macro-crate 3.5.0, proc-macro2 1.0.107, profiling 1.0.18, quick-error 2.0.1, quote 1.0.47, range-alloc 0.1.5, raw-window-metal 1.1.0, read-fonts 0.41.0, regex 1.13.1, regex-automata 0.4.18, regex-syntax 0.8.11, renderdoc-sys 1.1.0, rustc_version 0.4.1, rustversion 1.0.23, scopeguard 1.2.0, semver 1.0.28, serde 1.0.229, serde_core 1.0.229, serde_derive 1.0.229, serde_json 1.0.151, serde_repr 0.1.21, shlex 2.0.1, signal-hook-registry 1.4.8, skrifa 0.44.0, smallvec 1.15.2, smol_str 0.2.2, socket2 0.6.5, stable_deref_trait 1.2.1, static_assertions 1.1.0, syn 2.0.119, syn 3.0.3, tempfile 3.27.0, thiserror 1.0.69, thiserror 2.0.21, thiserror-impl 1.0.69, thiserror-impl 2.0.21, toml_datetime 1.1.1+spec-1.1.0, toml_edit 0.25.13+spec-1.1.0, toml_parser 1.1.3+spec-1.1.0, ttf-parser 0.25.1, type-map 0.5.1, unicode-segmentation 1.13.3, unicode-width 0.1.14, url 2.5.8, version_check 0.9.5, wasm-bindgen 0.2.127, wasm-bindgen-macro 0.2.127, wasm-bindgen-macro-support 0.2.127, wasm-bindgen-shared 0.2.127, web-time 1.1.0, webbrowser 1.2.4, weezl 0.1.12, wgpu 30.0.1, wgpu-core 30.0.1, wgpu-core-deps-apple 30.0.1, wgpu-core-deps-windows-linux-android 30.0.1, wgpu-hal 30.0.0, wgpu-naga-bridge 30.0.1, wgpu-types 30.0.1, windows 0.62.2, windows-collections 0.3.2, windows-core 0.62.2, windows-future 0.3.2, windows-implement 0.60.2, windows-interface 0.59.3, windows-link 0.2.1, windows-numerics 0.3.1, windows-result 0.4.1, windows-strings 0.5.1, windows-sys 0.52.0, windows-sys 0.59.0, windows-sys 0.60.2, windows-sys 0.61.2, windows-targets 0.52.6, windows-targets 0.53.5, windows-threading 0.2.1, windows_aarch64_gnullvm 0.52.6, windows_aarch64_msvc 0.52.6, windows_i686_gnu 0.52.6, windows_i686_gnullvm 0.52.6, windows_i686_msvc 0.52.6, windows_x86_64_gnu 0.52.6, windows_x86_64_gnullvm 0.52.6, windows_x86_64_msvc 0.52.6, windows_x86_64_msvc 0.53.1, x11rb 0.13.2, x11rb-protocol 0.13.2

#### MIT (57)

block2 0.5.1, block2 0.6.2, bytes 1.12.1, cfg_aliases 0.2.2, combine 4.6.7, crunchy 0.2.4, dispatch 0.2.0, dlib 0.5.3, endi 1.1.1, fax 0.2.7, glutin-winit 0.5.0, harfrust 0.12.0, libm 0.2.16, memoffset 0.9.1, objc-sys 0.3.5, objc2 0.5.2, objc2 0.6.4, objc2-app-kit 0.2.2, objc2-core-data 0.2.2, objc2-core-image 0.2.2, objc2-encode 4.1.0, objc2-foundation 0.2.2, objc2-foundation 0.3.2, objc2-metal 0.2.2, objc2-quartz-core 0.2.2, ordered-float 4.6.0, phf 0.13.1, phf_generator 0.13.1, phf_macros 0.13.1, phf_shared 0.13.1, quick-xml 0.41.0, redox_syscall 0.5.18, simd-adler32 0.3.10, slab 0.4.12, strsim 0.11.1, synstructure 0.13.2, tiff 0.11.3, tracing 0.1.44, tracing-attributes 0.1.31, tracing-core 0.1.36, uds_windows 1.2.1, wayland-client 0.31.15, wayland-protocols 0.32.13, wayland-protocols-wlr 0.3.12, wayland-scanner 0.31.11, wayland-sys 0.31.11, winnow 1.0.4, x11-dl 2.21.0, xml-rs 0.8.29, zbus 5.19.0, zbus_macros 5.19.0, zbus_names 4.3.4, zcheapstr 1.1.0, zmij 1.0.23, zvariant 5.15.0, zvariant_derive 5.15.0, zvariant_utils 4.2.0

#### Apache-2.0 OR MIT (30)

atomic-waker 1.1.2, autocfg 1.5.1, bit-set 0.10.0, bit-vec 0.9.1, color 0.3.3, equivalent 1.0.2, event-listener 5.4.2, event-listener-strategy 0.5.4, fastrand 2.5.0, fearless_simd 0.4.1, futures-lite 2.6.1, glifo 0.2.0, idna_adapter 1.2.2, indexmap 2.14.0, kurbo 0.13.1, linebender_resource_handle 0.1.1, nohash-hasher 0.2.0, parking 2.2.1, peniko 0.6.1, pin-project-lite 0.2.17, pollster 1.0.1, portable-atomic 1.15.0, portable-atomic-util 0.2.8, rustc-hash 1.1.0, rustc-hash 2.1.3, utf8_iter 1.0.4, utf8parse 0.2.2, uuid 1.27.0, vello_common 0.1.0, vello_cpu 0.1.0

#### Unicode-3.0 (18)

icu_collections 2.2.0, icu_locale_core 2.2.0, icu_normalizer 2.2.0, icu_normalizer_data 2.2.0, icu_properties 2.2.0, icu_properties_data 2.2.0, icu_provider 2.2.0, litemap 0.8.2, potential_utf 0.1.5, tinystr 0.8.3, writeable 0.6.3, yoke 0.8.3, yoke-derive 0.8.2, zerofrom 0.1.8, zerofrom-derive 0.1.7, zerotrie 0.2.4, zerovec 0.11.6, zerovec-derive 0.11.3

#### Apache-2.0 (14)

ab_glyph 0.2.32, ab_glyph_rasterizer 0.1.10, accesskit_winit 0.32.2, codespan-reporting 0.13.1, gethostname 1.1.0, gl_generator 0.14.0, glutin 0.32.3, glutin_egl_sys 0.7.1, glutin_wgl_sys 0.6.1, khronos_api 3.1.0, owned_ttf_parser 0.25.1, spirv 0.4.0+sdk-1.4.341.0, unicode-general-category 1.1.0, winit 0.30.13

#### Zlib OR Apache-2.0 OR MIT (10)

bytemuck 1.25.2, bytemuck_derive 1.12.0, dispatch2 0.3.1, objc2-app-kit 0.3.2, objc2-core-foundation 0.3.2, objc2-core-graphics 0.3.2, objc2-io-surface 0.3.2, objc2-metal 0.3.2, objc2-quartz-core 0.3.2, objc2-ui-kit 0.3.2

#### Unlicense OR MIT (7)

aho-corasick 1.1.5, byteorder-lite 0.1.0, memchr 2.8.3, same-file 1.0.6, termcolor 1.4.1, walkdir 2.5.0, winapi-util 0.1.11

#### MIT OR Apache-2.0 OR Zlib (5)

cursor-icon 1.2.0, glow 0.17.0, raw-window-handle 0.6.2, zune-core 0.5.3, zune-jpeg 0.5.15

#### Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT (4)

linux-raw-sys 0.12.1, rustix 1.1.4, wasip2 1.0.4+wasi-0.2.12, wit-bindgen 0.57.1

#### BSD-2-Clause OR Apache-2.0 OR MIT (2)

zerocopy 0.8.56, zerocopy-derive 0.8.56

#### BSD-3-Clause OR Apache-2.0 (2)

moxcms 0.8.1, pxfm 0.1.30

#### BSD-3-Clause OR MIT OR Apache-2.0 (2)

num_enum 0.7.6, num_enum_derive 0.7.6

#### BSL-1.0 (2)

clipboard-win 5.4.1, error-code 3.3.2

#### ISC (2)

libloading 0.8.9, libloading 0.9.0

#### MIT OR Apache-2.0 OR LGPL-2.1-or-later (2)

r-efi 5.3.0, r-efi 6.0.0

#### (MIT OR Apache-2.0) AND OFL-1.1 AND Ubuntu-font-1.0 (1)

epaint_default_fonts 0.36.2

#### (MIT OR Apache-2.0) AND Unicode-3.0 (1)

unicode-ident 1.0.24

#### 0BSD OR MIT OR Apache-2.0 (1)

adler2 2.0.1

#### Apache-2.0 AND MIT (1)

dpi 0.1.2

#### Apache-2.0 OR GPL-2.0-only (1)

self_cell 1.3.0

#### MIT OR Zlib OR Apache-2.0 (1)

miniz_oxide 0.8.9

#### Zlib (1)

foldhash 0.2.0

## Trademark And Naming Posture

Vendor and standards names in this repository are used for factual compatibility,
hardware-target, or standards-reference discussion. No endorsement or affiliation
is implied. Any product-facing copy should receive a separate trademark and
attribution review before publication.

## Excluded From Public Release By Default

- `archive/**`
- `private/**`
- `reverse-engineering/**` if the old top-level tree is restored
- vendor SDK files or installers
- raw packet captures, media captures, screenshots, private endpoints, venue
  data, secrets, credentials, and unclear sample data
- unsanitized or unapproved runtime reports and evidence bundles

## Open Items

- Fixture provenance is not confirmed for public release.
- Apple developer agreement state is not recorded for the release account.
- Blackmagic SDK, Art-Net OEM code, sACN/E1.31 version, and Dante scope remain
  reviewer-gated.
- Trademark and product-facing attribution review is not complete.

See `docs/RELEASING.md` for the source-candidate boundary and approval
procedure. Local review packets and planning notes are not version-controlled
release inputs.

VERDICT: PARTIAL
