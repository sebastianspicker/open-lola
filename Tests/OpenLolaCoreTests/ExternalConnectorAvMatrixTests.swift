import Testing

@testable import OpenLolaCore


@Test
func externalConnectorAvMatrixBuildsTxRxAndBidirectionalPlansForEveryRequestedConnector() throws {
    for connector in ExternalConnectorKind.allCases {
        for role in [ExternalConnectorSessionRole.tx, .rx] {
            let configuration = ExternalConnectorSessionConfiguration(
                connector: connector,
                role: role,
                peer: role == .tx || connector != .lola ? "198.51.100.10" : "",
                localHost: "198.51.100.20",
                outputPath: "/tmp/\(connector.rawValue)-\(role.rawValue)-av.json",
                dryRun: true,
                mediaMode: .audioVideo,
                peerAudioPort: connector == .jackTrip && role.transmits ? 4464 : nil
            )

            let report = try ExternalConnectorSessionRunner.run(configuration: configuration)

            try report.validate()
            #expect(report.plan.mediaProfile.audioEnabled)
            #expect(report.plan.mediaProfile.videoEnabled)
            #expect(report.role == role)
        }
    }

    for connector in ExternalConnectorKind.allCases {
        let report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
            connector: connector,
            role: .txRx,
            peer: "198.51.100.10",
            localHost: "198.51.100.20",
            outputPath: "/tmp/\(connector.rawValue)-tx-rx-av.json",
            dryRun: true,
            mediaMode: .audioVideo,
            peerAudioPort: connector == .jackTrip ? 4464 : nil
        ))

        try report.validate()
        #expect(report.role == .txRx)
        #expect(report.plan.role == .txRx)
        #expect(report.plan.mediaProfile.audioEnabled)
        #expect(report.plan.mediaProfile.videoEnabled)
        if connector == .lola {
            #expect(report.lolaMedia?.role == .txRx)
            #expect(report.lolaMedia?.notes.contains("bidirectional") == true)
        }
    }
}

@Test
func ultraGridPlanUsesConfiguredProductionCaptureAndPlaybackModules() throws {
    let tx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ug-tx.json",
        audioCapture: "coreaudio:input-uid",
        videoCapture: "decklink:0"
    ))
    let rx = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .rx,
        peer: "198.51.100.10",
        localHost: "198.51.100.20",
        outputPath: "/tmp/ug-rx.json",
        audioPlayback: "coreaudio:output-uid",
        videoDisplay: "decklink:1"
    ))

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
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "--help",
            outputPath: "/tmp/jacktrip-bad-peer.json",
            peerAudioPort: 4464
        ))
    }

    #expect(throws: ExternalConnectorSessionError.invalidProcessArgument("audioCapture", "--help")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .tx,
            peer: "203.0.113.10",
            outputPath: "/tmp/jacktrip-bad-device.json",
            peerAudioPort: 4464,
            audioCapture: "--help"
        ))
    }
}

@Test
func externalConnectorSessionRejectsInvalidConnectorInputs() throws {
    let configuration = ExternalConnectorSessionConfiguration(connector: .mvtpUltraGrid, role: .tx, peer: "198.51.100.20", outputPath: "/tmp/ug-raw-link.json", rawLinkInterface: "en10")

    #expect(throws: ExternalConnectorSessionError.connectorDoesNotSupportRawLink(.mvtpUltraGrid)) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: configuration)
    }
    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .mvtpUltraGrid,
            role: .rx,
            peer: "",
            localHost: "198.51.100.20",
            outputPath: "/tmp/ug-rx-missing-peer.json"
        ))
    }
    #expect(throws: ExternalConnectorSessionError.missingRequiredArgument("--peer")) {
        _ = try ExternalConnectorLaunchPlan.build(configuration: ExternalConnectorSessionConfiguration(
            connector: .jackTrip,
            role: .rx,
            peer: "",
            localHost: "203.0.113.20",
            outputPath: "/tmp/jacktrip-av-rx-missing-peer.json",
            mediaMode: .audioVideo
        ))
    }
}

private func argumentValue(_ option: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: option), index + 1 < arguments.count else {
        return nil
    }
    return arguments[index + 1]
}
