"""LoLa UDP control-plane messages.

Static RE shows LoLa sends padded 1024-byte ASCII datagrams on UDP 7000.
The parser tokenizes on semicolons and does not escape semicolons in TXT.
"""

from __future__ import annotations

from dataclasses import dataclass
import struct


DEFAULT_CONTROL_PORT = 7000
DEFAULT_AUDIO_PORT = 19788
DEFAULT_VIDEO_PORT = 19798
CONTROL_DATAGRAM_SIZE = 0x400

MESG_QUICKCONN = "MESG_QUICKCONN"
MESG_DISCONNECT = "MESG_DISCONNECT"
MESG_REJECT = "MESG_REJECT"
MESG_QUICKCONN_ACK = "MESG_QUICKCONN_ACK"
MESG_CHECKLOLASTATUS = "MESG_CHECKLOLASTATUS"
MESG_CHECKLOLASTATUS_ACK = "MESG_CHECKLOLASTATUS_ACK"
MESG_SWITCH_ON_BB = "MESG_SWITCH_ON_BB"
MESG_SWITCH_OFF_BB = "MESG_SWITCH_OFF_BB"
MESG_CHAT = "MESG_CHAT"
MESG_SEND_AUDIO_SIGNAL = "MESG_SEND_AUDIO_SIGNAL"
MESG_STOP_AUDIO_SIGNAL = "MESG_STOP_AUDIO_SIGNAL"

CONTROL_MESSAGE_KINDS = {
    MESG_QUICKCONN,
    MESG_DISCONNECT,
    MESG_REJECT,
    MESG_QUICKCONN_ACK,
    MESG_CHECKLOLASTATUS,
    MESG_CHECKLOLASTATUS_ACK,
    MESG_SWITCH_ON_BB,
    MESG_SWITCH_OFF_BB,
    MESG_CHAT,
    MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL,
}


@dataclass(frozen=True)
class MediaSettings:
    """AV settings carried in QuickConn/ACK control messages."""

    sample_rate: int = 44100
    bits_per_sample: int = 16
    channels: int = 2
    fps: int = 25
    bits_per_pixel: int = 8
    width: int = 640
    height: int = 480
    compression: int = 0
    bayer: int = 0

    @classmethod
    def from_fields(cls, fields: dict[str, str], defaults: "MediaSettings | None" = None) -> "MediaSettings":
        base = defaults or cls()

        def number(key: str, current: int) -> int:
            value = fields.get(key)
            if value is None or value == "":
                return current
            try:
                return int(float(value))
            except ValueError:
                return 0

        return cls(
            sample_rate=number("SR", base.sample_rate),
            bits_per_sample=number("BPS", base.bits_per_sample),
            channels=number("CHNLS", base.channels),
            fps=number("FPS", base.fps),
            bits_per_pixel=number("BPP", base.bits_per_pixel),
            width=number("X", base.width),
            height=number("Y", base.height),
            compression=number("COMP", base.compression),
            bayer=number("BAYER", base.bayer),
        )

    def compatible_audio(self, other: "MediaSettings") -> bool:
        """Match Windows LoLa's observed QuickConn compatibility gate."""
        return (
            self.channels == other.channels
            and self.sample_rate == other.sample_rate
            and self.bits_per_sample == other.bits_per_sample
        )

    def control_fields(self) -> str:
        return (
            f"SR:{self.sample_rate};BPS:{self.bits_per_sample};CHNLS:{self.channels};"
            f"FPS:{self.fps};BPP:{self.bits_per_pixel};X:{self.width};Y:{self.height};"
            f"COMP:{self.compression};BAYER:{self.bayer}"
        )


