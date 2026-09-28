use std::collections::BTreeMap;

use super::{
    ControlMessage, MediaSettings, ProtocolError, CONTROL_DATAGRAM_SIZE, CONTROL_MESSAGE_KINDS,
    MESG_CHAT, MESG_QUICKCONN, MESG_QUICKCONN_ACK, MESG_REJECT, QUICKCONN_TAG_SEQUENCE,
};

fn osc_pad_size(length: usize) -> usize {
    (length + 3) & !3
}
fn read_osc_string(data: &[u8], offset: usize) -> Option<(String, usize)> {
    let end = data.get(offset..)?.iter().position(|b| *b == 0)? + offset;
    let text = std::str::from_utf8(&data[offset..end]).ok()?.to_string();
    if !text.is_ascii() {
        return None;
    }
    let next = osc_pad_size(end + 1);
    if next > data.len() || data[end..next].iter().any(|byte| *byte != 0) {
        return None;
    }
    Some((text, next))
}
fn read_osc(data: &[u8]) -> Option<(String, String, Vec<OscValue>, usize)> {
    let (address, offset) = read_osc_string(data, 0)?;
    let (tags, mut offset) = read_osc_string(data, offset)?;
    if !address.starts_with("/MESG_") || !tags.starts_with(',') {
        return None;
    }
    let mut args = Vec::new();
    for tag in tags[1..].chars() {
        let value = match tag {
            's' => {
                let (v, next) = read_osc_string(data, offset)?;
                offset = next;
                OscValue::String(v)
            }
            'i' => {
                let end = offset.checked_add(4)?;
                let v = i32::from_be_bytes(data.get(offset..end)?.try_into().ok()?);
                offset = end;
                OscValue::Int(v)
            }
            'd' => {
                let end = offset.checked_add(8)?;
                let v = f64::from_be_bytes(data.get(offset..end)?.try_into().ok()?);
                offset = end;
                OscValue::Double(v)
            }
            _ => return None,
        };
        args.push(value);
    }
    Some((address[1..].into(), tags[1..].into(), args, offset))
}
#[derive(Debug, Clone)]
enum OscValue {
    String(String),
    Int(i32),
    Double(f64),
}
impl OscValue {
    fn text(&self) -> String {
        match self {
            Self::String(v) => v.clone(),
            Self::Int(v) => v.to_string(),
            Self::Double(v) => v.to_string(),
        }
    }
    fn finite_int(&self) -> Option<u32> {
        let v = match self {
            Self::Int(v) => *v as f64,
            Self::Double(v) => *v,
            Self::String(v) => v.parse().ok()?,
        };
        if v.is_finite() && v.fract() == 0.0 && v >= 0.0 && v <= u32::MAX as f64 {
            Some(v as u32)
        } else {
            None
        }
    }
}
pub fn parse_osc15_control_datagram(data: &[u8]) -> Option<ControlMessage> {
    if data.len() > CONTROL_DATAGRAM_SIZE {
        return None;
    }
    let payload = osc_payload(data)?;
    let (kind, tags, args, consumed) = read_osc(payload)?;
    if consumed != payload.len() || !CONTROL_MESSAGE_KINDS.contains(&kind.as_str()) {
        return None;
    }
    let fields = osc_control_fields(&kind, &tags, &args)?;
    Some(ControlMessage {
        kind: kind.clone(),
        fields,
        text: format!("/{kind} osc15 tags={tags}"),
        dialect: "osc15".into(),
    })
}

fn osc_payload(data: &[u8]) -> Option<&[u8]> {
    if !data.starts_with(b"#bundle\0") {
        return Some(data);
    }
    if data.len() < 20 {
        return None;
    }
    let size = i32::from_be_bytes(data[16..20].try_into().ok()?);
    if size <= 0 {
        return None;
    }
    let end = 20usize.checked_add(size as usize)?;
    (end == data.len()).then(|| &data[20..end])
}

