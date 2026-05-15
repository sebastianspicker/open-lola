#!/usr/bin/env python3
import json
import sys


def main() -> int:
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
