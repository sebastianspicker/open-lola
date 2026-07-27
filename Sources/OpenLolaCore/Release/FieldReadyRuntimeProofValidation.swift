// Validates FieldReadyRuntimeProofValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension FieldReadyRuntimeProofReport {
    public func validate() throws {
        try validateIdentity()
        try validateP04()
        try validateRuntime()
        try validateRecording()
        try validateDistribution()
        try validateCleanMac()
        try VerdictValidationPolicy.validatePass(verdict) {
            try validatePassVerdict()
        }
    }

    private func validateIdentity() throws {
        try FieldReadyRuntimeValidator.requireNonEmpty(id, "id")
        try FieldReadyRuntimeValidator.requireNonEmpty(title, "title")
        try FieldReadyRuntimeValidator.requireNonEmpty(capturedAt, "capturedAt")
        try FieldReadyRuntimeValidator.requireISO8601Date(capturedAt, "capturedAt")
        try FieldReadyRuntimeValidator.requireNonEmpty(notes, "notes")
    }

    private func validateP04() throws {
        try FieldReadyRuntimeValidator.requireNonEmpty(p04.integratedReportId, "p04.integratedReportId")
    }

    private func validateRuntime() throws {
        guard !runtime.cliReportIds.isEmpty else {
            throw FieldReadyRuntimeValidationError.emptyList("runtime.cliReportIds")
        }
        for reportId in runtime.cliReportIds {
            try FieldReadyRuntimeValidator.requireNonEmpty(reportId, "runtime.cliReportIds")
        }
        if runtime.mode != .cliOnly {
            try FieldReadyRuntimeValidator.requireNonEmpty(runtime.appShellReportId, "runtime.appShellReportId")
        }
    }

    private func validateRecording() throws {
        if recording.enabled {
            try FieldReadyRuntimeValidator.requireNonEmpty(recording.reportId, "recording.reportId")
        }
    }

    private func validateDistribution() throws {
        try FieldReadyRuntimeValidator.requireNonEmpty(
distribution.signingIdentityLabel,
"distribution.signingIdentityLabel"
)
    }

    private func validateCleanMac() throws {
        if !cleanMac.targetLabel.isEmpty {
            try FieldReadyRuntimeValidator.requireNonEmpty(cleanMac.hardwareIdentifier, "cleanMac.hardwareIdentifier")
            try FieldReadyRuntimeValidator.requireNonEmpty(cleanMac.osVersion, "cleanMac.osVersion")
        }
        if cleanMac.rmeDeviceVisible {
            try FieldReadyRuntimeValidator.requireNonEmpty(
cleanMac.deviceInventoryReportId,
"cleanMac.deviceInventoryReportId"
)
        }
        if cleanMac.atemReadOnlyStatusRecorded {
            try FieldReadyRuntimeValidator.requireNonEmpty(
cleanMac.atemReadOnlyReportId,
"cleanMac.atemReadOnlyReportId"
)
        }
    }

    private func validatePassVerdict() throws {
        guard runMode == .measured else {
            throw FieldReadyRuntimeValidationError.passWithoutMeasuredRun
        }
        try validatePassP04Evidence()
        try validatePassRuntimeEvidence()
        try validatePassPermissions()
        try validatePassRecording()
        try validatePassDistribution()
        try validatePassCleanMacTarget()
        try validatePassCleanMacEvidence()
    }

    private func validatePassP04Evidence() throws {
        guard p04.verdict == .pass else {
            throw FieldReadyRuntimeValidationError.passWithoutDefensibleP04
        }
    }

    private func validatePassRuntimeEvidence() throws {
        guard runtime.mode == .signedApp else {
            throw FieldReadyRuntimeValidationError.passWithoutSignedAppRuntime(runtime.mode)
        }
        guard runtime.cliAuthoritative else {
            throw FieldReadyRuntimeValidationError.passWithoutCliAuthority
        }
        guard runtime.cliWorkflowCanWriteReports else {
            throw FieldReadyRuntimeValidationError.passWithoutCliReportWriting
        }
        guard !runtime.appShellOwnsRealtimePaths else {
            throw FieldReadyRuntimeValidationError.passWithAppRealtimeOwnership
        }
    }

    private func validatePassPermissions() throws {
        guard permissions.microphonePurposeStringPresent,
              permissions.cameraPurposeStringPresent,
              permissions.localNetworkPurposeStringPresent
        else {
            throw FieldReadyRuntimeValidationError.passWithoutPurposeStrings
        }
        guard permissions.promptsObserved else {
            throw FieldReadyRuntimeValidationError.passWithoutPermissionPromptRecord
        }
    }

    private func validatePassRecording() throws {
        guard recording.enabled, !recording.reportId.isEmpty else {
            throw FieldReadyRuntimeValidationError.passWithoutRecordingEvidence
        }
        guard recording.writesOutsideRealtimePaths, recording.dropOrGapEvidenceRecorded else {
            throw FieldReadyRuntimeValidationError.passWithoutRecordingSideLane
        }
    }

    private func validatePassDistribution() throws {
        guard distribution.signingStatusRecorded else {
            throw FieldReadyRuntimeValidationError.passWithoutSigningStatusRecord
        }
        guard distribution.notarizationStatusRecorded else {
            throw FieldReadyRuntimeValidationError.passWithoutNotarizationStatusRecord
        }
        guard distribution.notarizationStatus == .gatekeeperAccepted else {
            throw FieldReadyRuntimeValidationError.passWithoutGatekeeperAcceptedDistribution(
                distribution.notarizationStatus
            )
        }
        if runtime.mode == .signedApp {
            guard distribution.notarizationStatus != .deferred,
                  distribution.notarizationStatus != .notReady
            else {
                throw FieldReadyRuntimeValidationError.passWithoutSignedAppDistributionReadiness
            }
        }
    }

    private func validatePassCleanMacTarget() throws {
        guard !cleanMac.targetLabel.isEmpty,
              !cleanMac.hardwareIdentifier.isEmpty,
              !cleanMac.osVersion.isEmpty,
              !cleanMac.deviceInventoryReportId.isEmpty
        else {
            throw FieldReadyRuntimeValidationError.passWithoutCleanMacTarget
        }
    }

    private func validatePassCleanMacEvidence() throws {
        guard cleanMac.verdict == .pass else {
            throw FieldReadyRuntimeValidationError.passWithoutCleanMacPass
        }
        guard cleanMac.machineReadableVerdict else {
            throw FieldReadyRuntimeValidationError.passWithoutMachineReadableFieldVerdict
        }
        guard cleanMac.rmeDeviceVisible else {
            throw FieldReadyRuntimeValidationError.passWithoutRmeVisibility
        }
        guard cleanMac.atemReadOnlyStatusRecorded, !cleanMac.atemReadOnlyReportId.isEmpty else {
            throw FieldReadyRuntimeValidationError.passWithoutAtemStatus
        }
        guard cleanMac.reportWriteSucceeded else {
            throw FieldReadyRuntimeValidationError.passWithoutReportWrite
        }
    }
}
