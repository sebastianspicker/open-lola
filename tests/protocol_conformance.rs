//! Golden wire checks against the versioned LoLa 2 compatibility corpus.

use rusty_lola::protocol::*;
use serde::Deserialize;
use serde_json::Value;
use std::path::PathBuf;
use std::process::Command;

const LOLA2_CORPUS: &str = include_str!("../../interop/lola2/manifest.json");
const LOLA2_CORPUS_SCHEMA: &str = "open-lola.lola2.compatibility-corpus/v1";
const LOLA2_CORPUS_VERSION: &str = "1.1.0";

#[derive(Debug, Deserialize)]
struct CompatibilityCorpus {
    schema: String,
    version: String,
    provenance: CorpusProvenance,
    categories: std::collections::BTreeMap<String, String>,
    cases: Vec<CorpusCase>,
}

#[derive(Debug, Deserialize)]
struct CorpusProvenance {
    recovered_from: Vec<String>,
    vector_origin: String,
    original_windows_capture: bool,
}

#[derive(Debug, Deserialize)]
struct CorpusCase {
    id: String,
    operation: String,
    kind: Option<String>,
    src_ip: Option<String>,
    dst_ip: Option<String>,
    sid: Option<u32>,
    txt: Option<String>,
    txt_repeat: Option<String>,
    txt_count: Option<usize>,
    input_ascii: Option<String>,
    input_hex: Option<String>,
    pad_to: Option<usize>,
    pad_byte: Option<String>,
    expected_prefix: Option<String>,
    sequence: Option<u32>,
    pcm_hex: Option<String>,
    payload_hex: Option<String>,
    packet_size: Option<usize>,
    expected: Value,
}

fn decode_hex(input: &str) -> Vec<u8> {
    let input = input.trim();
    (0..input.len())
        .step_by(2)
        .map(|index| u8::from_str_radix(&input[index..index + 2], 16).unwrap())
        .collect()
}

fn decode_hex_lines(input: &str) -> Vec<Vec<u8>> {
    input.lines().map(decode_hex).collect()
}

#[test]
fn compatibility_corpus_contract_is_versioned_and_provenanced() {
    let corpus: CompatibilityCorpus = serde_json::from_str(LOLA2_CORPUS).expect("valid corpus");
    assert_eq!(corpus.schema, LOLA2_CORPUS_SCHEMA);
    assert_eq!(corpus.version, LOLA2_CORPUS_VERSION);
    assert_eq!(
        corpus.provenance.recovered_from,
        [
            "linux_connector/docs/protocol-reference.md",
            "linux_connector/lola_connector/protocol.py",
            "linux_connector/lola_connector/media.py",
        ]
    );
    assert_eq!(
        corpus.provenance.vector_origin,
        "synthetic reconstruction from documented behaviour and current Python wire codec"
    );
    assert!(!corpus.provenance.original_windows_capture);
    assert!(!corpus.cases.is_empty(), "corpus must contain wire cases");
}

fn case_field<'a>(case: &'a CorpusCase, field: &str) -> &'a Value {
    case.expected
        .get(field)
        .unwrap_or_else(|| panic!("{} is missing expected.{field}", case.id))
}

fn expected_category(case: &CorpusCase) -> &str {
    case_field(case, "category")
        .as_str()
        .unwrap_or_else(|| panic!("{} has non-string expected.category", case.id))
}

fn expected_u32(case: &CorpusCase, field: &str) -> u32 {
    case_field(case, field)
        .as_u64()
        .unwrap_or_else(|| panic!("{} has non-u32 expected.{field}", case.id))
        .try_into()
        .unwrap_or_else(|_| panic!("{} has out-of-range expected.{field}", case.id))
}

fn expected_usize(case: &CorpusCase, field: &str) -> usize {
    case_field(case, field)
        .as_u64()
        .unwrap_or_else(|| panic!("{} has non-usize expected.{field}", case.id))
        .try_into()
        .unwrap_or_else(|_| panic!("{} has out-of-range expected.{field}", case.id))
}

