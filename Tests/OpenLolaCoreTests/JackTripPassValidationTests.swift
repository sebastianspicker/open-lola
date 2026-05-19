import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripMediaReportAllowsPassOnlyWithCompleteRuntimeEvidence() throws {
    let report = JackTripCompatibilityMediaReport(
        id: "jacktrip-runtime-pass",
        capturedAt: "2026-05-18T00:00:00Z",
        role: .txRx,
        datagrams: [
            JackTripCompatibilityDatagram(
                sourceHost: "198.51.100.20",
                sourcePort: 4464,
                destinationPort: 4464,
                packet: try jackTripPassValidationPacket(sequenceNumber: 1, payloadByte: 0x01)
            ),
        ],
        transmittedDatagramCount: 1,
        receivedDatagramCount: 1,
        learnedPeerHost: "198.51.100.20",
        learnedPeerPort: 4464,
        provider: ExternalConnectorMediaProviderReport(
            audioSource: "coreaudio-live",
            videoSource: "not-applicable",
            observedEvidenceClasses: [.liveDevice],
            notes: "Measured live-device provider evidence."
        ),
        sink: ExternalConnectorMediaSinkReport(
            audioPacketCount: 1,
            audioPayloadByteCount: 8,
            notes: "Measured JackTrip sink evidence."
        ),
        observedEvidenceClasses: ExternalConnectorEvidenceClass.runtimePassRequiredEvidence,
        missingEvidenceClassesForPass: [],
        realLinkTransmitted: true,
        verdict: .pass,
        notes: "Complete measured evidence test."
    )

    try report.validate()
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

private func jackTripPassValidationPacket(sequenceNumber: UInt16, payloadByte: UInt8) throws -> JackTripAudioPacket {
    try JackTripAudioPacket(
        header: JackTripDefaultHeader(
            timestampMicroseconds: UInt64(1_700_000_000_000_000 + Int(sequenceNumber)),
            sequenceNumber: sequenceNumber,
            bufferSizeSamples: 2,
            sampleRate: .hz48000,
            bitResolution: .bit16,
            incomingChannelsFromNetwork: 2,
            outgoingChannelsToNetwork: JackTripCompatibility.matchingOutgoingChannelSentinel
        ),
        planarAudioPayload: Data(repeating: payloadByte, count: 8)
    )
}
