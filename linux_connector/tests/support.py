"""Shared assertions and capability guards for Linux connector tests."""

from __future__ import annotations

import asyncio
from collections.abc import Container
from typing import TypeVar

import pytest

from linux_connector.lola_connector.selftest import loopback_alias_capability
from linux_connector.lola_connector.backends import MemoryAudioPlayback, MemoryVideoDisplay, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.connector_impl import LolaConnector
from linux_connector.lola_connector.protocol import MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime

T = TypeVar("T")


def expect_true(condition: object, label: str | None = None) -> None:
    """Fail when a value is not truthy."""
    if not condition:
        if label is None:
            pytest.fail("expected truthy value")
        pytest.fail(f"{label}: expected truthy value")


def expect_false(condition: object, label: str) -> None:
    """Fail when a value is not falsey."""
    if condition:
        pytest.fail(f"{label}: expected falsey value")


def expect_equal(actual: object, expected: object, label: str | None = None) -> None:
    """Fail when two values differ."""
    if actual != expected:
        if label is None:
            pytest.fail(f"values differ: expected {expected!r}, got {actual!r}")
        pytest.fail(f"{label}: expected {expected!r}, got {actual!r}")


def expect_not_equal(actual: object, expected: object, label: str) -> None:
    """Fail when two values are equal."""
    if actual == expected:
        pytest.fail(f"{label}: expected value different from {expected!r}")


def expect_less_than(actual: int, threshold: int, label: str) -> None:
    """Fail when an integer is not below a threshold."""
    if actual >= threshold:
        pytest.fail(f"{label}: expected value less than {threshold}, got {actual}")


def expect_greater_than(actual: int, threshold: int, label: str | None = None) -> None:
    """Fail when an integer is not above a threshold."""
    if actual <= threshold:
        if label is None:
            pytest.fail(f"expected {actual!r} to be greater than {threshold!r}")
        pytest.fail(f"{label}: expected value greater than {threshold}, got {actual}")


def expect_is_none(actual: object, label: str) -> None:
    """Fail when a value is not None."""
    if actual is not None:
        pytest.fail(f"{label}: expected None, got {actual!r}")


def expect_not_none(actual: T | None, label: str) -> T:
    """Return a value or fail when it is None."""
    if actual is None:
        pytest.fail(f"{label}: expected non-None value")
    return actual


def expect_instance(actual: object, expected_type: type[T], label: str) -> T:
    """Return a value or fail when it has the wrong type."""
    if not isinstance(actual, expected_type):
        pytest.fail(f"{label}: expected {expected_type.__name__}, got {type(actual).__name__}")
    return actual


def expect_contains(needle: object, haystack: Container[object], label: str | None = None) -> None:
    """Fail when a container does not include the requested member."""
    if needle not in haystack:
        if label is None:
            pytest.fail(f"expected {needle!r} to be present")
        pytest.fail(f"{label}: expected {needle!r} in {haystack!r}")


def expect_not_contains(needle: str, haystack: str, label: str) -> None:
    """Fail when text contains a forbidden substring."""
    if needle in haystack:
        pytest.fail(f"{label}: expected {needle!r} to be absent from {haystack!r}")


def expect_startswith(actual: str, prefix: str, label: str) -> None:
    """Fail when text does not start with a prefix."""
    if not actual.startswith(prefix):
        pytest.fail(f"{label}: expected {actual!r} to start with {prefix!r}")


def require_loopback_alias(ip: str = "127.0.0.2") -> None:
    """Skip a test when the requested loopback alias is unavailable."""
    available, message = loopback_alias_capability(ip)
    if not available:
        pytest.skip(message)


def expect_log_messages(log_text: str, messages: tuple[str, ...]) -> None:
    """Fail when a captured log omits any expected message."""
    for message in messages:
        expect_contains(message, log_text)


async def receive_payload(payload: bytes, sender: tuple[str, int]) -> tuple[bytes, tuple[str, int]]:
    """Yield once, then return a fixed UDP payload and sender."""
    await asyncio.sleep(0)
    return payload, sender


def runtime_with_session(*, video_display: MemoryVideoDisplay | None = None) -> LolaLinuxRuntime:
    """Create an in-memory runtime with its canonical loopback session configured."""
    settings = MediaSettings(width=16, height=8)
    connector = LolaConnector("127.0.0.1", settings)
    connector.session = Session("127.0.0.1", "127.0.0.2", 1, settings)
    return LolaLinuxRuntime(
        connector,
        SilenceAudioCapture(settings),
        MemoryAudioPlayback(),
        video_display=video_display,
    )
