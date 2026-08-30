// Plans and performs overflow-checked channel byte copies so malformed buffer geometry cannot escape into realtime memory operations.
import Foundation

enum DirectPeerAudioChannelCopyPlanValidation {
    case valid(DirectPeerAudioChannelCopyPlan)
    case invalidByteOffset
    case sourceBufferTooSmall
    case destinationBufferTooSmall
}

struct DirectPeerAudioChannelCopyPlan {
    var sourceBaseOffset: Int
    var sourceFrameStride: Int
    var destinationBaseOffset: Int
    var destinationFrameStride: Int
}

struct DirectPeerAudioChannelCopyEndpoint {
    var channel: Int
    var channelCount: Int
    var byteCount: Int
}

struct DirectPeerAudioChannelCopyPlanRequest {
    var source: DirectPeerAudioChannelCopyEndpoint
    var destination: DirectPeerAudioChannelCopyEndpoint
    var bytesPerSample: Int
    var frameCount: Int
}

func audioChannelCopyPlan(request: DirectPeerAudioChannelCopyPlanRequest) -> DirectPeerAudioChannelCopyPlanValidation {
    guard request.source.channel >= 0,
          request.source.channel < request.source.channelCount,
          request.destination.channel >= 0,
          request.destination.channel < request.destination.channelCount,
          request.bytesPerSample > 0,
          request.frameCount > 0,
          let sourceFrameStride = checkedAudioByteOffsetProduct(
            request.source.channelCount,
            request.bytesPerSample
          ),
          let destinationFrameStride = checkedAudioByteOffsetProduct(
            request.destination.channelCount,
            request.bytesPerSample
          ),
          let sourceBaseOffset = checkedAudioByteOffsetProduct(request.source.channel, request.bytesPerSample),
          let destinationBaseOffset = checkedAudioByteOffsetProduct(
            request.destination.channel,
            request.bytesPerSample
          ),
          let maxFrameIndex = checkedAudioByteOffsetDifference(request.frameCount, 1),
          let sourceLastFrameOffset = checkedAudioByteOffsetProduct(maxFrameIndex, sourceFrameStride),
          let destinationLastFrameOffset = checkedAudioByteOffsetProduct(maxFrameIndex, destinationFrameStride),
          let sourceLastOffset = checkedAudioByteOffsetSum(sourceBaseOffset, sourceLastFrameOffset),
          let destinationLastOffset = checkedAudioByteOffsetSum(destinationBaseOffset, destinationLastFrameOffset),
          let sourceEndOffset = checkedAudioByteOffsetSum(sourceLastOffset, request.bytesPerSample),
          let destinationEndOffset = checkedAudioByteOffsetSum(
            destinationLastOffset,
            request.bytesPerSample
          ) else {
        return .invalidByteOffset
    }
    guard sourceEndOffset <= request.source.byteCount else {
        return .sourceBufferTooSmall
    }
    guard destinationEndOffset <= request.destination.byteCount else {
        return .destinationBufferTooSmall
    }
    return .valid(DirectPeerAudioChannelCopyPlan(
        sourceBaseOffset: sourceBaseOffset,
        sourceFrameStride: sourceFrameStride,
        destinationBaseOffset: destinationBaseOffset,
        destinationFrameStride: destinationFrameStride
    ))
}

func copyAudioChannelBytes(
    source: UnsafeRawPointer,
    destination: UnsafeMutableRawPointer,
    plan: DirectPeerAudioChannelCopyPlan,
    bytesPerSample: Int,
    frameCount: Int
) {
    var sourceOffset = plan.sourceBaseOffset
    var destinationOffset = plan.destinationBaseOffset
    for _ in 0..<frameCount {
        memcpy(
            destination.advanced(by: destinationOffset),
            source.advanced(by: sourceOffset),
            bytesPerSample
        )
        sourceOffset += plan.sourceFrameStride
        destinationOffset += plan.destinationFrameStride
    }
}

private func checkedAudioByteOffsetProduct(_ lhs: Int, _ rhs: Int) -> Int? {
    let result = lhs.multipliedReportingOverflow(by: rhs)
    return result.overflow ? nil : result.partialValue
}

private func checkedAudioByteOffsetSum(_ lhs: Int, _ rhs: Int) -> Int? {
    let result = lhs.addingReportingOverflow(rhs)
    return result.overflow ? nil : result.partialValue
}

private func checkedAudioByteOffsetDifference(_ lhs: Int, _ rhs: Int) -> Int? {
    let result = lhs.subtractingReportingOverflow(rhs)
    return result.overflow ? nil : result.partialValue
}
