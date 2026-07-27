// Collects direct-peer session evidence, report values, and verdict context so serialized results retain the fields required for review and validation.
import Foundation

func buildAVReport(
    configuration: DirectPeerSessionAVRunConfiguration,
    runner: PeerSessionRunner,
    control: DirectPeerSessionControlSocket,
    runtime: DirectPeerSessionAVRuntimeResult
) throws -> DirectPeerSessionReport {
    try writeAoIPSDPIfNeeded(configuration)
    let report = DirectPeerSessionReport(
        id: "m06-direct-p2p-av-\(configuration.avProfile.rawValue)-"
            + "\(configuration.manual.role.rawValue)-\(Int(Date().timeIntervalSince1970))",
        capturedAt: ISO8601DateFormatter().string(from: Date()),
        configuration: try requireDirectPeerSessionConfiguration(runner.acceptedConfiguration),
        metrics: avReportMetrics(
            runner: runner,
            control: control
        ),
        avRuntime: try avRuntimeMetadata(for: configuration, runtime: runtime),
        verdict: .partial,
        notes: avReportNotes(for: configuration)
    )
    try report.validate()
    return report
}

private func avReportMetrics(
    runner: PeerSessionRunner,
    control: DirectPeerSessionControlSocket
) -> DirectPeerSessionReportMetrics {
    let transportMetrics = runner.transportMetrics()
    return DirectPeerSessionReportMetrics(
            traffic: .init(
                controlMessagesSent: runner.metrics.controlMessagesSent,
                packetsSent: runner.metrics.mediaPacketsSent,
                packetsReceived: runner.metrics.mediaPacketsReceived,
                packetsLost: transportMetrics.packetsLost,
                jitterMicroseconds: transportMetrics.jitterMicroseconds,
                audioPacketsRouted: runner.metrics.audioPacketsRouted,
                videoPacketsRouted: runner.metrics.videoPacketsRouted,
                recoveryEvents: runner.metrics.recoveryEvents
            ),
            control: .init(
                audioPayloadsSentOnControlChannel: runner.metrics.audioPayloadsSentOnControlChannel,
                controlDatagramsSent: control.sentDatagrams,
                controlDatagramsReceived: control.receivedDatagrams,
                audioMetadataMessagesSent: runner.metrics.audioMetadataMessagesSent,
                audioMetadataMessagesReceived: runner.metrics.audioMetadataMessagesReceived,
                timingProbePacketsSent: runner.metrics.timingProbePacketsSent,
                timingProbePacketsReceived: runner.metrics.timingProbePacketsReceived,
                timingProbeMaxAgeMicroseconds: runner.metrics.timingProbeMaxAgeMicroseconds
            ),
            remote: .init(
                metricsMessagesSent: runner.metrics.metricsMessagesSent,
                remoteMetricsMessagesReceived: runner.metrics.remoteMetricsMessagesReceived,
                remotePacketsLost: runner.metrics.remotePacketsLost,
                remoteJitterMicroseconds: runner.metrics.remoteJitterMicroseconds,
                remoteLatePackets: runner.metrics.remoteLatePackets,
                remoteCallbackDurationP99Microseconds: runner.metrics.remoteCallbackDurationP99Microseconds,
                remoteQueueDepthPackets: runner.metrics.remoteQueueDepthPackets,
                remoteCPUPercent: runner.metrics.remoteCPUPercent
            ),
            remoteResources: .init(
                remoteMemoryResidentBytes: runner.metrics.remoteMemoryResidentBytes,
                remoteUnderruns: runner.metrics.remoteUnderruns,
                remoteOverruns: runner.metrics.remoteOverruns,
                remoteVideoFramesDropped: runner.metrics.remoteVideoFramesDropped
            )
        )
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
 session: .init(avProfile: configuration.avProfile, previewMode: configuration.preview, mediaSourceMode: configuration.mediaSourceMode, qualityPolicy: configuration.qualityPolicy, usefulMediaProof: directPeerUsefulMediaProof(
            runtime: runtime,
            policy: configuration.qualityPolicy
        )),
 audio: .init(deviceUID: configuration.audioDeviceUID, inputDeviceUID: configuration.inputDeviceUID, outputDeviceUID: configuration.outputDeviceUID, sampleRateHertz: configuration.sampleRateHertz, selectedBufferFrameSize: configuration.framesPerPacket, latencyProfile: policy.latencyProfile, rxBufferProfile: policy.rxBufferProfile),
 transport: .init(audioTransport: configuration.audioTransport, opusBitrateBitsPerSecond: opusBitrate(for: configuration.audioTransport), opusFrameDurationMilliseconds: opusFrameDuration(for: configuration.audioTransport), aoipProfile: aoipProfile(for: configuration.audioTransport), rtpPayloadType: rtpPayloadType(for: configuration.audioTransport), rtpClockRate: rtpClockRate(for: configuration.audioTransport), rtpPacketTimeMilliseconds: rtpPacketTime(for: configuration), rtpSSRC: rtpSSRC(for: configuration)),
 video: .init(deviceID: configuration.videoDeviceID, compression: configuration.videoCompression, jpegXSRateBitsPerPixel: jpegXSRateBitsPerPixel(for: configuration.videoCompression), frameRate: configuration.videoFrameRate, streamID: configuration.videoStreamID),
 evidence: .init(fastestPassBlockedReason: "physical two-Mac audio-only baseline", runtimeMetrics: runtime.metrics, videoFormat: runtime.videoFormat, receiveProof: runtime.receiveProof, fastestAVBaselineComparison: nil, ptpEvidenceSummary: nil, sdpPath: configuration.aoipSDPOutputPath)
)
}

