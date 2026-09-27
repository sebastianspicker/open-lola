import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
import OpenLolaIntegrations
// Reads a LoLa capture file at a path through the bounded reader before handing bytes to the Integrations decoder.
import Foundation

public extension LoLaCompatibilityCaptureDecoder {
    static func decode(inputPath: String) throws -> LoLaCompatibilityCaptureReport {
        try decode(
            data: BoundedFileReader.data(atPath: inputPath, maxBytes: maxInputByteCount),
            inputPath: inputPath,
            capturedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
