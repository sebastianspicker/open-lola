// Shared native app shell tests helpers keep related tests deterministic and focused on their contract.
import Foundation
import Testing

@testable import OpenLolaCore

func operatorPrototypeState() -> NativeAppShellOperatorPrototypeState {
    NativeAppShellOperatorPrototypeState(
        workflow: NativeAppShellOperatorWorkflow(commandIntent: .runRequested, remoteOrchestrationEnabled: false, startsLongRunningProcess: false),
        inventories: NativeAppShellOperatorInventories(local: operatorPrototypeLocalInventory(), remote: operatorPrototypeRemoteInventory()),
        peerFields: NativeAppShellOperatorPeerFields(
            directPeer: .appDefault
        )
    )
}

func operatorPrototypeLocalInventory() -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
        capturedAt: "2026-05-09T00:00:00Z",
        hostName: "test-host",
        audioDevices: [
            NativeAppShellAudioDeviceOption(
                name: "RME MADI",
                uid: "rme-madi-uid",
                inputChannelCount: 64,
                outputChannelCount: 64,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 32
            ),
            NativeAppShellAudioDeviceOption(
                name: "Output Only",
                uid: "output-only-uid",
                inputChannelCount: 0,
                outputChannelCount: 2,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 64
            )
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "ATEM Mini Pro ISO",
                uniqueId: "atem-uid",
                manufacturer: "Blackmagic Design",
                transport: "USB",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 2
            )
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: "rme-madi-uid",
            audioOutputUID: "rme-madi-uid",
            videoDeviceID: "atem-uid"
        ),
        inventoryErrors: []
    )
}

func operatorPrototypeRemoteInventory() -> NativeAppShellLocalMediaInventory {
    NativeAppShellLocalMediaInventory(
        capturedAt: "2026-05-09T00:00:00Z",
        hostName: "remote-test-host",
        audioDevices: [
            NativeAppShellAudioDeviceOption(
                name: "Remote RME Input",
                uid: "remote-rme-input-uid",
                inputChannelCount: 64,
                outputChannelCount: 0,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 32
            ),
            NativeAppShellAudioDeviceOption(
                name: "Remote RME Output",
                uid: "remote-rme-output-uid",
                inputChannelCount: 0,
                outputChannelCount: 64,
                nominalSampleRateHertz: 48_000,
                currentBufferFrameSize: 32
            )
        ],
        videoDevices: [
            NativeAppShellVideoDeviceOption(
                label: "Remote ATEM",
                uniqueId: "remote-atem-uid",
                manufacturer: "Blackmagic Design",
                transport: "USB",
                sourcePolicy: .blackmagicFirstAvFoundationFallback,
                formatCount: 2
            )
        ],
        selection: NativeAppShellLocalMediaSelection(
            audioInputUID: "remote-rme-input-uid",
            audioOutputUID: "remote-rme-output-uid",
            videoDeviceID: "remote-atem-uid"
        ),
        inventoryErrors: []
    )
}
func lolaCompatibilityCaptureReportForAppShell() -> LoLaCompatibilityCaptureReport {
    let packets = lolaCompatibilityCapturePacketsForAppShell()
    return LoLaCompatibilityCaptureReport(
        identity: .init(
            id: "app-shell-capture",
            title: "App shell packet monitor capture",
            capturedAt: "2026-05-10T00:00:00Z",
            inputPath: "fixtures/app-shell.pcapng",
            inputFormat: .pcapng
        ),
        content: .init(summary: LoLaCompatibilityCaptureSummary(packets: packets), packets: packets),
        outcome: .init(
            verdict: .partial,
            evidenceBoundary: "synthetic app packet monitor behavior",
            notes: "Synthetic app shell packet monitor fixture."
        )
    )
}

func lolaCompatibilityCapturePacketsForAppShell() -> [LoLaCompatibilityCapturePacketReport] {
    [
        LoLaCompatibilityCapturePacketReport(
            index: 1,
            capturedLength: 80,
            originalLength: 80,
            stream: .audio,
            network: .init(
                sourceIP: "192.0.2.10",
                destinationIP: "198.51.100.10",
                sourcePort: 7000,
                destinationPort: 7000,
                payloadLength: 48
            ),
            media: .init(envelopeValid: true, payloadCandidate: .rawAudio)
        ),
        LoLaCompatibilityCapturePacketReport(
            index: 2,
            capturedLength: 544,
            originalLength: 544,
            stream: .video,
            network: .init(
                sourceIP: "192.0.2.11",
                destinationIP: "198.51.100.10",
                sourcePort: 7000,
                destinationPort: 7000,
                payloadLength: 512
            ),
            media: .init(envelopeValid: true, payloadCandidate: .mjpeg)
        ),
        LoLaCompatibilityCapturePacketReport(
            index: 3,
            capturedLength: 64,
            originalLength: 64,
            stream: .control,
            network: .init(
                sourceIP: "192.0.2.12",
                destinationIP: "198.51.100.20",
                sourcePort: 7000,
                destinationPort: 7000,
                payloadLength: 32
            ),
            metadata: .init(controlMessageName: "MESG_QUICKCONN")
        )
    ]
}
func nativeAppShellPassCandidateReport() throws -> NativeAppShellReport {
    var report = try loadNativeAppShellTestFixture(named: "native-app-shell-partial")
    report.verdict = .pass
    report.smokeProbe.appTargetBuilds = true
    report.smokeProbe.runtimeSmokeProbed = true
    report.smokeProbe.comparedWithCLIMetrics = true
    return report
}

func loadNativeAppShellTestFixture(named name: String) throws -> NativeAppShellReport {
    let url = try nativeAppShellTestFixtureURL(named: name)
    return try NativeAppShellReport.decode(from: Data(contentsOf: url))
}

func nativeAppShellTestFixtureURL(named name: String) throws -> URL {
    let validURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NativeAppShellReports/valid"
    )
    let invalidURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "NativeAppShellReports/invalid"
    )
    let rootURL = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: nil
    )

    return try #require(validURL ?? invalidURL ?? rootURL)
}

func argumentValue(_ arguments: [String], _ flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}
