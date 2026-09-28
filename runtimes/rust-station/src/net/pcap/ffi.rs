use libloading::Library;
use serde_json::{json, Value};
use std::path::{Path, PathBuf};
use std::ptr::NonNull;
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub(super) fn pcap_lock() -> &'static Mutex<()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    LOCK.get_or_init(|| Mutex::new(()))
}
type PcapFindalldevs = unsafe extern "C" fn(*mut *mut PcapIf, *mut i8) -> i32;
type PcapFreealldevs = unsafe extern "C" fn(*mut PcapIf);
type PcapOpenLive =
    unsafe extern "C" fn(*const i8, i32, i32, i32, *mut i8) -> *mut std::ffi::c_void;
type PcapClose = unsafe extern "C" fn(*mut std::ffi::c_void);
type PcapSendpacket = unsafe extern "C" fn(*mut std::ffi::c_void, *const u8, i32) -> i32;
type PcapCompile =
    unsafe extern "C" fn(*mut std::ffi::c_void, *mut BpfProgram, *const i8, i32, u32) -> i32;
type PcapSetfilter = unsafe extern "C" fn(*mut std::ffi::c_void, *mut BpfProgram) -> i32;
type PcapFreecode = unsafe extern "C" fn(*mut BpfProgram);
type PcapNextEx = unsafe extern "C" fn(
    *mut std::ffi::c_void,
    *mut *const PcapPacketHeader,
    *mut *const u8,
) -> i32;
type PcapSetMinToCopy = unsafe extern "C" fn(*mut std::ffi::c_void, i32) -> i32;
type PcapSetNonblock = unsafe extern "C" fn(*mut std::ffi::c_void, i32, *mut i8) -> i32;
type PcapGeterr = unsafe extern "C" fn(*mut std::ffi::c_void) -> *const i8;
type PcapStats = unsafe extern "C" fn(*mut std::ffi::c_void, *mut PcapStat) -> i32;
#[repr(C)]
struct PcapIf {
    next: *mut PcapIf,
    name: *mut i8,
    description: *mut i8,
    addresses: *mut std::ffi::c_void,
    flags: u32,
}
#[repr(C)]
struct BpfInsn {
    code: u16,
    jt: u8,
    jf: u8,
    k: u32,
}
#[repr(C)]
struct BpfProgram {
    len: u32,
    instructions: *mut BpfInsn,
}
#[repr(C)]
struct PcapTimeval {
    seconds: std::ffi::c_long,
    micros: std::ffi::c_long,
}
#[repr(C)]
struct PcapPacketHeader {
    timestamp: PcapTimeval,
    captured_length: u32,
    original_length: u32,
}
#[derive(Debug, Clone, Copy, Default)]
#[repr(C)]
struct PcapStat {
    received: u32,
    dropped: u32,
    interface_dropped: u32,
    #[cfg(target_os = "windows")]
    captured: u32,
}

#[derive(Debug, Clone)]
pub struct PcapProbe {
    pub available: bool,
    pub library_path: Option<PathBuf>,
    pub device: Option<String>,
    pub reason: String,
    /// Only "pcap" when a live handle can be / was opened; otherwise "udp".
    pub transport: String,
    pub loaded: bool,
    pub device_count: Option<usize>,
}
impl PcapProbe {
    pub fn to_json(&self) -> Value {
        json!({ "available": self.available, "library_path": self.library_path.as_ref().map(|p| p.display().to_string()), "device": self.device, "reason": self.reason, "transport": self.transport, "loaded": self.loaded, "device_count": self.device_count })
    }
}

fn search_dirs() -> Vec<PathBuf> {
    crate::native_loader::search_dirs("pcap")
}
fn candidate_paths() -> Vec<PathBuf> {
    crate::native_loader::candidate_paths(
        &search_dirs(),
        &["wpcap.dll", "Packet.dll"],
        &[PathBuf::from(r"C:\Windows\System32\Npcap\wpcap.dll")],
    )
}

/// Bound pcap library.
pub struct PcapLibrary {
    _lib: Library,
    path: PathBuf,
    findalldevs: PcapFindalldevs,
    freealldevs: Option<PcapFreealldevs>,
    open_live: PcapOpenLive,
    close: PcapClose,
    compile: PcapCompile,
    setfilter: PcapSetfilter,
    freecode: PcapFreecode,
    next_ex: PcapNextEx,
    sendpacket: PcapSendpacket,
    set_min_to_copy: PcapSetMinToCopy,
    set_nonblock: PcapSetNonblock,
    geterr: PcapGeterr,
    stats: PcapStats,
}

