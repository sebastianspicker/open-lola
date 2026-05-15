import Darwin
import Dispatch
import Foundation

private let oscCueMaximumUdpPayloadBytes = 65_507

func oscString(_ value: String) -> Data {
    var data = Data(value.utf8)
    data.append(0)
    while data.count % 4 != 0 {
        data.append(0)
    }
    return data
}

/// cursor must be absolute offset from byte 0 of the OSC message.
func readOscString(_ data: Data, cursor: inout Int) throws -> String {
    precondition(cursor >= 0)
    let bytes = [UInt8](data)
    guard cursor < bytes.count else {
        throw OscCuePacketError.missingNullTerminator
    }
    let start = cursor
    while cursor < bytes.count && bytes[cursor] != 0 {
        cursor += 1
    }
    guard cursor < bytes.count else {
        throw OscCuePacketError.missingNullTerminator
    }
    let value = String(decoding: bytes[start..<cursor], as: UTF8.self)
    cursor += 1
    while cursor % 4 != 0 {
        guard cursor < bytes.count else {
            throw OscCuePacketError.missingNullTerminator
        }
        cursor += 1
    }
    return value
}

func boundUdpPort(for socket: Int32) throws -> UInt16 {
    UInt16(bigEndian: try boundPort(socket))
}

func sendUdpPacket(_ packet: Data, socket: Int32, port: UInt16) throws {
    try sendDatagram(packet, socket: socket, host: "127.0.0.1", port: port.bigEndian)
}

func receiveUdpOscMessage(socket: Int32, timeoutMilliseconds: Int = 1_000) throws -> OscCueMessage {
    try waitForUdpOscRead(socket: socket, timeoutMilliseconds: timeoutMilliseconds)
    let data: Data
    do {
        data = try receiveDatagram(socket: socket, byteCount: oscCueMaximumUdpPayloadBytes)
    } catch UdpPcmRouteProbeError.receiveFailed(let errorCode) {
        throw OscCueError.receiveFailed(errorCode)
    }
    return try OscCueMessage.decodePacket(data)
}

private func waitForUdpOscRead(socket: Int32, timeoutMilliseconds: Int) throws {
    var readSet = fd_set()
    openLolaFDZero(&readSet)
    guard oscCueSocketDescriptorFitsFDSet(socket) else {
        throw OscCueError.receiveFailed(EBADF)
    }
    try openLolaFDSet(socket, set: &readSet)
    var timeout = timeval(
        tv_sec: max(0, timeoutMilliseconds) / 1_000,
        tv_usec: Int32((max(0, timeoutMilliseconds) % 1_000) * 1_000)
    )
    let ready = select(socket + 1, &readSet, nil, nil, &timeout)
    if ready == 0 {
        throw OscCueError.receiveFailed(ETIMEDOUT)
    }
    guard ready > 0 else {
        throw OscCueError.receiveFailed(errno)
    }
}

func oscCueSocketDescriptorFitsFDSet(_ descriptor: Int32) -> Bool {
    openLolaFileDescriptorFitsFDSet(descriptor)
}

func requireOscNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, empty: OscCueValidationError.emptyField)
}

func requireOscPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, nonPositive: OscCueValidationError.nonPositiveField)
}

func requireOscPositive(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requirePositive(
        value,
        field: field,
        nonPositive: OscCueValidationError.nonPositiveField,
        nonFinite: OscCueValidationError.nonFiniteField
    )
}

func requireOscNonNegative(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(value, field: field, negative: OscCueValidationError.negativeField)
}

func requireOscNonNegative(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireNonNegative(
        value,
        field: field,
        negative: OscCueValidationError.negativeField,
        nonFinite: OscCueValidationError.nonFiniteField
    )
}

func requireOscFinite(_ value: Double, _ field: String) throws {
    try ValidationPrimitives.requireFinite(value, field: field, nonFinite: OscCueValidationError.nonFiniteField)
}

func requireOscJitterMatch(_ field: String, _ expected: Double, _ actual: Double) throws {
    if abs(expected - actual) > 0.0001 {
        throw OscCueValidationError.jitterSummaryMismatch(
            field: field,
            expected: expected,
            actual: actual
        )
    }
}

func requiredOscExternalRunString(
    _ argument: String,
    _ values: [String: String]
) throws -> String {
    guard let value = values[argument], !value.isEmpty else {
        throw OscCueExternalRunConfigurationError.missingRequiredArgument(argument)
    }
    return value
}

func requiredOscExternalRunPositiveInteger(
    _ argument: String,
    _ values: [String: String]
) throws -> Int {
    let value = try requiredOscExternalRunString(argument, values)
    guard let integer = Int(value) else {
        throw OscCueExternalRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    guard integer > 0 else {
        throw OscCueExternalRunConfigurationError.nonPositiveArgument(argument)
    }
    return integer
}

func requiredOscExternalRunPort(
    _ argument: String,
    _ values: [String: String],
    allowZero: Bool
) throws -> UInt16 {
    let value = try requiredOscExternalRunString(argument, values)
    guard let integer = Int(value) else {
        throw OscCueExternalRunConfigurationError.invalidInteger(argument: argument, value: value)
    }
    let lowerBound = allowZero ? 0 : 1
    guard integer >= lowerBound && integer <= Int(UInt16.max) else {
        throw OscCueExternalRunConfigurationError.invalidPort(value)
    }
    return UInt16(integer)
}

func requiredOscExternalRunBoolean(
    _ argument: String,
    _ values: [String: String]
) throws -> Bool {
    let value = try requiredOscExternalRunString(argument, values)
    switch value.lowercased() {
    case "true", "yes", "1":
        return true
    case "false", "no", "0":
        return false
    default:
        throw OscCueExternalRunConfigurationError.invalidBoolean(argument: argument, value: value)
    }
}

func requiredOscExternalRunPeerKind(
    _ argument: String,
    _ values: [String: String]
) throws -> OscCuePeerKind {
    let value = try requiredOscExternalRunString(argument, values)
    guard let kind = OscCuePeerKind(rawValue: value), kind != .localLoopback else {
        throw OscCueExternalRunConfigurationError.invalidExternalPeerKind(value)
    }
    return kind
}
