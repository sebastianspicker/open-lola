import Foundation
import Testing

@testable import OpenLolaAppSupport
@testable import OpenLolaCore

@Test
func appCopyVocabularyNamesEvidenceAndWindowsLoLaTermsConsistently() {
    #expect(AppCopyVocabulary.windowsLoLaConnector == "Windows LoLa connector")
    #expect(AppCopyVocabulary.windowsLoLaReportNotLoaded == "Windows LoLa report not loaded")
    #expect(AppCopyVocabulary.sourceSyntheticReport == "Source/synthetic report")
    #expect(AppCopyVocabulary.sourceSyntheticPartial == "Source/synthetic PARTIAL")
    #expect(AppCopyVocabulary.currentRuntimeEvidence == "Current runtime evidence")
    #expect(AppCopyVocabulary.packetEvidence == "Packet evidence")
    #expect(AppCopyVocabulary.remotePacketEvidence == "Remote packet evidence")
    #expect(AppCopyVocabulary.remotePlanUnavailable == "Remote plan unavailable")
}

@Test
func appExecutionErrorGuidanceClassifiesCommonFailureTypes() {
    #expect(AppExecutionErrorGuidance.detail(
        for: "Cannot validate missing report artifact: /tmp/supervisor.json"
    ).contains("report path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "No such file or executable"
    ).contains("executable path"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "plan validation failed"
    ).contains("plan fields"))
    #expect(AppExecutionErrorGuidance.detail(
        for: "process exited 42"
    ).contains("log paths"))
}

@Test
func appReadableMetricAccessibilityIncludesMetricContext() {
    #expect(AppReadableMetricAccessibility.valueLabel(
        metric: "Plan",
        value: "/tmp/plan.json"
    ) == "Plan: /tmp/plan.json")
    #expect(
        AppReadableMetricAccessibility.fullValueHelp(
            metric: "Plan",
            value: "/tmp/open-lola/very/long/plan.json"
        ) == "Full Plan value: /tmp/open-lola/very/long/plan.json"
    )
    #expect(AppReadableMetricAccessibility.valueHint(metric: "Plan").contains("can be copied"))
    #expect(AppReadableMetricAccessibility.copyLabel(metric: "Audio input UID") == "Copy Audio input UID value")
}

@Test
func appLongOperationalValuesExposeFullIdentifiersInHelpAndAccessibilityText() {
    let longUID = "AppleUSBAudioEngine:Vendor:Product:Device:Input:00000000000000000001"
    let longHost = "mac-studio-control-room-with-long-hostname.example.local"

    #expect(
        AppDeviceIdentifierDisplayPolicy.fullValueHelp(identifier: longUID) ==
            "Full device identifier: \(longUID)"
    )
    #expect(AppDeviceIdentifierDisplayPolicy.accessibilityHint(identifier: longUID).contains(longUID))
    #expect(
        AppConnectionTopologyValuePolicy.fullValueHelp(role: "Remote host", value: longHost) ==
            "Remote host: \(longHost)"
    )
    #expect(
        AppConnectionTopologyValuePolicy.accessibilityLabel(role: "Remote host", value: longHost) ==
            "Remote host: \(longHost)"
    )
}

@MainActor
@Test
func appPasteboardCopyReportsWriteResultBeforeSuccessStatus() {
    let originalWriter = AppPasteboard.writeString
    defer {
        AppPasteboard.writeString = originalWriter
    }
    var copiedValues: [String] = []
    AppPasteboard.writeString = { value in
        copiedValues.append(value)
        return true
    }

    #expect(AppPasteboard.copyString("open-lola --dry-run"))
    #expect(copiedValues == ["open-lola --dry-run"])

    AppPasteboard.writeString = { _ in false }
    #expect(!AppPasteboard.copyString("open-lola --dry-run"))
    let failedCopyFeedback = AppPasteboard.copyFeedback("open-lola --dry-run", target: "exact command")
    #expect(!failedCopyFeedback.copied)
    #expect(failedCopyFeedback.message == "Copy failed for exact command.")
    #expect(failedCopyFeedback.systemImage == "exclamationmark.triangle")

    let copiedStatuses = [
        (
            success: "Copied local inventory JSON.",
            failure: "Copy failed for local inventory JSON."
        ),
        (
            success: "Generated copyable plan JSON.",
            failure: "Generated plan JSON, but pasteboard copy failed."
        ),
        (
            success: "Wrote plan artifact to /tmp/plan.json.",
            failure: "Wrote plan artifact, but pasteboard copy failed."
        ),
        (
            success: "Reloaded plan artifact from /tmp/plan.json.",
            failure: "Reloaded plan artifact, but pasteboard copy failed."
        ),
        (
            success: "Copied SSH supervisor command.",
            failure: "Copy failed for SSH supervisor command."
        ),
    ]

    for status in copiedStatuses {
        #expect(AppPasteboardCopyStatus.message(
            copied: true,
            success: status.success,
            failure: status.failure
        ) == status.success)
        let failedMessage = AppPasteboardCopyStatus.message(
            copied: false,
            success: status.success,
            failure: status.failure
        )
        #expect(failedMessage == status.failure)
        #expect(!failedMessage.hasPrefix("Copied"))
        #expect(!failedMessage.hasPrefix("Generated copyable"))
    }
}