/// Load wpcap/npcap and bind required symbols. Err if unloadable.
pub fn load_pcap(dll_path: Option<&Path>) -> Result<PcapLibrary, String> {
    let mut paths = Vec::new();
    if let Some(p) = dll_path {
        paths.push(p.to_path_buf());
    }
    paths.extend(candidate_paths());
    let mut last_err = "wpcap/npcap not found".to_string();
    for path in paths {
        // SAFETY: `path` is a candidate library path; `Library` owns the loaded module on success.
        let lib = match unsafe { crate::native_loader::load(&path) } {
            Ok(l) => l,
            Err(e) => {
                last_err = format!("load {}: {e}", path.display());
                continue;
            }
        };
        macro_rules! bind {
            ($type:ty, $symbol:literal) => {
                // SAFETY: `$symbol` is a NUL-terminated literal and the requested type matches the pcap ABI.
                match unsafe { lib.get::<$type>($symbol) } {
                    Ok(symbol) => *symbol,
                    Err(error) => {
                        last_err = format!(
                            "{}: {error}",
                            String::from_utf8_lossy(&$symbol[..$symbol.len() - 1])
                        );
                        continue;
                    }
                }
            };
        }
        let findalldevs = bind!(PcapFindalldevs, b"pcap_findalldevs\0");
        let open_live = bind!(PcapOpenLive, b"pcap_open_live\0");
        let close = bind!(PcapClose, b"pcap_close\0");
        // SAFETY: the symbol name is NUL-terminated and the optional type matches the pcap ABI.
        let freealldevs = unsafe { lib.get(b"pcap_freealldevs\0").ok().map(|s| *s) };
        let compile = bind!(PcapCompile, b"pcap_compile\0");
        let setfilter = bind!(PcapSetfilter, b"pcap_setfilter\0");
        let freecode = bind!(PcapFreecode, b"pcap_freecode\0");
        let next_ex = bind!(PcapNextEx, b"pcap_next_ex\0");
        let sendpacket = bind!(PcapSendpacket, b"pcap_sendpacket\0");
        let set_min_to_copy = bind!(PcapSetMinToCopy, b"pcap_setmintocopy\0");
        let set_nonblock = bind!(PcapSetNonblock, b"pcap_setnonblock\0");
        let geterr = bind!(PcapGeterr, b"pcap_geterr\0");
        let stats = bind!(PcapStats, b"pcap_stats\0");
        return Ok(PcapLibrary {
            _lib: lib,
            path: path.canonicalize().unwrap_or(path),
            findalldevs,
            freealldevs,
            open_live,
            close,
            compile,
            setfilter,
            freecode,
            next_ex,
            sendpacket,
            set_min_to_copy,
            set_nonblock,
            geterr,
            stats,
        });
    }
    Err(last_err)
}

