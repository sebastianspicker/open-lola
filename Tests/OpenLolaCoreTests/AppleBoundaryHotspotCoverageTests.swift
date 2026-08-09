// Exercises Apple-framework boundary contracts exclusively through synthetic or injected state.
import CoreAudio
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func appleBoundaryVideoReportBuildsFromSyntheticSnapshot() throws {
    let source = AVFoundationCameraSourceDescription(
        source: VideoSourceDescription(
            kind: .avFoundation,
            label: "Synthetic AVFoundation boundary",
            deviceUniqueId: "synthetic-camera",
            permissionStatus: "not-requested"
        ),
        stream: VideoCaptureStreamMetadata(
            streamID: 404,
            sourceRole: .avFoundationDevice,
            timestampBasis: .hostUptimeNanoseconds
        ),
        format: VideoCaptureFormat(
            width: 4,
            height: 2,
            nominalFrameRate: 60,
            pixelFormat: "bgra8"
        ),
        queue: VideoQueueMetrics(
            policy: .latestFrame,
            maxDepth: 1,
            observedMaxDepth: 1,
            droppedFrames: 2
        )
    )
    let snapshot = AVFoundationCameraSourceSnapshot(
        sourceDescription: source,
        captureEvidence: AVFoundationCameraCaptureEvidence(
            framesCaptured: 3,
            framesRetained: 1,
            capturedFrameTimestampsNanoseconds: [1_000, 2_000, 3_000],
            callbackArrivalTimestampsNanoseconds: [1_010, 2_010, 3_010],
            retainedFrameTimestampsNanoseconds: [3_000],
            rawCapture: RawVideoCaptureMetrics(
                mode: .requested,
                extractionAttempts: 3,
                extractionFailures: 0,
                payloadsCaptured: 3,
                artifactFramesRetained: 0,
                lastExtractionError: nil
            )
        )
    )
    let configuration = VideoCaptureRunConfiguration(
        capture: .init(deviceUniqueId: "synthetic-camera", durationSeconds: 2, requestedFrameRate: 60),
        outputPath: "/tmp/synthetic-video-report.json"
    )

    let report = try AVFoundationVideoCaptureRunner.makeReport(
        snapshot: snapshot,
        configuration: configuration,
        capturedAt: "2026-08-05T00:00:00Z",
        nowNanoseconds: 5_000,
        processCpu: nil
    )

    #expect(report.id == "m08-avfoundation-capture-run")
    #expect(report.stream.streamID == 404)
    #expect(report.framesCaptured == 3)
    #expect(report.framesRetained == 1)
    #expect(report.frameInterval != nil)
    #expect(report.rawCapture?.payloadsCaptured == 3)
    #expect(report.audioImpact.synthetic == true)
}

@Test
func appleBoundaryDirectPeerSyntheticFramesAvoidAVFoundationCapture() throws {
    let configuration = directPeerAVSupportConfiguration(mediaSourceMode: .syntheticFixture)
    let source = DirectPeerAVFoundationRawFrameSource(configuration: configuration)

    let frame = try #require(try nextAVRawFrame(
        source: source,
        configuration: configuration,
        sequenceNumber: 12,
        timestampNanoseconds: 123_456
    ))

    #expect(frame.metadata.sequenceNumber == 12)
    #expect(frame.metadata.timestampNanoseconds == 123_456)
    #expect(frame.metadata.timestampBasis == .hostUptimeNanoseconds)
    #expect(frame.metadata.pixelFormat == "bgra8")
    #expect(frame.payload.count == configuration.videoWidth * configuration.videoHeight * 4)
    #expect(frame.payload.first == 12)
}

@Test
func appleBoundaryDirectPeerUnstartedProductionSourceHasNoDeviceState() {
    let source = DirectPeerAVFoundationRawFrameSource(
        configuration: directPeerAVSupportConfiguration(mediaSourceMode: .production)
    )

    #expect(source.videoFormat == nil)
    #expect(source.nextFrame() == nil)
    source.stop()
    #expect(source.videoFormat == nil)
}

@Test
func appleBoundaryLoLaBridgeDoesNotCreateDevicesWhenNotRequested() throws {
    let bridge = try LoLaCoreAudioLiveBridge.makeIfRequested(
        configuration: appleBoundaryLoLaConfiguration(capture: nil, playback: nil)
    )

    #expect(bridge == nil)
}

