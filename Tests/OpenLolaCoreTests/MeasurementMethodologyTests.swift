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
    #expect(LoLaParityLedgerRunMode.synthetic == MeasurementMethodology.synthetic)
    #expect(FasterThanLoLaClosureRunMode.measured == MeasurementMethodology.measured)

    let encoded = try JSONEncoder().encode(MeasurementMethodology.measured)
    #expect(String(decoding: encoded, as: UTF8.self) == "\"measured\"")
    #expect(try JSONDecoder().decode(ReleaseHardeningRunMode.self, from: encoded) == .measured)
}
