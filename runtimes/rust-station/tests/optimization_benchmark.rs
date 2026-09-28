use rusty_lola::protocol::{
    build_video_payloads, Fragment, FrameReassembler, MediaReassembler, MAX_MEDIA_FRAGMENT_COUNT,
};
use std::alloc::{GlobalAlloc, Layout, System};
use std::hint::black_box;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::Instant;

struct CountingAllocator;
static COUNT_ALLOCATIONS: AtomicBool = AtomicBool::new(false);
static ALLOC_CALLS: AtomicU64 = AtomicU64::new(0);
static ALLOC_BYTES: AtomicU64 = AtomicU64::new(0);

// SAFETY: every operation delegates to the system allocator with the original
// pointer and layout; the atomics only observe allocation counts and sizes.
unsafe impl GlobalAlloc for CountingAllocator {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        if COUNT_ALLOCATIONS.load(Ordering::Relaxed) {
            ALLOC_CALLS.fetch_add(1, Ordering::Relaxed);
            ALLOC_BYTES.fetch_add(layout.size() as u64, Ordering::Relaxed);
        }
        // SAFETY: The caller supplies a valid layout, forwarded unchanged to System.
        unsafe { System.alloc(layout) }
    }

    unsafe fn dealloc(&self, ptr: *mut u8, layout: Layout) {
        // SAFETY: The original System pointer and allocation layout are forwarded unchanged.
        unsafe { System.dealloc(ptr, layout) }
    }

    unsafe fn realloc(&self, ptr: *mut u8, layout: Layout, new_size: usize) -> *mut u8 {
        if COUNT_ALLOCATIONS.load(Ordering::Relaxed) {
            ALLOC_CALLS.fetch_add(1, Ordering::Relaxed);
            ALLOC_BYTES.fetch_add(new_size as u64, Ordering::Relaxed);
        }
        // SAFETY: The original System pointer, layout, and valid new size are forwarded unchanged.
        unsafe { System.realloc(ptr, layout, new_size) }
    }
}

#[global_allocator]
static GLOBAL: CountingAllocator = CountingAllocator;

#[derive(Clone, Copy)]
struct AllocationSnapshot {
    calls: u64,
    bytes: u64,
}

fn allocations() -> AllocationSnapshot {
    AllocationSnapshot {
        calls: ALLOC_CALLS.load(Ordering::Relaxed),
        bytes: ALLOC_BYTES.load(Ordering::Relaxed),
    }
}

fn shuffled_order(len: usize, mut seed: u64) -> Vec<usize> {
    let mut order: Vec<_> = (0..len).collect();
    for index in (1..len).rev() {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        order.swap(index, seed as usize % (index + 1));
    }
    order
}

fn percentile(values: &[f64], pct: f64) -> f64 {
    let mut sorted = values.to_vec();
    sorted.sort_by(f64::total_cmp);
    let index = ((sorted.len() as f64 * pct).ceil() as usize)
        .saturating_sub(1)
        .min(sorted.len() - 1);
    sorted[index]
}

fn report(
    name: &str,
    samples: &[f64],
    work: &str,
    before: AllocationSnapshot,
    after: AllocationSnapshot,
) {
    let mean = samples.iter().sum::<f64>() / samples.len() as f64;
    let variance = samples
        .iter()
        .map(|sample| (sample - mean).powi(2))
        .sum::<f64>()
        / samples.len() as f64;
    let standard_deviation = variance.sqrt();
    let raw_samples = samples
        .iter()
        .map(|sample| format!("{sample:.6}"))
        .collect::<Vec<_>>()
        .join(",");
    println!(
        "{{\"workload\":\"{name}\",\"samples\":{},\"median_ms\":{:.6},\"p95_ms\":{:.6},\"p99_ms\":{:.6},\"min_ms\":{:.6},\"max_ms\":{:.6},\"stddev_ms\":{standard_deviation:.6},\"cv_pct\":{:.3},\"work\":\"{work}\",\"alloc_calls\":{},\"alloc_bytes\":{},\"samples_ms\":[{raw_samples}]}}",
        samples.len(),
        percentile(samples, 0.5),
        percentile(samples, 0.95),
        percentile(samples, 0.99),
        samples.iter().copied().fold(f64::INFINITY, f64::min),
        samples.iter().copied().fold(f64::NEG_INFINITY, f64::max),
        standard_deviation / mean * 100.0,
        after.calls - before.calls,
        after.bytes - before.bytes,
    );
}