fn control_input(case: &CorpusCase) -> Vec<u8> {
    let mut input = match (&case.input_ascii, &case.input_hex) {
        (Some(ascii), None) => ascii.as_bytes().to_vec(),
        (None, Some(hex)) => decode_hex(hex),
        _ => panic!("{} must provide exactly one control input", case.id),
    };
    if let Some(size) = case.pad_to {
        let pad_byte = case
            .pad_byte
            .as_deref()
            .map(|value| {
                assert_eq!(value.len(), 1, "{} has a non-byte pad_byte", case.id);
                value.as_bytes()[0]
            })
            .unwrap_or(0);
        input.resize(size, pad_byte);
    }
    input
}

fn required<'a>(value: &'a Option<String>, case: &CorpusCase, field: &str) -> &'a str {
    value
        .as_deref()
        .unwrap_or_else(|| panic!("{} is missing {field}", case.id))
}

fn consume_encode_control_case(case: &CorpusCase) {
    let datagram = build_control_datagram(
        required(&case.kind, case, "kind"),
        required(&case.src_ip, case, "src_ip"),
        required(&case.dst_ip, case, "dst_ip"),
        case.sid
            .unwrap_or_else(|| panic!("{} is missing sid", case.id)),
        None,
        case.txt.as_deref().unwrap_or(""),
    )
    .unwrap_or_else(|error| panic!("{} unexpectedly failed to encode: {error}", case.id));
    assert_eq!(
        datagram.len(),
        expected_usize(case, "wire_size"),
        "{}",
        case.id
    );
    assert!(
        datagram.starts_with(required(&case.expected_prefix, case, "expected_prefix").as_bytes()),
        "{}",
        case.id
    );
    let parsed = parse_control_datagram(&datagram)
        .unwrap_or_else(|| panic!("{} encoded an unparsable datagram", case.id));
    assert_eq!(
        parsed
            .sid()
            .expect("encoded SID must fit the builder's numeric domain"),
        expected_u32(case, "sid") as i64,
        "{}",
        case.id
    );
    if let Some(expected_txt) = case.expected.get("txt").and_then(Value::as_str) {
        assert_eq!(parsed.txt(), expected_txt, "{}", case.id);
    }
    assert!(
        datagram[required(&case.expected_prefix, case, "expected_prefix").len()..]
            .iter()
            .all(|byte| *byte == 0),
        "{} must use NUL padding after its useful prefix",
        case.id
    );
}

fn consume_parse_control_case(case: &CorpusCase) {
    let parsed = parse_control_datagram(&control_input(case));
    match expected_category(case) {
        "accept" => {
            let parsed = parsed.unwrap_or_else(|| panic!("{} was unexpectedly rejected", case.id));
            let expected_sid = case
                .expected
                .get("sid_canonical")
                .and_then(Value::as_str)
                .map(str::to_owned)
                .unwrap_or_else(|| {
                    case_field(case, "sid")
                        .as_i64()
                        .unwrap_or_else(|| panic!("{} has non-i64 expected.sid", case.id))
                        .to_string()
                });
            assert_eq!(parsed.fields["SID"], expected_sid, "{}", case.id);
            if let Some(expected_txt) = case.expected.get("txt").and_then(Value::as_str) {
                assert_eq!(parsed.txt(), expected_txt, "{}", case.id);
            }
        }
        category if category.starts_with("reject.") => {
            assert!(parsed.is_none(), "{} must reject as {category}", case.id);
        }
        category => panic!("{} has unsupported category {category}", case.id),
    }
}

fn consume_reject_control_encoding_case(case: &CorpusCase) {
    let txt = case.txt.clone().unwrap_or_else(|| {
        required(&case.txt_repeat, case, "txt_repeat").repeat(
            case.txt_count
                .unwrap_or_else(|| panic!("{} is missing txt_count", case.id)),
        )
    });
    let result = build_control_datagram(
        required(&case.kind, case, "kind"),
        required(&case.src_ip, case, "src_ip"),
        required(&case.dst_ip, case, "dst_ip"),
        case.sid
            .unwrap_or_else(|| panic!("{} is missing sid", case.id)),
        None,
        &txt,
    );
    match expected_category(case) {
        "reject.non_ascii" => assert!(
            matches!(result, Err(ProtocolError::NonAscii)),
            "{}",
            case.id
        ),
        "reject.oversize" => assert!(matches!(result, Err(ProtocolError::TooLong)), "{}", case.id),
        category => panic!("{} has unsupported encoding category {category}", case.id),
    }
}

