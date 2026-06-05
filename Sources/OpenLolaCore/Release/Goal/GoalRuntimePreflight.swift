import Foundation

// Current-host preflight probe. This file captures local blockers for the
// runtime evidence template; it does not execute the two-Mac runtime closure.
public enum GoalRuntimePreflightValidationError: Error, Equatable, Sendable,
    ValidationEmptyFieldError,
    ValidationEmptyListError {
    case emptyField(String)
    case emptyList(String)
    case duplicateDeliverable(String)
    case missingDeliverable(String)
    case deliverablePassWithoutPhysicalEvidence(String)
    case summaryMismatch
}

public struct GoalRuntimePreflightAudioProbe: Codable, Equatable, Sendable {
    public var captured: Bool
    public var deviceCount: Int
    public var rmeMadiCandidateCount: Int
    public var error: String?

    public init(captured: Bool, deviceCount: Int, rmeMadiCandidateCount: Int, error: String?) {
        self.captured = captured
        self.deviceCount = deviceCount
        self.rmeMadiCandidateCount = rmeMadiCandidateCount
        self.error = error
    }
}

public struct GoalRuntimePreflightVideoProbe: Codable, Equatable, Sendable {
    public var captured: Bool
    public var deviceCount: Int
    public var blackmagicAtemCandidateCount: Int
    public var permissionStatus: AVFoundationPermissionStatus
    public var blackmagicSdkStatus: BlackmagicDesktopVideoSdkStatus

    public init(
        captured: Bool,
        deviceCount: Int,
        blackmagicAtemCandidateCount: Int,
        permissionStatus: AVFoundationPermissionStatus,
        blackmagicSdkStatus: BlackmagicDesktopVideoSdkStatus
    ) {
        self.captured = captured
        self.deviceCount = deviceCount
        self.blackmagicAtemCandidateCount = blackmagicAtemCandidateCount
        self.permissionStatus = permissionStatus
        self.blackmagicSdkStatus = blackmagicSdkStatus
    }
}

public struct GoalRuntimePreflightSigningIdentity: Codable, Equatable, Sendable {
    public var label: String
    public var developerIDApplication: Bool

    public init(label: String, developerIDApplication: Bool) {
        self.label = label
        self.developerIDApplication = developerIDApplication
    }
}

public struct GoalRuntimePreflightSigningProbe: Codable, Equatable, Sendable {
    public var command: String
    public var exitCode: Int32
    public var identities: [GoalRuntimePreflightSigningIdentity]
    public var error: String?

    public init(
        command: String,
        exitCode: Int32,
        identities: [GoalRuntimePreflightSigningIdentity],
        error: String?
    ) {
        self.command = command
        self.exitCode = exitCode
        self.identities = identities
        self.error = error
    }

    public var developerIDApplicationIdentityCount: Int {
        identities.filter(\.developerIDApplication).count
    }

    public static func parse(command: String, exitCode: Int32, output: String, error: String?) -> Self {
        GoalRuntimePreflightSigningProbe(
            command: command,
            exitCode: exitCode,
            identities: parseIdentities(output),
            error: error
        )
    }

    public static func capture(
        executable: String = "/usr/bin/security",
        arguments: [String] = ["find-identity", "-v", "-p", "codesigning"]
    ) -> Self {
        let command = ([executable] + arguments).joined(separator: " ")
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            return GoalRuntimePreflightSigningProbe(
                command: command,
                exitCode: -1,
                identities: [],
                error: "\(executable) is not executable"
            )
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let stdout = Pipe()
        let stderr = Pipe()
        let stdoutCapture = BoundedPipeCapture(pipe: stdout)
        let stderrCapture = BoundedPipeCapture(pipe: stderr)
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            stdoutCapture.closeWriteHandle()
            stderrCapture.closeWriteHandle()
        } catch {
            stdoutCapture.closeWriteHandle()
            stderrCapture.closeWriteHandle()
            return GoalRuntimePreflightSigningProbe(
                command: command,
                exitCode: -1,
                identities: [],
                error: String(describing: error)
            )
        }
        process.waitUntilExit()

