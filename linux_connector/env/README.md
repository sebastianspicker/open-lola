# Linux Test Environment For Probing Windows LoLa

The canonical same-machine WSL lab guide is now [../docs/wsl-lab-setup.md](../docs/wsl-lab-setup.md). This file remains as a local helper-script reference for the `env/` directory.

This folder contains a repeatable Linux-side test environment for running `linux-lola` against a Windows LoLa instance on the same machine or LAN.

## Runtime Choice

Preferred for local Windows LoLa probing:

- WSL2 Ubuntu, ideally with mirrored networking if available.
- Windows LoLa should select the NIC that can see WSL/Linux packets. With ordinary WSL2 NAT this may be a `vEthernet (WSL)` adapter.
- Npcap must be installed in WinPcap-compatible mode if Windows LoLa uses legacy `wpcap.dll`. Old WinPcap 4.1.3 did not enumerate `vEthernet (WSL)` on the tested host.

Alternative:

- Docker on a real Linux host using `network_mode: host`.
- Docker Desktop on Windows is less ideal for LoLa media tests because networking is hidden behind VM/NAT layers.
- The Compose service is behind the `host-network-lab` profile because host
  networking is a lab-only mode for real LoLa adapter probing, not a default
  production container posture.

## WSL Setup

From WSL in the repository root:

```bash
chmod +x linux_connector/env/*.sh
./linux_connector/env/wsl_setup.sh
```

Then probe Windows LoLa:

```bash
./linux_connector/env/probe_windows_lola.sh --windows-ip <windows-lola-ip>
```

For same-machine NAT mode, record the local lab values with placeholders:

```text
Windows LoLa selected local IP: <WINDOWS_WSL_ADAPTER_IP>
WSL/Linux local IP: <LINUX_LOLA_IP>
Windows LoLa NicDevName: <NPCAP_ADAPTER_GUID>
```

Confirm Npcap compatibility from elevated or normal PowerShell:

```powershell
reg query HKLM\SYSTEM\CurrentControlSet\Services\npcap\Parameters /v WinPcapCompatible
```

Expected value is `0x1`. If it is `0x0`, rerun the Npcap installer as Administrator with WinPcap-compatible mode enabled.

The script auto-detects the Linux source IP used to reach Windows. Override it if LoLa expects a specific `SRCIP`:

```bash
./linux_connector/env/probe_windows_lola.sh --windows-ip <windows-lola-ip> --local-ip <wsl-ip>
```

## Windows Launcher

From PowerShell on Windows:

```powershell
.\linux_connector\env\windows_probe_from_wsl.ps1 -WindowsIp <windows-lola-ip>
```

Useful options:

```powershell
.\linux_connector\env\windows_probe_from_wsl.ps1 `
  -WindowsIp <windows-lola-ip> `
  -LocalIp <wsl-ip> `
  -Duration 20 `
  -TestMedia diagnostic
```

## Probe Sequence

The probe runner performs:

1. Local Linux bidirectional UDP self-test.
2. `/MESG_CHECKLOLASTATUS` probe against Windows LoLa.
3. QuickConn to Windows LoLa with synthetic diagnostic AV:
   - per-channel audio tones
   - moving raw video test card

## Capture

To capture Linux-side packets:

```bash
./linux_connector/env/probe_windows_lola.sh --windows-ip <windows-lola-ip> --capture lola_probe.pcap
```

Decode LoLa media fragments:

```bash
python lola_packet_decoder.py lola_probe.pcap
```

For the decisive test, also capture on the Windows LoLa-selected Npcap adapter with:

```text
udp port 7000 or udp port 19788 or udp port 19798
```

## Expected Pass Conditions

- Status probe prints `status_ack=1 status_reason=ack`.
- Windows LoLa accepts QuickConn.
- Windows LoLa displays the moving diagnostic video card.
- Windows LoLa receives complete synthetic audio frames, not just incomplete packets.
- Linux runtime stats show nonzero `audio_rx` and `video_rx` when Windows LoLa is transmitting.

The 2026-05-07 same-machine Windows/WSL run passed this gate for LoLa 2.0 synthetic AV/control after the audio `frame_id = sequence + 1` fix, the `--audio-interval-scale 0.92` timing tune, and the optional Npcap UDP relay for Windows-injected packets that Hyper-V did not deliver into WSL. See `../docs/project-history.md` for the condensed history.
