// Coordinates direct-peer session execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Dispatch
import Foundation

extension DirectPeerSessionSocketRunner {
    static func startAndExchangeMediaStart(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint
    ) throws {
        try runner.startMedia()
        try control.send(try latestControlMessage(from: runner, label: "media start"), to: remoteControl)
        try runner.receiveControlMessages([try control.receiveMessage(
            label: "peer media start",
            expectedSource: remoteControl
        )])
    }

    static func exchangeMediaPauseForStopBoundary(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint,
        peerMediaPauseReceived: Bool,
        timeoutNanoseconds: UInt64 = 1_000_000_000
    ) throws {
        try runner.beginRecovery(reason: "audio-video run duration complete")
        try control.send(try latestControlMessage(from: runner, label: "media pause"), to: remoteControl)
        guard !peerMediaPauseReceived else { return }

        let start = DispatchTime.now().uptimeNanoseconds
        let deadlineResult = start.addingReportingOverflow(timeoutNanoseconds)
        let deadline = deadlineResult.overflow ? UInt64.max : deadlineResult.partialValue
        repeat {
            let result = try serviceDirectPeerAVControl(
                runner: &runner,
                control: control,
                remoteControl: remoteControl
            )
            if result.stopReason != nil {
                return
            }
            Thread.sleep(forTimeInterval: 0.001)
        } while DispatchTime.now().uptimeNanoseconds < deadline
    }

    static func exchangeAudioPackets(
        runner: inout PeerSessionRunner,
        packetCount: Int
    ) throws {
        let validatedPacketCount = try directPeerValidatedPacketCount(packetCount)
        for sequence in 1...validatedPacketCount {
            try runner.sendAudioPacket(sequenceNumber: UInt64(sequence))
        }
        for _ in 1...validatedPacketCount {
            try runner.receiveMediaPacket()
        }
    }

    static func exchangeTimingProbe(
        runner: inout PeerSessionRunner
    ) throws {
        try runner.sendAudioTimingProbe(sequenceNumber: 1)
        try runner.receiveMediaPacket()
    }

    static func publishAndExchangeAudioMetadata(
        first: inout PeerSessionRunner,
        firstControl: DirectPeerSessionControlSocket,
        second: inout PeerSessionRunner,
        secondControl: DirectPeerSessionControlSocket
    ) throws {
        if let firstMessage = try first.publishAudioMetadata(metadataSnapshot(for: first)) {
            try firstControl.send(firstMessage, to: secondControl.endpoint)
            try receiveControlMessage(
                ofType: .audioMetadata,
                into: &second,
                control: secondControl,
                expectedSource: firstControl.endpoint,
                label: "first audio metadata"
            )
        }
        if let secondMessage = try second.publishAudioMetadata(metadataSnapshot(for: second)) {
            try secondControl.send(secondMessage, to: firstControl.endpoint)
            try receiveControlMessage(
                ofType: .audioMetadata,
                into: &first,
                control: firstControl,
                expectedSource: secondControl.endpoint,
                label: "second audio metadata"
            )
        }
    }

    static func publishAndExchangeAudioMetadata(
        runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        remoteControl: SessionNetworkEndpoint
    ) throws {
        if let message = try runner.publishAudioMetadata(metadataSnapshot(for: runner)) {
            try control.send(message, to: remoteControl)
        }
        try receiveControlMessage(
            ofType: .audioMetadata,
            into: &runner,
            control: control,
            expectedSource: remoteControl,
            label: "peer audio metadata"
        )
    }

    static func receiveControlMessage(
        ofType expectedType: SessionControlMessageType,
        into runner: inout PeerSessionRunner,
        control: DirectPeerSessionControlSocket,
        expectedSource: SessionNetworkEndpoint,
        label: String,
        maxSkippedMessages: Int = 8
    ) throws {
        for attempt in 0...maxSkippedMessages {
            let message = try control.receiveMessage(
                label: attempt == 0 ? label : "\(label) skipped-\(attempt)",
                expectedSource: expectedSource
            )
            try runner.receiveControlMessages([message])
            if message.type == expectedType {
                return
            }
        }
        throw DirectPeerSessionSocketRunnerError.missingExpectedControlMessage(label)
    }

    static func send(
        _ messages: [SessionControlMessage],
        from socket: DirectPeerSessionControlSocket,
        to endpoint: SessionNetworkEndpoint
    ) throws {
        for message in messages {
            try socket.send(message, to: endpoint)
        }
    }

    private static func latestControlMessage(
        from runner: PeerSessionRunner,
        label: String
    ) throws -> SessionControlMessage {
        guard let message = runner.controlTranscript.last else {
            throw DirectPeerSessionSocketRunnerError.missingExpectedControlMessage(label)
        }
        return message
    }

    private static func metadataSnapshot(for runner: PeerSessionRunner) -> RmeMatrixMetadataSnapshot {
        // Control-plane RME metadata is advisory stereo V1 metadata; full channel capability stays in CapabilitySet.
        let channels = Array(runner.localCapabilities.audio.channelSet.sortedByStableSourceIndex.prefix(2))
        if channels.isEmpty {
            return RmeMatrixMetadataSnapshot.unavailable(
                revision: 1,
                capturedAt: ISO8601DateFormatter().string(from: Date()),
                notes: "No Core Audio channel descriptors were available for advisory metadata."
            )
        }
        return RmeMatrixMetadataSnapshot(
            identity: .init(
                snapshotID: "\(runner.localCapabilities.peer.peerID)-control-metadata-1",
                provider: .coreAudioOnly,
                revision: 1,
                capturedAt: ISO8601DateFormatter().string(from: Date())
            ),
            provenance: .init(
                legalBasis: "Core Audio channel order and open-lola capability document",
                confidence: .highForChannelOrder,
                notes: "Advisory control-plane metadata only; audio playback does not depend on it."
            ),
            matrix: .init(channels: channels, routes: [])
        )
    }
}