fn consume_parse_serialized_case(case: &CorpusCase) {
    let input = decode_hex(required(&case.input_hex, case, "input_hex"));
    match expected_category(case) {
        "reject.serialized_length" => assert!(
            matches!(
                parse_serialized_media(&input),
                Err(MediaError::LengthMismatch)
            ),
            "{}",
            case.id
        ),
        category => panic!("{} has unsupported serialized category {category}", case.id),
    }
}

fn consume_encode_audio_case(case: &CorpusCase) {
    let wire = build_audio_payload(
        case.sequence
            .unwrap_or_else(|| panic!("{} is missing sequence", case.id)),
        &decode_hex(required(&case.pcm_hex, case, "pcm_hex")),
        None,
    )
    .unwrap_or_else(|error| panic!("{} unexpectedly failed to encode audio: {error}", case.id));
    assert_eq!(wire.len(), expected_usize(case, "wire_size"), "{}", case.id);
    let fragment = parse_fragment(&wire)
        .unwrap_or_else(|error| panic!("{} produced an invalid fragment: {error}", case.id));
    for (field, actual) in [
        ("frame_id", fragment.frame_id),
        ("fragment_count", fragment.fragment_count),
        ("fragment_index", fragment.fragment_index),
        ("original_offset", fragment.original_offset),
        ("fragment_length", fragment.fragment_length),
    ] {
        assert_eq!(actual, expected_u32(case, field), "{} {field}", case.id);
    }
    assert_eq!(
        fragment.flags,
        expected_u32(case, "flags") as u8,
        "{}",
        case.id
    );
    assert_eq!(
        fragment.data,
        decode_hex(
            case_field(case, "serialized_hex")
                .as_str()
                .unwrap_or_else(|| panic!("{} has non-string expected.serialized_hex", case.id))
        ),
        "{}",
        case.id
    );
    assert!(
        wire[FRAGMENT_HEADER_SIZE + fragment.fragment_length as usize..]
            .iter()
            .all(|byte| *byte == 0),
        "{} must NUL-pad its fixed-size audio datagram",
        case.id
    );
}

fn consume_encode_video_case(case: &CorpusCase) {
    let packets = build_video_payloads(
        case.sequence
            .unwrap_or_else(|| panic!("{} is missing sequence", case.id)),
        &decode_hex(required(&case.payload_hex, case, "payload_hex")),
        None,
        case.packet_size
            .unwrap_or_else(|| panic!("{} is missing packet_size", case.id)),
    );
    assert_eq!(
        packets.len() - 1,
        expected_usize(case, "fragment_count"),
        "{}",
        case.id
    );
    assert_eq!(
        packets[0],
        decode_hex(
            case_field(case, "prelude_hex")
                .as_str()
                .unwrap_or_else(|| panic!("{} has non-string expected.prelude_hex", case.id))
        ),
        "{}",
        case.id
    );
    let prelude = parse_video_prelude(&packets[0])
        .unwrap_or_else(|| panic!("{} produced an invalid video prelude", case.id));
    assert_eq!(
        prelude.frame_id,
        expected_u32(case, "frame_id"),
        "{}",
        case.id
    );
    assert_eq!(
        prelude.expected_size as usize,
        expected_usize(case, "serialized_size"),
        "{}",
        case.id
    );
    assert_eq!(
        prelude.fragment_count as usize,
        expected_usize(case, "fragment_count"),
        "{}",
        case.id
    );

    let expected_fragments = case_field(case, "fragments")
        .as_array()
        .unwrap_or_else(|| panic!("{} has non-array expected.fragments", case.id));
    assert_eq!(expected_fragments.len(), packets.len() - 1, "{}", case.id);
    for (packet, expected) in packets.iter().skip(1).zip(expected_fragments) {
        let fragment = parse_fragment(packet)
            .unwrap_or_else(|error| panic!("{} produced an invalid fragment: {error}", case.id));
        for (field, actual) in [
            ("fragment_index", fragment.fragment_index),
            ("original_offset", fragment.original_offset),
            ("fragment_length", fragment.fragment_length),
        ] {
            assert_eq!(
                actual,
                expected[field]
                    .as_u64()
                    .unwrap_or_else(|| panic!("{} has non-u32 fragment {field}", case.id))
                    as u32,
                "{} {field}",
                case.id
            );
        }
        assert_eq!(
            fragment.flags,
            expected["flags"]
                .as_u64()
                .unwrap_or_else(|| panic!("{} has non-u8 fragment flags", case.id))
                as u8,
            "{} flags",
            case.id
        );
        assert_eq!(
            fragment.data,
            decode_hex(
                expected["data_hex"]
                    .as_str()
                    .unwrap_or_else(|| panic!("{} has non-string fragment data_hex", case.id))
            ),
            "{} fragment data",
            case.id
        );
    }
}

