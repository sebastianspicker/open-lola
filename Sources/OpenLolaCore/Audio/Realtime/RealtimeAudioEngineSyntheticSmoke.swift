import Foundation

public enum RealtimeAudioEngineSyntheticSmoke {
    public static func run() throws -> RealtimeAudioEngineReport {
        let rxBufferPolicy = try RxBufferPolicy.direct(
            framesPerPacket: 32,
            sampleRateHertz: 48_000,
            targetPackets: 1
        )
        let configuration = RealtimeAudioEngineConfiguration(
            inputDeviceUID: "synthetic-input",
            outputDeviceUID: "synthetic-output",
            sampleRateHertz: 48_000,
            framesPerBuffer: 32,
            channelCount: 2,
            packetFormat: .int16LittleEndian,
            inputChannelMap: [0, 1],
            outputChannelMap: [0, 1],
            playoutTargetFrames: 32,
            preallocatedBlockCount: 4,
            rxBufferPolicy: rxBufferPolicy
        )
        var handoff = try RealtimeAudioPacketHandoff(configuration: configuration)
        _ = handoff.captureCallback(startFrame: 0, hostTimeNanoseconds: 1)
        if let packet = try? handoff.sendNextPacket() {
            _ = try? handoff.receive(packet)
        }
        _ = handoff.renderCallback()
        _ = handoff.renderCallback()
        handoff.markShutdownCompleted()

        return RealtimeAudioEngineReport(
            id: "g03-realtime-audio-engine-synthetic-smoke",
            title: "Synthetic G03 realtime audio engine",
            capturedAt: "2026-05-02T00:00:00Z",
            runMode: .synthetic,
            hardwarePath: .synthetic,
            hardware: HardwareIdentity(
                referenceMac: "synthetic-host",
                audioInterface: "synthetic-device",
                osVersion: "synthetic-os",
                driverVersion: "synthetic-driver"
            ),
            configuration: configuration,
            safety: RealtimeAudioCallbackSafetyChecklist(
                noAllocationInCallback: true,
                noLoggingInCallback: true,
                noFileIOInCallback: true,
                noLocksOrUnboundedWaitsInCallback: true,
                noNetworkSetupInCallback: true,
                noReportWritingInCallback: true,
                countersOnlyInCallback: true
            ),
            runtime: RealtimeAudioRuntimeEvidence(
                callbackOwner: .synthetic,
                callback: SourceValidationMetrics.callback,
                handoff: handoff.metrics,
                udpSocketsPreparedBeforeStart: true,
                reportWrittenAfterStop: true,
                measuredDurationSeconds: 1
            ),
            verdict: .partial,
            notes: "Synthetic source validation only; RME hardware, Core Audio callback ownership, and two-Mac route measurement remain open."
        )
    }
}
