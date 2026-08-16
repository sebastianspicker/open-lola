use std::collections::BTreeMap;

use super::{
    ControlMessage, MediaSettings, ProtocolError, CONTROL_DATAGRAM_SIZE, CONTROL_MESSAGE_KINDS,
    MESG_CHAT, MESG_QUICKCONN, MESG_QUICKCONN_ACK, MESG_REJECT, QUICKCONN_MEDIA_FIELDS,
};

pub fn escape_txt_field(value: &str) -> String {
    value
        .replace('%', "%25")
        .replace(';', "%3B")
        .replace(':', "%3A")
}
pub fn unescape_txt_field(value: &str) -> String {
    let mut output = String::with_capacity(value.len());
    let mut chars = value.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '%' {
            let a = chars.next();
            let b = chars.next();
            match (
                a.map(|c| c.to_ascii_uppercase()),
                b.map(|c| c.to_ascii_uppercase()),
            ) {
                (Some('2'), Some('5')) => output.push('%'),
                (Some('3'), Some('B')) => output.push(';'),
                (Some('3'), Some('A')) => output.push(':'),
                (a, b) => {
                    output.push('%');
                    if let Some(a) = a {
                        output.push(a);
                    }
                    if let Some(b) = b {
                        output.push(b);
                    }
                }
            }
        } else {
            output.push(c);
        }
    }
    output
}

pub fn build_control_text(
    kind: &str,
    src_ip: &str,
    dst_ip: &str,
    sid: u32,
    settings: Option<&MediaSettings>,
    txt: &str,
) -> Result<String, ProtocolError> {
    if !CONTROL_MESSAGE_KINDS.contains(&kind) {
        return Err(ProtocolError::UnknownMessage(kind.into()));
    }
    let prefix = format!("/{kind};SRCIP:{src_ip};DSTIP:{dst_ip};SID:{sid}");
    let text = if matches!(kind, MESG_QUICKCONN | MESG_QUICKCONN_ACK) {
        format!(
            "{prefix};{}",
            settings.cloned().unwrap_or_default().control_fields()
        )
    } else if matches!(kind, MESG_REJECT | MESG_CHAT) {
        format!("{prefix};TXT:{}", escape_txt_field(txt))
    } else {
        format!("{prefix};")
    };
    if !text.is_ascii() {
        return Err(ProtocolError::NonAscii);
    }
    Ok(text)
}
pub fn build_control_datagram(
    kind: &str,
    src_ip: &str,
    dst_ip: &str,
    sid: u32,
    settings: Option<&MediaSettings>,
    txt: &str,
) -> Result<Vec<u8>, ProtocolError> {
    let mut data = build_control_text(kind, src_ip, dst_ip, sid, settings, txt)?.into_bytes();
    if data.len() > CONTROL_DATAGRAM_SIZE {
        return Err(ProtocolError::TooLong);
    }
    data.resize(CONTROL_DATAGRAM_SIZE, 0);
    Ok(data)
}

pub(super) fn parse_control_datagram(data: &[u8]) -> Option<ControlMessage> {
    let raw = data.split(|b| *b == 0).next()?;
    let text = std::str::from_utf8(raw).ok()?;
    if !text.is_ascii() || !text.starts_with("/MESG_") {
        return None;
    }
    let mut tokens = text.split(';');
    let kind = tokens.next()?.strip_prefix('/')?;
    if !CONTROL_MESSAGE_KINDS.contains(&kind) {
        return None;
    }
    let mut fields: BTreeMap<String, String> = BTreeMap::new();
    let mut txt_seen = false;
    for token in tokens {
        if txt_seen {
            return None;
        }
        if let Some((key, value)) = token.split_once(':') {
            if fields.insert(key.into(), value.into()).is_some() {
                return None;
            }
            if key == "TXT" {
                txt_seen = true;
            }
        }
    }
    if matches!(kind, MESG_QUICKCONN | MESG_QUICKCONN_ACK)
        && !QUICKCONN_MEDIA_FIELDS
            .iter()
            .all(|key| fields.contains_key(*key))
    {
        return None;
    }
    let sid = canonical_ascii_sid(fields.get("SID")?)?;
    fields.insert("SID".into(), sid);
    Some(ControlMessage {
        kind: kind.into(),
        fields,
        text: text.into(),
        dialect: "ascii".into(),
    })
}

fn canonical_ascii_sid(raw_sid: &str) -> Option<String> {
    let (negative, digits) = match raw_sid.as_bytes().first() {
        Some(b'+') => (false, &raw_sid[1..]),
        Some(b'-') => (true, &raw_sid[1..]),
        _ => (false, raw_sid),
    };
    if digits.is_empty() || !digits.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    let digits = digits.trim_start_matches('0');
    let digits = if digits.is_empty() { "0" } else { digits };
    Some(if negative && digits != "0" {
        format!("-{digits}")
    } else {
        digits.into()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ascii_is_padded_and_txt_is_safe() {
        let d =
            build_control_datagram(MESG_CHAT, "10.0.0.1", "10.0.0.2", 1, None, "a;b:c%").unwrap();
        assert_eq!(d.len(), 1024);
        let m = crate::protocol::parse_control_datagram(&d).unwrap();
        assert_eq!(m.txt(), "a;b:c%");
    }
}
