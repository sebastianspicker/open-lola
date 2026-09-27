use rusty_lola::video::{encode_frame_jpeg, encode_jpeg};
use serde_json::{json, Value};
use std::alloc::{GlobalAlloc, Layout, System};
use std::hint::black_box;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::Instant;

const WARMUPS: usize = 5;
const SAMPLES: usize = 31;
const ENCODINGS: u64 = 16;

struct CountingAllocator;
static COUNTING: AtomicBool = AtomicBool::new(false);
static CALLS: AtomicU64 = AtomicU64::new(0);
static BYTES: AtomicU64 = AtomicU64::new(0);

// SAFETY: allocation operations are forwarded unchanged to the system
// allocator. Atomics observe requests only during the separate memory pass.
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
        // SAFETY: the original pointer, layout, and new size are forwarded.
        unsafe { System.realloc(pointer, layout, size) }
    }
}

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Work {
    operations: u64,
    encoded_bytes: u64,
    checksum: u64,
}

fn sample(mut run: impl FnMut() -> Work) -> (Vec<f64>, Work) {
    let expected = run();
    for _ in 1..WARMUPS {
        assert_eq!(run(), expected);
    }
    let mut samples = Vec::with_capacity(SAMPLES);
    for _ in 0..SAMPLES {
        let started = Instant::now();
        assert_eq!(black_box(run()), expected);
        samples.push(started.elapsed().as_secs_f64() * 1_000_000.0);
    }
    (samples, expected)
}

fn measure_allocations(mut run: impl FnMut() -> Work) -> (Work, u64, u64) {
    CALLS.store(0, Ordering::Relaxed);
    BYTES.store(0, Ordering::Relaxed);
    COUNTING.store(true, Ordering::SeqCst);
    let work = black_box(run());
    COUNTING.store(false, Ordering::SeqCst);
    (
        work,
        CALLS.load(Ordering::Relaxed),
        BYTES.load(Ordering::Relaxed),
    )
}

fn percentile(sorted: &[f64], value: f64) -> f64 {
    let index = ((sorted.len() as f64 * value).ceil() as usize)
        .saturating_sub(1)
        .min(sorted.len() - 1);
    sorted[index]
}

fn row(name: &str, mut run: impl FnMut() -> Work) -> Value {
    let (samples, work) = sample(&mut run);
    let (memory_work, calls, bytes) = measure_allocations(&mut run);
    assert_eq!(memory_work, work);
    let mean = samples.iter().sum::<f64>() / samples.len() as f64;
    let stddev = (samples
        .iter()
        .map(|sample| (sample - mean).powi(2))
        .sum::<f64>()
        / samples.len() as f64)
        .sqrt();
    let mut sorted = samples.clone();
    sorted.sort_by(f64::total_cmp);
    json!({
        "workload": name,
        "warmups": WARMUPS,
        "samples": SAMPLES,
        "median_us": percentile(&sorted, 0.50),
        "p95_us": percentile(&sorted, 0.95),
        "p99_us": percentile(&sorted, 0.99),
        "stddev_us": stddev,
        "allocation_calls": calls,
        "allocated_bytes": bytes,
        "work_operations": work.operations,
        "encoded_bytes": work.encoded_bytes,
        "checksum": work.checksum,
        "samples_us": samples,
    })
}

fn encoded_work(mut encode: impl FnMut() -> Vec<u8>) -> Work {
    let mut encoded_bytes = 0_u64;
    let mut checksum = 0_u64;
    for _ in 0..ENCODINGS {
        let jpeg = encode();
        encoded_bytes += jpeg.len() as u64;
        checksum = jpeg
            .iter()
            .fold(checksum, |sum, byte| sum.wrapping_add(u64::from(*byte)));
        black_box(jpeg);
    }
    Work {
        operations: ENCODINGS,
        encoded_bytes,
        checksum,
    }
}

#[test]
#[ignore = "manual isolated release-mode JPEG benchmark"]
fn jpeg_borrowed_view_benchmark() {
    let output_path = std::env::var("RUSTY_LOLA_JPEG_BENCHMARK_OUTPUT")
        .expect("set an external benchmark output path");
    let rgb = (0..640 * 360 * 3)
        .map(|value| (value * 37) as u8)
        .collect::<Vec<_>>();
    let gray = (0..640 * 360)
        .map(|value| (value * 19) as u8)
        .collect::<Vec<_>>();
    let report = json!({
        "rows": [
            row("rgb_borrowed_view", || encoded_work(|| {
                encode_jpeg(&rgb, 640, 360, "RGB", 83).expect("RGB JPEG")
            })),
            row("grayscale_frame_expansion", || encoded_work(|| {
                encode_frame_jpeg(&gray, 640, 360, "Mono8", 83).expect("grayscale JPEG")
            })),
        ]
    });
    std::fs::write(
        output_path,
        serde_json::to_vec_pretty(&report).expect("serialize benchmark"),
    )
    .expect("write benchmark output");
}