        let output = stdoutCapture.prefix()
        let errorOutput = stderrCapture.prefix()
        return GoalRuntimePreflightSigningProbe.parse(
            command: command,
            exitCode: process.terminationStatus,
            output: output,
            error: errorOutput.isEmpty ? nil : errorOutput
        )
    }

    private static func parseIdentities(_ output: String) -> [GoalRuntimePreflightSigningIdentity] {
        output.split(separator: "\n").compactMap { rawLine in
            let line = String(rawLine)
            guard let firstQuote = line.firstIndex(of: "\""),
                  let lastQuote = line.lastIndex(of: "\""),
                  firstQuote != lastQuote else {
                return nil
            }
            let label = String(line[line.index(after: firstQuote)..<lastQuote])
            return GoalRuntimePreflightSigningIdentity(
                label: label,
                developerIDApplication: label.hasPrefix("Developer ID Application:")
            )
        }
    }
}

public struct GoalRuntimePreflightDeliverable: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var verdict: MeasurementVerdict
    public var currentHostEvidence: [String]
    public var blockers: [String]
    public var nextCommands: [String]

    public init(
        id: GoalRuntimeEvidenceDeliverableID,
        title: String,
        verdict: MeasurementVerdict,
        currentHostEvidence: [String],
        blockers: [String],
        nextCommands: [String]
    ) {
        self.id = id.rawValue
        self.title = title
        self.verdict = verdict
        self.currentHostEvidence = currentHostEvidence
        self.blockers = blockers
        self.nextCommands = nextCommands
    }
}

public struct GoalRuntimePreflightSummary: Codable, Equatable, Sendable {
    public var deliverableCount: Int
    public var blockedDeliverableCount: Int
    public var partialDeliverableCount: Int
    public var audioDeviceCount: Int
    public var rmeMadiCandidateCount: Int
    public var videoDeviceCount: Int
    public var blackmagicAtemCandidateCount: Int
    public var codeSigningIdentityCount: Int
    public var developerIDApplicationIdentityCount: Int

    public init(
        deliverables: [GoalRuntimePreflightDeliverable],
        audio: GoalRuntimePreflightAudioProbe,
        video: GoalRuntimePreflightVideoProbe,
        signing: GoalRuntimePreflightSigningProbe
    ) {
        deliverableCount = deliverables.count
        blockedDeliverableCount = deliverables.filter { !$0.blockers.isEmpty }.count
        partialDeliverableCount = deliverables.filter { $0.verdict == .partial }.count
        audioDeviceCount = audio.deviceCount
        rmeMadiCandidateCount = audio.rmeMadiCandidateCount
        videoDeviceCount = video.deviceCount
        blackmagicAtemCandidateCount = video.blackmagicAtemCandidateCount
        codeSigningIdentityCount = signing.identities.count
        developerIDApplicationIdentityCount = signing.developerIDApplicationIdentityCount
    }
}

