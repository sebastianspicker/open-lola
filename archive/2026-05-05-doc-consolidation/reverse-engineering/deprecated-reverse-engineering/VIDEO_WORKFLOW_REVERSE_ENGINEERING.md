# Windows Video E2E Reverse Engineering

This document reconstructs the Windows LoLa video workflow from the compiled
artifacts in `../win-compiled/`. It is a static reverse-engineering report, not
a source-level design document.

## Scope

Reference binary:

- `../win-compiled/2-0/LolaGui_XIMEA_x64.exe`

Compared artifacts:

- `../win-compiled/1-5/LolaGui_XIMEA_x64.exe`
- `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe`
- `../win-compiled/2-0/LolaVideoConverter_x64.exe`
- `../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe`
- `../win-compiled/2-0/CAMERAFILES/*.ini`
- `../win-compiled/2-0/XimeaColors.ini`

Corpus cross-link: see
[CORPUS_ORIGINS_AND_INTEGRATION.md](CORPUS_ORIGINS_AND_INTEGRATION.md) for the
package-wide proof that the video converter is an unchanged offline helper,
that v1.5 carries the legacy camera payload corpus, and that v2.0 narrows the
shipped camera surface around XIMEA/PtGrey configuration.

Limits:

- No PDB symbols were present.
- No camera hardware, network peer, or packet capture was available in this
  pass.
- Function names below are inferred from imports, strings, call shape, and data
  flow unless the name is an imported API.
- Field offsets are object-layout offsets inferred from the binary. They are
  useful for mapping the compiled workflow but should not be treated as stable
  source ABI.

Evidence labels used below:

- Static fact: directly visible in imports, strings, PE metadata, disassembly,
  or Ghidra caller/decompiler output.
- Strong inference: multiple static facts point to the workflow, but exact
  source names or user-facing enum labels are unavailable.
- Medium inference: the static evidence is real, but branch coverage or field
  meaning is not fully pinned down.
- Runtime gap: requires Windows execution, XIMEA/PtGrey hardware, a LoLa peer,
  or packet capture.

## Core Finding

The Windows video path is a threaded camera/network/display pipeline built for
low latency, but it is not the same kind of hard realtime path as audio.

Video frames are captured from XIMEA hardware through `xiapi64.dll`, placed into
a 30-slot local frame ring, optionally color corrected or Bayer decoded,
optionally JPEG compressed, serialized into LoLa video frames, fragmented into
custom LoLa subframes, and sent as raw Ethernet/IP/UDP packets through WinPcap.

On receive, UDP packets are parsed from WinPcap, LoLa fragments are reassembled,
the serialized video frame is decoded, optional JPEG decompression runs through
IJG/libjpeg, and the resulting image is placed into a remote frame buffer for
GDI/DIB display and optional recording.

Important consequence for the Mac port: video can be rebuilt as a pragmatic
low-latency capture, packetize, decode, display path. It must not contaminate
the audio path with video-style blocking waits, JPEG work, display work, or
recording work. Audio remains the latency gate.

## Ghidra Refresh Summary

Ghidra 12.0.4 headless was run on the v2.0 main GUI, the v1.5 main GUI, the
v1.5 CUDA GUI, and the tester. The generated projects stayed under
`/private/tmp` and were deleted after import. Ghidra did not have PDBs or
Windows system DLL bodies, but bundled library exports were resolved well enough
to map caller clusters.

A focused video pass then ran `/private/tmp/lola-ghidra-scripts/LoLaVideoDeepDive.java`
against the v2.0 main GUI, v1.5 CUDA GUI, v2.0 video converter, and v2.0
tester. Its concise outputs stayed under `/private/tmp/lola-ghidra-output`.
This second pass sharpened the video map rather than changing the high-level
model:

- Static fact: `FUN_1400070b0` is called by audio send, raw video send, and
  MJPEG send; its decompiler output contains `0x21` header arithmetic and the
  `0xeeeeeeee` marker write.
- Static fact: `FUN_140020ba0` is called by audio send plus both v2.0 video
  send paths; its decompiler output contains `0x1337`, packet payload offset
  `0x2a`, and header offset `0x1e`.
- Static fact: `FUN_140012c00` constructs the camera preview/display side and
  references `CBFVideoServer Class`, `Couldn't create camera preview surface`,
  and `Camera Preview`.
- Static fact: `FUN_14000efc0` is a preview/helper loop that calls
  `xiGetImage`, OpenCV resize/drawing helpers, display update
  `FUN_1400190f0`, and event reset/signaling APIs.
- Static fact: `FUN_140012ec0` is the main XIMEA capture loop; it advances the
  local frame-ring index modulo `0x1e` and calls `xiGetImage(..., 1000, ...)`.
- Static fact: `FUN_1400115c0` and the inner address `0x140011680` share the
  raw-video send function body, call the LoLa fragmenter and raw packet
  builder, and use WinPcap send queues.
- Static fact: `FUN_140011c10` adds IJG/libjpeg compression before the same
  fragmenter, packet builder, and WinPcap sendqueue path.
- Static fact: `FUN_1400152d0` calls `pcap_next_ex`, the reassembly helpers,
  IJG/libjpeg decompression, and display/recording event signaling paths.
- Static fact: `FUN_1400107c0` and `FUN_1400161a0` are local/remote recording
  side paths with `_Local_%07d.*`, `_Remote_%07d.*`, OpenCV `imwrite`, and
  IJG/libjpeg compression evidence.
- Static fact: the v2.0 main GUI imports `xiapi64.dll`, `jpeg62.dll`, OpenCV,
  and `wpcap.dll`, but not `gpujpeg.dll`; the v1.5 CUDA GUI imports
  `gpujpeg.dll` and has GPUJPEG encode/decode caller clusters.
- Static fact: `LolaVideoConverter_x64.exe` imports OpenCV and IJG/libjpeg but
  not XIMEA, WinPcap, or GPUJPEG. It is an offline image conversion utility,
  not the live video transport.

