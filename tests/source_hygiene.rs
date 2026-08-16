//! Structural acceptance checks for production Rust sources.

use std::fs;
use std::path::{Path, PathBuf};

const MAX_PRODUCTION_LINES: usize = 600;

fn rust_sources(root: &Path, output: &mut Vec<PathBuf>) {
    let mut entries = fs::read_dir(root)
        .unwrap_or_else(|error| panic!("failed to read {}: {error}", root.display()))
        .collect::<Result<Vec<_>, _>>()
        .unwrap_or_else(|error| panic!("failed to enumerate {}: {error}", root.display()));
    entries.sort_by_key(|entry| entry.path());
    for entry in entries {
        let path = entry.path();
        if path.is_dir() {
            rust_sources(&path, output);
        } else if path.extension().and_then(|extension| extension.to_str()) == Some("rs") {
            output.push(path);
        }
    }
}

#[test]
fn production_modules_remain_bounded() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("src");
    let mut sources = Vec::new();
    rust_sources(&root, &mut sources);
    let oversized = sources
        .into_iter()
        .filter_map(|path| {
            let source = fs::read_to_string(&path).ok()?;
            let lines = source.lines().count();
            (lines > MAX_PRODUCTION_LINES).then_some((path, lines))
        })
        .collect::<Vec<_>>();
    assert!(
        oversized.is_empty(),
        "production modules exceed {MAX_PRODUCTION_LINES} lines: {oversized:?}"
    );
}

#[test]
fn removed_custom_media_magic_does_not_return() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("src");
    let mut sources = Vec::new();
    rust_sources(&root, &mut sources);
    for path in sources {
        let source = fs::read_to_string(&path).expect("read production source");
        assert!(!source.contains("OLAV"), "legacy OLAV magic in {path:?}");
        assert!(!source.contains("OLFG"), "legacy OLFG magic in {path:?}");
    }
}
