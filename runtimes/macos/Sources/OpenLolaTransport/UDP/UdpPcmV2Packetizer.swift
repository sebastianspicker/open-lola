import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
// Defines UDP media packet, frame, or monitor values and conversion helpers so producers and consumers agree on their exchanged representation.
import Foundation

/// Splits one interleaved PCM deadline payload into validated UDP PCM v2 fragment packets.
public enum UdpPcmV2Packetizer {
  public static func silence(
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    senderHostTimeNanoseconds: UInt64,
    mode: AudioTransportMode
  ) throws -> [UdpPcmV2Packet] {
    try packetize(
      Data(repeating: 0, count: expectedDeadlinePayloadByteCount(mode)),
      sequenceNumber: sequenceNumber,
      senderFrameIndex: senderFrameIndex,
      senderHostTimeNanoseconds: senderHostTimeNanoseconds,
      mode: mode
    )
  }

  public static func packetize(
    _ payload: Data,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    senderHostTimeNanoseconds: UInt64,
    mode: AudioTransportMode
  ) throws -> [UdpPcmV2Packet] {
    try payload.withUnsafeBytes { payloadBytes in
      try packetize(
        payloadBytes,
        sequenceNumber: sequenceNumber,
        senderFrameIndex: senderFrameIndex,
        senderHostTimeNanoseconds: senderHostTimeNanoseconds,
        mode: mode
      )
    }
  }

  public static func packetize(
    _ payload: UnsafeRawBufferPointer,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    senderHostTimeNanoseconds: UInt64,
    mode: AudioTransportMode
  ) throws -> [UdpPcmV2Packet] {
    try validatePacketizeRequest(payload: payload, mode: mode)
    let context = UdpPcmV2PacketizeContext(
      sourceBytes: payload,
      sequenceNumber: sequenceNumber,
      senderFrameIndex: senderFrameIndex,
      senderHostTimeNanoseconds: senderHostTimeNanoseconds,
      mode: mode
    )
    return try mode.fragments.map { fragment in
      try packetizedFragment(fragment, context: context)
    }
  }

  package static func packetize(
    _ payload: UnsafeRawBufferPointer,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    senderHostTimeNanoseconds: UInt64,
    mode: AudioTransportMode,
    plan: UdpPcmV2ValidatedFragmentPlan
  ) throws -> [UdpPcmV2Packet] {
    guard mode == plan.mode else {
      throw UdpPcmV2PacketizerError.fragmentPlanMismatch("preparedMode")
    }
    return try packetize(
      payload, sequenceNumber: sequenceNumber, senderFrameIndex: senderFrameIndex,
      senderHostTimeNanoseconds: senderHostTimeNanoseconds, plan: plan
    )
  }

  package static func packetize(
    _ payload: UnsafeRawBufferPointer,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    senderHostTimeNanoseconds: UInt64,
    plan: UdpPcmV2ValidatedFragmentPlan
  ) throws -> [UdpPcmV2Packet] {
    try validatePacketizeRequest(payload: payload, mode: plan.mode)
    let context = UdpPcmV2PacketizeContext(
      sourceBytes: payload,
      sequenceNumber: sequenceNumber,
      senderFrameIndex: senderFrameIndex,
      senderHostTimeNanoseconds: senderHostTimeNanoseconds,
      mode: plan.mode
    )
    return try plan.fragments.map { fragment in
      try packetizedValidatedFragment(fragment, context: context)
    }
  }

  package static func validatePacketizeRequest(
    payload: UnsafeRawBufferPointer,
    mode: AudioTransportMode
  ) throws {
    guard mode.protocolVersion == .udpPcmV2 else {
      throw UdpPcmV2PacketizerError.invalidModeProtocol(mode.protocolVersion)
    }
    guard !mode.fragments.isEmpty else {
      throw UdpPcmV2PacketizerError.missingFragments
    }
    let expectedPayloadByteCount = expectedDeadlinePayloadByteCount(mode)
    guard payload.count == expectedPayloadByteCount,
      payload.baseAddress != nil
    else {
      throw UdpPcmV2PacketizerError.payloadLengthMismatch(
        expected: expectedPayloadByteCount,
        actual: payload.count
      )
    }
  }

