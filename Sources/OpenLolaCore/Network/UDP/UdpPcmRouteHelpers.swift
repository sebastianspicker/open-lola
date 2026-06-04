import Darwin
import Dispatch
import Foundation

private let routeRunPositiveIntegerBounds: [String: Int] = [
    "--sample-rate": 384_000,
    "--frames": 4_096,
    "--channels": 256,
    "--duration-seconds": 86_400,
    "--link-rate-mbps": 1_000_000,
]

func makeProbePacket(sequenceNumber: UInt64, senderFrameIndex: UInt64) -> UdpPcmPacket {
    makeProbePacket(
        sequenceNumber: sequenceNumber,
        senderFrameIndex: senderFrameIndex,
        packetMode: UdpPcmPacketMode(
            sampleRateHertz: 48_000,
            framesPerPacket: 32,
            channelCount: 2,
            sampleFormat: .int16LittleEndian
        )
    )
}

func makeProbePacket(
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    packetMode: UdpPcmPacketMode
) -> UdpPcmPacket {
    UdpPcmPacket(
        header: UdpPcmPacketHeader(
            sequenceNumber: sequenceNumber,
            senderFrameIndex: senderFrameIndex,
            senderHostTimeNanoseconds: DispatchTime.now().uptimeNanoseconds,
            sampleRateHertz: UInt32(packetMode.sampleRateHertz),
            framesPerPacket: UInt32(packetMode.framesPerPacket),
            channelCount: UInt16(packetMode.channelCount),
            sampleFormat: packetMode.sampleFormat
        ),
        payload: Data(
            repeating: 0,
            count: packetMode.framesPerPacket
                * packetMode.channelCount
                * packetMode.sampleFormat.bytesPerSample
        )
    )
}

func requiredRouteRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    try KeyValueArgumentParser.requiredString(
        argument,
        values,
        missing: UdpPcmRouteRunConfigurationError.missingRequiredArgument
    )
}

func requiredRouteRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let number = try KeyValueArgumentParser.requiredPositiveInteger(
        argument,
        values,
        missing: UdpPcmRouteRunConfigurationError.missingRequiredArgument,
        invalid: { UdpPcmRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: UdpPcmRouteRunConfigurationError.nonPositiveArgument
    )
    try validateRouteRunPositiveIntegerBound(number, argument: argument)
    return number
}

func optionalRouteRunInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    try KeyValueArgumentParser.optionalInteger(
        argument,
        values,
        invalid: { UdpPcmRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) }
    )
}

func requiredRouteRunPort(_ values: [String: String]) throws -> UInt16 {
    let port = try requiredRouteRunPositiveInteger("--port", values)
    guard port <= Int(UInt16.max) else {
        throw UdpPcmRouteRunConfigurationError.invalidPort(port)
    }
    return UInt16(port)
}

func optionalRouteRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int? {
    let number = try KeyValueArgumentParser.optionalPositiveInteger(
        argument,
        values,
        invalid: { UdpPcmRouteRunConfigurationError.invalidInteger(argument: $0, value: $1) },
        nonPositive: UdpPcmRouteRunConfigurationError.nonPositiveArgument
    )
    if let number {
        try validateRouteRunPositiveIntegerBound(number, argument: argument)
    }
    return number
}

private func validateRouteRunPositiveIntegerBound(_ number: Int, argument: String) throws {
    guard let maximum = routeRunPositiveIntegerBounds[argument] else {
        return
    }
    guard number <= maximum else {
        throw UdpPcmRouteRunConfigurationError.invalidInteger(
            argument: argument,
            value: String(number)
        )
    }
}

