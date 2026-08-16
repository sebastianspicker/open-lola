use super::*;

#[test]
fn diagnostic_backends_are_explicit() {
    let mut settings = default_settings();
    settings.audio.backend = AudioBackend::Diagnostic;
    settings.video.backend = VideoBackend::Diagnostic;
    assert_eq!(settings.audio.backend.as_preference(), "diagnostic");
    assert_eq!(settings.video.backend.as_preference(), "diagnostic");
}

#[test]
fn backends_ffi_load_and_honest_select() {
    use rusty_lola::audio::load_portaudio;
    use rusty_lola::net::{load_pcap, RawMediaPlane};
    use rusty_lola::video::load_xiapi;

    // Probes must LoadLibrary + bind symbols (not path-stat alone)
    let xp = probe_ximea();
    if xp.available {
        assert!(xp.loaded, "ximea available implies loaded via FFI");
        let lib = load_xiapi(xp.library_path.as_deref()).expect("load_xiapi");
        let _ = lib.get_number_devices(); // real C call
    }
    let ap = probe_portaudio();
    if ap.available {
        assert!(ap.loaded && ap.initialized);
        let mut lib = load_portaudio(ap.library_path.as_deref()).expect("load_portaudio");
        lib.initialize().expect("Pa_Initialize");
        let _ = lib.device_count();
    }
    let pp = probe_pcap(None);
    // Probe alone never claims transport=pcap
    assert_eq!(pp.transport, "udp");
    if pp.available {
        assert!(pp.loaded);
        let lib = load_pcap(pp.library_path.as_deref()).expect("load_pcap");
        let _ = lib.findalldevs();
    }

    // A raw handle probe may fail when Npcap is absent, but never reports an
    // active Npcap session or substitutes UDP.
    if let Ok(plane) = RawMediaPlane::try_open(None) {
        assert!(plane.is_open());
    }
}
