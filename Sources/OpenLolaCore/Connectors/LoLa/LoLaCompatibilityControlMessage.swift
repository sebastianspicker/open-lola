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

public struct LoLaCompatibilityVideoDimensions: Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

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
                ("SID", String(sessionID)),
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
                ("SID", String(sessionID)),
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
        let sanitizedMessage = message
            .split(separator: "\0", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? message
        let parts = sanitizedMessage.split(separator: ";", omittingEmptySubsequences: true).map(String.init)
        guard let name = parts.first, name.hasPrefix("/MESG_") else {
            throw ExternalConnectorSessionError.malformedLoLaControlMessage(message)
        }
        guard supportedMessageNames.contains(name) else {
            throw ExternalConnectorSessionError.malformedLoLaControlMessage(message)
        }
        var fields: [String: String] = [:]
        var index = 1
        while index < parts.count {
            let part = parts[index]
            let pair = part.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else {
                throw ExternalConnectorSessionError.malformedLoLaControlMessage(message)
            }
            let key = String(pair[0])
            if key == "TXT" {
                fields[key] = ([String(pair[1])] + parts[(index + 1)...]).joined(separator: ";")
                break
            }
            fields[key] = String(pair[1])
            index += 1
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
        "/MESG_STOP_AUDIO_SIGNAL",
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
            ("BAYER", String(media.video.bayer)),
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
            ("SID", String(sessionID)),
        ]
    }

    private static func encode(
        name: String,
        fields: [(String, String)],
        hasTrailingSemicolon: Bool
    ) -> String {
        let message = ([name] + fields.map { "\($0.0):\($0.1)" }).joined(separator: ";")
        return hasTrailingSemicolon ? message + ";" : message
    }
}
