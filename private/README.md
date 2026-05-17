# Private Evidence

Date: 2026-05-11
Status: private evidence entry point
Verdict: PARTIAL

This directory contains internal evidence that is useful for local development
and review but is not part of the public documentation surface or release
candidate allowlist.

| Directory | Purpose |
|---|---|
| [reverse-engineering/](reverse-engineering/README.md) | Internal Windows LoLa reverse-engineering evidence, validation gates, and command provenance. |

Public-safe summaries belong under [../docs/](../docs/README.md), especially
[../docs/reverse-engineering-boundary.md](../docs/reverse-engineering-boundary.md).
Release rules in [../docs/release-manifest.md](../docs/release-manifest.md)
exclude `private/**` by default.

VERDICT: PARTIAL
