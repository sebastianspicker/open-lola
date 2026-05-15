import Foundation
import Testing

@testable import OpenLolaCore

@Test
func reportPrimitiveValidatorRoutesSharedProtocolErrors() throws {
    #expect(throws: RxBufferBenchmarkValidationError.emptyField("field")) {
        try RxBufferBenchmarkValidator.requireNonEmpty("", "field")
    }
    #expect(throws: RxBufferBenchmarkValidationError.nonPositiveField("field")) {
        try RxBufferBenchmarkValidator.requirePositive(0, "field")
    }
    #expect(throws: RxBufferBenchmarkValidationError.negativeField("field")) {
        try RxBufferBenchmarkValidator.requireNonNegative(-1, "field")
    }
    #expect(throws: RxBufferBenchmarkValidationError.nonFiniteField("field")) {
        try RxBufferBenchmarkValidator.requireNonNegative(Double.nan, "field")
    }
    #expect(throws: RecordingSessionArtifactValidationError.nonFiniteField("field")) {
        try RecordingSessionArtifactValidator.requirePositive(Double.nan, "field")
    }
    #expect(throws: PerformanceAuditValidationError.emptyList("field")) {
        try PerformanceAuditValidator.requireNonEmpty([Int](), "field")
    }
    #expect(throws: PerformanceAuditValidationError.passWithCounterWarning("field")) {
        try PerformanceAuditValidator.validateThreshold(
            value: 1,
            max: 0,
            error: PerformanceAuditValidationError.passWithCounterWarning("field")
        )
    }
    var passValidated = false
    PerformanceAuditValidator.validateVerdictPass(.pass) {
        passValidated = true
    }
    #expect(passValidated)
    var partialValidated = false
    PerformanceAuditValidator.validateVerdictPass(.partial) {
        partialValidated = true
    }
    #expect(!partialValidated)
}

@Test
func validationPrimitivesExposeSharedProtocolBasedValidators() throws {
    let primitiveSource = try readValidationSource("Sources/OpenLolaCore/Core/ValidationPrimitives.swift")
    let rxBenchmarkSource = try readValidationSource("Sources/OpenLolaCore/Timing/RxBufferBenchmarkReport.swift")
    let latencySource = try readValidationSource("Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift")
    let performanceSource = try readValidationSource(
        "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift"
    )
    let packagingSource = try readValidationSource("Sources/OpenLolaCore/Release/PackagingFieldTestHelpers.swift")
    let recordingSource = try readValidationSource("Sources/OpenLolaCore/Release/RecordingSessionHelpers.swift")
    let referenceSource = try readValidationSource("Sources/OpenLolaCore/Evidence/ReferenceRigHelpers.swift")
    let goalAuditSource = try readValidationSource("Sources/OpenLolaCore/Release/Goal/GoalCompletionAudit.swift")
    let goalRuntimeSource = try readValidationSource(
        "Sources/OpenLolaCore/Release/Goal/GoalRuntimeEvidenceTemplate.swift"
    )
    let hardwareValidationSource = try readValidationSource(
        "Sources/OpenLolaCore/Evidence/HardwareValidationReport.swift"
    )
    let fasterThanLoLaSource = try readValidationSource("Sources/OpenLolaCore/Release/FasterThanLoLaClosure.swift")
    let madiFullDuplexSource = try readValidationSource("Sources/OpenLolaCore/Audio/MADI/MadiFullDuplexValidation.swift")
    let madiReceiveSource = try readValidationSource("Sources/OpenLolaCore/Audio/MADI/MadiReceiveReport.swift")
    let madiTransmitSource = try readValidationSource("Sources/OpenLolaCore/Audio/MADI/MadiTransmit.swift")
    let rmeFastestSource = try readValidationSource("Sources/OpenLolaCore/Audio/MADI/RmeFastestAudioPath.swift")
    let driftSource = try readValidationSource("Sources/OpenLolaCore/Timing/DriftPlcHelpers.swift")
    let e2eSource = try readValidationSource("Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift")
    let latencyBenchmarkSource = try readValidationSource(
        "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift"
    )
    let sessionProfileSource = try readValidationSource("Sources/OpenLolaCore/Timing/SessionProfileBenchmark.swift")
    let driftCertificationSource = try readValidationSource(
        "Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift"
    )

    #expect(primitiveSource.contains("protocol ReportPrimitiveValidating"))
    #expect(primitiveSource.contains("protocol ReportValidationProtocol"))
    #expect(primitiveSource.contains("static func validateVerdictNotRun"))
    #expect(primitiveSource.contains("static func validateVerdictPass"))
    #expect(primitiveSource.contains("static func validateThreshold"))
    #expect(primitiveSource.contains("protocol ValidationEmptyFieldError"))
    #expect(primitiveSource.contains("protocol ValidationEmptyListError"))
    #expect(primitiveSource.contains("static func requireNonEmptyStrings"))
    #expect(primitiveSource.contains("where ValidationError: ValidationNonPositiveFieldError & ValidationNonFiniteFieldError"))
    #expect(primitiveSource.contains("where ValidationError: ValidationNegativeFieldError & ValidationNonFiniteFieldError"))
    #expect(rxBenchmarkSource.contains("enum RxBufferBenchmarkValidator: ReportPrimitiveValidating"))
    #expect(rxBenchmarkSource.contains("try RxBufferBenchmarkValidator.requireNonEmpty"))
    #expect(rxBenchmarkSource.contains("try RxBufferBenchmarkValidator.requirePositive"))
    #expect(rxBenchmarkSource.contains("try RxBufferBenchmarkValidator.requireNonNegative"))
    #expect(latencySource.contains("enum LatencyTuningValidator: ReportValidationProtocol"))
    #expect(latencySource.contains("try LatencyTuningValidator.requirePositive"))
    #expect(latencySource.contains("try LatencyTuningValidator.validateVerdictPass"))
    #expect(latencySource.contains("try LatencyTuningValidator.validateThreshold"))
    #expect(!latencySource.contains("private func requireBelow"))
    #expect(performanceSource.contains("enum PerformanceAuditValidator: ReportValidationProtocol"))
    #expect(performanceSource.contains("try PerformanceAuditValidator.requireNonEmpty(sourceReportIds"))
    #expect(performanceSource.contains("try PerformanceAuditValidator.validateVerdictPass"))
    #expect(performanceSource.contains("try PerformanceAuditValidator.validateThreshold"))
    #expect(packagingSource.contains("enum PackagingFieldValidator: ReportPrimitiveValidating"))
    #expect(recordingSource.contains("enum RecordingSessionArtifactValidator: ReportPrimitiveValidating"))
    #expect(referenceSource.contains("enum ReferenceRigValidator: ReportPrimitiveValidating"))
    #expect(goalAuditSource.contains("enum GoalCompletionAuditValidator: ReportPrimitiveValidating"))
    #expect(goalAuditSource.contains("try GoalCompletionAuditValidator.requireNonEmptyStrings"))
    #expect(goalRuntimeSource.contains("enum GoalRuntimeEvidenceTemplateValidator: ReportPrimitiveValidating"))
    #expect(hardwareValidationSource.contains("enum HardwareValidationValidator: ReportPrimitiveValidating"))
    #expect(fasterThanLoLaSource.contains("enum FasterThanLoLaClosureValidator: ReportPrimitiveValidating"))
    #expect(!goalAuditSource.contains("ValidationPrimitives.require"))
    #expect(!goalRuntimeSource.contains("ValidationPrimitives.require"))
    #expect(!hardwareValidationSource.contains("ValidationPrimitives.require"))
    #expect(!fasterThanLoLaSource.contains("ValidationPrimitives.require"))
    #expect(madiFullDuplexSource.contains("ValidationPrimitives.requireNonEmpty"))
    #expect(madiFullDuplexSource.contains("ValidationPrimitives.requirePositive"))
    #expect(madiFullDuplexSource.contains("ValidationPrimitives.requireNonNegative"))
    #expect(madiFullDuplexSource.contains("ValidationPrimitives.requireFinite"))
    #expect(madiReceiveSource.contains("ValidationPrimitives.requireNonEmpty"))
    #expect(madiReceiveSource.contains("ValidationPrimitives.requirePositive"))
    #expect(madiReceiveSource.contains("ValidationPrimitives.requireNonNegative"))
    #expect(madiTransmitSource.contains("ValidationPrimitives.requireNonEmpty"))
    #expect(madiTransmitSource.contains("ValidationPrimitives.requirePositive"))
    #expect(madiTransmitSource.contains("ValidationPrimitives.requireNonNegative"))
    #expect(rmeFastestSource.contains("ValidationPrimitives.requireNonEmpty"))
    #expect(rmeFastestSource.contains("ValidationPrimitives.requirePositive"))
    #expect(driftSource.contains("ValidationPrimitives.requireNonNegative"))
    #expect(e2eSource.contains("ValidationPrimitives.requireNonNegative"))
    #expect(latencyBenchmarkSource.contains("ValidationPrimitives.requireNonNegative"))
    #expect(sessionProfileSource.contains("ValidationPrimitives.requireNonNegative"))
    #expect(driftCertificationSource.contains("ValidationPrimitives.requireNonNegative"))
}

