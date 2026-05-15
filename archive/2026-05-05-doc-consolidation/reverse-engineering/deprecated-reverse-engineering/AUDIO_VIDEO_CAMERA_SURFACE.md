# Reverse Engineering: Audio, Video, And Camera Surface

Back to index: [README.md](../README.md)

Scope: static hardware and media surface findings from
`../win-compiled/1-5` and `../win-compiled/2-0`.

## Audio Behavior

The main GUI uses PortAudio with ASIO-specific probing.

Static facts:

- `../win-compiled/2-0/LolaGui_XIMEA_x64.exe` imports PortAudio functions by
  ordinal from `portaudio_x64.dll`.
- The GUI directly imports the ASIO-specific ordinal mapped to
  `PaAsio_GetAvailableBufferSizes`.
- The bundled `portaudio_x64.dll` exports additional ASIO/WASAPI helpers, but
  the main GUI did not directly import ASIO channel-name helpers.
- No `Pa_ReadStream` or `Pa_WriteStream` imports were found in the main GUI.
- Ghidra caller clusters resolve PortAudio initialization/enumeration at
  `FUN_140007980`, ASIO buffer-size probing at `FUN_140009010`, and stream open
  at `FUN_1400093a0`.
- Focused audio Ghidra/objdump resolves local callback processing at
  `FUN_14000ad00`, audio send at `FUN_140009bf0`, audio receive/ring insertion
  in `FUN_1400152d0`, and audio/network settings load/save at `FUN_14002a6e0`
  and `FUN_140031d70`.

Relevant main-GUI PortAudio imports:

- `Pa_Initialize`
- `Pa_Terminate`
- `Pa_GetHostApiCount`
- `Pa_GetHostApiInfo`
- `Pa_HostApiDeviceIndexToDeviceIndex`
- `Pa_GetDeviceInfo`
- `Pa_OpenStream`
- `Pa_StartStream`
- `Pa_StopStream`
- `Pa_CloseStream`
- `Pa_IsStreamStopped`
- `Pa_IsStreamActive`
- `PaAsio_GetAvailableBufferSizes`

Observed settings and constraints:

- ASIO device selection.
- Input and output audio device names.
- Sample-rate setting and protocol field.
- Audio input offset.
- Audio output level.
- Suggested latency.
- Channel count between 2 and 10.
- Startup warning if the audio card buffer size is not 32 or 64 samples.
- Static recovered callback path uses 64-frame signed 16-bit PCM blocks.
- Default static settings include `socketport=7000`, `audioport=19788`,
  `videoport=19798`, `AudioTxFixedBuffer=1`, `WinPcap_SetMinToCopy=10`, and
  `RxPacketFiltering=1`.

Recording outputs:

- `_Local.wav`
- `_Remote.wav`
- v2.0 session format: `%s\%s_Local.wav`
- v2.0 session format: `%s\%s_Remote.wav`

Inference: the primary audio path is an ASIO-first callback workflow, not a
normal Windows conferencing or blocking PortAudio stream. See
[AUDIO_WORKFLOW_REVERSE_ENGINEERING.md](AUDIO_WORKFLOW_REVERSE_ENGINEERING.md)
for address-level details.

Runtime gap: 48 kHz support remains unresolved because static strings mention
48 kHz but the recovered stream-open path uses `44100.0`.

Audio evidence labels:

| Claim | Evidence label | Evidence |
|---|---|---|
| ASIO-first workflow | Static fact | Direct PortAudio imports plus Ghidra caller cluster for `PaAsio_GetAvailableBufferSizes`. |
| Callback mode, not blocking I/O | Static fact | `Pa_OpenStream` is imported/called; `Pa_ReadStream` and `Pa_WriteStream` are absent. |
| 64-frame int16 block | Strong inference | `Pa_OpenStream` path carries `0x40`; audio block byte count is `channelCount * 128`; sample format maps to `paInt16`. |
| Local processing | Static fact | Callback disassembly shows int16 capture/monitor gain scaling, ping-pong capture buffers, `WriteEvent`, remote ring copy/clear, and recording-ring memory copies. |
| TX/RX media transport | Static fact | Send path calls `pcap_sendpacket`; receive path calls `pcap_next_ex`; raw frame builder creates Ethernet/IPv4/UDP frames with LoLa payload at offset `0x2a`. |
| 48 kHz compatibility | Runtime gap | Strings/protocol mention sample rate and `48000`, but recovered open/WAV setup stays on `44100`. |

