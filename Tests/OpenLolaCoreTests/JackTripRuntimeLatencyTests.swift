// Verifies that JackTrip generation stops before capture when the shared deadline has expired.
import Dispatch
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func jackTripGenerationStopsBeforeCaptureWhenTheSharedDeadlineHasExpired() throws {
    let provider = JackTripCallCountingAudioProvider()
    let configuration = ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .txRx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-expired-deadline.json"
    ) { input in
        input.mediaPacketCount = 1
    })

    #expect(throws: ExternalConnectorSessionError.socketFailed(
        "JackTrip exchange deadline expired before audio capture"
    )) {
        try JackTripCompatibilityRunner.forEachDatagram(
            configuration: configuration,
            audioProvider: provider,
            deadlineNanoseconds: DispatchTime.now().uptimeNanoseconds - 1
        ) { _ in }
    }
    #expect(provider.callCount == 0)
}

@Test
func jackTripFullDuplexDeadlineRejectsLegacyProviderWithoutCallingIt() throws {
    let provider = JackTripLegacyBlockingAudioProvider()
    let started = Date()

    #expect(throws: ExternalConnectorSessionError.unsupportedRuntimeMode(
        "jacktrip-full-duplex-provider-without-deadline"
    )) {
        _ = try JackTripCompatibilityRunner.run(
            configuration: ExternalConnectorSessionConfiguration(.init(
                connector: .jackTrip,
                role: .txRx,
                peer: "203.0.113.10",
                outputPath: "/tmp/jacktrip-legacy-provider-deadline.json"
            ) { input in
                input.dryRun = true
                input.mediaPacketCount = 1
            }),
            transmitter: JackTripMemoryMediaTransmitter(),
            receiver: JackTripMemoryMediaReceiver(datagrams: []),
            audioProvider: provider
        )
    }

    #expect(provider.legacyCallCount == 0)
    #expect(Date().timeIntervalSince(started) < 0.5)
}

@Test
func jackTripNeverReturningTransmitterDoesNotBlockDeadlineAndRetainsClosure() throws {
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    var retained: JackTripLateTransmitProbe? = JackTripLateTransmitProbe()
    weak let weakRetained = retained
    let task = JackTripConcurrentTransmitTask { [retained] in
        _ = retained
        started.signal()
        release.wait()
        return 0
    }
    retained = nil
    task.start()
    let startedBeforeDeadline = started.wait(timeout: .now() + .seconds(1))
    #expect(startedBeforeDeadline == .success)

    let pendingDeadline = DispatchTime.now().uptimeNanoseconds + 1_000_000
    #expect(task.wait(untilNanoseconds: pendingDeadline) == .timedOut)
    #expect(weakRetained != nil)

    // Cleanup only: the simulated transmitter has no production completion path.
    release.signal()
    let completedBeforeDeadline = task.wait(
        untilNanoseconds: DispatchTime.now().uptimeNanoseconds + 1_000_000_000
    )
    #expect(completedBeforeDeadline == .success)
}

@Test
func jackTripPacingUsesAbsolutePacketSlotsAndDropsOverrunCatchUp() throws {
    let period: UInt64 = 10_000_000
    let regularClock = JackTripTestMonotonicClock()
    var regularSendTimes: [UInt64] = []
    try JackTripCompatibilityRunner.forEachDatagram(
        configuration: jackTripPacingConfiguration(packetCount: 4),
        audioProvider: JackTripSyntheticAudioFrameProvider(),
        clock: regularClock
    ) { _ in regularSendTimes.append(regularClock.nowNanoseconds()) }

    #expect(regularSendTimes == [0, period, 2 * period, 3 * period])

    let overrunClock = JackTripTestMonotonicClock()
    var overrunSendTimes: [UInt64] = []
    var sequences: [UInt16] = []
    try JackTripCompatibilityRunner.forEachDatagram(
        configuration: jackTripPacingConfiguration(packetCount: 7),
        audioProvider: JackTripFirstCaptureOverrunProvider(
            clock: overrunClock,
            overrunNanoseconds: 35_000_000
        ),
        clock: overrunClock
    ) { datagram in
        overrunSendTimes.append(overrunClock.nowNanoseconds())
        sequences.append(datagram.packet.header.sequenceNumber)
    }

    #expect(sequences == [3, 5, 6])
    #expect(zip(overrunSendTimes, overrunSendTimes.dropFirst()).allSatisfy { later, earlier in
        earlier - later >= period
    })
}

private func jackTripPacingConfiguration(packetCount: Int) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .jackTrip,
        role: .tx,
        peer: "203.0.113.10",
        outputPath: "/tmp/jacktrip-pacing.json"
    ) { input in
        input.dryRun = false
        input.sampleRateHertz = 48_000
        input.framesPerPacket = 480
        input.mediaPacketCount = packetCount
    })
}
