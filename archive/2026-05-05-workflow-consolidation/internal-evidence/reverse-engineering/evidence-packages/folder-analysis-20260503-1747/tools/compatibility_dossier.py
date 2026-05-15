#!/usr/bin/env python3
"""Generate the LoLa 2.0 Legacy Compatibility Mode RE addendum."""

from __future__ import annotations

import json

from compatibility_model import DATA_DIR, OUT_DIR, compatibility_rows, load_artifacts
from compatibility_roadmap import update_parent_readme, write_dod, write_roadmap
from compatibility_writers import (
    write_artifact_map,
    write_codec_doc,
    write_exe_summary,
    write_protocol_doc,
    write_readme,
    write_string_triage,
)

def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    artifacts = load_artifacts()
    rows = compatibility_rows(artifacts)
    (DATA_DIR / "compatibility-artifacts.json").write_text(
        json.dumps(rows, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    write_readme(rows)
    write_artifact_map(rows)
    write_string_triage(rows)
    write_exe_summary()
    write_protocol_doc()
    write_codec_doc()
    write_roadmap()
    write_dod()
    update_parent_readme()


if __name__ == "__main__":
    main()
