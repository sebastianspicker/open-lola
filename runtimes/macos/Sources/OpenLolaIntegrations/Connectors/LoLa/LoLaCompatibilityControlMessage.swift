import OpenLolaContracts
import OpenLolaSessionDomain
import OpenLolaEvidenceModels
import OpenLolaTransport
import OpenLolaMediaPlatform
/// Handles LoLaCompatibilityControlMessage control exchange, keeping control-plane details distinct from media data flow.
public struct LoLaControlSessionFields: Equatable, Sendable {
    public var sourceIP: String
    public var destinationIP: String
    public var sessionID: Int

    public init(sourceIP: String, destinationIP: String, sessionID: Int) {
        self.sourceIP = sourceIP
        self.destinationIP = destinationIP
        self.sessionID = sessionID
    }
}

/// Carries the sample rate, bit depth, and channel count announced by a LoLa control message.
public struct LoLaCompatibilityAudioFields: Equatable, Sendable {
    public var sampleRateHertz: Int
    public var bitsPerSample: Int
    public var channels: Int

    public init(sampleRateHertz: Int, bitsPerSample: Int, channels: Int) {
        self.sampleRateHertz = sampleRateHertz
        self.bitsPerSample = bitsPerSample
        self.channels = channels
    }
}

/// Carries the width and height announced by a LoLa video control message.
public struct LoLaCompatibilityVideoDimensions: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// Defines the validated fields for LoLa compatibility video fields.
public struct LoLaCompatibilityVideoFields: Equatable, Sendable {
    public static let none = LoLaCompatibilityVideoFields(
        frameRate: 0,
        bitsPerPixel: 0,
        dimensions: LoLaCompatibilityVideoDimensions(width: 0, height: 0),
        compression: 0,
        bayer: 0
    )

    public var frameRate: Int
    public var bitsPerPixel: Int
    public var dimensions: LoLaCompatibilityVideoDimensions
    public var compression: Int
    public var bayer: Int

    public init(
        frameRate: Int,
        bitsPerPixel: Int,
        dimensions: LoLaCompatibilityVideoDimensions,
        compression: Int = 0,
        bayer: Int = 0
    ) {
        self.frameRate = frameRate
        self.bitsPerPixel = bitsPerPixel
        self.dimensions = dimensions
        self.compression = compression
        self.bayer = bayer
    }
}

/// Defines the validated fields for LoLa compatibility media fields.
public struct LoLaCompatibilityMediaFields: Equatable, Sendable {
    public var session: LoLaControlSessionFields
    public var audio: LoLaCompatibilityAudioFields
    public var video: LoLaCompatibilityVideoFields

    public init(
        session: LoLaControlSessionFields,
        audio: LoLaCompatibilityAudioFields,
        video: LoLaCompatibilityVideoFields = .none
    ) {
        self.session = session
        self.audio = audio
        self.video = video
    }
}

/// Encodes and decodes LoLa control-message fields using the compatibility wire syntax.
public enum LoLaCompatibilityControlMessage {
    public static func checkStatus(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> String {
        encode(
            name: "/MESG_CHECKLOLASTATUS",
            fields: [
                ("SRCIP", sourceIP),
                ("DSTIP", destinationIP),
                ("SID", String(sessionID))
            ],
            hasTrailingSemicolon: true
        )
    }

    public static func checkStatusAck(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> String {
        encode(
            name: "/MESG_CHECKLOLASTATUS_ACK",
            fields: [
                ("SRCIP", sourceIP),
                ("DSTIP", destinationIP),
                ("SID", String(sessionID))
            ],
            hasTrailingSemicolon: true
        )
    }

    public static func quickConnect(_ media: LoLaCompatibilityMediaFields) -> String {
        encode(
            name: "/MESG_QUICKCONN",
            fields: mediaFields(media),
            hasTrailingSemicolon: false
        )
    }

    public static func quickConnectAck(_ media: LoLaCompatibilityMediaFields) -> String {
        encode(
            name: "/MESG_QUICKCONN_ACK",
            fields: mediaFields(media),
            hasTrailingSemicolon: false
        )
    }

    public static func reject(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int,
        text: String
    ) -> String {
        encode(
            name: "/MESG_REJECT",
            fields: commonFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ) + [("TXT", text)],
            hasTrailingSemicolon: false
        )
    }

    public static func disconnect(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> String {
        encode(
            name: "/MESG_DISCONNECT",
            fields: commonFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ),
            hasTrailingSemicolon: true
        )
    }

    public static func switchOnBounceBack(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> String {
        encode(
            name: "/MESG_SWITCH_ON_BB",
            fields: commonFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ),
            hasTrailingSemicolon: true
        )
    }

    public static func switchOffBounceBack(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> String {
        encode(
            name: "/MESG_SWITCH_OFF_BB",
            fields: commonFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ),
            hasTrailingSemicolon: true
        )
    }

    public static func chat(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int,
        text: String
    ) -> String {
        encode(
            name: "/MESG_CHAT",
            fields: commonFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ) + [("TXT", text)],
            hasTrailingSemicolon: false
        )
    }

