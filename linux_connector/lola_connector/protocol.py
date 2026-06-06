"""LoLa UDP control-plane messages.

Static RE shows LoLa sends padded 1024-byte ASCII datagrams on UDP 7000. TXT
fields use a small percent-escape layer so semicolon-delimited parsing remains
unambiguous while user-facing text is decoded after parsing.
"""

from __future__ import annotations

from dataclasses import dataclass
import ipaddress
import math
import struct

from .media import AUDIO_UDP_PAYLOAD_SIZE, FRAGMENT_HEADER_SIZE, MAX_MEDIA_FRAME_SIZE

OscArgument = str | int | float


DEFAULT_CONTROL_PORT = 7000
DEFAULT_AUDIO_PORT = 19788
DEFAULT_VIDEO_PORT = 19798
CONTROL_DATAGRAM_SIZE = 0x400
QUICKCONN_TAG_SEQUENCE = "sdiisdiiii"
QUICKCONN_MEDIA_FIELD_KEYS = {"SR", "BPS", "CHNLS", "FPS", "BPP", "X", "Y", "COMP", "BAYER"}
MAX_SAMPLE_RATE_HZ = 384_000
MAX_FRAME_RATE = 240
MAX_DIMENSION_PIXELS = 8_192
MAX_AUDIO_BLOCK_BYTES = AUDIO_UDP_PAYLOAD_SIZE - FRAGMENT_HEADER_SIZE - 8

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

    def __post_init__(self) -> None:
        self.validate()

    @classmethod
    def from_fields(cls, fields: dict[str, str], defaults: "MediaSettings | None" = None) -> "MediaSettings":
        base = defaults or cls()

        def number(key: str, current: int) -> int:
            value = fields.get(key)
            if value is None or value == "":
                return current
            try:
                numeric = float(value)
                if not math.isfinite(numeric) or not numeric.is_integer():
                    raise ValueError
                return int(numeric)
            except (OverflowError, ValueError) as exc:
                raise ValueError(f"invalid numeric media field {key}={value!r}") from exc

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

    def validate(self) -> None:
        require_int_range("sample_rate", self.sample_rate, 1, MAX_SAMPLE_RATE_HZ)
        require_member("bits_per_sample", self.bits_per_sample, {8, 16, 24, 32})
        require_int_range("channels", self.channels, 1, 64)
        require_int_range("fps", self.fps, 1, MAX_FRAME_RATE)
        require_member("bits_per_pixel", self.bits_per_pixel, {8, 16, 24, 32})
        require_int_range("width", self.width, 1, MAX_DIMENSION_PIXELS)
        require_int_range("height", self.height, 1, MAX_DIMENSION_PIXELS)
        require_member("compression", self.compression, {0, 1})
        require_member("bayer", self.bayer, {0, 1})
        bytes_per_sample = max(1, self.bits_per_sample // 8)
        audio_block_bytes = self.channels * 64 * bytes_per_sample
        if audio_block_bytes > MAX_AUDIO_BLOCK_BYTES:
            raise ValueError(
                f"invalid media setting audio callback block: {audio_block_bytes} > {MAX_AUDIO_BLOCK_BYTES}"
            )
        bytes_per_pixel = max(1, self.bits_per_pixel // 8)
        raw_frame_bytes = self.width * self.height * bytes_per_pixel
        if raw_frame_bytes > MAX_MEDIA_FRAME_SIZE:
            raise ValueError(f"invalid media setting raw video frame: {raw_frame_bytes} > {MAX_MEDIA_FRAME_SIZE}")

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
        return unescape_txt_field(self.raw_txt)

    @property
    def raw_txt(self) -> str:
        return self.fields.get("TXT", "")


def parse_control_datagram(data: bytes) -> ControlMessage | None:
    """Parse either LoLa 2.0 ASCII control or the older OSC15 dialect."""
    if len(data) > CONTROL_DATAGRAM_SIZE:
        return None
    osc = parse_osc15_control_datagram(data)
    if osc is not None:
        return osc
    try:
        text = data.split(b"\0", 1)[0].decode("ascii", errors="strict")
    except UnicodeDecodeError:
        return None
    return _parse_ascii_control_text(text)


def _parse_ascii_control_text(text: str) -> ControlMessage | None:
    """Parse the semicolon-delimited ASCII control payload."""
    if not text.startswith("/MESG_"):
        return None

    tokens = text.split(";")
    kind = tokens[0][1:]
    if kind not in CONTROL_MESSAGE_KINDS:
        return None
    fields = _ascii_control_fields(tokens[1:])
    if fields is None:
        return None
    if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK} and not QUICKCONN_MEDIA_FIELD_KEYS.issubset(fields):
        return None
    return ControlMessage(kind=kind, fields=fields, text=text)


def _ascii_control_fields(tokens: list[str]) -> dict[str, str] | None:
    fields: dict[str, str] = {}
    for token in tokens:
        if "TXT" in fields:
            return None
        if ":" not in token:
            continue
        if not _add_ascii_control_field(fields, token):
            return None
    return fields


def _add_ascii_control_field(fields: dict[str, str], token: str) -> bool:
    key, value = token.split(":", 1)
    if key in fields:
        return False
    fields[key] = value
    return True


def escape_txt_field(value: str) -> str:
    """Escape delimiters that would be parsed as additional control fields."""
    return value.replace("%", "%25").replace(";", "%3B").replace(":", "%3A")


def unescape_txt_field(value: str) -> str:
    """Decode the TXT escape layer without reinterpreting decoded percent signs."""
    decoded: list[str] = []
    index = 0
    while index < len(value):
        if value[index] == "%" and index + 2 < len(value):
            escape = value[index + 1 : index + 3].upper()
            if escape == "25":
                decoded.append("%")
                index += 3
                continue
            if escape == "3B":
                decoded.append(";")
                index += 3
                continue
            if escape == "3A":
                decoded.append(":")
                index += 3
                continue
        decoded.append(value[index])
        index += 1
    return "".join(decoded)


def message_ip(msg: ControlMessage, sender_ip: str) -> str:
    """Return a validated message source IP, falling back to the UDP sender."""
    try:
        ipaddress.ip_address(msg.src_ip)
    except ValueError:
        return sender_ip
    return msg.src_ip


def _osc_pad_size(length: int) -> int:
    return (length + 3) & ~3


def _osc_string(value: str) -> bytes:
    raw = value.encode("ascii", errors="strict") + b"\0"
    return raw.ljust(_osc_pad_size(len(raw)), b"\0")


def _read_osc_string(data: bytes, offset: int) -> tuple[str, int] | None:
    end = data.find(b"\0", offset)
    if end < 0:
        return None
    try:
        value = data[offset:end].decode("ascii", errors="strict")
    except UnicodeDecodeError:
        return None
    return value, _osc_pad_size(end + 1)


def _read_osc_message(data: bytes) -> tuple[str, str, list[OscArgument]] | None:
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
    args = _read_osc_arguments(data, offset, tags[1:])
    if args is None:
        return None
    return address[1:], tags[1:], args


def _read_osc_arguments(data: bytes, offset: int, tags: str) -> list[OscArgument] | None:
    args: list[OscArgument] = []
    for tag in tags:
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
    return args


def parse_osc15_control_datagram(data: bytes) -> ControlMessage | None:
    """Parse the OSC-style control messages seen in LoLa 1.5/Tester builds."""
    payload = _osc15_payload(data)
    if payload is None:
        return None
    parsed = _read_osc_message(payload)
    if parsed is None:
        return None
    kind, tags, args = parsed
    fields = _osc15_control_fields(kind, tags, args)
    if fields is None:
        return None
    text = f"/{kind} osc15 tags={tags} args={args!r}"
    return ControlMessage(kind=kind, fields=fields, text=text, dialect="osc15")


def _osc15_control_fields(kind: str, tags: str, args: list[OscArgument]) -> dict[str, str] | None:
    fields = _osc15_base_fields(args)
    if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK}:
        media_fields = _validated_osc15_quickconn_fields(tags, args)
        if media_fields is None:
            return None
        fields.update(media_fields)
    elif kind in {MESG_REJECT, MESG_CHAT} and len(args) > 1:
        fields["TXT"] = str(args[1])
    return fields


