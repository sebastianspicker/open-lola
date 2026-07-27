// Keeps UltraGrid packet generation state grouped without changing packet ordering or pacing rules.
import Foundation

struct UltraGridDatagramGenerationContext {
    let configuration: ExternalConnectorSessionConfiguration
    let mediaProvider: any UltraGridMediaProviding
    let deadline: UltraGridRuntimeDeadline?
    let clock: (any UltraGridMonotonicClock)?
    let profile: ExternalConnectorMediaProfile
    let encryption: UltraGridEncryptionConfiguration?

    func generate(emit: (UltraGridCompatibilityDatagram) throws -> Void) throws {
        if let clock {
            var generator = UltraGridPacedDatagramGenerator(context: self, clock: clock)
            try generator.generate(emit: emit)
        }
        else { try generateUnpaced(emit: emit) }
    }

    private func generateUnpaced(emit: (UltraGridCompatibilityDatagram) throws -> Void) throws {
        var nextVideoSequenceNumber: UInt16 = 0
        for packetIndex in 0..<configuration.mediaPacketCount {
            try emitAudio(packetIndex: packetIndex, emit: emit)
            nextVideoSequenceNumber = try emitVideo(
                packetIndex: packetIndex, sequenceStart: nextVideoSequenceNumber, emit: emit
            )
        }
    }