impl PcapLibrary {
    pub fn path(&self) -> &Path {
        &self.path
    }
    /// Enumerate devices via real pcap_findalldevs.
    pub fn findalldevs(&self) -> Result<Vec<String>, String> {
        let mut alldevs = std::ptr::null_mut();
        let mut errbuf = [0i8; 256];
        // SAFETY: pcap receives valid writable out-pointers to the device list and 256-byte error buffer.
        let rc = unsafe { (self.findalldevs)(&mut alldevs, errbuf.as_mut_ptr()) };
        if rc != 0 {
            // SAFETY: pcap writes a NUL-terminated message into `errbuf` on failure.
            let msg = unsafe { std::ffi::CStr::from_ptr(errbuf.as_ptr()) };
            return Err(format!(
                "pcap_findalldevs failed: {}",
                msg.to_string_lossy()
            ));
        }
        let mut names = Vec::new();
        let mut cur = alldevs;
        while !cur.is_null() {
            // SAFETY: `cur` is a node from pcap's NUL-terminated linked device list.
            unsafe {
                let name_ptr = (*cur).name;
                if !name_ptr.is_null() {
                    names.push(
                        std::ffi::CStr::from_ptr(name_ptr)
                            .to_string_lossy()
                            .into_owned(),
                    );
                }
                cur = (*cur).next;
            }
        }
        if let Some(free) = self.freealldevs {
            if !alldevs.is_null() {
                // SAFETY: `alldevs` came from pcap_findalldevs and `free` is its matching deallocator.
                unsafe { free(alldevs) };
            }
        }
        Ok(names)
    }
    pub(super) fn open_live(
        &self,
        device: &str,
        snaplen: i32,
        promisc: i32,
        timeout_ms: i32,
    ) -> Result<NonNull<std::ffi::c_void>, String> {
        let c_dev = std::ffi::CString::new(device).map_err(|e| e.to_string())?;
        let mut errbuf = [0i8; 256];
        // SAFETY: `c_dev` is NUL-terminated and both its pointer and `errbuf` remain valid for the call.
        let handle = unsafe {
            (self.open_live)(
                c_dev.as_ptr(),
                snaplen,
                promisc,
                timeout_ms,
                errbuf.as_mut_ptr(),
            )
        };
        let Some(handle) = NonNull::new(handle) else {
            // SAFETY: pcap writes a NUL-terminated message into `errbuf` when opening fails.
            let msg = unsafe { std::ffi::CStr::from_ptr(errbuf.as_ptr()) };
            return Err(format!(
                "pcap_open_live({device}): {}",
                msg.to_string_lossy()
            ));
        };
        Ok(handle)
    }
    pub(super) fn close(&self, handle: NonNull<std::ffi::c_void>) {
        // SAFETY: `handle` was returned by this library's `pcap_open_live` and ownership is retained by exactly one `RawMediaPlane` until Drop.
        unsafe { (self.close)(handle.as_ptr()) };
    }
    fn error(&self, handle: NonNull<std::ffi::c_void>, context: &str) -> String {
        // SAFETY: the handle is live for the duration of this call; pcap owns the returned NUL-terminated error string.
        let ptr = unsafe { (self.geterr)(handle.as_ptr()) };
        if ptr.is_null() {
            return context.to_string();
        }
        format!(
            "{context}: {}",
            // SAFETY: `ptr` was checked non-null and pcap owns its NUL-terminated error string.
            unsafe { std::ffi::CStr::from_ptr(ptr) }.to_string_lossy()
        )
    }
    pub(super) fn set_filter(
        &self,
        handle: NonNull<std::ffi::c_void>,
        filter: &str,
    ) -> Result<(), String> {
        let filter = std::ffi::CString::new(filter).map_err(|error| error.to_string())?;
        let mut program = BpfProgram {
            len: 0,
            instructions: std::ptr::null_mut(),
        };
        // SAFETY: `handle`, `filter`, and `program` pointers remain valid for compilation.
        if unsafe {
            (self.compile)(
                handle.as_ptr(),
                &mut program,
                filter.as_ptr(),
                1,
                0x00ff_ffff,
            )
        } != 0
        {
            return Err(self.error(handle, "pcap_compile failed"));
        }
        // SAFETY: `program` was initialized by pcap_compile and belongs to this loaded pcap library.
        let set_rc = unsafe { (self.setfilter)(handle.as_ptr(), &mut program) };
        // SAFETY: `program` was initialized by pcap_compile and is released by its matching pcap library.
        unsafe { (self.freecode)(&mut program) };
        if set_rc != 0 {
            return Err(self.error(handle, "pcap_setfilter failed"));
        }
        Ok(())
    }
    pub(super) fn set_min_to_copy(
        &self,
        handle: NonNull<std::ffi::c_void>,
        bytes: i32,
    ) -> Result<(), String> {
        // SAFETY: handle ownership/lifetime is retained by RawMediaPlane.
        if unsafe { (self.set_min_to_copy)(handle.as_ptr(), bytes) } != 0 {
            return Err(self.error(handle, "pcap_setmintocopy failed"));
        }
        Ok(())
    }
    pub(super) fn set_nonblock(&self, handle: NonNull<std::ffi::c_void>) -> Result<(), String> {
        let mut errbuf = [0i8; 256];
        // SAFETY: `handle` is live and `errbuf` is a writable pcap error buffer
        // for the duration of this synchronous call.
        if unsafe { (self.set_nonblock)(handle.as_ptr(), 1, errbuf.as_mut_ptr()) } != 0 {
            // SAFETY: pcap_setnonblock writes a NUL-terminated message into errbuf on failure.
            let detail = unsafe { std::ffi::CStr::from_ptr(errbuf.as_ptr()) }
                .to_string_lossy()
                .into_owned();
            return Err(if detail.is_empty() {
                self.error(handle, "pcap_setnonblock failed")
            } else {
                format!("pcap_setnonblock failed: {detail}")
            });
        }
        Ok(())
    }
    pub(super) fn sendpacket(
        &self,
        handle: NonNull<std::ffi::c_void>,
        data: &[u8],
    ) -> Result<(), String> {
        if data.is_empty() || data.len() > i32::MAX as usize {
            return Err("pcap_sendpacket requires a non-empty bounded frame".into());
        }
        // SAFETY: `data` remains alive and immutable for this synchronous call; `handle` is live.
        if unsafe { (self.sendpacket)(handle.as_ptr(), data.as_ptr(), data.len() as i32) } != 0 {
            return Err(self.error(handle, "pcap_sendpacket failed"));
        }
        Ok(())
    }
    pub(super) fn inspect_next_packet<T, F>(
        &self,
        handle: NonNull<std::ffi::c_void>,
        inspect: F,
    ) -> Result<Option<T>, String>
    where
        F: FnOnce(&[u8], SystemTime) -> T,
    {
        let mut header = std::ptr::null();
        let mut data = std::ptr::null();
        // SAFETY: pcap_next_ex initializes both valid out-pointers; returned data is copied below.
        match unsafe { (self.next_ex)(handle.as_ptr(), &mut header, &mut data) } {
            0 | -2 => Ok(None),
            1 => {
                if header.is_null() || data.is_null() {
                    return Err("pcap_next_ex returned null packet pointers".into());
                }
                // SAFETY: pcap_next_ex returned a non-null header valid until the next pcap call.
                let header = unsafe { &*header };
                if header.captured_length == 0 || header.captured_length > 65_535 + 64 {
                    return Err(format!(
                        "pcap_next_ex invalid captured length {}",
                        header.captured_length
                    ));
                }
                // SAFETY: pcap supplied `captured_length` bytes at non-null
                // `data`. The callback completes before any later pcap call can
                // invalidate this borrowed capture buffer.
                let bytes =
                    unsafe { std::slice::from_raw_parts(data, header.captured_length as usize) };
                let timestamp = UNIX_EPOCH
                    + Duration::from_secs(header.timestamp.seconds.max(0) as u64)
                    + Duration::from_micros(header.timestamp.micros.max(0) as u64);
                Ok(Some(inspect(bytes, timestamp)))
            }
            rc => Err(self.error(handle, &format!("pcap_next_ex failed ({rc})"))),
        }
    }