  package static func encodePreparedMediaDatagram(
    _ payload: UnsafeRawBufferPointer,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    senderHostTimeNanoseconds: UInt64,
    fragment: UdpPcmV2ChannelFragmentPlan,
    mode: AudioTransportMode,
    into data: inout Data
  ) throws {
    guard senderHostTimeNanoseconds > 0 else {
      throw UdpPcmV2PacketError.invalidTimestamp(senderHostTimeNanoseconds)
    }
    let streamID = try uint32(fragment.streamID, field: "streamID")
    let nestedPayloadByteCount = fragment.payloadByteCount
    let nestedPacketByteCount = UdpPcmV2PacketHeader.byteCount + nestedPayloadByteCount
    guard nestedPacketByteCount <= mode.maxTransmissionUnitBytes else {
      throw UdpPcmV2PacketizerError.packetExceedsMtu(
        packetByteCount: nestedPacketByteCount,
        maxTransmissionUnitBytes: mode.maxTransmissionUnitBytes
      )
    }
    guard nestedPacketByteCount <= UdpMediaPacket.maxPayloadByteCount else {
      throw UdpMediaPacketError.payloadTooLarge(nestedPacketByteCount)
    }

    data.removeAll(keepingCapacity: true)
    data.reserveCapacity(UdpMediaPacketHeader.byteCount + nestedPacketByteCount)
    appendPreparedMediaHeader(
      payloadType: .audioPcmV2,
      streamID: streamID,
      sequenceNumber: sequenceNumber,
      timestampNanoseconds: senderHostTimeNanoseconds,
      payloadByteCount: nestedPacketByteCount,
      to: &data
    )
    data.append(contentsOf: UdpPcmV2PacketHeader.magic)
    data.append(UdpPcmV2PacketHeader.currentVersion)
    data.append(fragment.sampleFormat.rawValue)
    data.append(fragment.packingMode.wireValue)
    data.append(0)
    appendUdpPcmUInt32LE(streamID, to: &data)
    appendUdpPcmUInt64LE(sequenceNumber, to: &data)
    appendUdpPcmUInt64LE(senderFrameIndex, to: &data)
    appendUdpPcmUInt64LE(senderHostTimeNanoseconds, to: &data)
    appendUdpPcmUInt32LE(try uint32(fragment.sampleRateHertz, field: "sampleRateHertz"), to: &data)
    appendUdpPcmUInt32LE(try uint32(fragment.framesPerPacket, field: "framesPerPacket"), to: &data)
    appendUdpPcmUInt16LE(try uint16(fragment.totalChannelCount, field: "totalChannelCount"), to: &data)
    appendUdpPcmUInt16LE(try uint16(fragment.channelOffset, field: "channelOffset"), to: &data)
    appendUdpPcmUInt16LE(try uint16(fragment.channelsInFragment, field: "channelsInFragment"), to: &data)
    appendUdpPcmUInt16LE(try uint16(fragment.fragmentIndex, field: "fragmentIndex"), to: &data)
    appendUdpPcmUInt16LE(try uint16(fragment.fragmentCount, field: "fragmentCount"), to: &data)
    appendUdpPcmUInt16LE(0, to: &data)
    appendUdpPcmUInt32LE(try uint32(fragment.metadataRevision, field: "metadataRevision"), to: &data)
    appendUdpPcmUInt32LE(UInt32(nestedPayloadByteCount), to: &data)
    appendUdpPcmUInt32LE(UdpPcmV2PacketHeader.headerGuard, to: &data)
    data.append(contentsOf: repeatElement(0, count: UdpPcmV2PacketHeader.reservedPaddingByteCount))
    try appendPreparedFragmentPayload(
      payload,
      fragment: fragment,
      totalChannelCount: mode.channelCount,
      bytesPerSample: mode.sampleFormat.bytesPerSample,
      to: &data
    )
  }

  private static func packetizedFragment(
    _ fragment: UdpPcmV2ChannelFragmentPlan,
    context: UdpPcmV2PacketizeContext
  ) throws -> UdpPcmV2Packet {
    try validateFragmentPlan(fragment, mode: context.mode)
    return try packetizedValidatedFragment(fragment, context: context)
  }

