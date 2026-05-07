# Contributing

Thank you for helping make low-latency music collaboration more accessible.

## Project Boundary

Contributions must be original work or material you have permission to contribute. Do not submit:

- original LoLa binaries, installers, license files, manuals, or extracted resources;
- copied decompiler output or proprietary source reconstruction;
- private reverse-engineering artifacts;
- packet captures containing institution data, public IP addresses, or private session details unless they have been scrubbed and intentionally approved.

## Good Contributions

Useful contributions include:

- connector bug fixes;
- Linux audio/video backend work;
- macOS feasibility work;
- packet decoder improvements;
- reproducible validation notes;
- documentation that helps universities, conservatories, and research labs run lawful interop tests.

## Development Checks

Run the local self-test:

```bash
python -m linux_connector.lola_connector.cli --local-ip 127.0.0.1 selftest --duration 0.25
```

Run tests when `pytest` is installed:

```bash
python -m pytest linux_connector/tests
```
