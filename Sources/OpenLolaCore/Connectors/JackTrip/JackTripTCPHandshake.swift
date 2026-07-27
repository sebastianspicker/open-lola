// Encodes and validates JackTrip TCP hub handshakes, keeping byte-level authentication and port negotiation outside session orchestration.
import Foundation

/// Enumerates the supported operating modes for JackTrip hub TCP handshake.
public enum JackTripHubTCPHandshakeMode: String, Codable, Equatable, Sendable {
    case none
    case unauthenticated
    case authenticatedTLS = "authenticated-tls"
}

/// Defines the supported choices for JackTrip TCP handshake state.
public enum JackTripTCPHandshakeState: String, Codable, Equatable, Sendable {
    case notApplicable = "not-applicable"
    case clientRequestReady = "client-request-ready"
    case serverResponseReady = "server-response-ready"
    case authenticationRequestReady = "authentication-request-ready"
    case authenticatedClientInfoReady = "authenticated-client-info-ready"
}

/// Defines the supported choices for JackTrip auth response.
public enum JackTripAuthResponse: Int32, Codable, Equatable, Sendable {
    // swiftlint:disable:next identifier_name
    case ok = 65_536
    case required = 131_072
    case notRequired = 196_608
    case wrongCredentials = 262_144
    case wrongTime = 327_680
}

/// Records the evidence and outcome for JackTrip TCP handshake report.
public struct JackTripTCPHandshakeReport: Codable, Equatable, Sendable {
    public var mode: JackTripHubTCPHandshakeMode
    public var state: JackTripTCPHandshakeState
    public var clientUDPPort: UInt16
    public var serverUDPPort: UInt16
    public var remoteClientName: String?
    public var authResponse: JackTripAuthResponse?
    public var clientRequestByteCount: Int
    public var serverResponseByteCount: Int
    public var credentialFrameByteCount: Int
    public var notes: String

    public func validate(fieldPrefix: String) throws {
        try requireExternalConnectorSessionNonEmpty(notes, "\(fieldPrefix).notes")
        if mode == .none {
            guard state == .notApplicable else {
                throw ExternalConnectorSessionError.unsupportedRuntimeMode(
                    "jacktrip-tcp-handshake-state-\(state.rawValue)"
                )
            }
            return
        }

        try validatePorts(fieldPrefix: fieldPrefix)
        try validateByteCounts(fieldPrefix: fieldPrefix)
        try validateAuthentication(fieldPrefix: fieldPrefix)
    }

    private func validatePorts(fieldPrefix: String) throws {
        guard clientUDPPort > 0 else {
            throw ExternalConnectorSessionError.invalidPort("\(fieldPrefix).clientUDPPort", String(clientUDPPort))
        }
        guard serverUDPPort > 0 else {
            throw ExternalConnectorSessionError.invalidPort("\(fieldPrefix).serverUDPPort", String(serverUDPPort))
        }
    }

    private func validateByteCounts(fieldPrefix: String) throws {
        guard clientRequestByteCount == 4
            || clientRequestByteCount == JackTripTCPHandshakeCodec.clientRequestByteCount
        else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "\(fieldPrefix).clientRequestByteCount",
                String(clientRequestByteCount)
            )
        }
        guard serverResponseByteCount == 4 else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "\(fieldPrefix).serverResponseByteCount",
                String(serverResponseByteCount)
            )
        }
    }

    private func validateAuthentication(fieldPrefix: String) throws {
        guard mode == .authenticatedTLS else {
            return
        }
        guard authResponse != nil else {
            throw ExternalConnectorSessionError.emptyField("\(fieldPrefix).authResponse")
        }
        guard credentialFrameByteCount == 0
            || credentialFrameByteCount >= JackTripTCPHandshakeCodec.authenticatedClientInfoMinimumByteCount else {
            throw ExternalConnectorSessionError.invalidPositiveInteger(
                "\(fieldPrefix).credentialFrameByteCount",
                String(credentialFrameByteCount)
            )
        }
    }
}

/// Encodes and decodes JackTrip TCP handshake requests, responses, and authentication fields.
public enum JackTripTCPHandshakeCodec {
    public static let remoteNameByteCount = 64
    public static let clientRequestByteCount = 4 + remoteNameByteCount
    public static let authenticatedClientInfoMinimumByteCount = clientRequestByteCount + 10
    public static let maxCredentialByteCount = 256

    public static func encodeAuthenticationRequest() -> Data {
        var data = Data()
        appendJackTripInt32LE(JackTripAuthResponse.ok.rawValue, to: &data)
        return data
    }

    public static func decodeAuthResponse(_ data: Data) throws -> JackTripAuthResponse {
        let bytes = [UInt8](data)
        guard bytes.count == 4 else {
            throw JackTripCompatibilityError.payloadLengthMismatch(expected: 4, actual: bytes.count)
        }
        let value = readJackTripInt32LE(bytes, offset: 0)
        guard let response = JackTripAuthResponse(rawValue: value) else {
            throw JackTripCompatibilityError.invalidField("authResponse", Int(value))
        }
        return response
    }

