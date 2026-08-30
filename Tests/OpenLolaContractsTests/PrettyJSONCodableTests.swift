// Protects the deterministic persisted-JSON contract independently of runtime frameworks.

import Foundation
import Testing
@testable import OpenLolaContracts

@Test func prettyJSONUsesStableSortedKeysAndRoundTrips() throws {
    let report = ContractReport(zeta: 7, alpha: "ready")

    let json = try report.prettyJSONString()

    #expect(
        json == """
        {
          \"alpha\" : \"ready\",
          \"zeta\" : 7
        }
        """
    )
    #expect(try ContractReport.decode(from: Data(json.utf8)) == report)
}

private struct ContractReport: PrettyJSONCodable, Equatable {
    let zeta: Int
    let alpha: String
}
