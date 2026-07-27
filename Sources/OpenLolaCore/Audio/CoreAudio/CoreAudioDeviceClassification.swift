// Centralizes hardware identity matching used by audio route preflight and evidence validation.

func isCoreAudioRmeMadiDevice(_ device: CoreAudioDeviceInventory) -> Bool {
    let searchableIdentity = [device.name, device.uid, device.manufacturer ?? ""]
        .joined(separator: " ")
        .lowercased()
    return searchableIdentity.contains("rme") && searchableIdentity.contains("madi")
}
