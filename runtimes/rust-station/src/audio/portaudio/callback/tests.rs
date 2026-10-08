use super::*;
use crate::test_alloc::{measure_allocations, samples, timing_json};
use std::hint::black_box;

#[test]
fn callback_ring_preserves_fifo_order() {
    let ring = CallbackRing::new(3, 2).expect("create ring");
    for block in [[1, 2], [3, 4], [5, 6]] {
        assert!(!ring.push_from_ptr(block.as_ptr()));
    }

    let mut output = [0; 2];
    for expected in [[1, 2], [3, 4], [5, 6]] {
        assert!(ring.pop_into(&mut output).expect("buffered capture"));
        assert_eq!(output, expected);
    }
    assert!(!ring.pop_into(&mut output).expect("empty capture"));
}

#[test]
fn callback_ring_discards_oldest_block_when_full() {
    let ring = CallbackRing::new(2, 1).expect("create ring");
    for (block, discarded) in [([10], false), ([20], false), ([30], true)] {
        assert_eq!(ring.push_from_ptr(block.as_ptr()), discarded);
    }

    let mut output = [0];
    for expected in [[20], [30]] {
        assert!(ring.pop_into(&mut output).expect("buffered capture"));
        assert_eq!(output, expected);
    }
    assert_eq!(ring.queued_blocks(), 0);
}

#[test]
fn callback_ring_producer_drops_instead_of_spinning_on_a_held_slot() {
    let ring = CallbackRing::new(2, 1).expect("create ring");
    assert!(!ring.push_from_ptr([1].as_ptr()));
    assert!(!ring.push_from_ptr([2].as_ptr()));
    // The session thread has claimed the oldest block but not yet released it.
    let held = ring.claim_consumer_slot().expect("claim oldest block");

    // The full ring cannot free the held slot: one reported drop, no hang.
    assert!(ring.push_from_ptr([3].as_ptr()));
    assert_eq!(ring.queued_blocks(), 0);

    ring.release_consumer_slot(held.0, held.1);
    assert!(!ring.push_from_ptr([4].as_ptr()));
    let mut output = [0];
    assert!(ring.pop_into(&mut output).expect("buffered capture"));
    assert_eq!(output, [4]);
}

#[test]
fn callback_ring_pop_into_reuses_caller_storage_without_changing_bytes() {
    let ring = CallbackRing::new(2, 4).expect("create ring");
    let first = [1, 2, 3, 4];
    let second = [5, 6, 7, 8];
    assert!(!ring.push_from_ptr(first.as_ptr()));
    assert!(!ring.push_from_ptr(second.as_ptr()));
    let mut block = vec![0; 4];
    let storage = block.as_ptr();

    assert!(ring.pop_into(&mut block).expect("first block"));
    assert_eq!(block, first);
    assert_eq!(block.as_ptr(), storage);
    assert!(ring.pop_into(&mut block).expect("second block"));
    assert_eq!(block, second);
    assert_eq!(block.as_ptr(), storage);
    assert!(!ring.pop_into(&mut block).expect("empty ring"));
}

#[test]
fn callback_ring_rejects_wrong_caller_buffer_without_consuming_block() {
    let ring = CallbackRing::new(1, 2).expect("create ring");
    let source = [9, 10];
    assert!(!ring.push_from_ptr(source.as_ptr()));
    let error = ring.pop_into(&mut [0]).expect_err("wrong buffer length");
    assert!(matches!(
        error,
        PortAudioError::InvalidPayload {
            expected: 2,
            actual: 1
        }
    ));
    let mut destination = [0; 2];
    assert!(ring.pop_into(&mut destination).expect("queued block"));
    assert_eq!(destination, source);
}

#[test]
#[ignore = "manual release-mode callback ring benchmark"]
fn callback_ring_has_zero_steady_state_allocations() {
    const OPERATIONS: u64 = 8_192;
    let output_path = std::env::var("RUSTY_LOLA_CALLBACK_BENCHMARK_OUTPUT")
        .expect("set an external benchmark output path");
    let ring = CallbackRing::new(8, 256).expect("create ring");
    let source = vec![0x5a; 256];
    let mut destination = vec![0; 256];
    let mut run = || {
        let mut bytes = 0_u64;
        let mut checksum = 0_u64;
        for _ in 0..OPERATIONS {
            assert!(!ring.push_from_ptr(source.as_ptr()));
            assert!(ring.pop_into(&mut destination).expect("capture block"));
            bytes += destination.len() as u64;
            checksum = checksum.wrapping_add(u64::from(destination[0]));
            black_box(&destination);
        }
        (OPERATIONS, bytes, checksum)
    };
    let (elapsed, work) = samples(&mut run);
    let (measured_work, memory) = measure_allocations(&mut run);
    assert_eq!(measured_work, work);
    assert_eq!(memory.calls, 0);
    assert_eq!(memory.bytes, 0);
    let report = serde_json::json!({
        "workload": "callback_ring_caller_buffered",
        "timing": timing_json(elapsed),
        "memory": {"allocation_calls": memory.calls, "allocated_bytes": memory.bytes},
        "work": {"operations": work.0, "bytes": work.1, "checksum": work.2},
    });
    std::fs::write(
        output_path,
        serde_json::to_vec_pretty(&report).expect("serialize benchmark"),
    )
    .expect("write benchmark output");
}

#[test]
fn one_slot_ring_distinguishes_unread_and_consumer_owned_blocks() {
    let ring = CallbackRing::new(1, 2).unwrap();
    assert!(!ring.push_from_ptr([1, 2].as_ptr()));
    assert!(
        ring.push_from_ptr([3, 4].as_ptr()),
        "unread block is replaced"
    );
    assert_eq!(ring.queued_blocks(), 1);
    let held = ring.claim_consumer_slot().unwrap();
    assert!(
        ring.push_from_ptr([5, 6].as_ptr()),
        "held block is never overwritten"
    );
    let mut output = [0; 2];
    // SAFETY: this test owns the claimed slot until the explicit release below.
    unsafe {
        std::ptr::copy_nonoverlapping(held.0.data.as_ptr().cast::<u8>(), output.as_mut_ptr(), 2);
    }
    assert_eq!(output, [3, 4]);
    ring.release_consumer_slot(held.0, held.1);
    assert!(!ring.push_from_ptr([7, 8].as_ptr()));
    assert!(ring.pop_into(&mut output).unwrap());
    assert_eq!(output, [7, 8]);
}

#[test]
fn callback_ring_sequence_arithmetic_wraps_without_overflow() {
    let ring = CallbackRing::new(2, 1).unwrap();
    let position = usize::MAX - 1;
    ring.enqueue.store(position, Ordering::Relaxed);
    ring.dequeue.store(position, Ordering::Relaxed);
    for offset in 0..2 {
        let next = position.wrapping_add(offset);
        ring.slots[next % 2]
            .sequence
            .store(next.wrapping_mul(2), Ordering::Relaxed);
    }
    for value in [1, 2, 3, 4] {
        assert!(!ring.push_from_ptr([value].as_ptr()));
        assert_eq!(ring.queued_blocks(), 1);
        let mut output = [0];
        assert!(ring.pop_into(&mut output).unwrap());
        assert_eq!(output, [value]);
    }
    assert_eq!(ring.queued_blocks(), 0);
}
