// Shared External connector NMP plan helpers keep multi-file test scenarios deterministic.
@testable import OpenLolaCore

func makeExternalConnectorNmpPlanConfiguration(
    localHost: String = "198.51.100.20",
    remoteHost: String = "198.51.100.10",
    outputPath: String = "/tmp/nmp-plan.json",
    configure: (inout NmpPlanConfigurationFields) -> Void = { _ in }
) -> ExternalConnectorNmpPlanConfiguration {
    var fields = NmpPlanConfigurationFields(
        localHost: localHost,
        remoteHost: remoteHost,
        outputPath: outputPath
    )
    configure(&fields)
    return fields
}