For the current network/session refresh that ties raw/MJPEG video TX, RX
filtering, fragment reassembly, and session control together, see
[NETWORK_AND_SESSION_PROTOCOL.md](NETWORK_AND_SESSION_PROTOCOL.md).

### v2.0 Main GUI Caller Map

| Function | Evidence label | Recovered surface |
|---|---|---|
| `FUN_14000fb40` | Static fact | XIMEA setup: `xiOpenDevice`, `xiSetParamFloat`, `xiSetParamInt`, `xiGetParamInt`, `xiStartAcquisition`, `xiGetImage`, `xiCloseDevice`, and `XimeaColors.ini` string xrefs. |
| `FUN_140012ec0` | Static fact | XIMEA capture/display loop: `xiGetImage`, `xiGetParamInt`, frame/display strings, OpenCV drawing helpers, and event signaling. |
| `FUN_1400115c0` | Static fact | Raw video send cluster: WinPcap send-queue allocation, queueing, transmit, and teardown, with `0x1e`, `0x2a`, and `0x21` decompiler signals. |
| `FUN_140011c10` | Static fact | CPU MJPEG send cluster: IJG/libjpeg compression plus WinPcap send queues. |
| `FUN_1400152d0` | Static fact | Shared media receive cluster: `pcap_next_ex`, IJG/libjpeg decompression, counters, and event signaling. |
| `FUN_140019c80` | Static fact | DIB allocation/display-surface creation via `CreateDIBSection`. |
| `FUN_14001ac90` | Static fact | Display blit/palette path via `CreateCompatibleDC`, `SetDIBColorTable`, `StretchBlt`, and `CDC::SetStretchBltMode`. |
| `FUN_1400107c0`, `FUN_1400161a0` | Static fact | Local/remote recording-side JPEG/OpenCV clusters, separate from the send path. |

### v1.5 CUDA Branch

The CUDA executable resolves GPUJPEG caller clusters that the v2.0 main GUI
does not have:

| Function | Evidence label | Recovered surface |
|---|---|---|
| `FUN_14000b4a0` | Static fact | GPUJPEG encode setup and encode calls combined with WinPcap send queues. |
| `FUN_140009820` | Static fact | GPUJPEG decode calls alongside IJG/libjpeg decode fallbacks and event waits. |
| `FUN_140011210` | Static fact | Receive cluster with `pcap_next_ex`, GPUJPEG decode, IJG/libjpeg decode, and send-queue cleanup. |
| `FUN_14000e980`, `FUN_1400138f0` | Static fact | Recording/conversion-side GPUJPEG encode and OpenCV file output surfaces. |

This makes the branch boundary clear: v1.5 CUDA has active GPUJPEG import
callers; v2.0 main has GPUJPEG strings but no `gpujpeg.dll` import or GPUJPEG
caller cluster.

## Artifact Map

### `../win-compiled/2-0/LolaGui_XIMEA_x64.exe`

This is the primary v2.0 GUI binary. It contains the live video path:

- XIMEA camera access through `xiapi64.dll`.
- OpenCV 2.4.9 core/imgproc/highgui imports.
- IJG/libjpeg imports from `jpeg62.dll`.
- WinPcap send and receive imports from `wpcap.dll`.
- GDI/User32 display-surface imports.
- Video configuration, display, compression, recording, and monitor strings.

### `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe`

This older v1.5 CUDA build imports `gpujpeg.dll` and proves that a GPU JPEG
path existed in an earlier Windows build.

Imported GPUJPEG functions include:

- `gpujpeg_init_device`
- `gpujpeg_encoder_create`
- `gpujpeg_encoder_encode`
- `gpujpeg_decoder_create`
- `gpujpeg_decoder_decode`
- `gpujpeg_encoder_destroy`
- `gpujpeg_decoder_destroy`

The v2.0 primary XIMEA binary still contains GPUJPEG copyright/configuration
strings, but it does not import `gpujpeg.dll` directly. For the v2.0 binary
analyzed here, the proven live JPEG path is CPU IJG/libjpeg.

### `../win-compiled/2-0/LolaVideoConverter_x64.exe`

This is an offline converter. It imports OpenCV image read/write/encode/decode
functions and IJG/libjpeg symbols, but it is not the live network video path.

Relevant strings include:

- `Lola Video Converter - Version 1.0.21`
- `Video files: %d`
- `.bmp`
- `.jpg`

### `../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe`

This tester binary imports WinPcap and IJG/libjpeg and contains the same
network monitor/configuration vocabulary, but it does not expose the live XIMEA
camera import surface seen in the main GUI binary.

## Proven Import Surface

### Camera

The v2.0 GUI imports these XIMEA functions from `xiapi64.dll`:

- `xiGetImage`
- `xiStopAcquisition`
- `xiStartAcquisition`
- `xiCloseDevice`
- `xiOpenDevice`
- `xiGetNumberDevices`
- `xiSetParamFloat`
- `xiGetParamInt`
- `xiGetParamString`
- `xiSetParamInt`
- `xiGetParamFloat`

No FlyCapture/PtGrey SDK imports were visible in the v2.0 XIMEA GUI binary,
even though `PtGrey.ini` is shipped. Treat PtGrey support as a configuration
surface or another-build feature unless runtime evidence proves otherwise.

### OpenCV

The v2.0 GUI imports OpenCV 2.4.9 functions from:

- `opencv_core249.dll`
- `opencv_imgproc249.dll`
- `opencv_highgui249.dll`

Relevant imported operations include:

- `cv::Mat` construction/destruction/copy/create helpers.
- `cv::cvtColor`
- `cv::resize`
- `cv::rectangle`
- `cv::ellipse`
- `cv::putText`
- `cv::getTextSize`
- `cv::imwrite`

The display and recording code therefore has both custom GDI/DIB paths and
OpenCV image helper paths available.

### JPEG

The v2.0 GUI imports IJG/libjpeg functions from `jpeg62.dll` by ordinal.

Compression path:

- `jpeg_std_error`
- `jpeg_CreateCompress`
- `jpeg_mem_dest`
- `jpeg_set_defaults`
- `jpeg_set_quality`
- `jpeg_start_compress`
- `jpeg_write_scanlines`
- `jpeg_finish_compress`
- `jpeg_destroy_compress`

