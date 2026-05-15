#!/usr/bin/env python3
import json
import sys


def main() -> int:
    if len(sys.argv) != 9:
        print(
            "usage: write-connection-metrics.py output.json connected elapsed-ms "
            "timeout-seconds poll-seconds live-log preflight-report executable",
            file=sys.stderr,
        )
        return 2

    path, connected, elapsed_ms, timeout_seconds, poll_seconds, live_log, preflight, executable = sys.argv[1:]
    payload = {
        "schema": "open-lola-ultragrid-native-managed-connection-metrics-v1",
        "connected": connected == "true",
        "audioVideoConnectionMs": int(elapsed_ms) if elapsed_ms else None,
        "connectionTimeoutSeconds": int(timeout_seconds),
        "connectionPollSeconds": float(poll_seconds),
        "liveRxLog": live_log,
        "preflightReport": preflight,
        "executable": executable,
        "evidenceBoundary": (
            "Measured from Open LoLa-managed native UltraGrid TX command start until "
            "the managed native RX log first contains incoming audio and video format lines."
        ),
    }
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
