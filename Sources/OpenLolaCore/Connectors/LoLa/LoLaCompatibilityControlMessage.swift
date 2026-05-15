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

    public static func quickConnect(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int,
        sampleRateHertz: Int,
        bitsPerSample: Int,
        channels: Int,
        videoFrameRate: Int = 0,
        videoBitsPerPixel: Int = 0,
        videoWidth: Int = 0,
        videoHeight: Int = 0,
        videoCompression: Int = 0,
        videoBayer: Int = 0
    ) -> String {
        encode(
            name: "/MESG_QUICKCONN",
            fields: mediaFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID,
                sampleRateHertz: sampleRateHertz,
                bitsPerSample: bitsPerSample,
                channels: channels,
                videoFrameRate: videoFrameRate,
                videoBitsPerPixel: videoBitsPerPixel,
                videoWidth: videoWidth,
                videoHeight: videoHeight,
                videoCompression: videoCompression,
                videoBayer: videoBayer
            ),
            hasTrailingSemicolon: false
        )
    }

    public static func quickConnectAck(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int,
        sampleRateHertz: Int,
        bitsPerSample: Int,
        channels: Int,
        videoFrameRate: Int = 0,
        videoBitsPerPixel: Int = 0,
        videoWidth: Int = 0,
        videoHeight: Int = 0,
        videoCompression: Int = 0,
        videoBayer: Int = 0
    ) -> String {
        encode(
            name: "/MESG_QUICKCONN_ACK",
            fields: mediaFields(
                sourceIP: sourceIP,
                destinationIP: destinationIP,
                sessionID: sessionID,
                sampleRateHertz: sampleRateHertz,
                bitsPerSample: bitsPerSample,
                channels: channels,
                videoFrameRate: videoFrameRate,
                videoBitsPerPixel: videoBitsPerPixel,
                videoWidth: videoWidth,
                videoHeight: videoHeight,
                videoCompression: videoCompression,
                videoBayer: videoBayer
            ),
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

    private static func mediaFields(
        sourceIP: String,
        destinationIP: String,
        sessionID: Int,
        sampleRateHertz: Int,
        bitsPerSample: Int,
        channels: Int,
        videoFrameRate: Int,
        videoBitsPerPixel: Int,
        videoWidth: Int,
        videoHeight: Int,
        videoCompression: Int,
        videoBayer: Int
    ) -> [(String, String)] {
        [
            ("SRCIP", sourceIP),
            ("DSTIP", destinationIP),
            ("SID", String(sessionID)),
            ("SR", String(sampleRateHertz)),
            ("BPS", String(bitsPerSample)),
            ("CHNLS", String(channels)),
            ("FPS", String(videoFrameRate)),
            ("BPP", String(videoBitsPerPixel)),
            ("X", String(videoWidth)),
            ("Y", String(videoHeight)),
            ("COMP", String(videoCompression)),
            ("BAYER", String(videoBayer)),
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
