use std::collections::BTreeMap;
use std::net::IpAddr;

use thiserror::Error;

use crate::protocol::media::{AUDIO_UDP_PAYLOAD_SIZE, FRAGMENT_HEADER_SIZE, MAX_MEDIA_FRAME_SIZE};

pub const CONTROL_DATAGRAM_SIZE: usize = 0x400;
pub const DEFAULT_CONTROL_PORT: u16 = 7000;
pub const DEFAULT_AUDIO_PORT: u16 = 19788;
pub const DEFAULT_VIDEO_PORT: u16 = 19798;
pub const QUICKCONN_TAG_SEQUENCE: &str = "sdiisdiiii";
pub const MAX_SAMPLE_RATE_HZ: u32 = 384_000;
pub const MAX_FRAME_RATE: u32 = 240;
pub const MAX_DIMENSION_PIXELS: u32 = 8_192;
pub const MAX_AUDIO_BLOCK_BYTES: usize = AUDIO_UDP_PAYLOAD_SIZE - FRAGMENT_HEADER_SIZE - 8;

pub const MESG_QUICKCONN: &str = "MESG_QUICKCONN";
pub const MESG_DISCONNECT: &str = "MESG_DISCONNECT";
pub const MESG_REJECT: &str = "MESG_REJECT";
pub const MESG_QUICKCONN_ACK: &str = "MESG_QUICKCONN_ACK";
pub const MESG_CHECKLOLASTATUS: &str = "MESG_CHECKLOLASTATUS";
pub const MESG_CHECKLOLASTATUS_ACK: &str = "MESG_CHECKLOLASTATUS_ACK";
pub const MESG_SWITCH_ON_BB: &str = "MESG_SWITCH_ON_BB";
pub const MESG_SWITCH_OFF_BB: &str = "MESG_SWITCH_OFF_BB";
pub const MESG_CHAT: &str = "MESG_CHAT";
pub const MESG_SEND_AUDIO_SIGNAL: &str = "MESG_SEND_AUDIO_SIGNAL";
pub const MESG_STOP_AUDIO_SIGNAL: &str = "MESG_STOP_AUDIO_SIGNAL";

