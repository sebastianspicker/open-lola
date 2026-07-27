# Protocol Reference

Use this page when you need the stable behavior-level protocol summary.

Procedure type: reference.

## Ports

LoLa uses three UDP ports:

| Purpose | Port |
| --- | ---: |
| Control | `7000` |
| Audio | `19788` |
| Video | `19798` |

Audio packets use source port `19788` and destination port `19788`.

Video packets use source port `19798` and destination port `19798`.

## Control Plane

LoLa 2.0 uses ASCII `/MESG_*` control messages over ordinary UDP on port `7000`.

Important observed messages:

```text
/MESG_CHECKLOLASTATUS
/MESG_CHECKLOLASTATUS_ACK
/MESG_QUICKCONN
/MESG_QUICKCONN_ACK
/MESG_REJECT
/MESG_DISCONNECT
/MESG_CHAT
/MESG_SEND_AUDIO_SIGNAL
/MESG_STOP_AUDIO_SIGNAL
```

LoLa-originated control datagrams are padded or sent as `0x400` byte UDP payloads. The useful message is the ASCII prefix before NUL padding.

Important fields:

```text
SRCIP, DSTIP, SID, SR, BPS, CHNLS, FPS, BPP, X, Y, COMP, BAYER, TXT
```

The QuickConn acceptance gate checks audio compatibility:

- sample rate
- bits per sample
- channel count

If these do not match, Windows LoLa rejects the session.

## Serialized Media Frame

Audio and video both use the same serialized media body:

```text
uint32_le sequence
uint32_le payload_len
byte[payload_len] payload
```

For audio, `payload` is interleaved PCM. For video, `payload` is raw frame bytes or JPEG bytes depending on negotiated compression.

## Normal Fragment Header

Normal LoLa media fragments begin with a `0x21` byte header:

```text
offset  size  meaning
0x00    4     fd fd fd fd
0x04    4     df df df df
0x08    4     ee ee ee ee
0x0c    4     uint32_le frame_id
0x10    4     uint32_le total_fragment_count
0x14    4     uint32_le fragment_index
0x18    4     uint32_le original_payload_offset
0x1c    4     uint32_le fragment_payload_length
0x20    1     flags; final audio fragment uses 1
0x21    n     serialized media payload fragment
```

## Audio Payload

Working LoLa 2.0 audio packets use one normal LoLa fragment per callback. The Windows Network Monitor reports an audio UDP payload size of `1066` bytes:

```text
0x42a = 1066 bytes
```

For the validated starting configuration:

```text
channels = 2
frames per callback = 64
bytes per sample = 2
pcm_len = 2 * 64 * 2 = 256 bytes
serialized size = 8 + 256 = 264 bytes
```

Critical live-capture rule:

```text
fragment frame_id = serialized sequence + 1
```

Before this rule was implemented, Windows LoLa saw audio packets but counted them as incomplete. After the rule was implemented, Windows counted real Audio RX frames and incomplete packets dropped to zero.

## Audio Timing

The nominal LoLa audio callback cadence for 64 frames at 44100 Hz is:

```text
44100 / 64 = 689.0625 packets per second
64 / 44100 = 1.451 ms per packet
```

Packet structure alone is not enough. In WSL, uneven synthetic packet timing caused Windows LoLa to realign buffers heavily. The validated WSL run used:

```text
--audio-interval-scale 0.92
```

Measured Linux-to-Windows audio on the Windows WSL adapter was about `686.6` packets/sec with no sequence gaps.

## Video Prelude

Before every video frame's normal fragments, LoLa sends a `0x40` byte video prelude:

```text
offset  size  meaning
0x00    4     fd fd fd fd
0x04    4     df df df df
0x08    4     aa aa aa aa
0x10    4     uint32_le frame_id
0x14    4     uint32_le expected serialized payload size
0x1c    4     uint32_le fragment count
```

Then it sends normal `0x21` fragments.

For the raw validation mode:

```text
width = 640
height = 480
bits per pixel = 8
raw frame payload = 640 * 480 = 307200 bytes
serialized size = 307208 bytes
```

## Transport Model

Windows LoLa uses ordinary UDP for control and WinPcap/Npcap-visible UDP-looking packets for audio/video. This matters most in WSL:

- Linux normal UDP from WSL can be visible to Windows LoLa when Windows selects the correct `vEthernet (WSL)` Npcap adapter.
- Some Windows/Npcap-injected media packets are visible in Windows Npcap captures but not delivered into WSL.
- `deployment/wsl/npcap_udp_relay.py` is a lab workaround for that WSL receive
  gap.

On a real Linux host over a normal network path, the relay should not be needed if packets arrive directly.
