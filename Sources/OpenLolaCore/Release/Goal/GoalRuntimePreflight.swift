// Coordinates release-goal execution and its result lifecycle, keeping runtime side effects separate from protocol values and validation policy.
import Foundation

/// Captures current-host runtime blockers without executing the two-Mac closure evaluation.
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

/// Captures structured result required to validate, interpret, and reproduce a goal-runtime closure result.
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

/// Captures structured result required to validate, interpret, and reproduce a goal-runtime closure result.
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

/// Captures hardware and endpoint identity required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimePreflightSigningIdentity: Codable, Equatable, Sendable {
    public var label: String
    public var developerIDApplication: Bool

    public init(label: String, developerIDApplication: Bool) {
        self.label = label
        self.developerIDApplication = developerIDApplication
    }
}

/// Captures structured result required to validate, interpret, and reproduce a goal-runtime closure result.
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

/// Captures structured result required to validate, interpret, and reproduce a goal-runtime closure result.
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

/// Captures summary statistics required to validate, interpret, and reproduce a goal-runtime closure result.
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

/// Captures report contents required to validate, interpret, and reproduce a goal-runtime closure result.
public struct GoalRuntimePreflightReport: ReportValidatingArtifact, PrettyJSONCodable, Equatable, Sendable {
    public struct Identity: Sendable {
        public let id: String
        public let title: String
        public let capturedAt: String
        public let goalDocument: String
        public let sourceOfTruth: String

        public init(
            id: String,
            title: String,
            capturedAt: String,
            goalDocument: String,
            sourceOfTruth: String
        ) {
            self.id = id
            self.title = title
            self.capturedAt = capturedAt
            self.goalDocument = goalDocument
            self.sourceOfTruth = sourceOfTruth
        }
    }

    public struct Verdicts: Sendable {
        public let aggregate: MeasurementVerdict
        public let realWorld: MeasurementVerdict

        public init(aggregate: MeasurementVerdict, realWorld: MeasurementVerdict) {
            self.aggregate = aggregate
            self.realWorld = realWorld
        }
    }

    public struct Probes: Sendable {
        public let audio: GoalRuntimePreflightAudioProbe
        public let video: GoalRuntimePreflightVideoProbe
        public let signing: GoalRuntimePreflightSigningProbe

        public init(
            audio: GoalRuntimePreflightAudioProbe,
            video: GoalRuntimePreflightVideoProbe,
            signing: GoalRuntimePreflightSigningProbe
        ) {
            self.audio = audio
            self.video = video
            self.signing = signing
        }
    }

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
        identity: Identity,
        verdicts: Verdicts,
        probes: Probes,
        deliverables: [GoalRuntimePreflightDeliverable],
        notes: String
    ) {
        self.id = identity.id
        self.title = identity.title
        self.capturedAt = identity.capturedAt
        self.goalDocument = identity.goalDocument
        self.sourceOfTruth = identity.sourceOfTruth
        self.verdict = verdicts.aggregate
        self.realWorldVerdict = verdicts.realWorld
        self.audio = probes.audio
        self.video = probes.video
        self.signing = probes.signing
        self.summary = GoalRuntimePreflightSummary(
            deliverables: deliverables,
            audio: probes.audio,
            video: probes.video,
            signing: probes.signing
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
            identity: GoalRuntimePreflightReport.Identity(
                id: "goal-runtime-preflight-2026-05-05",
                title: "GOAL.md runtime host preflight",
                capturedAt: capturedAt,
                goalDocument: "GOAL.md",
                sourceOfTruth: "docs/current-state.md"
            ),
            verdicts: GoalRuntimePreflightReport.Verdicts(
                aggregate: .partial,
                realWorld: .partial
            ),
            probes: GoalRuntimePreflightReport.Probes(
                audio: audio,
                video: video,
                signing: signing
            ),
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

/// Runs the goal-runtime closure evaluation from supplied artifacts while retaining their measurement provenance in the resulting report.
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
