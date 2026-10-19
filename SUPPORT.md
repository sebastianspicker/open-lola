# Support

Open LoLa is an experimental source alpha with a `PARTIAL` verdict. It is meant
for evaluation and contribution, not for production use. There are no support,
uptime, compatibility, deployment, or response-time commitments.

## Where to ask

- Use the GitHub issue chooser for reproducible source defects, scoped feature
  proposals, or sanitized interoperability evidence.
- Skim [CONTRIBUTING.md](CONTRIBUTING.md) first. Reports must state whether
  their evidence is source-only, synthetic, localhost, measured hardware,
  reference-peer, or not measured.
- Report suspected vulnerabilities through the private route in
  [SECURITY.md](SECURITY.md), never in a public issue.

Do not upload credentials, private packet or media captures, personal data,
hostnames, licensed binaries, proprietary material, or confidential topology.
Maintainers may close requests that cannot be reproduced safely or that fall
outside the current source-alpha scope.

## Before you ask for help

Please include the exact source revision, your platform and toolchain versions,
a minimal sanitized reproduction, what you observed and expected, the commands
you ran, and any checks that were unavailable. A successful build, unit test,
localhost run, or offline screenshot is not evidence of field interoperability
or product readiness.

## Logs and reports to attach

Attach the newest files for the failing run, after removing hostnames, IP
addresses, and device identifiers you do not want to publish.

| Runtime | What to attach | Where it is written |
| --- | --- | --- |
| macOS operator app | Run stdout/stderr logs (the previous run is kept as `previous-execution-*.log`); each file is capped at 1 MiB | `~/Library/Caches/de.hfmt.open-lola.app/logs/execution-stdout.log` and `execution-stderr.log` (the folder is named after the bundle identifier; an unbundled debug build uses `open-lola-app`) |
| macOS operator app | Run plan, connection preflight, and supervisor reports | `~/Library/Application Support/OpenLoLa/MacToMac/plan.json`, `connection-preflight.json`, and `supervisor.json`, plus the per-peer reports in the run directory named in the plan |
| macOS operator app | Unified log messages | `bash tools/macos/build_and_run.sh --telemetry` streams them while the app runs |
| macOS CLI | The report written to the `--output` path you passed, and the command's stdout/stderr | Your terminal and the `--output` path |
| Rust station CLI | The result JSON printed on stdout, the stderr text, and the exit code | Your terminal; redirect with `> result.json 2> stderr.txt` |
| Rust station | The settings or session profile you passed with `--settings` or `--session` | The path you passed |
| Rust station | Device inventory | Output of `rusty-lola devices` |