func optionalRouteRunBoolean(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool? {
    guard let value = values[argument] else {
        return nil
    }
    return try KeyValueArgumentParser.boolean(
        value,
        argument: argument,
        invalid: { UdpPcmRouteRunConfigurationError.invalidBoolean(argument: $0, value: $1) }
    )
}

func optionalRouteKind(_ value: String?) throws -> UdpPcmRouteKind? {
    guard let value else {
        return nil
    }
    guard let routeKind = UdpPcmRouteKind(rawValue: value) else {
        throw UdpPcmRouteRunConfigurationError.invalidRouteKind(value)
    }
    return routeKind
}

func optionalDscpClassification(
    _ value: String?
) throws -> UdpPcmDscpClassification? {
    guard let value else {
        return nil
    }
    guard let classification = UdpPcmDscpClassification(rawValue: value) else {
        throw UdpPcmRouteRunConfigurationError.invalidDscpClassification(value)
    }
    return classification
}

func optionalVerdict(_ value: String?) throws -> MeasurementVerdict? {
    guard let value else {
        return nil
    }
    guard let verdict = MeasurementVerdict(rawValue: value) else {
        throw UdpPcmRouteRunConfigurationError.invalidVerdict(value)
    }
    return verdict
}

func defaultRouteLabel(for routeKind: UdpPcmRouteKind) -> String {
    switch routeKind {
    case .localhostSmoke:
        "localhost-continuous"
    case .directLink:
        "direct-link-continuous"
    case .dedicatedSwitch:
        "dedicated-switch-continuous"
    case .campusPath:
        "campus-path-continuous"
    }
}

func defaultRouteTopology(for routeKind: UdpPcmRouteKind) -> String {
    switch routeKind {
    case .localhostSmoke:
        "loopback-udp"
    case .directLink:
        "mac-to-mac-direct-cable"
    case .dedicatedSwitch:
        "mac-to-mac-dedicated-switch"
    case .campusPath:
        "campus-network-path"
    }
}

func defaultEndpointHostName(local: Bool) -> String {
    if local {
        return Host.current().localizedName ?? "localhost"
    }
    return "peer"
}

func defaultSenderEndpoint(
    role: UdpPcmRouteRunRole,
    bindHost: String,
    peer: String
) -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: "udp-pcm-sender",
        hostName: defaultEndpointHostName(local: role == .sender),
        interfaceName: "unknown",
        ipAddress: role == .sender ? bindHost : peer
    )
}

func defaultReceiverEndpoint(
    role: UdpPcmRouteRunRole,
    bindHost: String,
    peer: String
) -> UdpPcmRouteEndpoint {
    UdpPcmRouteEndpoint(
        label: "udp-pcm-receiver",
        hostName: defaultEndpointHostName(local: role == .receiver),
        interfaceName: "unknown",
        ipAddress: role == .receiver ? bindHost : peer
    )
}

func dscpObservation(_ configuration: UdpPcmRouteRunConfiguration) -> UdpPcmDscpObservation {
    UdpPcmDscpObservation(
        requested: configuration.dscp,
        observed: configuration.dscpObserved,
        classification: configuration.dscpClassification,
        notTestedReason: configuration.dscpClassification == .notTested
            ? configuration.dscpNotTestedReason
                ?? "continuous runner cannot observe DSCP without packet capture"
            : nil
    )
}

func defaultReceiverNotes(for configuration: UdpPcmRouteRunConfiguration) -> String {
    if configuration.verdict == .pass {
        return "Measured UDP PCM receiver report with fixed one-packet playout target, packet capture correlation, and DSCP classification."
    }
    return "Continuous receiver completed with a fixed playout target. M05 PASS still requires direct wired two-Mac packet capture correlation and DSCP classification."
}

func packetDurationSeconds(_ packetMode: UdpPcmPacketMode) -> Double {
    Double(packetMode.framesPerPacket) / Double(packetMode.sampleRateHertz)
}

func packetIntervalNanoseconds(_ packetMode: UdpPcmPacketMode) -> UInt64 {
    MediaClock.nanoseconds(
        forFrameCount: UInt64(packetMode.framesPerPacket),
        sampleRateHertz: packetMode.sampleRateHertz
    )
}

func playoutTargetMicroseconds(_ packetMode: UdpPcmPacketMode) -> Double {
    packetDurationSeconds(packetMode) * 1_000_000
}

func expectedPacketCount(durationSeconds: Int, packetMode: UdpPcmPacketMode) -> Int {
    max(
        1,
        (durationSeconds * packetMode.sampleRateHertz) / packetMode.framesPerPacket
    )
}

func routeDeadlineNanoseconds(durationSeconds: Int) throws -> UInt64 {
    guard durationSeconds > 0 else {
        throw UdpPcmRouteProbeError.receiveFailed(EINVAL)
    }
    let seconds = UInt64(durationSeconds)
    let duration = seconds.multipliedReportingOverflow(by: 1_000_000_000)
    guard !duration.overflow else {
        throw UdpPcmRouteProbeError.receiveFailed(EOVERFLOW)
    }
    let deadline = DispatchTime.now().uptimeNanoseconds.addingReportingOverflow(duration.partialValue)
    guard !deadline.overflow else {
        throw UdpPcmRouteProbeError.receiveFailed(EOVERFLOW)
    }
    return deadline.partialValue
}

