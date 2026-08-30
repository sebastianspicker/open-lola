//! Repository-owned LoLa 2.0 wire compatibility corpus coverage.

use rusty_lola::protocol::{
    build_audio_payload, build_video_payloads, encode_mesg, parse_control_datagram, parse_fragment,
    parse_serialized_media, parse_video_prelude,
};
use serde_json::Value;

const CORPUS: &str = include_str!("../../../interop/lola2/manifest.json");

#[test]
fn every_lola2_compatibility_vector_matches() {
    let manifest: Value = serde_json::from_str(CORPUS).expect("valid compatibility corpus JSON");
    assert_eq!(
        manifest["schema"].as_str(),
        Some("open-lola.lola2.compatibility-corpus/v1")
    );

    let cases = manifest["cases"]
        .as_array()
        .expect("compatibility corpus cases array");
    assert!(!cases.is_empty(), "compatibility corpus must not be empty");
    for case in cases {
        assert_case(case);
    }
}

fn assert_case(case: &Value) {
    match string(case, "operation") {
        "encode_control" => assert_encode_control(case),
        "parse_control" => assert_parse_control(case),
        "reject_control_encoding" => assert_reject_control_encoding(case),
        "parse_serialized" => assert_parse_serialized(case),
        "encode_audio" => assert_encode_audio(case),
        "encode_video" => assert_encode_video(case),
        operation => panic!("{}: unknown corpus operation {operation}", case_id(case)),
    }
}

fn assert_encode_control(case: &Value) {
    assert_eq!(
        category(case),
        "accept",
        "{}: control encoding category",
        case_id(case)
    );
    let output = encode_control(case).unwrap_or_else(|error| {
        panic!(
            "{}: expected control encoding success: {error}",
            case_id(case)
        )
    });
    let expected = expected(case);
    let prefix = string(case, "expected_prefix").as_bytes();
    assert!(
        output.as_bytes().starts_with(prefix),
        "{}: control prefix differs",
        case_id(case)
    );
    assert_eq!(
        output.len(),
        number(expected, "wire_size") as usize,
        "{}: control wire size",
        case_id(case)
    );

    let decoded = parse_control_datagram(output.as_bytes())
        .unwrap_or_else(|| panic!("{}: encoded control did not decode", case_id(case)));
    assert_expected_control(case, &decoded.fields, decoded.txt());
}

fn assert_parse_control(case: &Value) {
    let decoded = parse_control_datagram(&control_input(case));
    if category(case) == "accept" {
        let decoded =
            decoded.unwrap_or_else(|| panic!("{}: expected control acceptance", case_id(case)));
        assert_expected_control(case, &decoded.fields, decoded.txt());
    } else {
        assert!(
            decoded.is_none(),
            "{}: expected control rejection",
            case_id(case)
        );
    }
}

fn assert_reject_control_encoding(case: &Value) {
    assert!(
        encode_control(case).is_err(),
        "{}: expected control encoding rejection",
        case_id(case)
    );
}

fn assert_parse_serialized(case: &Value) {
    assert!(
        parse_serialized_media(&hex(string(case, "input_hex"))).is_err(),
        "{}: expected serialized media rejection",
        case_id(case)
    );
}

fn assert_encode_audio(case: &Value) {
    let expected = expected(case);
    assert_eq!(
        category(case),
        "accept",
        "{}: audio encoding category",
        case_id(case)
    );
    let packet = build_audio_payload(
        number(case, "sequence") as u32,
        &hex(string(case, "pcm_hex")),
        None,
    )
    .unwrap_or_else(|error| {
        panic!(
            "{}: expected audio encoding success: {error}",
            case_id(case)
        )
    });
    let fragment = parse_fragment(&packet).unwrap_or_else(|error| {
        panic!("{}: audio fragment did not decode: {error}", case_id(case))
    });
    assert_eq!(packet.len(), number(expected, "wire_size") as usize);
    assert_eq!(fragment.frame_id, number(expected, "frame_id") as u32);
    assert_eq!(
        fragment.fragment_count,
        number(expected, "fragment_count") as u32
    );
    assert_eq!(
        fragment.fragment_index,
        number(expected, "fragment_index") as u32
    );
    assert_eq!(
        fragment.original_offset,
        number(expected, "original_offset") as u32
    );
    assert_eq!(
        fragment.fragment_length,
        number(expected, "fragment_length") as u32
    );
    assert_eq!(fragment.flags, number(expected, "flags") as u8);
    assert_eq!(fragment.data, hex(string(expected, "serialized_hex")));
}

