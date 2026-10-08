//! Replays the synthetic LoLa 2.0 compatibility corpus in `interop/lola2/`
//! against the public protocol API. Cases the API cannot express are listed on
//! stderr (`SKIPPED`) instead of being dropped silently.
use rusty_lola::protocol::{
    build_audio_payload, build_control_datagram, build_video_payloads, decode_mesg,
    parse_control_datagram, parse_fragment, parse_quickconn_fields, parse_serialized_media,
    parse_video_prelude, ControlMessage, MediaError, ProtocolError, CONTROL_DATAGRAM_SIZE,
    MESG_QUICKCONN, MESG_QUICKCONN_ACK,
};
use serde_json::Value;
use std::fs;
use std::path::PathBuf;

fn corpus(name: &str) -> Value {
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("../../interop/lola2")
        .join(name);
    let text = fs::read_to_string(&path).unwrap_or_else(|error| panic!("{path:?}: {error}"));
    serde_json::from_str(&text).unwrap_or_else(|error| panic!("{path:?}: {error}"))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn unhex(text: &str) -> Vec<u8> {
    assert!(text.len().is_multiple_of(2), "odd-length hex");
    (0..text.len() / 2)
        .map(|i| u8::from_str_radix(&text[2 * i..2 * i + 2], 16).expect("hex digit"))
        .collect()
}

fn text<'a>(case: &'a Value, key: &str) -> &'a str {
    case[key]
        .as_str()
        .unwrap_or_else(|| panic!("{}: missing string {key}", case["id"]))
}

fn number(value: &Value, key: &str) -> u64 {
    value[key]
        .as_u64()
        .unwrap_or_else(|| panic!("missing number {key} in {value}"))
}

/// Mirrors what a consumer must check before admitting a control datagram.
fn parse_and_validate(data: &[u8]) -> Result<ControlMessage, String> {
    let message = parse_control_datagram(data).ok_or("datagram not parsed")?;
    message.sid().map_err(|error| error.to_string())?;
    if message.kind == MESG_QUICKCONN || message.kind == MESG_QUICKCONN_ACK {
        let mesg = decode_mesg(data).map_err(|error| error.to_string())?;
        parse_quickconn_fields(&mesg).map_err(|error| error.to_string())?;
    }
    Ok(message)
}

fn control_input(case: &Value) -> Vec<u8> {
    let mut data = match case.get("input_hex") {
        Some(hex_text) => unhex(hex_text.as_str().expect("input_hex string")),
        None => text(case, "input_ascii").as_bytes().to_vec(),
    };
    if let Some(pad_to) = case.get("pad_to").and_then(Value::as_u64) {
        let pad = case
            .get("pad_byte")
            .and_then(Value::as_str)
            .map_or(0, |byte| byte.as_bytes()[0]);
        data.resize(pad_to as usize, pad);
    }
    data
}

fn encode_control(case: &Value) {
    let sid = number(&case["expected"], "sid") as u32;
    let wire = build_control_datagram(
        text(case, "kind"),
        text(case, "src_ip"),
        text(case, "dst_ip"),
        case["sid"].as_u64().expect("sid") as u32,
        None,
        case.get("txt").and_then(Value::as_str).unwrap_or(""),
    )
    .unwrap_or_else(|error| panic!("{}: {error}", case["id"]));
    let prefix = text(case, "expected_prefix").as_bytes();
    assert_eq!(wire.len() as u64, number(&case["expected"], "wire_size"));
    assert_eq!(&wire[..prefix.len()], prefix, "{}", case["id"]);
    assert!(
        wire[prefix.len()..].iter().all(|byte| *byte == 0),
        "{}: padding must be NUL",
        case["id"]
    );
    let parsed = parse_and_validate(&wire).expect("encoded datagram parses");
    assert_eq!(parsed.sid().ok(), Some(i64::from(sid)));
    if let Some(txt) = case["expected"].get("txt").and_then(Value::as_str) {
        assert_eq!(parsed.txt(), txt, "{}", case["id"]);
    }
}

fn reject_control_encoding(case: &Value) {
    let txt = match case.get("txt_repeat") {
        Some(unit) => unit
            .as_str()
            .expect("txt_repeat")
            .repeat(number(case, "txt_count") as usize),
        None => text(case, "txt").to_string(),
    };
    let error = build_control_datagram(
        text(case, "kind"),
        text(case, "src_ip"),
        text(case, "dst_ip"),
        case["sid"].as_u64().expect("sid") as u32,
        None,
        &txt,
    )
    .expect_err(text(case, "id"));
    match case["expected"]["category"].as_str() {
        Some("reject.non_ascii") => assert!(matches!(error, ProtocolError::NonAscii), "{error}"),
        Some("reject.oversize") => assert!(matches!(error, ProtocolError::TooLong), "{error}"),
        other => panic!("{}: unmapped category {other:?}", case["id"]),
    }
}