def _osc15_base_fields(args: list[OscArgument]) -> dict[str, str]:
    if args and isinstance(args[0], str):
        return {"SRCIP": args[0]}
    return {}


def _validated_osc15_quickconn_fields(tags: str, args: list[OscArgument]) -> dict[str, str] | None:
    if tags != QUICKCONN_TAG_SEQUENCE or len(args) != 10:
        return None
    return _osc15_quickconn_fields(args)


def _osc15_payload(data: bytes) -> bytes | None:
    if not data.startswith(b"#bundle\0"):
        return data
    if len(data) < 20:
        return None
    size = struct.unpack_from(">i", data, 16)[0]
    if size <= 0 or 20 + size > len(data):
        return None
    return data[20 : 20 + size]


def _osc15_quickconn_fields(args: list[OscArgument]) -> dict[str, str] | None:
    try:
        sample_rate = finite_int_arg(args[1])
        frame_rate = finite_int_arg(args[5])
    except ValueError:
        return None
    return {
        "SR": str(sample_rate),
        "BPS": str(args[2]),
        "CHNLS": str(args[3]),
        "BAYER": "1" if "BAYER" in str(args[4]) else "0",
        "FPS": str(frame_rate),
        "BPP": str(args[6]),
        "X": str(args[7]),
        "Y": str(args[8]),
        "COMP": str(args[9]),
    }