#[test]
fn every_lola2_compatibility_corpus_case_matches_rust() {
    let corpus: CompatibilityCorpus = serde_json::from_str(LOLA2_CORPUS).expect("valid corpus");
    let mut consumed = std::collections::BTreeSet::new();
    for case in &corpus.cases {
        assert!(
            consumed.insert(&case.id),
            "duplicate corpus case id: {}",
            case.id
        );
        assert!(
            corpus.categories.contains_key(expected_category(case)),
            "{} uses undocumented category {}",
            case.id,
            expected_category(case)
        );
        match case.operation.as_str() {
            "encode_control" => consume_encode_control_case(case),
            "parse_control" => consume_parse_control_case(case),
            "reject_control_encoding" => consume_reject_control_encoding_case(case),
            "parse_serialized" => consume_parse_serialized_case(case),
            "encode_audio" => consume_encode_audio_case(case),
            "encode_video" => consume_encode_video_case(case),
            operation => panic!("{} has unsupported operation {operation}", case.id),
        }
    }
    assert_eq!(consumed.len(), corpus.cases.len());
}

fn oracle_connector_root() -> Option<PathBuf> {
    let configured = PathBuf::from(std::env::var_os("TUX_LOLA_ROOT")?);
    for candidate in [configured.clone(), configured.join("linux_connector")] {
        if candidate.join("lola_connector/protocol.py").is_file() {
            return Some(candidate);
        }
    }
    panic!("TUX_LOLA_ROOT does not contain linux_connector/lola_connector or lola_connector");
}

#[test]
#[ignore = "requires TUX_LOLA_ROOT pointing at a Python connector checkout"]
fn live_python_wire_output_matches_rust() {
    let connector_root = oracle_connector_root()
        .expect("TUX_LOLA_ROOT must point at linux_connector/lola_connector or lola_connector");

    let python = std::env::var_os("PYTHON").unwrap_or_else(|| "python3".into());
    let script = r#"
import json
from lola_connector.media import build_audio_payload, build_video_payloads
from lola_connector.protocol import MESG_CHAT, build_control_datagram
print(json.dumps({
  "control": build_control_datagram(MESG_CHAT, "10.0.0.1", "10.0.0.2", 7, txt="hello;world:100%").hex(),
  "audio": build_audio_payload(42, bytes(range(64))).hex(),
  "video": [packet.hex() for packet in build_video_payloads(42, b"raw-video", packet_size=128)],
}))
"#;
    let output = Command::new(python)
        .arg("-c")
        .arg(script)
        .current_dir(&connector_root)
        .env("PYTHONPATH", &connector_root)
        .output()
        .expect("launch Python oracle");
    assert!(
        output.status.success(),
        "Python oracle failed: {}",
        String::from_utf8_lossy(&output.stderr)
    );
    let oracle: serde_json::Value =
        serde_json::from_slice(&output.stdout).expect("oracle JSON output");
    assert_eq!(
        decode_hex(oracle["control"].as_str().unwrap()),
        build_control_datagram(
            MESG_CHAT,
            "10.0.0.1",
            "10.0.0.2",
            7,
            None,
            "hello;world:100%",
        )
        .unwrap()
    );
    assert_eq!(
        decode_hex(oracle["audio"].as_str().unwrap()),
        build_audio_payload(42, &(0u8..64).collect::<Vec<_>>(), None).unwrap()
    );
    let oracle_video: Vec<Vec<u8>> = oracle["video"]
        .as_array()
        .unwrap()
        .iter()
        .map(|value| decode_hex(value.as_str().unwrap()))
        .collect();
    assert_eq!(
        oracle_video,
        build_video_payloads(42, b"raw-video", None, 128)
    );
}

