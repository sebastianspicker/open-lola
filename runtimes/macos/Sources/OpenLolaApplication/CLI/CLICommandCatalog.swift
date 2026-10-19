// Lists every open-lola command by group so the top-level help can show testers the real session commands.
import Foundation

/// A named group of CLI commands shown together in the top-level usage text.
public struct CLICommandGroup: Equatable, Sendable {
    /// Heading printed above the group.
    public let title: String
    /// Command names in the group.
    public let names: [String]
    /// One-line descriptions keyed by command name; commands without an entry are listed by name only.
    public let descriptions: [String: String]

    /// Creates a group from its heading, command names and optional descriptions.
    public init(title: String, names: [String], descriptions: [String: String] = [:]) {
        self.title = title
        self.names = names
        self.descriptions = descriptions
    }
}

/// Catalog of all commands dispatched by the open-lola executable, including delegated handlers.
public enum CLICommandCatalog {
    /// Session commands that start, plan, supervise or validate a real peer session, in recommended order.
    public static let sessionGroup = CLICommandGroup(
        title: "Session commands",
        names: [
            "direct-p2p-session-run",
            "direct-p2p-two-peer-plan-run",
            "mac-to-mac-connection-preflight-run",
            "direct-p2p-two-peer-local-run",
            "validate-direct-p2p-two-peer-local-run-report",
            "external-connector-session-run",
            "session-capabilities"
        ],
        descriptions: [
            "direct-p2p-session-run": "run one peer of a direct Mac-to-Mac session (has its own --help)",
            "direct-p2p-two-peer-plan-run": "write a two-peer run plan",
            "mac-to-mac-connection-preflight-run":
                "check connectivity to the remote peer and write the preflight report the supervisor requires",
            "direct-p2p-two-peer-local-run":
                "supervise both peers from a plan (dry run by default; --execute true launches)",
            "validate-direct-p2p-two-peer-local-run-report": "validate a supervisor report",
            "external-connector-session-run":
                "run a LoLa/UltraGrid/JackTrip connector session (--dry-run true by default)",
            "session-capabilities": "print the local session capability set"
        ]
    )