def build_control_text(kind: str, src_ip: str, dst_ip: str, sid: int = 0, settings: MediaSettings | None = None, txt: str = "") -> str:
    """Build the semicolon-delimited ASCII message before 0x400 padding."""
    if kind not in CONTROL_MESSAGE_KINDS:
        raise ValueError(f"unknown LoLa control message kind: {kind}")
    prefix = f"/{kind};SRCIP:{src_ip};DSTIP:{dst_ip};SID:{sid}"
    if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK}:
        media = settings or MediaSettings()
        return f"{prefix};{media.control_fields()}"
    if kind == MESG_REJECT:
        return f"{prefix};TXT:{escape_txt_field(txt)}"
    if kind == MESG_CHAT:
        return f"{prefix};TXT:{escape_txt_field(txt)}"
    return f"{prefix};"


def build_control_datagram(kind: str, src_ip: str, dst_ip: str, sid: int = 0, settings: MediaSettings | None = None, txt: str = "") -> bytes:
    """Build a Windows LoLa-compatible 1024-byte ASCII UDP payload."""
    raw = build_control_text(kind, src_ip, dst_ip, sid, settings, txt).encode("ascii", errors="strict")
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
    args = _osc15_control_args(kind, src_ip, settings, txt, source_name)
    message = _encoded_osc15_message(kind, args)
    bundle = b"#bundle\0" + struct.pack(">q", 1) + struct.pack(">i", len(message)) + message
    if len(bundle) > CONTROL_DATAGRAM_SIZE:
        raise ValueError(f"control message is too long: {len(bundle)} bytes")
    return bundle


def _osc15_control_args(
    kind: str,
    src_ip: str,
    settings: MediaSettings | None,
    txt: str,
    source_name: str | None,
) -> list[tuple[str, OscArgument]]:
    media = settings or MediaSettings()
    args: list[tuple[str, OscArgument]] = [("s", source_name or src_ip)]
    if kind in {MESG_QUICKCONN, MESG_QUICKCONN_ACK}:
        args.extend(_osc15_media_args(media))
    elif kind in {MESG_REJECT, MESG_CHAT}:
        args.append(("s", txt))
    return args


def _osc15_media_args(media: MediaSettings) -> list[tuple[str, OscArgument]]:
    return [
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


def _encoded_osc15_message(kind: str, args: list[tuple[str, OscArgument]]) -> bytes:
    message = _osc_string(f"/{kind}") + _osc_string("," + "".join(tag for tag, _ in args))
    for tag, value in args:
        message += _encoded_osc_argument(tag, value)
    return message


def _encoded_osc_argument(tag: str, value: OscArgument) -> bytes:
    if tag == "s":
        return _osc_string(str(value))
    if tag == "i":
        return struct.pack(">i", int(value))
    if tag == "d":
        return struct.pack(">d", float(value))
    raise ValueError(f"unsupported OSC argument tag: {tag}")


def build_quickconn(src_ip: str, dst_ip: str, sid: int, settings: MediaSettings) -> bytes:
    return build_control_datagram(MESG_QUICKCONN, src_ip, dst_ip, sid, settings)


def build_quickconn_ack(src_ip: str, dst_ip: str, sid: int, settings: MediaSettings) -> bytes:
    return build_control_datagram(MESG_QUICKCONN_ACK, src_ip, dst_ip, sid, settings)


def build_reject(src_ip: str, dst_ip: str, sid: int, txt: str) -> bytes:
    return build_control_datagram(MESG_REJECT, src_ip, dst_ip, sid, txt=txt)


def build_chat(src_ip: str, dst_ip: str, sid: int, txt: str) -> bytes:
    return build_control_datagram(MESG_CHAT, src_ip, dst_ip, sid, txt=txt)


def finite_int_arg(value: OscArgument) -> int:
    try:
        numeric = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"invalid OSC numeric argument: {value!r}") from exc
    if not math.isfinite(numeric) or not numeric.is_integer():
        raise ValueError(f"invalid OSC numeric argument: {value!r}")
    return int(numeric)


def require_int_range(name: str, value: int, minimum: int, maximum: int) -> None:
    if value < minimum or value > maximum:
        raise ValueError(f"invalid media setting {name}: {value}")


def require_member(name: str, value: int, allowed: set[int]) -> None:
    if value not in allowed:
        raise ValueError(f"invalid media setting {name}: {value}")
