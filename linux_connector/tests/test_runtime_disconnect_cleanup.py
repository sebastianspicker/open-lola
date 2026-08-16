"""Regression coverage for peer-driven runtime shutdown."""

from __future__ import annotations

import asyncio

from linux_connector.lola_connector.backends import MemoryAudioPlayback, SilenceAudioCapture
from linux_connector.lola_connector.connector import Session
from linux_connector.lola_connector.connector_impl import LolaConnector
from linux_connector.lola_connector.protocol import MESG_DISCONNECT, ControlMessage, MediaSettings
from linux_connector.lola_connector.runtime import LolaLinuxRuntime
from linux_connector.lola_connector.runtime_types import CapturedVideoFrame
from linux_connector.tests.support import expect_is_none


class _CloseableSocket:
    """Provide the narrow socket contract used during runtime teardown."""

    def fileno(self) -> int:
        return -1

    def close(self) -> None:
        return


class _UnusedVideoCapture:
    """Satisfy the video-loop precondition without producing a frame."""

    async def read_frame(self) -> bytes:
        raise AssertionError("the queued frame should be handled by the transmit loop")


def test_peer_disconnect_stops_video_send_waiting_on_captured_frame() -> None:
    """A valid disconnect wins over a video task resumed from its queue wait."""

    async def run() -> None:
        settings = MediaSettings(width=16, height=8)
        connector = LolaConnector("127.0.0.1", settings)
        connector.session = Session("127.0.0.1", "127.0.0.2", 7, settings)
        runtime = LolaLinuxRuntime(
            connector,
            SilenceAudioCapture(settings),
            MemoryAudioPlayback(),
            video_capture=_UnusedVideoCapture(),
        )
        runtime._video_sock = _CloseableSocket()  # type: ignore[assignment]  # pylint: disable=protected-access
        runtime._video_tx_enabled.set()  # pylint: disable=protected-access
        video_task = asyncio.create_task(runtime._video_tx_loop())  # pylint: disable=protected-access
        runtime._tasks.append(video_task)  # pylint: disable=protected-access
        await asyncio.sleep(0)

        disconnect = ControlMessage(
            kind=MESG_DISCONNECT,
            fields={"SRCIP": "127.0.0.2", "SID": "7"},
            text="/MESG_DISCONNECT;SRCIP:127.0.0.2;SID:7",
        )
        runtime._control_handler._apply_control_action(  # pylint: disable=protected-access
            disconnect,
            "127.0.0.2",
        )
        expect_is_none(connector.session, "connector session after peer disconnect")
        runtime._video_tx_queue.put_nowait(  # pylint: disable=protected-access
            CapturedVideoFrame(b"frame", captured_at=asyncio.get_running_loop().time())
        )
        await asyncio.sleep(0)

        await runtime.stop()

    asyncio.run(run())