    /// Remaining command groups, names only, in display order.
    public static let otherGroups: [CLICommandGroup] = [
        CLICommandGroup(
            title: "Network and direct peer tools",
            names: [
                "audio-loopback-run", "device-inventory", "direct-p2p-localhost-smoke",
                "direct-p2p-mesh-runtime-localhost-smoke", "direct-p2p-mesh-topology-synthetic-smoke",
                "direct-p2p-two-peer-prototype-report", "direct-p2p-two-peer-report",
                "network-diagnostics-run", "route-certification-synthetic-smoke",
                "udp-pcm-localhost-smoke", "udp-pcm-loopback-localhost-smoke", "udp-pcm-loopback-run",
                "udp-pcm-receive-once", "udp-pcm-route-localhost-smoke", "udp-pcm-route-run",
                "udp-pcm-send-once"
            ]
        ),
        CLICommandGroup(
            title: "NAT traversal",
            names: [
                "nat-friendly-localhost-smoke", "nat-friendly-route-run",
                "nat-relay-fallback-localhost-smoke", "nat-relay-run",
                "nat-rendezvous-forwarder-localhost-smoke", "nat-rendezvous-forwarder-run",
                "nat-rendezvous-localhost-smoke", "nat-rendezvous-run"
            ]
        ),
        CLICommandGroup(
            title: "MADI audio",
            names: [
                "madi-full-duplex-run", "madi-full-duplex-synthetic-smoke", "madi-rx-synthetic-smoke",
                "madi-tx-synthetic-smoke"
            ]
        ),
        CLICommandGroup(
            title: "Latency, performance and benchmarks",
            names: [
                "aoip-synthetic-smoke", "drift-plc-certification-synthetic-smoke", "drift-plc-run",
                "drift-plc-synthetic-smoke", "e2e-benchmark-run", "e2e-benchmark-synthetic-smoke",
                "latency-benchmark-synthetic-smoke", "latency-profile-benchmark-synthetic-smoke",
                "latency-profile-synthetic-smoke", "latency-tuning-synthetic-smoke",
                "network-aoip-certification-synthetic-smoke", "performance-audit-synthetic-smoke",
                "realtime-audio-synthetic-smoke", "rx-buffer-benchmark-run"
            ]
        ),
        CLICommandGroup(
            title: "Video and integrated A/V",
            names: [
                "hardware-validation-run", "hardware-validation-synthetic-smoke", "integrated-av-run",
                "integrated-av-synthetic-smoke", "integrated-profile-run",
                "integrated-profile-synthetic-smoke", "video-capture-inventory", "video-capture-run",
                "video-capture-synthetic-smoke", "video-transport-run",
                "video-transport-synthetic-smoke"
            ]
        ),
        CLICommandGroup(
            title: "Control and native app",
            names: [
                "atem-readonly-probe", "lighting-gate-run", "lighting-gate-synthetic-smoke",
                "native-app-runtime-smoke", "native-app-shell-surface-probe",
                "native-app-shell-synthetic-smoke", "osc-cue-external-run", "osc-cue-run",
                "osc-cue-synthetic-smoke"
            ]
        ),
        CLICommandGroup(
            title: "Field and release",
            names: [
                "faster-than-lola-closure-run", "faster-than-lola-closure-synthetic-smoke",
                "field-readiness-run", "field-runtime-proof-run", "field-runtime-synthetic-smoke",
                "open-source-release-readiness-run", "packaging-field-run",
                "packaging-field-synthetic-smoke", "recording-session-run",
                "recording-session-synthetic-smoke", "release-hardening-run",
                "release-hardening-synthetic-smoke"
            ]
        ),
        CLICommandGroup(
            title: "External connectors",
            names: [
                "external-connector-connection-plan-run", "external-connector-executable-preflight-run",
                "external-connector-nmp-endpoint-run", "external-connector-nmp-plan-run",
                "external-connector-nmp-preflight-run", "external-connector-nmp-workflow-run",
                "external-connector-report-run", "external-connector-synthetic-smoke"
            ]
        ),
        CLICommandGroup(
            title: "LoLa compatibility",
            names: [
                "lola-capture-decode", "lola-media-report-run", "lola-packet-fixture-run",
                "lola-raw-link-rx-run", "lola-raw-link-tx-run", "lola-udp-media-rx-run",
                "lola-udp-media-tx-run"
            ]
        ),
        CLICommandGroup(
            title: "Report validators",
            names: [
                "validate-aoip-report", "validate-atem-control-report",
                "validate-audio-loopback-run-report", "validate-direct-p2p-mesh-runtime-report",
                "validate-direct-p2p-mesh-topology-report", "validate-direct-p2p-session-report",
                "validate-direct-p2p-two-peer-plan-report",
                "validate-direct-p2p-two-peer-prototype-report", "validate-direct-p2p-two-peer-report",
                "validate-drift-plc-certification-report", "validate-drift-plc-report",
                "validate-e2e-benchmark-report", "validate-external-connector-connection-plan",
                "validate-external-connector-executable-preflight-report",
                "validate-external-connector-nmp-endpoint-run", "validate-external-connector-nmp-plan",
                "validate-external-connector-nmp-preflight", "validate-external-connector-nmp-workflow",
                "validate-external-connector-report", "validate-external-connector-session-report",
                "validate-faster-than-lola-closure", "validate-field-runtime-proof",
                "validate-hardware-validation-report", "validate-integrated-av-report",
                "validate-integrated-profile-report", "validate-latency-benchmark-report",
                "validate-latency-tuning-report", "validate-lighting-gate-report",
                "validate-lola-capture-report", "validate-lola-media-session-report",
                "validate-lola-packet-fixture-report", "validate-lola-parity-deferred-ledger",
                "validate-loopback-report", "validate-mac-to-mac-connection-establishment-report",
                "validate-madi-full-duplex-report", "validate-madi-rx-report",
                "validate-nat-friendly-route-report", "validate-native-app-shell-report",
                "validate-native-app-shell-surface-probe-report",
                "validate-network-aoip-certification-report", "validate-network-diagnostics-report",
                "validate-open-source-release-readiness-report", "validate-osc-cue-report",
                "validate-packaging-field-report", "validate-performance-audit-report",
                "validate-realtime-audio-engine-report", "validate-recording-session-report",
                "validate-reference-rig-report", "validate-release-hardening-report",
                "validate-rme-fastest-audio-report", "validate-route-certification-report",
                "validate-route-report", "validate-rx-buffer-benchmark-report",
                "validate-udp-pcm-loopback-report", "validate-udp-pcm-loopback-session",
                "validate-udp-pcm-packet", "validate-video-capture-inventory",
                "validate-video-capture-report", "validate-video-transport-report",
                "verify-direct-p2p-session-evidence-bundle"
            ]
        )
    ]

    /// All groups with the session group first.
    public static var groups: [CLICommandGroup] { [sessionGroup] + otherGroups }

    /// Renders the top-level usage text: session commands with descriptions first, then other groups by name.
    public static func usageText() -> String {
        var lines = ["Usage: open-lola <command> [...]", ""]
        for group in groups {
            lines.append("\(group.title):")
            let names = group.descriptions.isEmpty ? group.names.sorted() : group.names
            for name in names {
                if let description = group.descriptions[name] {
                    lines.append("  \(name) - \(description)")
                } else {
                    lines.append("  \(name)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