  private static func packetizedValidatedFragment(
    _ fragment: UdpPcmV2ChannelFragmentPlan,
    context: UdpPcmV2PacketizeContext
  ) throws -> UdpPcmV2Packet {
    let fragmentPayload = try fragmentPayloadBytes(
      sourceBytes: context.sourceBytes,
      fragment: fragment,
      totalChannelCount: context.mode.channelCount,
      bytesPerSample: context.mode.sampleFormat.bytesPerSample
    )
    let packet = UdpPcmV2Packet(
      header: try packetHeader(
        fragment: fragment,
        sequenceNumber: context.sequenceNumber,
        senderFrameIndex: context.senderFrameIndex,
        senderHostTimeNanoseconds: context.senderHostTimeNanoseconds
      ),
      payload: fragmentPayload
    )
    try validatePacketSize(packet, maxTransmissionUnitBytes: context.mode.maxTransmissionUnitBytes)
    return packet
  }

  private static func packetHeader(
    fragment: UdpPcmV2ChannelFragmentPlan,
    sequenceNumber: UInt64,
    senderFrameIndex: UInt64,
    senderHostTimeNanoseconds: UInt64
  ) throws -> UdpPcmV2PacketHeader {
    UdpPcmV2PacketHeader(
      stream: .init(streamID: try uint32(fragment.streamID, field: "streamID")),
      timing: .init(
        sequenceNumber: sequenceNumber,
        senderFrameIndex: senderFrameIndex,
        senderHostTimeNanoseconds: senderHostTimeNanoseconds
      ),
      format: .init(
        sampleRateHertz: try uint32(fragment.sampleRateHertz, field: "sampleRateHertz"),
        framesPerPacket: try uint32(fragment.framesPerPacket, field: "framesPerPacket"),
        totalChannelCount: try uint16(fragment.totalChannelCount, field: "totalChannelCount"),
        sampleFormat: fragment.sampleFormat,
        metadataRevision: try uint32(fragment.metadataRevision, field: "metadataRevision"),
        packingMode: fragment.packingMode
      ),
      fragment: .init(
        channelOffset: try uint16(fragment.channelOffset, field: "channelOffset"),
        channelsInFragment: try uint16(fragment.channelsInFragment, field: "channelsInFragment"),
        fragmentIndex: try uint16(fragment.fragmentIndex, field: "fragmentIndex"),
        fragmentCount: try uint16(fragment.fragmentCount, field: "fragmentCount")
      )
    )
  }

  private static func validatePacketSize(
    _ packet: UdpPcmV2Packet,
    maxTransmissionUnitBytes: Int
  ) throws {
    guard packet.header.packetByteCount <= maxTransmissionUnitBytes else {
      throw UdpPcmV2PacketizerError.packetExceedsMtu(
        packetByteCount: packet.header.packetByteCount,
        maxTransmissionUnitBytes: maxTransmissionUnitBytes
      )
    }
  }

  private static func fragmentPayloadBytes(
    sourceBytes: UnsafeRawBufferPointer,
    fragment: UdpPcmV2ChannelFragmentPlan,
    totalChannelCount: Int,
    bytesPerSample: Int
  ) throws -> Data {
    let fragmentFrameByteCount = try checkedV2PacketizerProduct(
      fragment.channelsInFragment,
      bytesPerSample,
      field: "fragmentFrameByteCount"
    )
    var output = Data(count: fragment.payloadByteCount)
    try output.withUnsafeMutableBytes { destinationBytes in
      guard let sourceBaseAddress = sourceBytes.baseAddress,
        let destinationBaseAddress = destinationBytes.baseAddress
      else {
        throw UdpPcmV2PacketizerError.fragmentPlanMismatch("payloadBuffer")
      }
      for frame in 0..<fragment.framesPerPacket {
        let offsets = try fragmentPayloadCopyOffsets(
          frame: frame,
          fragment: fragment,
          totalChannelCount: totalChannelCount,
          bytesPerSample: bytesPerSample,
          fragmentFrameByteCount: fragmentFrameByteCount
        )
        guard offsets.sourceEnd <= sourceBytes.count,
          offsets.destinationEnd <= destinationBytes.count
        else {
          throw UdpPcmV2PacketizerError.fragmentPlanMismatch("fragmentPayloadBounds")
        }
        memcpy(
          destinationBaseAddress.advanced(by: offsets.destinationStart),
          sourceBaseAddress.advanced(by: offsets.sourceStart),
          fragmentFrameByteCount
        )
      }
    }
    return output
  }