    pub(super) fn kernel_drop_count(
        &self,
        handle: NonNull<std::ffi::c_void>,
    ) -> Result<u64, String> {
        let mut stats = PcapStat::default();
        // SAFETY: `handle` is live and `stats` is writable for the documented
        // pcap_stat layout for the duration of this synchronous call.
        if unsafe { (self.stats)(handle.as_ptr(), &mut stats) } != 0 {
            return Err(self.error(handle, "pcap_stats failed"));
        }
        Ok(u64::from(stats.dropped) + u64::from(stats.interface_dropped))
    }
}

/// Probe: available when DLL loads + symbols bind + findalldevs works.
/// transport stays "udp" until a live plane is opened (no stub pcap success).
pub fn probe_pcap(device: Option<&str>) -> PcapProbe {
    let _g = pcap_lock().lock().unwrap_or_else(|e| e.into_inner());
    match load_pcap(None) {
        Ok(lib) => match lib.findalldevs() {
            Ok(devs) => PcapProbe {
                available: true,
                library_path: Some(lib.path().to_path_buf()),
                device: device.map(str::to_owned).or_else(|| devs.first().cloned()),
                reason: format!(
                    "loaded {}; {} device(s) via pcap_findalldevs",
                    lib.path().display(),
                    devs.len()
                ),
                transport: "udp".into(),
                loaded: true,
                device_count: Some(devs.len()),
            },
            Err(e) => PcapProbe {
                available: true,
                library_path: Some(lib.path().to_path_buf()),
                device: device.map(str::to_owned),
                reason: format!("loaded {}; findalldevs: {e}", lib.path().display()),
                transport: "udp".into(),
                loaded: true,
                device_count: None,
            },
        },
        Err(e) => PcapProbe {
            available: false,
            library_path: None,
            device: device.map(str::to_owned),
            reason: e,
            transport: "udp".into(),
            loaded: false,
            device_count: None,
        },
    }
}
