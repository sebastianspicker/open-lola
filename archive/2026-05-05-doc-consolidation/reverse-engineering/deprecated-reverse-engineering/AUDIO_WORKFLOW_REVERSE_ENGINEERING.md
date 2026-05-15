# Audio Workflow Reverse Engineering

Date: 2026-05-02

Scope: static reverse engineering of the Windows binaries under
`../win-compiled/`.
This pass did not execute the Windows programs, bypass activation, patch binaries,
or perform network/runtime tracing.

Primary target: `../win-compiled/2-0/LolaGui_XIMEA_x64.exe`

Comparison targets:

- `../win-compiled/1-5/LolaGui_XIMEA_x64.exe`
- `../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe`
- `../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe`
- `../win-compiled/2-0/portaudio_x64.dll`
- `../win-compiled/1-5/portaudio_x64.dll`
- `../win-compiled/2-0/LolaWavSplitter_x64.exe`
- `../win-compiled/1-5/LolaWavSplitter_x64.exe`

Corpus cross-link: see
[CORPUS_ORIGINS_AND_INTEGRATION.md](CORPUS_ORIGINS_AND_INTEGRATION.md) for the
package-wide proof that the WAV splitter is an unchanged offline helper, while
the live audio path remains inside the main GUI/tester family.

## Executive Result

The Windows LoLa audio path is a callback-driven PortAudio ASIO path.
It is not a normal Windows conferencing audio path.

The reconstructed workflow is:

```text
ASIO device discovery
  -> ASIO buffer-size check
  -> PortAudio full-duplex callback stream
  -> 64-frame signed 16-bit PCM capture blocks
  -> callback wakes WriteEvent
  -> audio send thread packetizes current capture block immediately
  -> LoLa fragment header + serialized audio message
  -> raw Ethernet/IP/UDP frame built in user space
  -> WinPcap sends the frame to active peers

network receive thread
  -> WinPcap captures IP/UDP frames
  -> filters expected peer IP and audio/video UDP ports
  -> reassembles LoLa audio fragments
  -> parses audio sequence and PCM byte count
  -> writes PCM into a 100-slot per-peer remote playback ring
  -> PortAudio callback consumes remote ring
  -> missing/late audio becomes silence/dropout, not blocking
```

The key low-latency design choices visible in the binary are:

- ASIO is the intended host API.
- PortAudio is used in callback mode, not blocking read/write mode.
- Sample format is signed 16-bit PCM.
- User callback size passed to `Pa_OpenStream` is hardcoded to 64 frames.
- Suggested PortAudio input/output latency is `0.0005` seconds.
- The callback never waits for network data.
- The send thread waits on a single capture-ready event, then sends.
- Audio packets are raw PCM carried inside LoLa's own tiny fragment/message
  layer; no speech codec, AEC, AGC, retransmission, or concealment path is
  visible in the binary.
- WinPcap is used for the low-latency data path. The sender constructs
  Ethernet, IPv4, and UDP headers itself instead of using normal UDP sockets
  for audio transport.
- Receive buffering is a fixed ring, not an adaptive concealment buffer.
- Recording is side-band and drained by separate threads.

## Ghidra Refresh Summary

Ghidra 12.0.4 headless was run after the original objdump pass. It did not
recover original C++ source names, but it did recover enough import-caller and
decompiler signal data to strengthen the audio map.

| Claim | Evidence label | Ghidra evidence |
|---|---|---|
| PortAudio/ASIO object construction | Static fact | `FUN_140007980` calls `Pa_Initialize`, `Pa_GetHostApiCount`, `Pa_GetHostApiInfo`, `Pa_HostApiDeviceIndexToDeviceIndex`, and `Pa_GetDeviceInfo`; string xrefs include `WriteEvent`, `AudSndThreadEnded`, `LocRecThreadEnded`, and `RemRecThreadEnded`. |
| ASIO buffer-size probe | Static fact | `FUN_140009010` calls `PaAsio_GetAvailableBufferSizes` and `Pa_HostApiDeviceIndexToDeviceIndex`. |
| Full-duplex stream open | Static fact | `FUN_1400093a0` calls `Pa_OpenStream`, `Pa_GetDeviceInfo`, `Pa_HostApiDeviceIndexToDeviceIndex`, `Pa_GetErrorText`, and `Pa_CloseStream`; the decompiler signal matrix sees `0x40` and `Pa_OpenStream`. |
| Event-driven audio send | Static fact | `FUN_140009bf0` calls `WaitForSingleObject`, `SetEvent`, and `pcap_sendpacket`; the decompiler signal matrix sees `0x2a` and `0x21`. |
| Receive-to-ring path | Strong inference | `FUN_1400152d0` is the shared media receive cluster and combines `pcap_next_ex`, event signaling, `100`, and video/JPEG branches; audio-specific ring copy details still come from the address-level objdump reconstruction below. |
| WAV writing is side-band | Static fact | `FUN_1400214a0` calls `mmioOpenA`, `mmioCreateChunk`, `mmioAscend`, and `mmioWrite`; `FUN_1400215a0` calls `mmioWrite`. |

The focused audio deep dive added these tighter v2.0 links:

| Claim | Evidence label | Focused Ghidra/objdump evidence |
|---|---|---|
| Quick-connect and generated-signal messages are built and parsed in one control cluster. | Static fact | `FUN_14001fb60` builds `/MESG_QUICKCONN`, `/MESG_QUICKCONN_ACK`, `/MESG_SEND_AUDIO_SIGNAL`, and `/MESG_STOP_AUDIO_SIGNAL`; `FUN_14001f390` parses the matching message names and dispatches window/control messages. |
| Runtime audio/network settings are round-tripped through `LolaGui.ini`. | Static fact | `FUN_14002a6e0` loads audio/network keys and `FUN_140031d70` writes the same keys back through profile-write helpers. |
| Audio WinPcap start owns the transmit thread setup. | Static fact | `FUN_14000a000` calls `pcap_findalldevs`, `pcap_open`, and `AfxBeginThread`, then hands off to the audio send thread. |
| Audio and video share the raw Ethernet/IP/UDP frame builder. | Static fact | `FUN_140020ba0` is called from audio send and both raw/MJPEG video send clusters; it contains the `0x2a` wrapper and `0x1337` IPv4 identification constants. |
| Generated audio signal is a real alternate PCM source. | Strong inference | `FUN_140008b10` calls `sin` and is called from `FUN_140009bf0`; the send loop can replace `object +0x1288` live capture with this generated buffer when the signal flag is active. |

For the current network/session refresh that ties this audio TX cluster to
WinPcap setup, control messages, and RX filtering, see
[NETWORK_AND_SESSION_PROTOCOL.md](NETWORK_AND_SESSION_PROTOCOL.md).

Ghidra also confirmed the same PortAudio shape in the v1.5 non-CUDA main GUI:
`FUN_1400054d0` calls `PaAsio_GetAvailableBufferSizes`, and
`FUN_1400060a0` calls `Pa_OpenStream`.

## Artifact Identity

Static hashes for the inspected binaries:

```text
3132fda33c2c6cc71796e8dde882a9434dd42e4e29726d06a104348207d34c7f  ../win-compiled/2-0/LolaGui_XIMEA_x64.exe
c19372600cb1b16c3a0d33682094c2c52d3716aa1364af60f0aa0d2716469cbb  ../win-compiled/1-5/LolaGui_XIMEA_x64.exe
2cc2519c5b9ffcfdd0581e04299fbe3f2ba5f0d604b6f27398227c341bf2de11  ../win-compiled/1-5/LolaGui_XIMEA_CUDA_x64.exe
aab0b718a04fb08d8bcfeb136fca8b14e649eb773c687ee482c33d82789644a8  ../win-compiled/2-0/LolaGui_Tester/LolaGui_TESTER_x64.exe
4d56b6305ffd20547d38b0592f3b8c6321b4f7122ef3cdee94b615070f2f44d8  ../win-compiled/2-0/portaudio_x64.dll
4d56b6305ffd20547d38b0592f3b8c6321b4f7122ef3cdee94b615070f2f44d8  ../win-compiled/1-5/portaudio_x64.dll
741e0c81297010f1f05bed4d92bbfd81f41cc54fe925eef7ba42389ea4c031d2  ../win-compiled/2-0/LolaWavSplitter_x64.exe
741e0c81297010f1f05bed4d92bbfd81f41cc54fe925eef7ba42389ea4c031d2  ../win-compiled/1-5/LolaWavSplitter_x64.exe
```

All inspected executables and DLLs are PE32+ x86-64 Windows binaries.

## PortAudio Import Surface

`LolaGui_XIMEA_x64.exe` imports PortAudio functions by ordinal from
`portaudio_x64.dll`. The PortAudio DLL exports ASIO and WASAPI helper symbols,
but the LoLa GUI binary directly imports only one ASIO-specific helper:
`PaAsio_GetAvailableBufferSizes`.

The imported ordinals in LoLa 2.0 map to:

```text
ordinal  3  Pa_GetErrorText
ordinal  4  Pa_Initialize
ordinal  5  Pa_Terminate
ordinal  6  Pa_GetHostApiCount
ordinal  8  Pa_GetHostApiInfo
ordinal 10  Pa_HostApiDeviceIndexToDeviceIndex
ordinal 15  Pa_GetDeviceInfo
ordinal 17  Pa_OpenStream
ordinal 19  Pa_CloseStream
ordinal 21  Pa_StartStream
ordinal 22  Pa_StopStream
ordinal 24  Pa_IsStreamStopped
ordinal 25  Pa_IsStreamActive
ordinal 50  PaAsio_GetAvailableBufferSizes
```

Important non-imports:

- No `Pa_ReadStream`.
- No `Pa_WriteStream`.
- No direct `PaAsio_ShowControlPanel`.
- No direct `PaAsio_GetInputChannelName`.
- No direct `PaAsio_GetOutputChannelName`.
- No direct WASAPI helper calls from the LoLa GUI binary.

This proves the primary audio path is a full-duplex callback stream, not a
blocking PortAudio stream.

## Windows API Surface

The main GUI binary imports these relevant Windows APIs:

```text
KERNEL32.CreateEventA
KERNEL32.ResetEvent
KERNEL32.SetEvent
KERNEL32.WaitForSingleObject
KERNEL32.CreateThread
KERNEL32.Sleep
KERNEL32.EnterCriticalSection
KERNEL32.LeaveCriticalSection
KERNEL32.InitializeCriticalSection
KERNEL32.DeleteCriticalSection
WINMM.timeBeginPeriod
WINMM.timeEndPeriod
WINMM.timeGetTime
WINMM.timeGetDevCaps
WINMM.mmioOpenA
WINMM.mmioCreateChunk
WINMM.mmioAscend
WINMM.mmioWrite
WINMM.mmioClose
```

The main GUI imports `mmioWrite` but not `mmioRead`, so it writes WAV files but
does not use the main binary as a WAV reader.

`LolaWavSplitter_x64.exe` imports both read and write `mmio*` functions and is
the separate multichannel WAV splitting tool.

