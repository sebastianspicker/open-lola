import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridAESGCMEncryptionWrapsAudioAndVideoPackets() throws {
    let configuration = try UltraGridEncryptionConfiguration(
        mode: .aes128GCM,
        passphrase: "shared test passphrase"
    )
    let iv = Data((0..<16).map(UInt8.init))
    let audio = try UltraGridCompatibility.audioPacket(UltraGridAudioPacketRequest(
        sequenceNumber: 7,
        timestamp: 128,
        ssrc: 0x1234_5678,
        channels: 2,
        sampleRateHertz: 48_000,
        framesPerPacket: 128,
        pcmPayload: Data([0, 1, 2, 3, 4, 5, 6, 7])
    ))
    let encryptedAudio = try UltraGridCompatibility.encryptedAudioPacket(
        audio,
        configuration: configuration,
        iv: iv
    )
    let decryptedAudio = try UltraGridCompatibility.decode(
        encryptedAudio,
        encryptionConfiguration: configuration
    ).rtp
    let encryptedAudioPayload = encryptedAudio.payload

    #expect(encryptedAudio.header.payloadType == UltraGridCompatibility.encryptedAudioPayloadType)
    #expect(encryptedAudioPayload[UltraGridAudioPayloadHeader.byteCount] == UltraGridOpenSSLCipherMode.aes128GCM.rawValue)
    #expect(decryptedAudio.header.payloadType == UltraGridCompatibility.audioPayloadType)
    #expect(decryptedAudio.payload == audio.payload)

    let video = try #require(try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        framePayload: Data((0..<128).map(UInt8.init)),
        frameID: 2,
        sequenceStart: 10,
        timestamp: 9_000,
        ssrc: 0x8765_4321,
        width: 8,
        height: 8,
        frameRate: 30,
        bitsPerPixel: 8
    )).first)
    let encryptedVideo = try UltraGridCompatibility.encryptedVideoPacket(
        video,
        configuration: configuration,
        iv: iv
    )
    let decryptedVideo = try UltraGridCompatibility.decode(
        encryptedVideo,
        encryptionConfiguration: configuration
    ).rtp

    #expect(encryptedVideo.header.payloadType == UltraGridCompatibility.encryptedVideoPayloadType)
    #expect(decryptedVideo.header.payloadType == UltraGridCompatibility.videoPayloadType)
    #expect(decryptedVideo.payload == video.payload)
}

@Test
func ultraGridEncryptedRunnerProducesAndConsumesPT24PT25() throws {
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .txRx,
        peer: "127.0.0.1",
        localHost: "127.0.0.1",
        outputPath: "/tmp/ug-encrypted-native.json",
        dryRun: false,
        mediaMode: .audioVideo,
        videoWidth: 8,
        videoHeight: 8,
        videoFrameRate: 30,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1,
        ultraGridEncryptionMode: .aes128GCM,
        ultraGridEncryptionPassphrase: "shared test passphrase"
    )
    let datagrams = try UltraGridCompatibilityRunner.buildDatagrams(configuration: configuration)
    let receiver = UltraGridMemoryMediaReceiver(datagrams: datagrams.map {
        UltraGridCompatibilityDatagram(
            stream: $0.stream,
            sourceHost: "127.0.0.1",
            sourcePort: 40_000,
            destinationPort: $0.destinationPort,
            rtp: $0.rtp
        )
    })

    let report = try UltraGridCompatibilityRunner.run(
        configuration: configuration,
        transmitter: UltraGridMemoryMediaTransmitter(),
        receiver: receiver
    )

    try report.validate()
    #expect(datagrams.contains { $0.rtp.header.payloadType == UltraGridCompatibility.encryptedAudioPayloadType })
    #expect(datagrams.contains { $0.rtp.header.payloadType == UltraGridCompatibility.encryptedVideoPayloadType })
    #expect(report.sink.audioPacketCount == 1)
    #expect(report.sink.videoFrameCount == 1)
    #expect(report.sink.rejectedMediaCount == 0)
    #expect(!report.unsupportedModes.contains("encryption"))
}
