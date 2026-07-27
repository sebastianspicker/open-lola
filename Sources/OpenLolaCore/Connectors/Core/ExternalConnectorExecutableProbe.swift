// Probes ExternalConnectorExecutableProbe capability or availability, isolating environment inspection from policy decisions.
import Foundation

struct ExternalConnectorExecutableProbeRequest {
    let id: String
    let connector: ExternalConnectorKind
    let label: String
    let executable: String
    let arguments: [String]
    let expected: ExternalConnectorExecutableIdentity
}

func externalExecutableProbe(_ request: ExternalConnectorExecutableProbeRequest) -> ExternalConnectorExecutableProbe {
    let attempts = externalConnectorExecutableAttempts(request)
    guard let selected = attempts.first(where: { $0.verdict == .pass }) ?? attempts.first else {
        return missingExternalConnectorExecutableProbe(request)
    }
    return selectedExternalConnectorExecutableProbe(request, selected, attempts)
}

private func externalConnectorExecutableAttempts(
    _ request: ExternalConnectorExecutableProbeRequest
) -> [ExternalConnectorExecutableProbeAttempt] {
    externalConnectorExecutableCandidates(primary: request.executable, expected: request.expected).map { candidate in
        externalConnectorExecutableAttempt(candidate, request)
    }
}

private func externalConnectorExecutableAttempt(
    _ candidate: String,
    _ request: ExternalConnectorExecutableProbeRequest
) -> ExternalConnectorExecutableProbeAttempt {
    let result = runExternalConnectorExecutableProbe(executable: candidate, arguments: request.arguments)
    let identity = detectedExternalConnectorExecutableIdentity(result)
    return ExternalConnectorExecutableProbeAttempt(
        executable: candidate,
        result: result,
        detectedIdentity: identity,
        verdict: externalConnectorExecutableProbeVerdict(result, identity, request.expected)
    )
}

private func detectedExternalConnectorExecutableIdentity(
    _ result: ExternalConnectorProcessResult
) -> ExternalConnectorExecutableIdentity {
    guard result.launched, result.exitStatus != 127 else {
        return .missing
    }
    return detectExternalConnectorExecutableIdentity(
        "\(result.standardOutputPrefix)\n\(result.standardErrorPrefix)"
    )
}

private func externalConnectorExecutableProbeVerdict(
    _ result: ExternalConnectorProcessResult,
    _ identity: ExternalConnectorExecutableIdentity,
    _ expected: ExternalConnectorExecutableIdentity
) -> MeasurementVerdict {
    result.launched && result.exitStatus == 0 && identity == expected ? .pass : .fail
}

private func missingExternalConnectorExecutableProbe(
    _ request: ExternalConnectorExecutableProbeRequest
) -> ExternalConnectorExecutableProbe {
    var fields = ExternalConnectorExecutableProbeFields()
    fields.id = request.id
    fields.connector = request.connector
    fields.label = request.label
    fields.executable = request.executable
    fields.arguments = request.arguments
    fields.detectedIdentity = .missing
    fields.verdict = .fail
    fields.notes = "No executable candidates were available for probing."
    return ExternalConnectorExecutableProbe(fields)
}

private func selectedExternalConnectorExecutableProbe(
    _ request: ExternalConnectorExecutableProbeRequest,
    _ selected: ExternalConnectorExecutableProbeAttempt,
    _ attempts: [ExternalConnectorExecutableProbeAttempt]
) -> ExternalConnectorExecutableProbe {
    var fields = ExternalConnectorExecutableProbeFields()
    fields.id = request.id
    fields.connector = request.connector
    fields.label = request.label
    fields.executable = selected.executable
    fields.arguments = request.arguments
    fields.launched = selected.result.launched
    fields.exitStatus = selected.result.exitStatus
    fields.standardOutputPrefix = selected.result.standardOutputPrefix
    fields.standardErrorPrefix = selected.result.standardErrorPrefix
    fields.detectedIdentity = selected.detectedIdentity
    fields.evidenceStatus = selected.verdict == .pass ? "launched-and-matched" : "launch-failed-or-mismatched"
    fields.verdict = selected.verdict
    fields.notes = externalConnectorExecutableProbeNotes(noteContext(request, selected, attempts))
    return ExternalConnectorExecutableProbe(fields)
}

