"""Shared constants for public documentation verification checks."""

from __future__ import annotations

from pathlib import Path

ROOT = Path.cwd()

DOC_PATTERNS = (
    "*.md",
    ".github/**/*.md",
    "archive/README.md",
    "docs/**/*.md",
    "linux_connector/**/*.md",
    "scripts/README.md",
)

DOC_IGNORE_PREFIXES = (
    (".build",),
    (".pytest_cache",),
    (".ruff_cache",),
    ("re_out",),
    ("docs", "agent"),
    ("docs", "agents"),
    ("docs", "internal"),
    ("docs", "local"),
    ("docs", "implementation-handoff.md"),
    ("docs", "archive-binary-retention-proposal.md"),
)

REQUIRED_TOPICS = (
    "Core Audio",
    "AudioDeviceIOProc",
    "AUHAL",
    "UDP PCM",
    "drift",
    "PLC",
    "AVB",
    "DSCP",
    "PTP",
    "AVFoundation",
    "VideoToolbox",
    "OSC",
    "sACN",
    "Art-Net",
    "validation",
    "risk",
    "progress",
)

PUBLIC_ARCHITECTURE_DOCS = (
    "docs/clean-room-design-rules.md",
    "docs/latency-first-architecture.md",
    "docs/latency-budget.md",
    "docs/latency-profiles.md",
    "docs/p2p-networking.md",
    "docs/audio-rme-madi.md",
    "docs/audio-routing.md",
    "docs/multichannel-transport.md",
    "docs/rme-madi-routing.md",
    "docs/rx-buffering.md",
    "docs/video-blackmagic-atem.md",
    "docs/lighting-control.md",
    "docs/benchmark-methodology.md",
)

PUBLIC_PLANNING_DOCS = (
    "docs/current-state.md",
    *PUBLIC_ARCHITECTURE_DOCS,
)

PUBLIC_EVIDENCE_LABEL_HEADING = "Evidence Labels"
PUBLIC_EVIDENCE_LABELS = (
    "public standard",
    "public API",
    "original open-lola design",
    "experimentally derived requirement",
    "compatibility requirement",
    "implementation hypothesis",
)

PUBLIC_PLANNING_REQUIRED_TOKENS = (
    "clean-room",
    "public standard",
    "original open-lola design",
    "experimentally derived requirement",
    "implementation hypothesis",
    "AudioDeviceIOProc",
    "Core Audio",
    "UDP",
    "P2P",
    "RME",
    "Blackmagic",
    "ATEM",
    "OSC",
    "sACN",
    "Art-Net",
    "VERDICT: PARTIAL",
)

PUBLIC_PLANNING_FORBIDDEN_TOKENS = (
    "/MESG_",
    "pcap_",
    "xiGetImage",
    "xiOpenDevice",
    "PDB",
)

PUBLIC_ACTIVE_STALE_REFERENCES = (
    "docs/milestones/",
    "milestones/",
    "docs/roadmap/mac-port-public-roadmap.md",
    "docs/source-contracts/MXX-",
    "docs/testing/verification-matrix.md",
    "docs/compliance/open-questions.md",
    "docs/compliance/release-artifact-hygiene.md",
    "docs/fixture-provenance.md",
    "docs/compliance/dependency-license-review.md",
    "docs/compliance/notices-attribution-register.md",
    "docs/compliance/sdk-license-notes.md",
    "architecture/implementation-roadmap.md",
    "M01-M14",
    "Public M01-M14",
)
