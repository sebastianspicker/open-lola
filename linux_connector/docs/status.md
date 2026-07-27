# Status

Use this page to check what is proven and what remains unfinished.

Procedure type: reference.

## Current State

Status date: 2026-07-24.

The connector implements the LoLa 2.0.0 XIMEA control and synthetic media
paths described below. The current revision has local automated coverage and a
localhost self-test. It does not have current reference-peer validation.

Observed in the dated Windows/WSL lab:

- Windows LoLa 2.0 connects to Linux LoLa in WSL.
- Linux LoLa transmits synthetic audio to Windows LoLa.
- Linux LoLa transmits synthetic raw video to Windows LoLa.
- Windows LoLa transmits audio test signal packets that Linux receives and decodes.
- Windows LoLa or LoLa Tester transmits video packets that Linux can receive and decode; one WSL path required the Npcap-to-Winsock relay.
- Audio packet format is correct and complete.

Remaining tuning:

- Windows LoLa is clean with remote audio buffer around `8` or higher on the validated WSL path.
- Buffer `0` is too strict for that WSL timing path.
- Production validation still needs native media backends and intended network hardware.

## Success Criteria Covered

| Requirement | Current evidence |
| --- | --- |
| Command transport and parser behavior understood | Control behavior documented in [Protocol Reference](protocol-reference.md) |
| QuickConn initiate/accept behavior exists | `lola_connector/connector.py` implements initiate and accept paths |
| Audio RX/TX format understood | Audio payload and `frame_id = sequence + 1` documented in [Protocol Reference](protocol-reference.md) |
| Audio encode/decode exists | `lola_connector/media.py` and local tests |
| Video RX/TX format understood | Video prelude/fragments documented in [Protocol Reference](protocol-reference.md) |
| Video encode/decode exists | `lola_connector/media.py` and local tests |
| Runnable Linux connector skeleton exists | CLI modes documented in [Quickstart](quickstart.md) |
| Local verification exists | `tests/test_codec.py` plus CLI `selftest` |
| Live validation procedure exists | [Windows Validation](windows-validation.md) |

## Dated Lab Boundary

The 2026-05-07 Windows/WSL run is historical evidence for an earlier revision,
not proof of the current checkout. It found two environment constraints:

- Windows LoLa media uses Npcap/WinPcap, so packets must arrive on the selected Windows NIC with the expected source IP and ports.
- Some Windows/Npcap-injected media packets were visible to Windows Npcap but
  were not delivered into WSL. `deployment/wsl/npcap_udp_relay.py` is the
  documented lab workaround for that Hyper-V/WSL boundary.

## Not Production Complete Yet

The package still does not include production ALSA/JACK/PipeWire, V4L2, or GStreamer adapters. The connector boundary is ready for those adapters, but the production media layer still needs to be implemented and validated.