## ASIO Device Discovery

The constructor-like function around `0x140007980` builds the audio object.
The static string `ASIOAudio` is associated with this object.

Startup sequence:

```text
initialize object fields
initialize critical section at object +0x8
create event "WriteEvent" at object +0x30
create event "AudSndThreadEnded" at object +0x1fb0
create event "LocRecThreadEnded" at object +0x1fb8
create event "RemRecThreadEnded" at object +0x1fc0
initialize recording basename strings to "LOLA_REC"
call Pa_Initialize
enumerate PortAudio host APIs
find host API whose name is "ASIO"
store ASIO host API index and ASIO device count
enumerate ASIO devices
store device names and max input/output channel counts
```

If no ASIO devices are available, the binary contains the user-facing warning:

```text
No ASIO devices available!
```

This confirms that the workflow is ASIO-first, even though the bundled
PortAudio DLL also contains other host APIs.

## ASIO Buffer Size Check

Function around `0x140009010` calls:

```text
Pa_HostApiDeviceIndexToDeviceIndex(asioHostApiIndex, localDeviceIndex)
PaAsio_GetAvailableBufferSizes(globalDeviceIndex, &min, &max, &preferred, &granularity)
```

It returns the preferred size when positive, otherwise the minimum size when
positive.

The UI/status string is:

```text
ASIO Buffer size: %d samples
```

The binary also contains the warning text that the ASIO buffer size must be 32
or 64 samples. This matches LoLa's public latency guidance.

Important distinction:

- The ASIO driver/hardware buffer is queried and warned about separately.
- The `Pa_OpenStream` callback buffer is hardcoded to 64 frames.

## Stream Open

The stream-open function is around `0x1400093a0`.

It builds PortAudio input and output parameter blocks and calls `Pa_OpenStream`.

Recovered call shape:

```c
Pa_OpenStream(
    &stream,
    &inputParameters,
    &outputParameters,
    44100.0,
    64,
    0,
    audioCallback,
    audioObject
);
```

Recovered input parameters:

```text
device                       Pa_HostApiDeviceIndexToDeviceIndex(...)
channelCount                 requested channel count
sampleFormat                 0x08, PortAudio paInt16
suggestedLatency             0.0005
hostApiSpecificStreamInfo    PaAsioStreamInfo with channel selectors
```

Recovered output parameters:

```text
device                       same selected ASIO device mapping
channelCount                 requested channel count
sampleFormat                 0x08, PortAudio paInt16
suggestedLatency             0.0005
hostApiSpecificStreamInfo    NULL
```

Recovered `PaAsioStreamInfo` for input:

```text
size             0x18
hostApiType       3
version           1
flags             1
channelSelectors  AudioInputOffset + 0..channelCount-1
```

The input side supports channel offset selection. The output side does not show
equivalent channel selector wiring in this path.

After a successful open:

```text
object +0x90    = PortAudio stream pointer
object +0xa0    = stream allocated/open flag
object +0x1918  = channelCount * 128
```

`channelCount * 128` is exactly:

```text
channelCount * 64 frames * 2 bytes/sample
```

So the internal audio block is one 64-frame signed 16-bit PCM block.

## Sample Rate Finding

The binary contains UI/resource strings for `44100` and `48000`, and the
connection negotiation strings include `SR:%d`.

However, the recovered `Pa_OpenStream` path in the inspected 2.0 and 1.5 GUI
binaries passes a static double constant of `44100.0` to PortAudio. The WAV
format initialization also writes `0xAC44`, which is 44100 decimal.

This creates an important unresolved point:

- Static evidence proves the analyzed open path uses 44100 Hz.
- Static strings prove the application has UI/protocol awareness of 48000 Hz.
- This pass did not find a second `Pa_OpenStream` call using `48000.0`.

Practical implication: do not assume 48 kHz interop works in the Windows binary
without runtime tracing. The Mac port should support both 44.1 kHz and 48 kHz,
but the Windows compatibility test must verify the actual negotiated sample
rate with a live Windows LoLa peer.

## Start, Stop, Close

Start wrapper around `0x14000a350`:

```text
if stream is open and not started:
    Pa_StartStream(stream)
    started flag = 1
```

Stop wrapper around `0x14000a710`:

```text
if started and stream open:
    if not Pa_IsStreamStopped(stream):
        Pa_StopStream(stream)
    started flag = 0
```

Cleanup path around `0x140008700`:

```text
if recording enabled:
    stop recording
if stream open:
    check Pa_IsStreamActive / Pa_IsStreamStopped
Pa_Terminate()
clear stream/record flags
SetEvent(WriteEvent)
WaitForSingleObject(AudSndThreadEnded, 1000)
free audio rings
close record events
destroy strings/vectors
```

The destructor explicitly wakes the audio send thread before waiting for the
`AudSndThreadEnded` event.

## PortAudio Callback

The callback thunk is at `0x14000acb0`. It adapts the PortAudio callback ABI and
calls the main callback method at `0x14000ad00`.

The callback returns `0`, which is PortAudio's continue status.

The callback uses these internal buffers:

```text
object +0x8e0   local capture ping-pong buffer[0]
object +0x8e8   local capture ping-pong buffer[1]
object +0x8d0   sample cursor inside current callback
object +0x8f0   active local capture buffer index, modulo 2
object +0x8c8   input/capture gain, initialized to 1.0
object +0x98    local output monitor gain, initialized to 0.0
object +0x1288  pointer to current local capture block
object +0xc20   remote playback rings, two peers, 100 slots each
object +0x1290  local recording ring, 100 slots
object +0x15b8  remote recording ring, 100 slots
```

