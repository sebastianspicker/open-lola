@_exported import OpenLolaContracts
@_exported import OpenLolaEvidenceModels
@_exported import OpenLolaSessionDomain
@_exported import OpenLolaTransport

// The MediaPlatform target owns adapters and runtimes, while these lower wire
// values remain defined in their compiler-enforced targets.
public typealias VideoCaptureStreamMetadata = OpenLolaTransport.VideoCaptureStreamMetadata
public typealias CapturedVideoFrame = OpenLolaTransport.CapturedVideoFrame
public typealias RawCapturedVideoFrame = OpenLolaTransport.RawCapturedVideoFrame
public typealias VideoTransportPacket = OpenLolaTransport.VideoTransportPacket
public typealias VideoTransportFragment = OpenLolaTransport.VideoTransportFragment
public typealias VideoTransportFragmentFields = OpenLolaTransport.VideoTransportFragmentFields
public typealias VideoTransportFragmentError = OpenLolaTransport.VideoTransportFragmentError
public typealias RawVideoFrameTransport = OpenLolaTransport.RawVideoFrameTransport
