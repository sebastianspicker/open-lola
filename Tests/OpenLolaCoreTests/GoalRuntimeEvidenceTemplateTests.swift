import Foundation
import Testing

@testable import OpenLolaCore

@Test
func goalRuntimeEvidenceTemplateMapsEveryRuntimeDeliverable() throws {
    let report = GoalRuntimeEvidenceTemplateReport.template()

    try report.validate()

    let deliverableIDs = Set(report.deliverables.map(\.id))
    let requiredIDs = Set(GoalRuntimeEvidenceDeliverableID.allCases.map(\.rawValue))

    #expect(report.goalDocument == "GOAL.md")
    #expect(report.sourceOfTruth == "docs/mac-port/README.md")
    #expect(report.verdict == .partial)
    #expect(report.realWorldVerdict == .partial)
    #expect(deliverableIDs == requiredIDs)
    #expect(report.summary.deliverableCount == requiredIDs.count)
    #expect(report.summary.partialDeliverableCount == requiredIDs.count)
}

@Test
func goalRuntimeEvidenceTemplateCarriesRequiredCommandsAndValidators() throws {
    let report = GoalRuntimeEvidenceTemplateReport.template()
    let commands = report.deliverables.flatMap(\.commandTemplates).joined(separator: "\n")
    let validators = Set(report.deliverables.flatMap(\.validators))

    #expect(commands.contains("madi-full-duplex-run"))
    #expect(commands.contains("direct-p2p-session-run --role initiator"))
    #expect(commands.contains("rx-buffer-benchmark-run"))
    #expect(commands.contains("video-capture-run"))
    #expect(commands.contains("lighting-gate-run"))
    #expect(commands.contains("packaging-field-run"))
    #expect(commands.contains("field-runtime-proof-run"))
    #expect(commands.contains("field-readiness-run"))
    #expect(commands.contains("codesign --verify"))
    #expect(commands.contains("xcrun notarytool submit"))
    #expect(commands.contains("spctl --assess"))

    #expect(validators.contains("validate-madi-full-duplex-report"))
    #expect(validators.contains("validate-direct-p2p-session-report"))
    #expect(validators.contains("validate-rx-buffer-benchmark-report"))
    #expect(validators.contains("validate-video-transport-report"))
    #expect(validators.contains("validate-packaging-field-report"))
    #expect(validators.contains("validate-field-runtime-proof"))
}

@Test
func goalRuntimeEvidenceTemplateCommandsCoverEveryAdvertisedSurface() throws {
    let report = GoalRuntimeEvidenceTemplateReport.template()

    for deliverable in report.deliverables {
        for surface in deliverable.localRunnableSurfaces {
            let command = surface.split(separator: " ", maxSplits: 1).first.map(String.init) ?? surface
            #expect(deliverable.commandTemplates.contains { $0.contains(command) })
        }
    }
}

@Test
func goalRuntimeEvidenceTemplateRejectsFalsePass() throws {
    var report = GoalRuntimeEvidenceTemplateReport.template()
    report.deliverables[0].currentVerdict = .pass
    report.summary = GoalRuntimeEvidenceTemplateSummary(deliverables: report.deliverables)

    #expect(throws: GoalRuntimeEvidenceTemplateValidationError.deliverablePassWithoutPhysicalEvidence(
        GoalRuntimeEvidenceDeliverableID.twoMacRmeMadiBidirectional.rawValue
    )) {
        try report.validate()
    }
}

@Test
func goalRuntimeEvidenceTemplateJSONSurfaceRoundTrips() throws {
    let data = try OpenLolaCLI.goalRuntimeEvidenceTemplateData()
    let decoded = try JSONDecoder().decode(GoalRuntimeEvidenceTemplateReport.self, from: data)

    #expect(decoded == GoalRuntimeEvidenceTemplateReport.template())
    #expect(decoded.realWorldVerdict == .partial)
}

@Test
func goalRuntimeEvidenceTemplateValidatorPrintsBothVerdicts() throws {
    let data = try GoalRuntimeEvidenceTemplateReport.template().prettyJSONData()
    let output = try ReportValidatorSurface.validate(
        data,
        as: GoalRuntimeEvidenceTemplateReport.self,
        label: "GOAL.md runtime evidence template",
        extraLines: { ["real-world-verdict: \($0.realWorldVerdict.rawValue)"] }
    )

    #expect(output.lines == [
        "GOAL.md runtime evidence template valid: goal-runtime-evidence-template-2026-05-05",
        "real-world-verdict: partial",
        "VERDICT: PARTIAL",
    ])
}