    func emitAudio(
        packetIndex: Int,
        emit: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws {
        guard profile.audioEnabled else { return }
        try deadline?.check()
        try emit(try audioDatagram(packetIndex: packetIndex))
    }

    func audioDatagram(packetIndex: Int) throws -> UltraGridCompatibilityDatagram {
        try UltraGridCompatibilityDatagramBuilder.audioDatagram(
            packetIndex: packetIndex, configuration: configuration, mediaProvider: mediaProvider,
            encryption: encryption, deadlineNanoseconds: deadline?.deadlineNanoseconds
        )
    }

    func emitVideo(
        packetIndex: Int,
        sequenceStart: UInt16,
        slotExpiresNanoseconds: UInt64? = nil,
        clock: (any UltraGridMonotonicClock)? = nil,
        emit: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws -> UInt16 {
        guard profile.videoEnabled else { return sequenceStart }
        try deadline?.check()
        let count = try UltraGridVideoDatagramGenerator(context: self).emit(
            packetIndex: packetIndex, sequenceStart: sequenceStart,
            slotExpiresNanoseconds: slotExpiresNanoseconds, clock: clock, emit: emit
        )
        return sequenceStart &+ UInt16(truncatingIfNeeded: count)
    }
}

private struct UltraGridPacedDatagramGenerator {
    let context: UltraGridDatagramGenerationContext
    let clock: any UltraGridMonotonicClock
    private let start: UInt64
    private let audioPeriod: UInt64
    private let videoPeriod: UInt64
    private var audioIndex: Int
    private var videoIndex: Int
    private var lastAudioEmission: UInt64?
    private var lastVideoEmission: UInt64?
    private var nextVideoSequenceNumber: UInt16 = 0

    init(context: UltraGridDatagramGenerationContext, clock: any UltraGridMonotonicClock) {
        self.context = context
        self.clock = clock
        start = clock.nowNanoseconds()
        audioPeriod = UltraGridCompatibilityDatagramBuilder.mediaPeriodNanoseconds(units: context.configuration.framesPerPacket, rate: context.configuration.sampleRateHertz)
        videoPeriod = UltraGridCompatibilityDatagramBuilder.mediaPeriodNanoseconds(units: 1, rate: context.configuration.videoFrameRate)
        audioIndex = context.profile.audioEnabled ? 0 : context.configuration.mediaPacketCount
        videoIndex = context.profile.videoEnabled ? 0 : context.configuration.mediaPacketCount
    }

    mutating func generate(emit: (UltraGridCompatibilityDatagram) throws -> Void) throws {
        while audioIndex < context.configuration.mediaPacketCount || videoIndex < context.configuration.mediaPacketCount {
            try emitNextDatagram(emit: emit)
        }
    }

    private mutating func emitNextDatagram(
        emit: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws {
        let now = clock.nowNanoseconds()
        advanceIndexes(now: now)
        let targets = scheduledTargets()
        try waitForTarget(targets.next, now: now)
        try context.deadline?.check()
        if targets.audio <= targets.video { try emitAudio(target: targets.audio, emit: emit) }
        else { try emitVideo(target: targets.video, emit: emit) }
    }

    private mutating func advanceIndexes(now: UInt64) {
        audioIndex = nextIndex(current: audioIndex, now: now, period: audioPeriod, lastEmission: lastAudioEmission)
        videoIndex = nextIndex(current: videoIndex, now: now, period: videoPeriod, lastEmission: lastVideoEmission)
    }

    private func nextIndex(current: Int, now: UInt64, period: UInt64, lastEmission: UInt64?) -> Int {
        UltraGridCompatibilityDatagramBuilder.pacedIndex(UltraGridPacedIndexRequest(
            current: current, count: context.configuration.mediaPacketCount, now: now,
            start: start, period: period, lastEmission: lastEmission
        ))
    }

    private func scheduledTargets() -> UltraGridPacedTargets {
        let audio = target(index: audioIndex, period: audioPeriod)
        let video = target(index: videoIndex, period: videoPeriod)
        return UltraGridPacedTargets(audio: audio, video: video)
    }

    private func target(index: Int, period: UInt64) -> UInt64 {
        index < context.configuration.mediaPacketCount
            ? UltraGridCompatibilityDatagramBuilder.slotTarget(index: index, start: start, period: period)
            : UInt64.max
    }

    private func waitForTarget(_ target: UInt64, now: UInt64) throws {
        guard target != UInt64.max, now < target else { return }
        if let deadline = context.deadline, target >= deadline.deadlineNanoseconds {
            try deadline.check()
            throw UltraGridCompatibilityError.receiveTimeout(expected: 0, actual: 0)
        }
        try clock.sleep(untilNanoseconds: target)
    }

    private mutating func emitAudio(
        target: UInt64,
        emit: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws {
        let packetIndex = audioIndex
        audioIndex += 1
        let datagram = try context.audioDatagram(packetIndex: packetIndex)
        guard clock.nowNanoseconds() < UltraGridCompatibilityDatagramBuilder.saturatedAdd(target, audioPeriod) else { return }
        let emission = clock.nowNanoseconds()
        try emit(datagram)
        lastAudioEmission = emission
    }

    private mutating func emitVideo(
        target: UInt64,
        emit: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws {
        let packetIndex = videoIndex
        videoIndex += 1
        let sequenceStart = nextVideoSequenceNumber
        nextVideoSequenceNumber = try context.emitVideo(
            packetIndex: packetIndex, sequenceStart: sequenceStart,
            slotExpiresNanoseconds: UltraGridCompatibilityDatagramBuilder.saturatedAdd(target, videoPeriod),
            clock: clock,
            emit: emit
        )
        if nextVideoSequenceNumber != sequenceStart { lastVideoEmission = clock.nowNanoseconds() }
    }
}

struct UltraGridPacedIndexRequest {
    let current: Int
    let count: Int
    let now: UInt64
    let start: UInt64
    let period: UInt64
    let lastEmission: UInt64?
}

private struct UltraGridPacedTargets {
    let audio: UInt64
    let video: UInt64

    var next: UInt64 { min(audio, video) }
}

private struct UltraGridVideoPacketRequest {
    let frame: Data
    let packetIndex: Int
    let sequenceStart: UInt16
    let fragmentIndex: Int
    let fragmentBytes: Int
    let fragmentCount: Int
}

private struct UltraGridVideoDatagramGenerator {
    let context: UltraGridDatagramGenerationContext

    func emit(
        packetIndex: Int,
        sequenceStart: UInt16,
        slotExpiresNanoseconds: UInt64?,
        clock: (any UltraGridMonotonicClock)?,
        emit: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws -> Int {
        let frame = try videoFrame(packetIndex: packetIndex)
        guard !slotHasExpired(slotExpiresNanoseconds, clock: clock) else { return 0 }
        let packets = try videoPackets(frame: frame, packetIndex: packetIndex, sequenceStart: sequenceStart)
        try self.emit(packets: packets, packetIndex: packetIndex, datagramEmitter: emit)
        return packets.count + (context.configuration.ultraGridFECMode == .singleParity ? 1 : 0)
    }

    private func videoFrame(packetIndex: Int) throws -> Data {
        try context.mediaProvider.videoFrame(
            frameID: packetIndex, width: context.configuration.videoWidth, height: context.configuration.videoHeight,
            bitsPerPixel: context.configuration.videoBitsPerPixel, deadlineNanoseconds: context.deadline?.deadlineNanoseconds
        )
    }

    private func slotHasExpired(_ expiry: UInt64?, clock: (any UltraGridMonotonicClock)?) -> Bool {
        guard let expiry, let clock else { return false }
        return clock.nowNanoseconds() >= expiry
    }

    private func videoPackets(frame: Data, packetIndex: Int, sequenceStart: UInt16) throws -> [RTPPacket] {
        let fragmentBytes = 1_200 - UltraGridVideoRawFragmentPayload.headerByteCount
        let fragmentCount = (frame.count + fragmentBytes - 1) / fragmentBytes
        return try (0..<fragmentCount).map { fragmentIndex in
            try videoPacket(UltraGridVideoPacketRequest(
                frame: frame, packetIndex: packetIndex, sequenceStart: sequenceStart,
                fragmentIndex: fragmentIndex, fragmentBytes: fragmentBytes, fragmentCount: fragmentCount
            ))
        }
    }

    private func videoPacket(_ request: UltraGridVideoPacketRequest) throws -> RTPPacket {
        let offset = request.fragmentIndex * request.fragmentBytes
        let end = min(request.frame.count, offset + request.fragmentBytes)
        let payload = try UltraGridVideoRawFragmentPayload(
            header: videoHeader(packetIndex: request.packetIndex, offset: offset, frameByteCount: request.frame.count),
            fragmentPayload: Data(request.frame[offset..<end])
        ).encoded()
        return RTPPacket(header: RTPPacketHeader(
            payloadType: context.configuration.ultraGridVideoPayloadType, marker: request.fragmentIndex == request.fragmentCount - 1,
            sequenceNumber: request.sequenceStart &+ UInt16(truncatingIfNeeded: request.fragmentIndex),
            timestamp: UltraGridCompatibilityDatagramBuilder.videoTimestamp(packetIndex: request.packetIndex, configuration: context.configuration),
            ssrc: 0x4F4C_5556
        ), payload: payload)
    }

    private func videoHeader(packetIndex: Int, offset: Int, frameByteCount: Int) throws -> UltraGridVideoPayloadHeader {
        UltraGridVideoPayloadHeader(
            bufferNumber: UInt32(packetIndex), payloadOffset: UInt32(offset), payloadByteCount: UInt32(frameByteCount),
            geometry: UltraGridVideoPayloadGeometry(
                width: try uint16(context.configuration.videoWidth, "video.width"),
                height: try uint16(context.configuration.videoHeight, "video.height"),
                fourCC: try ultraGridRawVideoFourCC(bitsPerPixel: context.configuration.videoBitsPerPixel)
            ),
            timing: UltraGridVideoPayloadTiming(frameRateNumerator: try uint16(context.configuration.videoFrameRate, "video.frameRate"))
        )
    }

    private func emit(
        packets: [RTPPacket],
        packetIndex: Int,
        datagramEmitter: (UltraGridCompatibilityDatagram) throws -> Void
    ) throws {
        for packet in packets {
            try context.deadline?.check()
            let transmitted = try context.encryption.map { try UltraGridCompatibility.encryptedVideoPacket(packet, configuration: $0) } ?? packet
            try datagramEmitter(UltraGridCompatibilityDatagram(stream: .video, destinationPort: context.configuration.videoPort, rtp: transmitted))
        }
        guard context.configuration.ultraGridFECMode == .singleParity else { return }
        try context.deadline?.check()
        try datagramEmitter(UltraGridCompatibilityDatagramBuilder.videoFECDatagram(
            packetIndex: packetIndex, packets: packets, configuration: context.configuration
        ))
    }
}
