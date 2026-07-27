// Handles LoLaAVFoundationPayloadCollectors receive-side processing, isolating input handling from compatibility and report policy.
import Foundation
import Dispatch

// swiftlint:disable:next line_length
#if canImport(AVFoundation) && canImport(CoreGraphics) && canImport(CoreImage) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
@preconcurrency import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo

protocol LoLaAVFoundationPayloadCollector: AVCaptureVideoDataOutputSampleBufferDelegate {
    var payloadCount: Int { get }
    func waitForPayloads(until deadline: Date)
    func result() throws -> [Data]
}

final class LoLaAVFoundationMjpegCollector: LoLaAVFoundationPayloadCollectorBase, LoLaAVFoundationPayloadCollector, @unchecked Sendable {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        _ = output
        _ = connection
        captureImagePayload(
            from: sampleBuffer,
            missingImageError: nil,
            encodingError: .jpegEncodingFailed
        ) { image, _, _, _ in
            try LoLaMjpegJPEGEncoder.jpegData(from: image)
        }
    }
}

#endif
