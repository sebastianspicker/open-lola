# LoLa 2.0 Legacy Compatibility Mode RE Base

This addendum turns the static v2.0 folder analysis into an implementable
base for a Windows Legacy Compatibility Mode. It is still static-only:
no Windows EXE, DLL, installer, or helper was executed.

## Current Verdict

- Legacy Compatibility Mode planning base: confirmed.
- Session/control grammar base: confirmed statically.
- Codec selection base: confirmed for PCM audio plus raw video/CPU MJPEG video.
- Media packet envelope base: observed/inferred from packet-builder xrefs.
- Byte-exact LoLa AV TX/RX compatibility: partial; requires isolated Windows peer captures.

`VERDICT: PARTIAL`

## Corpus Coverage

- Artifacts classified for compatibility scope: `29`
- Included or included-after-main artifacts: `12`
- Protocol-critical artifacts: `2`
- Codec/optional-codec artifacts: `4`
- Runtime-only artifacts intentionally excluded from protocol logic: `10`

## Compatibility Layers

| Layer | Static status | Implementation implication |
|---|---|---|
| L0 artifact/dependency map | confirmed | Every file has a compatibility tier and next validation step. |
| L1 session/control text grammar | confirmed | Implement `/MESG_*` parser and generator first. |
| L2 config/profile import | confirmed | Parse `LolaGui.ini` keys and shipped camera profile INI lines. |
| L3 media envelope | inferred | Implement parser/builder behind PCAP fixtures, not live network first. |
| L4 audio media | inferred | Start with PCM 16-bit frames, 64 samples/channel per packet hypothesis. |
| L5 video media | inferred | Support raw frame chunks and CPU MJPEG chunks; GPUJPEG remains optional/unproven. |
| L6 byte-exact peer interop | requires validation | Needs Windows LoLa peer, owned hardware or fixtures, and packet captures. |

## Files In This Addendum

- [compatibility-artifact-map.md](compatibility-artifact-map.md)
- [string-interest-triage.md](string-interest-triage.md)
- [exe-deep-summary.md](exe-deep-summary.md)
- [av-tx-rx-protocol-decoding.md](av-tx-rx-protocol-decoding.md)
- [codec-and-media-findings.md](codec-and-media-findings.md)
- [legacy-compatibility-roadmap.md](legacy-compatibility-roadmap.md)
- [definition-of-done-ledger.md](definition-of-done-ledger.md)
- [data/compatibility-artifacts.json](data/compatibility-artifacts.json)

## Safety Boundary

Network use is not needed for this static addendum. Licensing, DRM,
authentication, access-control bypass, and credential extraction are not
part of this compatibility base.