fn benchmark_reassembly(shuffled: bool) {
    const FRAME_BYTES: usize = 1024 * 1024;
    const FRAMES_PER_SAMPLE: usize = 3;
    const WARMUP: usize = 5;
    const REPEATS: usize = 31;
    const SEED: u64 = 0x4c4f_4c41_3230_3236;
    let payload: Vec<u8> = (0..FRAME_BYTES).map(|index| index as u8).collect();
    let packets = build_video_payloads(17, &payload, Some(99), 1400);
    let order = if shuffled {
        shuffled_order(packets.len() - 1, SEED)
    } else {
        (0..packets.len() - 1).collect()
    };
    let mut samples = Vec::with_capacity(REPEATS);
    let mut before = allocations();
    for sample in 0..=WARMUP + REPEATS {
        if sample == WARMUP + REPEATS {
            before = allocations();
            COUNT_ALLOCATIONS.store(true, Ordering::Relaxed);
        }
        let started = Instant::now();
        for _ in 0..FRAMES_PER_SAMPLE {
            let mut reassembler = FrameReassembler::strict_video();
            reassembler.feed(&packets[0]).unwrap();
            for &index in &order {
                if let Some(frame) = reassembler.feed(&packets[index + 1]).unwrap() {
                    black_box(frame);
                }
            }
        }
        if (WARMUP..WARMUP + REPEATS).contains(&sample) {
            samples.push(started.elapsed().as_secs_f64() * 1000.0);
        }
    }
    COUNT_ALLOCATIONS.store(false, Ordering::Relaxed);
    report(
        if shuffled {
            "reassembly_shuffled"
        } else {
            "reassembly_in_order"
        },
        &samples,
        &format!(
            "{} frames x {FRAME_BYTES} bytes; {} fragments/frame; seed={SEED}",
            REPEATS * FRAMES_PER_SAMPLE,
            packets.len() - 1
        ),
        before,
        allocations(),
    );
}

fn benchmark_max_fragments(shuffled: bool) {
    const WARMUP: usize = 5;
    const REPEATS: usize = 31;
    const SEED: u64 = 0x4c4f_4c41_3230_3236;
    let count = MAX_MEDIA_FRAGMENT_COUNT as usize;
    let order = if shuffled {
        shuffled_order(count, SEED)
    } else {
        (0..count).collect()
    };
    let mut samples = Vec::with_capacity(REPEATS);
    let mut before = allocations();
    for sample in 0..=WARMUP + REPEATS {
        if sample == WARMUP + REPEATS {
            before = allocations();
            COUNT_ALLOCATIONS.store(true, Ordering::Relaxed);
        }
        let started = Instant::now();
        let mut reassembler = MediaReassembler::new();
        reassembler.begin(101, count, count as u32).unwrap();
        let mut completed = None;
        for &index in &order {
            completed = reassembler
                .add(Fragment {
                    frame_id: 101,
                    fragment_count: count as u32,
                    fragment_index: index as u32,
                    original_offset: index as u32,
                    fragment_length: 1,
                    flags: u8::from(index + 1 == count),
                    data: vec![(index % 251) as u8],
                })
                .unwrap();
        }
        black_box(completed.expect("maximum fragment frame"));
        if (WARMUP..WARMUP + REPEATS).contains(&sample) {
            samples.push(started.elapsed().as_secs_f64() * 1000.0);
        }
    }
    COUNT_ALLOCATIONS.store(false, Ordering::Relaxed);
    report(
        if shuffled {
            "reassembly_max_16384_shuffled"
        } else {
            "reassembly_max_16384_in_order"
        },
        &samples,
        &format!("{REPEATS} frames x {count} one-byte fragments; seed={SEED}"),
        before,
        allocations(),
    );
}

fn benchmark_packetization(name: &str, frame_bytes: usize, frames_per_sample: usize) {
    const WARMUP: usize = 5;
    const REPEATS: usize = 31;
    let payload: Vec<u8> = (0..frame_bytes).map(|index| index as u8).collect();
    let mut samples = Vec::with_capacity(REPEATS);
    let mut before = allocations();
    for sample in 0..=WARMUP + REPEATS {
        if sample == WARMUP + REPEATS {
            before = allocations();
            COUNT_ALLOCATIONS.store(true, Ordering::Relaxed);
        }
        let started = Instant::now();
        for frame_id in 0..frames_per_sample as u32 {
            black_box(build_video_payloads(frame_id, &payload, None, 1400));
        }
        if (WARMUP..WARMUP + REPEATS).contains(&sample) {
            samples.push(started.elapsed().as_secs_f64() * 1000.0);
        }
    }
    COUNT_ALLOCATIONS.store(false, Ordering::Relaxed);
    report(
        name,
        &samples,
        &format!(
            "{} frames x {frame_bytes} bytes; packet_size=1400",
            REPEATS * frames_per_sample
        ),
        before,
        allocations(),
    );
}

#[test]
#[ignore = "manual release-mode optimization benchmark"]
fn rust_hot_path_benchmarks() {
    println!("{{\"warmup\":5,\"repeats\":31,\"allocation_samples\":1,\"allocation_timing_separate\":true,\"seed\":\"0x4c4f4c4132303236\"}}");
    benchmark_reassembly(false);
    benchmark_reassembly(true);
    benchmark_max_fragments(false);
    benchmark_max_fragments(true);
    benchmark_packetization("video_packetization_64x64_bgra", 64 * 64 * 4, 100);
    benchmark_packetization("video_packetization_1080p_mono8", 1920 * 1080, 2);
    benchmark_packetization("video_packetization_1080p_bgra", 1920 * 1080 * 4, 1);
}
