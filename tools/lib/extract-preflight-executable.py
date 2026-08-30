#!/usr/bin/env python3
# pylint: disable=invalid-name
"""Extract the preflight executable path from a JSON report."""

import json
import sys


def main() -> int:
    """Print the validated UltraGrid executable from a passing preflight report."""
    if len(sys.argv) != 2:
        print("usage: extract-preflight-executable.py preflight-report.json", file=sys.stderr)
        return 2

    with open(sys.argv[1], encoding="utf-8") as handle:
        report = json.load(handle)

    probe = report["probes"][0]
    if report["verdict"] != "pass" or probe["detectedIdentity"] != "ultraGrid":
        print(probe["notes"], file=sys.stderr)
        return 1

    print(probe["executable"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
