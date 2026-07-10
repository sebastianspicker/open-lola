# pylint: disable=missing-function-docstring
"""Shared pytest fixtures for Linux connector tests."""

from __future__ import annotations

import pytest

from linux_connector.lola_connector.selftest import loopback_alias_capability


def pytest_terminal_summary(terminalreporter: pytest.TerminalReporter) -> None:
    _available, message = loopback_alias_capability()
    terminalreporter.write_sep("-", f"loopback alias capability: {message}")


@pytest.fixture
def require_localhost_udp() -> None:
    available, message = loopback_alias_capability("127.0.0.1")
    if not available:
        pytest.skip(message)
