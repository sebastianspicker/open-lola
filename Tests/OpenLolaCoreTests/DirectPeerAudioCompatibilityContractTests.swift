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
        avProfile: .balanced,
        previewMode: .off,
        mediaSourceMode: .syntheticFixture,
        qualityPolicy: .requireUsefulMedia,
        usefulMediaProof: .requiredButNotProven,
        audioDeviceUID: "legacy-full-duplex",
        inputDeviceUID: "split-input",
        outputDeviceUID: "split-output",
        sampleRateHertz: 48_000,
        selectedBufferFrameSize: 120,
        latencyProfile: .balancedAV,
        rxBufferProfile: .small,
        videoDeviceID: "synthetic-video",
        audioTransport: .aes67ST2110L24,
        videoCompression: .raw,
        videoFrameRate: 30,
        videoStreamID: 101,
        fastestPassBlockedReason: "missing fastest baseline"
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
        manual: directPeerCompatibilityManualRunConfiguration(),
        durationSeconds: 1,
        inputDeviceUID: "split-input",
        outputDeviceUID: "split-output",
        sampleRateHertz: 48_000,
        framesPerPacket: 120,
        inputChannels: [0, 1],
        outputChannels: [0, 1],
        videoDeviceID: "synthetic-video",
        audioCompression: .opusCELTLowDelay
    )

    #expect(configuration.audioDeviceUID == "split-input")
    #expect(configuration.inputDeviceUID == "split-input")
    #expect(configuration.outputDeviceUID == "split-output")
    #expect(configuration.audioTransport == .openLolaOpusCeltLowDelay)
    #expect(configuration.audioCompression == .opusCELTLowDelay)
}

@Test
func directPeerRealtimeGraphLegacyInitializerEncodesOnlySplitDeviceUIDs() throws {
    let configuration = DirectPeerRealtimeAudioGraphConfiguration(
        audioDeviceUID: "legacy-full-duplex",
        sampleRateHertz: 48_000,
        framesPerBuffer: 32,
        channelCount: 2,
        sampleFormat: .float32LittleEndian,
        inputChannelMap: [0, 1],
        outputChannelMap: [0, 1]
    )

    let encoded = try JSONEncoder().encode(configuration)
    let encodedObject = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

    #expect(configuration.inputDeviceUID == "legacy-full-duplex")
    #expect(configuration.outputDeviceUID == "legacy-full-duplex")
    #expect(encodedObject["audioDeviceUID"] == nil)
    #expect(encodedObject["inputDeviceUID"] as? String == "legacy-full-duplex")
    #expect(encodedObject["outputDeviceUID"] as? String == "legacy-full-duplex")
}

private func directPeerCompatibilityManualRunConfiguration() -> DirectPeerSessionManualRunConfiguration {
    DirectPeerSessionManualRunConfiguration(
        role: .initiator,
        localPeerID: "peer-a",
        remotePeerID: "peer-b",
        localHost: "127.0.0.1",
        remoteHost: "127.0.0.1",
        controlPort: 19_101,
        remoteControlPort: 19_102,
        audioPort: 19_103,
        videoPort: 19_104,
        metricsPort: 19_105,
        audioChannelCount: 2
    )
}
