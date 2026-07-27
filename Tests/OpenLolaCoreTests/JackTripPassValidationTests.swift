// Verifies that JackTrip media report allows pass only with complete runtime evidence.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripMediaReportAllowsPassOnlyWithCompleteRuntimeEvidence() throws {
    var report = try jackTripCompatibilityMediaReport {
        $0.id = "jacktrip-runtime-pass"
        $0.capturedAt = "2026-05-18T00:00:00Z"
        $0.role = .txRx
        $0.datagrams = [
            JackTripCompatibilityDatagram(
                sourceHost: "198.51.100.20",
                sourcePort: 4464,
                destinationPort: 4464,
                packet: try jackTripTestPacket(sequenceNumber: 1, payloadByte: 0x01)
            )
        ]
        $0.transmittedDatagramCount = 1
        $0.receivedDatagramCount = 1
        $0.learnedPeerHost = "198.51.100.20"
        $0.learnedPeerPort = 4464
        $0.provider = ExternalConnectorMediaProviderReport(
            audioSource: "coreaudio-live",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.liveDevice],
            notes: "Measured live-device provider evidence."
        )
        $0.sink = ExternalConnectorMediaSinkReport(
            audioPacketCount: 1,
            audioPayloadByteCount: 8,
            notes: "Measured JackTrip sink evidence."
        )
        $0.observedEvidenceClasses = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
        $0.missingEvidenceClassesForPass = []
        $0.realLinkTransmitted = true
        $0.verdict = .pass
        $0.notes = "Complete measured evidence test."
    }

    try report.validate()

    report.sink.rejectedMediaCount = 1
    #expect(throws: ExternalConnectorSessionError.runtimePassMissingEvidence(
        "jackTripMedia.sink.rejectedMediaCount"
    )) {
        try report.validate()
    }
}

@Test
func jackTripInvalidSyntheticPassFixtureIsRejected() throws {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/JackTripCompatibilityMediaReports/invalid/jacktrip-synthetic-pass.json")
    let report = try JackTripCompatibilityMediaReport.decode(from: Data(contentsOf: url))

    #expect(throws: ExternalConnectorSessionError.dryRunCannotPass) {
        try report.validate()
    }
}
