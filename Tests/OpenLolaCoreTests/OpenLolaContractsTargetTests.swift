import Foundation
import Testing

import OpenLolaContracts
@testable import OpenLolaCore

@Test
func openLolaContractsTargetExposesFrameworkFreeSharedContracts() throws {
    #expect(OpenLolaContracts.RxBufferProfile.allCases == [
        .direct,
        .small,
        .adaptive,
        .stableWan,
    ])
    #expect(OpenLolaContracts.MeasurementVerdict.pass.rawValue == "pass")
    #expect(OpenLolaContracts.MeasurementMethodology.measured.rawValue == "measured")

    let payload = try ContractProbe(id: "contracts").prettyJSONData()
    let decoded = try ContractProbe.decode(from: payload)
    #expect(decoded == ContractProbe(id: "contracts"))
}

@Test
func openLolaCoreReexportsExtractedContractsForExistingCallers() {
    let coreVerdict: OpenLolaCore.MeasurementVerdict = .partial
    let coreRxProfile: OpenLolaCore.RxBufferProfile = .stableWan
    let coreMethodology: OpenLolaCore.MeasurementMethodology = .synthetic

    #expect(coreVerdict == OpenLolaContracts.MeasurementVerdict.partial)
    #expect(coreRxProfile == OpenLolaContracts.RxBufferProfile.stableWan)
    #expect(coreMethodology == OpenLolaContracts.MeasurementMethodology.synthetic)
}

private struct ContractProbe: OpenLolaContracts.PrettyJSONCodable, Equatable {
    let id: String
}
