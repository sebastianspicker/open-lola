// Validates driver evidence and route assumptions for the fastest available RME MADI path.
import Foundation

func requireRmeFastestAudioPathNonEmpty(_ value: String, _ field: String) throws {
    try ValidationPrimitives.requireNonEmpty(value, field: field, error: RmeFastestAudioPathValidationError.self)
}

func requireRmeFastestAudioPathPositive(_ value: Int, _ field: String) throws {
    try ValidationPrimitives.requirePositive(value, field: field, error: RmeFastestAudioPathValidationError.self)
}

func isRmeFastestAudioPathMadiDevice(_ device: CoreAudioDeviceInventory) -> Bool {
    isCoreAudioRmeMadiDevice(device)
}

func isRmeFastestAudioPathMadiLoopback(_ report: EndpointLoopbackReport) -> Bool {
    let searchable = [
        report.hardware.audioInterface,
        report.device.name,
        report.device.uid
    ].joined(separator: " ").lowercased()
    return searchable.contains("rme") && searchable.contains("madi")
}

func isRmeFastestAudioPathPlaceholder(_ value: String) -> Bool {
    PlaceholderDetection.matches(
        value,
        containing: [PlaceholderDetection.manualEvidenceToken, "placeholder"],
        exactly: ["unknown", "tbd"]
    )
}
