import Foundation
import Testing

@testable import OpenLolaCore

@Test
func validMeasurementReportFixturesDecodeAndValidate() throws {
    let fixtureNames = [
        "endpoint-valid",
        "network-valid",
        "video-valid",
        "lighting-valid",
        "field-test-valid",
    ]

    let reports = try fixtureNames.map(loadReportFixture(named:))

    #expect(Set(reports.map(\.kind)) == Set(MeasurementReportKind.allCases))

    for report in reports {
        try report.validate()
        #expect(!report.hardware.referenceMac.isEmpty)
        #expect(!report.route.label.isEmpty)
        #expect(report.timing.p50Milliseconds <= report.timing.p95Milliseconds)
        #expect(report.timing.p95Milliseconds <= report.timing.p99Milliseconds)
        #expect(report.timing.p99Milliseconds <= report.timing.maxMilliseconds)
    }
}

@Test
func invalidMeasurementReportFixturesAreRejected() {
    for fixture in [
        "missing-hardware",
        "missing-route",
        "missing-timing",
        "missing-verdict",
        "invalid-verdict",
    ] {
        #expect(throws: Error.self) {
            _ = try loadInvalidFixture(named: fixture)
        }
    }
}

private func loadReportFixture(named name: String) throws -> MeasurementReport {
    let url = try fixtureURL(named: name, directory: "valid")
    let report = try MeasurementReport.decode(from: Data(contentsOf: url))
    try report.validate()
    return report
}

private func loadInvalidFixture(named name: String) throws -> MeasurementReport {
    let url = try fixtureURL(named: name, directory: "invalid")
    let report = try MeasurementReport.decode(from: Data(contentsOf: url))
    try report.validate()
    return report
}

private func fixtureURL(named name: String, directory: String) throws -> URL {
    let nestedURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "MeasurementReports/\(directory)"
    )
    return try #require(
        nestedURL ?? Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: nil
        )
    )
}
