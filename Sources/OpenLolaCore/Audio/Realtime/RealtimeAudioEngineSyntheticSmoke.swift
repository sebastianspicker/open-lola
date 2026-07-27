// Exercises realtime-engine validation with fixed callback and handoff metrics while explicitly withholding physical-device provenance.
import Foundation

/// Exercises a deterministic callback-driven audio path without requiring physical hardware.
public enum RealtimeAudioEngineSyntheticSmoke {
    public static func run() throws -> RealtimeAudioEngineReport {
        let configuration = try syntheticRealtimeAudioConfiguration()
        let handoff = try exercisedSyntheticHandoff(configuration: configuration)
        return syntheticRealtimeAudioReport(configuration: configuration, handoff: handoff)
    }

    private static func syntheticRealtimeAudioConfiguration() throws -> RealtimeAudioEngineConfiguration {
    RealtimeAudioEngineConfiguration(
            devices: .init(inputDeviceUID: "synthetic-input", outputDeviceUID: "synthetic-output"),
            format: .init(sampleRateHertz: 48_000, framesPerBuffer: 32, channelCount: 2, packetFormat: .int16LittleEndian),
            channelMaps: .init(input: [0, 1], output: [0, 1]),
            buffering: .init(playoutTargetFrames: 32, preallocatedBlockCount: 4, rxBufferPolicy: try RxBufferPolicy.direct(
                framesPerPacket: 32,
    sampleRateHertz: 48_000,
    targetPackets: 1
    ))
        )
    }

    private static func exercisedSyntheticHandoff(
        configuration: RealtimeAudioEngineConfiguration
    ) throws -> RealtimeAudioPacketHandoff {
        var handoff = try RealtimeAudioPacketHandoff(configuration: configuration)
        _ = handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1)
        if let packet = try? handoff.sendNextPacket() {
            _ = try? handoff.receive(packet)
        }
        _ = handoff.renderCallback()
        _ = handoff.renderCallback()
        handoff.markShutdownCompleted()
        return handoff
    }

    private static func syntheticRealtimeAudioReport(
        configuration: RealtimeAudioEngineConfiguration,
        handoff: RealtimeAudioPacketHandoff
    ) -> RealtimeAudioEngineReport {
    RealtimeAudioEngineReport(RealtimeAudioEngineReport.Init(
        metadata: .init(
            id: "g03-realtime-audio-engine-synthetic-smoke",
            title: "Synthetic G03 realtime audio engine",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            hardwarePath: .synthetic
        ),
        runtime: .init(
            hardware: HardwareIdentity(
                referenceMac: "synthetic-host",
                audioInterface: "synthetic-device",
                osVersion: "synthetic-os",
                driverVersion: "synthetic-driver"
            ),
            configuration: configuration,
            safety: syntheticRealtimeCallbackSafety(),
            runtime: syntheticRealtimeRuntimeEvidence(handoff: handoff)
        ),
        outcome: .init(verdict: .partial, notes: syntheticRealtimeAudioNotes)
    ))
    }

    private static func syntheticRealtimeCallbackSafety() -> RealtimeAudioCallbackSafetyChecklist {
        RealtimeAudioCallbackSafetyChecklist(
            noAllocationInCallback: true,
            noLoggingInCallback: true,
            noFileIOInCallback: true,
            noLocksOrUnboundedWaitsInCallback: true,
            noNetworkSetupInCallback: true,
            noReportWritingInCallback: true,
            countersOnlyInCallback: true
        )
    }

    private static func syntheticRealtimeRuntimeEvidence(
        handoff: RealtimeAudioPacketHandoff
    ) -> RealtimeAudioRuntimeEvidence {
        RealtimeAudioRuntimeEvidence(
            callbackOwner: .synthetic,
            callback: SourceValidationMetrics.callback,
            handoff: handoff.metrics,
            udpSocketsPreparedBeforeStart: true,
            reportWrittenAfterStop: true,
            measuredDurationSeconds: 1
        )
    }

    private static let syntheticRealtimeAudioNotes =
        "Synthetic source validation only; RME hardware, Core Audio callback " +
        "ownership, and two-Mac route measurement remain open."
}