Decompression path:

- `jpeg_std_error`
- `jpeg_CreateDecompress`
- `jpeg_mem_src`
- `jpeg_read_header`
- `jpeg_start_decompress`
- `jpeg_read_scanlines`
- `jpeg_finish_decompress`
- `jpeg_destroy_decompress`

### Network

The v2.0 GUI imports WinPcap from `wpcap.dll`:

- `pcap_findalldevs_ex`
- `pcap_findalldevs`
- `pcap_open`
- `pcap_close`
- `pcap_compile`
- `pcap_setfilter`
- `pcap_setmintocopy`
- `pcap_next_ex`
- `pcap_sendpacket`
- `pcap_sendqueue_alloc`
- `pcap_sendqueue_queue`
- `pcap_sendqueue_transmit`
- `pcap_sendqueue_destroy`
- `pcap_freealldevs`

The video sender uses send queues, not just one packet at a time. The helper at
`0x140020d70` proves a single-packet `pcap_sendpacket` path exists, but the
video frame sender uses `pcap_sendqueue_queue` and
`pcap_sendqueue_transmit`.

### Threading and Timing

The v2.0 GUI imports these relevant Win32 primitives:

- `CreateThread`
- `CreateEventA`
- `CreateEventW`
- `SetEvent`
- `ResetEvent`
- `WaitForSingleObject`
- `CloseHandle`
- critical-section functions
- `QueryPerformanceCounter`
- `QueryPerformanceFrequency`
- `SetThreadPriority`
- `Sleep`
- `timeBeginPeriod`
- `timeEndPeriod`
- `timeGetTime`

The video path is event/thread driven. It is not a callback-only design.

### Display

The v2.0 GUI imports User32/GDI32 functions used by the display path:

- `GetDC`
- `GetClientRect`
- `InvalidateRect`
- `UpdateWindow`
- `CreateCompatibleDC`
- `CreateDIBSection`
- `SetDIBColorTable`
- `StretchBlt`
- `DeleteDC`
- `DeleteObject`

This proves a Windows GDI/DIB display path. There is no evidence that live v2.0
video display depends on GPU rendering.

## Configuration Surface

Video-related strings in the v2.0 GUI include:

- `InputVideoBoardType`
- `InputVideoBoardName`
- `InputVideoCameraFile`
- `FrameRate`
- `Exposure`
- `FrameX`
- `FrameY`
- `BayerDec`
- `Compression`
- `CompressionQuality`
- `OptimizeJpegDecompression`
- `IncompleteFramesThreshold`
- `UseGpuJpegDecOnCuda`
- `UseLolaHWColorCorrectionForCxp`
- `AutomaticBayerDecoding`
- `ColorVideo`
- `BayerMatrix`
- `BayerAlgorithm`
- `VideoTxWinPcap`
- `RxPacketFiltering`
- `VideoPacketSize`
- `RemoteVideoBuffers`
- `RecPref_LocalOutputPath`
- `RecPref_RemoteOutputPath`
- `RecPref_RecordLocalVideo`
- `RecPref_RecordRemoteVideo`
- `RecPref_ColorBayerDecoding`
- `RecPref_CompressLocalVideo`
- `RecPref_CompressRemoteVideo`

`VideoPacketSize` is bounded by the helper at `0x140007250`:

- Minimum: 128 bytes.
- Maximum: 8192 bytes.

The LoLa fragment header is 0x21 bytes, so usable fragment payload is roughly:

```text
fragment_payload_bytes = VideoPacketSize - 0x21
```

`CompressionQuality` has validation strings that indicate the accepted range is
40 to 100.

## Camera Files

### `Ximea.ini`

The v2.0 XIMEA camera file lists models and modes such as:

- `xiQ_MQ013CG_E2`
- `XiC_MC023CG_SY`
- `xiQ_Generic`

Representative modes include:

- 640x360
- 640x480
- 1024x576
- 1024x768
- 1280x720
- 1280x960
- 1280x1024
- 1920x1080
- 2048x2048

Formats include:

- `Mono8`
- `RGB24`

Typical listed frame rate is 60 fps for the XIMEA entries observed.

### `PtGrey.ini`

The shipped PtGrey file lists models such as:

- `FL3_U3_13S2C`
- `FL3_U3_13S2M`
- `GS3_U3_41C6C`
- `GS3_U3_41C6M`
- `PtGrey_Generic`

It includes several resolutions and frame rates, including 25, 30, 60, and 120
fps depending on mode.

Because the analyzed v2.0 XIMEA GUI binary does not import a PtGrey SDK, this
file should not be used as proof that this specific binary can drive PtGrey
hardware without further runtime evidence.

### `XimeaColors.ini`

The XIMEA color correction file contains:

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

The binary reads this file and maps values to XIMEA parameters including:

- `wb_kr`
- `wb_kg`
- `wb_kb`
- `gain`
- `gammaY`
- `gammaC`
- `bpc`

## Thread and Event Model

Relevant event/thread strings include:

- `VideoFrameReady%d`
- `VideoWriteEvent`
- `RecFrameReadyEvent`
- `CameraPreviewEndedEvent`
- `FrameDoneThreadEnded`
- `NetSendThreadEnded`
- `LocRecVideoThreadEnded`
- `RemRecFrameReadyEvent%d`
- `AudioVideoRecvThreadEnded%d`
- `RemRecVideoThreadEnded%d`

Important inferred object fields in the local video object:

- `+0x438`: camera preview/capture thread handle.
- `+0x450`: video frame ready event.
- `+0x458`: local recording frame ready event.
- `+0x460`: camera preview ended or thread coordination event.
- `+0x478`: local capture run flag.
- `+0x480`: send thread run flag.
- `+0x1188`: local frame counter.
- `+0x118c`: send/record coordination flag.
- `+0x1830`: current-frame valid flag.
- `+0x1838`: pointer to current local frame.
- `+0x1840`: display surface/window object.
- `+0x1848`: camera preview/display server object.
- `+0x1870`: current local frame-ring index.
- `+0x1878`: start of local frame-ring pointer array.
- `+0x1980`: local recording enabled flag.
- `+0x1988`: local recording frame pointer.
- `+0x1990`: local recording frame byte count.