fn osc_control_fields(
    kind: &str,
    tags: &str,
    args: &[OscValue],
) -> Option<BTreeMap<String, String>> {
    let mut fields = BTreeMap::new();
    if let Some(OscValue::String(src)) = args.first() {
        fields.insert("SRCIP".into(), src.clone());
    }
    if matches!(kind, MESG_QUICKCONN | MESG_QUICKCONN_ACK) {
        if tags != QUICKCONN_TAG_SEQUENCE || args.len() != 10 {
            return None;
        }
        let sr = args[1].finite_int()?;
        let fps = args[5].finite_int()?;
        fields.extend([
            (String::from("SR"), sr.to_string()),
            (String::from("BPS"), args[2].text()),
            (String::from("CHNLS"), args[3].text()),
            (
                String::from("BAYER"),
                u32::from(args[4].text().contains("BAYER")).to_string(),
            ),
            (String::from("FPS"), fps.to_string()),
            (String::from("BPP"), args[6].text()),
            (String::from("X"), args[7].text()),
            (String::from("Y"), args[8].text()),
            (String::from("COMP"), args[9].text()),
        ]);
        // Decode wire values independently of supported device/negotiation policy.
        // Callers must validate media() before admitting a session.
    } else if matches!(kind, MESG_REJECT | MESG_CHAT) && args.len() > 1 {
        fields.insert("TXT".into(), args[1].text());
    }
    Some(fields)
}
fn osc_string(value: &str) -> Result<Vec<u8>, ProtocolError> {
    if !value.is_ascii() {
        return Err(ProtocolError::NonAscii);
    }
    let mut out = value.as_bytes().to_vec();
    out.push(0);
    out.resize(osc_pad_size(out.len()), 0);
    Ok(out)
}
pub fn build_osc15_control_datagram(
    kind: &str,
    src_ip: &str,
    _dst_ip: &str,
    _sid: u32,
    settings: Option<&MediaSettings>,
    txt: &str,
    source_name: Option<&str>,
) -> Result<Vec<u8>, ProtocolError> {
    if !CONTROL_MESSAGE_KINDS.contains(&kind) {
        return Err(ProtocolError::UnknownMessage(kind.into()));
    }
    let media = settings.cloned().unwrap_or_default();
    let mut args: Vec<(char, Vec<u8>)> = vec![('s', osc_string(source_name.unwrap_or(src_ip))?)];
    if matches!(kind, MESG_QUICKCONN | MESG_QUICKCONN_ACK) {
        args.extend([
            ('d', (media.sample_rate as f64).to_be_bytes().to_vec()),
            ('i', (media.bits_per_sample as i32).to_be_bytes().to_vec()),
            ('i', (media.channels as i32).to_be_bytes().to_vec()),
            (
                's',
                osc_string(if media.bayer == 1 { "BAYER" } else { "" })?,
            ),
            ('d', (media.fps as f64).to_be_bytes().to_vec()),
            ('i', (media.bits_per_pixel as i32).to_be_bytes().to_vec()),
            ('i', (media.width as i32).to_be_bytes().to_vec()),
            ('i', (media.height as i32).to_be_bytes().to_vec()),
            ('i', (media.compression as i32).to_be_bytes().to_vec()),
        ]);
    } else if matches!(kind, MESG_REJECT | MESG_CHAT) {
        args.push(('s', osc_string(txt)?));
    }
    let tags: String = args.iter().map(|(tag, _)| *tag).collect();
    let mut message = osc_string(&format!("/{kind}"))?;
    message.extend(osc_string(&format!(",{tags}"))?);
    for (_, arg) in args {
        message.extend(arg);
    }
    let mut out = b"#bundle\0".to_vec();
    out.extend_from_slice(&1i64.to_be_bytes());
    out.extend_from_slice(&(message.len() as i32).to_be_bytes());
    out.extend(message);
    if out.len() > CONTROL_DATAGRAM_SIZE {
        return Err(ProtocolError::TooLong);
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn osc15_round_trip() {
        let d = build_osc15_control_datagram(MESG_QUICKCONN, "10.0.0.1", "", 0, None, "", None)
            .unwrap();
        let m = crate::protocol::parse_control_datagram(&d).unwrap();
        assert_eq!(m.dialect, "osc15");
        assert_eq!(m.media().unwrap().sample_rate, 44100);
    }

    #[test]
    fn osc15_rejects_trailing_bundle_elements_and_nonzero_padding() {
        let datagram =
            build_osc15_control_datagram(MESG_CHAT, "10.0.0.1", "", 0, None, "hello", None)
                .unwrap();
        let mut trailing = datagram.clone();
        trailing.extend_from_slice(&[0, 0, 0, 4, 0, 0, 0, 0]);
        assert!(parse_osc15_control_datagram(&trailing).is_none());

        let mut bad_padding = datagram;
        let last = bad_padding.len() - 1;
        if bad_padding[last] == 0 {
            bad_padding[last] = 1;
            assert!(parse_osc15_control_datagram(&bad_padding).is_none());
        }
    }
    #[test]
    fn python_mixed_osc_argument_oracle_and_unknown_tag() {
        let mut message = osc_string("/MESG_QUICKCONN_ACK").unwrap();
        message.extend(osc_string(",sdiisdiiii").unwrap());
        message.extend(osc_string("10.0.0.2").unwrap());
        message.extend(48000_f64.to_be_bytes());
        message.extend(24_i32.to_be_bytes());
        message.extend(2_i32.to_be_bytes());
        message.extend(osc_string("BAYER").unwrap());
        message.extend(60_f64.to_be_bytes());
        for value in [10_i32, 1920, 1080, 1] {
            message.extend(value.to_be_bytes());
        }
        let parsed = parse_osc15_control_datagram(&message).unwrap();
        assert!(
            parsed.media().is_err(),
            "10-bit media remains unsupported by session policy"
        );
        for (key, value) in [
            ("SRCIP", "10.0.0.2"),
            ("SR", "48000"),
            ("BPS", "24"),
            ("BAYER", "1"),
            ("FPS", "60"),
        ] {
            assert_eq!(parsed.fields.get(key).map(String::as_str), Some(value));
        }
        let mut unsupported = osc_string("/MESG_CHECKLOLASTATUS_ACK").unwrap();
        unsupported.extend(osc_string(",x").unwrap());
        assert!(parse_osc15_control_datagram(&unsupported).is_none());
    }
}
