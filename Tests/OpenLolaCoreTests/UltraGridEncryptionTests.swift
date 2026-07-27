// Verifies that UltraGrid AES-GCM encryption wraps audio and video packets.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func ultraGridAESGCMEncryptionWrapsAudioAndVideoPackets() throws {
    let configuration = try UltraGridEncryptionConfiguration(
        mode: .aes128GCM,
        passphrase: "shared test passphrase"
    )
    // swiftlint:disable:next identifier_name
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
    #expect(
        encryptedAudioPayload[UltraGridAudioPayloadHeader.byteCount] ==
            UltraGridOpenSSLCipherMode.aes128GCM.rawValue
    )
    #expect(decryptedAudio.header.payloadType == UltraGridCompatibility.audioPayloadType)
    #expect(decryptedAudio.payload == audio.payload)

    let video = try encryptedTestVideoPacket()
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

private func encryptedTestVideoPacket() throws -> RTPPacket {
    try #require(try UltraGridCompatibility.videoFragments(UltraGridVideoFragmentRequest(
        frame: UltraGridVideoFragmentFrame(
            payload: Data((0..<128).map(UInt8.init)),
            id: 2,
            width: 8,
            height: 8,
            frameRate: 30,
            bitsPerPixel: 8
        ),
        transport: UltraGridVideoFragmentTransport(
            sequenceStart: 10,
            timestamp: 9_000,
            ssrc: 0x8765_4321
        )
    )).first)
}

@Test
func ultraGridEncryptedRunnerProducesAndConsumesPT24PT25() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .mvtpUltraGrid,
  role: .txRx,
  peer: "127.0.0.1",
  outputPath: "/tmp/ug-encrypted-native.json"
) { input in
  input.localHost = "127.0.0.1"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.videoWidth = 8
  input.videoHeight = 8
  input.videoFrameRate = 30
  input.videoBitsPerPixel = 8
  input.mediaPacketCount = 1
  input.ultraGridEncryptionMode = .aes128GCM
  input.ultraGridEncryptionPassphrase = "shared test passphrase"
})
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
