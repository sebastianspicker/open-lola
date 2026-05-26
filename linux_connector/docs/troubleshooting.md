# Troubleshooting

Use this page when a run fails and you need the next evidence-gathering step.

Procedure type: troubleshooting.

## Symptom Guide

| Symptom | Likely cause | Evidence to collect | Fix |
| --- | --- | --- | --- |
| `status_ack=0 status_reason=timeout` | Windows LoLa not reachable on control port | Capture `udp port 7000`; check firewall and `socketport` | Allow UDP `7000`, use correct `<WINDOWS_LOLA_IP>`, verify LoLa is running |
| `status_ack=0 status_reason=malformed-response` or `wrong-peer` | Control packets arrived but were not a valid ACK from the requested peer | Capture `udp port 7000`; compare sender IP and decoded control payload | Use the expected `<WINDOWS_LOLA_IP>` and source IP, or fix the malformed sender |
| QuickConn rejected | Audio settings mismatch | Capture `/MESG_REJECT`; compare `SR`, `BPS`, `CHNLS` | Match sample rate, bits, and channels on both sides |
| Control works but Windows receives no media | Wrong Npcap adapter or source IP mismatch | Capture media ports on Windows selected adapter | Select adapter that sees Linux packets; set remote IP to `<LINUX_LOLA_IP>` |
| Windows sees audio incomplete packets | Wrong audio fragment relationship or stale connector | Decode audio payload offsets | Ensure audio uses `frame_id = sequence + 1` and UDP payload size `1066` |
| Windows realigned buffers rise | Packet timing is too tight or jittery | Measure packet rate and gaps | In WSL, try `--audio-interval-scale 0.92` and remote audio buffer `8` or `20` |
| Video frames incomplete | Missing prelude, wrong packet size, or wrong capture point | Decode video with `tools/lola_packet_decoder.py` | Confirm one `0x40` prelude per frame and complete normal fragments |
| Windows media visible in Npcap but absent in WSL | Hyper-V/WSL delivery gap for Npcap-injected packets | Compare Windows Npcap with WSL `tcpdump` | Use `env/npcap_udp_relay.py` for WSL lab receive validation |
| Linux receives duplicate or odd media | Relay left running during direct receive test | Compare direct packets and relayed packets | Stop relay unless testing the specific WSL delivery gap |
| Real Linux media command hangs | Process backend command not producing or consuming expected bytes | Run the command standalone | Match raw PCM/video format exactly and check stderr outside the connector |

## Control Works, Media Does Not

First prove the packets are on the adapter Windows LoLa selected:

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' `
  -i <TSHARK_INTERFACE_NUMBER> `
  -a duration:10 `
  -f "udp port 19788 or udp port 19798"
```

If packets are absent, the problem is routing, firewall, source IP, or adapter selection.

If packets are present but LoLa ignores them, check:

- source and destination ports are fixed to `19788` for audio and `19798` for video;
- source IP matches the QuickConn `SRCIP`/remote-session expectation;
- Windows LoLa selected the same Npcap adapter that sees the packets;
- audio payloads have `frame_id = sequence + 1`;
- video frames include the `0x40` prelude.

## QuickConn Rejection

The common reject is audio compatibility. Capture control traffic and read the `/MESG_REJECT` text:

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' `
  -i <TSHARK_INTERFACE_NUMBER> `
  -a duration:10 `
  -f "udp port 7000" `
  -T fields `
  -e data.data
```

Then align Linux flags:

```bash
--sr 44100 --bps 16 --channels 2
```

with Windows LoLa's audio configuration.

## Audio Incomplete Packets

Decode a sample audio payload. Expected values:

```text
UDP payload len = 1066
fragment length = 264
serialized pcm length = 256
fragment frame_id = serialized sequence + 1
```

If `frame_id` equals `sequence`, Windows LoLa can see packets but count them incomplete.

## WSL Delivery Gap

Use this only when Windows captures packets but WSL does not:

```powershell
python .\linux_connector\env\npcap_udp_relay.py `
  --interface <TSHARK_INTERFACE_NUMBER> `
  --src-ip <WINDOWS_WSL_ADAPTER_IP> `
  --dst-ip <LINUX_LOLA_IP> `
  --audio-port 19788 `
  --video-port 19798
```

Do not treat the relay as production architecture. It is a WSL lab workaround.

## When To Move To A Real Linux Host

Move off WSL when:

- Windows control and Linux-to-Windows media work, but timing remains marginal;
- WSL captures disagree with Windows captures;
- you are validating production latency;
- you need confidence that Npcap/Hyper-V behavior is not shaping the result.
