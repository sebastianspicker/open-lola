// Builds deterministic LoLa Ethernet and UDP frames for compatibility test scenarios.
import Foundation

@testable import OpenLolaCore

func lolaCompatibilityTestWireFrame(
    payload: Data,
    sourcePort: UInt16,
    destinationPort: UInt16
) throws -> Data {
    try LoLaCompatibilityWireFrame(
        destinationMAC: LoLaEthernetAddress(octets: [0xff, 0xff, 0xff, 0xff, 0xff, 0xff]),
        sourceMAC: LoLaEthernetAddress(octets: [0x02, 0x4c, 0x6f, 0x4c, 0x61, 0x00]),
        sourceIP: LoLaIPv4Address(octets: [192, 0, 2, 20]),
        destinationIP: LoLaIPv4Address(octets: [192, 0, 2, 10]),
        sourcePort: sourcePort,
        destinationPort: destinationPort,
        payload: payload
    ).encoded()
}
