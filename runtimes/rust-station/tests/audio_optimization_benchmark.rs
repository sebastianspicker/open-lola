use rusty_lola::audio::SoftwareAudio;
use rusty_lola::protocol::{build_audio_payload, AUDIO_UDP_PAYLOAD_SIZE};
use serde_json::{json, Value};
use std::alloc::{GlobalAlloc, Layout, System};
use std::hint::black_box;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::{Duration, Instant};

const WARMUPS: usize = 5;
const SAMPLES: usize = 31;

struct CountingAllocator;
static COUNTING: AtomicBool = AtomicBool::new(false);
static ALLOCATION_CALLS: AtomicU64 = AtomicU64::new(0);
static ALLOCATED_BYTES: AtomicU64 = AtomicU64::new(0);
static LIVE_BYTES: AtomicU64 = AtomicU64::new(0);
static PEAK_LIVE_BYTES: AtomicU64 = AtomicU64::new(0);

fn note_allocation(bytes: usize) {
    if !COUNTING.load(Ordering::Relaxed) {
        return;
    }
    ALLOCATION_CALLS.fetch_add(1, Ordering::Relaxed);
    ALLOCATED_BYTES.fetch_add(bytes as u64, Ordering::Relaxed);
    let live = LIVE_BYTES.fetch_add(bytes as u64, Ordering::Relaxed) + bytes as u64;
    PEAK_LIVE_BYTES.fetch_max(live, Ordering::Relaxed);
}

// SAFETY: every operation delegates to the system allocator with its original
// pointer and layout. Atomics only observe allocations while a benchmark lane
// explicitly enables counting outside its timing samples.
unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        // SAFETY: the caller's layout is forwarded unchanged.
        let pointer = unsafe { System.alloc(layout) };
        if !pointer.is_null() {
            note_allocation(layout.size());
        }
        pointer
    }

    unsafe fn dealloc(&self, pointer: *mut u8, layout: Layout) {
        if COUNTING.load(Ordering::Relaxed) {
            LIVE_BYTES.fetch_sub(layout.size() as u64, Ordering::Relaxed);
        }
        // SAFETY: the original pointer and layout are forwarded unchanged.
        unsafe { System.dealloc(pointer, layout) }
    }

    unsafe fn realloc(&self, pointer: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        // SAFETY: the original pointer/layout and requested size are forwarded.
        let resized = unsafe { System.realloc(pointer, layout, new_size) };
        if !resized.is_null() && COUNTING.load(Ordering::Relaxed) {
            ALLOCATION_CALLS.fetch_add(1, Ordering::Relaxed);
            ALLOCATED_BYTES.fetch_add(new_size as u64, Ordering::Relaxed);
            let live = if new_size >= layout.size() {
                LIVE_BYTES.fetch_add((new_size - layout.size()) as u64, Ordering::Relaxed)
                    + (new_size - layout.size()) as u64
            } else {
                LIVE_BYTES.fetch_sub((layout.size() - new_size) as u64, Ordering::Relaxed)
                    - (layout.size() - new_size) as u64
            };
            PEAK_LIVE_BYTES.fetch_max(live, Ordering::Relaxed);
        }
        resized
    }
}

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Work {
    operations: u64,
    bytes: u64,
    checksum: u64,
}

fn measure_allocations(mut run: impl FnMut() -> Work) -> (Work, u64, u64, u64) {
    ALLOCATION_CALLS.store(0, Ordering::Relaxed);
    ALLOCATED_BYTES.store(0, Ordering::Relaxed);
    LIVE_BYTES.store(0, Ordering::Relaxed);
    PEAK_LIVE_BYTES.store(0, Ordering::Relaxed);
    COUNTING.store(true, Ordering::SeqCst);
    let work = black_box(run());
    COUNTING.store(false, Ordering::SeqCst);
    (
        work,
        ALLOCATION_CALLS.load(Ordering::Relaxed),
        ALLOCATED_BYTES.load(Ordering::Relaxed),
        PEAK_LIVE_BYTES.load(Ordering::Relaxed),
    )
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

fn percentile(sorted: &[f64], percentile: f64) -> f64 {
    let index = ((sorted.len() as f64 * percentile).ceil() as usize)
        .saturating_sub(1)
        .min(sorted.len() - 1);
    sorted[index]
}

fn row(name: &str, samples: Vec<f64>, work: Work, memory: (Work, u64, u64, u64)) -> Value {
    assert_eq!(memory.0, work);
    let mean = samples.iter().sum::<f64>() / samples.len() as f64;
    let standard_deviation = (samples
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
        "stddev_us": standard_deviation,
        "allocation_calls": memory.1,
        "allocated_bytes": memory.2,
        "peak_live_bytes": memory.3,
        "work_operations": work.operations,
        "work_bytes": work.bytes,
        "checksum": work.checksum,
        "samples_us": samples,
    })
}

