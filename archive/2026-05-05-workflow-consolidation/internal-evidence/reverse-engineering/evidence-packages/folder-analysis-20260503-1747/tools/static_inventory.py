#!/usr/bin/env python3
"""Static inventory builder for the LoLa v2.0 Windows artifact folder."""

from __future__ import annotations

from static_inventory_core import DATA_DIR, OUT, TARGET, ROOT, make_artifact
from static_inventory_evidence import write_json, write_summary, write_tool_evidence
from static_inventory_writers import (
    write_av_analysis,
    write_diagrams,
    write_findings,
    write_inventory,
    write_strings,
)

def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    paths = sorted(path for path in TARGET.rglob("*") if path.is_file())
    artifacts = [make_artifact(path) for path in paths]
    write_json(artifacts)
    write_inventory(artifacts)
    write_strings(artifacts)
    write_findings(artifacts)
    write_av_analysis()
    write_diagrams()
    write_tool_evidence(artifacts)
    write_summary(artifacts)
    print(f"wrote {len(artifacts)} artifacts to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
