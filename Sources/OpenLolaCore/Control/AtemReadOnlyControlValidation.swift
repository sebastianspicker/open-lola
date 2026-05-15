import Foundation

extension AtemReadOnlyControlReport {
    public func validate() throws {
        try requireAtemNonEmpty(id, "id")
        try requireAtemNonEmpty(title, "title")
        try requireAtemNonEmpty(capturedAt, "capturedAt")
        try requireAtemNonEmpty(ipAddress, "ipAddress")
        try requireAtemNonEmpty(model, "model")
        try requireAtemNonEmpty(firmware, "firmware")
        try requireAtemNonEmpty(programSource, "programSource")
        try requireAtemNonEmpty(previewSource, "previewSource")
        try requireAtemNonEmpty(tally, "tally")
        try requireAtemNonEmpty(audioMixerState, "audioMixerState")
        try requireAtemNonEmpty(notes, "notes")
        try validateOptionalEvidence()

        guard !armedCommandsAllowed else {
            throw AtemReadOnlyControlValidationError.commandsArmed
        }

        guard verdict != .pass || health == .connected else {
            throw AtemReadOnlyControlValidationError.passWithoutConnectedHealth(health)
        }
        try validatePassEvidence()
    }


    private func validateOptionalEvidence() throws {
        if let protocolName {
            try requireAtemNonEmpty(protocolName, "protocolName")
        }
        if let networkInterface {
            try requireAtemNonEmpty(networkInterface, "networkInterface")
        }
        if let readOnlyPollIntervalMilliseconds {
            try requireAtemPositive(readOnlyPollIntervalMilliseconds, "readOnlyPollIntervalMilliseconds")
        }
        if let connectionAttemptMilliseconds {
            try requireAtemNonNegative(connectionAttemptMilliseconds, "connectionAttemptMilliseconds")
        }
        if let errorMessage {
            try requireAtemNonEmpty(errorMessage, "errorMessage")
        }
    }

    private func validatePassEvidence() throws {
        guard verdict == .pass else {
            return
        }
        guard controlPort != nil,
              protocolName != nil,
              networkInterface != nil,
              connectionAttemptMilliseconds != nil else {
            throw AtemReadOnlyControlValidationError.passWithoutNetworkEvidence
        }
        for field in placeholderSensitiveFields() where isAtemPlaceholder(field.value) {
            throw AtemReadOnlyControlValidationError.passWithPlaceholderField(field.name)
        }
    }

    private func placeholderSensitiveFields() -> [(name: String, value: String)] {
        var fields = [
            ("ipAddress", ipAddress),
            ("model", model),
            ("firmware", firmware),
            ("programSource", programSource),
            ("previewSource", previewSource),
            ("tally", tally),
            ("audioMixerState", audioMixerState),
            ("notes", notes),
        ]
        if let protocolName {
            fields.append(("protocolName", protocolName))
        }
        if let networkInterface {
            fields.append(("networkInterface", networkInterface))
        }
        return fields
    }
}
