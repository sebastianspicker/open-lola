#[cfg(target_os = "windows")]
use libloading::Library;
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
    let library = unsafe { Library::new("iphlpapi.dll") }
        .map_err(|error| format!("load iphlpapi.dll: {error}"))?;
    let send_arp: libloading::Symbol<SendArp> =
        unsafe { library.get(b"SendARP\0") }.map_err(|error| format!("bind SendARP: {error}"))?;
    let mut mac = [0u8; 8];
    let mut length = mac.len() as u32;
    let source = source.map_or(0, |ip| u32::from_be_bytes(ip.octets()));
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

#[cfg(any(target_os = "windows", test))]
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
    let library = unsafe { Library::new("iphlpapi.dll") }
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
    if frame.len() < 14 {
        return None;
    }
    let mut ip_start = 14;
    let mut ethertype = u16::from_be_bytes(frame[12..14].try_into().ok()?);
    let mut vlan_tag = None;
    if ethertype == ETHERTYPE_VLAN {
        if frame.len() < 18 {
            return None;
        }
        let tag_control = u16::from_be_bytes(frame[14..16].try_into().ok()?);
        let identifier = tag_control & 0x0fff;
        if !(1..=4_094).contains(&identifier) {
            return None;
        }
        vlan_tag = Some(identifier);
        ethertype = u16::from_be_bytes(frame[16..18].try_into().ok()?);
        ip_start = 18;
    }
    if ethertype != ETHERTYPE_IPV4 || frame.len() < ip_start + 28 {
        return None;
    }
    let version_ihl = frame[ip_start];
    if version_ihl >> 4 != 4 {
        return None;
    }
    let ihl = usize::from(version_ihl & 0x0f) * 4;
    if ihl < 20 || frame.len() < ip_start + ihl + 8 {
        return None;
    }
    let total_len = usize::from(u16::from_be_bytes(
        frame[ip_start + 2..ip_start + 4].try_into().ok()?,
    ));
    if total_len < ihl + 8 || frame.len() < ip_start + total_len {
        return None;
    }
    let fragment = u16::from_be_bytes(frame[ip_start + 6..ip_start + 8].try_into().ok()?);
    if fragment & 0x3fff != 0
        || frame[ip_start + 9] != IP_PROTOCOL_UDP
        || fold16(&frame[ip_start..ip_start + ihl]) != 0xffff
    {
        return None;
    }
    let udp_start = ip_start + ihl;
    let source_port = u16::from_be_bytes(frame[udp_start..udp_start + 2].try_into().ok()?);
    let destination_port = u16::from_be_bytes(frame[udp_start + 2..udp_start + 4].try_into().ok()?);
    let udp_len = usize::from(u16::from_be_bytes(
        frame[udp_start + 4..udp_start + 6].try_into().ok()?,
    ));
    if source_port == 0
        || destination_port == 0
        || udp_len < 8
        || udp_start + udp_len != ip_start + total_len
    {
        return None;
    }
    let source_ip = Ipv4Addr::new(
        frame[ip_start + 12],
        frame[ip_start + 13],
        frame[ip_start + 14],
        frame[ip_start + 15],
    );
    let destination_ip = Ipv4Addr::new(
        frame[ip_start + 16],
        frame[ip_start + 17],
        frame[ip_start + 18],
        frame[ip_start + 19],
    );
    let udp_checksum = u16::from_be_bytes(frame[udp_start + 6..udp_start + 8].try_into().ok()?);
    if udp_checksum != 0 {
        let mut pseudo = Vec::with_capacity(12 + udp_len);
        pseudo.extend_from_slice(&source_ip.octets());
        pseudo.extend_from_slice(&destination_ip.octets());
        pseudo.extend_from_slice(&[0, IP_PROTOCOL_UDP]);
        pseudo.extend_from_slice(&(udp_len as u16).to_be_bytes());
        pseudo.extend_from_slice(&frame[udp_start..udp_start + udp_len]);
        if fold16(&pseudo) != 0xffff {
            return None;
        }
    }
    Some(ParsedUdpPacket {
        source_mac: frame[6..12].try_into().ok()?,
        destination_mac: frame[..6].try_into().ok()?,
        vlan_tag,
        source_ip,
        destination_ip,
        source_port,
        destination_port,
        payload: frame[udp_start + 8..udp_start + udp_len].to_vec(),
    })
}
