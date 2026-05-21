import Foundation

func buildAVReport(
    configuration: DirectPeerSessionAVRunConfiguration,
    runner: PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    runtime: DirectPeerSessionAVRuntimeResult
) throws -> DirectPeerSessionReport {
    try writeAoIPSDPIfNeeded(configuration)
    let transportMetrics = runner.transportMetrics()
    let report = DirectPeerSessionReport(
        id: "m06-direct-p2p-av-\(configuration.avProfile.rawValue)-\(configuration.manual.role.rawValue)-\(Int(Date().timeIntervalSince1970))",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        configuration: try requireDirectPeerSessionConfiguration(runner.acceptedConfiguration),
        metrics: DirectPeerSessionReportMetrics(
            controlMessagesSent: runner.metrics.controlMessagesSent,
            packetsSent: runner.metrics.mediaPacketsSent,
            packetsReceived: runner.metrics.mediaPacketsReceived,
            packetsLost: transportMetrics.packetsLost,
            jitterMicroseconds: transportMetrics.jitterMicroseconds,
            audioPacketsRouted: runner.metrics.audioPacketsRouted,
            videoPacketsRouted: runner.metrics.videoPacketsRouted,
            recoveryEvents: runner.metrics.recoveryEvents,
            audioPayloadsSentOnControlChannel: runner.metrics.audioPayloadsSentOnControlChannel,
            controlDatagramsSent: control.sentDatagrams,
            controlDatagramsReceived: control.receivedDatagrams,
            audioMetadataMessagesSent: runner.metrics.audioMetadataMessagesSent,
            audioMetadataMessagesReceived: runner.metrics.audioMetadataMessagesReceived,
            timingProbePacketsSent: runner.metrics.timingProbePacketsSent,
            timingProbePacketsReceived: runner.metrics.timingProbePacketsReceived,
            timingProbeMaxAgeMicroseconds: runner.metrics.timingProbeMaxAgeMicroseconds,
            metricsMessagesSent: runner.metrics.metricsMessagesSent,
            remoteMetricsMessagesReceived: runner.metrics.remoteMetricsMessagesReceived,
            remotePacketsLost: runner.metrics.remotePacketsLost,
            remoteJitterMicroseconds: runner.metrics.remoteJitterMicroseconds,
            remoteLatePackets: runner.metrics.remoteLatePackets,
            remoteCallbackDurationP99Microseconds: runner.metrics.remoteCallbackDurationP99Microseconds,
            remoteQueueDepthPackets: runner.metrics.remoteQueueDepthPackets,
            remoteCPUPercent: runner.metrics.remoteCPUPercent,
            remoteMemoryResidentBytes: runner.metrics.remoteMemoryResidentBytes,
            remoteUnderruns: runner.metrics.remoteUnderruns,
            remoteOverruns: runner.metrics.remoteOverruns,
            remoteVideoFramesDropped: runner.metrics.remoteVideoFramesDropped
        ),
        avRuntime: try avRuntimeMetadata(for: configuration, runtime: runtime),
        verdict: .partial,
        notes: avReportNotes(for: configuration)
    )
    try report.validate()
    return report
}