#[test]
fn ascii_control_is_exactly_1024_bytes_and_escapes_txt_once() {
    let expected = include_str!("fixtures/lola2-control-chat-prefix.txt").trim_end();
    let datagram = build_control_datagram(
        MESG_CHAT,
        "10.0.0.1",
        "10.0.0.2",
        7,
        None,
        "hello;world:100%",
    )
    .unwrap();
    assert_eq!(datagram.len(), CONTROL_DATAGRAM_SIZE);
    assert_eq!(&datagram[..expected.len()], expected.as_bytes());
    assert!(datagram[expected.len()..].iter().all(|byte| *byte == 0));
    let parsed = parse_control_datagram(&datagram).unwrap();
    assert_eq!(parsed.raw_txt(), "hello%3Bworld%3A100%25");
    assert_eq!(parsed.txt(), "hello;world:100%");
}

#[test]
fn strict_control_requires_and_canonicalizes_ascii_sid() {
    assert!(parse_control_datagram(b"/MESG_CHAT;TXT:\xff\0").is_none());
    assert!(parse_control_datagram(b"/MESG_UNKNOWN;SID:1\0").is_none());
    assert!(parse_control_datagram(b"/MESG_CHAT\0").is_none());
    assert!(parse_control_datagram(b"/MESG_CHAT;SID:\0").is_none());
    assert!(parse_control_datagram(b"/MESG_CHAT;SID:nope\0").is_none());
    assert!(parse_control_datagram(b"/MESG_CHAT;SID:+\0").is_none());
    assert!(parse_control_datagram(b"/MESG_CHAT;SRCIP:a;SRCIP:b\0").is_none());

    let leading_zeroes = parse_control_datagram(b"/MESG_CHAT;SID:000\0").unwrap();
    assert_eq!(leading_zeroes.fields["SID"], "0");
    assert_eq!(leading_zeroes.sid().unwrap(), 0);
    let signed = parse_control_datagram(b"/MESG_CHAT;SID:-0007\0").unwrap();
    assert_eq!(signed.fields["SID"], "-7");
    assert_eq!(signed.sid().unwrap(), -7);
    let unbounded = parse_control_datagram(b"/MESG_CHAT;SID:18446744073709551616000\0").unwrap();
    assert_eq!(unbounded.fields["SID"], "18446744073709551616000");
    assert!(matches!(unbounded.sid(), Err(ProtocolError::BadInt(field)) if field == "SID"));

    let bad_media = b"/MESG_QUICKCONN;SRCIP:a;DSTIP:b;SID:1;SR:44100;BPS:16;CHNLS:2;FPS:25;BPP:8;X:99999;Y:480;COMP:0;BAYER:0";
    let parsed = parse_control_datagram(bad_media).unwrap();
    assert!(parsed.media().is_err());
}

#[test]
fn osc15_quickconn_round_trips_with_numeric_validation() {
    let datagram = build_osc15_control_datagram(
        MESG_QUICKCONN_ACK,
        "10.0.0.2",
        "10.0.0.1",
        7,
        Some(&MediaSettings {
            width: 1920,
            height: 1080,
            ..MediaSettings::default()
        }),
        "",
        None,
    )
    .unwrap();
    let parsed = parse_osc15_control_datagram(&datagram).unwrap();
    assert_eq!(parsed.dialect, "osc15");
    assert_eq!(parsed.media().unwrap().width, 1920);
}