    public static func encodeClientRequest(
        clientUDPPort: UInt16,
        remoteClientName: String?
    ) throws -> Data {
        var data = Data()
        appendJackTripInt32LE(Int32(clientUDPPort), to: &data)
        guard let remoteClientName, !remoteClientName.isEmpty else {
            return data
        }
        guard let nameData = remoteClientName.data(using: .utf8),
              nameData.count < remoteNameByteCount else {
            throw ExternalConnectorSessionError.invalidProcessArgument("jackTrip.remoteClientName", remoteClientName)
        }
        data.append(nameData)
        data.append(0)
        data.append(Data(repeating: 0, count: remoteNameByteCount - nameData.count - 1))
        return data
    }

    public static func decodeClientRequest(_ data: Data) throws -> (clientUDPPort: UInt16, remoteClientName: String?) {
        let bytes = [UInt8](data)
        guard bytes.count == 4 || bytes.count == clientRequestByteCount else {
            throw JackTripCompatibilityError.payloadLengthMismatch(
                expected: clientRequestByteCount,
                actual: bytes.count
            )
        }
        let value = readJackTripInt32LE(bytes, offset: 0)
        guard value > 0, value <= Int32(UInt16.max) else {
            throw JackTripCompatibilityError.invalidField("clientUDPPort", Int(value))
        }
        let name: String?
        if bytes.count == clientRequestByteCount {
            let nameBytes = bytes[4..<clientRequestByteCount].prefix { $0 != 0 }
            guard !nameBytes.isEmpty else {
                return (UInt16(value), nil)
            }
            guard let decodedName = String(bytes: nameBytes, encoding: .utf8) else {
                throw JackTripCompatibilityError.invalidField("remoteClientNameUTF8", nameBytes.count)
            }
            name = decodedName
        } else {
            name = nil
        }
        return (UInt16(value), name)
    }

    public static func encodeServerResponse(serverUDPPort: UInt16) -> Data {
        var data = Data()
        appendJackTripInt32LE(Int32(serverUDPPort), to: &data)
        return data
    }

    public static func decodeServerResponse(_ data: Data) throws -> UInt16 {
        let bytes = [UInt8](data)
        guard bytes.count == 4 else {
            throw JackTripCompatibilityError.payloadLengthMismatch(expected: 4, actual: bytes.count)
        }
        let value = readJackTripInt32LE(bytes, offset: 0)
        guard value > 0, value <= Int32(UInt16.max) else {
            throw JackTripCompatibilityError.invalidField("serverUDPPort", Int(value))
        }
        return UInt16(value)
    }

    public static func encodeAuthenticatedClientInfo(
        clientUDPPort: UInt16,
        remoteClientName: String?,
        username: String,
        password: String
    ) throws -> Data {
        guard !username.isEmpty, !password.isEmpty else {
            throw ExternalConnectorSessionError.invalidProcessArgument("jackTrip.authCredentials", "<empty>")
        }
        guard let usernameData = username.data(using: .utf8),
              let passwordData = password.data(using: .utf8),
              usernameData.count <= maxCredentialByteCount,
              passwordData.count <= maxCredentialByteCount else {
            throw ExternalConnectorSessionError.invalidProcessArgument("jackTrip.authCredentials", "<oversized>")
        }
        var data = try encodeClientRequest(clientUDPPort: clientUDPPort, remoteClientName: remoteClientName)
        if data.count == 4 {
            data.append(Data(repeating: 0, count: remoteNameByteCount))
        }
        appendJackTripInt32LE(Int32(usernameData.count), to: &data)
        appendJackTripInt32LE(Int32(passwordData.count), to: &data)
        data.append(usernameData)
        data.append(0)
        data.append(passwordData)
        data.append(0)
        return data
    }
}

func parseJackTripHubTCPHandshakeMode(_ value: String) throws -> JackTripHubTCPHandshakeMode {
    switch value {
    case "none", "off", "disabled":
        return .none
    case "unauthenticated", "tcp", "plain":
        return .unauthenticated
    case "authenticated-tls", "auth", "tls":
        return .authenticatedTLS
    default:
        throw ExternalConnectorSessionError.unknownArgument("--jacktrip-hub-tcp-handshake \(value)")
    }
}

func appendJackTripInt32LE(_ value: Int32, to data: inout Data) {
    let unsigned = UInt32(bitPattern: value)
    data.append(UInt8(unsigned & 0xff))
    data.append(UInt8((unsigned >> 8) & 0xff))
    data.append(UInt8((unsigned >> 16) & 0xff))
    data.append(UInt8((unsigned >> 24) & 0xff))
}

func readJackTripInt32LE(_ bytes: [UInt8], offset: Int) -> Int32 {
    let unsigned = UInt32(bytes[offset])
        | (UInt32(bytes[offset + 1]) << 8)
        | (UInt32(bytes[offset + 2]) << 16)
        | (UInt32(bytes[offset + 3]) << 24)
    return Int32(bitPattern: unsigned)
}
