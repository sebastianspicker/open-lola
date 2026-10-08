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
    parts_by_offset: BTreeMap<usize, Fragment>,
    fragment_indices: Vec<u64>,
    buffered_bytes: usize,
    touched: Instant,
}

#[derive(Debug)]
struct ValidatedFragment {
    received_bytes: usize,
}

#[derive(Debug)]
pub struct MediaReassembler {
    active: BTreeMap<u32, ActiveFrame>,
    pub allow_fragment_auto_begin: bool,
    max_active_frames: usize,
    max_buffered_bytes: usize,
    buffered_bytes: usize,
    expiry: Duration,
    evicted_older_frames: u64,
    /// The newest incomplete frame a later frame superseded, kept for
    /// `take_expired_partial` so the diagnostic incomplete-frame threshold
    /// still sees superseded frames. At most one frame is retained.
    superseded_partial: Option<ActiveFrame>,
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
            evicted_older_frames: 0,
            superseded_partial: None,
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
        self.evict_older_than(frame_id);
        if !self.active.contains_key(&frame_id) && self.active.len() >= self.max_active_frames {
            return Err(MediaError::TooManyActiveFrames);
        }
        self.remove_active(frame_id);
        self.active.insert(
            frame_id,
            ActiveFrame {
                expected_size,
                fragment_count,
                parts_by_offset: BTreeMap::new(),
                fragment_indices: fragment_index_bits(fragment_count),
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
        expired.extend(self.superseded_partial.take());
        expired.sort_by_key(|frame| std::cmp::Reverse(frame.touched));
        let required_coverage_pct = 100.0 - threshold_pct.clamp(0.0, 100.0);
        expired.into_iter().find_map(|frame| {
            let coverage_pct =
                frame.buffered_bytes as f64 * 100.0 / frame.expected_size.max(1) as f64;
            if frame.expected_size == 0 || coverage_pct < required_coverage_pct {
                return None;
            }
            let mut partial = vec![0; frame.expected_size];
            for part in frame.parts_by_offset.into_values() {
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
        self.superseded_partial = None;
        self.active.clear();
        self.buffered_bytes = 0;
    }
    /// Returns how many incomplete frames were dropped because a newer frame
    /// began or completed, and resets the counter.
    pub fn take_evicted_older_frames(&mut self) -> u64 {
        std::mem::take(&mut self.evicted_older_frames)
    }
    /// Drops every active frame that is serial-older than `frame_id`; a newer
    /// frame superseding them means their missing fragments are not coming.
    fn evict_older_than(&mut self, frame_id: u32) {
        let stale = self
            .active
            .keys()
            .copied()
            .filter(|id| serial_u32_is_newer(frame_id, *id))
            .collect::<Vec<_>>();
        for id in stale {
            let Some(frame) = self.active.remove(&id) else {
                continue;
            };
            self.buffered_bytes = self.buffered_bytes.saturating_sub(frame.buffered_bytes);
            self.evicted_older_frames += 1;
            if frame.buffered_bytes > 0
                && self
                    .superseded_partial
                    .as_ref()
                    .is_none_or(|kept| frame.touched >= kept.touched)
            {
                self.superseded_partial = Some(frame);
            }
        }
    }
    fn remove_active(&mut self, frame_id: u32) {
        if let Some(frame) = self.active.remove(&frame_id) {
            self.buffered_bytes = self.buffered_bytes.saturating_sub(frame.buffered_bytes);
        }
    }
    pub fn add(&mut self, fragment: Fragment) -> Result<Option<Vec<u8>>, MediaError> {
        self.expire();
        if !self.ensure_active_frame(&fragment)? {
            return Ok(None);
        }
        let frame_id = fragment.frame_id;
        let validated = self.validate_fragment(&fragment)?;
        if !self.store_fragment(fragment, validated) {
            return Ok(None);
        }
        self.complete_frame(frame_id).map(Some)
    }

    fn ensure_active_frame(&mut self, fragment: &Fragment) -> Result<bool, MediaError> {
        if self.active.contains_key(&fragment.frame_id) {
            return Ok(true);
        }
        if !self.allow_fragment_auto_begin {
            return Ok(false);
        }
        if fragment.fragment_count == 0 || fragment.fragment_count > MAX_MEDIA_FRAGMENT_COUNT {
            return Err(MediaError::InvalidFragmentCount(fragment.fragment_count));
        }
        self.evict_older_than(fragment.frame_id);
        if self.active.len() >= self.max_active_frames {
            return Err(MediaError::TooManyActiveFrames);
        }
        self.active.insert(
            fragment.frame_id,
            ActiveFrame {
                expected_size: 0,
                fragment_count: fragment.fragment_count,
                parts_by_offset: BTreeMap::new(),
                fragment_indices: fragment_index_bits(fragment.fragment_count),
                buffered_bytes: 0,
                touched: Instant::now(),
            },
        );
        Ok(true)
    }

    fn validate_fragment(&self, fragment: &Fragment) -> Result<ValidatedFragment, MediaError> {
        let frame = self.active.get(&fragment.frame_id).expect("inserted");
        validate_fragment_shape(frame, fragment)?;
        let end = fragment_end(fragment)?;
        if end > MAX_MEDIA_FRAME_SIZE {
            return Err(MediaError::InvalidFrameSize(end));
        }
        if frame.expected_size != 0 && end > frame.expected_size {
            return Err(MediaError::FragmentExceeds(end, frame.expected_size));
        }
        if fragment_index_is_set(&frame.fragment_indices, fragment.fragment_index) {
            return Err(MediaError::DuplicateFragment(fragment.fragment_index));
        }
        let start = fragment.original_offset as usize;
        if fragment_overlaps(frame, start, end) {
            return Err(MediaError::FragmentOverlap(start));
        }
        let received_bytes = self.buffered_bytes.checked_add(fragment.data.len()).ok_or(
            MediaError::BufferedLimitExceeded {
                received: usize::MAX,
                limit: self.max_buffered_bytes,
            },
        )?;
        if received_bytes > self.max_buffered_bytes {
            return Err(MediaError::BufferedLimitExceeded {
                received: received_bytes,
                limit: self.max_buffered_bytes,
            });
        }
        Ok(ValidatedFragment { received_bytes })
    }

    fn store_fragment(&mut self, fragment: Fragment, validated: ValidatedFragment) -> bool {
        let frame = self.active.get_mut(&fragment.frame_id).expect("inserted");
        frame.touched = Instant::now();
        frame.buffered_bytes += fragment.data.len();
        self.buffered_bytes = validated.received_bytes;
        let offset = fragment.original_offset as usize;
        set_fragment_index(&mut frame.fragment_indices, fragment.fragment_index);
        frame.parts_by_offset.insert(offset, fragment);
        frame.parts_by_offset.len() == frame.fragment_count as usize
    }

    fn complete_frame(&mut self, frame_id: u32) -> Result<Vec<u8>, MediaError> {
        let frame = self.active.remove(&frame_id).expect("active frame");
        self.buffered_bytes = self.buffered_bytes.saturating_sub(frame.buffered_bytes);
        self.evict_older_than(frame_id);
        let expected = resolved_expected_size(&frame);
        validate_reassembly_shape(expected, frame.fragment_count)?;
        assemble_frame(frame, expected)
    }
}

fn validate_fragment_shape(frame: &ActiveFrame, fragment: &Fragment) -> Result<(), MediaError> {
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
    Ok(())
}

fn fragment_end(fragment: &Fragment) -> Result<usize, MediaError> {
    (fragment.original_offset as usize)
        .checked_add(fragment.data.len())
        .ok_or(MediaError::InvalidFrameSize(usize::MAX))
}

fn fragment_overlaps(frame: &ActiveFrame, start: usize, end: usize) -> bool {
    let overlaps_predecessor = frame
        .parts_by_offset
        .range(..=start)
        .next_back()
        .is_some_and(|(part_start, part)| *part_start + part.data.len() > start);
    let overlaps_successor = frame
        .parts_by_offset
        .range(start..)
        .next()
        .is_some_and(|(part_start, _)| *part_start < end);
    overlaps_predecessor || overlaps_successor
}

fn fragment_index_bits(fragment_count: u32) -> Vec<u64> {
    vec![0; (fragment_count as usize).div_ceil(u64::BITS as usize)]
}

fn fragment_index_is_set(bits: &[u64], index: u32) -> bool {
    let index = index as usize;
    bits[index / u64::BITS as usize] & (1 << (index % u64::BITS as usize)) != 0
}

fn set_fragment_index(bits: &mut [u64], index: u32) {
    let index = index as usize;
    bits[index / u64::BITS as usize] |= 1 << (index % u64::BITS as usize);
}

fn resolved_expected_size(frame: &ActiveFrame) -> usize {
    if frame.expected_size != 0 {
        return frame.expected_size;
    }
    frame
        .parts_by_offset
        .last_key_value()
        .map(|(offset, part)| *offset + part.data.len())
        .unwrap_or(0)
}

fn assemble_frame(frame: ActiveFrame, expected: usize) -> Result<Vec<u8>, MediaError> {
    let mut cursor = 0;
    let mut out = vec![0; expected];
    for (start, part) in frame.parts_by_offset {
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
    Ok(out)
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
    pub fn take_evicted_older_frames(&mut self) -> u64 {
        self.inner.take_evicted_older_frames()
    }
    pub fn take_expired_partial(&mut self, threshold_pct: f64) -> Option<Vec<u8>> {
        self.inner.take_expired_partial(threshold_pct)
    }
}

#[cfg(test)]
mod tests;
