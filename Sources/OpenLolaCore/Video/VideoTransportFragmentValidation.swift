// Validates VideoTransportFragmentValidation acceptance rules, keeping failure policy close to its contract rather than the runtime path.
import Foundation

extension VideoTransportFragment {
    public func validate() throws {
        let fingerprintByteCount = frameFingerprint.utf8.count
        let sourceRoleByteCount = sourceRole.rawValue.utf8.count
        let pixelFormatByteCount = pixelFormat.utf8.count
        try validateStreamMetadata(sourceRoleByteCount: sourceRoleByteCount)
        try validateGeometry(pixelFormatByteCount: pixelFormatByteCount)
        try validateTimingAndFingerprint(fingerprintByteCount: fingerprintByteCount)
        try validateFragmentPayload()
    }

    private func validateStreamMetadata(sourceRoleByteCount: Int) throws {
        guard streamID > 0 else {
            throw VideoTransportFragmentError.invalidStreamID(streamID)
        }
        guard sourceRole != .disabled else {
            throw VideoTransportFragmentError.invalidSourceRole(sourceRole.rawValue)
        }
        guard sourceRoleByteCount <= Int(UInt16.max) else {
            throw VideoTransportFragmentError.sourceRoleTooLarge(sourceRoleByteCount)
        }
    }

    private func validateGeometry(pixelFormatByteCount: Int) throws {
        guard width > 0 else {
            throw VideoTransportFragmentError.invalidFrameWidth(width)
        }
        guard width <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.frameWidthTooLarge(width)
        }
        guard height > 0 else {
            throw VideoTransportFragmentError.invalidFrameHeight(height)
        }
        guard height <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.frameHeightTooLarge(height)
        }
        guard !pixelFormat.isEmpty else {
            throw VideoTransportFragmentError.emptyPixelFormat
        }
        guard pixelFormatByteCount <= Int(UInt16.max) else {
            throw VideoTransportFragmentError.pixelFormatTooLarge(pixelFormatByteCount)
        }
    }

    private func validateTimingAndFingerprint(fingerprintByteCount: Int) throws {
        guard frameRate.numerator > 0,
              frameRate.denominator > 0 else {
            throw VideoTransportFragmentError.invalidFrameRate(
                numerator: frameRate.numerator,
                denominator: frameRate.denominator
            )
        }
        guard frameRate.numerator <= Int(UInt32.max),
              frameRate.denominator <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.frameRateTooLarge(
                numerator: frameRate.numerator,
                denominator: frameRate.denominator
            )
        }
        guard fingerprintByteCount > 0 else {
            throw VideoTransportFragmentError.emptyFrameFingerprint
        }
        guard fingerprintByteCount <= Int(UInt16.max) else {
            throw VideoTransportFragmentError.fingerprintTooLarge(fingerprintByteCount)
        }
    }

    private func validateFragmentPayload() throws {
        try validateFramePayloadBounds()
        try validateFragmentOrdinal()
        try validatePayloadBytes()
    }

    private func validateFramePayloadBounds() throws {
        guard framePayloadByteCount > 0 else {
            throw VideoTransportFragmentError.invalidFramePayloadByteCount(framePayloadByteCount)
        }
        guard framePayloadByteCount <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.framePayloadTooLarge(framePayloadByteCount)
        }
    }

    private func validateFragmentOrdinal() throws {
        guard fragmentCount > 0 else {
            throw VideoTransportFragmentError.invalidFragmentCount(fragmentCount)
        }
        guard fragmentIndex >= 0 && fragmentIndex < fragmentCount else {
            throw VideoTransportFragmentError.invalidFragmentIndex(
                index: fragmentIndex,
                count: fragmentCount
            )
        }
    }

    private func validatePayloadBytes() throws {
        guard payloadOffset >= 0 else {
            throw VideoTransportFragmentError.invalidPayloadOffset(payloadOffset)
        }
        guard payloadOffset <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.payloadOffsetTooLarge(payloadOffset)
        }
        guard !payload.isEmpty else {
            throw VideoTransportFragmentError.emptyPayload
        }
        guard payload.count <= Int(UInt32.max) else {
            throw VideoTransportFragmentError.fragmentPayloadTooLarge(payload.count)
        }
        guard payloadOffset + payload.count <= framePayloadByteCount else {
            throw VideoTransportFragmentError.payloadOutOfBounds(
                offset: payloadOffset,
                payloadBytes: payload.count,
                framePayloadBytes: framePayloadByteCount
            )
        }
    }
}
