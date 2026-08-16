//! Npcap media plane with strict dynamic bindings and private RAII handles.

mod ffi;
mod packet;
mod plane;

pub use ffi::{load_pcap, probe_pcap, PcapLibrary, PcapProbe};
pub use packet::{
    build_ethernet_ipv4_udp_frame, internet_checksum, parse_ethernet_ipv4_udp_frame,
    parse_mac_address, resolve_direct_lan_mac_via_ip_helper, resolve_local_mac_via_ip_helper,
    resolve_mac_via_ip_helper, ParsedUdpPacket, ETHERTYPE_IPV4, ETHERTYPE_VLAN, IP_PROTOCOL_UDP,
    MAX_UDP_PAYLOAD,
};
pub use plane::RawMediaPlane;

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::Ipv4Addr;

    #[test]
    fn probe_uses_loadlibrary_not_path_only() {
        let p = probe_pcap(None);
        assert_eq!(p.transport, "udp");
        if p.available {
            assert!(p.loaded);
            let lib = load_pcap(p.library_path.as_deref()).expect("reload");
            let _ = lib.findalldevs();
        } else {
            assert!(!p.reason.is_empty());
        }
    }

    #[test]
    fn try_open_honest() {
        match RawMediaPlane::try_open(None) {
            Ok(plane) => {
                assert!(plane.is_open());
                assert!(!plane.device.is_empty());
            }
            Err(e) => assert!(!e.is_empty()),
        }
    }

    #[test]
    fn ethernet_ipv4_udp_roundtrip_with_checksum() {
        let payload = b"lola-media";
        let source_ip = Ipv4Addr::new(10, 0, 0, 1);
        let destination_ip = Ipv4Addr::new(10, 0, 0, 2);
        let frame = build_ethernet_ipv4_udp_frame(
            [0, 1, 2, 3, 4, 5],
            [6, 7, 8, 9, 10, 11],
            source_ip,
            destination_ip,
            19788,
            19788,
            payload,
            None,
        )
        .expect("frame");
        assert_eq!(packet::fold16(&frame[14..34]), 0xffff);
        assert_eq!(
            parse_ethernet_ipv4_udp_frame(&frame),
            Some(ParsedUdpPacket {
                source_mac: [0, 1, 2, 3, 4, 5],
                destination_mac: [6, 7, 8, 9, 10, 11],
                vlan_tag: None,
                source_ip,
                destination_ip,
                source_port: 19788,
                destination_port: 19788,
                payload: payload.to_vec()
            })
        );
    }

    #[test]
    fn vlan_parser_and_malformed_packets_are_bounded() {
        let mut frame = build_ethernet_ipv4_udp_frame(
            [0, 1, 2, 3, 4, 5],
            [6, 7, 8, 9, 10, 11],
            Ipv4Addr::LOCALHOST,
            Ipv4Addr::new(127, 0, 0, 2),
            19798,
            19798,
            b"video",
            Some(7),
        )
        .expect("vlan frame");
        let parsed = parse_ethernet_ipv4_udp_frame(&frame).unwrap();
        assert_eq!(parsed.payload, b"video");
        assert_eq!(parsed.vlan_tag, Some(7));
        frame[18] = 0x65;
        assert!(parse_ethernet_ipv4_udp_frame(&frame).is_none());
        assert!(parse_ethernet_ipv4_udp_frame(&[]).is_none());
    }

    #[test]
    fn raw_frame_builder_rejects_unrepresentable_payloads() {
        let error = build_ethernet_ipv4_udp_frame(
            [0; 6],
            [1; 6],
            Ipv4Addr::LOCALHOST,
            Ipv4Addr::LOCALHOST,
            0,
            19788,
            b"x",
            None,
        )
        .expect_err("zero port");
        assert!(error.contains("ports"));

        let error = build_ethernet_ipv4_udp_frame(
            [0; 6],
            [1; 6],
            Ipv4Addr::LOCALHOST,
            Ipv4Addr::LOCALHOST,
            19788,
            19788,
            b"x",
            Some(4095),
        )
        .expect_err("reserved VLAN identifier");
        assert!(error.contains("VLAN"));
    }

    #[test]
    fn parser_rejects_corrupt_nonzero_udp_checksum() {
        let mut frame = build_ethernet_ipv4_udp_frame(
            [0; 6],
            [1; 6],
            Ipv4Addr::new(192, 0, 2, 1),
            Ipv4Addr::new(192, 0, 2, 2),
            19788,
            19788,
            b"audio",
            None,
        )
        .unwrap();
        *frame.last_mut().unwrap() ^= 0xff;
        assert!(parse_ethernet_ipv4_udp_frame(&frame).is_none());
    }

    #[test]
    fn direct_lan_check_uses_the_selected_adapter_netmask() {
        let local = Ipv4Addr::new(10, 20, 30, 10);
        let mask = Ipv4Addr::new(255, 255, 255, 0);
        assert!(packet::same_ipv4_subnet(
            local,
            Ipv4Addr::new(10, 20, 30, 200),
            mask
        ));
        assert!(!packet::same_ipv4_subnet(
            local,
            Ipv4Addr::new(10, 20, 31, 1),
            mask
        ));
    }
}
