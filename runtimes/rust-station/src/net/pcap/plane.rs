use super::ffi::{load_pcap, pcap_lock, PcapLibrary};
use super::packet::{parse_ethernet_ipv4_udp_frame, ParsedUdpPacket};
use std::net::Ipv4Addr;
use std::path::PathBuf;
use std::ptr::NonNull;
use std::time::SystemTime;

/// Open raw plane: LoadLibrary + findalldevs + pcap_open_live (real use path).
pub struct RawMediaPlane {
    pub device: String,
    pub library_path: PathBuf,
    lib: PcapLibrary,
    handle: NonNull<std::ffi::c_void>,
    closed: bool,
}
impl Drop for RawMediaPlane {
    fn drop(&mut self) {
        self.close_handle();
    }
}
impl RawMediaPlane {
    /// Real probe-and-use: fails unless pcap_open_live returns a handle.
    pub fn try_open(device: Option<&str>) -> Result<Self, String> {
        let _g = pcap_lock().lock().unwrap_or_else(|e| e.into_inner());
        let lib = load_pcap(None)?;
        let devs = lib.findalldevs()?;
        if devs.is_empty() {
            return Err("pcap loaded but no capture devices".into());
        }
        let requested = device.filter(|name| !name.is_empty());
        let order = capture_device_order(devs, requested)?;
        let mut failures = Vec::new();
        for name in order {
            // The 1 ms timeout remains a defensive fallback for Npcap builds
            // whose nonblocking mode does not apply to every capture path.
            match lib.open_live(&name, 65535, 0, 1) {
                Ok(handle) => {
                    let plane = Self {
                        device: name,
                        library_path: lib.path().to_path_buf(),
                        lib,
                        handle,
                        closed: false,
                    };
                    plane.lib.set_nonblock(plane.handle)?;
                    plane.lib.set_min_to_copy(plane.handle, 0)?;
                    return Ok(plane);
                }
                Err(error) => failures.push(format!("{name}: {error}")),
            }
        }
        Err(if requested.is_some() {
            failures
                .into_iter()
                .next()
                .unwrap_or_else(|| "requested Npcap adapter could not be opened".into())
        } else {
            format!("no Npcap adapter could be opened: {}", failures.join("; "))
        })
    }
    pub fn backend_name(&self) -> String {
        format!("pcap:{}", self.device)
    }
    /// Send a datagram via pcap_sendpacket when available.
    pub fn send(&self, data: &[u8]) -> Result<(), String> {
        self.lib.sendpacket(self.handle, data)
    }
    pub fn install_filter(
        &self,
        peer_ip: Ipv4Addr,
        local_ip: Ipv4Addr,
        audio_port: u16,
        video_port: u16,
        vlan_tag: Option<u16>,
    ) -> Result<String, String> {
        if audio_port == 0 || video_port == 0 {
            return Err("media ports must be nonzero".into());
        }
        let filter = capture_filter(peer_ip, local_ip, audio_port, video_port, vlan_tag);
        self.lib.set_filter(self.handle, &filter)?;
        Ok(filter)
    }
    pub fn receive(&self) -> Result<Option<(ParsedUdpPacket, SystemTime)>, String> {
        self.receive_with(|frame, timestamp| {
            parse_ethernet_ipv4_udp_frame(frame).map(|packet| (packet, timestamp))
        })
        .map(Option::flatten)
    }
    pub(crate) fn receive_with<T, F>(&self, inspect: F) -> Result<Option<T>, String>
    where
        F: FnOnce(&[u8], SystemTime) -> T,
    {
        self.lib.inspect_next_packet(self.handle, inspect)
    }
    pub(crate) fn kernel_drop_snapshot(&self) -> Result<u64, String> {
        self.lib.kernel_drop_count(self.handle)
    }
    pub(crate) fn finalize(mut self) -> Result<u64, String> {
        let snapshot = self.kernel_drop_snapshot();
        self.close_handle();
        snapshot
    }
    pub fn is_open(&self) -> bool {
        !self.closed
    }

    fn close_handle(&mut self) {
        if !self.closed {
            self.lib.close(self.handle);
            self.closed = true;
        }
    }
}

fn capture_device_order(
    devices: Vec<String>,
    requested: Option<&str>,
) -> Result<Vec<String>, String> {
    match requested {
        Some(name) if devices.iter().any(|candidate| candidate == name) => {
            Ok(vec![name.to_owned()])
        }
        Some(name) => Err(format!("requested Npcap adapter `{name}` was not found")),
        None => Ok(devices),
    }
}

fn capture_filter(
    peer_ip: Ipv4Addr,
    local_ip: Ipv4Addr,
    audio_port: u16,
    video_port: u16,
    vlan_tag: Option<u16>,
) -> String {
    let vlan = vlan_tag.map_or_else(String::new, |tag| format!("vlan {tag} and "));
    format!(
        "{vlan}ip and src host {peer_ip} and dst host {local_ip} and (udp port {audio_port} or udp port {video_port})"
    )
}
