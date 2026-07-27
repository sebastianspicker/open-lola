// Verifies that external connector AV matrix builds TX RX and bidirectional plans for every requested connector.
import Testing

@testable import OpenLolaCore

@Test
func externalConnectorAvMatrixBuildsTxRxAndBidirectionalPlansForEveryRequestedConnector() throws {
    for connector in ExternalConnectorKind.allCases {
        for role in [ExternalConnectorSessionRole.tx, .rx] {
            try assertExternalConnectorAvMatrixReport(connector: connector, role: role)
        }

        try assertExternalConnectorAvMatrixReport(connector: connector, role: .txRx)
    }
}

private func assertExternalConnectorAvMatrixReport(
    connector: ExternalConnectorKind,
    role: ExternalConnectorSessionRole
) throws {
    let outputRole = role == .txRx ? "tx-rx" : role.rawValue
    let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: connector,
  role: role,
  peer: role == .rx && connector == .lola ? "" : "198.51.100.10",
  outputPath: "/tmp/\(connector.rawValue)-\(outputRole)-av.json"
) { input in
  input.localHost = "198.51.100.20"
  input.dryRun = true
  input.mediaMode = .audioVideo
  input.peerAudioPort = connector == .jackTrip && role.transmits ? 4464 : nil
}))

    try report.validate()
    #expect(report.role == role)
    #expect(report.plan.mediaProfile.audioEnabled)
    #expect(report.plan.mediaProfile.videoEnabled)
    #expect(report.runtimeEvidenceState == .noRuntimeErrorRecordedEvidenceIncomplete)

    assertTxRxExternalConnectorAvMatrixReport(report, connector: connector, role: role)
}

private func assertTxRxExternalConnectorAvMatrixReport(
    _ report: ExternalConnectorSessionReport,
    connector: ExternalConnectorKind,
    role: ExternalConnectorSessionRole
) {
    guard role == .txRx else {
        return
    }
    #expect(report.plan.role == .txRx)
    if connector == .lola {
        #expect(report.lolaMedia?.role == .txRx)
        #expect(report.lolaMedia?.notes.contains("bidirectional") == true)
    }
}

@Test
func ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules() throws {
    // swiftlint:disable:next identifier_name
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-tx.json"
) { input in
  input.audioCapture = "coreaudio:input-uid"
  input.videoCapture = "decklink:0"
}))
    // swiftlint:disable:next identifier_name
    let rx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .rx,
  peer: "198.51.100.10",
  outputPath: "/tmp/ug-rx.json"
) { input in
  input.localHost = "198.51.100.20"
  input.audioPlayback = "coreaudio:output-uid"
  input.videoDisplay = "decklink:1"
}))

    #expect(argumentValue("--video-capture", in: tx.arguments) == "decklink:0")
    #expect(argumentValue("--audio-capture", in: tx.arguments) == "coreaudio:input-uid")
    #expect(argumentValue("--video-display", in: rx.arguments) == "decklink:1")
    #expect(argumentValue("--audio-playback", in: rx.arguments) == "coreaudio:output-uid")
    #expect(rx.arguments.last == "198.51.100.10")
    #expect(tx.protocolFacts.contains { $0.contains("reference metadata") })
}

@Test
func jackTripPlanRejectsFlagLikePeerAndDeviceArguments() throws {
    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("peer", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "--help",
  outputPath: "/tmp/jacktrip-bad-peer.json"
) { input in
  input.peerAudioPort = 4464
}))
    }

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("audioCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .tx,
  peer: "203.0.113.10",
  outputPath: "/tmp/jacktrip-bad-device.json"
) { input in
  input.peerAudioPort = 4464
  input.audioCapture = "--help"
}))
    }
}

@Test
func externalConnectorSessionRejectsInvalidConnectorInputs() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .tx,
  peer: "198.51.100.20",
  outputPath: "/tmp/ug-raw-link.json"
) { input in
  input.rawLinkInterface = "en10"
})

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportRawLink(.mvtpUltraGrid)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .rx,
  peer: "",
  outputPath: "/tmp/ug-rx-missing-peer.json"
) { input in
  input.localHost = "198.51.100.20"
}))
    }
    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(.init(
  connector: .jackTrip,
  role: .rx,
  peer: "",
  outputPath: "/tmp/jacktrip-av-rx-missing-peer.json"
) { input in
  input.localHost = "203.0.113.20"
  input.mediaMode = .audioVideo
}))
    }
}

private func argumentValue(_ option: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: option), index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}