fn assert_encode_video(case: &Value) {
    let expected = expected(case);
    assert_eq!(
        category(case),
        "accept",
        "{}: video encoding category",
        case_id(case)
    );
    let packets = build_video_payloads(
        number(case, "sequence") as u32,
        &hex(string(case, "payload_hex")),
        None,
        number(case, "packet_size") as usize,
    );
    assert_eq!(
        packets.len(),
        number(expected, "fragment_count") as usize + 1
    );
    assert_eq!(packets[0], hex(string(expected, "prelude_hex")));

    let prelude = parse_video_prelude(&packets[0])
        .unwrap_or_else(|| panic!("{}: video prelude did not decode", case_id(case)));
    assert_eq!(prelude.frame_id, number(expected, "frame_id") as u32);
    assert_eq!(
        prelude.expected_size,
        number(expected, "serialized_size") as u32
    );
    assert_eq!(
        prelude.fragment_count,
        number(expected, "fragment_count") as u32
    );

    let expected_fragments = expected["fragments"]
        .as_array()
        .unwrap_or_else(|| panic!("{}: expected fragments array", case_id(case)));
    assert_eq!(
        expected_fragments.len(),
        packets.len() - 1,
        "{}: expected video fragment count",
        case_id(case)
    );
    for (packet, expected_fragment) in packets[1..].iter().zip(expected_fragments) {
        let fragment = parse_fragment(packet).unwrap_or_else(|error| {
            panic!("{}: video fragment did not decode: {error}", case_id(case))
        });
        assert_eq!(
            fragment.fragment_index,
            number(expected_fragment, "fragment_index") as u32
        );
        assert_eq!(
            fragment.original_offset,
            number(expected_fragment, "original_offset") as u32
        );
        assert_eq!(
            fragment.fragment_length,
            number(expected_fragment, "fragment_length") as u32
        );
        assert_eq!(fragment.flags, number(expected_fragment, "flags") as u8);
        assert_eq!(fragment.data, hex(string(expected_fragment, "data_hex")));
    }
}

fn assert_expected_control(
    case: &Value,
    fields: &std::collections::BTreeMap<String, String>,
    decoded_txt: String,
) {
    let expected = expected(case);
    if let Some(sid) = expected.get("sid") {
        assert_eq!(
            fields
                .get("SID")
                .and_then(|value| value.parse::<i64>().ok()),
            sid.as_i64()
        );
    }
    if let Some(sid) = expected.get("sid_canonical") {
        assert_eq!(fields.get("SID").map(String::as_str), sid.as_str());
    }
    if let Some(txt) = expected.get("txt") {
        assert_eq!(decoded_txt, txt.as_str().expect("text expectation"));
    }
}

fn encode_control(case: &Value) -> Result<String, rusty_lola::protocol::ProtocolError> {
    let txt = match case.get("txt") {
        Some(value) => value.as_str().expect("text vector").to_owned(),
        None => case
            .get("txt_repeat")
            .map(|value| {
                value
                    .as_str()
                    .expect("repeat text vector")
                    .repeat(number(case, "txt_count") as usize)
            })
            .unwrap_or_default(),
    };
    let mut fields = vec![
        ("SRCIP", string(case, "src_ip").to_owned()),
        ("DSTIP", string(case, "dst_ip").to_owned()),
        ("SID", number(case, "sid").to_string()),
    ];
    if !txt.is_empty() {
        fields.push(("TXT", txt));
    }
    if string(case, "kind") == "MESG_QUICKCONN" {
        fields.extend([
            ("SR", "44100".into()),
            ("BPS", "16".into()),
            ("CHNLS", "2".into()),
            ("FPS", "25".into()),
            ("BPP", "8".into()),
            ("X", "640".into()),
            ("Y", "480".into()),
            ("COMP", "0".into()),
            ("BAYER", "0".into()),
        ]);
    }
    let fields = fields
        .iter()
        .map(|(name, value)| (*name, value.clone()))
        .collect::<Vec<_>>();
    encode_mesg(string(case, "kind"), &fields)
}

fn control_input(case: &Value) -> Vec<u8> {
    let mut input = match case.get("input_ascii") {
        Some(value) => value
            .as_str()
            .expect("ASCII input vector")
            .as_bytes()
            .to_vec(),
        None => hex(string(case, "input_hex")),
    };
    if let Some(size) = case.get("pad_to") {
        let pad_byte = case
            .get("pad_byte")
            .and_then(Value::as_str)
            .map_or(0, |value| value.as_bytes()[0]);
        input.resize(size.as_u64().expect("padding size") as usize, pad_byte);
    }
    input
}

fn expected(case: &Value) -> &Value {
    &case["expected"]
}

fn category(case: &Value) -> &str {
    string(expected(case), "category")
}

fn case_id(case: &Value) -> &str {
    string(case, "id")
}

fn string<'a>(object: &'a Value, key: &str) -> &'a str {
    object[key]
        .as_str()
        .unwrap_or_else(|| panic!("missing string field {key}"))
}

fn number(object: &Value, key: &str) -> u64 {
    object[key]
        .as_u64()
        .unwrap_or_else(|| panic!("missing unsigned integer field {key}"))
}

fn hex(value: &str) -> Vec<u8> {
    assert_eq!(value.len() % 2, 0, "hex vector has an odd length");
    value
        .as_bytes()
        .as_chunks::<2>()
        .0
        .iter()
        .map(|digits| {
            std::str::from_utf8(digits)
                .expect("ASCII hex")
                .chars()
                .fold(0_u8, |value, digit| {
                    value * 16
                        + digit
                            .to_digit(16)
                            .unwrap_or_else(|| panic!("invalid hex digit {digit}"))
                            as u8
                })
        })
        .collect()
}
