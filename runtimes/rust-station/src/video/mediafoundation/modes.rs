//! Platform-independent Media Foundation mode description and selection.

use serde::Serialize;
use std::fmt;

/// Native subtype of one Media Foundation media type.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub enum MfSubtype {
    Nv12,
    Yuy2,
    Rgb32,
    /// A subtype this backend does not convert, e.g. `MJPG` or `H264`.
    Other(String),
}

impl MfSubtype {
    /// Names a `DEFINE_MEDIATYPE_GUID` subtype from its first GUID field.
    pub fn from_fourcc(value: u32) -> Self {
        match &value.to_le_bytes() {
            b"NV12" => Self::Nv12,
            b"YUY2" => Self::Yuy2,
            // MFVideoFormat_RGB32 is D3DFMT_X8R8G8B8 (22), not a FOURCC.
            _ if value == 0x16 => Self::Rgb32,
            bytes if bytes.iter().all(|byte| byte.is_ascii_graphic()) => {
                Self::Other(String::from_utf8_lossy(bytes).into_owned())
            }
            _ => Self::Other(format!("0x{value:08X}")),
        }
    }

    pub fn is_supported(&self) -> bool {
        !matches!(self, Self::Other(_))
    }
}

impl fmt::Display for MfSubtype {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Nv12 => formatter.write_str("NV12"),
            Self::Yuy2 => formatter.write_str("YUY2"),
            Self::Rgb32 => formatter.write_str("RGB32"),
            Self::Other(name) => formatter.write_str(name),
        }
    }
}

/// A frame rate as Media Foundation stores it: numerator / denominator frames per second.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
pub struct MfRatio {
    pub numerator: u32,
    pub denominator: u32,
}

impl MfRatio {
    pub const fn new(numerator: u32, denominator: u32) -> Self {
        Self {
            numerator,
            denominator,
        }
    }

    /// Unpacks an `MF_MT_FRAME_RATE`-style UINT64 (numerator high, denominator low).
    pub const fn from_packed(value: u64) -> Self {
        Self::new((value >> 32) as u32, value as u32)
    }

    pub const fn packed(self) -> u64 {
        (self.numerator as u64) << 32 | self.denominator as u64
    }

    /// Compares `self` with `fps / 1` without rounding; `None` for a zero denominator.
    fn cmp_fps(self, fps: u32) -> Option<std::cmp::Ordering> {
        (self.denominator != 0)
            .then(|| u64::from(self.numerator).cmp(&(u64::from(fps) * u64::from(self.denominator))))
    }

    fn label(self) -> String {
        if self.denominator == 0 {
            return "?".into();
        }
        let fps = f64::from(self.numerator) / f64::from(self.denominator);
        if (fps - fps.round()).abs() < 0.005 {
            format!("{fps:.0}")
        } else {
            format!("{fps:.2}")
        }
    }
}

/// One native media type offered by a capture device.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct MfMode {
    pub subtype: MfSubtype,
    pub width: u32,
    pub height: u32,
    pub frame_rate: Option<MfRatio>,
    pub frame_rate_min: Option<MfRatio>,
    pub frame_rate_max: Option<MfRatio>,
}

impl MfMode {
    fn matches_exactly(&self, fps: u32) -> bool {
        self.frame_rate
            .and_then(|rate| rate.cmp_fps(fps))
            .is_some_and(|order| order.is_eq())
    }

    fn range_contains(&self, fps: u32) -> bool {
        match (self.frame_rate_min, self.frame_rate_max) {
            (Some(min), Some(max)) => {
                min.cmp_fps(fps).is_some_and(|order| order.is_le())
                    && max.cmp_fps(fps).is_some_and(|order| order.is_ge())
            }
            _ => false,
        }
    }

    fn rate_label(&self) -> String {
        match (self.frame_rate, self.frame_rate_min, self.frame_rate_max) {
            (_, Some(min), Some(max)) if min != max => format!("{}-{}", min.label(), max.label()),
            (Some(rate), _, _) => rate.label(),
            _ => "unknown".into(),
        }
    }
}

/// Station frame format a capture delivers to the session.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MfOutput {
    /// 8-bit luma, the session's `Mono8` (GREY).
    Mono8,
    /// Packed R, G, B, the session's `RGB24`.
    Rgb24,
}

impl MfOutput {
    pub fn pixel_format(self) -> &'static str {
        match self {
            Self::Mono8 => "Mono8",
            Self::Rgb24 => "RGB24",
        }
    }

    /// Subtypes in the order of conversion cost for this output.
    fn preference(self) -> [MfSubtype; 3] {
        match self {
            Self::Mono8 => [MfSubtype::Nv12, MfSubtype::Yuy2, MfSubtype::Rgb32],
            Self::Rgb24 => [MfSubtype::Rgb32, MfSubtype::Yuy2, MfSubtype::Nv12],
        }
    }
}

