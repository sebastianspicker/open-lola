"""Compatibility entry point for the canonical WSL Npcap UDP relay."""

from __future__ import annotations

from importlib import import_module
from pathlib import Path
import sys


_REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
if str(_REPOSITORY_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPOSITORY_ROOT))

_canonical_relay = import_module("linux_connector.deployment.wsl.npcap_udp_relay")

if __name__ == "__main__":
    _canonical_relay.logging.basicConfig(level=_canonical_relay.logging.INFO, format="%(message)s")
    raise SystemExit(_canonical_relay.main())

# Keep legacy imports and monkeypatch targets attached to the canonical module.
sys.modules[__name__] = _canonical_relay
