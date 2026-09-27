use std::collections::BTreeMap;

use super::{
    build_control_datagram, parse_control_datagram, MediaSettings, Mesg, ProtocolError,
    CONTROL_MESSAGE_KINDS, MESG_CHAT, MESG_CHECKLOLASTATUS, MESG_CHECKLOLASTATUS_ACK,
    MESG_DISCONNECT, MESG_QUICKCONN, MESG_QUICKCONN_ACK, MESG_REJECT, MESG_SEND_AUDIO_SIGNAL,
    MESG_STOP_AUDIO_SIGNAL, MESG_SWITCH_OFF_BB, MESG_SWITCH_ON_BB, QUICKCONN_FIELDS,
};

pub fn decode_mesg(payload: impl AsRef<[u8]>) -> Result<Mesg, ProtocolError> {
    let msg = parse_control_datagram(payload.as_ref())
        .ok_or(ProtocolError::BadField("invalid control datagram".into()))?;
    Ok(Mesg {
        name: format!("/{}", msg.kind),
        fields: msg.fields,
    })
}
pub fn encode_mesg(name: &str, fields: &[(&str, String)]) -> Result<String, ProtocolError> {
    let name = name.strip_prefix('/').unwrap_or(name);
    let kind = name;
    if !CONTROL_MESSAGE_KINDS.contains(&kind) {
        return Err(ProtocolError::UnknownMessage(kind.into()));
    }
    let mut map = BTreeMap::new();
    for (key, value) in fields {
        if map.insert((*key).into(), value.clone()).is_some() {
            return Err(ProtocolError::DuplicateField((*key).into()));
        }
    }
    let src = map.remove("SRCIP").unwrap_or_default();
    let dst = map.remove("DSTIP").unwrap_or_default();
    let sid = map
        .remove("SID")
        .unwrap_or_default()
        .parse()
        .map_err(|_| ProtocolError::BadInt("SID".into()))?;
    let settings = if matches!(kind, MESG_QUICKCONN | MESG_QUICKCONN_ACK) {
        Some(MediaSettings::from_fields(&map, None)?)
    } else {
        None
    };
    let txt = map.get("TXT").map(String::as_str).unwrap_or("");
    let bytes = build_control_datagram(kind, &src, &dst, sid, settings.as_ref(), txt)?;
    String::from_utf8(bytes).map_err(|_| ProtocolError::NonAscii)
}
fn endpoint(src: &str, dst: &str, sid: i64) -> Vec<(&'static str, String)> {
    vec![
        ("SRCIP", src.into()),
        ("DSTIP", dst.into()),
        ("SID", sid.to_string()),
    ]
}
pub fn encode_check_status(src: &str, dst: &str, sid: i64) -> Result<String, ProtocolError> {
    encode_mesg(MESG_CHECKLOLASTATUS, &endpoint(src, dst, sid))
}
pub fn encode_check_status_ack(src: &str, dst: &str, sid: i64) -> Result<String, ProtocolError> {
    encode_mesg(MESG_CHECKLOLASTATUS_ACK, &endpoint(src, dst, sid))
}
#[allow(clippy::too_many_arguments)]
pub fn encode_quickconn(
    src: &str,
    dst: &str,
    sid: i64,
    sr: i64,
    bps: i64,
    chnls: i64,
    fps: i64,
    bpp: i64,
    x: i64,
    y: i64,
    comp: i64,
    bayer: i64,
) -> Result<String, ProtocolError> {
    encode_quickconn_kind(
        MESG_QUICKCONN,
        src,
        dst,
        sid,
        sr,
        bps,
        chnls,
        fps,
        bpp,
        x,
        y,
        comp,
        bayer,
    )
}
#[allow(clippy::too_many_arguments)]
pub fn encode_quickconn_ack(
    src: &str,
    dst: &str,
    sid: i64,
    sr: i64,
    bps: i64,
    chnls: i64,
    fps: i64,
    bpp: i64,
    x: i64,
    y: i64,
    comp: i64,
    bayer: i64,
) -> Result<String, ProtocolError> {
    encode_quickconn_kind(
        MESG_QUICKCONN_ACK,
        src,
        dst,
        sid,
        sr,
        bps,
        chnls,
        fps,
        bpp,
        x,
        y,
        comp,
        bayer,
    )
}

