use std::net::Ipv4Addr;

#[cfg(target_os = "windows")]
use std::ffi::CStr;

#[cfg(target_os = "windows")]
const MAX_ADAPTER_NAME_LENGTH: usize = 256;
#[cfg(target_os = "windows")]
const MAX_ADAPTER_DESCRIPTION_LENGTH: usize = 128;
#[cfg(target_os = "windows")]
const MAX_ADAPTER_ADDRESS_LENGTH: usize = 8;

#[cfg(target_os = "windows")]
#[repr(C)]
struct IpAddressString {
    value: [std::ffi::c_char; 16],
}

#[cfg(target_os = "windows")]
#[repr(C)]
struct IpAddrString {
    next: *mut IpAddrString,
    ip_address: IpAddressString,
    ip_mask: IpAddressString,
    context: u32,
}

#[cfg(target_os = "windows")]
#[repr(C)]
struct IpAdapterInfoPrefix {
    next: *mut IpAdapterInfoPrefix,
    combo_index: u32,
    adapter_name: [std::ffi::c_char; MAX_ADAPTER_NAME_LENGTH + 4],
    description: [std::ffi::c_char; MAX_ADAPTER_DESCRIPTION_LENGTH + 4],
    address_length: u32,
    address: [u8; MAX_ADAPTER_ADDRESS_LENGTH],
    index: u32,
    adapter_type: u32,
    dhcp_enabled: u32,
    current_ip_address: *mut IpAddrString,
    ip_address_list: IpAddrString,
}

#[cfg(target_os = "windows")]
type GetAdaptersInfo = unsafe extern "system" fn(*mut IpAdapterInfoPrefix, *mut u32) -> u32;

pub const ETHERTYPE_IPV4: u16 = 0x0800;
pub const ETHERTYPE_VLAN: u16 = 0x8100;
pub const IP_PROTOCOL_UDP: u8 = 17;
pub const MAX_UDP_PAYLOAD: usize = 65_507;

pub fn parse_mac_address(value: &str) -> Result<[u8; 6], String> {
    let parts: Vec<_> = value
        .replace('-', ":")
        .split(':')
        .map(str::to_owned)
        .collect();
    if parts.len() != 6 {
        return Err(format!("invalid MAC address: {value}"));
    }
    let mut result = [0; 6];
    for (index, part) in parts.iter().enumerate() {
        if part.len() != 2 {
            return Err(format!("invalid MAC address: {value}"));
        }
        result[index] =
            u8::from_str_radix(part, 16).map_err(|_| format!("invalid MAC address: {value}"))?;
    }
    Ok(result)
}

#[cfg(target_os = "windows")]
pub fn resolve_mac_via_ip_helper(
    target: Ipv4Addr,
    source: Option<Ipv4Addr>,
) -> Result<[u8; 6], String> {
    type SendArp = unsafe extern "system" fn(u32, u32, *mut std::ffi::c_void, *mut u32) -> u32;
    // SAFETY: iphlpapi is a Windows system DLL. The symbol type matches the
    // documented SendARP ABI, and all output storage remains live for the call.
    let library = unsafe {
        crate::native_loader::load(std::path::Path::new(r"C:\Windows\System32\iphlpapi.dll"))
    }
    .map_err(|error| format!("load iphlpapi.dll: {error}"))?;
    // SAFETY: the loaded symbol is retained only while `library` is live, and
    // the declared function type exactly matches the documented SendARP ABI.
    let send_arp: libloading::Symbol<SendArp> =
        unsafe { library.get(b"SendARP\0") }.map_err(|error| format!("bind SendARP: {error}"))?;
    let mut mac = [0u8; 8];
    let mut length = mac.len() as u32;
    let source = source.map_or(0, |ip| u32::from_be_bytes(ip.octets()));
    // SAFETY: `mac` and `length` provide live, writable storage for the call,
    // and both IPv4 addresses are passed in the byte order expected by SendARP.
    let status = unsafe {
        send_arp(
            u32::from_be_bytes(target.octets()),
            source,
            mac.as_mut_ptr().cast(),
            &mut length,
        )
    };
    if status != 0 || length < 6 {
        return Err(format!(
            "SendARP({target}) failed with status {status}, length {length}"
        ));
    }
    Ok(mac[..6].try_into().expect("checked MAC length"))
}