/// The exact mode the session asks for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MfModeRequest {
    pub width: u32,
    pub height: u32,
    pub fps: u32,
    /// `None` lets the backend pick NV12, YUY2 or RGB32 by conversion cost.
    pub subtype: Option<MfSubtype>,
    pub output: MfOutput,
}

impl MfModeRequest {
    fn candidates(&self) -> Vec<MfSubtype> {
        match &self.subtype {
            Some(subtype) => vec![subtype.clone()],
            None => self.output.preference().to_vec(),
        }
    }

    fn label(&self) -> String {
        let subtype = self
            .subtype
            .as_ref()
            .map_or("NV12/YUY2/RGB32".to_string(), ToString::to_string);
        format!(
            "{subtype} {}x{} @ {} fps",
            self.width, self.height, self.fps
        )
    }
}

/// The chosen native type and, for a frame-rate range, the rate to set on it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MfSelection {
    pub index: usize,
    pub set_frame_rate: Option<MfRatio>,
}

/// Picks the native type with the exact requested size and frame rate.
///
/// A discrete frame rate must equal the request; otherwise a type whose
/// `MF_MT_FRAME_RATE_RANGE_MIN..=MAX` contains it is used with the rate set.
/// Never scales, crops or substitutes another size or rate.
pub fn select_mode(modes: &[MfMode], request: &MfModeRequest) -> Option<MfSelection> {
    let sized = |mode: &MfMode, subtype: &MfSubtype| {
        mode.subtype == *subtype && mode.width == request.width && mode.height == request.height
    };
    let candidates = request.candidates();
    let find = |accept: &dyn Fn(&MfMode) -> bool| {
        candidates.iter().find_map(|subtype| {
            modes
                .iter()
                .position(|mode| sized(mode, subtype) && accept(mode))
        })
    };
    if let Some(index) = find(&|mode| mode.matches_exactly(request.fps)) {
        return Some(MfSelection {
            index,
            set_frame_rate: None,
        });
    }
    find(&|mode| mode.range_contains(request.fps)).map(|index| MfSelection {
        index,
        set_frame_rate: Some(MfRatio::new(request.fps, 1)),
    })
}

/// What the device offers, e.g. `YUY2 640x480 @ 30/15 fps; NV12 1280x720 @ 30 fps`.
pub fn offered_modes(modes: &[MfMode]) -> String {
    let mut entries: Vec<(String, Vec<String>)> = Vec::new();
    let mut unsupported: Vec<String> = Vec::new();
    for mode in modes {
        if !mode.subtype.is_supported() {
            let name = mode.subtype.to_string();
            if !unsupported.contains(&name) {
                unsupported.push(name);
            }
            continue;
        }
        let key = format!("{} {}x{}", mode.subtype, mode.width, mode.height);
        let rate = mode.rate_label();
        match entries.iter_mut().find(|(existing, _)| *existing == key) {
            Some((_, rates)) if rates.contains(&rate) => {}
            Some((_, rates)) => rates.push(rate),
            None => entries.push((key, vec![rate])),
        }
    }
    let mut text = if entries.is_empty() {
        "no NV12, YUY2 or RGB32 modes".to_string()
    } else {
        entries
            .iter()
            .map(|(key, rates)| format!("{key} @ {} fps", rates.join("/")))
            .collect::<Vec<_>>()
            .join("; ")
    };
    if !unsupported.is_empty() {
        text.push_str(&format!(
            " (also offers {}, which this backend does not convert)",
            unsupported.join(", ")
        ));
    }
    text
}