@Test
func timingValidationUsesSharedPercentileOrderingHelper() throws {
    let e2eSource = try readValidationSource("Sources/OpenLolaCore/Benchmarks/E2E/E2EBenchmarkReportValidation.swift")
    let performanceSource = try readValidationSource(
        "Sources/OpenLolaCore/Benchmarks/Performance/PerformanceAuditReportValidation.swift"
    )
    let latencyBenchmarkSource = try readValidationSource(
        "Sources/OpenLolaCore/Benchmarks/Latency/LatencyBenchmarkReport.swift"
    )
    let mediaClockSource = try readValidationSource("Sources/OpenLolaCore/Timing/MediaClock.swift")
    let latencyTuningSource = try readValidationSource("Sources/OpenLolaCore/Timing/LatencyTuningReportValidation.swift")
    let driftCertificationSource = try readValidationSource(
        "Sources/OpenLolaCore/Timing/DriftPlcFixedTargetCertification.swift"
    )

    #expect(e2eSource.contains("timingPercentilesAreOrdered"))
    #expect(performanceSource.contains("timingPercentilesAreOrdered"))
    #expect(latencyBenchmarkSource.contains("timingPercentilesAreOrdered"))
    #expect(mediaClockSource.contains("timingPercentilesAreOrdered"))
    #expect(latencyTuningSource.contains("timingPercentilesAreOrdered"))
    #expect(driftCertificationSource.contains("timingPercentilesAreOrdered"))
    #expect(!e2eSource.contains("p50Microseconds <= counter.p95Microseconds"))
    #expect(!performanceSource.contains("p50Microseconds <= counter.p95Microseconds"))
    #expect(!latencyBenchmarkSource.contains("p50Microseconds <= timing.jitter.p95Microseconds"))
    #expect(!mediaClockSource.contains("p50Microseconds <= metrics.p95Microseconds"))
    #expect(!latencyTuningSource.contains("cpuP50Percent <= resources.cpuP95Percent"))
    #expect(!driftCertificationSource.contains("p50Milliseconds <= latency.p95Milliseconds"))
}

private func readValidationSource(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