The cleanup path at `0x14000e960` proves a 30-slot local frame ring: it loops
over 0x1e entries starting at `+0x1878` and frees each non-null pointer.

## Local Video Startup

Evidence label: static fact for the function calls and strings; strong
inference for the object-field roles.

The setup path around `0x140012c00` configures the display/preview side before
the acquisition thread runs:

1. If a previous preview/display object exists at `+0x1848`, stop it and wait
   up to 1000 ms.
2. Allocate and construct a display/server object through `0x1400181e0`.
3. Set display flags. If selected bit depth is 24-bit (`+0x10dc == 0x18`), set
   color/RGB display flags.
4. Configure geometry/surface/window through calls around:
   - `0x140014910`
   - `0x1400196c0`
   - `0x140018f60`
   - `0x140019790`
   - `0x140019610`
   - `0x140019810`
5. Create a capture/preview thread with start address `0x14000efb0`.

Nearby strings include:

- `Camera Preview`
- `Couldn't create display surface`
- `No display surface available`
- `Couldn't update display surface window.`
- `Lola DSCreate: Cannot create a valid display surface`
- `Cannot change display surface to new size.`

## Camera Preview Helper

Evidence label: static fact.

`FUN_14000efc0` is separate from the main long-running capture loop. The video
deep-dive script resolves calls to `xiGetImage`, OpenCV `resize`,
`rectangle`, `putText`, `Mat` helpers, display update `FUN_1400190f0`,
`ResetEvent`, `SetEvent`, and `MessageBoxA`.

Interpretation: this is the camera-preview/helper path used around local
preview setup. It still pulls frames through XIMEA and updates the same
Windows display surface family; it is not a generic webcam or DirectShow path.

## XIMEA Device Initialization

Evidence label: static fact for API calls, parameter strings, and
`XimeaColors.ini` xrefs; strong inference for the exact source-level order.

The XIMEA setup path starts around `0x14000fb40`.

It loops over configured XIMEA devices, closes any existing handle, opens each
device with `xiOpenDevice`, and sets capture parameters.

Observed parameter strings and addresses:

```text
0x140044950  Initializing USB3 camera #%d. Please wait ...
0x1400449d8  exposure
0x1400449e4  RGB24
0x1400449f0  imgdataformat
0x140044a00  width
0x140044a08  height
0x140044a10  offsetX
0x140044a18  offsetY
0x140044a20  cms
0x140044a28  auto_wb
0x140044a30  .\XimeaColors.ini
0x140044a48  m_RedGain
0x140044a54  Colors
0x140044a60  m_GreenGain
0x140044a70  m_BlueGain
0x140044a80  m_GainAll
0x140044a90  m_Luminosity
0x140044aa0  m_Chromaticity
0x140044ab0  m_BadPixelsCorrection
0x140044ac8  m_RawColorCorrection
0x140044ae0  wb_kr
0x140044ae8  wb_kg
0x140044af0  wb_kb
0x140044af8  gain
0x140044b00  gammaY
0x140044b08  gammaC
0x140044b10  bpc
0x140044b98  cfa
```

Initialization sequence:

1. `xiOpenDevice(deviceIndex, handleSlot)`.
2. Set `exposure`, derived from the configured frame-rate/exposure state.
3. Select `imgdataformat` based on whether the selected camera file/mode string
   contains `RGB24`.
4. Query current `width` and `height` limits.
5. Clamp requested width/height to device maxima.
6. Center the region of interest by setting `offsetX` and `offsetY`.
7. Set `width` and `height`.
8. Disable XIMEA color management with `cms = 0`.
9. Disable auto white balance with `auto_wb = 0`.
10. Load `XimeaColors.ini` when present.
11. Apply `wb_kr`, `wb_kg`, `wb_kb`, `gain`, `gammaY`, `gammaC`, and `bpc`.
12. Start acquisition with `xiStartAcquisition`.
13. Prime the image structure with `xiGetImage(handle, 1000, imageStruct)`.

This path is explicitly hardware-driver-first. The live camera path is not
implemented through DirectShow, Media Foundation, browser capture, or a generic
video abstraction.

## Local Capture Loop

Evidence label: static fact for `xiGetImage`, modulo-30 ring arithmetic,
display calls, and event calls; strong inference for the object-field names.

The main local capture loop is around `0x140012ec0`.

Setup:

1. Allocate or reallocate a scratch image buffer at `+0x1130`.
2. Compute byte counts from selected width, height, and bit depth.
3. Build a DIB/BITMAPINFO-like structure for the selected frame geometry.
4. Initialize color/Bayer/display helper structures depending on bit depth and
   mode.
5. Set local capture run flag `+0x478 = 1`.
6. Signal capture/display coordination events at `+0x460` and `+0x450`.
7. Query `cfa` with `xiGetParamInt` and map the camera's CFA/Bayer value to
   internal orientation flags.

Per-frame loop:

1. Increment local frame counter `+0x1188`.
2. Advance local ring index:

   ```text
   ring_index = (ring_index + 1) mod 30
   ```

3. Clear the target ring slot at `+0x1878[ring_index]`.
4. Call `xiGetImage(handle, 1000, imageStruct)`.
5. Copy the returned XIMEA image pointer into the current ring slot.
6. Use byte count:

   ```text
   frame_bytes = width * height * bit_depth / 8
   ```

7. Optionally apply raw color correction or Bayer-related processing when
   configured and when the frame is 8-bit.
8. If display is active, call the display update path around `0x1400190f0`.
9. Publish the current frame:

   ```text
   current_frame_ptr = ring[ring_index]
   current_frame_bytes = frame_bytes
   current_frame_valid = 1
   ```