func routeDeadlineNanoseconds(timeoutMicroseconds: UInt64) throws -> UInt64 {
    let duration = timeoutMicroseconds.multipliedReportingOverflow(by: 1_000)
    guard !duration.overflow else {
        throw UdpPcmRouteProbeError.receiveFailed(EOVERFLOW)
    }
    let deadline = DispatchTime.now().uptimeNanoseconds.addingReportingOverflow(duration.partialValue)
    guard !deadline.overflow else {
        throw UdpPcmRouteProbeError.receiveFailed(EOVERFLOW)
    }
    return deadline.partialValue
}

func nearlyEqualMicroseconds(_ lhs: Double, _ rhs: Double) -> Bool {
    abs(lhs - rhs) <= 1
}

func isDocumentationIPAddress(_ ipAddress: String) -> Bool {
    ipAddress.hasPrefix("192.0.2.")
        || ipAddress.hasPrefix("198.51.100.")
        || ipAddress.hasPrefix("203.0.113.")
}

func isRoutePlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder", "fixture", "synthetic"],
        exactly: ["unknown", "tbd"]
    )
}

func sleepUntilUptimeNanoseconds(_ deadline: UInt64) {
    let now = DispatchTime.now().uptimeNanoseconds
    guard deadline > now else {
        return
    }
    let delta = deadline - now
    sleepRouteMicroseconds(delta / 1_000)
}

func sleepRouteMicroseconds(_ microseconds: UInt64) {
    var remaining = microseconds
    while remaining > 0 {
        let chunk = min(remaining, UInt64(useconds_t.max))
        usleep(useconds_t(chunk))
        remaining -= chunk
    }
}

func inferredRouteKind(forPeer peer: String) -> UdpPcmRouteKind {
    if peer == "127.0.0.1" || peer == "localhost" {
        return .localhostSmoke
    }
    return .directLink
}

func packetAgeMetrics(for ages: [Double]) -> UdpPcmPacketAgeMetrics {
    let sortedAges = ages.sorted()
    return UdpPcmPacketAgeMetrics(
        p50Microseconds: percentile(sortedValues: sortedAges, rank: 0.50),
        p95Microseconds: percentile(sortedValues: sortedAges, rank: 0.95),
        p99Microseconds: percentile(sortedValues: sortedAges, rank: 0.99),
        maxMicroseconds: ages.max() ?? 0
    )
}

func jitterP99Microseconds(for ages: [Double]) -> Double {
    guard ages.count > 1 else {
        return 0
    }
    let sortedJitter = zip(ages.dropFirst(), ages).map { abs($0 - $1) }.sorted()
    return percentile(sortedValues: sortedJitter, rank: 0.99)
}

func percentile(_ values: [Double], rank: Double) -> Double {
    percentile(sortedValues: values.sorted(), rank: rank)
}

func percentile(sortedValues: [Double], rank: Double) -> Double {
    guard !sortedValues.isEmpty else {
        return 0
    }
    let index = Int((Double(sortedValues.count - 1) * rank).rounded(.up))
    return sortedValues[min(max(index, 0), sortedValues.count - 1)]
}

func requireRouteNonEmpty(_ value: String, _ field: String) throws {
    if value.isEmpty {
        throw UdpPcmRouteValidationError.emptyField(field)
    }
}

func requireRoutePositive(_ value: Int, _ field: String) throws {
    if value <= 0 {
        throw UdpPcmRouteValidationError.nonPositiveField(field)
    }
}

func requireRoutePositive(_ value: Double, _ field: String) throws {
    if value <= 0 {
        throw UdpPcmRouteValidationError.nonPositiveField(field)
    }
}

func requireRouteNonNegative(_ value: Int, _ field: String) throws {
    if value < 0 {
        throw UdpPcmRouteValidationError.negativeField(field)
    }
}

func requireRouteNonNegative(_ value: Double, _ field: String) throws {
    if value < 0 {
        throw UdpPcmRouteValidationError.negativeField(field)
    }
}

func requireDscpRange(_ value: Int) throws {
    if value < 0 || value > 63 {
        throw UdpPcmRouteValidationError.invalidDscpValue(value)
    }
}
