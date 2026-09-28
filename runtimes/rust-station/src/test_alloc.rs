//! Shared allocation and timing support for ignored release-mode unit benches.

use std::alloc::{GlobalAlloc, Layout, System};
use std::fmt::Debug;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::Instant;

const WARMUPS: usize = 5;
const SAMPLES: usize = 31;

struct CountingAllocator;
static COUNTING: AtomicBool = AtomicBool::new(false);
static CALLS: AtomicU64 = AtomicU64::new(0);
static BYTES: AtomicU64 = AtomicU64::new(0);

// SAFETY: all operations delegate to the system allocator with unchanged
// pointers and layouts. The gated atomics observe requested allocation work.
unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        if COUNTING.load(Ordering::Relaxed) {
            CALLS.fetch_add(1, Ordering::Relaxed);
            BYTES.fetch_add(layout.size() as u64, Ordering::Relaxed);
        }
        // SAFETY: the caller's layout is forwarded unchanged.
        unsafe { System.alloc(layout) }
    }

    unsafe fn dealloc(&self, pointer: *mut u8, layout: Layout) {
        // SAFETY: the original pointer and layout are forwarded unchanged.
        unsafe { System.dealloc(pointer, layout) }
    }

    unsafe fn realloc(&self, pointer: *mut u8, layout: Layout, size: usize) -> *mut u8 {
        if COUNTING.load(Ordering::Relaxed) {
            CALLS.fetch_add(1, Ordering::Relaxed);
            BYTES.fetch_add(size as u64, Ordering::Relaxed);
        }
        // SAFETY: the original pointer/layout and requested size are forwarded.
        unsafe { System.realloc(pointer, layout, size) }
    }
}

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct AllocationSnapshot {
    pub(crate) calls: u64,
    pub(crate) bytes: u64,
}

pub(crate) fn measure_allocations<T>(run: impl FnOnce() -> T) -> (T, AllocationSnapshot) {
    CALLS.store(0, Ordering::Relaxed);
    BYTES.store(0, Ordering::Relaxed);
    COUNTING.store(true, Ordering::SeqCst);
    let result = run();
    COUNTING.store(false, Ordering::SeqCst);
    (
        result,
        AllocationSnapshot {
            calls: CALLS.load(Ordering::Relaxed),
            bytes: BYTES.load(Ordering::Relaxed),
        },
    )
}

pub(crate) fn samples<T>(mut run: impl FnMut() -> T) -> (Vec<f64>, T)
where
    T: Copy + Debug + Eq,
{
    let expected = run();
    for _ in 1..WARMUPS {
        assert_eq!(run(), expected);
    }
    let mut elapsed = Vec::with_capacity(SAMPLES);
    for _ in 0..SAMPLES {
        let started = Instant::now();
        assert_eq!(run(), expected);
        elapsed.push(started.elapsed().as_secs_f64() * 1_000_000.0);
    }
    (elapsed, expected)
}

pub(crate) fn timing_json(samples: Vec<f64>) -> serde_json::Value {
    let mean = samples.iter().sum::<f64>() / samples.len() as f64;
    let standard_deviation = (samples
        .iter()
        .map(|sample| (sample - mean).powi(2))
        .sum::<f64>()
        / samples.len() as f64)
        .sqrt();
    let mut sorted = samples.clone();
    sorted.sort_by(f64::total_cmp);
    let percentile = |value: f64| {
        let index = ((sorted.len() as f64 * value).ceil() as usize)
            .saturating_sub(1)
            .min(sorted.len() - 1);
        sorted[index]
    };
    serde_json::json!({
        "warmups": WARMUPS,
        "samples": SAMPLES,
        "median_us": percentile(0.50),
        "p95_us": percentile(0.95),
        "p99_us": percentile(0.99),
        "stddev_us": standard_deviation,
        "samples_us": samples,
    })
}
