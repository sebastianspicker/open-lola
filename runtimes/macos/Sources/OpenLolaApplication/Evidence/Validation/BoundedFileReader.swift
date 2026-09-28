import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
// Manages BoundedFileReader resource handling, keeping file-descriptor and process lifetime details out of calling workflows.
import Foundation
import Darwin

/// Reads data, text, and JSON while enforcing a caller-configurable byte limit.
public enum BoundedFileReadError: Error, Equatable, CustomStringConvertible, Sendable {
    case fileTooLarge(path: String, bytes: Int, limit: Int)
    case unreadableText(path: String, encoding: String)

    public var description: String {
        switch self {
        case let .fileTooLarge(path, bytes, limit):
            return "File \(path) is too large to read safely (\(bytes) bytes, limit \(limit) bytes)."
        case let .unreadableText(path, encoding):
            return "File \(path) could not be decoded as \(encoding)."
        }
    }
}

/// Defines the finite structured result values recorded by bounded file reader artifacts for deterministic validation and report interpretation.
public enum BoundedFileReader {
    public static let defaultJSONByteLimit = 100 * 1024 * 1024

    public static func data(
        at url: URL,
        maxBytes: Int = defaultJSONByteLimit
    ) throws -> Data {
        guard maxBytes >= 0, maxBytes < Int.max else {
            throw CocoaError(.fileReadTooLarge)
        }
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard metadata.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileReadUnsupportedScheme) }
        var result = Data()
        while result.count <= maxBytes {
            let count = min(64 * 1024, maxBytes - result.count + 1)
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { return result }
            result.append(chunk)
        }
        throw BoundedFileReadError.fileTooLarge(path: url.path, bytes: result.count, limit: maxBytes)
    }

    public static func data(
        atPath path: String,
        maxBytes: Int = defaultJSONByteLimit
    ) throws -> Data {
        try data(at: URL(fileURLWithPath: path), maxBytes: maxBytes)
    }

    public static func string(
        at url: URL,
        encoding: String.Encoding = .utf8,
        maxBytes: Int = defaultJSONByteLimit
    ) throws -> String {
        let data = try data(at: url, maxBytes: maxBytes)
        guard let text = String(data: data, encoding: encoding) else {
            throw BoundedFileReadError.unreadableText(
                path: url.path,
                encoding: String(describing: encoding)
            )
        }
        return text
    }

    public static func decodeJSON<T: Decodable>(
        _ type: T.Type,
        fromPath path: String,
        maxBytes: Int = defaultJSONByteLimit
    ) throws -> T {
        try JSONDecoder().decode(type, from: data(atPath: path, maxBytes: maxBytes))
    }
}

public extension ReportValidatingArtifact {
    static func readValidated(
        from url: URL,
        maxBytes: Int = BoundedFileReader.defaultJSONByteLimit
    ) throws -> Self {
        let report = try decode(from: BoundedFileReader.data(at: url, maxBytes: maxBytes))
        try report.validate()
        return report
    }

    static func readValidated(
        fromPath path: String,
        maxBytes: Int = BoundedFileReader.defaultJSONByteLimit
    ) throws -> Self {
        try readValidated(from: URL(fileURLWithPath: path), maxBytes: maxBytes)
    }
}
