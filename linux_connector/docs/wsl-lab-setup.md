# WSL Lab Setup

Use this page to reproduce the same-machine Windows LoLa to WSL/Linux connector lab.

Procedure type: same-machine WSL lab.

## What This Lab Proves

The WSL lab can prove LoLa 2.0.0 XIMEA control compatibility and synthetic audio/video interop on one Windows machine. It is not a perfect substitute for a real Linux host because WSL/Hyper-V/Npcap delivery can behave differently from a normal NIC.

## Prerequisites

Windows side:

- Windows LoLa 2.0.0 XIMEA extracted locally.
- Npcap installed with WinPcap-compatible mode enabled.
- Wireshark or tshark for packet capture.
- A LoLa-accepted ASIO device. FlexASIO worked in the validated lab; ASIO4ALL was also accepted by regular LoLa.
- Windows firewall rules allowing UDP `7000`, `19788`, and `19798` on the selected adapter.

Linux/WSL side:

- WSL2 Ubuntu.
- Python 3.
- `tcpdump`.
- `scapy` for `tools/lola_packet_decoder.py`.
- This `linux_connector` package under `<LOLA_PACKAGE_DIR>`.

Install common WSL packages:

```bash
sudo apt update
sudo apt install -y python3 python3-pip tcpdump
python3 -m pip install --user scapy
```

## Identify Addresses

Replace every machine-specific value with placeholders in notes and docs:

| Placeholder | Meaning |
| --- | --- |
| `<LOLA_PACKAGE_DIR>` | Directory containing `linux_connector/` |
| `<WINDOWS_WSL_ADAPTER_IP>` | Windows-side `vEthernet (WSL)` address selected by Windows LoLa |
| `<LINUX_LOLA_IP>` | WSL Ubuntu address used by the connector |
| `<WINDOWS_LOLA_IP>` | Windows address that Linux probes or connects to |
| `<NPCAP_ADAPTER_GUID>` | Npcap GUID for the Windows adapter LoLa selected |
| `<TSHARK_INTERFACE_NUMBER>` | tshark interface number for that adapter |

In WSL, find the Linux address:

```bash
ip addr show
```

In Windows PowerShell, inspect WSL-facing adapters:

```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object InterfaceAlias -like '*WSL*'
```

List tshark interfaces:

```powershell
& 'C:\Program Files\Wireshark\tshark.exe' -D
```

## Confirm Npcap Compatibility

Windows LoLa uses legacy WinPcap/Npcap behavior for media. Confirm Npcap compatibility mode:

```powershell
reg query HKLM\SYSTEM\CurrentControlSet\Services\npcap\Parameters /v WinPcapCompatible
```

Expected value:

```text
WinPcapCompatible    REG_DWORD    0x1
```

If the value is `0x0`, rerun the Npcap installer as Administrator and enable WinPcap-compatible mode.

Old WinPcap 4.1.3 did not enumerate the WSL adapter on the validated host. Npcap in WinPcap-compatible mode did.

## Configure Windows LoLa

In Windows LoLa:

- Select the WSL-visible local network interface, usually `vEthernet (WSL)`.
- Set the remote IP to `<LINUX_LOLA_IP>`.
- Match Linux audio settings:
  - `44100` Hz
  - `16` bit
  - `2` channels
- Match synthetic raw video settings:
  - `640 x 480`
  - `8` bit
  - `25` FPS
  - compression `0`
- Open `Tools -> Network Monitor` before running media tests.

Relevant `LolaGui.ini` shape:

```ini
[Audio]
InputAudioDevName=FlexASIO
OutputAudioDevName=FlexASIO
SamplingRate=44100.000000
NumOfChannels=2
bitPerSample=16

[Video]
FrameRate=25.000000
bitPerPixel=8
FrameX=640
FrameY=480
Compression=0

[Network]
socketport=7000
audioport=19788
videoport=19798
VideoTxWinPcap=1
AudioTxFixedBuffer=1
NicDevName=<NPCAP_ADAPTER_GUID>;;
RxPacketFiltering=1
VideoPacketSize=1000
```

Relevant `LastSsn.ssn` shape:

```ini
[RemoteHost]
RemoteIpAddr=<LINUX_LOLA_IP>;0.0.0.0;

[AVBuffers]
RemoteVideoBuffers=0;0;
RemoteAudioBuffers=8;1;
```

In the WSL lab, remote audio buffer `8` stabilized the path and `20` was conservative. Buffer `0` was too strict for the validated WSL timing path.

## Configure FlexASIO

Regular Windows LoLa accepted FlexASIO in the validated lab. A minimal FlexASIO config was:

```toml
backend = "Windows WASAPI"

[input]
suggestedLatencySeconds = 0.01

[output]
suggestedLatencySeconds = 0.01
```

LoLa Tester did not reliably accept the virtual ASIO configuration in the same way, so final audio validation used regular Windows LoLa.

## Run The WSL Probe Script

From Windows PowerShell in `<LOLA_PACKAGE_DIR>`:

```powershell
.\linux_connector\env\windows_probe_from_wsl.ps1 -WindowsIp <WINDOWS_LOLA_IP>
```

With explicit values:

```powershell
.\linux_connector\env\windows_probe_from_wsl.ps1 `
  -WindowsIp <WINDOWS_LOLA_IP> `
  -LocalIp <LINUX_LOLA_IP> `
  -Duration 20 `
  -TestMedia diagnostic
```

From WSL:

```bash
chmod +x linux_connector/env/*.sh
./linux_connector/env/wsl_setup.sh
./linux_connector/env/probe_windows_lola.sh --windows-ip <WINDOWS_LOLA_IP> --local-ip <LINUX_LOLA_IP>
```

## Known WSL Boundary

Linux UDP sent from WSL to Windows can be visible to Windows LoLa when LoLa selects the correct `vEthernet (WSL)` Npcap adapter. Some Windows/Npcap-injected packets can be visible in Windows Npcap captures but absent from WSL `tcpdump`.

Use `env/npcap_udp_relay.py` only for that lab-specific receive gap:

```powershell
python .\linux_connector\env\npcap_udp_relay.py `
  --interface <TSHARK_INTERFACE_NUMBER> `
  --src-ip <WINDOWS_WSL_ADAPTER_IP> `
  --dst-ip <LINUX_LOLA_IP> `
  --audio-port 19788 `
  --video-port 19798
```

Stop the relay when testing direct regular Windows LoLa audio, otherwise duplicated packets can confuse timing analysis.

## Expected Pass Conditions

- Status probe prints `status_ack=1`.
- Windows LoLa accepts QuickConn.
- Windows LoLa displays the moving diagnostic video card.
- Windows LoLa receives complete synthetic audio frames, not just incomplete packets.
- Linux runtime stats show nonzero `audio_rx` and `video_rx` when Windows LoLa is transmitting.

Use [Windows Validation](windows-validation.md) for the formal acceptance gates.
