# Packet Capture

Use this page when GUI counters are not enough and you need packet-level proof.

Procedure type: same-machine WSL lab, real Linux host validation, or troubleshooting.

## Capture Questions

Each capture should answer a specific question:

| Question | Capture point | Filter | Expected proof |
| --- | --- | --- | --- |
| Does control reach the peer? | Windows selected Npcap adapter or Linux NIC | `udp port 7000` | `/MESG_QUICKCONN`, ACK, reject, status messages |
| Does Linux media reach Windows LoLa's pcap path? | Windows selected Npcap adapter | `udp port 19788 or udp port 19798` | Linux source IP and fixed media ports visible |
| Does Windows media reach Linux? | Linux NIC or WSL `eth0` | `udp port 19788 or udp port 19798` | Packets from Windows to `<LINUX_LOLA_IP>` |
| Is WSL dropping Npcap-injected media? | Compare Windows Npcap and WSL `tcpdump` | Same media filters | Present in Windows capture but absent in WSL capture |
| Is audio complete and ordered? | Windows selected adapter | `udp port 19788` | `payload_len=256`, `frag_len=264`, `frame_id=seq+1`, no sequence gaps |
| Is video complete? | Windows selected adapter or Linux NIC | `udp port 19798` | One prelude plus expected fragments for each frame |

## List Windows Adapters

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' -D
```

Use the interface number that corresponds to the adapter selected by Windows LoLa.

## Capture Control Plane

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' `
  -i <TSHARK_INTERFACE_NUMBER> `
  -a duration:10 `
  -f "udp port 7000" `
  -T fields `
  -e frame.time_epoch `
  -e ip.src `
  -e ip.dst `
  -e udp.length `
  -e data.data
```

A successful LoLa 2.0 connection has:

```text
/MESG_QUICKCONN;SRCIP:<WINDOWS_LOLA_IP>;DSTIP:<LINUX_LOLA_IP>;SID:...
/MESG_QUICKCONN_ACK;SRCIP:<LINUX_LOLA_IP>;DSTIP:<WINDOWS_LOLA_IP>;SID:...
```

A settings mismatch has `/MESG_REJECT` with explanatory text.

## Capture Audio Timing

```powershell
$out = Join-Path $env:TEMP 'lola_audio_timing.tsv'
& 'C:\Program Files\Wireshark\tshark.exe' `
  -i <TSHARK_INTERFACE_NUMBER> `
  -a duration:5 `
  -f "udp port 19788" `
  -Y "udp.srcport==19788 && udp.dstport==19788" `
  -T fields `
  -e frame.time_epoch `
  -e ip.src `
  -e udp.payload > $out
```

For a quick manual parse, the important offsets are:

```python
frame_id, count, index, off, frag_len = struct.unpack_from("<IIIII", data, 12)
seq, payload_len = struct.unpack_from("<II", data, 33)
```

Expected audio values:

```text
UDP payload len: 1066
fragment count: 1
fragment index: 0
fragment offset: 0
fragment length: 264
flag: 1
payload_len: 256
frame_id: seq + 1
```

## Decode Packet Captures

Install the packet-capture dependency before using the decoder:

```bash
python -m pip install "open-lola2-linux-connector[pcap]"
```

From a local checkout, use:

```bash
python -m pip install ".[pcap]"
```

Decode a capture:

```bash
python linux_connector/tools/lola_packet_decoder.py <capture.pcapng>
```

From inside `linux_connector/`, use:

```bash
python tools/lola_packet_decoder.py <capture.pcapng>
```

Expected Linux-to-Windows raw 640x480 8-bit video:

```text
lola_video_preludes > 0
prelude_size=307208
complete=True for video frames
```

## Compare Windows Npcap To WSL

This comparison diagnoses the Hyper-V/WSL delivery problem.

On Windows:

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' `
  -i <TSHARK_INTERFACE_NUMBER> `
  -a duration:5 `
  -f "udp and src host <WINDOWS_WSL_ADAPTER_IP> and dst host <LINUX_LOLA_IP> and (port 19788 or port 19798)" `
  -T fields `
  -e frame.time_epoch `
  -e ip.src `
  -e ip.dst `
  -e udp.srcport `
  -e udp.dstport `
  -e udp.length
```

At the same time in WSL:

```bash
timeout 5 tcpdump -i eth0 -tt -n 'udp and src host <WINDOWS_WSL_ADAPTER_IP> and dst host <LINUX_LOLA_IP> and (port 19788 or port 19798)'
```

Interpretation:

- Present in both captures: WSL receives the media directly.
- Present in Windows capture but absent in WSL: use `env/npcap_udp_relay.py` for this lab path.
- Absent in Windows capture: Windows LoLa is not transmitting, selected the wrong adapter, or the filter/IP settings are wrong.

## WSL tcpdump Checks

Audio:

```bash
tcpdump -i eth0 -tt -n -vv udp src port 19788 and dst port 19788
```

Audio/video:

```bash
tcpdump -i eth0 -tt -n -vv 'udp and (port 19788 or port 19798)'
```

If Windows Npcap shows packets but WSL `tcpdump` does not, use the relay path only for that WSL lab receive gap.