#[test]
fn common_body_and_0x21_fragment_match_golden_bytes() {
    let body = serialize_media_frame(42, b"abc");
    assert_eq!(
        body,
        decode_hex(include_str!("fixtures/lola2-media-body.hex"))
    );
    let packets = fragment_serialized(&body, 42, 0x80);
    assert_eq!(
        packets,
        vec![decode_hex(include_str!("fixtures/lola2-fragment.hex"))]
    );
    assert_eq!(
        parse_serialized_media(&body).unwrap(),
        (42, b"abc".to_vec())
    );
    assert_eq!(parse_fragment(&packets[0]).unwrap().flags, 1);
}

#[test]
fn video_prelude_and_audio_wire_rules_match_lola() {
    let prelude = build_video_prelude(9, 123, 2);
    assert_eq!(prelude.len(), 0x40);
    assert_eq!(&prelude[..8], &FRAGMENT_MAGIC);
    assert_eq!(&prelude[8..12], &VIDEO_PRELUDE_SENTINEL);
    assert_eq!(parse_video_prelude(&prelude).unwrap().expected_size, 123);

    let audio = build_audio_payload(0xffff_ffff, &[1; 128], None).unwrap();
    assert_eq!(audio.len(), 1066);
    assert_eq!(parse_fragment(&audio).unwrap().frame_id, 0);

    assert_eq!(
        build_audio_payload(42, &(0u8..32).collect::<Vec<_>>(), None).unwrap(),
        decode_hex(include_str!("fixtures/lola2-audio.hex"))
    );
    assert_eq!(
        build_video_payloads(42, b"raw-video", None, 128),
        decode_hex_lines(include_str!("fixtures/lola2-video-raw.hex"))
    );
    let jpeg = decode_hex("ffd8ffe000104a4649460001ffd9");
    assert_eq!(
        build_video_payloads(42, &jpeg, None, 128),
        decode_hex_lines(include_str!("fixtures/lola2-video-jpeg.hex"))
    );
    assert_eq!(
        build_audio_payload(u32::MAX, b"wrap", None).unwrap(),
        decode_hex(include_str!("fixtures/lola2-wrap-audio.hex"))
    );
    assert!(parse_fragment(&decode_hex(include_str!(
        "fixtures/lola2-malformed-fragment.hex"
    )))
    .is_err());
}

#[test]
fn reassembly_is_strict_bounded_and_expires_stale_frames() {
    let mut strict = MediaReassembler::strict();
    let fragment =
        parse_fragment(&fragment_serialized(&serialize_media_frame(1, b"x"), 1, 128)[0]).unwrap();
    assert_eq!(strict.add(fragment).unwrap(), None);

    let mut reassembler = MediaReassembler::with_limits(1, std::time::Duration::ZERO);
    reassembler.begin(1, 9, 1).unwrap();
    assert_eq!(reassembler.expire(), 1);
    assert_eq!(reassembler.active_frames(), 0);

    let mut coverage = MediaReassembler::new();
    coverage.begin(2, 8, 2).unwrap();
    let first = Fragment {
        frame_id: 2,
        fragment_count: 2,
        fragment_index: 0,
        original_offset: 0,
        fragment_length: 4,
        flags: 0,
        data: b"abcd".to_vec(),
    };
    let overlap = Fragment {
        frame_id: 2,
        fragment_count: 2,
        fragment_index: 1,
        original_offset: 2,
        fragment_length: 6,
        flags: 1,
        data: b"cdefgh".to_vec(),
    };
    assert_eq!(coverage.add(first).unwrap(), None);
    assert!(matches!(
        coverage.add(overlap),
        Err(MediaError::FragmentOverlap(2))
    ));
}

#[test]
fn arbitrary_datagrams_never_panic_or_create_unbounded_frames() {
    let mut seed = 0x9e37_79b9_7f4a_7c15u64;
    for length in 0..2_048usize {
        let mut bytes = vec![0u8; length];
        for byte in &mut bytes {
            seed ^= seed << 13;
            seed ^= seed >> 7;
            seed ^= seed << 17;
            *byte = seed as u8;
        }
        let outcome = std::panic::catch_unwind(|| {
            let _ = parse_control_datagram(&bytes);
            let _ = parse_osc15_control_datagram(&bytes);
            let _ = parse_fragment(&bytes);
            let _ = parse_video_prelude(&bytes);
        });
        assert!(
            outcome.is_ok(),
            "parser panicked at datagram length {length}"
        );
    }
}