/// Resolves the physical address of the Windows adapter that owns `local_ip`.
///
/// When an Npcap device name is supplied, its adapter GUID must also match the
/// IP Helper adapter name. This prevents a valid local IP on one interface from
/// being paired with a different capture device.
#[cfg(target_os = "windows")]
pub fn resolve_local_mac_via_ip_helper(
    local_ip: Ipv4Addr,
    npcap_device: Option<&str>,
) -> Result<[u8; 6], String> {
    resolve_local_adapter(local_ip, npcap_device).map(|(mac, _)| mac)
}

/// Resolves the selected adapter and rejects peers outside its IPv4 subnet.
/// Npcap is intentionally unavailable for routed/WAN sessions.
#[cfg(target_os = "windows")]
pub fn resolve_direct_lan_mac_via_ip_helper(
    local_ip: Ipv4Addr,
    peer_ip: Ipv4Addr,
    npcap_device: Option<&str>,
) -> Result<[u8; 6], String> {
    let (mac, netmask) = resolve_local_adapter(local_ip, npcap_device)?;
    if !same_ipv4_subnet(local_ip, peer_ip, netmask) {
        return Err(format!(
            "Npcap peer {peer_ip} is routed outside local subnet {local_ip}/{netmask}; use UDP"
        ));
    }
    Ok(mac)
}

#[cfg(target_os = "windows")]
pub(super) fn same_ipv4_subnet(local: Ipv4Addr, peer: Ipv4Addr, mask: Ipv4Addr) -> bool {
    u32::from(local) & u32::from(mask) == u32::from(peer) & u32::from(mask)
}

#[cfg(target_os = "windows")]
fn resolve_local_adapter(
    local_ip: Ipv4Addr,
    npcap_device: Option<&str>,
) -> Result<([u8; 6], Ipv4Addr), String> {
    const ERROR_BUFFER_OVERFLOW: u32 = 111;

    // SAFETY: iphlpapi is a Windows system DLL and the symbol signature is the
    // documented GetAdaptersInfo ABI. The library outlives every call below.
    let library = unsafe {
        crate::native_loader::load(std::path::Path::new(r"C:\Windows\System32\iphlpapi.dll"))
    }
    .map_err(|error| format!("load iphlpapi.dll: {error}"))?;
    // SAFETY: the requested symbol and function pointer use the documented ABI.
    let get_adapters_info: libloading::Symbol<GetAdaptersInfo> =
        unsafe { library.get(b"GetAdaptersInfo\0") }
            .map_err(|error| format!("bind GetAdaptersInfo: {error}"))?;

    let mut bytes = 0u32;
    // SAFETY: a null first call is the documented size-query operation.
    let sizing = unsafe { get_adapters_info(std::ptr::null_mut(), &mut bytes) };
    if sizing != ERROR_BUFFER_OVERFLOW || bytes == 0 {
        return Err(format!(
            "GetAdaptersInfo size query failed with status {sizing}, length {bytes}"
        ));
    }
    let mut storage = vec![0u8; bytes as usize];
    // SAFETY: storage is writable for `bytes` bytes and remains live while all
    // API-owned linked-list pointers are traversed.
    let status = unsafe {
        get_adapters_info(
            storage.as_mut_ptr().cast::<IpAdapterInfoPrefix>(),
            &mut bytes,
        )
    };
    if status != 0 {
        return Err(format!(
            "GetAdaptersInfo failed with status {status}, length {bytes}"
        ));
    }

    let expected_ip = local_ip.to_string();
    let expected_device = npcap_device.map(normalize_adapter_name);
    let mut adapter = storage.as_ptr().cast::<IpAdapterInfoPrefix>();
    while !adapter.is_null() {
        // SAFETY: adapter points into the live API-filled linked-list buffer.
        let info = unsafe { &*adapter };
        // SAFETY: IP Helper guarantees NUL-terminated AdapterName and address strings.
        let name = unsafe { CStr::from_ptr(info.adapter_name.as_ptr()) }.to_string_lossy();
        let name_matches = expected_device
            .as_deref()
            .is_none_or(|expected| normalize_adapter_name(&name) == expected);
        let mut address = &info.ip_address_list as *const IpAddrString;
        while !address.is_null() {
            // SAFETY: address is the embedded list head or an API-owned next node.
            let entry = unsafe { &*address };
            // SAFETY: IP Helper guarantees the fixed address string is NUL-terminated.
            let ip = unsafe { CStr::from_ptr(entry.ip_address.value.as_ptr()) }.to_string_lossy();
            if name_matches && ip == expected_ip {
                if info.address_length != 6 {
                    return Err(format!(
                        "adapter {name} for {local_ip} has unsupported MAC length {}",
                        info.address_length
                    ));
                }
                // SAFETY: IP Helper guarantees the fixed mask string is NUL-terminated.
                let mask = unsafe { CStr::from_ptr(entry.ip_mask.value.as_ptr()) }
                    .to_string_lossy()
                    .parse::<Ipv4Addr>()
                    .map_err(|_| format!("adapter {name} returned an invalid IPv4 netmask"))?;
                return Ok((
                    info.address[..6].try_into().expect("checked MAC length"),
                    mask,
                ));
            }
            address = entry.next;
        }
        adapter = info.next;
    }
    let adapter_detail = npcap_device.map_or(String::new(), |device| format!(" on {device}"));
    Err(format!(
        "no Windows adapter{adapter_detail} owns local IPv4 address {local_ip}"
    ))
}