public struct GoalRuntimePreflightReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var capturedAt: String
    public var goalDocument: String
    public var sourceOfTruth: String
    public var verdict: MeasurementVerdict
    public var realWorldVerdict: MeasurementVerdict
    public var audio: GoalRuntimePreflightAudioProbe
    public var video: GoalRuntimePreflightVideoProbe
    public var signing: GoalRuntimePreflightSigningProbe
    public var summary: GoalRuntimePreflightSummary
    public var deliverables: [GoalRuntimePreflightDeliverable]
    public var notes: String

    public init(
        id: String,
        title: String,
        capturedAt: String,
        goalDocument: String,
        sourceOfTruth: String,
        verdict: MeasurementVerdict,
        realWorldVerdict: MeasurementVerdict,
        audio: GoalRuntimePreflightAudioProbe,
        video: GoalRuntimePreflightVideoProbe,
        signing: GoalRuntimePreflightSigningProbe,
        deliverables: [GoalRuntimePreflightDeliverable],
        notes: String
    ) {
        self.id = id
        self.title = title
        self.capturedAt = capturedAt
        self.goalDocument = goalDocument
        self.sourceOfTruth = sourceOfTruth
        self.verdict = verdict
        self.realWorldVerdict = realWorldVerdict
        self.audio = audio
        self.video = video
        self.signing = signing
        self.summary = GoalRuntimePreflightSummary(
            deliverables: deliverables,
            audio: audio,
            video: video,
            signing: signing
        )
        self.deliverables = deliverables
        self.notes = notes
    }

    public static func make(
        capturedAt: String,
        audio: GoalRuntimePreflightAudioProbe,
        video: GoalRuntimePreflightVideoProbe,
        signing: GoalRuntimePreflightSigningProbe
    ) -> GoalRuntimePreflightReport {
        let deliverables = preflightDeliverables(audio: audio, video: video, signing: signing)
        return GoalRuntimePreflightReport(
            id: "goal-runtime-preflight-2026-05-05",
            title: "GOAL.md runtime host preflight",
            capturedAt: capturedAt,
            goalDocument: "GOAL.md",
            sourceOfTruth: "docs/implementation-handoff.md",
            verdict: .partial,
            realWorldVerdict: .partial,
            audio: audio,
            video: video,
            signing: signing,
            deliverables: deliverables,
            notes: "Current-host preflight for physical GOAL.md runtime closure. This report can explain blockers; "
                + "it cannot replace two-Mac, hardware, signing, notarization, Gatekeeper, or clean-Mac evidence."
        )
    }

    public func validate() throws {
        try GoalRuntimePreflightValidator.requireNonEmpty(id, "id")
        try GoalRuntimePreflightValidator.requireNonEmpty(title, "title")
        try GoalRuntimePreflightValidator.requireNonEmpty(capturedAt, "capturedAt")
        try GoalRuntimePreflightValidator.requireNonEmpty(goalDocument, "goalDocument")
        try GoalRuntimePreflightValidator.requireNonEmpty(sourceOfTruth, "sourceOfTruth")
        try GoalRuntimePreflightValidator.requireNonEmpty(notes, "notes")
        try GoalRuntimePreflightValidator.requireNonEmpty(signing.command, "signing.command")
        guard summary == GoalRuntimePreflightSummary(
            deliverables: deliverables,
            audio: audio,
            video: video,
            signing: signing
        ) else {
            throw GoalRuntimePreflightValidationError.summaryMismatch
        }
        try validateDeliverables()
    }

    private func validateDeliverables() throws {
        guard !deliverables.isEmpty else {
            throw GoalRuntimePreflightValidationError.emptyList("deliverables")
        }

        var seen = Set<String>()
        for deliverable in deliverables {
            try GoalRuntimePreflightValidator.requireNonEmpty(deliverable.id, "deliverables.id")
            try GoalRuntimePreflightValidator.requireNonEmpty(deliverable.title, "deliverables.title")
            try GoalRuntimePreflightValidator.requireNonEmptyStrings(
                deliverable.currentHostEvidence,
                "deliverables.currentHostEvidence"
            )
            try GoalRuntimePreflightValidator.requireNonEmptyStrings(deliverable.blockers, "deliverables.blockers")
            try GoalRuntimePreflightValidator.requireNonEmptyStrings(
                deliverable.nextCommands,
                "deliverables.nextCommands"
            )
            guard seen.insert(deliverable.id).inserted else {
                throw GoalRuntimePreflightValidationError.duplicateDeliverable(deliverable.id)
            }
            if deliverable.verdict == .pass {
                throw GoalRuntimePreflightValidationError.deliverablePassWithoutPhysicalEvidence(deliverable.id)
            }
        }

        for id in GoalRuntimeEvidenceDeliverableID.allCases.map(\.rawValue) where !seen.contains(id) {
            throw GoalRuntimePreflightValidationError.missingDeliverable(id)
        }
    }
}

public enum GoalRuntimePreflightRunner {
    public static func run() -> GoalRuntimePreflightReport {
        GoalRuntimePreflightReport.make(
            capturedAt: ISO8601DateFormatter().string(from: Date()),
            audio: captureAudioProbe(),
            video: captureVideoProbe(),
            signing: GoalRuntimePreflightSigningProbe.capture()
        )
    }

