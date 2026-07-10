# LoLa Linux Connector Documentation

This documentation is organized by reader task. Start here instead of the historical bring-up report unless you specifically need the full investigation record.

## Reader Paths

| Goal | Read |
| --- | --- |
| Run the connector locally or try a synthetic LoLa session | [Quickstart](quickstart.md) |
| Build the same-machine Windows/WSL lab | [WSL Lab Setup](wsl-lab-setup.md) |
| Decide whether interop is actually working | [Windows Validation](windows-validation.md) |
| Understand control, audio, video, ports, and packet shapes | [Protocol Reference](protocol-reference.md) |
| Capture, decode, and prove packet behavior | [Packet Capture](packet-capture.md) |
| Diagnose a failing lab run | [Troubleshooting](troubleshooting.md) |
| Understand the package structure and runtime layers | [Architecture](architecture.md) |
| Continue the production Linux port | [Roadmap](roadmap.md) |
| Review the public-safe reverse-engineering method | [Reverse-Engineering Notes](reverse-engineering-notes.md) |
| Check current completion state and limits | [Status](status.md) |
| Read the condensed 2023-2026 bring-up history | [Project History](project-history.md) |
| Understand licensing and attribution boundaries | [License](../../LICENSE) and [Notices](../../NOTICE) |

## Current Status

The connector is a working LoLa 2.0.0 XIMEA prototype for control-plane interop and synthetic bidirectional audio/video validation. It is not yet a production Linux LoLa application because native low-latency Linux audio/video backends still need to replace the synthetic and subprocess-backed test paths.

The same-machine WSL lab is useful for reproducible validation, but it is a lab harness. A real Linux host over a real or intentionally bridged NIC remains the better production validation target.

## Public Documentation Boundary

Public docs may describe externally observable protocol behavior, packet fields,
byte offsets, command names, validation procedures, and connector source we
wrote. Raw reverse-engineering process output, decompiler text, binary blobs,
extracted resources, and environment-specific captures must never be committed.