#[cfg(target_os = "windows")]
fn normalize_adapter_name(value: &str) -> String {
    value
        .rsplit(['\\', '/'])
        .next()
        .unwrap_or(value)
        .trim_start_matches("NPF_")
        .to_ascii_lowercase()
}

#[cfg(not(target_os = "windows"))]
pub fn resolve_mac_via_ip_helper(
    _target: Ipv4Addr,
    _source: Option<Ipv4Addr>,
) -> Result<[u8; 6], String> {
    Err("Windows IP Helper MAC resolution is unavailable on this platform".into())
}

#[cfg(not(target_os = "windows"))]
pub fn resolve_local_mac_via_ip_helper(
    _local_ip: Ipv4Addr,
    _npcap_device: Option<&str>,
) -> Result<[u8; 6], String> {
    Err("Windows IP Helper local-adapter resolution is unavailable on this platform".into())
}

#[cfg(not(target_os = "windows"))]
pub fn resolve_direct_lan_mac_via_ip_helper(
    _local_ip: Ipv4Addr,
    _peer_ip: Ipv4Addr,
    _npcap_device: Option<&str>,
) -> Result<[u8; 6], String> {
    Err("Windows IP Helper direct-LAN validation is unavailable on this platform".into())
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedUdpPacket {
    /// Ethernet source retained for receive-side L2 peer pinning.
    pub source_mac: [u8; 6],
    /// Ethernet destination retained for receive-side L2 peer pinning.
    pub destination_mac: [u8; 6],
    /// IEEE 802.1Q VLAN identifier, excluding priority and drop-eligible bits.
    pub vlan_tag: Option<u16>,
    pub source_ip: Ipv4Addr,
    pub destination_ip: Ipv4Addr,
    pub source_port: u16,
    pub destination_port: u16,
    pub payload: Vec<u8>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct BorrowedUdpPacket<'a> {
    pub(crate) source_mac: [u8; 6],
    pub(crate) destination_mac: [u8; 6],
    pub(crate) vlan_tag: Option<u16>,
    pub(crate) source_ip: Ipv4Addr,
    pub(crate) destination_ip: Ipv4Addr,
    pub(crate) source_port: u16,
    pub(crate) destination_port: u16,
    pub(crate) payload: &'a [u8],
}

impl BorrowedUdpPacket<'_> {
    fn to_owned(self) -> ParsedUdpPacket {
        ParsedUdpPacket {
            source_mac: self.source_mac,
            destination_mac: self.destination_mac,
            vlan_tag: self.vlan_tag,
            source_ip: self.source_ip,
            destination_ip: self.destination_ip,
            source_port: self.source_port,
            destination_port: self.destination_port,
            payload: self.payload.to_vec(),
        }
    }
}