@Test
func appleBoundaryLoLaBridgeRejectsCaptureOnlyBeforeInventoryAccess() {
    #expect(throws: LoLaCoreAudioLiveBridgeError.missingPlaybackDevice) {
        _ = try LoLaCoreAudioLiveBridge.makeIfRequested(
            configuration: appleBoundaryLoLaConfiguration(capture: "coreaudio:input", playback: nil)
        )
    }
}

@Test
func appleBoundaryLoLaBridgeRejectsPlaybackOnlyBeforeInventoryAccess() {
    #expect(throws: LoLaCoreAudioLiveBridgeError.missingCaptureDevice) {
        _ = try LoLaCoreAudioLiveBridge.makeIfRequested(
            configuration: appleBoundaryLoLaConfiguration(capture: nil, playback: "coreaudio:output")
        )
    }
}

@Test
func appleBoundaryLoLaBridgeValidatesPayloadAndReportsInMemoryState() throws {
    let bridge = try LoLaCoreAudioLiveBridge(
        configuration: appleBoundaryLoLaConfiguration(capture: "coreaudio:input", playback: "coreaudio:output"),
        inputDeviceUID: "input",
        outputDeviceUID: "output",
        inventory: appleBoundaryAudioInventory()
    )
    let expectedPayloadBytes = try LoLaCompatibilityMediaModel.audioPayloadByteCount(channels: 2)

    #expect(bridge.snapshot.graphSampleRateHertz == 48_000)
    #expect(try bridge.nextLoLaAudioPayload() == nil)
    #expect(try bridge.nextLoLaAudioPayload(until: .now()) == nil)
    #expect(throws: LoLaCoreAudioLiveBridgeError.malformedAudioPayload(
        expected: expectedPayloadBytes,
        actual: 0
    )) {
        try bridge.enqueueLoLaPlaybackPayload(Data(), hostTimeNanoseconds: 1)
    }
    #expect(bridge.snapshot.receivedAudioPackets == 0)
    #expect(bridge.snapshot.queuedPlayoutBlocks == 0)
}

@Test
func appleBoundaryLoLaResamplerResetsBufferedUnequalRateInput() {
    let resampler = LoLaLinearPCMResampler(inputRate: 48_000, outputRate: 44_100, channels: 1)

    #expect(resampler.appendAndProduce([0.25]).isEmpty)
    resampler.reset()
    let output = resampler.appendAndProduce([0, 1, 0])

    #expect(!output.isEmpty)
    #expect(output.first == 0)
}

@Test
func appleBoundaryLoopbackHelpersHandleSyntheticCapabilitiesAndPercentiles() throws {
    let device = appleBoundaryAudioDevice(uid: "RME MADI synthetic", inputChannels: 2, outputChannels: 2)

    #expect(try parseAudioLoopbackChannelMap("1, 0", argument: "channels", expectedCount: 2) == [1, 0])
    #expect(throws: AudioLoopbackRunConfigurationError.channelMapCountMismatch(
        argument: "channels", expected: 2, actual: 1
    )) {
        _ = try parseAudioLoopbackChannelMap("0", argument: "channels", expectedCount: 2)
    }
    #expect(supportsSampleRate(device, 48_000))
    #expect(!supportsSampleRate(device, 96_000))
    #expect(supportsFrameSize(device, 64))
    #expect(!supportsFrameSize(device, 1_024))
    #expect(channelMapFits([0, 1], available: 2))
    #expect(!channelMapFits([2], available: 2))
    #expect(percentile([], 0.5) == 0)
    #expect(percentile([1, 3, 9], 2) == 9)
    #expect(percentile([1, 3, 9], -1) == 1)
}