Callback behavior:

```text
if stream-started flag is false:
    return continue

toggle local ping-pong capture buffer index modulo 2

if input pointer is null or frameCount is zero:
    write zeroes to current local capture block
    write zeroes to PortAudio output buffer
else:
    for each frame:
        for each channel:
            read signed 16-bit input sample
            write sample * captureGain to current local capture block
            write sample * monitorGain to PortAudio output buffer

reset local sample cursor
publish current capture block pointer at object +0x1288
SetEvent(WriteEvent)

for each remote peer slot:
    if remote ring is active:
        copy remote PCM from ring into output buffer
        clear consumed ring slot
        advance ring index modulo 100

if recording is enabled:
    copy current remote output block into remote record ring if space exists
    copy current local capture block into local record ring if space exists

return continue
```

Focused disassembly of `0x14000ad00` makes the local processing deliberately
small:

- Static fact: the callback alternates between two local capture buffers and
  publishes the active pointer at `object +0x1288`.
- Static fact: the input pointer null path writes silence to both the capture
  block and the PortAudio output block.
- Static fact: capture gain at `object +0x8c8` and local monitor gain at
  `object +0x98` are applied inside the callback loop to signed 16-bit samples.
- Medium inference: no explicit limiter, compressor, AEC, AGC, or saturation
  clamp is visible in the recovered callback loop; it is integer gain/multiply,
  copy, zero-fill, event signal, and ring copy.
- Static fact: remote playback ring consumption copies one fixed PCM block into
  the output buffer, clears the consumed slot with zeroes, and advances the
  per-peer read index modulo 100.
- Static fact: recording production is only a memory copy into local/remote
  recording rings. The disk-writing threads are outside the callback.

Critical latency point: the callback signals `WriteEvent` and proceeds. It does
not wait for the send thread, the receive thread, a network packet, or a WAV
recording write.

This is the key LoLa behavior: drop/click is acceptable; waiting is not.

## Audio Send Thread

The audio send thread entry is:

```text
0x140009be0 -> 0x140009bf0
```

It is created around `0x14000a2cf` with thread start address `0x140009be0` and
the audio object as the thread parameter. The returned handle is stored at
`object +0x1fa8`.

The thread owns the `AudSndThreadEnded` event.

Thread setup:

```text
object +0x18ec = 1                    ; send-thread running flag
allocate packet builder at object +0x1920
compute send packet size at object +0x196c
compute PCM payload size at object +0x1968
allocate transmit buffer at object +0x1b60
ResetEvent(AudSndThreadEnded)
ResetEvent(WriteEvent)
```

Focused objdump detail:

```text
object +0x1968  PCM block byte count, channelCount * 128
object +0x196c  LoLa payload capacity before raw frame wrapper
object +0x1fe8  generated-signal/test-source flag
peer stride     0x220 bytes per configured remote peer send slot
peer count      two send slots in the recovered loop
```

Recovered transmit allocation rule:

```text
normal LoLa payload capacity = channelCount * 128 + 0x2a
PCM block byte count         = channelCount * 128
```

Important correction: `0x2a` is 42 decimal, but it is not simply "the LoLa
audio header." The raw network frame builder also prepends a 42-byte
Ethernet/IPv4/UDP wrapper. The live frame is layered like this:

```text
Ethernet + IPv4 + UDP wrapper, 42 bytes
  -> UDP payload: LoLa application fragment
     -> LoLa fragment header, 33 bytes
        -> serialized audio message
           -> uint32 audio sequence
           -> uint32 PCM byte count
           -> PCM block, channelCount * 64 frames * 2 bytes
```

The `channelCount * 128` term is exactly:

```text
channelCount * 64 frames * 2 bytes/sample
```

There is also a fixed-buffer mode:

```text
if AudioTxFixedBuffer-like parent flag is enabled and channelCount < 8:
    LoLa payload capacity = 0x42a
else:
    LoLa payload capacity = channelCount * 128 + 0x2a
```

`0x42a` is:

```text
8 channels * 64 frames * 2 bytes + 42 bytes LoLa-side capacity margin
```

That LoLa-side `+0x2a` closely matches the recovered application payload
overhead:

```text
33-byte fragment header + 8-byte audio message prefix = 41 bytes
```

The remaining byte appears to be capacity slack/alignment in the fragmenter.

So `AudioTxFixedBuffer` appears to pad smaller channel counts up to an
8-channel packet size. This is probably to keep packet size constant across 2,
4, 6, and 8 channel configurations.

The parent flag used by this branch is the loaded `AudioTxFixedBuffer` setting
in the surrounding configuration object. Static evidence proves the flag,
branch, and default; the user-facing reason for the compatibility mode remains
an inference.

Main loop:

```text
while object +0x18ec is true:
    WaitForSingleObject(WriteEvent, INFINITE)
    if running flag was cleared:
        break

    choose source PCM:
        normally object +0x1288, published by callback
        generated-signal buffer if audio-signal/test mode is active

    serialize audio message:
        uint32 sequence counter
        uint32 PCM payload size
        raw PCM payload, channelCount * 128 bytes

    fragment serialized message:
        33-byte LoLa fragment header
        fragment data
        set first fragment byte +0x20 to 1

    for each active remote peer slot:
        build Ethernet/IPv4/UDP frame
        send through pcap_sendpacket

cleanup transmit buffer and peer send state
SetEvent(AudSndThreadEnded)
```

The send loop is event-paced by the audio callback:

- Static fact: `WaitForSingleObject(WriteEvent, INFINITE)` is the pacing point.
- Static fact: the callback writes the active capture pointer before setting
  `WriteEvent`.
- Static fact: the sender does not call PortAudio. It only serializes the most
  recently published PCM block or the generated-signal buffer.
- Static fact: packet transmission goes through `pcap_sendpacket`, not Winsock
  `sendto`.

The binary has control message strings for this generated-signal path:

```text
/MESG_SEND_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d
/MESG_STOP_AUDIO_SIGNAL;SRCIP:%s;DSTIP:%s;SID:%d
```

Function `0x140008b10` generates a synthetic audio buffer and can be substituted
for the live capture block in the send thread. This is consistent with a remote
audio signal/test function.

The control side is now narrower:

- Static fact: `FUN_14001fb60` formats `/MESG_SEND_AUDIO_SIGNAL` and
  `/MESG_STOP_AUDIO_SIGNAL`.
- Static fact: `FUN_14001f390` recognizes the same message names and dispatches
  control/window-message IDs.
- Strong inference: these messages toggle the generated-signal flag consumed by
  the audio send thread.
- Runtime gap: the exact UI gesture and peer-side state transition still need a
  live Windows run or source symbols.

## Audio Packet And Payload Layout

The send thread calls the raw frame builder at `0x140020ba0`. That function
constructs a complete Ethernet + IPv4 + UDP frame into the transmit buffer and
copies the LoLa application payload at offset `0x2a`.

Recovered raw frame layout:

```text
0x00..0x05  destination MAC
0x06..0x0b  source MAC
0x0c..0x0d  EtherType 0x0800
0x0e        IPv4 version/IHL, 0x45
0x0f        IPv4 DSCP/ECN, 0
0x10..0x11  IPv4 total length, htons(LoLaPayloadLen + 0x1c)
0x12..0x13  IPv4 identification, htons(0x1337)
0x14..0x15  IPv4 flags/fragment offset, 0
0x16        IPv4 TTL, 0x80
0x17        IPv4 protocol, 0x11 UDP
0x18..0x19  IPv4 header checksum
0x1a..0x1d  source IPv4 address
0x1e..0x21  destination IPv4 address
0x22..0x23  UDP source port
0x24..0x25  UDP destination port
0x26..0x27  UDP length, htons(LoLaPayloadLen + 8)
0x28..0x29  UDP checksum
0x2a..      LoLa application payload
```

Checksum helpers:

```text
0x140020580  combine two bytes as a big-endian 16-bit word
0x140020a10  compute IPv4 header checksum over offsets 0x0e..0x21
0x140020a80  compute UDP checksum using pseudo-header + UDP header + payload
```

The LoLa application payload is built by the fragmenter at `0x1400070b0` and
received by the reassembler at `0x140007200`.

Recovered LoLa fragment header:

```text
+0x00  magic1              0xfdfdfdfd
+0x04  magic2              0xdfdfdfdf
+0x08  magic3/type         observed sender value 0xeeeeeeee
+0x0c  sequence/id         matched by receiver
+0x10  fragment count      filled into every fragment after build
+0x14  fragment index
+0x18  fragment data offset in reassembled message
+0x1c  fragment data length
+0x20  completion marker   first fragment is explicitly marked 1 in audio send
+0x21  fragment bytes
```

Static receive-side note: the shared receive function also recognizes an
alternate marker value `0xaaaaaaaa` in one branch. The audio sender path above
was observed with `0xeeeeeeee`; the `0xaaaaaaaa` branch is therefore documented
as shared-fragment evidence, not assigned specifically to normal audio.

The audio message inside the fragment bytes is serialized with a small in-memory
writer at `object +0x1948`:

```text
uint32 audio sequence counter, object +0x18e8
uint32 PCM byte count, normally channelCount * 128
int16  PCM samples, interleaved by channel for 64 frames
```

The matching receive-side reader uses the same 32-bit reads before copying the
remaining PCM bytes into the playback ring.

## WinPcap Receive Setup

The peer/session object opens a WinPcap capture handle and applies a BPF filter
before the receive loop.

Relevant strings:

```text
ip and udp
ip and src host %s and dst host %s and (udp port %d or udp port %d)
```

The filtered path is controlled by the `RxPacketFiltering` configuration key.
When enabled, the filter uses:

```text
remote source host
local destination host
audio UDP port
video UDP port
```

The setup function around `0x140017140` calls the WinPcap open/compile/filter
path:

```text
pcap_open(...)
pcap_setmintocopy(...)
pcap_compile(...)
pcap_setfilter(...)
```

`WinPcap_SetMinToCopy` is a configuration key loaded from `LolaGui.ini` and is
passed to the capture handle. This is latency-relevant because WinPcap can
otherwise batch captured bytes before delivering them to the application.

## Network Receive To Playback Ring

Each peer/session object creates named events:

```text
AudioRxEvent%d
AudioVideoRecvThreadEnded%d
```

The session constructor around `0x140014f30` stores:

```text
session +0x300  AudioRxEvent handle
session +0x318  AudioVideoRecvThreadEnded handle
session +0x330  pointer back to the audio object
session +0x348  session/peer index
```

Audio receive logic writes incoming PCM into the audio object's remote playback
ring. Static evidence:

- Receive-side code around `0x1400156e7` copies decoded payload bytes into
  `audioObject + 0xc20 + peerStride + ringIndex`.
- The peer stride is `0x330`.
- The ring depth is 100 slots.
- Function `0x14000aaa0` updates per-peer playback ring offset/index values.
- Calls to `0x14000aaa0` occur from network/receive control paths around
  `0x140029912` and `0x14002d99d`.