10. Signal the frame-ready event at `+0x450`.
11. Increment local capture counters.
12. If local recording is enabled and the send path is not consuming that flag,
    copy the current frame pointer/size to the recording slots and signal
    `+0x458`.
13. Continue while `+0x478 != 0`.

Critical observation:

The camera loop blocks in `xiGetImage(handle, 1000, ...)`. That is acceptable
for the video side, but it is exactly the kind of blocking behavior that must
not appear in the Mac audio callback.

## Display and Bayer Path

Evidence label: static fact for imports, strings, and Ghidra caller clusters;
runtime gap for any claim that a DirectX renderer is actually selected live.

Display-related strings include:

- `CBFVideoServer Class`
- `FrameBufferFill:`
- `DSFormatBlit-Bayer:`
- `Bayer decoder supports 8 bit images only.`
- `Lola - Software Color Correction (LOCAL)`
- `Lola - Software Color Correction (REMOTE)`

RTTI/class strings include:

- `.?AVBayer@@`
- `.?AVCBFVideoServ@@`
- `.?AVCColorCorrect@@`
- `.?AVXimeaColorCorrect@@`

The display object constructed at `0x1400181e0` uses GDI/DIB primitives. It can
show local or remote frames and can perform Bayer/color conversion for display.

The code distinguishes at least these cases:

- 24-bit RGB path.
- 8-bit mono/raw path.
- Bayer decode/color-correction path.

The Bayer decoder has an explicit 8-bit-only guard. That matters for a Mac
port: if camera modes are expanded later, Bayer handling must be deliberately
bounded to the supported pixel formats instead of silently guessing.

Ghidra cross-check:

- `FUN_140019c80` calls `CreateDIBSection` and carries DIB/display allocation
  constants.
- `FUN_14001ac90` calls `CreateCompatibleDC`, `SetDIBColorTable`,
  `StretchBlt`, and `CDC::SetStretchBltMode`.
- `FUN_1400190f0` and `FUN_14001b580` call OpenCV `cvtColor`, consistent with
  separate color/Bayer conversion helpers.

The strings `DirectX`, `Rendering mode: %s`, and `SIMD Acceleration: %s` are
present, but this static pass still proves GDI/DIB display; it does not prove a
live DirectX-rendered v2.0 video path.

## Local Send Path

Evidence label: static fact for wait/event calls, serialization constants,
fragmenter calls, packet-builder calls, and WinPcap sendqueue calls; strong
inference for field names and queue ownership.

The local sender waits for frames from the capture loop. It does not capture
from the camera directly.

Common send structure:

1. Wait for the frame-ready event at `+0x450`.
2. Reset the event.
3. Read the current local frame pointer at `+0x1838`.
4. Serialize a LoLa video frame:

   ```text
   uint32 frame_counter
   uint32 image_payload_length
   byte[] image_payload
   ```

5. Fragment the serialized video frame with the custom LoLa fragmenter
   `0x1400070b0`.
6. For each fragment, build a raw Ethernet/IP/UDP packet with `0x140020ba0`.
7. Queue packets with `pcap_sendqueue_queue`.
8. Transmit the queue with `pcap_sendqueue_transmit`.
9. Destroy/reallocate send queues as needed.

The send queue allocation uses a batch size based on 30 packets:

```text
sendqueue_bytes = (fragmented_payload_bytes + 0x32) * 0x1e
```

`0x1e` is decimal 30, matching the broader use of 30-slot buffering.

When `pcap_sendqueue_queue` fails, the sender transmits the current queue,
destroys it, allocates a new queue, and retries queueing. That is a throughput
and syscall amortization optimization; it is not a retransmission safety net.

## Raw Video Send Path

Evidence label: static fact for the function body, LoLa fragmenter calls,
packet-builder calls, and WinPcap sendqueue calls; strong inference for the
source-level name "raw video."

The raw/uncompressed sender is around `0x140011680` and neighboring code.

Payload:

```text
uint32 local_frame_counter
uint32 raw_frame_byte_count
byte[] raw_frame
```

The raw frame byte count comes from:

```text
width * height * bit_depth / 8
```

After serialization, the frame is fragmented through `0x1400070b0` and emitted
through the WinPcap sendqueue path.

This path avoids JPEG latency but consumes much more network bandwidth.

## MJPEG Send Path

Evidence label: static fact for IJG/libjpeg compression calls and WinPcap
sendqueue calls; strong inference for exact source-level enum naming.

The CPU MJPEG sender starts at `0x140011c10`.

Per frame:

1. Wait for the frame-ready event.
2. Read current frame pointer and raw byte count.
3. Read `CompressionQuality` from configuration state.
4. Allocate/reuse a JPEG output buffer.
5. Configure IJG/libjpeg:

   ```text
   jpeg_std_error
   jpeg_CreateCompress
   jpeg_set_defaults
   jpeg_set_quality
   jpeg_mem_dest
   jpeg_start_compress
   ```

6. Set image width from selected video width.
7. Set image height from selected video height.
8. Set `input_components` to bit depth divided by 8.
9. Set color space based on component count:
   - 3 components: RGB-like color input.
   - 1 component: grayscale input.
10. Write one scanline per image row with `jpeg_write_scanlines`.
11. Finish compression:

   ```text
   jpeg_finish_compress
   jpeg_destroy_compress
   ```

12. Serialize:

   ```text
   uint32 local_frame_counter
   uint32 jpeg_byte_count
   byte[] jpeg_payload
   ```

13. Fragment and send through WinPcap send queues.

This is a blocking CPU compression path in the video send thread. It must not be
placed on an audio realtime thread in a Mac implementation.

## LoLa Fragment Format

Evidence label: static fact for header size, offsets, and send-side marker;
runtime gap for live marker byte interpretation.

The fragment builder at `0x1400070b0` splits a serialized video frame into
smaller LoLa subframes.

The fragment header is 0x21 bytes:

```text
offset  size  meaning
0x00    u32   magic 0xfdfdfdfd
0x04    u32   magic 0xdfdfdfdf
0x08    u32   direction/type marker, send side observed as 0xeeeeeeee
0x0c    u32   sequence/frame id
0x10    u32   fragment count
0x14    u32   fragment index
0x18    u32   byte offset into serialized frame
0x1c    u32   fragment payload byte length
0x20    u8    final-fragment marker, 1 on final fragment
0x21    ...   fragment payload bytes
```

The builder:

1. Increments a sequence/frame id at builder offset `+0x8`.
2. Computes max fragment payload from configured packet size minus 0x21.
3. Allocates one fragment buffer per subframe.
4. Writes header and copies the relevant serialized-frame slice.
5. Marks only the final fragment with byte `+0x20 = 1`.
6. Backfills the total fragment count into every fragment.

The receive branch checks a marker value observed as `0xaaaaaaaa` while the send
builder writes `0xeeeeeeee`. This may be direction-specific or role-specific.
It needs live packet capture before treating it as a protocol contradiction.

## Raw Ethernet/IP/UDP Packet Builder

Evidence label: static fact for shared caller sites and packet-field writes;
runtime gap for live checksum/driver behavior on a Windows host.

The packet builder at `0x140020ba0` wraps each LoLa fragment as a raw
Ethernet/IP/UDP packet.

Focused audio cross-check: the same `0x140020ba0` builder is called from the
audio send thread and from the raw/MJPEG video send paths. Static fact: audio
and video share this raw Ethernet/IP/UDP wrapper even though audio transmits
single packets with `pcap_sendpacket` and video batches frames with WinPcap
send queues.

Packet layout:

```text
Ethernet header
IPv4 header
UDP header
LoLa fragment payload at packet offset 0x2a
```

Observed behavior:

- Copies destination and source MAC addresses from caller-provided structures.
- Sets EtherType to IPv4 (`0x0800`).
- Sets IPv4 version/header byte to `0x45`.
- Sets protocol to UDP (`0x11`).
- Sets total IPv4 length to UDP payload plus header length.
- Sets IP identification to `0x1337`.
- Writes source/destination IPv4 addresses.
- Writes source/destination UDP ports.
- Writes UDP length as payload plus 8.
- Computes IPv4 header checksum with helper `0x140020a10`.
- Computes UDP pseudo-header checksum with helper `0x140020a80`.

This explains why LoLa depends on WinPcap/Npcap-like low-level packet access
instead of normal NAT-friendly socket transport. The video path, like audio,
constructs packets close to the link layer.

## Network Receive Loop

Evidence label: static fact for `pcap_next_ex`, parser/reassembly/decode calls,
and counter/display event calls; strong inference for exact counter names.

The main packet receive loop starts around `0x140015300`.

High-level receive loop:

1. Get next packet from WinPcap with `pcap_next_ex`.
2. Parse Ethernet/IP/UDP packet headers.
3. Compute IPv4 header length.
4. Extract UDP ports.
5. Format/check source IPv4 address.
6. Branch by source port and remote host/session state.
7. Dispatch to audio or video handling.

The video branch begins around `0x140015768` for one video mode and around
`0x1400158e4`/`0x140015921` for the compressed mode.

The receive loop verifies remote host/port state before accepting video data.
It is not a general UDP socket receiver.

## Video Reassembly

Evidence label: static fact for helper call graph and buffer-copy offsets;
runtime gap for live packet loss thresholds and marker semantics.

Fragment reassembly uses helpers around `0x140006e80` through `0x140007200`.

Initializer `0x140006f00`:

- Stores sequence/frame id.
- Stores full payload length.
- Stores expected fragment count.
- Allocates a reassembly byte buffer.
- Allocates/tracks a received-fragment bitmap.
- Initializes completed-fragment count.

Add-fragment helper `0x140007200`:

1. Checks that fragment sequence matches the active reassembly object.
2. Checks that fragment index is within the bitmap range.
3. Rejects duplicate fragments.
4. Copies fragment payload bytes from `fragment + 0x21` into the reassembly
   buffer at the fragment's byte offset.
5. Marks the fragment received.
6. Increments completed-fragment count.

Completion helper `0x140006e80`:

```text
complete = completed_fragment_count == expected_fragment_count
```

Access helper `0x140006e90` returns:

- pointer to the completed serialized video frame.
- byte count of that serialized video frame.

Incomplete handling:

- The receiver tracks fragment sequence mismatches.
- The receiver tracks orphan/out-of-order subframes.
- When the final-fragment marker is seen but not enough fragments have arrived,
  the code compares completion state against `IncompleteFramesThreshold`.
- If the threshold is not met, the frame is dropped.

There is no evidence of retransmission. The recovery policy is drop, count, and
continue.

## Raw Video Receive Path

Evidence label: static fact for copy/event/counter shape; strong inference for
field labels.

The raw receive path accepts a completed serialized video frame, then reads:

```text
uint32 remote_frame_counter
uint32 raw_frame_byte_count
byte[] raw_frame
```

Then it:

1. Checks for duplicate/invalid frame state.
2. Updates video receive/drop counters.
3. Copies the raw payload into the remote frame ring/buffer.
4. Updates the current remote frame pointer and valid-count state.
5. Signals remote display/recording events.

Important inferred remote/session fields:

- `+0x288`: received video frames / video RX frame counter.
- `+0x28c`: dropped or invalid video frames.
- `+0x290`: sequence-gap related video drops.
- `+0x294`: start-frame or sequence mismatch counter.
- `+0x298`: orphan/out-of-order subframe counter.
- `+0x340`: remote frame buffer/ring region.
- `+0x370`: remote recording frame-ready event.
- `+0x388`: remote recording frame pointer.
- `+0x390`: remote recording frame byte count.

Exact counter labels are inferred from strings and offset proximity. The broader
counter roles are clear from the increment sites.

## MJPEG Receive Path

Evidence label: static fact for IJG/libjpeg decode calls; medium inference for
the precise `OptimizeJpegDecompression` branch semantics.

The MJPEG receive path reconstructs:

```text
uint32 remote_frame_counter
uint32 jpeg_byte_count
byte[] jpeg_payload
```

Then it decodes the JPEG payload through IJG/libjpeg.