@dataclass(frozen=True)
class ControlMessage:
    kind: str
    fields: dict[str, str]
    text: str
    dialect: str = "ascii"

    @property
    def src_ip(self) -> str:
        return self.fields.get("SRCIP", "")

    @property
    def dst_ip(self) -> str:
        return self.fields.get("DSTIP", "")

    @property
    def sid(self) -> int:
        try:
            return int(self.fields.get("SID", "0"))
        except ValueError:
            return 0

    @property
    def media(self) -> MediaSettings:
        return MediaSettings.from_fields(self.fields)

    @property
    def txt(self) -> str:
        return self.fields.get("TXT", "")


def parse_control_datagram(data: bytes) -> ControlMessage | None:
    """Parse either LoLa 2.0 ASCII control or the older OSC15 dialect."""
    osc = parse_osc15_control_datagram(data)
    if osc is not None:
        return osc
    text = data.split(b"\0", 1)[0].decode("ascii", errors="ignore")
    if not text.startswith("/MESG_"):
        return None

    tokens = text.split(";")
    kind = tokens[0][1:]
    fields: dict[str, str] = {}
    for token in tokens[1:]:
        if ":" not in token:
            continue
        key, value = token.split(":", 1)
        fields[key] = value
    return ControlMessage(kind=kind, fields=fields, text=text)


def _osc_pad_size(length: int) -> int:
    return (length + 3) & ~3


def _osc_string(value: str) -> bytes:
    raw = value.encode("ascii", errors="replace") + b"\0"
    return raw.ljust(_osc_pad_size(len(raw)), b"\0")


def _read_osc_string(data: bytes, offset: int) -> tuple[str, int] | None:
    end = data.find(b"\0", offset)
    if end < 0:
        return None
    value = data[offset:end].decode("ascii", errors="ignore")
    return value, _osc_pad_size(end + 1)


def _read_osc_message(data: bytes) -> tuple[str, str, list[object]] | None:
    parsed = _read_osc_string(data, 0)
    if parsed is None:
        return None
    address, offset = parsed
    parsed = _read_osc_string(data, offset)
    if parsed is None:
        return None
    tags, offset = parsed
    if not address.startswith("/MESG_") or not tags.startswith(","):
        return None
    args: list[object] = []
    for tag in tags[1:]:
        if tag == "s":
            parsed = _read_osc_string(data, offset)
            if parsed is None:
                return None
            value, offset = parsed
            args.append(value)
        elif tag == "i":
            if offset + 4 > len(data):
                return None
            args.append(struct.unpack_from(">i", data, offset)[0])
            offset += 4
        elif tag == "d":
            if offset + 8 > len(data):
                return None
            args.append(struct.unpack_from(">d", data, offset)[0])
            offset += 8
        else:
            return None
    return address[1:], tags[1:], args


def parse_osc15_control_datagram(data: bytes) -> ControlMessage | None:
    """Parse the OSC-style control messages seen in LoLa 1.5/Tester builds."""
    payload = data
    if data.startswith(b"#bundle\0"):
        if len(data) < 20:
            return None
        size = struct.unpack_from(">i", data, 16)[0]
        if size <= 0 or 20 + size > len(data):
            return None
        payload = data[20 : 20 + size]
    parsed = _read_osc_message(payload)
    if parsed is None:
        return None
    kind, tags, args = parsed
    fields: dict[str, str] = {}
    if args and isinstance(args[0], str):
        fields["SRCIP"] = args[0]
    if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK} and tags == "sdiisdiiii" and len(args) == 10:
        fields.update(
            {
                "SR": str(int(float(args[1]))),
                "BPS": str(args[2]),
                "CHNLS": str(args[3]),
                "BAYER": "1" if "BAYER" in str(args[4]) else "0",
                "FPS": str(int(float(args[5]))),
                "BPP": str(args[6]),
                "X": str(args[7]),
                "Y": str(args[8]),
                "COMP": str(args[9]),
            }
        )
    elif kind in {MESG_REJECT, MESG_CHAT} and len(args) > 1:
        fields["TXT"] = str(args[1])
    text = f"/{kind} osc15 tags={tags} args={args!r}"
    return ControlMessage(kind=kind, fields=fields, text=text, dialect="osc15")