## Video And Camera Behavior

Corpus-level static facts:

- v1.5 ships 50 configuration/camera payloads across `CAMERAFILES`, including
  43 legacy binary `.kcxp`/`.anlg` camera payloads. v2.0 ships
  `CAMERAFILES/Ximea.ini`, `CAMERAFILES/PtGrey.ini`, and root
  `XimeaColors.ini`.
- v1.5 includes 36 Imperx `.kcxp` payloads and 7 analog `.anlg` payloads for
  legacy frame-grabber/analog camera profiles. Short embedded strings identify
  makers/models such as Imperx, Sony, Toshiba, Hitachi, and BitFlow.
- v2.0 `CAMERAFILES/Ximea.ini` expands from 28 nonblank v1.5 entries to 54
  nonblank entries, adding xiQ/XiC and generic XIMEA profiles up to
  2048x2048.
- `CAMERAFILES/PtGrey.ini` is byte-identical between v1.5 and v2.0 and lists
  FL3/GS3 USB3 Point Grey profiles, but the analyzed v2.0 XIMEA GUI still has
  no proven PtGrey/FlyCapture import surface.

Hardware/media/display matrix:

| Surface | Evidence label | Evidence | Interpretation |
|---|---|---|---|
| XIMEA capture | Static fact | v2.0 main imports `xiapi64.dll`; `FUN_14000fb40`, `FUN_14000efc0`, and `FUN_140012ec0` call XIMEA setup and `xiGetImage`. | Active camera path in the analyzed v2.0 GUI. |
| PtGrey files/UI | Runtime gap | `PtGrey.ini` is shipped unchanged in v1.5/v2.0 and lists FL3/GS3 USB3 profiles, but no PtGrey/FlyCapture import was visible in the v2.0 XIMEA GUI. | Treat as config/UI surface or another-build lineage until dynamic-load/runtime proof exists. |
| Camera files | Static fact | v2.0 ships expanded `CAMERAFILES/Ximea.ini`, unchanged `CAMERAFILES/PtGrey.ini`, and root `XimeaColors.ini`; v1.5 also ships legacy `.kcxp` and `.anlg` payloads. | v2.0 narrows the shipped camera-file surface toward XIMEA/PtGrey while adding XIMEA color defaults. |
| ROI/exposure/image format | Static fact | `FUN_14000fb40` references `exposure`, `imgdataformat`, `RGB24`, `width`, `height`, `offsetX`, and `offsetY`. | XIMEA setup programs frame format and centered ROI directly through driver parameters. |
| Bayer/color correction | Static fact | Strings, OpenCV `cvtColor`, `XimeaColors.ini`, `wb_kr`, `wb_kg`, `wb_kb`, `gammaY`, `gammaC`, and `bpc` xrefs. | Local/remote display and hardware color correction are explicit video-side concerns. |
| Local preview/display | Static fact | `FUN_140012c00` creates the camera preview surface; `FUN_14000efc0` calls XIMEA image fetch, OpenCV resize/drawing helpers, and display update. | Preview is a Windows display-surface path driven from XIMEA frames, not a generic webcam preview. |
| Remote display | Static fact | Receive cluster plus `FUN_140019c80`/`FUN_14001ac90` GDI/DIB caller clusters. | Remote frames are copied or decoded, then handed to GDI/DIB display surfaces. |
| Raw video | Static fact | `FUN_1400115c0`/`0x140011680` call the LoLa fragmenter, shared raw Ethernet/IP/UDP builder, and WinPcap send queues. | Raw video is the uncompressed send path. |
| MJPEG | Static fact | `FUN_140011c10` calls IJG/libjpeg compression before the same fragment/sendqueue path; `FUN_1400152d0` calls IJG/libjpeg decode. | v2.0 main-binary MJPEG is CPU IJG/libjpeg. |
| GPUJPEG | Static fact for v1.5 CUDA, runtime gap for v2.0 | v1.5 CUDA imports `gpujpeg.dll` and has encode/decode callers; v2.0 main does not import `gpujpeg.dll`. | GPUJPEG is proven active in v1.5 CUDA only unless v2.0 dynamic-load proof appears. |
| Recording/converter | Static fact | `FUN_1400107c0`, `FUN_1400161a0`, and `LolaVideoConverter_x64.exe` show `_Local_%07d.*`, `_Remote_%07d.*`, OpenCV `imwrite`, and IJG/libjpeg calls. | Recording/export is a side path separate from live capture/send/receive timing. |