    private static func captureAudioProbe() -> GoalRuntimePreflightAudioProbe {
        do {
            let report = try CoreAudioInventoryReader().capture()
            try report.validate()
            let rmeMadiCandidates = report.devices.filter(isRmeMadiDevice)
            return GoalRuntimePreflightAudioProbe(
                captured: true,
                deviceCount: report.devices.count,
                rmeMadiCandidateCount: rmeMadiCandidates.count,
                error: nil
            )
        } catch {
            return GoalRuntimePreflightAudioProbe(
                captured: false,
                deviceCount: 0,
                rmeMadiCandidateCount: 0,
                error: String(describing: error)
            )
        }
    }

    private static func captureVideoProbe() -> GoalRuntimePreflightVideoProbe {
        let report = AVFoundationVideoDeviceInventoryReader().capture()
        let blackmagicCandidates = report.devices.filter(\.isExternalCaptureCandidate)
        return GoalRuntimePreflightVideoProbe(
            captured: true,
            deviceCount: report.devices.count,
            blackmagicAtemCandidateCount: blackmagicCandidates.count,
            permissionStatus: report.permissionStatus,
            blackmagicSdkStatus: report.blackmagicSdkStatus
        )
    }
}

private func preflightDeliverables(
    audio: GoalRuntimePreflightAudioProbe,
    video: GoalRuntimePreflightVideoProbe,
    signing: GoalRuntimePreflightSigningProbe
) -> [GoalRuntimePreflightDeliverable] {
    let templateCommands = Dictionary(uniqueKeysWithValues: GoalRuntimeEvidenceTemplateReport
        .template()
        .deliverables
        .map { ($0.id, $0.commandTemplates) })
    let context = GoalRuntimePreflightDeliverableContext(
        audio: audio,
        video: video,
        signing: signing,
        templateCommands: templateCommands
    )
    return coreAudioPreflightDeliverables(context)
        + networkAudioPreflightDeliverables(context)
        + videoPreflightDeliverables(context)
        + integrationPreflightDeliverables(context)
}

private struct GoalRuntimePreflightDeliverableContext {
    let audio: GoalRuntimePreflightAudioProbe
    let video: GoalRuntimePreflightVideoProbe
    let signing: GoalRuntimePreflightSigningProbe
    let templateCommands: [String: [String]]

    var audioEvidence: [String] {
        [
            "core-audio-captured: \(audio.captured)",
            "core-audio-device-count: \(audio.deviceCount)",
            "rme-madi-candidate-count: \(audio.rmeMadiCandidateCount)",
            "core-audio-error: \(audio.error ?? "none")"
        ]
    }

    var videoEvidence: [String] {
        [
            "avfoundation-captured: \(video.captured)",
            "video-device-count: \(video.deviceCount)",
            "blackmagic-atem-candidate-count: \(video.blackmagicAtemCandidateCount)",
            "camera-permission: \(video.permissionStatus.rawValue)",
            "blackmagic-sdk-status: \(video.blackmagicSdkStatus.rawValue)"
        ]
    }

    var signingEvidence: [String] {
        [
            "codesigning-command: \(signing.command)",
            "codesigning-exit-code: \(signing.exitCode)",
            "codesigning-identity-count: \(signing.identities.count)",
            "developer-id-application-identity-count: \(signing.developerIDApplicationIdentityCount)",
            "codesigning-error: \(signing.error ?? "none")"
        ]
    }

    func deliverable(
        _ id: GoalRuntimeEvidenceDeliverableID,
        _ title: String,
        _ evidence: [String],
        _ blockers: [String]
    ) -> GoalRuntimePreflightDeliverable {
        GoalRuntimePreflightDeliverable(
            id: id,
            title: title,
            verdict: .partial,
            currentHostEvidence: evidence,
            blockers: blockers,
            nextCommands: templateCommands[id.rawValue] ?? ["goal-runtime-evidence-template"]
        )
    }
}

private func coreAudioPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .twoMacRmeMadiBidirectional,
            "Two-Mac multichannel RME MADI TX/RX both directions",
            context.audioEvidence,
            rmeBlockers(context.audio) + ["two-Mac bidirectional route evidence is not attached"]
        ),
        context.deliverable(
            .receiverSideRoutingMixing,
            "Receiver-side routing/mixing",
            context.audioEvidence,
            rmeBlockers(context.audio) + ["physical receiver-side RME receive/mix evidence is not attached"]
        )
    ]
}

