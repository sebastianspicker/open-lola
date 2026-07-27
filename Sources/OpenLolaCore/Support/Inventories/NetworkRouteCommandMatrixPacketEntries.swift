// Collects source inventory evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

extension NetworkRouteCommandMatrix {
    static let packetAndUdpRouteEntries: [NetworkRouteCommandMatrixEntry] = [
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-send-once",
            kind: .probe,
            ownerSourceFile: "Sources/open-lola/main.swift",
            parser: "two positional arguments: host and port",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-send-once 127.0.0.1 5004",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "One-shot packet probe; useful for packet contract smoke, not route readiness."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-receive-once",
            kind: .probe,
            ownerSourceFile: "Sources/open-lola/main.swift",
            parser: "one positional argument: port",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-receive-once 5004",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "One-shot receive probe; confirms decode path only."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-udp-pcm-packet",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola validate-udp-pcm-packet " +
                "Tests/OpenLolaCoreTests/Fixtures/UdpPcmPackets/valid/valid-stereo-int16.hex",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "Packet schema validation is a prerequisite but carries no route evidence."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-route-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "UdpPcmRouteReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directFastestCandidate,
            canContributeToFastestDirectEvidence: true,
            representativeCommand: "open-lola validate-route-report " +
                "Tests/OpenLolaCoreTests/Fixtures/UdpPcmRoutes/valid/direct-link-pass.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            notes: "A passing physical direct-link route report can feed fastest-path " +
                "evidence, but route certification still owns broader route ordering."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "validate-route-certification-report",
            kind: .validator,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "fixed-arity path argument",
            outputReport: "MacToMacRouteCertificationReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directCertificationGate,
            canContributeToFastestDirectEvidence: true,
            representativeCommand: "open-lola validate-route-certification-report " +
                "Tests/OpenLolaCoreTests/Fixtures/MacToMacRouteCertificationReports/valid/g04" +
                "-route-certification-partial.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/P2P/MacToMacRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/MacToMacRouteCertificationTests.swift"],
            notes: "Certification is the aggregate route gate and requires the " +
                "direct-link candidate before switched or campus paths."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-route-run",
            kind: .run,
            ownerSourceFile: "Sources/open-lola/Commands/Network/NetworkCommands.swift",
            parser: "UdpPcmRouteRunConfiguration.parse",
            outputReport: "UdpPcmContinuousSenderSummary or UdpPcmRouteReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directFastestCandidate,
            canContributeToFastestDirectEvidence: true,
            representativeCommand: "open-lola udp-pcm-route-run --role receiver --peer 10.10.20.10 --port 5004 " +
                "--sample-rate 48000 --frames 32 --channels 2 --duration-seconds 2 --output " +
                "reports/route.json",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmContinuousRouteRunner.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteRunConfiguration.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            notes: "Receiver mode can emit measured route evidence; sender mode only " +
                "emits a send summary."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/MilestoneCommands.swift",
            parser: "fixed command",
            outputReport: "UdpPcmPacket",
            routeMode: .udpPcmPacketProbe,
            evidenceBoundary: .packetContractOnly,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-localhost-smoke",
            relatedSourceFiles: ["Sources/OpenLolaCore/Network/UDP/UdpPcmPacket.swift"],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmPacketTests.swift"],
            notes: "Local packet smoke stays source-level and cannot close route readiness."
        )),
        entry(NetworkRouteCommandMatrixEntryDraft(
            command: "udp-pcm-route-localhost-smoke",
            kind: .localhostSmoke,
            ownerSourceFile: "Sources/open-lola/Commands/MilestoneCommands.swift",
            parser: "fixed command",
            outputReport: "UdpPcmRouteReport",
            routeMode: .udpPcmRoute,
            evidenceBoundary: .directFastestCandidate,
            canContributeToFastestDirectEvidence: false,
            representativeCommand: "open-lola udp-pcm-route-localhost-smoke",
            relatedSourceFiles: [
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteCertification.swift",
                "Sources/OpenLolaCore/Network/UDP/UdpPcmRouteLocalhostSmoke.swift"
            ],
            relatedTestFiles: ["Tests/OpenLolaCoreTests/UdpPcmRouteReportTests.swift"],
            notes: "Localhost route smoke must remain PARTIAL and is explicitly excluded " +
                "from fastest direct evidence."
        ))
    ]
}