#[derive(Debug)]
struct EthernetHeader {
    source_mac: [u8; 6],
    destination_mac: [u8; 6],
    vlan_tag: Option<u16>,
    ip_start: usize,
}

#[derive(Debug)]
struct Ipv4Header {
    start: usize,
    header_length: usize,
    total_length: usize,
    source_ip: Ipv4Addr,
    destination_ip: Ipv4Addr,
}

pub(super) fn fold16(data: &[u8]) -> u16 {
    let mut total = 0u32;
    for pair in data.chunks(2) {
        let word = if pair.len() == 2 {
            u16::from_be_bytes([pair[0], pair[1]])
        } else {
            u16::from_be_bytes([pair[0], 0])
        };
        total += u32::from(word);
        while total > 0xffff {
            total = (total & 0xffff) + (total >> 16);
        }
    }
    total as u16
}

pub fn internet_checksum(data: &[u8]) -> u16 {
    !fold16(data)
}

#[allow(clippy::too_many_arguments)]
pub fn build_ethernet_ipv4_udp_frame(
    source_mac: [u8; 6],
    destination_mac: [u8; 6],
    source_ip: Ipv4Addr,
    destination_ip: Ipv4Addr,
    source_port: u16,
    destination_port: u16,
    payload: &[u8],
    vlan_tag: Option<u16>,
) -> Result<Vec<u8>, String> {
    if source_port == 0 || destination_port == 0 {
        return Err("UDP ports must be in 1..=65535".into());
    }
    if payload.len() > MAX_UDP_PAYLOAD {
        return Err(format!("UDP payload exceeds {MAX_UDP_PAYLOAD} bytes"));
    }
    if vlan_tag.is_some_and(|tag| !(1..=4_094).contains(&tag)) {
        return Err("VLAN tag must be 1..=4094".into());
    }
    let udp_len = 8 + payload.len();
    let ip_len = 20 + udp_len;
    let mut frame = Vec::with_capacity(18 + ip_len);
    frame.extend_from_slice(&destination_mac);
    frame.extend_from_slice(&source_mac);
    if let Some(tag) = vlan_tag {
        frame.extend_from_slice(&ETHERTYPE_VLAN.to_be_bytes());
        frame.extend_from_slice(&tag.to_be_bytes());
    }
    frame.extend_from_slice(&ETHERTYPE_IPV4.to_be_bytes());
    let ip_start = frame.len();
    frame.extend_from_slice(&[
        0x45,
        0,
        (ip_len >> 8) as u8,
        ip_len as u8,
        0,
        0,
        0x40,
        0,
        64,
        IP_PROTOCOL_UDP,
        0,
        0,
    ]);
    frame.extend_from_slice(&source_ip.octets());
    frame.extend_from_slice(&destination_ip.octets());
    let ip_checksum = internet_checksum(&frame[ip_start..ip_start + 20]);
    frame[ip_start + 10..ip_start + 12].copy_from_slice(&ip_checksum.to_be_bytes());
    let udp_start = frame.len();
    frame.extend_from_slice(&source_port.to_be_bytes());
    frame.extend_from_slice(&destination_port.to_be_bytes());
    frame.extend_from_slice(&(udp_len as u16).to_be_bytes());
    frame.extend_from_slice(&[0, 0]);
    frame.extend_from_slice(payload);
    let mut pseudo = Vec::with_capacity(12 + udp_len + 1);
    pseudo.extend_from_slice(&source_ip.octets());
    pseudo.extend_from_slice(&destination_ip.octets());
    pseudo.extend_from_slice(&[0, IP_PROTOCOL_UDP]);
    pseudo.extend_from_slice(&(udp_len as u16).to_be_bytes());
    pseudo.extend_from_slice(&frame[udp_start..]);
    let checksum = internet_checksum(&pseudo);
    let checksum = if checksum == 0 { 0xffff } else { checksum };
    frame[udp_start + 6..udp_start + 8].copy_from_slice(&checksum.to_be_bytes());
    Ok(frame)
}