Per-peer playback state:

```text
remote ring base      object +0xc20
peer stride           0x330
ring slots per peer   100
ring index modulo     100
per-peer indices      object +0xf40 / +0xf44 region
```

The PortAudio callback consumes these same remote ring slots and clears each
consumed slot with zeroes. If no suitable remote audio block is available, the
callback leaves silence/dropout rather than blocking.

The receive loop starts at `0x1400152d0` and calls `pcap_next_ex` through the
WinPcap thunk at `0x14003616b`.

Recovered receive flow:

```text
pcap_next_ex(captureHandle, &pcapHeader, &packetBytes)
packetBytes + 0x0e                   -> IPv4 header
(ipv4[0] & 0x0f) * 4                 -> IPv4 header length
ipv4 + ipHeaderLength                -> UDP header
ntohs(udp.srcPort)                   -> source port
ntohs(udp.dstPort)                   -> destination port
ntohs(udp.length)                    -> UDP length
udp + 8                              -> LoLa application payload
format source IP as "%d.%d.%d.%d"
compare source IP with expected remote host string
branch by UDP source port
```

For the audio port branch:

```text
expected assembled audio message size = audioChannels * 128 + 8
fragment sequence/id                  = payload + 0x0c
call 0x140006f00 to initialize/reset the audio reassembler
call 0x140007200 to accept the LoLa fragment
call 0x140006e90 to obtain assembled message pointer and length
wrap assembled bytes in reader at 0x140004dd0
read uint32 audio sequence
read uint32 PCM byte count
if PCM byte count is valid:
    copy PCM bytes into the peer's remote playback ring
```

Focused objdump detail:

```text
UDP source/destination port is compared against the configured peer audio port.
source IP string is compared with the expected remote host.
assembled message length must match audioChannels * 128 + 8.
PCM byte count must be nonzero and no larger than the configured audio block.
```

Audio receive counters visible in this branch:

```text
session +0x270  complete audio fragment/message path reached
session +0x274  incomplete/invalid audio message path reached
session +0x278  audio sequence gap counter
session +0x27c  playback-ring realignment/late-placement counter
```

The receive branch has separate video/control logic after the audio branch.
Counters outside this audio block were not assigned audio semantics.

Playback ring insertion:

```text
audioObject = session +0x330
peerIndex   = session +0x348
peerStride  = peerIndex * 0x330
writeIndex  = audioObject + peerStride + 0xf40
delay/offset = audioObject + peerStride + 0xf44

target slot pointer:
    audioObject + 0xc20 + ((peerIndex * 0x66) + writeIndex) * 8

copy PCM bytes into target slot
advance writeIndex modulo 100
```

The code compares incoming sequence numbers and ring positions, but it does not
wait for missing packets. If the packet is missing, late, oversized, or cannot
be placed in the expected ring position, counters increase and playback falls
back to the callback's silence/dropout behavior.

## Connection Negotiation

The binary contains quick-connect message formats:

```text
/MESG_QUICKCONN;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d
/MESG_QUICKCONN_ACK;SRCIP:%s;DSTIP:%s;SID:%d;SR:%d;BPS:%d;CHNLS:%d;FPS:%d;BPP:%d;X:%d;Y:%d;COMP:%d;BAYER:%d
```

Focused Ghidra evidence ties these strings to code, not just data:

```text
FUN_14001fb60  builds QUICKCONN, QUICKCONN_ACK, SEND_AUDIO_SIGNAL, STOP_AUDIO_SIGNAL
FUN_14001f390  parses/dispatches the same control-message names
```

It also contains mismatch diagnostics:

```text
- Number of audio channels doesn't match
- Audio Sampling Rate doesn't match
- Audio Bits Per Sample don't match
```

This confirms that LoLa negotiates exact audio parameters before a session:

- sample rate
- bits per sample
- channel count

The recovered local stream path uses:

```text
sample rate       44100.0 in the inspected open path
bits per sample   16
sample format     signed 16-bit PCM
channels          validated as 2..10 in UI/config strings
block size        64 frames
```

## Audio-Relevant Configuration Inputs

Settings are read from `.\LolaGui.ini` in the loader around `0x14002a6e0`.
The save path around `0x140031d70` writes the same audio/network keys back to
the profile. The audio path uses these keys directly or indirectly:

```text
[General]
LolaPriority

[Audio]
InputAudioDevName
OutputAudioDevName
SamplingRate
NumOfChannels
bitPerSample
AudioIOSuggLat
AudioInputOffset
AudioOutputLevel
AudioBuffersWarning
InputChannels
OutputChannels

[Network]
socketport
audioport
videoport
VideoTxWinPcap
AudioTxFixedBuffer
WinPcap_SetMinToCopy
NicDevName
RxPacketFiltering
VideoPacketSize

[Recording]
RecPref_LocalOutputPath
RecPref_RemoteOutputPath
```

Static defaults visible in the loader include:

```text
SamplingRate           44100.0
NumOfChannels          4
bitPerSample           16
AudioIOSuggLat         5
AudioInputOffset       0
AudioOutputLevel       1.0
AudioBuffersWarning    1
InputChannels          0;1;2;3;4;5;6;7;
OutputChannels         1;3;5;7;
socketport             7000
audioport              19788
videoport              19798
VideoTxWinPcap         1
AudioTxFixedBuffer     1
WinPcap_SetMinToCopy   10
RxPacketFiltering      1
VideoPacketSize        1000
```

`SamplingRate` is loaded and negotiated, but the recovered `Pa_OpenStream` path
still passes the static `44100.0` double constant. That makes live runtime
testing mandatory before claiming Windows 48 kHz compatibility.