private func noteContext(
    _ request: ExternalConnectorExecutableProbeRequest,
    _ selected: ExternalConnectorExecutableProbeAttempt,
    _ attempts: [ExternalConnectorExecutableProbeAttempt]
) -> ExternalConnectorExecutableProbeNoteContext {
    ExternalConnectorExecutableProbeNoteContext(
        requestedExecutable: request.executable,
        selectedExecutable: selected.executable,
        attemptedExecutables: attempts.map(\.executable),
        expected: request.expected,
        detected: selected.detectedIdentity,
        result: selected.result
    )
}

private struct ExternalConnectorExecutableProbeAttempt {
    var executable: String
    var result: ExternalConnectorProcessResult
    var detectedIdentity: ExternalConnectorExecutableIdentity
    var verdict: MeasurementVerdict
}

private func detectExternalConnectorExecutableIdentity(_ text: String) -> ExternalConnectorExecutableIdentity {
    let lowered = text.lowercased()
    if externalConnectorExecutableTextIsPythonUv(lowered) {
        return .pythonUv
    }
    if externalConnectorExecutableTextIsUltraGrid(lowered) {
        return .ultraGrid
    }
    if lowered.contains("jacktrip") {
        return .jackTrip
    }
    return .unknown
}

private func externalConnectorExecutableTextIsPythonUv(_ lowered: String) -> Bool {
    lowered.contains("an extremely fast python package manager")
        || (lowered.contains("python package") && lowered.contains("uv"))
}

private func externalConnectorExecutableTextIsUltraGrid(_ lowered: String) -> Bool {
    lowered.contains("ultragrid")
        || externalConnectorExecutableTextHasUltraGridHelpFlags(lowered)
}

private func externalConnectorExecutableTextHasUltraGridHelpFlags(_ lowered: String) -> Bool {
    lowered.contains("capture")
        && lowered.contains("display")
        && lowered.contains("-t")
        && lowered.contains("-d")
}

// swiftlint:disable:next type_name
private struct ExternalConnectorExecutableProbeNoteContext {
    let requestedExecutable: String
    let selectedExecutable: String
    let attemptedExecutables: [String]
    let expected: ExternalConnectorExecutableIdentity
    let detected: ExternalConnectorExecutableIdentity
    let result: ExternalConnectorProcessResult
}

private func externalConnectorExecutableProbeNotes(_ context: ExternalConnectorExecutableProbeNoteContext) -> String {
    if !context.result.launched {
        return externalConnectorExecutableNotLaunchedNote(context)
    }
    if context.result.exitStatus != 0 {
        return externalConnectorExecutableExitStatusNote(context)
    }
    if context.expected != context.detected {
        return externalConnectorExecutableMismatchNote(context)
    }
    return externalConnectorExecutableMatchedNote(context)
}

private func externalConnectorExecutableNotLaunchedNote(
    _ context: ExternalConnectorExecutableProbeNoteContext
) -> String {
    [
        "\(context.requestedExecutable) could not be launched through PATH,",
        "common macOS install locations, or the supplied path."
    ].joined(separator: " ")
}

private func externalConnectorExecutableExitStatusNote(
    _ context: ExternalConnectorExecutableProbeNoteContext
) -> String {
    let status = context.result.exitStatus ?? -1
    return "\(context.selectedExecutable) launched but exited with status \(status).\(discoverySuffix(context))"
}

private func externalConnectorExecutableMismatchNote(
    _ context: ExternalConnectorExecutableProbeNoteContext
) -> String {
    [
        "\(context.selectedExecutable) launched, but identity \(context.detected.rawValue)",
        "does not match expected \(context.expected.rawValue).\(discoverySuffix(context))"
    ].joined(separator: " ")
}

private func externalConnectorExecutableMatchedNote(
    _ context: ExternalConnectorExecutableProbeNoteContext
) -> String {
    [
        "\(context.selectedExecutable) launched and matched expected",
        "\(context.expected.rawValue) identity.\(discoverySuffix(context))"
    ].joined(separator: " ")
}

private func discoverySuffix(_ context: ExternalConnectorExecutableProbeNoteContext) -> String {
    guard context.selectedExecutable != context.requestedExecutable else {
        return ""
    }
    return [
        " Selected \(context.selectedExecutable) after trying",
        "\(context.attemptedExecutables.joined(separator: ", "))."
    ].joined(separator: " ")
}