@Test
func appleBoundaryLoopbackReportRetainsBlockedSyntheticPreflight() {
    let configuration = AudioLoopbackRunConfiguration(
        devices: .init(inputUID: "missing-input", outputUID: "missing-output"),
        audio: .init(sampleRateHertz: 48_000, framesPerBuffer: 32),
        run: .init(durationSeconds: 1, outputPath: "/tmp/loopback.json")
    )
    let preflight = AudioLoopbackPreflight(
        inputDevice: nil,
        outputDevice: nil,
        rmeMadiVisible: false,
        sampleRateSupported: false,
        frameSizeInReportedRange: false,
        canStartIOProc: false,
        blockers: ["input UID not found"]
    )
    let report = makeRunReport(
        configuration: configuration,
        inventory: CoreAudioInventoryReport(capturedAt: "test", hostName: "synthetic-host", devices: []),
        draft: AudioLoopbackRunReportDraft(
            preflight: preflight,
            state: .blockedPreflight,
            ioProcResult: nil,
            notes: "Synthetic preflight blocked before Core Audio IOProc creation."
        )
    )

    #expect(report.hostName == "synthetic-host")
    #expect(report.state == .blockedPreflight)
    #expect(report.callback == nil)
    #expect(report.cleanup == nil)
    #expect(report.verdict == .partial)
}

@Test
func appleBoundaryLoopbackCleanupUsesInjectedSuccessWithoutHALCalls() {
    let runner = CoreAudioLoopbackRunner(
        destroyIOProc: { _, _ in noErr },
        restoreDoubleProperty: { _, _, _, _ in },
        restoreUInt32Property: { _, _, _, _ in }
    )

    let cleanup = runner.cleanupIOProc(
        deviceID: 1,
        ioProcID: nil,
        savedSettings: AudioLoopbackSavedDeviceSettings(sampleRate: nil, frames: nil)
    )

    #expect(cleanup.failures == [
        .init(operation: "restore sample rate", status: nil),
        .init(operation: "restore buffer frame size", status: nil)
    ])
    #expect(!cleanup.succeeded)
}

private func appleBoundaryLoLaConfiguration(
    capture: String?,
    playback: String?
) -> ExternalConnectorSessionConfiguration {
    ExternalConnectorSessionConfiguration(.init(
        connector: .lola,
        role: .txRx,
        peer: "192.0.2.44",
        outputPath: "/tmp/lola-apple-boundary.json"
    ) { input in
        input.framesPerPacket = 64
        input.sampleRateHertz = 48_000
        input.channels = 2
        input.audioCapture = capture
        input.audioPlayback = playback
    })
}

private func appleBoundaryAudioInventory() -> CoreAudioInventoryReport {
    CoreAudioInventoryReport(
        capturedAt: "test",
        hostName: "synthetic-host",
        devices: [
            appleBoundaryAudioDevice(uid: "input", inputChannels: 2, outputChannels: 0),
            appleBoundaryAudioDevice(uid: "output", inputChannels: 0, outputChannels: 2)
        ]
    )
}

private func appleBoundaryAudioDevice(
    uid: String,
    inputChannels: Int,
    outputChannels: Int
) -> CoreAudioDeviceInventory {
    CoreAudioDeviceInventory(
        identity: .init(
            id: UInt32(abs(uid.hashValue % 10_000) + 1),
            name: uid,
            uid: uid,
            manufacturer: "RME",
            transportType: "synthetic",
            isAggregate: false
        ),
        streams: .init(
            inputChannelCount: inputChannels,
            outputChannelCount: outputChannels,
            inputStreamCount: inputChannels > 0 ? 1 : 0,
            outputStreamCount: outputChannels > 0 ? 1 : 0,
            inputChannelLayout: nil,
            outputChannelLayout: nil
        ),
        sampleRates: .init(
            nominalSampleRateHertz: 48_000,
            availableSampleRateRanges: [AudioValueRangeSnapshot(minimum: 44_100, maximum: 48_000)]
        ),
        buffering: .init(
            currentBufferFrameSize: 64,
            bufferFrameSizeRange: AudioValueRangeSnapshot(minimum: 32, maximum: 512),
            candidateBufferFrames: BufferFrameCandidates(
                inReportedRange: [32, 64, 128],
                outsideReportedRange: [],
                note: "synthetic"
            )
        ),
        timing: .init(
            inputLatencyFrames: nil,
            outputLatencyFrames: nil,
            inputSafetyOffsetFrames: nil,
            outputSafetyOffsetFrames: nil,
            clockDomain: nil
        ),
        diagnosticNotes: []
    )
}
