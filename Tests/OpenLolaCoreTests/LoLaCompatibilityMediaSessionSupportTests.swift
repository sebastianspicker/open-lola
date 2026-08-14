// Verifies that LoLa UDP media bidirectional runner fails when receive side times out.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaUdpMediaBidirectionalRunnerFailsWhenReceiveSideTimesOut() throws {
    let sink = LoLaMemoryUdpMediaTransmitter()
    let configuration = ExternalConnectorSessionConfiguration(.init(
  connector: .lola,
  role: .txRx,
  peer: "192.0.2.20",
  outputPath: "/tmp/lola-udp-media-tx-rx-timeout.json"
) { input in
  input.localHost = "192.0.2.10"
  input.dryRun = false
  input.mediaMode = .audioVideo
  input.durationSeconds = 3
  input.videoWidth = 16
  input.videoHeight = 16
  input.videoBitsPerPixel = 8
  input.mediaPacketCount = 1
})

    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: configuration,
        transmitter: sink,
        receiver: LoLaTimeoutUdpMediaReceiver()
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "receiveTimedOut")
    #expect(!report.realLinkTransmitted)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(sink.transmittedDatagrams.count == 3)
}

@Test
func lolaUdpMediaBidirectionalRunnerCapturesInjectedReceiverFailure() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-udp-media-tx-rx-injected-failure.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.dryRun = false
        input.mediaMode = .audio
        input.durationSeconds = 3
        input.mediaPacketCount = 1
    })
    let sink = LoLaMemoryUdpMediaTransmitter()
    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: configuration,
        transmitter: sink,
        receiver: LoLaFailingUdpMediaReceiver()
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "socketFailed(\"injected receiver failure\")")
    #expect(!report.realLinkTransmitted)
    #expect(report.sentBytesTotal ?? 0 > 0)
    #expect(sink.transmittedDatagrams.count == 1)
}

@Test
func lolaUdpMediaBidirectionalRunnerPreservesTransmitFailureWhenReceiveSucceeds() throws {
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        outputPath: "/tmp/lola-udp-media-tx-rx-transmit-failure.json"
    ) { input in
        input.localHost = "192.0.2.10"
        input.dryRun = false
        input.mediaMode = .audio
        input.durationSeconds = 3
        input.mediaPacketCount = 1
    })
    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: configuration,
        transmitter: LoLaZeroByteUdpMediaTransmitter(),
        receiver: LoLaMemoryUdpMediaReceiver(datagrams: [
            .init(
                stream: .audio,
                port: configuration.audioPort,
                sourceHost: configuration.peer,
                sequenceNumber: 1,
                payload: try LoLaCompatibilityMediaCodec.audioFragments(
                    sequenceNumber: 1,
                    channels: configuration.channels,
                    payload: Data(repeating: 0, count: 256)
                )[0].payload
            )
        ])
    )

    try report.validate()
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "LoLa UDP media TX sent zero payload bytes")
    #expect(report.sentBytesTotal == 0)
    #expect(report.audioFrameCount == 2)
    #expect(report.notes.contains("TX evidence:"))
    #expect(report.notes.contains("RX evidence:"))
}

private struct LoLaZeroByteUdpMediaTransmitter: LoLaUdpMediaTransmitter {
    var usesRealLink: Bool { true }

    func transmit(
        _ datagrams: [LoLaUdpMediaDatagram],
        localHost _: String,
        peer _: String
    ) throws -> [Int] {
        datagrams.map { _ in 0 }
    }
}

struct LoLaTimeoutUdpMediaReceiver: LoLaUdpMediaReceiver {
    func receive(
        maxDatagrams _: Int,
        localHost _: String,
        peer _: String,
        audioPort _: UInt16,
        videoPort _: UInt16
    ) throws -> [LoLaUdpMediaDatagram] {
        throw ExternalConnectorSessionError.receiveTimedOut
    }
}

private struct LoLaFailingUdpMediaReceiver: LoLaUdpMediaReceiver {
    func receive(
        maxDatagrams _: Int,
        localHost _: String,
        peer _: String,
        audioPort _: UInt16,
        videoPort _: UInt16
    ) throws -> [LoLaUdpMediaDatagram] {
        throw ExternalConnectorSessionError.socketFailed("injected receiver failure")
    }
}

struct LoLaTimeoutRawLinkReceiver: LoLaRawLinkReceiver {
    func receive(maxFrames _: Int) throws -> [Data] {
        throw ExternalConnectorSessionError.receiveTimedOut
    }
}

func bpfTestRecord(headerLength: Int = 26, capturedLength: Int, payload: Data) -> [UInt8] {
    var record = [UInt8](repeating: 0, count: headerLength)
    writeBpfTestUInt32(UInt32(capturedLength), into: &record, offset: 16)
    writeBpfTestUInt16(UInt16(headerLength), into: &record, offset: 24)
    record.append(contentsOf: payload)
    let alignedLength = bpfTestWordAlign(headerLength + capturedLength)
    if record.count < alignedLength {
        record.append(contentsOf: repeatElement(UInt8(0), count: alignedLength - record.count))
    }
    return record
}

private func writeBpfTestUInt16(_ value: UInt16, into bytes: inout [UInt8], offset: Int) {
    withUnsafeBytes(of: value) { raw in
        bytes[offset] = raw[0]
        bytes[offset + 1] = raw[1]
    }
}

private func writeBpfTestUInt32(_ value: UInt32, into bytes: inout [UInt8], offset: Int) {
    withUnsafeBytes(of: value) { raw in
        bytes[offset] = raw[0]
        bytes[offset + 1] = raw[1]
        bytes[offset + 2] = raw[2]
        bytes[offset + 3] = raw[3]
    }
}

private func bpfTestWordAlign(_ value: Int) -> Int {
    let alignment = MemoryLayout<Int32>.size
    return (value + alignment - 1) & ~(alignment - 1)
}
