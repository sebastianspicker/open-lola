use std::collections::BTreeMap;
use std::time::{Duration, Instant};

use super::{
    parse_fragment, parse_video_prelude, Fragment, MediaError, VideoPrelude,
    MAX_MEDIA_FRAGMENT_COUNT, MAX_MEDIA_FRAME_SIZE, MAX_REASSEMBLY_BUFFERED_BYTES,
    REASSEMBLY_EXPIRY,
};

pub fn validate_reassembly_shape(
    expected_size: usize,
    fragment_count: u32,
) -> Result<(), MediaError> {
    if expected_size == 0 || expected_size > MAX_MEDIA_FRAME_SIZE {
        return Err(MediaError::InvalidFrameSize(expected_size));
    }
    if fragment_count == 0 || fragment_count > MAX_MEDIA_FRAGMENT_COUNT {
        return Err(MediaError::InvalidFragmentCount(fragment_count));
    }
    Ok(())
}

/// Returns whether `candidate` is later than `reference` in the serial-number
/// space used by wrapping media sequence counters.
pub fn serial_u32_is_newer(candidate: u32, reference: u32) -> bool {
    candidate != reference && candidate.wrapping_sub(reference) < (1 << 31)
}

#[derive(Debug)]
struct ActiveFrame {
    expected_size: usize,
    fragment_count: u32,
    parts: BTreeMap<u32, Fragment>,
    buffered_bytes: usize,
    touched: Instant,
}

#[derive(Debug)]
pub struct MediaReassembler {
    active: BTreeMap<u32, ActiveFrame>,
    pub allow_fragment_auto_begin: bool,
    max_active_frames: usize,
    max_buffered_bytes: usize,
    buffered_bytes: usize,
    expiry: Duration,
}

