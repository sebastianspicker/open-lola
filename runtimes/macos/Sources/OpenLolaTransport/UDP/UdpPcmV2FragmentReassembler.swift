import OpenLolaEvidenceModels
import OpenLolaSessionDomain
import OpenLolaContracts
// Defines the PCM v2 reassembly errors and result shared by the audio receive paths.
import Foundation

/// Enumerates failures that callers must handle when working with UDP media transport.
public enum UdpPcmV2FragmentReassemblyError: Error, Equatable, Sendable {
    case emptyFragments
    case inconsistentDeadline(String)
    case fragmentCountExceedsLimit(actual: UInt16, max: UInt16)
    case destinationBufferUnavailable
    case invalidFragmentPayload(index: UInt16)
}

/// Represents the UdpPcmV2ReassemblyResult produced by UDP media transport without exposing its execution state.
public struct UdpPcmV2ReassemblyResult: Equatable, Sendable {
    public var sequenceNumber: UInt64
    public var missingFragmentIndices: [UInt16]
    public var duplicateFragmentIndices: [UInt16]
    public var payload: Data?

    public var isComplete: Bool {
        missingFragmentIndices.isEmpty && payload != nil
    }

    public init(
        sequenceNumber: UInt64,
        missingFragmentIndices: [UInt16],
        duplicateFragmentIndices: [UInt16],
        payload: Data?
    ) {
        self.sequenceNumber = sequenceNumber
        self.missingFragmentIndices = missingFragmentIndices
        self.duplicateFragmentIndices = duplicateFragmentIndices
        self.payload = payload
    }
}