private func opusBitrate(
    for transport: DirectPeerSessionAudioTransport
) -> Int? {
    transport == .openLolaOpusCeltLowDelay ? OpusCELTLowDelayConstants.bitrateBitsPerSecond : nil
}

private func opusFrameDuration(
    for transport: DirectPeerSessionAudioTransport
) -> Double? {
    transport == .openLolaOpusCeltLowDelay ? OpusCELTLowDelayConstants.frameDurationMilliseconds : nil
}

private func aoipProfile(for transport: DirectPeerSessionAudioTransport) -> String? {
    transport == .aes67ST2110L24 ? AES67ST2110L24Profile.profileName : nil
}

private func rtpPayloadType(for transport: DirectPeerSessionAudioTransport) -> UInt8? {
    transport == .aes67ST2110L24 ? AES67ST2110L24Profile.payloadType : nil
}

private func rtpClockRate(for transport: DirectPeerSessionAudioTransport) -> Int? {
    transport == .aes67ST2110L24 ? AES67ST2110L24Profile.clockRateHertz : nil
}

private func rtpPacketTime(for configuration: DirectPeerSessionAVRunConfiguration) -> Double? {
    guard configuration.audioTransport == .aes67ST2110L24 else {
        return nil
    }
    return AES67ST2110L24Profile.packetTime(
        forFramesPerPacket: configuration.framesPerPacket
    )?.milliseconds
}

private func rtpSSRC(for configuration: DirectPeerSessionAVRunConfiguration) -> UInt32? {
    configuration.audioTransport == .aes67ST2110L24
        ? directPeerReportAES67SSRC(peerID: configuration.manual.localPeerID)
        : nil
}

private func jpegXSRateBitsPerPixel(for compression: DirectPeerSessionVideoCompression) -> Float? {
    compression == .jpegXS ? JPEGXSReferenceCodec.bitsPerPixel : nil
}

private func avReportNotes(for configuration: DirectPeerSessionAVRunConfiguration) -> String {
    switch configuration.avProfile {
    case .balanced:
        return balancedAVReportNotes(for: configuration)
    case .fastest:
        return fastestAVReportNotes(for: configuration)
    }
}

private func balancedAVReportNotes(for configuration: DirectPeerSessionAVRunConfiguration) -> String {
    "Manual-address direct P2P balanced AV run used native UDP media envelope with "
        + "\(audioDescription(for: configuration.audioTransport)), explicit audio device UID, and one "
        + "\(videoDescription(for: configuration.videoCompression)) stream. Balanced AV is not "
        + "fastest-path claim; PASS still requires two-Mac physical audio/video validation, "
        + "device evidence, packet capture, latency, and jitter evidence."
}

private func fastestAVReportNotes(for configuration: DirectPeerSessionAVRunConfiguration) -> String {
    switch configuration.audioTransport {
    case .openLolaOpusCeltLowDelay:
        "Manual-address direct P2P fastest AV run used Opus CELT restricted low-delay audio "
            + "as useful transport evidence. VERDICT remains PARTIAL not fastest-audio PASS "
            + "evidence because codec delay changes speed claim."
    case .aes67ST2110L24:
        "Manual-address direct P2P fastest AV run used AES67/ST 2110-30-shaped RTP L24 audio "
            + "as source-level AoIP evidence. VERDICT remains PARTIAL not fastest-audio or "
            + "real AoIP PASS evidence without external route, packet capture, and PTP lock/"
            + "profile/domain/grandmaster/offset evidence."
    case .openLolaRaw:
        "Manual-address direct P2P fastest AV run used direct audio-first profile, direct RX buffer "
            + "profile, fixed Core Audio frame size, latest-frame "
            + "\(videoDescription(for: configuration.videoCompression)), preview "
            + "\(configuration.preview.rawValue). VERDICT remains PARTIAL until two-Mac evidence "
            + "proves audio latency equals audio-only fastest baseline."
    }
}
private func audioDescription(for transport: DirectPeerSessionAudioTransport) -> String {
    switch transport {
    case .openLolaRaw:
        "raw PCM audio"
    case .openLolaOpusCeltLowDelay:
        "Opus CELT restricted low-delay audio"
    case .aes67ST2110L24:
        "AES67/ST 2110-30-shaped RTP L24 audio"
    }
}

private func videoDescription(for compression: DirectPeerSessionVideoCompression) -> String {
    compression == .jpegXS
        ? "JPEG XS 4 bpp AVFoundation/BGRA video"
        : "raw AVFoundation/BGRA video"
}

private func writeAoIPSDPIfNeeded(_ configuration: DirectPeerSessionAVRunConfiguration) throws {
    guard configuration.audioTransport == .aes67ST2110L24,
          let path = configuration.aoipSDPOutputPath else {
        return
    }
    let sdp = AES67ST2110L24SDP(
        address: configuration.manual.localHost,
        port: configuration.manual.audioPort,
        direction: .bidirectional,
        packetTime: try directPeerReportAES67PacketTime(for: configuration)
    )
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try Data(sdp.text().utf8).write(to: url)
}

private func directPeerReportAES67PacketTime(
    for configuration: DirectPeerSessionAVRunConfiguration
) throws -> AES67ST2110L24PacketTime {
    guard let packetTime = AES67ST2110L24Profile.packetTime(
        forFramesPerPacket: configuration.framesPerPacket
    ) else {
        throw DirectPeerSessionAVRuntimeError.unsupportedAudioCompressionShape(
            "unsupported aes67-st2110-l24 packet time"
        )
    }
    return packetTime
}

private func directPeerReportAES67SSRC(peerID: String) -> UInt32 {
    let hash = directPeerFNV1A32(peerID)
    return hash == 0 ? 1 : hash
}