pub const CONTROL_MESSAGE_KINDS: &[&str] = &[
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
];
/// Historical public list. `ACCEPT` and `BOUNCEBACKCONN` remain names only;
/// strict LoLa 2.0 parsing does not accept them as production wire messages.
pub const KNOWN_MESSAGES: &[&str] = &[
    "/MESG_QUICKCONN",
    "/MESG_DISCONNECT",
    "/MESG_REJECT",
    "/MESG_QUICKCONN_ACK",
    "/MESG_CHECKLOLASTATUS",
    "/MESG_CHECKLOLASTATUS_ACK",
    "/MESG_SWITCH_ON_BB",
    "/MESG_SWITCH_OFF_BB",
    "/MESG_CHAT",
    "/MESG_SEND_AUDIO_SIGNAL",
    "/MESG_STOP_AUDIO_SIGNAL",
    "/MESG_ACCEPT",
    "/MESG_BOUNCEBACKCONN",
];
pub const QUICKCONN_FIELDS: &[&str] = &[
    "SRCIP", "DSTIP", "SID", "SR", "BPS", "CHNLS", "FPS", "BPP", "X", "Y", "COMP", "BAYER",
];
pub(super) const QUICKCONN_MEDIA_FIELDS: &[&str] = &[
    "SR", "BPS", "CHNLS", "FPS", "BPP", "X", "Y", "COMP", "BAYER",
];

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ProtocolError {
    #[error("empty message")]
    Empty,
    #[error("control datagram exceeds 1024 bytes")]
    TooLong,
    #[error("control datagram contains non-ASCII data")]
    NonAscii,
    #[error("not a MESG message: {0}")]
    NotMesg(String),
    #[error("unknown LoLa control message: {0}")]
    UnknownMessage(String),
    #[error("bad field {0}")]
    BadField(String),
    #[error("duplicate field {0}")]
    DuplicateField(String),
    #[error("missing field {0}")]
    MissingField(String),
    #[error("message name must start with /MESG_: {0}")]
    BadName(String),
    #[error("not a quickconn message: {0}")]
    NotQuickconn(String),
    #[error("invalid integer field {0}")]
    BadInt(String),
    #[error("invalid media setting {0}")]
    BadMedia(String),
    #[error("invalid OSC15 datagram")]
    BadOsc15,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Mesg {
    pub name: String,
    pub fields: BTreeMap<String, String>,
}
impl Mesg {
    pub fn get_int(&self, key: &str) -> Result<i64, ProtocolError> {
        self.fields
            .get(key)
            .ok_or_else(|| ProtocolError::MissingField(key.into()))?
            .parse()
            .map_err(|_| ProtocolError::BadInt(key.into()))
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ControlMessage {
    pub kind: String,
    pub fields: BTreeMap<String, String>,
    pub text: String,
    pub dialect: String,
}
impl ControlMessage {
    pub fn src_ip(&self) -> &str {
        self.fields.get("SRCIP").map_or("", String::as_str)
    }
    pub fn dst_ip(&self) -> &str {
        self.fields.get("DSTIP").map_or("", String::as_str)
    }
    pub fn sid(&self) -> Result<i64, ProtocolError> {
        self.fields
            .get("SID")
            .ok_or_else(|| ProtocolError::MissingField("SID".into()))?
            .parse()
            .map_err(|_| ProtocolError::BadInt("SID".into()))
    }
    pub fn raw_txt(&self) -> &str {
        self.fields.get("TXT").map_or("", String::as_str)
    }
    pub fn txt(&self) -> String {
        super::unescape_txt_field(self.raw_txt())
    }
    pub fn media(&self) -> Result<MediaSettings, ProtocolError> {
        MediaSettings::from_fields(&self.fields, None)
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MediaSettings {
    pub sample_rate: u32,
    pub bits_per_sample: u32,
    pub channels: u32,
    pub fps: u32,
    pub bits_per_pixel: u32,
    pub width: u32,
    pub height: u32,
    pub compression: u32,
    pub bayer: u32,
}
impl Default for MediaSettings {
    fn default() -> Self {
        Self {
            sample_rate: 44_100,
            bits_per_sample: 16,
            channels: 2,
            fps: 25,
            bits_per_pixel: 8,
            width: 640,
            height: 480,
            compression: 0,
            bayer: 0,
        }
    }
}
impl MediaSettings {
    pub fn validate(&self) -> Result<(), ProtocolError> {
        range("sample_rate", self.sample_rate, 1, MAX_SAMPLE_RATE_HZ)?;
        member("bits_per_sample", self.bits_per_sample, &[8, 16, 24, 32])?;
        range("channels", self.channels, 1, 64)?;
        range("fps", self.fps, 1, MAX_FRAME_RATE)?;
        member("bits_per_pixel", self.bits_per_pixel, &[8, 16, 24, 32])?;
        range("width", self.width, 1, MAX_DIMENSION_PIXELS)?;
        range("height", self.height, 1, MAX_DIMENSION_PIXELS)?;
        member("compression", self.compression, &[0, 1])?;
        member("bayer", self.bayer, &[0, 1])?;
        let audio = self.channels as usize * 64 * (self.bits_per_sample as usize / 8);
        if audio > MAX_AUDIO_BLOCK_BYTES {
            return Err(ProtocolError::BadMedia("audio callback block".into()));
        }
        let video = self.width as usize * self.height as usize * (self.bits_per_pixel as usize / 8);
        if video > MAX_MEDIA_FRAME_SIZE {
            return Err(ProtocolError::BadMedia("raw video frame".into()));
        }
        Ok(())
    }
    pub fn from_fields(
        fields: &BTreeMap<String, String>,
        defaults: Option<&Self>,
    ) -> Result<Self, ProtocolError> {
        let base = defaults.cloned().unwrap_or_default();
        let number = |key: &str, current: u32| -> Result<u32, ProtocolError> {
            match fields.get(key) {
                None => Ok(current),
                Some(v) if v.is_empty() => Ok(current),
                Some(v) => {
                    let n: f64 = v.parse().map_err(|_| ProtocolError::BadMedia(key.into()))?;
                    if !n.is_finite() || n.fract() != 0.0 || n < 0.0 || n > u32::MAX as f64 {
                        Err(ProtocolError::BadMedia(key.into()))
                    } else {
                        Ok(n as u32)
                    }
                }
            }
        };
        let result = Self {
            sample_rate: number("SR", base.sample_rate)?,
            bits_per_sample: number("BPS", base.bits_per_sample)?,
            channels: number("CHNLS", base.channels)?,
            fps: number("FPS", base.fps)?,
            bits_per_pixel: number("BPP", base.bits_per_pixel)?,
            width: number("X", base.width)?,
            height: number("Y", base.height)?,
            compression: number("COMP", base.compression)?,
            bayer: number("BAYER", base.bayer)?,
        };
        result.validate()?;
        Ok(result)
    }
    pub fn control_fields(&self) -> String {
        format!(
            "SR:{};BPS:{};CHNLS:{};FPS:{};BPP:{};X:{};Y:{};COMP:{};BAYER:{}",
            self.sample_rate,
            self.bits_per_sample,
            self.channels,
            self.fps,
            self.bits_per_pixel,
            self.width,
            self.height,
            self.compression,
            self.bayer
        )
    }
}
fn range(name: &str, value: u32, min: u32, max: u32) -> Result<(), ProtocolError> {
    if (min..=max).contains(&value) {
        Ok(())
    } else {
        Err(ProtocolError::BadMedia(name.into()))
    }
}
fn member(name: &str, value: u32, allowed: &[u32]) -> Result<(), ProtocolError> {
    if allowed.contains(&value) {
        Ok(())
    } else {
        Err(ProtocolError::BadMedia(name.into()))
    }
}

pub fn message_ip(msg: &ControlMessage, sender_ip: &str) -> String {
    msg.src_ip()
        .parse::<IpAddr>()
        .map(|_| msg.src_ip().into())
        .unwrap_or_else(|_| sender_ip.into())
}