pub fn parse_ethernet_ipv4_udp_frame(frame: &[u8]) -> Option<ParsedUdpPacket> {
    parse_ethernet_ipv4_udp_frame_borrowed(frame).map(BorrowedUdpPacket::to_owned)
}

pub(crate) fn parse_ethernet_ipv4_udp_frame_borrowed(
    frame: &[u8],
) -> Option<BorrowedUdpPacket<'_>> {
    let ethernet = parse_ethernet_header(frame)?;
    let ip = parse_ipv4_udp_header(frame, ethernet.ip_start)?;
    let udp_start = ip.start + ip.header_length;
    let source_port = u16::from_be_bytes(frame[udp_start..udp_start + 2].try_into().ok()?);
    let destination_port = u16::from_be_bytes(frame[udp_start + 2..udp_start + 4].try_into().ok()?);
    let udp_len = usize::from(u16::from_be_bytes(
        frame[udp_start + 4..udp_start + 6].try_into().ok()?,
    ));
    if !valid_udp_shape(source_port, destination_port, udp_start, udp_len, &ip) {
        return None;
    }
    let udp_checksum = u16::from_be_bytes(frame[udp_start + 6..udp_start + 8].try_into().ok()?);
    if !valid_udp_checksum(frame, &ip, udp_start, udp_len, udp_checksum) {
        return None;
    }
    Some(BorrowedUdpPacket {
        source_mac: ethernet.source_mac,
        destination_mac: ethernet.destination_mac,
        vlan_tag: ethernet.vlan_tag,
        source_ip: ip.source_ip,
        destination_ip: ip.destination_ip,
        source_port,
        destination_port,
        payload: &frame[udp_start + 8..udp_start + udp_len],
    })
}

fn parse_ethernet_header(frame: &[u8]) -> Option<EthernetHeader> {
    if frame.len() < 14 {
        return None;
    }
    let destination_mac = frame[..6].try_into().ok()?;
    let source_mac = frame[6..12].try_into().ok()?;
    let ethertype = u16::from_be_bytes(frame[12..14].try_into().ok()?);
    if ethertype == ETHERTYPE_VLAN {
        return parse_vlan_ethernet_header(frame, source_mac, destination_mac);
    }
    (ethertype == ETHERTYPE_IPV4).then_some(EthernetHeader {
        source_mac,
        destination_mac,
        vlan_tag: None,
        ip_start: 14,
    })
}

fn parse_vlan_ethernet_header(
    frame: &[u8],
    source_mac: [u8; 6],
    destination_mac: [u8; 6],
) -> Option<EthernetHeader> {
    if frame.len() < 18 {
        return None;
    }
    let tag_control = u16::from_be_bytes(frame[14..16].try_into().ok()?);
    let vlan_tag = tag_control & 0x0fff;
    if !(1..=4_094).contains(&vlan_tag) {
        return None;
    }
    let ethertype = u16::from_be_bytes(frame[16..18].try_into().ok()?);
    (ethertype == ETHERTYPE_IPV4).then_some(EthernetHeader {
        source_mac,
        destination_mac,
        vlan_tag: Some(vlan_tag),
        ip_start: 18,
    })
}