#[allow(clippy::too_many_arguments)]
fn encode_quickconn_kind(
    kind: &str,
    src: &str,
    dst: &str,
    sid: i64,
    sr: i64,
    bps: i64,
    chnls: i64,
    fps: i64,
    bpp: i64,
    x: i64,
    y: i64,
    comp: i64,
    bayer: i64,
) -> Result<String, ProtocolError> {
    encode_mesg(
        kind,
        &[
            ("SRCIP", src.into()),
            ("DSTIP", dst.into()),
            ("SID", sid.to_string()),
            ("SR", sr.to_string()),
            ("BPS", bps.to_string()),
            ("CHNLS", chnls.to_string()),
            ("FPS", fps.to_string()),
            ("BPP", bpp.to_string()),
            ("X", x.to_string()),
            ("Y", y.to_string()),
            ("COMP", comp.to_string()),
            ("BAYER", bayer.to_string()),
        ],
    )
}
pub fn encode_reject(src: &str, dst: &str, sid: i64, txt: &str) -> Result<String, ProtocolError> {
    encode_mesg(
        MESG_REJECT,
        &[
            ("SRCIP", src.into()),
            ("DSTIP", dst.into()),
            ("SID", sid.to_string()),
            ("TXT", txt.into()),
        ],
    )
}
pub fn encode_disconnect(src: &str, dst: &str, sid: i64) -> Result<String, ProtocolError> {
    encode_mesg(MESG_DISCONNECT, &endpoint(src, dst, sid))
}
pub fn encode_switch_bb(src: &str, dst: &str, sid: i64, on: bool) -> Result<String, ProtocolError> {
    encode_mesg(
        if on {
            MESG_SWITCH_ON_BB
        } else {
            MESG_SWITCH_OFF_BB
        },
        &endpoint(src, dst, sid),
    )
}
pub fn encode_chat(src: &str, dst: &str, sid: i64, txt: &str) -> Result<String, ProtocolError> {
    encode_mesg(
        MESG_CHAT,
        &[
            ("SRCIP", src.into()),
            ("DSTIP", dst.into()),
            ("SID", sid.to_string()),
            ("TXT", txt.into()),
        ],
    )
}
pub fn encode_audio_signal(
    src: &str,
    dst: &str,
    sid: i64,
    start: bool,
) -> Result<String, ProtocolError> {
    encode_mesg(
        if start {
            MESG_SEND_AUDIO_SIGNAL
        } else {
            MESG_STOP_AUDIO_SIGNAL
        },
        &endpoint(src, dst, sid),
    )
}
pub fn encode_accept(_src: &str, _dst: &str, _sid: i64) -> Result<String, ProtocolError> {
    Err(ProtocolError::UnknownMessage(
        "MESG_ACCEPT is not LoLa 2.0".into(),
    ))
}
pub fn encode_bouncebackconn(_src: &str, _dst: &str, _sid: i64) -> Result<String, ProtocolError> {
    Err(ProtocolError::UnknownMessage(
        "MESG_BOUNCEBACKCONN is not LoLa 2.0".into(),
    ))
}
pub fn parse_quickconn_fields(
    msg: &Mesg,
) -> Result<BTreeMap<String, serde_json::Value>, ProtocolError> {
    if msg.name != format!("/{MESG_QUICKCONN}") && msg.name != format!("/{MESG_QUICKCONN_ACK}") {
        return Err(ProtocolError::NotQuickconn(msg.name.clone()));
    }
    MediaSettings::from_fields(&msg.fields, None)?;
    let mut out = BTreeMap::new();
    for key in QUICKCONN_FIELDS {
        let fallback = match *key {
            "DSTIP" => Some(""),
            "SID" => Some("0"),
            _ => None,
        };
        let value = msg
            .fields
            .get(*key)
            .map(String::as_str)
            .or(fallback)
            .ok_or_else(|| ProtocolError::MissingField((*key).into()))?;
        if matches!(*key, "SRCIP" | "DSTIP") {
            out.insert((*key).into(), serde_json::Value::String(value.into()));
        } else {
            out.insert(
                (*key).into(),
                serde_json::json!(value
                    .parse::<i64>()
                    .map_err(|_| ProtocolError::BadInt((*key).into()))?),
            );
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quickconn_wrappers_preserve_their_distinct_wire_kind_and_shared_fields() {
        let fields = [
            ("SRCIP", "10.0.0.1".into()),
            ("DSTIP", "10.0.0.2".into()),
            ("SID", "7".into()),
            ("SR", "48000".into()),
            ("BPS", "24".into()),
            ("CHNLS", "2".into()),
            ("FPS", "50".into()),
            ("BPP", "8".into()),
            ("X", "640".into()),
            ("Y", "480".into()),
            ("COMP", "1".into()),
            ("BAYER", "0".into()),
        ];
        let request = encode_quickconn(
            "10.0.0.1", "10.0.0.2", 7, 48_000, 24, 2, 50, 8, 640, 480, 1, 0,
        )
        .expect("encode request");
        let acknowledgement = encode_quickconn_ack(
            "10.0.0.1", "10.0.0.2", 7, 48_000, 24, 2, 50, 8, 640, 480, 1, 0,
        )
        .expect("encode acknowledgement");

        assert_eq!(request, encode_mesg(MESG_QUICKCONN, &fields).unwrap());
        assert_eq!(
            acknowledgement,
            encode_mesg(MESG_QUICKCONN_ACK, &fields).unwrap()
        );
    }
}
