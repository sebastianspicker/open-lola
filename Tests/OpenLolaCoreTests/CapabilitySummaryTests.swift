// Verifies that the capability summary describes only the M00 scaffold.
import Testing

@testable import OpenLolaCore

@Test
func capabilitySummaryDescribesTheM00ScaffoldOnly() {
    let summary = CapabilitySummary.m00Scaffold

    #expect(summary.name == "open-lola")
    #expect(summary.version == "0.0.0-m00")
    #expect(summary.stage == .m00Scaffold)
    #expect(summary.capabilities == [
        "swift-package",
        "core-model",
        "cli-summary"
    ])
    #expect(summary.description == "open-lola 0.0.0-m00 (M00 scaffold)")
}

@Test
func capabilitySummaryDescriptionIsDerivedFromInstanceValues() {
    let summary = CapabilitySummary(
        name: "open-lola-test",
        version: "0.0.0-m02-test",
        stage: .m02ProtocolSession,
        capabilities: []
    )

    #expect(summary.description == "open-lola-test 0.0.0-m02-test (M02 protocol/session model)")
}

@Test
func capabilitySummaryDevelopmentStageIncludesCurrentMilestones() {
    #expect(CapabilitySummary.m14ReleaseHardening.stage == .m14ReleaseHardening)
    #expect(CapabilitySummary.m14ReleaseHardening.description == "open-lola 0.0.0-m14 (M14 release hardening)")
    #expect(CapabilitySummary.m15PackagingFieldTest.stage == .m15PackagingFieldTest)
    #expect(CapabilitySummary.m15PackagingFieldTest.description == "open-lola 0.0.0-m15 (M15 packaging field-test)")
}

@Test
func capabilitySummaryCurrentMatchesCompileTimeMilestoneConstants() {
    let summary = CapabilitySummary.current

    #expect(summary.name == "open-lola")
    #expect(summary.version == CapabilitySummary.currentVersion)
    #expect(summary.stage == CapabilitySummary.currentStage)
    #expect(summary.capabilities.isEmpty == false)
    #expect(Set(summary.capabilities).count == summary.capabilities.count)
    #expect(summary.capabilities.allSatisfy { !$0.isEmpty })
    #expect(summary.description == "\(summary.name) \(summary.version) (\(summary.stage.rawValue))")
}
