// Verifies that release and evidence run modes share measurement methodology.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func releaseAndEvidenceRunModesShareMeasurementMethodology() throws {
    #expect(HardwareValidationRunMode.measured == MeasurementMethodology.measured)
    #expect(ReleaseHardeningRunMode.synthetic == MeasurementMethodology.synthetic)
    #expect(FieldReadyRuntimeRunMode.measured == MeasurementMethodology.measured)
    #expect(PackagingFieldTestRunMode.synthetic == MeasurementMethodology.synthetic)
    #expect(RecordingSessionRunMode.measured == MeasurementMethodology.measured)
    #expect(FasterThanLoLaClosureRunMode.measured == MeasurementMethodology.measured)

    let encoded = try JSONEncoder().encode(MeasurementMethodology.measured)
        #expect(String(data: encoded, encoding: .utf8) == "\"measured\"")
    #expect(try JSONDecoder().decode(ReleaseHardeningRunMode.self, from: encoded) == .measured)
}