fn audio_payload_work() -> Work {
    const PACKETS: u32 = 8_192;
    let pcm = [0x5a; 256];
    let mut checksum = 0_u64;
    for sequence in 0..PACKETS {
        let packet = build_audio_payload(sequence, &pcm, None).expect("audio payload");
        checksum = checksum.wrapping_add(u64::from(packet[0x0c]));
        black_box(packet);
    }
    Work {
        operations: u64::from(PACKETS),
        bytes: u64::from(PACKETS) * AUDIO_UDP_PAYLOAD_SIZE as u64,
        checksum,
    }
}

fn software_capture_allocating() -> Work {
    const BLOCKS: u32 = 8_192;
    let mut audio = SoftwareAudio::default();
    audio.start();
    let mut checksum = 0_u64;
    let mut bytes = 0_u64;
    for _ in 0..BLOCKS {
        let pcm = audio.read_pcm();
        checksum = checksum.wrapping_add(u64::from(pcm[0]));
        bytes += pcm.len() as u64;
        black_box(pcm);
    }
    Work {
        operations: u64::from(BLOCKS),
        bytes,
        checksum,
    }
}

fn software_capture_buffered() -> Work {
    const BLOCKS: u32 = 8_192;
    let mut audio = SoftwareAudio::default();
    audio.start();
    let mut pcm = Vec::new();
    let mut checksum = 0_u64;
    let mut bytes = 0_u64;
    for _ in 0..BLOCKS {
        audio.read_pcm_into(&mut pcm);
        checksum = checksum.wrapping_add(u64::from(pcm[0]));
        bytes += pcm.len() as u64;
        black_box(&pcm);
    }
    Work {
        operations: u64::from(BLOCKS),
        bytes,
        checksum,
    }
}

fn wait_until_timeout(sleep: Option<Duration>) -> Work {
    let deadline = Instant::now() + Duration::from_micros(500);
    let mut polls = 0_u64;
    while Instant::now() < deadline {
        polls += 1;
        if let Some(duration) = sleep {
            std::thread::sleep(duration);
        } else {
            std::thread::yield_now();
        }
    }
    Work {
        operations: polls,
        bytes: 0,
        checksum: 0,
    }
}

fn wait_row(name: &str, sleep: Option<Duration>) -> Value {
    for _ in 0..WARMUPS {
        black_box(wait_until_timeout(sleep));
    }
    let mut samples = Vec::with_capacity(SAMPLES);
    let mut polls = Vec::with_capacity(SAMPLES);
    for _ in 0..SAMPLES {
        let started = Instant::now();
        let work = wait_until_timeout(sleep);
        samples.push(started.elapsed().as_secs_f64() * 1_000_000.0);
        polls.push(work.operations);
    }
    let mut sorted = samples.clone();
    sorted.sort_by(f64::total_cmp);
    polls.sort_unstable();
    json!({
        "workload": name,
        "warmups": WARMUPS,
        "samples": SAMPLES,
        "median_us": percentile(&sorted, 0.50),
        "p95_us": percentile(&sorted, 0.95),
        "p99_us": percentile(&sorted, 0.99),
        "median_poll_count": polls[SAMPLES / 2],
        "min_poll_count": polls[0],
        "max_poll_count": polls[SAMPLES - 1],
        "timeout_us": 500,
    })
}

#[test]
#[ignore = "manual release-mode audio optimization benchmark"]
fn audio_optimization_benchmarks() {
    let (payload_samples, payload_work) = sample(audio_payload_work);
    let (allocating_samples, allocating_work) = sample(software_capture_allocating);
    let (buffered_samples, buffered_work) = sample(software_capture_buffered);
    assert_eq!(allocating_work, buffered_work);
    let report = json!({
        "mode": "release",
        "timing_allocator_enabled": false,
        "memory_measured_separately": true,
        "rows": [
            row(
                "audio_payload_public_builder",
                payload_samples,
                payload_work,
                measure_allocations(audio_payload_work),
            ),
            row(
                "software_capture_allocating",
                allocating_samples,
                allocating_work,
                measure_allocations(software_capture_allocating),
            ),
            row(
                "software_capture_caller_buffered",
                buffered_samples,
                buffered_work,
                measure_allocations(software_capture_buffered),
            ),
            wait_row("callback_wait_yield_polling", None),
            wait_row(
                "callback_wait_bounded_50us_sleep",
                Some(Duration::from_micros(50)),
            ),
        ],
    });
    let output = std::env::var_os("RUSTY_LOLA_AUDIO_BENCHMARK_OUTPUT")
        .expect("set RUSTY_LOLA_AUDIO_BENCHMARK_OUTPUT to an external JSON path");
    std::fs::write(
        output,
        serde_json::to_vec_pretty(&report).expect("serialize benchmark"),
    )
    .expect("write benchmark report");
}