private func avRuntimeMetadata(
    for configuration: DirectPeerSessionAVRunConfiguration,
    runtime: DirectPeerSessionAVRuntimeResult
) throws -> DirectPeerSessionAVRuntimeMetadata {
    let policy = try DirectPeerSessionAVBufferPolicy.resolve(
        avProfile: configuration.avProfile,
        rxBufferProfile: configuration.rxBufferProfile,
        framesPerPacket: configuration.framesPerPacket,
        sampleRateHertz: configuration.sampleRateHertz
    )
    return DirectPeerSessionAVRuntimeMetadata(
        avProfile: configuration.avProfile,
        previewMode: configuration.preview,
        mediaSourceMode: configuration.mediaSourceMode,
        qualityPolicy: configuration.qualityPolicy,
        usefulMediaProof: directPeerUsefulMediaProof(
            runtime: runtime,
            policy: configuration.qualityPolicy
        ),
        audioDeviceUID: configuration.audioDeviceUID,
        inputDeviceUID: configuration.inputDeviceUID,
        outputDeviceUID: configuration.outputDeviceUID,
        sampleRateHertz: configuration.sampleRateHertz,
        selectedBufferFrameSize: configuration.framesPerPacket,
        latencyProfile: policy.latencyProfile,
        rxBufferProfile: policy.rxBufferProfile,
        videoDeviceID: configuration.videoDeviceID,
        audioTransport: configuration.audioTransport,
        opusBitrateBitsPerSecond: configuration.audioTransport == .openLolaOpusCeltLowDelay
            ? OpusCELTLowDelayConstants.bitrateBitsPerSecond
            : nil,
        opusFrameDurationMilliseconds: configuration.audioTransport == .openLolaOpusCeltLowDelay
            ? OpusCELTLowDelayConstants.frameDurationMilliseconds
            : nil,
        aoipProfile: configuration.audioTransport == .aes67ST2110L24
            ? AES67ST2110L24Profile.profileName
            : nil,
        rtpPayloadType: configuration.audioTransport == .aes67ST2110L24
            ? AES67ST2110L24Profile.payloadType
            : nil,
        rtpClockRate: configuration.audioTransport == .aes67ST2110L24
            ? AES67ST2110L24Profile.clockRateHertz
            : nil,
        rtpPacketTimeMilliseconds: configuration.audioTransport == .aes67ST2110L24
            ? AES67ST2110L24Profile.packetTimeMilliseconds
            : nil,
        rtpSSRC: configuration.audioTransport == .aes67ST2110L24
            ? directPeerReportAES67SSRC(peerID: configuration.manual.localPeerID)
            : nil,
        sdpPath: configuration.aoipSDPOutputPath,
        ptpEvidenceSummary: nil,
        videoCompression: configuration.videoCompression,
        jpegXSRateBitsPerPixel: configuration.videoCompression == .jpegXS ? JPEGXSReferenceCodec.bitsPerPixel : nil,
        videoFrameRate: configuration.videoFrameRate,
        videoStreamID: configuration.videoStreamID,
        fastestPassBlockedReason: "physical two-Mac audio-only baseline, fastest AV comparison, packet capture, analog latency, jitter, and visible received-video evidence are not attached",
        runtimeMetrics: runtime.metrics,
        videoFormat: runtime.videoFormat,
        receiveProof: runtime.receiveProof
    )
}

private func avReportNotes(for configuration: DirectPeerSessionAVRunConfiguration) -> String {
    let videoDescription = configuration.videoCompression == .jpegXS
        ? "JPEG XS 4 bpp AVFoundation/BGRA video"
        : "raw AVFoundation/BGRA video"
    let audioDescription = switch configuration.audioTransport {
    case .openLolaRaw:
        "raw PCM audio"
    case .openLolaOpusCeltLowDelay:
        "Opus CELT restricted low-delay audio"
    case .aes67ST2110L24:
        "AES67/ST 2110-30-shaped RTP L24 audio"
    }
    switch configuration.avProfile {
    case .balanced:
        return "Manual-address direct P2P balanced AV run used the native UDP media envelope with \(audioDescription), explicit audio device UID, and one \(videoDescription) stream. Balanced AV is not the fastest-path claim; PASS still requires two-Mac physical audio/video validation, device evidence, packet capture, latency, and jitter evidence."
    case .fastest:
        if configuration.audioTransport == .openLolaOpusCeltLowDelay {
            return "Manual-address direct P2P fastest AV run used Opus CELT restricted low-delay audio as useful transport evidence. VERDICT remains PARTIAL and is not fastest-audio PASS evidence because codec delay changes the speed claim."
        }
        if configuration.audioTransport == .aes67ST2110L24 {
            return "Manual-address direct P2P fastest AV run used AES67/ST 2110-30-shaped RTP L24 audio as source-level AoIP evidence. VERDICT remains PARTIAL and is not fastest-audio or real AoIP PASS evidence without external route, packet capture, and PTP lock/profile/domain/grandmaster/offset evidence."
        }
        return "Manual-address direct P2P fastest AV run used the direct audio-first profile, direct RX buffer profile, fixed Core Audio frame size, latest-frame \(videoDescription), and preview \(configuration.preview.rawValue). VERDICT remains PARTIAL until two-Mac evidence proves audio latency equals the audio-only fastest baseline."
    }
}

private func writeAoIPSDPIfNeeded(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    guard configuration.audioTransport == .aes67ST2110L24,
          let path = configuration.aoipSDPOutputPath else {
        return
    }
    let sdp = AES67ST2110L24SDP(
        address: configuration.manual.localHost,
        port: configuration.manual.audioPort,
        direction: .bidirectional
    )
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(sdp.text().utf8).write(to: url)
}

private func directPeerReportAES67SSRC(peerID: String) -> UInt32 {
    let hash = directPeerFNV1A32(peerID)
    return hash == 0 ? 1 : hash
}
