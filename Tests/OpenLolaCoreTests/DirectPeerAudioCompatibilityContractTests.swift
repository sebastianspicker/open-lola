// Verifies that direct peer runtime metadata decodes legacy audio compression and single device UID.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func directPeerRuntimeMetadataDecodesLegacyAudioCompressionAndSingleDeviceUID() throws {
    let legacyJSON = Data("""
    {
      "avProfile": "balanced",
      "previewMode": "off",
      "mediaSourceMode": "syntheticFixture",
      "audioDeviceUID": "legacy-full-duplex",
      "sampleRateHertz": 48000,
      "selectedBufferFrameSize": 120,
      "latencyProfile": "balancedAV",
      "rxBufferProfile": "small",
      "videoDeviceID": "legacy-video",
      "audioCompression": "opus-celt-ld",
      "videoCompression": "raw",
      "videoFrameRate": 30,
      "videoStreamID": 101,
      "fastestPassBlockedReason": "missing fastest baseline"
    }
    """.utf8)

    let metadata = try JSONDecoder().decode(DirectPeerSessionAVRuntimeMetadata.self, from: legacyJSON)

    #expect(metadata.audioDeviceUID == "legacy-full-duplex")
    #expect(metadata.inputDeviceUID == "legacy-full-duplex")
    #expect(metadata.outputDeviceUID == "legacy-full-duplex")
    #expect(metadata.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(metadata.audioCompression == .opusCELTLowDelay)
    #expect(metadata.usefulMediaProof == .unknown)
}

@Test
func directPeerRuntimeMetadataPrefersCanonicalAudioTransportAndSplitDeviceUIDs() throws {
    let mixedJSON = Data("""
    {
      "avProfile": "balanced",
      "previewMode": "off",
      "mediaSourceMode": "syntheticFixture",
      "qualityPolicy": "require-useful-media",
      "usefulMediaProof": "required-but-not-proven",
      "audioDeviceUID": "legacy-full-duplex",
      "inputDeviceUID": "split-input",
      "outputDeviceUID": "split-output",
      "sampleRateHertz": 48000,
      "selectedBufferFrameSize": 120,
      "latencyProfile": "balancedAV",
      "rxBufferProfile": "small",
      "videoDeviceID": "legacy-video",
      "audioTransport": "aes67-st2110-l24",
      "audioCompression": "opus-celt-ld",
      "videoCompression": "raw",
      "videoFrameRate": 30,
      "videoStreamID": 101,
      "fastestPassBlockedReason": "missing fastest baseline"
    }
    """.utf8)

    let metadata = try JSONDecoder().decode(DirectPeerSessionAVRuntimeMetadata.self, from: mixedJSON)

    #expect(metadata.audioDeviceUID == "legacy-full-duplex")
    #expect(metadata.inputDeviceUID == "split-input")
    #expect(metadata.outputDeviceUID == "split-output")
    #expect(metadata.audioTransport == .aes67ST2110L24)
    #expect(metadata.audioCompression == .raw)
    #expect(metadata.qualityPolicy == .requireUsefulMedia)
}

@Test
func directPeerRuntimeMetadataEncodesCanonicalTransportAndSplitUIDs() throws {
    let metadata = DirectPeerSessionAVRuntimeMetadata(
 session: .init(avProfile: .balanced, previewMode: .off, mediaSourceMode: .syntheticFixture, qualityPolicy: .requireUsefulMedia, usefulMediaProof: .requiredButNotProven),
 audio: .init(deviceUID: "legacy-full-duplex", inputDeviceUID: "split-input", outputDeviceUID: "split-output", sampleRateHertz: 48_000, selectedBufferFrameSize: 120, latencyProfile: .balancedAV, rxBufferProfile: .small),
 transport: .init(audioTransport: .aes67ST2110L24, opusBitrateBitsPerSecond: nil, opusFrameDurationMilliseconds: nil, aoipProfile: nil, rtpPayloadType: nil, rtpClockRate: nil, rtpPacketTimeMilliseconds: nil, rtpSSRC: nil),
 video: .init(deviceID: "synthetic-video", compression: .raw, jpegXSRateBitsPerPixel: nil, frameRate: 30, streamID: 101),
 evidence: .init(fastestPassBlockedReason: "missing fastest baseline", runtimeMetrics: .empty, videoFormat: nil, receiveProof: nil, fastestAVBaselineComparison: nil, ptpEvidenceSummary: nil)
)

    let encoded = try JSONEncoder().encode(metadata)
    let encodedObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(encodedObject["audioTransport"] as? String == "aes67-st2110-l24")
    #expect(encodedObject["audioCompression"] == nil)
    #expect(encodedObject["inputDeviceUID"] as? String == "split-input")
    #expect(encodedObject["outputDeviceUID"] as? String == "split-output")
}

@Test
func directPeerAVRunConfigurationMapsLegacyCompressionInitializerToCanonicalTransport() {
    let configuration = DirectPeerSessionAVRunConfiguration(
        manual: directPeerCompatibilityManualRunConfiguration(), durationSeconds: 1,
        devices: .init(audioDeviceUID: nil, inputDeviceUID: "split-input", outputDeviceUID: "split-output"),
        audio: .init(sampleRateHertz: 48_000, framesPerPacket: 120, sampleFormat: .float32LittleEndian, inputChannels: [0, 1], outputChannels: [0, 1], transport: nil, compression: .opusCELTLowDelay),
        video: .init(deviceID: "synthetic-video", width: 1_280, height: 720, pixelFormat: "bgra8", compression: .raw, frameRate: 30, streamID: 100),
        quality: .init(profile: .balanced, rxBufferProfile: nil, preview: .on, mediaSourceMode: .production, policy: .requireUsefulMedia),
        aoip: .init(sdpOutputPath: nil, sdpInputPath: nil))

    #expect(configuration.audioDeviceUID == "split-input")
    #expect(configuration.inputDeviceUID == "split-input")
    #expect(configuration.outputDeviceUID == "split-output")
    #expect(configuration.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(configuration.audioCompression == .opusCELTLowDelay)
}

@Test
func directPeerRealtimeGraphLegacyInitializerEncodesOnlySplitDeviceUIDs() throws {
    let configuration = standardDirectPeerAudioGraphConfiguration(
        inputDeviceUID: "legacy-full-duplex",
        outputDeviceUID: "legacy-full-duplex"
    )

    let encoded = try JSONEncoder().encode(configuration)
    let encodedObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    let decoded = try JSONDecoder().decode(DirectPeerRealtimeAudioGraphConfiguration.self, from: encoded)

    #expect(decoded == configuration)
    #expect(configuration.inputDeviceUID == "legacy-full-duplex")
    #expect(configuration.outputDeviceUID == "legacy-full-duplex")
    #expect(encodedObject["audioDeviceUID"] == nil)
    #expect(encodedObject["inputDeviceUID"] as? String == "legacy-full-duplex")
    #expect(encodedObject["outputDeviceUID"] as? String == "legacy-full-duplex")
}

private func directPeerCompatibilityManualRunConfiguration() -> DirectPeerSessionManualRunConfiguration {
    DirectPeerSessionManualRunConfiguration(identity: .init(role: .initiator, localPeerID: "peer-a", remotePeerID: "peer-b"), network: .init(localHost: "127.0.0.1", remoteHost: "127.0.0.1", ports: .init(controlPort: 19_101, remoteControlPort: 19_102, audioPort: 19_103, videoPort: 19_104, metricsPort: 19_105)), tuning: .init(packetCount: 3, audioChannelCount: 2, timeoutSeconds: 5, dscp: nil))
}