def build_control_text(kind: str, src_ip: str, dst_ip: str, sid: int = 0, settings: MediaSettings | None = None, txt: str = "") -> str:
    """Build the semicolon-delimited ASCII message before 0x400 padding."""
    if kind not in CONTROL_MESSAGE_KINDS:
        raise ValueError(f"unknown LoLa control message kind: {kind}")
    prefix = f"/{kind};SRCIP:{src_ip};DSTIP:{dst_ip};SID:{sid}"
    if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK}:
        media = settings or MediaSettings()
        return f"{prefix};{media.control_fields()}"
    if kind == MESG_REJECT:
        return f"{prefix};TXT:{txt}"
    if kind == MESG_CHAT:
        return f"{prefix};TXT:{txt}"
    return f"{prefix};"


def build_control_datagram(kind: str, src_ip: str, dst_ip: str, sid: int = 0, settings: MediaSettings | None = None, txt: str = "") -> bytes:
    """Build a Windows LoLa-compatible 1024-byte ASCII UDP payload."""
    raw = build_control_text(kind, src_ip, dst_ip, sid, settings, txt).encode("ascii", errors="replace")
    if len(raw) > CONTROL_DATAGRAM_SIZE:
        raise ValueError(f"control message is too long: {len(raw)} bytes")
    return raw.ljust(CONTROL_DATAGRAM_SIZE, b"\0")


def build_osc15_control_datagram(
    kind: str,
    src_ip: str,
    dst_ip: str,
    sid: int = 0,
    settings: MediaSettings | None = None,
    txt: str = "",
    source_name: str | None = None,
) -> bytes:
    """Build an OSC15 control datagram for LoLa 1.5/Tester experiments."""
    if kind not in CONTROL_MESSAGE_KINDS:
        raise ValueError(f"unknown LoLa control message kind: {kind}")
    media = settings or MediaSettings()
    args: list[tuple[str, object]] = [("s", source_name or src_ip)]
    if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK}:
        args.extend(
            [
                ("d", float(media.sample_rate)),
                ("i", media.bits_per_sample),
                ("i", media.channels),
                ("s", "BAYER" if media.bayer else ""),
                ("d", float(media.fps)),
                ("i", media.bits_per_pixel),
                ("i", media.width),
                ("i", media.height),
                ("i", media.compression),
            ]
        )
    elif kind in {MESG_REJECT, MESG_CHAT}:
        args.append(("s", txt))
    message = _osc_string(f"/{kind}") + _osc_string("," + "".join(tag for tag, _ in args))
    for tag, value in args:
        if tag == "s":
            message += _osc_string(str(value))
        elif tag == "i":
            message += struct.pack(">i", int(value))
        elif tag == "d":
            message += struct.pack(">d", float(value))
    bundle = b"#bundle\0" + struct.pack(">q", 1) + struct.pack(">i", len(message)) + message
    if len(bundle) > CONTROL_DATAGRAM_SIZE:
        raise ValueError(f"control message is too long: {len(bundle)} bytes")
    return bundle


def build_quickconn(src_ip: str, dst_ip: str, sid: int, settings: MediaSettings) -> bytes:
    return build_control_datagram(MESG_QUICKCONN, src_ip, dst_ip, sid, settings)


def build_quickconn_ack(src_ip: str, dst_ip: str, sid: int, settings: MediaSettings) -> bytes:
    return build_control_datagram(MESG_QUICKCONN_ACK, src_ip, dst_ip, sid, settings)


def build_reject(src_ip: str, dst_ip: str, sid: int, txt: str) -> bytes:
    return build_control_datagram(MESG_REJECT, src_ip, dst_ip, sid, txt=txt)


def build_chat(src_ip: str, dst_ip: str, sid: int, txt: str) -> bytes:
    return build_control_datagram(MESG_CHAT, src_ip, dst_ip, sid, txt=txt)