fn parse_ipv4_udp_header(frame: &[u8], start: usize) -> Option<Ipv4Header> {
    if frame.len() < start + 28 {
        return None;
    }
    let version_ihl = frame[start];
    if version_ihl >> 4 != 4 {
        return None;
    }
    let header_length = usize::from(version_ihl & 0x0f) * 4;
    if header_length < 20 || frame.len() < start + header_length + 8 {
        return None;
    }
    let total_length = usize::from(u16::from_be_bytes(
        frame[start + 2..start + 4].try_into().ok()?,
    ));
    if total_length < header_length + 8 || frame.len() < start + total_length {
        return None;
    }
    let fragment = u16::from_be_bytes(frame[start + 6..start + 8].try_into().ok()?);
    if fragment & 0x3fff != 0
        || frame[start + 9] != IP_PROTOCOL_UDP
        || fold16(&frame[start..start + header_length]) != 0xffff
    {
        return None;
    }
    Some(Ipv4Header {
        start,
        header_length,
        total_length,
        source_ip: Ipv4Addr::new(
            frame[start + 12],
            frame[start + 13],
            frame[start + 14],
            frame[start + 15],
        ),
        destination_ip: Ipv4Addr::new(
            frame[start + 16],
            frame[start + 17],
            frame[start + 18],
            frame[start + 19],
        ),
    })
}

fn valid_udp_shape(
    source_port: u16,
    destination_port: u16,
    udp_start: usize,
    udp_length: usize,
    ip: &Ipv4Header,
) -> bool {
    source_port != 0
        && destination_port != 0
        && udp_length >= 8
        && udp_start + udp_length == ip.start + ip.total_length
}

fn valid_udp_checksum(
    frame: &[u8],
    ip: &Ipv4Header,
    udp_start: usize,
    udp_length: usize,
    checksum: u16,
) -> bool {
    if checksum == 0 {
        return true;
    }
    let mut pseudo_header = [0u8; 12];
    pseudo_header[..4].copy_from_slice(&ip.source_ip.octets());
    pseudo_header[4..8].copy_from_slice(&ip.destination_ip.octets());
    pseudo_header[9] = IP_PROTOCOL_UDP;
    pseudo_header[10..].copy_from_slice(&(udp_length as u16).to_be_bytes());
    let mut total = u32::from(fold16(&pseudo_header))
        + u32::from(fold16(&frame[udp_start..udp_start + udp_length]));
    while total > 0xffff {
        total = (total & 0xffff) + (total >> 16);
    }
    total == 0xffff
}

#[cfg(test)]
mod tests {
    use super::*;

    fn frame(vlan_tag: Option<u16>) -> Vec<u8> {
        build_ethernet_ipv4_udp_frame(
            [1, 2, 3, 4, 5, 6],
            [7, 8, 9, 10, 11, 12],
            Ipv4Addr::new(10, 0, 0, 1),
            Ipv4Addr::new(10, 0, 0, 2),
            7000,
            7001,
            &[1, 2, 3],
            vlan_tag,
        )
        .unwrap()
    }

    #[test]
    fn parser_preserves_vlan_layout_and_rejects_malformed_frames() {
        let valid = frame(Some(42));
        let borrowed = parse_ethernet_ipv4_udp_frame_borrowed(&valid).unwrap();
        assert_eq!(borrowed.payload, &[1, 2, 3]);
        let parsed = parse_ethernet_ipv4_udp_frame(&valid).unwrap();
        assert_eq!(parsed.vlan_tag, Some(42));
        assert_eq!(parsed.payload, vec![1, 2, 3]);

        assert!(parse_ethernet_ipv4_udp_frame(&valid[..17]).is_none());
        let mut invalid_checksum = valid;
        let ip_start = 18;
        invalid_checksum[ip_start + 10] ^= 1;
        assert!(parse_ethernet_ipv4_udp_frame(&invalid_checksum).is_none());
    }
}
