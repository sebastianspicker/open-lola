@testable import OpenLolaCore

func measuredFixturePacketMode() -> UdpPcmPacketMode {
    UdpPcmPacketMode(
        sampleRateHertz: 48_000,
        framesPerPacket: 32,
        channelCount: 2,
        sampleFormat: .int16LittleEndian
    )
}

func measuredFixtureAcceptedMode(
    _ sampleRate: Int,
    _ frames: Int,
    stable: Bool,
    oneWayMilliseconds: Double,
    p99: Double,
    max: Double,
    missed: Int = 0,
    underruns: Int = 0,
    unstableNotes: String = "accepted but unstable measured row"
) -> EndpointModeResult {
    EndpointModeResult(
        mode: AudioMode(
            sampleRateHertz: sampleRate,
            framesPerBuffer: frames,
            channelCount: 2,
            sampleFormat: "int16"
        ),
        accepted: true,
        stable: stable,
        rejectionReason: nil,
        callback: EndpointCallbackMetrics(
            p50Microseconds: 100,
            p95Microseconds: 180,
            p99Microseconds: p99,
            maxMicroseconds: max,
            missedDeadlines: missed,
            underruns: underruns,
            overruns: 0
        ),
        loopback: EndpointLoopbackMetrics(
            reportedInputLatencyFrames: 12,
            reportedOutputLatencyFrames: 12,
            inputSafetyOffsetFrames: 0,
            outputSafetyOffsetFrames: 0,
            measuredAnalogRoundTripMilliseconds: oneWayMilliseconds * 2,
            correctedOneWayMilliseconds: oneWayMilliseconds,
            hiddenBufferGrowthDetected: false
        ),
        notes: stable ? "stable measured row" : unstableNotes
    )
}

func measuredFixtureRejectedMode(
    _ sampleRate: Int,
    _ frames: Int,
    reason: String
) -> EndpointModeResult {
    EndpointModeResult(
        mode: AudioMode(
            sampleRateHertz: sampleRate,
            framesPerBuffer: frames,
            channelCount: 2,
            sampleFormat: "int16"
        ),
        accepted: false,
        stable: false,
        rejectionReason: reason,
        callback: nil,
        loopback: nil,
        notes: "rejected measured row"
    )
}

func measuredFixtureRmeMadiDevice(
    uid: String,
    id: UInt32 = 100,
    transportType: String = "thun",
    outsideReportedRange: [Int] = [256],
    diagnosticNotes: [String] = ["test fixture"]
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        id: id,
        name: "RME Fireface UFX+ MADI Thunderbolt",
        uid: uid,
        manufacturer: "RME",
        transportType: transportType,
        isAggregate: false,
        inputChannelCount: 64,
        outputChannelCount: 64,
        inputStreamCount: 1,
        outputStreamCount: 1,
        nominalSampleRateHertz: 48_000,
        availableSampleRateRanges: [
            AudioValueRangeSnapshot(minimum: 48_000, maximum: 96_000),
        ],
        currentBufferFrameSize: 32,
        bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 8, maximum: 128),
        candidateBufferFrames: BufferFrameCandidates(
            inReportedRange: [8, 16, 32, 64, 128],
            outsideReportedRange: outsideReportedRange,
            note: outsideReportedRange.isEmpty ? "reported measured range" : "reported-range-only"
        ),
        inputLatencyFrames: 12,
        outputLatencyFrames: 12,
        inputSafetyOffsetFrames: 0,
        outputSafetyOffsetFrames: 0,
        clockDomain: 1,
        diagnosticNotes: diagnosticNotes
    )
}

func measuredFixtureLolaBaseline(
    route: RouteIdentity,
    packetMode: UdpPcmPacketMode
) -> LolaBaselineComparison {
    LolaBaselineComparison(
        availability: .measured,
        lolaVersion: "LoLa 2.0.0 Windows reference",
        lolaSettings: "48 kHz, 32-frame comparable low-latency audio path",
        audioInterface: "RME Fireface UFX+ MADI Thunderbolt",
        route: route,
        packetMode: packetMode,
        measurementMethod: .roundTripAnalogLoopback,
        latency: LolaBaselineLatencyMetrics(
            p50Milliseconds: 3.5,
            p95Milliseconds: 4.0,
            p99Milliseconds: 4.3,
            maxMilliseconds: 4.8
        ),
        lostPackets: 0,
        latePackets: 0,
        underruns: 0,
        artifactNotes: "No audible LoLa baseline artifacts during the measured comparison.",
        measuredOnSameHardwareAndRoute: true,
        result: .openLolaFaster,
        notTestedReason: nil
    )
}