Configuration confidence:

- Static fact: the settings above are compiled defaults passed to the profile
  read helpers when no user value is present.
- Static fact: `SamplingRate`, `NumOfChannels`, `bitPerSample`,
  `AudioIOSuggLat`, `AudioInputOffset`, `AudioOutputLevel`, `InputChannels`,
  `OutputChannels`, `socketport`, `audioport`, `videoport`,
  `AudioTxFixedBuffer`, `WinPcap_SetMinToCopy`, and `RxPacketFiltering` are
  also present in the profile-write path.
- Runtime gap: a user-generated `LolaGui.ini` can override these values.

## Recording Workflow

The main GUI records local and remote audio to PCM WAV files through WinMM
`mmio*` APIs.

Relevant strings:

```text
LOLA_REC
_Local.wav
_Remote.wav
%s\%s_Local.wav
%s\%s_Remote.wav
```

WAV format setup around `0x14000999d`:

```text
wFormatTag       1        ; PCM
nChannels        channelCount
wBitsPerSample   16
nSamplesPerSec   44100
nBlockAlign      channelCount * 2
nAvgBytesPerSec  44100 * nBlockAlign
```

The callback is the producer for recording rings:

```text
local recording ring   object +0x1290, 100 slots
remote recording ring  object +0x15b8, 100 slots
```

Local recording thread:

```text
entry wrapper  0x140009bd0
worker         0x140009ad0
event          LocRecThreadEnded, object +0x1fb8
writer object  object +0x1ff0
source ring    object +0x1290
```

Remote recording thread:

```text
entry wrapper  0x14000aa50
worker         0x14000a930
event          RemRecThreadEnded, object +0x1fc0
writer object  object +0x1ff8
source ring    object +0x15b8
```

Both recording threads poll their ring indices, allocate a small block
descriptor, copy one PCM block from the ring, submit it to the WAV writer, and
sleep for 21 ms (`Sleep(0x15)`) when no data is available.

This confirms recording is intentionally outside the real-time callback path.

## WAV Splitter

`LolaWavSplitter_x64.exe` is a separate utility. It imports `mmioRead`,
`mmioDescend`, `mmioWrite`, `mmioCreateChunk`, `mmioAscend`, and `mmioClose`.

Relevant strings:

```text
Lola Wav Splitter - Version 1.0.14
PCM Wav Files (*.wav)|*.wav||
Open wav file
Input file is already mono. The file must contain at least 2 audio channels.
Sample Rate: %d
Bits: %d
Channels: %d
%s_Track_%d.wav
```

Its role is post-processing: read a multichannel PCM WAV recording and write
per-track WAV files. It is not part of the live low-latency audio path.

## Version Comparison

LoLa 1.5 and LoLa 2.0 GUI binaries import the same PortAudio ordinal set and use
the same bundled `portaudio_x64.dll` hash.

Static differences relevant to this pass:

- 1.5 and 2.0 have the same core ASIO/PortAudio architecture.
- The 1.5 CUDA build does not change the audio import surface.
- The 2.0 tester binary has audio receive/status strings but does not import
  PortAudio. It is not a full audio hardware workflow implementation.
- Both inspected GUI generations show the same 44100.0 stream-open constant in
  the recovered path.

## Reconstructed Runtime Workflow

Full normal-session audio workflow:

```text
1. App starts.
2. Audio object initializes critical section and named events.
3. PortAudio initializes.
4. Host APIs are scanned until "ASIO" is found.
5. ASIO devices are listed and their channel counts are recorded.
6. ASIO buffer size is queried with PaAsio_GetAvailableBufferSizes.
7. User/session settings select device, channel count, offsets, and levels.
8. Connection negotiation checks sample rate, bit depth, and channel count.
   The same control cluster can issue generated-audio-signal start/stop
   messages.
9. Pa_OpenStream opens a full-duplex callback stream:
       44100.0 Hz in recovered path
       64 frames per callback
       signed 16-bit PCM
       same channel count for input and output
10. Audio send thread is created.
11. Pa_StartStream starts the callback.
12. Each callback:
       captures 64 frames
       applies capture and monitor gain with simple int16 scaling
       publishes capture block pointer
       wakes WriteEvent
       mixes/plays remote ring audio without waiting
       mirrors blocks into record rings if recording is enabled
13. Audio send thread:
       waits on WriteEvent
       serializes sequence + PCM byte count + PCM block
       wraps serialized bytes in LoLa fragment header
       builds raw Ethernet/IPv4/UDP frame
       sends via pcap_sendpacket to active peers
14. Network receive thread:
       captures packets via pcap_next_ex
       filters/validates expected peer IP and audio UDP port
       reassembles LoLa fragments
       reads sequence + PCM byte count
       validates/realigns sequence and ring placement
       writes PCM payload into 100-slot remote ring
15. Stop/cleanup:
       stops stream
       wakes send thread
       waits for thread-ended events
       terminates PortAudio
       frees rings and recording writers
```

## Performance Interpretation

The design is optimized for musical interaction latency:

- The hardware/driver must provide the actual low-latency guarantee.
- PortAudio is used only as a thin callback gateway to ASIO.
- The callback does constant-size PCM copy and simple integer gain scaling.
- Network send is event-driven from capture completion.
- Network receive writes fixed ring slots.
- Callback playback never waits for a network packet.
- Packet loss or lateness becomes silence/dropout, not added delay.

The tradeoff is exactly what LoLa's design implies:

```text
low latency first
smoothness second
recovery/concealment last
```