impl Default for MediaReassembler {
    fn default() -> Self {
        Self::new()
    }
}
impl MediaReassembler {
    pub fn new() -> Self {
        Self {
            active: BTreeMap::new(),
            allow_fragment_auto_begin: true,
            max_active_frames: 32,
            max_buffered_bytes: buffered_capacity(32),
            buffered_bytes: 0,
            expiry: REASSEMBLY_EXPIRY,
        }
    }
    pub fn strict() -> Self {
        Self {
            allow_fragment_auto_begin: false,
            ..Self::new()
        }
    }
    pub fn with_limits(max_active_frames: usize, expiry: Duration) -> Self {
        let max_active_frames = max_active_frames.max(1);
        Self {
            max_active_frames,
            max_buffered_bytes: buffered_capacity(max_active_frames),
            expiry,
            ..Self::new()
        }
    }
    pub fn begin(
        &mut self,
        frame_id: u32,
        expected_size: usize,
        fragment_count: u32,
    ) -> Result<(), MediaError> {
        self.expire();
        validate_reassembly_shape(expected_size, fragment_count)?;
        if !self.active.contains_key(&frame_id) && self.active.len() >= self.max_active_frames {
            return Err(MediaError::TooManyActiveFrames);
        }
        self.remove_active(frame_id);
        self.active.insert(
            frame_id,
            ActiveFrame {
                expected_size,
                fragment_count,
                parts: BTreeMap::new(),
                buffered_bytes: 0,
                touched: Instant::now(),
            },
        );
        Ok(())
    }
    pub fn begin_prelude(&mut self, prelude: VideoPrelude) -> Result<(), MediaError> {
        self.begin(
            prelude.frame_id,
            prelude.expected_size as usize,
            prelude.fragment_count,
        )
    }
    pub fn expire(&mut self) -> usize {
        let now = Instant::now();
        let before = self.active.len();
        let expired_bytes = self
            .active
            .values()
            .filter(|frame| now.duration_since(frame.touched) > self.expiry)
            .map(|frame| frame.buffered_bytes)
            .sum::<usize>();
        self.active
            .retain(|_, frame| now.duration_since(frame.touched) <= self.expiry);
        self.buffered_bytes = self.buffered_bytes.saturating_sub(expired_bytes);
        before - self.active.len()
    }
    pub fn take_expired_partial(&mut self, threshold_pct: f64) -> Option<Vec<u8>> {
        if threshold_pct <= 0.0 {
            self.expire();
            return None;
        }
        let now = Instant::now();
        let expired_ids = self
            .active
            .iter()
            .filter(|(_, frame)| now.duration_since(frame.touched) >= self.expiry)
            .map(|(frame_id, _)| *frame_id)
            .collect::<Vec<_>>();
        let mut expired = expired_ids
            .into_iter()
            .filter_map(|frame_id| self.active.remove(&frame_id))
            .collect::<Vec<_>>();
        let expired_bytes = expired.iter().map(|frame| frame.buffered_bytes).sum();
        self.buffered_bytes = self.buffered_bytes.saturating_sub(expired_bytes);
        expired.sort_by_key(|frame| std::cmp::Reverse(frame.touched));
        let required_coverage_pct = 100.0 - threshold_pct.clamp(0.0, 100.0);
        expired.into_iter().find_map(|frame| {
            let coverage_pct =
                frame.buffered_bytes as f64 * 100.0 / frame.expected_size.max(1) as f64;
            if frame.expected_size == 0 || coverage_pct < required_coverage_pct {
                return None;
            }
            let mut partial = vec![0; frame.expected_size];
            for part in frame.parts.into_values() {
                let start = part.original_offset as usize;
                let end = start.checked_add(part.data.len())?;
                if end > partial.len() {
                    return None;
                }
                partial[start..end].copy_from_slice(&part.data);
            }
            Some(partial)
        })
    }
    pub fn active_frames(&self) -> usize {
        self.active.len()
    }
    pub fn reset(&mut self) {
        self.active.clear();
        self.buffered_bytes = 0;
    }
    fn remove_active(&mut self, frame_id: u32) {
        if let Some(frame) = self.active.remove(&frame_id) {
            self.buffered_bytes = self.buffered_bytes.saturating_sub(frame.buffered_bytes);
        }
    }
    pub fn add(&mut self, fragment: Fragment) -> Result<Option<Vec<u8>>, MediaError> {
        self.expire();
        if !self.active.contains_key(&fragment.frame_id) {
            if !self.allow_fragment_auto_begin {
                return Ok(None);
            }
            if fragment.fragment_count == 0 || fragment.fragment_count > MAX_MEDIA_FRAGMENT_COUNT {
                return Err(MediaError::InvalidFragmentCount(fragment.fragment_count));
            }
            if self.active.len() >= self.max_active_frames {
                return Err(MediaError::TooManyActiveFrames);
            }
            self.active.insert(
                fragment.frame_id,
                ActiveFrame {
                    expected_size: 0,
                    fragment_count: fragment.fragment_count,
                    parts: BTreeMap::new(),
                    buffered_bytes: 0,
                    touched: Instant::now(),
                },
            );
        }
        let frame_id = fragment.frame_id;
        let frame = self.active.get(&frame_id).expect("inserted");
        if fragment.fragment_count != frame.fragment_count {
            return Err(MediaError::FragmentCountMismatch {
                expected: frame.fragment_count,
                received: fragment.fragment_count,
            });
        }
        if fragment.fragment_index >= frame.fragment_count {
            return Err(MediaError::FragmentIndex(fragment.fragment_index));
        }
        if fragment.data.is_empty() || fragment.data.len() != fragment.fragment_length as usize {
            return Err(MediaError::BadFragment);
        }
        let end = (fragment.original_offset as usize)
            .checked_add(fragment.data.len())
            .ok_or(MediaError::InvalidFrameSize(usize::MAX))?;
        if end > MAX_MEDIA_FRAME_SIZE {
            return Err(MediaError::InvalidFrameSize(end));
        }
        if frame.expected_size != 0 && end > frame.expected_size {
            return Err(MediaError::FragmentExceeds(end, frame.expected_size));
        }
        if frame.parts.contains_key(&fragment.fragment_index) {
            return Err(MediaError::DuplicateFragment(fragment.fragment_index));
        }
        let start = fragment.original_offset as usize;
        if frame.parts.values().any(|part| {
            let part_start = part.original_offset as usize;
            let part_end = part_start + part.data.len();
            start < part_end && part_start < end
        }) {
            return Err(MediaError::FragmentOverlap(start));
        }
        let received = self.buffered_bytes.checked_add(fragment.data.len()).ok_or(
            MediaError::BufferedLimitExceeded {
                received: usize::MAX,
                limit: self.max_buffered_bytes,
            },
        )?;
        if received > self.max_buffered_bytes {
            return Err(MediaError::BufferedLimitExceeded {
                received,
                limit: self.max_buffered_bytes,
            });
        }
        let frame = self.active.get_mut(&frame_id).expect("inserted");
        frame.touched = Instant::now();
        frame.buffered_bytes += fragment.data.len();
        self.buffered_bytes = received;
        frame.parts.insert(fragment.fragment_index, fragment);
        if frame.parts.len() != frame.fragment_count as usize {
            return Ok(None);
        }
        let frame = self.active.remove(&frame_id).expect("active frame");
        self.buffered_bytes = self.buffered_bytes.saturating_sub(frame.buffered_bytes);
        let expected = if frame.expected_size == 0 {
            frame
                .parts
                .values()
                .map(|part| part.original_offset as usize + part.data.len())
                .max()
                .unwrap_or(0)
        } else {
            frame.expected_size
        };
        validate_reassembly_shape(expected, frame.fragment_count)?;
        let mut cursor = 0;
        let mut out = vec![0; expected];
        let mut parts: Vec<_> = frame.parts.into_values().collect();
        parts.sort_by_key(|part| part.original_offset);
        for part in parts {
            let start = part.original_offset as usize;
            let end = start + part.data.len();
            if start < cursor {
                return Err(MediaError::FragmentOverlap(start));
            }
            if start > cursor {
                return Err(MediaError::FragmentGap(cursor, start));
            }
            out[start..end].copy_from_slice(&part.data);
            cursor = end;
        }
        if cursor != expected {
            return Err(MediaError::FragmentCoverage(cursor, expected));
        }
        Ok(Some(out))
    }
}

