import Testing

@testable import OpenLolaCore

@Test
func connectorRuntimeEvidenceStateDoesNotTreatPartialNoErrorAsValidated() throws {
    let lolaReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "",
        outputPath: "/tmp/lola-runtime-evidence-state.json",
        dryRun: true
    ))
    let ultraGridReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .mvtpUltraGrid,
        role: .tx,
        peer: "198.51.100.10",
        outputPath: "/tmp/ultragrid-runtime-evidence-state.json",
        dryRun: false
    ))
    let jackTripReport = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-runtime-evidence-state.json",
        dryRun: false,
        peerAudioPort: 4464
    ))

    #expect(lolaReport.runtimeEvidenceState == .noRuntimeErrorRecordedEvidenceIncomplete)
    #expect(lolaReport.runtimeEvidenceStatusMessage ==
        "no runtime error recorded; verdict partial still requires measured evidence")
    #expect(ultraGridReport.runtimeEvidenceState == .noRuntimeErrorRecordedEvidenceIncomplete)
    #expect(ultraGridReport.ultraGridMedia?.runtimeEvidenceState == .noRuntimeErrorRecordedEvidenceIncomplete)
    #expect(jackTripReport.runtimeEvidenceState == .noRuntimeErrorRecordedEvidenceIncomplete)
    #expect(jackTripReport.jackTripMedia?.runtimeEvidenceState == .noRuntimeErrorRecordedEvidenceIncomplete)
}

@Test
func connectorRuntimeEvidenceStateReportsRuntimeErrorsAndUnknownCompatibilityField() throws {
    var report = try ExternalConnectorSessionRunner.run(configuration: ExternalConnectorSessionConfiguration(
        connector: .lola,
        role: .rx,
        peer: "",
        outputPath: "/tmp/lola-runtime-error-state-unknown.json",
        dryRun: true
    ))
    report.runtimeErrorFree = nil
    #expect(report.runtimeEvidenceState == .runtimeErrorStateUnknownEvidenceIncomplete)

    report.verdict = .pass
    #expect(report.runtimeEvidenceState == .runtimeErrorStateUnknownEvidenceIncomplete)

    report.runtimeError = "runtime failed"
    report.runtimeErrorFree = false
    #expect(report.runtimeEvidenceState == .runtimeErrorRecorded)
}

@Test
func connectorMediaPassValidationRejectsFalseRuntimeErrorFreeFlag() throws {
    let ultraGrid = UltraGridCompatibilityMediaReport(UltraGridCompatibilityMediaReportInput(
        identity: UltraGridCompatibilityMediaIdentity(
            id: "ultragrid-runtime-error-free-false",
            capturedAt: "2026-05-20T00:00:00Z",
            role: .tx,
            mediaMode: .audio
        ),
        packets: UltraGridCompatibilityPacketSummary(
            datagrams: [],
            transmittedDatagramCount: 1,
            receivedDatagramCount: 0
        ),
        evidence: UltraGridCompatibilityEvidenceState(
            observedEvidenceClasses: ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
            missingEvidenceClassesForPass: [],
            realLinkTransmitted: true,
            verdict: .pass,
            runtimeErrorFree: false,
            notes: "False PASS media fixture with runtimeErrorFree set false."
        )
    ))
    #expect(throws: ExternalConnectorSessionError.runtimePassWithRuntimeError("ultraGridMedia.runtimeErrorFree")) {
        try ultraGrid.validate()
    }

    let jackTrip = jackTripCompatibilityMediaReport {
        $0.id = "jacktrip-runtime-error-free-false"
        $0.capturedAt = "2026-05-20T00:00:00Z"
        $0.role = .tx
        $0.transmittedDatagramCount = 1
        $0.observedEvidenceClasses = ExternalConnectorEvidenceClass.runtimePassRequiredEvidence
        $0.missingEvidenceClassesForPass = []
        $0.realLinkTransmitted = true
        $0.verdict = .pass
        $0.runtimeErrorFree = false
        $0.notes = "False PASS media fixture with runtimeErrorFree set false."
    }
    #expect(throws: ExternalConnectorSessionError.runtimePassWithRuntimeError("jackTripMedia.runtimeErrorFree")) {
        try jackTrip.validate()
    }
}
