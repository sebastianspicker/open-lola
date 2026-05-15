import Foundation
import Testing

@testable import OpenLolaCore

@Test
func lolaUdpMediaBidirectionalRunnerFailsWhenReceiveSideTimesOut() throws {
    let sink = LoLaMemoryUdpMediaTransmitter()
    let configuration = ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.20",
        localHost: "192.0.2.10",
        outputPath: "/tmp/lola-udp-media-tx-rx-timeout.json",
        dryRun: false,
        mediaMode: .audioVideo,
        durationSeconds: 3,
        videoWidth: 16,
        videoHeight: 16,
        videoBitsPerPixel: 8,
        mediaPacketCount: 1
    )

    let report = try LoLaUdpMediaBidirectionalRunner.run(
        configuration: configuration,
        transmitter: sink,
        receiver: LoLaTimeoutUdpMediaReceiver()
    )

    try report.validate()
    #expect(report.id == "lola-udp-media-tx-rx")
    #expect(report.verdict == .fail)
    #expect(report.runtimeError == "receiveTimedOut")
    #expect(report.realLinkTransmitted)
    #expect(report.audioFrameCount == 1)
    #expect(report.videoFrameCount == 2)
    #expect(sink.transmittedDatagrams.count == 3)
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

struct LoLaTimeoutRawLinkReceiver: LoLaRawLinkReceiver {
    func receive(maxFrames _: Int) throws -> [Data] {
        throw ExternalConnectorSessionError.receiveTimedOut
    }
}

func bpfTestRecord(capturedLength: Int, payload: Data) -> [UInt8] {
    let headerLength = 26
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

func readLoLaMediaSessionSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
