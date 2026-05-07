"""Async LoLa connector skeleton for Linux."""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
import ipaddress
import socket

from .media import (
    Fragment,
    MediaReassembler,
    VideoPrelude,
    build_audio_payload,
    build_video_payloads,
    parse_media_payload,
    parse_serialized_media,
)
from .protocol import (
    DEFAULT_AUDIO_PORT,
    DEFAULT_CONTROL_PORT,
    DEFAULT_VIDEO_PORT,
    MESG_CHAT,
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_DISCONNECT,
    MESG_QUICKCONN,
    MESG_QUICKCONN_ACK,
    MESG_REJECT,
    MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL,
    MediaSettings,
    ControlMessage,
    build_control_datagram,
    build_osc15_control_datagram,
    parse_control_datagram,
)


@dataclass
class Session:
    local_ip: str
    remote_ip: str
    sid: int
    remote_settings: MediaSettings


class LolaConnector:
    def __init__(
        self,
        local_ip: str,
        settings: MediaSettings | None = None,
        control_port: int = DEFAULT_CONTROL_PORT,
        audio_port: int = DEFAULT_AUDIO_PORT,
        video_port: int = DEFAULT_VIDEO_PORT,
        video_packet_size: int = 1000,
        control_dialect: str = "ascii",
    ) -> None:
        self.local_ip = local_ip
        self.settings = settings or MediaSettings()
        self.control_port = control_port
        self.audio_port = audio_port
        self.video_port = video_port
        self.video_packet_size = video_packet_size
        self.control_dialect = control_dialect
        self.session: Session | None = None
        self.audio_signal_requested = False

    def make_udp_socket(self, bind_port: int = 0) -> socket.socket:
        """Create a nonblocking UDP socket bound to LoLa's negotiated local IP.

        Binding media sockets to 19788/19798 is important: Windows LoLa's pcap
        filters and packet parser expect both source and destination stream
        ports to match the configured LoLa audio/video ports.
        """
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if hasattr(socket, "SO_REUSEPORT"):
            try:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
            except OSError:
                pass
        sock.setblocking(False)
        sock.bind((self.local_ip, bind_port))
        return sock

    async def initiate(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> Session:
        sock = self.make_udp_socket(self.control_port)
        try:
            await self._send_control(sock, "MESG_QUICKCONN", remote_ip, sid)
            loop = asyncio.get_running_loop()
            deadline = loop.time() + timeout
            while loop.time() < deadline:
                try:
                    data, addr = await asyncio.wait_for(loop.sock_recvfrom(sock, 4096), timeout=deadline - loop.time())
                except asyncio.TimeoutError:
                    raise TimeoutError("LoLa QuickConn ACK timed out")
                msg = parse_control_datagram(data)
                if msg is None or addr[0] != remote_ip:
                    continue
                if msg.kind == MESG_REJECT:
                    raise RuntimeError(msg.txt or "LoLa rejected QuickConn")
                if msg.kind == MESG_QUICKCONN_ACK:
                    self.session = Session(self.local_ip, remote_ip, sid, MediaSettings.from_fields(msg.fields, self.settings))
                    return self.session
        finally:
            sock.close()
        raise TimeoutError("LoLa QuickConn ACK timed out")

    async def check_status(self, remote_ip: str, sid: int = 0, timeout: float = 2.0) -> bool:
        sock = self.make_udp_socket(self.control_port)
        try:
            if self.control_dialect == "auto":
                await self._send_control(sock, MESG_CHECKLOLASTATUS, remote_ip, sid, dialect="ascii")
                await self._send_control(sock, MESG_CHECKLOLASTATUS, remote_ip, sid, dialect="osc15")
            else:
                await self._send_control(sock, MESG_CHECKLOLASTATUS, remote_ip, sid)
            loop = asyncio.get_running_loop()
            deadline = loop.time() + timeout
            while loop.time() < deadline:
                try:
                    data, addr = await asyncio.wait_for(loop.sock_recvfrom(sock, 4096), timeout=deadline - loop.time())
                except asyncio.TimeoutError:
                    return False
                msg = parse_control_datagram(data)
                if msg is None or addr[0] != remote_ip:
                    continue
                if msg.kind == MESG_CHECKLOLASTATUS_ACK:
                    return True
        finally:
            sock.close()
        return False

    async def accept_once(self) -> Session:
        """Accept one incoming LoLa QuickConn and establish a session."""
        sock = self.make_udp_socket(self.control_port)
        try:
            loop = asyncio.get_running_loop()
            while True:
                data, addr = await loop.sock_recvfrom(sock, 4096)
                msg = parse_control_datagram(data)
                if msg is None:
                    continue
                response_ip = self._message_ip(msg, addr[0])
                if msg.kind == MESG_CHECKLOLASTATUS:
                    await self._send_control(sock, MESG_CHECKLOLASTATUS_ACK, response_ip, msg.sid, dialect=msg.dialect)
                    continue
                if msg.kind != MESG_QUICKCONN:
                    continue
                remote_settings = MediaSettings.from_fields(msg.fields, self.settings)
                if not self.settings.compatible_audio(remote_settings):
                    # Windows LoLa's live reject gate checks audio only:
                    # channel count, sample rate, and bits per sample.
                    print(
                        "rejecting QuickConn: "
                        f"sender={addr[0]} src={msg.src_ip!r} dialect={msg.dialect} "
                        f"remote_settings={remote_settings} local_settings={self.settings}",
                        flush=True,
                    )
                    await self._send_control(sock, MESG_REJECT, response_ip, msg.sid, txt=self._compat_error(remote_settings), dialect=msg.dialect)
                    continue
                remote_ip = response_ip
                ack_settings = self.settings
                if msg.dialect == "osc15":
                    # LoLa 1.5/Tester OSC15 uses a slightly different control
                    # dialect. Keep the ACK conservative and mirror its Bayer
                    # field so legacy peers do not reject immediately.
                    ack_settings = MediaSettings(
                        sample_rate=self.settings.sample_rate,
                        bits_per_sample=self.settings.bits_per_sample,
                        channels=self.settings.channels,
                        fps=self.settings.fps,
                        bits_per_pixel=self.settings.bits_per_pixel,
                        width=self.settings.width,
                        height=self.settings.height,
                        compression=self.settings.compression,
                        bayer=remote_settings.bayer,
                    )
                await self._send_control(sock, MESG_QUICKCONN_ACK, remote_ip, msg.sid, dialect=msg.dialect, settings=ack_settings)
                print(
                    "accepted QuickConn: "
                    f"sender={addr[0]} src={msg.src_ip!r} dialect={msg.dialect} "
                    f"remote_settings={remote_settings}",
                    flush=True,
                )
                self.session = Session(self.local_ip, remote_ip, msg.sid, remote_settings)
                return self.session
        finally:
            sock.close()

    def handle_control_message(self, msg: ControlMessage, sender_ip: str | None = None) -> str:
        """Update local state for non-handshake control messages.

        Returns a small action label so host applications can decide how to
        surface chat, disconnects, and audio test-signal requests.
        """
        remote_ip = msg.src_ip or sender_ip or ""
        if msg.kind == MESG_DISCONNECT:
            if self.session and self.session.remote_ip == remote_ip and self.session.sid == msg.sid:
                self.session = None
            return "disconnect"
        if msg.kind == MESG_SEND_AUDIO_SIGNAL:
            self.audio_signal_requested = True
            return "send_audio_signal"
        if msg.kind == MESG_STOP_AUDIO_SIGNAL:
            self.audio_signal_requested = False
            return "stop_audio_signal"
        if msg.kind == MESG_CHAT:
            return "chat"
        if msg.kind == MESG_CHECKLOLASTATUS_ACK:
            return "status_ack"
        if msg.kind == MESG_REJECT:
            return "reject"
        return "ignore"

    async def _send_control(
        self,
        sock: socket.socket,
        kind: str,
        remote_ip: str,
        sid: int,
        txt: str = "",
        dialect: str | None = None,
        settings: MediaSettings | None = None,
    ) -> None:
        """Send one padded LoLa control datagram in the selected dialect."""
        selected = dialect or self.control_dialect
        if selected == "osc15":
            datagram = build_osc15_control_datagram(
                kind,
                self.local_ip,
                remote_ip,
                sid,
                settings or self.settings,
                txt,
                source_name=socket.gethostname(),
            )
        else:
            datagram = build_control_datagram(kind, self.local_ip, remote_ip, sid, settings or self.settings, txt)
        await asyncio.get_running_loop().sock_sendto(sock, datagram, (remote_ip, self.control_port))

    async def send_control_once(self, kind: str, remote_ip: str, sid: int = 0, txt: str = "") -> None:
        sock = self.make_udp_socket(0)
        try:
            await self._send_control(sock, kind, remote_ip, sid, txt)
        finally:
            sock.close()

    async def send_chat(self, txt: str) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        await self.send_control_once(MESG_CHAT, self.session.remote_ip, self.session.sid, txt)

    async def send_disconnect(self) -> None:
        if self.session is None:
            return
        session = self.session
        await self.send_control_once(MESG_DISCONNECT, session.remote_ip, session.sid)
        self.session = None

    def _compat_error(self, remote: MediaSettings) -> str:
        return (
            "Unable to establish a valid connection due to the following reason(s): "
            f"local audio {self.settings.channels}ch/{self.settings.sample_rate}Hz/"
            f"{self.settings.bits_per_sample}bit, remote audio "
            f"{remote.channels}ch/{remote.sample_rate}Hz/{remote.bits_per_sample}bit."
        )

    def _message_ip(self, msg: ControlMessage, sender_ip: str) -> str:
        try:
            ipaddress.ip_address(msg.src_ip)
        except ValueError:
            return sender_ip
        return msg.src_ip

    async def send_audio(self, pcm: bytes, sequence: int) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        sock = self.make_udp_socket(self.audio_port)
        try:
            await self.send_audio_on_socket(sock, pcm, sequence)
        finally:
            sock.close()

    async def send_video(self, frame: bytes, sequence: int) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        sock = self.make_udp_socket(self.video_port)
        try:
            await self.send_video_on_socket(sock, frame, sequence)
        finally:
            sock.close()

    async def send_audio_on_socket(self, sock: socket.socket, pcm: bytes, sequence: int) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        loop = asyncio.get_running_loop()
        payload = build_audio_payload(sequence, pcm)
        await loop.sock_sendto(sock, payload, (self.session.remote_ip, self.audio_port))

    async def send_video_on_socket(self, sock: socket.socket, frame: bytes, sequence: int) -> None:
        if self.session is None:
            raise RuntimeError("no active LoLa session")
        loop = asyncio.get_running_loop()
        for index, payload in enumerate(build_video_payloads(sequence, frame, packet_size=self.video_packet_size)):
            await loop.sock_sendto(sock, payload, (self.session.remote_ip, self.video_port))
            if index and index % 16 == 0:
                # Raw 640x480 frames are many UDP fragments. Yield so audio can
                # keep its 64-frame cadence while video is being flushed.
                await asyncio.sleep(0)

    async def recv_media_forever(self) -> None:
        audio_sock = self.make_udp_socket(self.audio_port)
        video_sock = self.make_udp_socket(self.video_port)
        audio_reasm = MediaReassembler()
        video_reasm = MediaReassembler()
        try:
            await asyncio.gather(
                self._recv_stream(audio_sock, audio_reasm, "audio"),
                self._recv_stream(video_sock, video_reasm, "video"),
            )
        finally:
            audio_sock.close()
            video_sock.close()

    async def _recv_stream(self, sock: socket.socket, reasm: MediaReassembler, name: str) -> None:
        loop = asyncio.get_running_loop()
        while True:
            payload, addr = await loop.sock_recvfrom(sock, 65535)
            if self.session and addr[0] != self.session.remote_ip:
                continue
            item = parse_media_payload(payload)
            if isinstance(item, VideoPrelude):
                reasm.begin(item.frame_id, item.expected_size, item.fragment_count)
                continue
            if not isinstance(item, Fragment):
                continue
            assembled = reasm.add(item)
            if assembled is None:
                continue
            sequence, media = parse_serialized_media(assembled)
            print(f"{name} seq={sequence} bytes={len(media)} from={addr[0]}")