    public static func sendAudioSignal(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> String {
        encode(
            name: "/MESG_SEND_AUDIO_SIGNAL",
            fields: commonFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ),
            hasTrailingSemicolon: false
        )
    }

    public static func stopAudioSignal(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> String {
        encode(
            name: "/MESG_STOP_AUDIO_SIGNAL",
            fields: commonFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID
            ),
            hasTrailingSemicolon: false
        )
    }

    public static func parse(_ message: String) throws -> (name: String, fields: [String: String]) {
        try LoLaControlDatagramDecoder.decode(message.utf8)
    }

    static func parseASCIIControlMessage(_ message: String) throws -> (name: String, fields: [String: String]) {
        let parts = message.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        guard let name = parts.first, name.hasPrefix("/MESG_") else {
            throw LoLaControlDatagramDecodingError(category: .malformed)
        }
        guard supportedMessageNames.contains(name) else {
            throw LoLaControlDatagramDecodingError(category: .malformed)
        }
        var fields: [String: String] = [:]
        for part in parts.dropFirst() {
            if fields["TXT"] != nil {
                throw LoLaControlDatagramDecodingError(category: .txtOrder)
            }
            guard part.contains(":") else {
                continue
            }
            let pair = part.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else {
                throw LoLaControlDatagramDecodingError(category: .malformed)
            }
            let key = String(pair[0])
            guard fields[key] == nil else {
                throw LoLaControlDatagramDecodingError(
                    category: key == "SID" ? .invalidSID : .duplicateField
                )
            }
            fields[key] = String(pair[1])
        }
        guard let canonicalSessionID = canonicalSessionID(fields["SID"]) else {
            throw LoLaControlDatagramDecodingError(category: .invalidSID)
        }
        fields["SID"] = canonicalSessionID
        if name == "/MESG_QUICKCONN" || name == "/MESG_QUICKCONN_ACK",
           !quickConnectMediaFieldKeys.isSubset(of: fields.keys) {
            throw LoLaControlDatagramDecodingError(category: .missingRequiredFields)
        }
        if let text = fields["TXT"] {
            fields["TXT"] = unescapeText(text)
        }
        return (name, fields)
    }

    private static let supportedMessageNames: Set<String> = [
        "/MESG_CHECKLOLASTATUS",
        "/MESG_CHECKLOLASTATUS_ACK",
        "/MESG_QUICKCONN",
        "/MESG_QUICKCONN_ACK",
        "/MESG_REJECT",
        "/MESG_DISCONNECT",
        "/MESG_SWITCH_ON_BB",
        "/MESG_SWITCH_OFF_BB",
        "/MESG_CHAT",
        "/MESG_SEND_AUDIO_SIGNAL",
        "/MESG_STOP_AUDIO_SIGNAL"
    ]

    private static let quickConnectMediaFieldKeys: Set<String> = [
        "SR", "BPS", "CHNLS", "FPS", "BPP", "X", "Y", "COMP", "BAYER"
    ]

    private static func mediaFields(_ media: LoLaCompatibilityMediaFields) -> [(String, String)] {
        [
            ("SRCIP", media.session.sourceIP),
            ("DSTIP", media.session.destinationIP),
            ("SID", String(media.session.sessionID)),
            ("SR", String(media.audio.sampleRateHertz)),
            ("BPS", String(media.audio.bitsPerSample)),
            ("CHNLS", String(media.audio.channels)),
            ("FPS", String(media.video.frameRate)),
            ("BPP", String(media.video.bitsPerPixel)),
            ("X", String(media.video.dimensions.width)),
            ("Y", String(media.video.dimensions.height)),
            ("COMP", String(media.video.compression)),
            ("BAYER", String(media.video.bayer))
        ]
    }