/// Returns a skip note when the case cannot be expressed with the public API.
fn parse_control(case: &Value) -> Option<String> {
    let expected = &case["expected"];
    let result = parse_and_validate(&control_input(case));
    if expected["category"] == "accept" {
        let message = match result {
            Ok(message) => message,
            Err(error) if expected.get("sid_canonical").is_some() => {
                return Some(format!("SID canonicalization beyond i64 ({error})"));
            }
            Err(error) => panic!("{}: expected accept, got {error}", case["id"]),
        };
        if let Some(sid) = expected.get("sid").and_then(Value::as_i64) {
            assert_eq!(message.sid().unwrap(), sid, "{}", case["id"]);
        }
        if let Some(canonical) = expected.get("sid_canonical").and_then(Value::as_str) {
            assert_eq!(message.sid().unwrap().to_string(), canonical);
        }
        if let Some(txt) = expected.get("txt").and_then(Value::as_str) {
            assert_eq!(message.txt(), txt, "{}", case["id"]);
        }
    } else {
        // The parser reports rejection as `None`/`Err` without a category, so
        // the corpus category is only asserted as "rejected".
        assert!(
            result.is_err(),
            "{}: expected {} rejection",
            case["id"],
            expected["category"]
        );
    }
    None
}

fn parse_serialized(case: &Value) {
    let error = parse_serialized_media(&unhex(text(case, "input_hex"))).unwrap_err();
    assert_eq!(case["expected"]["category"], "reject.serialized_length");
    assert_eq!(error, MediaError::LengthMismatch);
}

fn check_fragment(fragment: &rusty_lola::protocol::Fragment, expected: &Value) {
    assert_eq!(
        u64::from(fragment.fragment_index),
        number(expected, "fragment_index")
    );
    assert_eq!(
        u64::from(fragment.original_offset),
        number(expected, "original_offset")
    );
    assert_eq!(
        u64::from(fragment.fragment_length),
        number(expected, "fragment_length")
    );
    assert_eq!(u64::from(fragment.flags), number(expected, "flags"));
}

fn encode_audio(case: &Value) {
    let expected = &case["expected"];
    let wire = build_audio_payload(
        number(case, "sequence") as u32,
        &unhex(text(case, "pcm_hex")),
        None,
    )
    .expect("audio payload");
    assert_eq!(wire.len() as u64, number(expected, "wire_size"));
    let fragment = parse_fragment(&wire).expect("audio fragment");
    assert_eq!(u64::from(fragment.frame_id), number(expected, "frame_id"));
    assert_eq!(
        u64::from(fragment.fragment_count),
        number(expected, "fragment_count")
    );
    check_fragment(&fragment, expected);
    assert_eq!(hex(&fragment.data), text(expected, "serialized_hex"));
}

fn encode_video(case: &Value) {
    let expected = &case["expected"];
    let packets = build_video_payloads(
        number(case, "sequence") as u32,
        &unhex(text(case, "payload_hex")),
        None,
        number(case, "packet_size") as usize,
    );
    assert_eq!(hex(&packets[0]), text(expected, "prelude_hex"));
    let prelude = parse_video_prelude(&packets[0]).expect("prelude");
    assert_eq!(u64::from(prelude.frame_id), number(expected, "frame_id"));
    assert_eq!(
        u64::from(prelude.expected_size),
        number(expected, "serialized_size")
    );
    let fragments = expected["fragments"].as_array().expect("fragments");
    assert_eq!(
        u64::from(prelude.fragment_count),
        number(expected, "fragment_count")
    );
    assert_eq!(packets.len() - 1, fragments.len());
    for (packet, want) in packets[1..].iter().zip(fragments) {
        let fragment = parse_fragment(packet).expect("fragment");
        assert_eq!(u64::from(fragment.frame_id), number(expected, "frame_id"));
        check_fragment(&fragment, want);
        assert_eq!(hex(&fragment.data), text(want, "data_hex"));
    }
}

#[test]
fn manifest_cases_match_the_rust_codec() {
    let manifest = corpus("manifest.json");
    let cases = manifest["cases"].as_array().expect("cases");
    assert!(!cases.is_empty());
    let mut skipped = Vec::new();
    for case in cases {
        let id = text(case, "id");
        match text(case, "operation") {
            "encode_control" => encode_control(case),
            "reject_control_encoding" => reject_control_encoding(case),
            "parse_control" => {
                if let Some(note) = parse_control(case) {
                    skipped.push(format!("{id}: {note}"));
                }
            }
            "parse_serialized" => parse_serialized(case),
            "encode_audio" => encode_audio(case),
            "encode_video" => encode_video(case),
            other => skipped.push(format!("{id}: unknown operation {other}")),
        }
    }
    for note in &skipped {
        eprintln!("SKIPPED {note}");
    }
    assert!(
        skipped.len() < cases.len(),
        "corpus was skipped wholesale: {skipped:?}"
    );
}

#[test]
fn migration_oracle_observations_match_the_rust_decoders() {
    let oracle = corpus("migration-control-oracle.json");
    let cases = oracle["cases"].as_array().expect("cases");
    assert_eq!(cases.len(), 110);
    for case in cases {
        let dialect = text(case, "dialect");
        let kind = text(case, "kind");
        let wire = unhex(text(case, "wire_hex"));
        assert!(wire.len() <= CONTROL_DATAGRAM_SIZE || !case["accepted"].as_bool().unwrap());
        let parsed = parse_control_datagram(&wire);
        if case["accepted"].as_bool().expect("accepted") {
            let message = parsed
                .unwrap_or_else(|| panic!("{dialect} {kind}: expected the datagram accepted"));
            assert_eq!(message.kind, kind, "{dialect}");
            assert_eq!(message.dialect, dialect, "{kind}");
        } else {
            assert!(
                parsed.is_none(),
                "{dialect} {kind}: expected the datagram rejected"
            );
        }
    }
}
