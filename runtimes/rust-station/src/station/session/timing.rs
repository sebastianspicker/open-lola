//! Fixed-storage scheduler observation buckets; never hardware latency claims.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub(super) struct TimingHistogram {
    counts: [u64; 14],
    samples: u64,
}
const UPPER_US: [u64; 14] = [
    0,
    25,
    50,
    100,
    250,
    500,
    1000,
    2000,
    5000,
    10000,
    50000,
    100000,
    1000000,
    u64::MAX,
];
impl TimingHistogram {
    pub(super) fn observe(&mut self, microseconds: u64) {
        let bucket = UPPER_US
            .iter()
            .position(|upper| microseconds <= *upper)
            .unwrap_or(13);
        self.counts[bucket] += 1;
        self.samples += 1;
    }
    pub(super) fn p95_upper_us(&self) -> Option<u64> {
        if self.samples == 0 {
            return None;
        }
        let target = self.samples - self.samples / 20;
        let mut total = 0;
        for (count, upper) in self.counts.iter().zip(UPPER_US) {
            total += count;
            if total >= target {
                return Some(upper);
            }
        }
        None
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn missing_observations_and_bucket_percentiles_remain_distinct() {
        let mut histogram = TimingHistogram::default();
        assert_eq!(histogram.p95_upper_us(), None);
        for _ in 0..19 {
            histogram.observe(26);
        }
        histogram.observe(6000);
        assert_eq!(histogram.p95_upper_us(), Some(50));
        histogram.observe(6000);
        assert_eq!(histogram.p95_upper_us(), Some(10000));
    }
}