/// Explains a missing mode: requested vs offered, and which knobs to change.
pub fn mismatch_hint(request: &MfModeRequest, device: &str, modes: &[MfMode]) -> String {
    format!(
        "requested {}; {device} offers: {}. Only the exact requested size and frame rate are \
         used (no automatic negotiation); set --width/--height/--fps/--pixel-format or the \
         settings video.width, video.height, video.fps, video.pixel_format to one of these, \
         or video.device / video.local_camera_index to pick another camera. \
         `rusty-lola devices` shows the same list",
        request.label(),
        offered_modes(modes)
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mode(subtype: MfSubtype, width: u32, height: u32, fps: u32) -> MfMode {
        MfMode {
            subtype,
            width,
            height,
            frame_rate: Some(MfRatio::new(fps, 1)),
            frame_rate_min: None,
            frame_rate_max: None,
        }
    }

    fn request(width: u32, height: u32, fps: u32, output: MfOutput) -> MfModeRequest {
        MfModeRequest {
            width,
            height,
            fps,
            subtype: None,
            output,
        }
    }

    fn webcam() -> Vec<MfMode> {
        vec![
            mode(MfSubtype::Yuy2, 640, 480, 30),
            mode(MfSubtype::Yuy2, 640, 480, 15),
            mode(MfSubtype::Other("MJPG".into()), 1280, 720, 60),
            mode(MfSubtype::Nv12, 640, 480, 30),
            mode(MfSubtype::Rgb32, 640, 480, 30),
        ]
    }

    #[test]
    fn exact_match_prefers_the_cheapest_subtype_for_the_output() {
        let modes = webcam();
        let mono = select_mode(&modes, &request(640, 480, 30, MfOutput::Mono8)).unwrap();
        assert_eq!(
            mono,
            MfSelection {
                index: 3,
                set_frame_rate: None
            }
        );
        let rgb = select_mode(&modes, &request(640, 480, 30, MfOutput::Rgb24)).unwrap();
        assert_eq!(rgb.index, 4);
        let mut yuy2 = request(640, 480, 15, MfOutput::Mono8);
        yuy2.subtype = Some(MfSubtype::Yuy2);
        assert_eq!(select_mode(&modes, &yuy2).unwrap().index, 1);
    }

    #[test]
    fn fractional_rates_must_match_exactly() {
        let mut ntsc = mode(MfSubtype::Nv12, 640, 480, 0);
        ntsc.frame_rate = Some(MfRatio::new(30_000, 1001));
        let modes = vec![ntsc, mode(MfSubtype::Nv12, 640, 480, 60)];
        assert_eq!(
            select_mode(&modes, &request(640, 480, 60, MfOutput::Mono8))
                .unwrap()
                .index,
            1
        );
        assert!(select_mode(&modes, &request(640, 480, 30, MfOutput::Mono8)).is_none());
        assert_eq!(offered_modes(&modes), "NV12 640x480 @ 29.97/60 fps");
    }

    #[test]
    fn no_match_lists_the_offered_modes_and_the_knobs() {
        let modes = webcam();
        let wanted = request(1280, 720, 60, MfOutput::Mono8);
        assert!(select_mode(&modes, &wanted).is_none());
        let hint = mismatch_hint(&wanted, "USB Cam", &modes);
        assert!(
            hint.contains("requested NV12/YUY2/RGB32 1280x720 @ 60 fps; USB Cam offers:"),
            "{hint}"
        );
        assert!(
            hint.contains(
                "YUY2 640x480 @ 30/15 fps; NV12 640x480 @ 30 fps; RGB32 640x480 @ 30 fps \
                 (also offers MJPG, which this backend does not convert)"
            ),
            "{hint}"
        );
        assert!(
            hint.contains("--width/--height/--fps/--pixel-format"),
            "{hint}"
        );
        assert!(hint.contains("video.local_camera_index"), "{hint}");
        assert!(hint.contains("`rusty-lola devices`"), "{hint}");
        assert_eq!(offered_modes(&[]), "no NV12, YUY2 or RGB32 modes");
    }

    #[test]
    fn frame_rate_range_matches_and_sets_the_requested_rate() {
        let mut ranged = mode(MfSubtype::Yuy2, 1280, 720, 30);
        ranged.frame_rate_min = Some(MfRatio::new(5, 1));
        ranged.frame_rate_max = Some(MfRatio::new(30, 1));
        let modes = vec![ranged];
        let selection = select_mode(&modes, &request(1280, 720, 24, MfOutput::Rgb24)).unwrap();
        assert_eq!(
            selection,
            MfSelection {
                index: 0,
                set_frame_rate: Some(MfRatio::new(24, 1))
            }
        );
        assert!(select_mode(&modes, &request(1280, 720, 60, MfOutput::Rgb24)).is_none());
        assert_eq!(offered_modes(&modes), "YUY2 1280x720 @ 5-30 fps");
    }

    #[test]
    fn subtypes_are_named_from_their_fourcc() {
        assert_eq!(
            MfSubtype::from_fourcc(u32::from_le_bytes(*b"NV12")),
            MfSubtype::Nv12
        );
        assert_eq!(
            MfSubtype::from_fourcc(u32::from_le_bytes(*b"YUY2")),
            MfSubtype::Yuy2
        );
        assert_eq!(MfSubtype::from_fourcc(0x16), MfSubtype::Rgb32);
        assert_eq!(
            MfSubtype::from_fourcc(u32::from_le_bytes(*b"MJPG")).to_string(),
            "MJPG"
        );
        assert_eq!(MfSubtype::from_fourcc(0x15).to_string(), "0x00000015");
        assert_eq!(
            MfRatio::from_packed(MfRatio::new(30, 1).packed()).numerator,
            30
        );
    }
}