The primary GUI imports XIMEA API functions:

- `xiGetNumberDevices`
- `xiOpenDevice`
- `xiCloseDevice`
- `xiStartAcquisition`
- `xiStopAcquisition`
- `xiGetImage`
- `xiGetParamInt`
- `xiGetParamFloat`
- `xiGetParamString`
- `xiSetParamInt`
- `xiSetParamFloat`

Observed camera workflows:

- XIMEA camera initialization.
- XIMEA API and driver version display.
- Camera file selection.
- Frame size and frame rate configuration.
- Exposure setting.
- Region of interest width/height and `offsetX` / `offsetY`.
- `RGB24` vs 8-bit image format handling.
- Bayer decoding.
- Software color correction.
- XIMEA hardware color correction through `XimeaColors.ini`.
- PtGrey hardware color-correction UI/config surface.
- Local camera preview / local preview in v2.0.

Ghidra caller evidence:

| Function | Static surface |
|---|---|
| `FUN_14000fb40` | XIMEA setup: `PathFileExistsA`, `xiOpenDevice`, `xiSetParamFloat`, `xiSetParamInt`, `xiGetParamInt`, `xiStartAcquisition`, `xiGetImage`, and `xiCloseDevice`. |
| `FUN_140012ec0` | Capture loop: `xiGetImage`, `xiGetParamInt`, frame/display counters, and local display update strings. |
| `FUN_14000efc0` | Preview/capture helper: `xiGetImage`, OpenCV `Mat`/resize/drawing helpers, and event reset. |

Observed image recording outputs:

- `_Local_%07d.bmp`
- `_Local_%07d.jpg`
- `_Remote_%07d.bmp`
- `_Remote_%07d.jpg`

Static fact: v2.0 imports XIMEA APIs but no PtGrey/FlyCapture SDK imports were
visible in the analyzed XIMEA GUI binary. Treat PtGrey as a shipped
configuration/UI surface or another-build feature until runtime evidence proves
this binary can drive PtGrey hardware.

## Image Processing Surface

The v2.0 main GUI imports:

- OpenCV 2.4.9 core/imgproc/highgui.
- IJG/libjpeg from `jpeg62.dll`.
- GDI/User32 display primitives.

Relevant OpenCV imports include `cv::Mat` helpers, `cv::cvtColor`,
`cv::resize`, drawing helpers, and `cv::imwrite`.

Relevant JPEG imports include:

- `jpeg_CreateCompress`
- `jpeg_mem_dest`
- `jpeg_set_quality`
- `jpeg_write_scanlines`
- `jpeg_CreateDecompress`
- `jpeg_mem_src`
- `jpeg_read_header`
- `jpeg_read_scanlines`

Static fact: CPU IJG/libjpeg is the proven live JPEG path in the v2.0 main
binary.

Static fact: `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe` imports
`gpujpeg.dll`, so GPUJPEG existed in the older CUDA branch.

Ghidra refresh: the v2.0 main binary resolves `FUN_140011c10` as the main
MJPEG send cluster because it combines IJG/libjpeg compression with WinPcap
send queues. The receive cluster `FUN_1400152d0` combines `pcap_next_ex` with
IJG/libjpeg decompression. The v1.5 CUDA binary, by contrast, resolves
`gpujpeg_*` callers in its encode/decode clusters, which is proof that GPUJPEG
was active in that branch.

Runtime gap: v2.0 still embeds GPUJPEG-related strings, but it does not import
`gpujpeg.dll` directly. Do not claim v2.0 main-binary GPU JPEG acceleration
without runtime or dynamic-load evidence.

## Display Surface

Static facts:

- v2.0 imports `CreateDIBSection`, `SetDIBColorTable`, `StretchBlt`,
  `CreateCompatibleDC`, `InvalidateRect`, and `UpdateWindow`.
- Ghidra resolves `FUN_140019c80` as the DIB creation cluster because it calls
  `CreateDIBSection`.
- Ghidra resolves `FUN_14001ac90` as the blit/palette cluster because it calls
  `CreateCompatibleDC`, `SetDIBColorTable`, `StretchBlt`, and MFC
  `CDC::SetStretchBltMode`.
- Display strings include `CDspSurf`, `Lola DSCreate: Cannot create a valid
  display surface`, `DSFormatBlit-Bayer:`, `DirectX`, `SIMD Acceleration`,
  `Bayer decoder supports 8 bit images only.`, and software color-correction
  labels for local and remote display.

