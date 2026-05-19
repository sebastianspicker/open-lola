import CryptoKit
import Foundation
import Security

public struct UltraGridEncryptionConfiguration: Equatable, Sendable {
    public var mode: UltraGridEncryptionMode
    public var passphrase: String

    public init(mode: UltraGridEncryptionMode, passphrase: String) throws {
        guard mode != .none else {
            throw UltraGridCompatibilityError.unsupportedMode("encryption-disabled")
        }
        guard !passphrase.isEmpty else {
            throw UltraGridCompatibilityError.invalidField("encryption.passphrase", 0)
        }
        self.mode = mode
        self.passphrase = passphrase
    }
}

public enum UltraGridOpenSSLCipherMode: UInt8, Equatable, Sendable {
    case aes128GCM = 5
}

public struct UltraGridCryptoPayloadHeader: Equatable, Sendable {
    public static let byteCount = 4

    public var cipherMode: UltraGridOpenSSLCipherMode

    public init(cipherMode: UltraGridOpenSSLCipherMode = .aes128GCM) {
        self.cipherMode = cipherMode
    }

    public init(bytes: Data) throws {
        guard bytes.count == Self.byteCount else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: Self.byteCount,
                actual: bytes.count
            )
        }
        let word = readUltraGridUInt32BE(Array(bytes), offset: 0)
        let mode = UInt8((word >> 24) & 0xff)
        guard let cipherMode = UltraGridOpenSSLCipherMode(rawValue: mode) else {
            throw UltraGridCompatibilityError.unsupportedMode("aes-128-mode-\(mode)")
        }
        self.cipherMode = cipherMode
    }

    public func encoded() -> Data {
        var data = Data()
        appendUltraGridUInt32BE(UInt32(cipherMode.rawValue) << 24, to: &data)
        return data
    }
}

public enum UltraGridOpenSSLEncryption {
    public static let lengthByteCount = 4
    public static let ivByteCount = 16
    public static let gcmTagByteCount = 16

    public static func encrypt(
        plaintext: Data,
        aad: Data,
        configuration: UltraGridEncryptionConfiguration,
        iv: Data? = nil
    ) throws -> Data {
        guard configuration.mode == .aes128GCM else {
            throw UltraGridCompatibilityError.unsupportedMode("encryption-\(configuration.mode.rawValue)")
        }
        let iv = try iv ?? secureRandomBytes(count: ivByteCount)
        guard iv.count == ivByteCount else {
            throw UltraGridCompatibilityError.invalidPayloadLength(expected: ivByteCount, actual: iv.count)
        }
        let key = SymmetricKey(data: md5Digest(Data(configuration.passphrase.utf8)))
        let sealed = try AES.GCM.seal(
            plaintext,
            using: key,
            nonce: try AES.GCM.Nonce(data: iv),
            authenticating: aad
        )
        var output = Data()
        output.append(UInt8(plaintext.count & 0xff))
        output.append(UInt8((plaintext.count >> 8) & 0xff))
        output.append(UInt8((plaintext.count >> 16) & 0xff))
        output.append(UInt8((plaintext.count >> 24) & 0xff))
        output.append(iv)
        output.append(sealed.ciphertext)
        output.append(sealed.tag)
        return output
    }

    public static func decrypt(
        ciphertext: Data,
        aad: Data,
        configuration: UltraGridEncryptionConfiguration
    ) throws -> Data {
        let ciphertext = Data(ciphertext)
        guard configuration.mode == .aes128GCM else {
            throw UltraGridCompatibilityError.unsupportedMode("encryption-\(configuration.mode.rawValue)")
        }
        let minimum = lengthByteCount + ivByteCount + gcmTagByteCount
        guard ciphertext.count >= minimum else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: ciphertext.count)
        }
        let plaintextLength = Int(ciphertext[0])
            | (Int(ciphertext[1]) << 8)
            | (Int(ciphertext[2]) << 16)
            | (Int(ciphertext[3]) << 24)
        let ivStart = lengthByteCount
        let cipherStart = ivStart + ivByteCount
        let tagStart = ciphertext.count - gcmTagByteCount
        guard tagStart >= cipherStart else {
            throw UltraGridCompatibilityError.truncatedPayload(byteCount: ciphertext.count)
        }
        let key = SymmetricKey(data: md5Digest(Data(configuration.passphrase.utf8)))
        let sealedBox = try AES.GCM.SealedBox(
            nonce: try AES.GCM.Nonce(data: ciphertext[ivStart..<cipherStart]),
            ciphertext: ciphertext[cipherStart..<tagStart],
            tag: ciphertext[tagStart..<ciphertext.count]
        )
        let plaintext = try AES.GCM.open(sealedBox, using: key, authenticating: aad)
        guard plaintext.count == plaintextLength else {
            throw UltraGridCompatibilityError.invalidPayloadLength(
                expected: plaintextLength,
                actual: plaintext.count
            )
        }
        return plaintext
    }

    private static func md5Digest(_ data: Data) -> Data {
        Data(Insecure.MD5.hash(data: data))
    }

    private static func secureRandomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw UltraGridCompatibilityError.unsupportedMode("secure-random-\(status)")
        }
        return Data(bytes)
    }
}