The decompression sequence around `0x140015d33` is:

```text
jpeg_std_error
jpeg_CreateDecompress
jpeg_mem_src
jpeg_read_header
jpeg_start_decompress
jpeg_read_scanlines
jpeg_finish_decompress
jpeg_destroy_decompress
```

The scanline loop writes decompressed rows into the remote raw frame buffer.
After decode, the remote frame buffer is published to the display/recording
side.

The `OptimizeJpegDecompression` setting appears to select whether the code
copies the JPEG payload into an intermediate buffer before decompression or
decodes from the reassembled payload memory directly. The exact enum/branch
meaning should be verified with runtime config toggles or source symbols before
reimplementing it literally.

## Recording Paths

Evidence label: static fact for local/remote recording functions, file-name
strings, OpenCV `imwrite`, and IJG/libjpeg compression calls.

Recording is a side path driven by frame-ready events.

Strings:

- `LolaVideoRec`
- `Video Recording:`
- `_Local_%07d.bmp`
- `_Local_%07d.jpg`
- `_Remote_%07d.bmp`
- `_Remote_%07d.jpg`

### Local Recording

The capture loop publishes local recording frames through:

```text
record_ptr = current_frame_ptr
record_bytes = current_frame_bytes
SetEvent(local_record_event)
```

Local recording code around `0x140010f70` and `0x1400110d5` uses IJG/libjpeg
for JPEG output and constructs `_Local_%07d.jpg` file names. OpenCV `imwrite`
is also imported and likely supports BMP/JPEG image file output in the
recording/converter paths.

### Remote Recording

The receive path publishes remote recording frames through:

```text
remote_record_ptr = decoded_or_raw_remote_frame_ptr
remote_record_bytes = frame_bytes
SetEvent(remote_record_event)
```

Remote JPEG recording around `0x140016980` uses IJG/libjpeg compression and
constructs `_Remote_%07d.jpg` names.

Recording is not part of the minimum live video latency path. It must remain a
side thread in any Mac implementation.

## Monitoring Counters

Relevant strings:

- `Video RX frames`
- `Video Dropped frames`
- `Video Dropped start_frames`
- `Video Orphans sub_frames`
- `Video Dropped sub_frames`
- `Video Remote FpS settings`
- `Video Remote Window FpS`
- `Video Received FpS`
- `Video Local FpS settings`
- `Video Local window FpS`
- `Video Sent FpS`
- `Frame Size (byte): %i`
- `Packet Size (byte): %i`
- `Sent Frames: %d`

The monitor surface distinguishes:

- configured local frame rate.
- local display/window frame rate.
- sent frame rate.
- remote configured frame rate.
- remote display/window frame rate.
- received frame rate.
- receive drops.
- malformed/incomplete frame starts.
- orphan/dropped subframes.

This is useful for the Mac port: the first Mac video prototype should expose
the same class of counters before adding UI polish.

## End-to-End Local Send Diagram

```text
XIMEA camera
  xiOpenDevice / xiSetParam* / xiStartAcquisition
        |
        v
capture thread
  xiGetImage(handle, 1000, imageStruct)
        |
        v
30-slot local frame ring
  object+0x1878[index]
        |
        +--> GDI/DIB local display
        |
        +--> local recording side event
        |
        v
VideoFrameReady event
        |
        v
video send thread
  raw path OR CPU MJPEG path
        |
        v
serialized LoLa video frame
  uint32 frame_counter
  uint32 payload_length
  bytes payload
        |
        v
LoLa fragmenter 0x1400070b0
        |
        v
raw Ethernet/IP/UDP packet builder 0x140020ba0
        |
        v
WinPcap send queue
  pcap_sendqueue_queue
  pcap_sendqueue_transmit
```

## End-to-End Remote Receive Diagram

```text
WinPcap receive loop
  pcap_next_ex
        |
        v
Ethernet/IP/UDP parse
        |
        v
video port / host / mode branch
        |
        v
LoLa fragment validation
  magic, sequence, index, final marker
        |
        v
fragment reassembler
        |
        v
serialized LoLa video frame
  uint32 frame_counter
  uint32 payload_length
  bytes payload
        |
        +--> raw payload copy
        |
        +--> IJG JPEG decode
        |
        v
remote raw frame buffer/ring
        |
        +--> GDI/DIB remote display
        |
        +--> remote recording side event
        |
        v
video counters
  received, dropped, orphan fragments, frame rates
```

## Latency-Relevant Design Choices

### Fast Choices

- Hardware-driver camera API instead of generic camera framework.
- WinPcap raw packet send/receive instead of ordinary conferencing transport.
- Custom fragmentation with no retransmission.
- Optional raw/uncompressed video mode.
- CPU MJPEG rather than modern high-latency interframe codec.
- Event-driven display/recording side paths.
- Small bounded rings instead of large adaptive smoothing buffers.

### Latency Costs

- `xiGetImage(..., 1000, ...)` can block the capture thread.
- CPU JPEG compression can dominate per-frame video latency at high resolution.
- CPU JPEG decompression can dominate receive latency.
- GDI/DIB display and Bayer conversion can add UI latency.
- WinPcap sendqueue batching may improve throughput but can add queueing delay
  depending on queue fill and transmit timing.
- Recording JPEG/BMP files must never run inline with audio or network receive.

### Safety Tradeoff

The video path follows the same general LoLa philosophy as audio: it prefers
drop/count/continue over reliable delivery. However, video tolerates much more
processing and visual degradation than audio. For musical interaction, the Mac
port should preserve this asymmetry.

## Mac Port Implications

Video should be implemented after the audio latency rig is proven.

Required principles:

- Keep video fully outside the audio callback.
- Keep JPEG encode/decode off audio and realtime audio helper threads.
- Use bounded video queues/rings.
- Drop late/incomplete video frames rather than blocking audio or network
  receive.
- Preserve counters for received frames, dropped frames, incomplete frames,
  orphan fragments, decode time, and display rate.
- Support degraded video modes early:
  - lower resolution,
  - lower frame rate,
  - grayscale,
  - lower JPEG quality,
  - frame dropping under load.