  fileprivate static func fragmentPayloadCopyOffsets(
    frame: Int,
    fragment: UdpPcmV2ChannelFragmentPlan,
    totalChannelCount: Int,
    bytesPerSample: Int,
    fragmentFrameByteCount: Int
  ) throws -> UdpPcmV2FragmentPayloadCopyOffsets {
    let sourceFrameOffset = try checkedV2PacketizerProduct(
      frame,
      totalChannelCount,
      field: "sourceFrameOffset"
    )
    let sourceChannelOffset = try checkedV2PacketizerSum(
      sourceFrameOffset,
      fragment.channelOffset,
      field: "sourceChannelOffset"
    )
    let sourceStart = try checkedV2PacketizerProduct(
      sourceChannelOffset,
      bytesPerSample,
      field: "sourceStart"
    )
    let destinationStart = try checkedV2PacketizerProduct(
      frame,
      fragmentFrameByteCount,
      field: "destinationStart"
    )
    return try UdpPcmV2FragmentPayloadCopyOffsets(
      sourceStart: sourceStart,
      sourceEnd: checkedV2PacketizerSum(
        sourceStart,
        fragmentFrameByteCount,
        field: "sourceEnd"
      ),
      destinationStart: destinationStart,
      destinationEnd: checkedV2PacketizerSum(
        destinationStart,
        fragmentFrameByteCount,
        field: "destinationEnd"
      )
    )
  }

  static func validateFragmentPlan(
    _ fragment: UdpPcmV2ChannelFragmentPlan,
    mode: AudioTransportMode
  ) throws {
    guard fragment.totalChannelCount == mode.channelCount else {
      throw UdpPcmV2PacketizerError.fragmentPlanMismatch("totalChannelCount")
    }
    guard fragment.framesPerPacket == mode.framesPerPacket else {
      throw UdpPcmV2PacketizerError.fragmentPlanMismatch("framesPerPacket")
    }
    guard fragment.sampleRateHertz == mode.sampleRateHertz else {
      throw UdpPcmV2PacketizerError.fragmentPlanMismatch("sampleRateHertz")
    }
    guard fragment.sampleFormat == mode.sampleFormat else {
      throw UdpPcmV2PacketizerError.fragmentPlanMismatch("sampleFormat")
    }
    guard fragment.packetByteCount <= mode.maxTransmissionUnitBytes else {
      throw UdpPcmV2PacketizerError.packetExceedsMtu(
        packetByteCount: fragment.packetByteCount,
        maxTransmissionUnitBytes: mode.maxTransmissionUnitBytes
      )
    }
  }
}

package func appendPreparedMediaHeader(
  payloadType: SessionPayloadType,
  streamID: UInt32,
  sequenceNumber: UInt64,
  timestampNanoseconds: UInt64,
  payloadByteCount: Int,
  to data: inout Data
) {
  data.append(contentsOf: UdpMediaPacketHeader.magic)
  data.append(UdpMediaPacketHeader.currentVersion)
  data.append(UInt8(payloadType.rawValue))
  appendUdpPcmUInt16LE(0, to: &data)
  appendUdpPcmUInt32LE(streamID, to: &data)
  appendUdpPcmUInt64LE(sequenceNumber, to: &data)
  appendUdpPcmUInt64LE(timestampNanoseconds, to: &data)
  appendUdpPcmUInt32LE(UInt32(payloadByteCount), to: &data)
  appendUdpPcmUInt32LE(UdpMediaPacketHeader.headerGuard, to: &data)
}

private func appendPreparedFragmentPayload(
  _ source: UnsafeRawBufferPointer,
  fragment: UdpPcmV2ChannelFragmentPlan,
  totalChannelCount: Int,
  bytesPerSample: Int,
  to data: inout Data
) throws {
  let fragmentFrameByteCount = try checkedV2PacketizerProduct(
    fragment.channelsInFragment,
    bytesPerSample,
    field: "fragmentFrameByteCount"
  )
  guard let sourceBase = source.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
    throw UdpPcmV2PacketizerError.fragmentPlanMismatch("payloadBuffer")
  }
  let payloadStart = data.count
  data.append(contentsOf: repeatElement(0, count: fragment.payloadByteCount))
  var copyError: UdpPcmV2PacketizerError?
  data.withUnsafeMutableBytes { destination in
    guard let destinationBase = destination.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
      copyError = .fragmentPlanMismatch("payloadBuffer")
      return
    }
    for frame in 0..<fragment.framesPerPacket {
      do {
        let offsets = try UdpPcmV2Packetizer.fragmentPayloadCopyOffsets(
          frame: frame,
          fragment: fragment,
          totalChannelCount: totalChannelCount,
          bytesPerSample: bytesPerSample,
          fragmentFrameByteCount: fragmentFrameByteCount
        )
        guard offsets.sourceEnd <= source.count,
              payloadStart + offsets.destinationEnd <= destination.count else {
          copyError = .fragmentPlanMismatch("fragmentPayloadBounds")
          return
        }
        memcpy(
          destinationBase.advanced(by: payloadStart + offsets.destinationStart),
          sourceBase.advanced(by: offsets.sourceStart),
          fragmentFrameByteCount
        )
      } catch let error as UdpPcmV2PacketizerError {
        copyError = error
        return
      } catch {
        preconditionFailure("unexpected prepared fragment offset error: \(error)")
      }
    }
  }
  if let copyError {
    throw copyError
  }
}

