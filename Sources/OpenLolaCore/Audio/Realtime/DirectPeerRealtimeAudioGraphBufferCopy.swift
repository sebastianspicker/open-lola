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

func audioChannelCopyPlan(
    sourceChannel: Int,
    sourceChannelCount: Int,
    sourceByteCount: Int,
    destinationChannel: Int,
    destinationChannelCount: Int,
    destinationByteCount: Int,
    bytesPerSample: Int,
    frameCount: Int
) -> DirectPeerAudioChannelCopyPlanValidation {
    guard sourceChannel >= 0,
          sourceChannel < sourceChannelCount,
          destinationChannel >= 0,
          destinationChannel < destinationChannelCount,
          bytesPerSample > 0,
          frameCount > 0,
          let sourceFrameStride = checkedAudioByteOffsetProduct(sourceChannelCount, bytesPerSample),
          let destinationFrameStride = checkedAudioByteOffsetProduct(destinationChannelCount, bytesPerSample),
          let sourceBaseOffset = checkedAudioByteOffsetProduct(sourceChannel, bytesPerSample),
          let destinationBaseOffset = checkedAudioByteOffsetProduct(destinationChannel, bytesPerSample),
          let maxFrameIndex = checkedAudioByteOffsetDifference(frameCount, 1),
          let sourceLastFrameOffset = checkedAudioByteOffsetProduct(maxFrameIndex, sourceFrameStride),
          let destinationLastFrameOffset = checkedAudioByteOffsetProduct(maxFrameIndex, destinationFrameStride),
          let sourceLastOffset = checkedAudioByteOffsetSum(sourceBaseOffset, sourceLastFrameOffset),
          let destinationLastOffset = checkedAudioByteOffsetSum(destinationBaseOffset, destinationLastFrameOffset),
          let sourceEndOffset = checkedAudioByteOffsetSum(sourceLastOffset, bytesPerSample),
          let destinationEndOffset = checkedAudioByteOffsetSum(destinationLastOffset, bytesPerSample) else {
        return .invalidByteOffset
    }
    guard sourceEndOffset <= sourceByteCount else {
        return .sourceBufferTooSmall
    }
    guard destinationEndOffset <= destinationByteCount else {
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