    private static func commonFields(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int
    ) -> [(String, String)] {
        [
            ("SRCIP", sourceIP),
            ("DSTIP", destinationIP),
            ("SID", String(sessionID))
        ]
    }

    private static func encode(
        name: String,
        fields: [(String, String)],
        hasTrailingSemicolon: Bool
    ) -> String {
        let message = ([name] + fields.map { key, value in
            let encodedValue = key == "TXT" ? escapeText(value) : value
            return "\(key):\(encodedValue)"
        }).joined(separator: ";")
        return hasTrailingSemicolon ? message + ";" : message
    }

    private static func canonicalSessionID(_ value: String?) -> String? {
        guard let value, !value.isEmpty else {
            return nil
        }
        let isNegative = value.first == "-"
        let unsigned = value.first == "+" || isNegative ? value.dropFirst() : value[...]
        guard !unsigned.isEmpty, unsigned.allSatisfy({ $0 >= "0" && $0 <= "9" }) else {
            return nil
        }
        let digits = unsigned.drop(while: { $0 == "0" })
        let canonicalDigits = digits.isEmpty ? "0" : String(digits)
        return isNegative && canonicalDigits != "0" ? "-\(canonicalDigits)" : canonicalDigits
    }

    private static func escapeText(_ value: String) -> String {
        value.replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: ";", with: "%3B")
            .replacingOccurrences(of: ":", with: "%3A")
    }

    private static func unescapeText(_ value: String) -> String {
        var decoded = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] == "%" {
                let first = value.index(index, offsetBy: 1, limitedBy: value.endIndex)
                let second = first.flatMap { value.index($0, offsetBy: 1, limitedBy: value.endIndex) }
                if let first, let second, second < value.endIndex {
                    switch String(value[first...second]).uppercased() {
                    case "25":
                        decoded.append("%")
                    case "3B":
                        decoded.append(";")
                    case "3A":
                        decoded.append(":")
                    default:
                        decoded.append(contentsOf: value[index...second])
                    }
                    index = value.index(after: second)
                    continue
                }
            }
            decoded.append(value[index])
            index = value.index(after: index)
        }
        return decoded
    }
}

/// Normalized LoLa 2.0 compatibility-corpus outcomes emitted by production codecs.
public enum LoLaCompatibilityCorpusCategory: String, Equatable, Sendable {
    case accept
    case invalidSID = "reject.invalid_sid"
    case duplicateField = "reject.duplicate_field"
    case missingRequiredFields = "reject.missing_required_fields"
    case txtOrder = "reject.txt_order"
    case nonASCII = "reject.non_ascii"
    case oversize = "reject.oversize"
    case serializedLength = "reject.serialized_length"
    case malformed = "reject.malformed"
}

/// Preserves a machine-readable control rejection while keeping parser callers on `Error`.
public struct LoLaControlDatagramDecodingError: Error, Equatable, Sendable {
    public let category: LoLaCompatibilityCorpusCategory

    public init(category: LoLaCompatibilityCorpusCategory) {
        self.category = category
    }
}

/// Decodes inbound fixed-width LoLa control datagrams before any string-based control handling.
public enum LoLaControlDatagramDecoder {
    public static func decode<Bytes: Collection>(_ datagram: Bytes) throws -> (name: String, fields: [String: String]) where Bytes.Element == UInt8 {
        let bytes = Array(datagram)
        guard bytes.count <= lolaControlDatagramByteCount else {
            throw LoLaControlDatagramDecodingError(category: .oversize)
        }
        let textBytes = bytes.prefix { $0 != 0 }
        guard textBytes.allSatisfy({ $0 <= 0x7f }) else {
            throw LoLaControlDatagramDecodingError(category: .nonASCII)
        }
        let message = String(decoding: textBytes, as: UTF8.self)
        return try LoLaCompatibilityControlMessage.parseASCIIControlMessage(message)
    }
}
