// Validates ExternalConnectorConnectionPlanValidationHelpers acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

func connectionPlanPreflightOutputPath(
    _ configuration: ExternalConnectorConnectionPlanConfiguration
) -> String {
    let fileName = "\(configuration.connector.rawValue)-executable-preflight.json"
    return "\(normalizedRunDirectory(configuration.runDirectory))/\(fileName)"
}

func connectionPlanShellCommand(_ command: [String]) -> String {
    (["open-lola"] + command).map(shellQuote).joined(separator: " ")
}

func shellQuote(_ value: String) -> String {
    guard !value.isEmpty, value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
          !value.contains("'"), value.range(of: #"[^A-Za-z0-9_./:=@+-]"#, options: .regularExpression) == nil else {
        return "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
    return value
}

func endpointPeer(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    role: ExternalConnectorSessionRole,
    remote: String
) -> String {
    if role.transmits {
        return remote
    }
    if configuration.connector == .lola {
        return remote
    }
    if configuration.connector == .mvtpUltraGrid {
        if configuration.ultraGridTopologyMode == .serverClient, role == .rx {
            return ""
        }
        return remote
    }
    if configuration.connector == .jackTrip, configuration.mediaMode.hasVideo {
        return remote
    }
    return ""
}

func sideScopedPort(
    _ basePort: UInt16,
    side: ExternalConnectorConnectionSide,
    label: String
) throws -> UInt16 {
    guard basePort > 0 else {
        return 0
    }
    guard side == .remote else {
        return basePort
    }
    guard basePort < UInt16.max else {
        throw ExternalConnectorSessionError.invalidPort(label, String(basePort))
    }
    return basePort + 1
}

func normalizedRunDirectory(_ runDirectory: String) -> String {
    guard runDirectory.count > 1, runDirectory.hasSuffix("/") else {
        return runDirectory
    }
    return String(runDirectory.dropLast())
}

func defaultRunDirectory(forOutputPath outputPath: String) -> String {
    guard let slash = outputPath.lastIndex(of: "/") else {
        return "."
    }
    if slash == outputPath.startIndex {
        return "/"
    }
    return String(outputPath[..<slash])
}

func rejectConnectionPlanPlaceholders(_ values: [String], field: String) throws {
    if values.contains(where: { $0.contains("<run-dir>") }) {
        throw ExternalConnectorSessionError.placeholderValue(field)
    }
}

func validateRawLinkConfiguration(_ configuration: ExternalConnectorConnectionPlanConfiguration) throws {
    guard hasRawLinkInput(configuration) else {
        return
    }
    guard configuration.connector == .lola else {
        throw ExternalConnectorSessionError.connectorDoesNotSupportRawLink(configuration.connector)
    }
    try requireRawLinkEndpointInputs(configuration)
}

func hasRawLinkInput(_ configuration: ExternalConnectorConnectionPlanConfiguration) -> Bool {
    configuration.localRawLinkInterface != nil
        || configuration.remoteRawLinkInterface != nil
        || configuration.localMAC != nil
        || configuration.remoteMAC != nil
}

func requireRawLinkEndpointInputs(_ configuration: ExternalConnectorConnectionPlanConfiguration) throws {
    guard configuration.localRawLinkInterface != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--local-raw-link-interface")
    }
    guard configuration.remoteRawLinkInterface != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--remote-raw-link-interface")
    }
    guard configuration.localMAC != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--local-mac")
    }
    guard configuration.remoteMAC != nil else {
        throw ExternalConnectorSessionError.missingRequiredArgument("--remote-mac")
    }
}

func rawLinkInterface(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide
) -> String? {
    guard configuration.connector == .lola else {
        return nil
    }
    return side == .local ? configuration.localRawLinkInterface : configuration.remoteRawLinkInterface
}

func rawLinkSourceMAC(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    role: ExternalConnectorSessionRole
) -> LoLaEthernetAddress? {
    guard configuration.connector == .lola, role.transmits else {
        return nil
    }
    return side == .local ? configuration.localMAC : configuration.remoteMAC
}

func rawLinkDestinationMAC(
    _ configuration: ExternalConnectorConnectionPlanConfiguration,
    side: ExternalConnectorConnectionSide,
    role: ExternalConnectorSessionRole
) -> LoLaEthernetAddress? {
    guard configuration.connector == .lola, role.transmits else {
        return nil
    }
    return side == .local ? configuration.remoteMAC : configuration.localMAC
}

func connectorCLIValue(_ connector: ExternalConnectorKind) -> String {
    switch connector {
    case .lola:
        return "lola"
    case .mvtpUltraGrid:
        return "mvtp-ultragrid"
    case .jackTrip:
        return "jacktrip"
    }
}

func mediaModeCLIValue(_ mediaMode: ExternalConnectorMediaMode) -> String {
    switch mediaMode {
    case .audio:
        return "audio"
    case .video:
        return "video"
    case .audioVideo:
        return "audio-video"
    }
}

func ethernetAddressCLIValue(_ address: LoLaEthernetAddress) -> String {
    address.octets.map { String(format: "%02x", $0) }.joined(separator: ":")
}