- Do not build large adaptive video smoothing buffers into the shared transport
  layer used by audio.

Reasonable Mac video implementation shape:

```text
camera capture thread
  AVFoundation or vendor SDK, depending target camera
        |
        v
bounded local video ring
        |
        +--> preview display
        |
        v
video encode/packet thread
  raw or MJPEG first
        |
        v
LoLa-compatible fragmenter
        |
        v
UDP/raw-packet transport layer

network receive thread
        |
        v
LoLa fragment reassembler
        |
        v
raw copy or JPEG decode
        |
        v
bounded remote video ring
        |
        v
display thread
```

For compatibility testing against Windows LoLa, the first Mac video target
should mimic the serialized frame structure:

```text
uint32 frame_counter
uint32 payload_length
bytes payload
```

and the 0x21-byte LoLa fragment header.

## Evidence Commands

Representative commands used from the repository root:

```sh
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output v2-main -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v15-cuda -import win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output v15-cuda -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v2-main-video -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-v15-cuda -import win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v15-cuda-video -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-converter -import win-compiled/2-0/LolaVideoConverter_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v2-converter-video -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-video-deep-tester -import win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaVideoDeepDive.java /private/tmp/lola-ghidra-output v2-tester-video -deleteProject
file win-compiled/2-0/LolaGui_XIMEA_x64.exe
shasum -a 256 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -p win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -p win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe
strings -a -n 4 win-compiled/2-0/LolaGui_XIMEA_x64.exe
strings -a -n 4 win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe
objdump -d --start-address=0x14000fb40 --stop-address=0x1400104e0 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140012ec0 --stop-address=0x140013b80 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140011680 --stop-address=0x140012400 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x1400152d0 --stop-address=0x140016620 win-compiled/2-0/LolaGui_XIMEA_x64.exe
rg -a -l "VideoPacketSize|CompressionQuality|xiGetImage|gpujpeg|_Remote_%07d.jpg|/MESG_QUICKCONN" win-compiled
python -c "from pathlib import Path; import lief; paths=['win-compiled/2-0/LolaGui_XIMEA_x64.exe','win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe','win-compiled/2-0/LolaVideoConverter_x64.exe']; [print(p, [lib.name for lib in lief.parse(p).imports]) for p in paths]"
```

Python/LIEF was also used to compare PE imports, timestamps, resources,
signature presence, and v1.5/v2.0 hashes. No generated inventory artifact is
vendored in this repository.

## Evidence Table

| Evidence | Meaning |
| --- | --- |
| `xiapi64.dll` imports | Live XIMEA camera path is proven. |
| `xiGetImage` calls around `0x140012ec0` | Local capture loop pulls frames from camera. |
| `xiOpenDevice`/`xiSetParam*` around `0x14000fb40` | Camera setup directly programs XIMEA parameters. |
| 30-slot free loop at `0x14000e960` | Local video frame ring has 30 slots. |
| `VideoFrameReady%d` | Capture-to-send handoff uses events. |
| `jpeg_CreateCompress`/`jpeg_write_scanlines` around `0x140011c10` | CPU MJPEG send path. |
| `jpeg_CreateDecompress`/`jpeg_read_scanlines` around `0x140015d33` | CPU MJPEG receive path. |
| `pcap_sendqueue_queue`/`pcap_sendqueue_transmit` in sender | Video sends through WinPcap send queues. |
| `pcap_next_ex` around `0x140015300` | Receive loop reads packets from WinPcap. |
| `0x1400070b0` | LoLa fragment builder. |
| `0x140007200` | LoLa fragment reassembly add function. |
| `0x140006e80` | Reassembly completion check. |
| `0x140020ba0` | Raw Ethernet/IP/UDP packet builder. |
| GDI imports and display strings | Live display uses Windows GDI/DIB surfaces. |
| `Bayer decoder supports 8 bit images only.` | Bayer decode path is format-limited. |
| `_Local_%07d.jpg`, `_Remote_%07d.jpg` | Local and remote recording side paths. |
| v1.5 CUDA `gpujpeg.dll` imports | GPUJPEG existed in older build, not proven active in v2.0 main binary. |

## Runtime Gaps To Close

These require hardware or live execution:

1. Capture a Windows LoLa video session with Wireshark/Npcap and confirm:
   - fragment marker values,
   - byte order of serialized fields,
   - exact port mapping,
   - exact packet size behavior,
   - raw vs MJPEG mode identifiers.
2. Run with a XIMEA camera and confirm:
   - exact `XI_IMG` fields used,
   - whether `xiGetImage` returns owned buffers or SDK-managed buffers,
   - real frame timing under 32/64 audio-buffer stress.
3. Toggle `Compression`, `CompressionQuality`, `OptimizeJpegDecompression`,
   `IncompleteFramesThreshold`, `BayerDec`, and `RemoteVideoBuffers` and map
   exact enum values.
4. Verify whether `PtGrey.ini` is dead in this v2.0 binary, used indirectly, or
   intended for another executable build.
5. Confirm whether the `0xeeeeeeee` send marker and `0xaaaaaaaa` receive marker
   are direction markers, role markers, or mode markers.
6. Measure real latency contribution:
   - camera exposure and transfer,
   - capture thread wait,
   - JPEG encode,
   - sendqueue batching,
   - network transit,
   - reassembly,
   - JPEG decode,
   - display blit.

## Acceptance Criteria For Understanding The Windows Video Flow

This static pass establishes:

- The live camera API.
- The camera configuration path.
- The local frame ring shape.
- The capture-to-send handoff.
- The raw video serialization shape.
- The CPU MJPEG serialization shape.
- The LoLa fragment header shape.
- The WinPcap raw packet send path.
- The WinPcap receive path.
- The reassembly policy.
- The raw and MJPEG receive paths.
- The display/Bayer/color path.
- The local and remote recording side paths.
- The key runtime gaps that still need hardware/packet evidence.

The remaining work is not more static string extraction. It is targeted runtime
validation with camera hardware and packet capture.
