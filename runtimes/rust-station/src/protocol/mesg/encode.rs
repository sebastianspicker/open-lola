use std::collections::BTreeMap;

use super::{
    parse_control_datagram, MediaSettings, Mesg, ProtocolError, MESG_QUICKCONN, MESG_QUICKCONN_ACK,
    QUICKCONN_FIELDS,
};

pub fn decode_mesg(payload: impl AsRef<[u8]>) -> Result<Mesg, ProtocolError> {
    let msg = parse_control_datagram(payload.as_ref())
        .ok_or(ProtocolError::BadField("invalid control datagram".into()))?;
    Ok(Mesg {
        name: format!("/{}", msg.kind),
        fields: msg.fields,
    })
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
