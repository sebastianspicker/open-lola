// Shared measured RME report builders keep test evidence fixtures reusable without overloading the general fixture file.
@testable import OpenLolaCore

func measuredRmeFastestAudioReport(
    capturedAt: String,
    device: CoreAudioDeviceInventory,
    loopback: EndpointLoopbackReport,
    notes: String
) -> RmeFastestAudioPathReport {
    RmeFastestAudioPathReport(
        identity: .init(
            id: "g02-rme-fastest-pass-candidate",
            title: "Measured G02 RME fastest audio report",
            capturedAt: capturedAt
        ),
        inventory: .init(capturedAt: capturedAt, hostName: "reference-mac", device: device),
        evidence: .init(
            driver: .init(
                driver: .init(
                    package: "RME Thunderbolt Driver",
                    version: "4.08",
                    firmwareVersion: "230",
                    mode: .driverKit
                ),
                totalMix: .init(
                    version: "1.94",
                    snapshot: "private/reports/totalmix/g02-rme-totalmix.tmx",
                    routingNotes: "Thunderbolt RME MADI output 1/2 looped to input 1/2"
                ),
                clocking: .init(
                    clockSource: "internal clock with MADI loopback locked",
                    sampleRateSource: "Core Audio nominal sample rate",
                    sampleRateConversion: .absent
                )
            ),
            loopback: loopback
        ),
        verdict: .pass,
        notes: notes
    )
}