fn buffered_capacity(max_active_frames: usize) -> usize {
    max_active_frames
        .saturating_mul(MAX_MEDIA_FRAME_SIZE)
        .min(MAX_REASSEMBLY_BUFFERED_BYTES)
}
/// Station-facing bounded fragment reassembler.
#[derive(Debug, Default)]
pub struct FrameReassembler {
    inner: MediaReassembler,
}
impl FrameReassembler {
    pub fn new() -> Self {
        Self::default()
    }
    pub fn with_limit(max_active_frames: usize) -> Self {
        Self {
            inner: MediaReassembler::with_limits(max_active_frames, REASSEMBLY_EXPIRY),
        }
    }
    /// Requires a video prelude before accepting fragments.
    pub fn strict_video() -> Self {
        Self {
            inner: MediaReassembler::strict(),
        }
    }
    pub fn feed(&mut self, data: &[u8]) -> Result<Option<Vec<u8>>, MediaError> {
        if let Some(prelude) = parse_video_prelude(data) {
            self.inner.begin_prelude(prelude)?;
            return Ok(None);
        }
        self.inner.add(parse_fragment(data)?)
    }
    pub fn reset(&mut self) {
        self.inner.reset();
    }
    pub fn expire(&mut self) -> usize {
        self.inner.expire()
    }
    pub fn take_expired_partial(&mut self, threshold_pct: f64) -> Option<Vec<u8>> {
        self.inner.take_expired_partial(threshold_pct)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn video_round_trip_with_prelude() {
        let packets = crate::protocol::build_video_payloads(9, &[7; 2000], None, 128);
        let prelude = parse_video_prelude(&packets[0]).unwrap();
        let mut re = MediaReassembler::new();
        re.begin_prelude(prelude).unwrap();
        let mut complete = None;
        for p in &packets[1..] {
            complete = re.add(parse_fragment(p).unwrap()).unwrap().or(complete);
        }
        assert_eq!(
            crate::protocol::parse_serialized_media(&complete.unwrap())
                .unwrap()
                .0,
            9
        );
    }

    #[test]
    fn rejects_duplicate_overlap_and_inconsistent_fragments_before_completion() {
        let mut reassembler = MediaReassembler::new();
        reassembler.begin(4, 4, 2).unwrap();
        let first = Fragment {
            frame_id: 4,
            fragment_count: 2,
            fragment_index: 0,
            original_offset: 0,
            fragment_length: 2,
            flags: 0,
            data: vec![1, 2],
        };
        assert_eq!(reassembler.add(first.clone()).unwrap(), None);
        assert_eq!(
            reassembler.add(first).unwrap_err(),
            MediaError::DuplicateFragment(0)
        );
        assert_eq!(
            reassembler
                .add(Fragment {
                    frame_id: 4,
                    fragment_count: 2,
                    fragment_index: 1,
                    original_offset: 1,
                    fragment_length: 2,
                    flags: 1,
                    data: vec![3, 4],
                })
                .unwrap_err(),
            MediaError::FragmentOverlap(1)
        );
        assert_eq!(
            reassembler
                .add(Fragment {
                    frame_id: 4,
                    fragment_count: 3,
                    fragment_index: 1,
                    original_offset: 2,
                    fragment_length: 2,
                    flags: 1,
                    data: vec![3, 4],
                })
                .unwrap_err(),
            MediaError::FragmentCountMismatch {
                expected: 2,
                received: 3,
            }
        );
        assert_eq!(reassembler.active_frames(), 1);
        assert_eq!(reassembler.buffered_bytes, 2);
    }

    #[test]
    fn strict_video_requires_a_prelude_while_audio_accepts_valid_fragments() {
        let packet = crate::protocol::build_audio_payload(7, &[1; 4], None).unwrap();
        let mut compatible = FrameReassembler::new();
        assert!(compatible.feed(&packet).unwrap().is_some());

        let mut video = FrameReassembler::strict_video();
        assert_eq!(video.feed(&packet).unwrap(), None);
        let fragment = parse_fragment(&packet).unwrap();
        let prelude =
            crate::protocol::build_video_prelude(fragment.frame_id, 12, fragment.fragment_count);
        video.feed(&prelude).unwrap();
        assert!(video.feed(&packet).unwrap().is_some());
    }

    #[test]
    fn frame_reassembler_never_treats_raw_bytes_as_media() {
        assert_eq!(
            FrameReassembler::new().feed(b"not a LoLa fragment"),
            Err(MediaError::BadFragment)
        );
    }

    #[test]
    fn serial_order_handles_u32_wraparound() {
        assert!(serial_u32_is_newer(0, u32::MAX));
        assert!(serial_u32_is_newer(4, u32::MAX - 2));
        assert!(!serial_u32_is_newer(u32::MAX, 0));
        assert!(!serial_u32_is_newer(7, 7));
    }

    #[test]
    fn aggregate_capacity_uses_checked_max_active_product() {
        assert_eq!(buffered_capacity(2), MAX_MEDIA_FRAME_SIZE * 2);
        assert_eq!(buffered_capacity(usize::MAX), MAX_REASSEMBLY_BUFFERED_BYTES);
    }

    #[test]
    fn aggregate_buffer_limit_is_capped_at_the_session_budget() {
        let mut reassembler = MediaReassembler::with_limits(usize::MAX, REASSEMBLY_EXPIRY);
        assert_eq!(
            reassembler.max_buffered_bytes,
            MAX_REASSEMBLY_BUFFERED_BYTES
        );
        reassembler.max_buffered_bytes = 2;
        reassembler.begin(1, 3, 1).unwrap();
        assert!(matches!(
            reassembler.add(Fragment {
                frame_id: 1,
                fragment_count: 1,
                fragment_index: 0,
                original_offset: 0,
                fragment_length: 3,
                flags: 1,
                data: vec![1, 2, 3],
            }),
            Err(MediaError::BufferedLimitExceeded {
                received: 3,
                limit: 2,
            })
        ));
    }

    #[test]
    fn incomplete_policy_returns_only_sufficient_expired_coverage() {
        let mut reassembler = MediaReassembler::with_limits(1, Duration::from_secs(1));
        reassembler.begin(1, 10, 2).unwrap();
        reassembler
            .add(Fragment {
                frame_id: 1,
                fragment_count: 2,
                fragment_index: 0,
                original_offset: 0,
                fragment_length: 9,
                flags: 0,
                data: vec![7; 9],
            })
            .unwrap();
        reassembler.active.get_mut(&1).unwrap().touched = Instant::now() - Duration::from_secs(2);
        let partial = reassembler
            .take_expired_partial(10.0)
            .expect("90% coverage is displayable at a 10% threshold");
        assert_eq!(&partial[..9], &[7; 9]);
        assert_eq!(partial[9], 0);
    }
}
