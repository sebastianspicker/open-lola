// Verifies that integrated AV run configuration parses video transport report path.
import Foundation
import Testing

@testable import OpenLolaCore

@Test
func integratedAvRunConfigurationParsesVideoTransportReportPath() throws {
    let configuration = try IntegratedAvRunConfiguration.parse([
        "--audio-baseline", "m05-route-baseline-required",
        "--video-capture", "on",
        "--video-transport", "on",
        "--video-preview", "off",
        "--osc-control", "on",
        "--atem-readonly", "192.0.2.10",
        "--duration-seconds", "60",
        "--video-transport-report", "reports/m09-video-transport.json",
        "--output", "reports/m10-integrated-av-run.json"
    ])

    #expect(configuration.videoTransportReportPath == "reports/m09-video-transport.json")
}

@Test
func integratedAvRunAggregatesMeasuredVideoTransportReport() throws {
    let videoTransport = try localhostVideoTransportReport()

    let configuration = integratedAvDegradeFirstRunConfiguration()

    let report = IntegratedAvRunner.run(
        configuration: configuration,
        videoTransportReport: videoTransport
    )

    try report.validate()

    #expect(report.id == "m10-integrated-av-run")
    #expect(report.runMode == .measured)
    #expect(report.video.format.width == 32)
    #expect(report.video.format.height == 18)
    #expect(report.video.frameTiming.lastFrameId == videoTransport.transmitted.framesSent)
    #expect(report.video.receiverDroppedFrames == videoTransport.receiver.droppedFrames)
    #expect(report.proof?.videoTransportReportId == videoTransport.id)
    #expect(report.proof?.videoTransportPacketCapturePoint == "local-udp-socket-loopback")
    #expect(report.verdict == .partial)
    #expect(report.notes.contains("Measured partial integrated A/V aggregate"))
}
