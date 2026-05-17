import Foundation
import Testing

@testable import OpenLolaCore

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
