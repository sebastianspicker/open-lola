import Foundation
import Testing

@testable import OpenLolaCore

@Test
func madiReceiveSourceKeepsRealtimeReceiveStorageBounded() throws {
    let source = try readMadiReceiveSource("Sources/OpenLolaCore/Audio/MADI/MadiReceive.swift")
    let bufferSource = try readMadiReceiveSource("Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift")

    #expect(source.contains("MadiReceivePendingDeadlineSlots(capacity: Self.maxPendingDeadlines)"))
    #expect(source.contains("receiverMixScratch"))
    #expect(source.contains("missingFragmentScratch.reserveCapacity"))
    #expect(source.contains("pending.appendMissingFragmentIndices(to: &missingFragmentScratch)"))
    #expect(!source.contains("private var pendingDeadlines: ["))
    #expect(!source.contains("UdpPcmV2FragmentReassembler.reassemble(pending.packets)"))
    #expect(!source.contains("fragmentsByIndex.compactMap"))
    #expect(!bufferSource.contains(".filter"))
    #expect(!source.contains("storage.firstIndex(where:"))
    #expect(!source.contains("storage.contains {"))
    #expect(!source.contains("let input = [UInt8](inputPayload)"))
    #expect(!source.contains("var output = [UInt8]"))
    #expect(!source.contains("_ = receivedAtHostTimeNanoseconds"))
}

@Test
func madiReceiveReassemblyChecksByteCountArithmeticBeforeCopy() throws {
    let source = try readMadiReceiveSource("Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift")
    let packetSource = try readMadiReceiveSource("Sources/OpenLolaCore/Network/UDP/UdpPcmV2Packet.swift")

    #expect(source.contains("checkedMadiReceiveByteCount"))
    #expect(source.contains("destinationStart.addingReportingOverflow(fragmentFrameByteCount)"))
    #expect(source.contains("sourceStart.addingReportingOverflow(fragmentFrameByteCount)"))
    #expect(packetSource.contains("case destinationBufferUnavailable"))
    #expect(source.contains("throw UdpPcmV2FragmentReassemblyError.destinationBufferUnavailable"))
}

@Test
func madiReceiveReassemblyChecksMissingFragmentsBeforeCopy() throws {
    let source = try readMadiReceiveSource("Sources/OpenLolaCore/Audio/MADI/MadiReceiveBuffers.swift")
    let reassembleStart = try #require(source.range(of: "func reassemble() throws -> UdpPcmV2ReassemblyResult"))
    let reassembleSource = String(source[reassembleStart.lowerBound..<source.endIndex])

    let missingCheck = try #require(reassembleSource.range(of: "let missing = missingFragmentIndices"))
    let payloadAllocation = try #require(reassembleSource.range(of: "var payload = Data(count: payloadByteCount)"))
    let copyLoop = try #require(reassembleSource.range(of: "for index in 0..<reference.fragmentCount"))

    #expect(missingCheck.lowerBound < payloadAllocation.lowerBound)
    #expect(missingCheck.lowerBound < copyLoop.lowerBound)
    #expect(reassembleSource.contains("guard missing.isEmpty else"))
    #expect(reassembleSource.contains("missingFragmentIndices: missing"))
    #expect(reassembleSource.contains("payload: nil"))
}

@Test
func madiReceiveSyntheticSmokeCoversRequiredReceiveMatrix() throws {
    let report = try MadiReceiveSyntheticSmoke.run()

    try report.validate()

    #expect(report.verdict == .partial)
    #expect(report.measurements.map(\.channelCount) == madiSyntheticRequiredChannelCounts)
    #expect(report.measurements.allSatisfy { $0.allocationWarnings == 0 })
    #expect(report.measurements.allSatisfy { $0.outputPayloadByteCount > 0 })
}

@Test
func madiReceiveReportUsesSpecificEmptyFieldError() throws {
    var report = try MadiReceiveSyntheticSmoke.run()
    report.id = ""

    #expect(throws: MadiReceiveError.emptyField("id")) {
        try report.validate()
    }
}

@Test
func madiReceiveReportUsesSpecificNegativeFieldError() throws {
    var report = try MadiReceiveSyntheticSmoke.run()
    report.measurements[0].overruns = -1

    #expect(throws: MadiReceiveError.negativeField("measurement.overruns")) {
        try report.validate()
    }
}

private func readMadiReceiveSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
