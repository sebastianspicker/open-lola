// Exposes live and synthetic video transport entry points while delegating deadline, receive, and report work to bounded worker files.
import Darwin
import Dispatch
import Foundation

/// Exercises a deterministic video capture and frame transport path so regressions remain reproducible without hardware.
public enum VideoTransportSyntheticSmoke {
    public static func run() throws -> VideoTransportReport {
        try VideoTransportRunner.run(
            configuration: VideoTransportRunConfiguration(VideoTransportRunConfiguration.Input(
                mode: .raw,
                connection: .init(peer: "127.0.0.1", port: 5_004, durationSeconds: 1, outputPath: "stdout"),
                frame: .init(width: 1_280, height: 720, frameRate: 3),
                route: .init(kind: .syntheticLocal, packetCapturePoint: "synthetic")
            ))
        )
    }
}

/// Exercises a deterministic video capture and frame transport path so regressions remain reproducible without hardware.
public enum VideoReceiveRenderSyntheticSmoke {
    public static func run() throws -> VideoTransportReport {
        try VideoTransportSyntheticSmoke.run()
    }
}

/// Executes a bounded video transport run and returns accountable video capture and frame transport evidence.
public enum VideoTransportRunner {
    public static func run(configuration: VideoTransportRunConfiguration) throws -> VideoTransportReport {
        preconditionVideoTransportRunnerQoS()

        let socketContext = try VideoTransportSocketContext(configuration: configuration)
        defer { close(socketContext.socket) }
        try setNonBlocking(socketContext.socket)

        var context = VideoTransportRunContext(configuration: configuration)
        try runVideoTransportFrameLoop(
            configuration: configuration,
            socketContext: socketContext,
            context: &context
        )
        context.reassembler.flushIncomplete()
        return videoTransportReport(
            configuration: configuration,
            socketContext: socketContext,
            context: context
        )
    }
}