Interpretation: the proven live display surface is a Windows GDI/DIB path with
Bayer/color-correction helpers. `DirectX` and `SIMD Acceleration` are visible
strings, but this pass did not prove a DirectX-rendered v2.0 video path.

## Camera Configuration Files

### v1.5

`../win-compiled/1-5/CAMERAFILES` includes many legacy camera files:

- XIMEA config list.
- PtGrey config list.
- Imperx CXP and ICX camera files.
- Hitachi analog camera files.
- Sony analog camera files.
- Toshiba analog camera files.
- Adimec camera register config.
- Imperx register config files.

The `.kcxp` and `.anlg` files contain camera metadata and BitFlow references.
Example strings include:

- `Imperx`
- `ICX-B1410C`
- `8 bit, 640x480, ExtTrig`
- `BitFlow`
- `Hitachi`
- `KP-FD30`
- `RGB, 1 FIELD, 640x480, Free Run`

### v2.0

`../win-compiled/2-0/CAMERAFILES` is reduced to:

- `Ximea.ini`
- `PtGrey.ini`

The v2.0 XIMEA list adds newer model and resolution coverage compared with
v1.5, including:

- `xiQ_MQ013CG_E2`
- `XiC_MC023CG_SY`
- generic XIMEA entries up to `2048x2048`

`../win-compiled/2-0/XimeaColors.ini` adds root-level XIMEA color-correction
defaults:

```ini
[Colors]
m_RedGain=68
m_GreenGain=64
m_BlueGain=130
m_GainAll=0
m_Luminosity=211
m_Chromaticity=204
m_BadPixelsCorrection=1
m_RawColorCorrection=1
```

The binary maps these values to XIMEA parameters such as `wb_kr`, `wb_kg`,
`wb_kb`, `gain`, `gammaY`, `gammaC`, and `bpc`.

## Recording Surface

Audio recording:

- Main GUI imports WinMM `mmioWrite` and related write-side APIs.
- It does not import `mmioRead`; reading/splitting WAVs is delegated to
  `LolaWavSplitter_x64.exe`.
- Local and remote recording rings are separate from the PortAudio callback's
  core send/receive path.

Video recording:

- Main GUI strings expose local and remote BMP/JPEG file sequences.
- Recording settings include `RecPref_RecordLocalVideo`,
  `RecPref_RecordRemoteVideo`, `RecPref_CompressLocalVideo`,
  `RecPref_CompressRemoteVideo`, and `RecPref_ColorBayerDecoding`.
- `LolaVideoConverter_x64.exe` is an offline post-processing utility, not the
  live network video path.

## Hardware Dependency Summary

| Surface | Static evidence | Runtime requirement |
|---|---|---|
| ASIO audio | PortAudio imports, `ASIO`, `PaAsio_GetAvailableBufferSizes`, 32/64 sample warning. | Real ASIO driver for latency and buffer-size behavior. |
| XIMEA camera | `xiapi64.dll` imports and XIMEA settings strings. | Real XIMEA device for capture timing and buffer ownership. |
| WinPcap | `wpcap.dll` imports, installer, `pcap_sendpacket`, `pcap_next_ex`, BPF filter strings, and default media ports. | Windows packet driver/NIC for live packet timing and capture. |
| GPUJPEG | v1.5 CUDA executable imports `gpujpeg.dll`. | CUDA-capable runtime only for the v1.5 CUDA branch unless v2.0 dynamic loading is later proven. |
| PtGrey | `PtGrey.ini` and UI strings, no visible SDK imports in v2.0 XIMEA GUI. | Runtime proof needed before claiming active support in this binary. |

## Confidence

High confidence:

- Main v2.0 GUI uses ASIO/PortAudio for audio and XIMEA API for camera capture.
- Main v2.0 GUI uses WinPcap for media packet send/receive.
- Main v2.0 GUI has CPU MJPEG and GDI/DIB display surfaces.
- Recording is side-path work rather than part of the audio callback.
- Local audio processing, TX packetization, RX ring insertion, and recording
  handoff are separated by static call/offset evidence.

Medium confidence:

- PtGrey support belongs to another build or a dormant UI/config path.
- GPUJPEG strings in v2.0 are legacy residue unless dynamic-load evidence is
  found.

Runtime gaps:

- Real ASIO device behavior.
- Real XIMEA capture timing and image buffer ownership.
- Real WinPcap/NIC timing.
- PtGrey reachability.
- GPUJPEG dynamic loading in v2.0, if any.
