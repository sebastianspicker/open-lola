//! Python-generated synthetic observations retained after connector retirement.
use rusty_lola::protocol::parse_control_datagram;
use serde_json::Value;
#[test]
fn python_control_acceptance_oracle_matches_rust() {
    let oracle: Value = serde_json::from_str(include_str!(
        "../../../interop/lola2/migration-control-oracle.json"
    ))
    .unwrap();
    for case in oracle["cases"].as_array().unwrap() {
        let hex = case["wire_hex"].as_str().unwrap();
        let bytes: Vec<u8> = (0..hex.len())
            .step_by(2)
            .map(|index| u8::from_str_radix(&hex[index..index + 2], 16).unwrap())
            .collect();
        let parsed = parse_control_datagram(&bytes);
        assert_eq!(
            parsed.is_some(),
            case["accepted"].as_bool().unwrap(),
            "{} {}",
            case["dialect"],
            case["kind"]
        );
        if let Some(parsed) = parsed {
            assert_eq!(parsed.kind, case["kind"].as_str().unwrap());
        }
    }
}
