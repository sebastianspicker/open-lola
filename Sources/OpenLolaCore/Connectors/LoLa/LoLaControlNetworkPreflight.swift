import Darwin

func lolaControlNetworkPreflightNote(
    configuration: ExternalConnectorSessionConfiguration
) -> String? {
    guard configuration.connector == .lola,
          !configuration.localHost.isEmpty,
          configuration.localHost != "0.0.0.0",
          !isLoLaLoopbackAddress(configuration.localHost) else {
        return nil
    }
    guard !localIPv4Addresses().contains(configuration.localHost) else {
        return nil
    }
    return "Network preflight: advertised LoLa local host \(configuration.localHost) is not assigned to a local IPv4 interface. Official LoLa guidance requires a public IPv4 address with no NAT/firewall for reliable control and media replies."
}

func appendLoLaControlNetworkPreflightNote(
    _ notes: String,
    configuration: ExternalConnectorSessionConfiguration
) -> String {
    guard let preflight = lolaControlNetworkPreflightNote(configuration: configuration) else {
        return notes
    }
    return "\(notes) \(preflight)"
}

private func localIPv4Addresses() -> Set<String> {
    var addresses = Set<String>()
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0, let first = interfaces else {
        return addresses
    }
    defer { freeifaddrs(interfaces) }

    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let current = cursor {
        defer { cursor = current.pointee.ifa_next }
        guard let address = current.pointee.ifa_addr,
              lolaSockaddrCarriesIPv4(address) else {
            continue
        }
        let ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            $0.pointee.sin_addr
        }
        if let host = try? lolaInetNtopString(ipv4, failurePrefix: "interface inet_ntop") {
            addresses.insert(host)
        }
    }
    return addresses
}

func lolaSockaddrCarriesIPv4(_ address: UnsafePointer<sockaddr>) -> Bool {
    let length = Int(address.pointee.sa_len)
    return length >= MemoryLayout<sockaddr>.size &&
        length >= MemoryLayout<sockaddr_in>.size &&
        address.pointee.sa_family == UInt8(AF_INET)
}

private func isLoLaLoopbackAddress(_ host: String) -> Bool {
    var address = in_addr()
    guard inet_pton(AF_INET, host, &address) == 1 else {
        return false
    }
    return withUnsafeBytes(of: address.s_addr) { $0.first == 127 }
}
