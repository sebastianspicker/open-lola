# Codec And Media Findings

## Audio Codec

| Finding | Classification | Compatibility decision |
|---|---|---|
| Audio uses PortAudio/ASIO and negotiates `SR`, `BPS`, and `CHNLS`. | confirmed | Implement an internal PCM stream model keyed by sample rate, bits per sample, and channels. |
| Audio packet payload size is `channels * 128`. | inferred | Start with 64 samples/channel/packet for 16-bit PCM. |
| WAV recording helpers exist. | confirmed | Use WAV fixtures to validate sample interpretation, not network timing. |
| ASIO buffers must be 32 or 64 samples. | observed | Build low-latency buffering around small fixed audio quanta. |

The compatibility-mode starting point should be signed 16-bit PCM in Windows
little-endian order. That is a hypothesis until packet captures prove the wire
order, but it is the most coherent assumption from `BPS`, PortAudio, Windows,
and WAV evidence.

## Video Codecs

| Codec path | Classification | Evidence | Compatibility decision |
|---|---|---|---|
| Raw/uncompressed video | inferred | Raw TX function `FUN_1400115c0`, `BPP`, `X`, `Y`, `BAYER`, camera profiles. | Implement after packet fragment header is mapped. |
| CPU MJPEG | confirmed | `jpeg62.dll`, `jpeg_CreateCompress`, `jpeg_mem_dest`, `jpeg_write_scanlines`, `jpeg_CreateDecompress`, `jpeg_mem_src`, `jpeg_read_scanlines`. | Implement first compressed-video path. |
| GPUJPEG/CUDA | observed/unproven | `gpujpeg.dll` and `cudart64_55.dll` are present, but the main GUI does not statically import them. | Keep optional; do not block LCM v1 on GPUJPEG. |

## Camera And Pixel Formats

Confirmed profile evidence:

- XIMEA profiles include Mono8 and RGB24 at 60 FPS across xiQ/XiC/generic modes.
- PtGrey profiles include Mono8 and RGB24, many at 120 FPS, but the v2.0 XIMEA GUI does not statically link a PtGrey SDK.
- Quick-connect format fields carry `FPS`, `BPP`, `X`, `Y`, `COMP`, and `BAYER`.
- XIMEA setup touches `imgdataformat`, `RGB24`, `width`, `height`, `offsetX`, `offsetY`, `auto_wb`, `wb_kr`, `wb_kg`, `wb_kb`, `gammaY`, and `gammaC`.

Compatibility decision: treat camera hardware as an adapter behind a LoLa
frame model. The wire/profile parser should not depend on XIMEA-specific APIs,
but it must preserve all negotiated fields.

## Codec Implementation Order

1. Session `COMP` field parser with explicit enum names only after capture confirms values.
2. PCM audio frame abstraction and packet fixture parser.
3. CPU MJPEG decode/encode using a standard JPEG library.
4. Raw video chunk parser once frame/fragment header fields are recovered.
5. GPUJPEG bridge only if dynamic-load or capture evidence proves LoLa v2.0 uses it.