private struct UdpPcmV2PacketizeContext {
  var sourceBytes: UnsafeRawBufferPointer
  var sequenceNumber: UInt64
  var senderFrameIndex: UInt64
  var senderHostTimeNanoseconds: UInt64
  var mode: AudioTransportMode
}

fileprivate struct UdpPcmV2FragmentPayloadCopyOffsets {
  var sourceStart: Int
  var sourceEnd: Int
  var destinationStart: Int
  var destinationEnd: Int
}

private func expectedDeadlinePayloadByteCount(_ mode: AudioTransportMode) -> Int {
  mode.payloadByteCount
}

func expectedV2PayloadByteCount(_ header: UdpPcmV2PacketHeader) -> Int {
  Int(header.framesPerPacket)
    * Int(header.channelsInFragment)
    * header.sampleFormat.bytesPerSample
}

private func uint16(_ value: Int, field: String) throws -> UInt16 {
  guard value >= 0, value <= Int(UInt16.max) else {
    throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
  }
  return UInt16(value)
}

private func uint32(_ value: Int, field: String) throws -> UInt32 {
  guard value >= 0, value <= Int(UInt32.max) else {
    throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
  }
  return UInt32(value)
}

private func checkedV2PacketizerProduct(_ lhs: Int, _ rhs: Int, field: String) throws -> Int {
  let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
  guard !overflow else {
    throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
  }
  return value
}

private func checkedV2PacketizerSum(_ lhs: Int, _ rhs: Int, field: String) throws -> Int {
  let (value, overflow) = lhs.addingReportingOverflow(rhs)
  guard !overflow else {
    throw UdpPcmV2PacketizerError.fragmentPlanMismatch(field)
  }
  return value
}

func readCheckedUdpPcmUInt16LE(_ bytes: [UInt8], offset: Int) throws -> UInt16 {
  guard udpPcmHasBytes(bytes, offset: offset, count: 2) else {
    throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
  }
  return NetworkByteReader.readUInt16LE(bytes, offset: offset)
}

func readCheckedUdpPcmUInt32LE(_ bytes: [UInt8], offset: Int) throws -> UInt32 {
  guard udpPcmHasBytes(bytes, offset: offset, count: 4) else {
    throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
  }
  return NetworkByteReader.readUInt32LE(bytes, offset: offset)
}

func readCheckedUdpPcmUInt64LE(_ bytes: [UInt8], offset: Int) throws -> UInt64 {
  guard udpPcmHasBytes(bytes, offset: offset, count: 8) else {
    throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
  }
  return NetworkByteReader.readUInt64LE(bytes, offset: offset)
}

func readCheckedUdpPcmUInt16LE(_ bytes: Data, offset: Int) throws -> UInt16 {
  guard udpPcmHasBytes(bytes, offset: offset, count: 2) else {
    throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
  }
  return readPrevalidatedUInt16LE(bytes, offset: offset)
}

func readCheckedUdpPcmUInt32LE(_ bytes: Data, offset: Int) throws -> UInt32 {
  guard udpPcmHasBytes(bytes, offset: offset, count: 4) else {
    throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
  }
  return readPrevalidatedUInt32LE(bytes, offset: offset)
}

func readCheckedUdpPcmUInt64LE(_ bytes: Data, offset: Int) throws -> UInt64 {
  guard udpPcmHasBytes(bytes, offset: offset, count: 8) else {
    throw UdpPcmV2PacketError.truncatedPacket(byteCount: bytes.count)
  }
  return NetworkByteReader.readUInt64LE(bytes, offset: offset)
}
