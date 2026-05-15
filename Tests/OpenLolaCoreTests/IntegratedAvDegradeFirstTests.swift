import Foundation
import Testing

@testable import OpenLolaCore

@Test
func integratedAvReportRejectsVideoChangingAudioPlayoutTarget() throws {
    var report = try integratedAvPassCandidateReport()
    report.sync.videoMayChangeAudioPlayoutTarget = true

    #expect(throws: IntegratedAvValidationError.videoMayChangeAudioPlayoutTarget) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsSyncWithoutVideoPreAudioImpactDegradation() throws {
    var report = try integratedAvPassCandidateReport()
    report.sync.videoDegradesBeforeAudioImpact = false

    #expect(throws: IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation) {
        try report.validate()
    }
}

@Test
func integratedAvReportRejectsPassWithoutVideoDegradationBeforeRouteOrAudioImpact() throws {
    var report = try integratedAvPassCandidateReport()
    report.video.degradation.triggeredBeforeAudioOrRouteImpact = false

    #expect(throws: IntegratedAvValidationError.videoWithoutPreAudioImpactDegradation) {
        try report.validate()
    }
}