private func networkAudioPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .directP2PSessionUdpMedia,
            "Direct P2P session setup and UDP media path",
            ["direct-peer-route-evidence: not-attached"],
            ["two-Mac direct or campus route transcript and packet capture are not attached"]
        ),
        context.deliverable(
            .audioLatencyJitterLossUnderrunsOverruns,
            "Measured audio latency, jitter, loss, underruns, and overruns",
            context.audioEvidence + [
                "physical-route-report: not-attached",
                "sixty-minute-drift-plc-report: not-attached"
            ],
            rmeBlockers(context.audio) + ["accepted physical route and long-run measurement reports are not attached"]
        ),
        context.deliverable(
            .rxBufferBenchmarks,
            "Configurable RX buffer modes with benchmarks",
            ["local-rx-buffer-runner: available", "same-route-physical-benchmark: not-attached"],
            ["same physical route RX buffer benchmark matrix is not attached"]
        )
    ]
}

private func videoPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .blackmagicAtemVideoTxRx,
            "Blackmagic/ATEM/DeckLink/UltraStudio video TX/RX",
            context.videoEvidence,
            videoBlockers(context.video)
        ),
        context.deliverable(
            .multiVideoRuntime,
            "Staged or working multi-video runtime",
            context.videoEvidence + ["staged-multi-video-runtime: available"],
            videoBlockers(context.video) + ["physical multi-source runtime evidence is not attached"]
        )
    ]
}

private func integrationPreflightDeliverables(
    _ context: GoalRuntimePreflightDeliverableContext
) -> [GoalRuntimePreflightDeliverable] {
    [
        context.deliverable(
            .avTimingRealRuns,
            "AV timing documentation from real runs",
            ["integrated-av-report: not-attached", "e2e-benchmark-report: not-attached"],
            ["physical audio, video, control, and E2E timing reports are not attached"]
        ),
        context.deliverable(
            .oscLightingNoAudioImpact,
            "OSC/lighting integration without audio-thread impact",
            ["external-osc-peer: not-attached", "lighting-target: not-attached"],
            ["external OSC peer and isolated lighting target evidence are not attached"]
        ),
        context.deliverable(
            .packagingSigningCleanMac,
            "Packaging, signing, notarization, Gatekeeper, and clean-Mac field test",
            context.signingEvidence + ["clean-mac-report: not-attached"],
            signingBlockers(context.signing) + [
                "notarization, Gatekeeper, and clean-Mac install evidence are not attached"
            ]
        )
    ]
}

private func rmeBlockers(_ audio: GoalRuntimePreflightAudioProbe) -> [String] {
    var blockers: [String] = []
    if !audio.captured {
        blockers.append("Core Audio inventory did not capture successfully")
    }
    if audio.rmeMadiCandidateCount == 0 {
        blockers.append("RME MADI device is not visible")
    }
    return blockers
}

private func videoBlockers(_ video: GoalRuntimePreflightVideoProbe) -> [String] {
    var blockers: [String] = []
    if video.permissionStatus != .authorized {
        blockers.append("camera/capture permission is \(video.permissionStatus.rawValue)")
    }
    if video.blackmagicAtemCandidateCount == 0 {
        blockers.append("Blackmagic/ATEM/DeckLink/UltraStudio device is not visible")
    }
    return blockers
}

private func signingBlockers(_ signing: GoalRuntimePreflightSigningProbe) -> [String] {
    var blockers: [String] = []
    if signing.exitCode != 0 {
        blockers.append("codesigning identity command exited \(signing.exitCode)")
    }
    if signing.developerIDApplicationIdentityCount == 0 {
        blockers.append("Developer ID Application identity is not visible")
    }
    return blockers
}

private func isRmeMadiDevice(_ device: CoreAudioDeviceInventory) -> Bool {
    let normalized = [
        device.name,
        device.uid,
        device.manufacturer ?? "",
        device.transportType ?? ""
    ]
    .joined(separator: " ")
    .lowercased()
    return normalized.contains("rme") && normalized.contains("madi")
}