## Mac Port Implications

The Mac port should mirror this behavior:

- Use HAL/AUHAL style full-duplex callbacks, not AVFoundation playback queues.
- Target 64-frame callback blocks, with 32-frame hardware buffers where stable.
- Use signed 16-bit PCM compatibility first.
- Keep the audio callback allocation-free, lock-free, and non-blocking.
- Publish capture blocks to a send thread with an event or realtime-safe signal.
- Implement the Windows-compatible payload layering explicitly:
  Ethernet/IP/UDP transport choice aside, the LoLa application payload is a
  fragment header plus `uint32 sequence`, `uint32 PCM byte count`, and raw PCM.
- Treat `AudioTxFixedBuffer` as a compatibility mode that pads LoLa payload
  capacity to the 8-channel class when channel count is below 8.
- Implement receive rings as small fixed rings, not adaptive jitter buffers.
- Make underruns visible as counters/dropouts, not hidden by latency.
- Keep WAV writing and UI work out of the callback.

## Remaining Unknowns

These are the limits of the current static pass:

1. The first 42 bytes of the raw frame are field-labelled as Ethernet, IPv4,
   and UDP, but a live capture is still needed to confirm byte-for-byte behavior
   on a real NIC and driver.
2. The exact original C++ class/function names are not available because symbols
   are stripped.
3. The 48 kHz support path is unresolved. Static strings show 48 kHz awareness,
   but the recovered `Pa_OpenStream` path uses 44100.0.
4. The exact meaning of every receive statistic outside the audio branch is only
   partially labelled.
5. Runtime clock-drift behavior requires a live trace between two peers.
6. The generated-audio-signal path is statically tied to parser/builder strings
   and the send-thread alternate buffer, but its exact UI workflow still needs
   runtime proof.
7. The callback-local gain loop does not show an explicit clamp in the recovered
   block; full overflow behavior should be verified against compiled runtime
   behavior before cloning it intentionally.

None of these unknowns change the main audio architecture: ASIO callback,
64-frame 16-bit PCM blocks, LoLa fragment/message payloads, raw WinPcap
transport, fixed receive rings, no blocking in the callback.

## Evidence Commands

Representative commands used from the repository root:

```sh
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output v2-main -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-ghidra-v15-main -import win-compiled/1-5/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaStaticSummary.java /private/tmp/lola-ghidra-output v15-main -deleteProject
JAVA_HOME=/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home /opt/homebrew/Cellar/ghidra/12.0.4/libexec/support/analyzeHeadless /private/tmp/lola-ghidra-projects lola-audio-deep-v2-main -import win-compiled/2-0/LolaGui_XIMEA_x64.exe -scriptPath /private/tmp/lola-ghidra-scripts -postScript LoLaAudioDeepDive.java /private/tmp/lola-ghidra-output v2-main-focused -deleteProject
file win-compiled/2-0/LolaGui_XIMEA_x64.exe
shasum -a 256 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -p win-compiled/2-0/portaudio_x64.dll
strings -a -n 4 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140007900 --stop-address=0x140007be0 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x1400093a0 --stop-address=0x140009820 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140009be0 --stop-address=0x14000a350 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x14000ac80 --stop-address=0x14000b150 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140014800 --stop-address=0x140015400 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x1400049f0 --stop-address=0x140005050 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140006e40 --stop-address=0x140007280 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x1400152d0 --stop-address=0x140015850 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x1400152d0 --stop-address=0x1400160b6 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140017140 --stop-address=0x1400172d0 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x14001f390 --stop-address=0x14001fe00 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140020580 --stop-address=0x140020d80 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x14002a6e0 --stop-address=0x14002af90 win-compiled/2-0/LolaGui_XIMEA_x64.exe
objdump -d --start-address=0x140031d70 --stop-address=0x140032590 win-compiled/2-0/LolaGui_XIMEA_x64.exe
rg -a -l "AudioTxFixedBuffer|ip and src host|ASIO Buffer size|/MESG_QUICKCONN|/MESG_SEND_AUDIO_SIGNAL" win-compiled
```

Python/LIEF was also used to compare PE imports, timestamps, resources,
signature presence, and v1.5/v2.0 hashes. No generated inventory artifact is
vendored in this repository.

## Static Confidence

High confidence:

- PortAudio ASIO callback design.
- No blocking PortAudio read/write stream.
- 16-bit PCM sample format.
- 64-frame PortAudio callback block.
- 44100.0 in the recovered stream-open path.
- Raw Ethernet/IPv4/UDP frame builder with a 42-byte transport wrapper.
- LoLa application fragment header size and core fields.
- Serialized audio message shape: sequence, PCM byte count, PCM bytes.
- 100-slot rings.
- Event-driven send thread.
- WinPcap `pcap_sendpacket` transmit path and `pcap_next_ex` receive path.
- Separate local and remote WAV recording threads.
- `LolaGui.ini` audio/network settings are both loaded and saved by v2.0.
- Default media ports in the v2.0 loader: control/socket `7000`, audio `19788`,
  video `19798`.

Medium confidence:

- Exact semantic names for all object offsets.
- Fixed-buffer mode controlled by the `AudioTxFixedBuffer` setting.
- Generated audio signal path used for `/MESG_SEND_AUDIO_SIGNAL`.
- No explicit limiter/clamp in the callback-local gain loop.
- Full semantic meaning of receive-side statistics beyond the audio counters.

Needs runtime proof:

- 48 kHz operation.
- Byte-for-byte packet capture against live Windows LoLa.
- Clock-drift and realignment behavior under live network jitter.
