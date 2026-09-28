use super::*;

#[test]
fn fragment_index_bits_cover_word_and_declared_count_boundaries() {
    let mut bits = fragment_index_bits(MAX_MEDIA_FRAGMENT_COUNT);
    assert_eq!(bits.len(), MAX_MEDIA_FRAGMENT_COUNT as usize / 64);

    for index in [0, 63, 64, MAX_MEDIA_FRAGMENT_COUNT - 1] {
        assert!(!fragment_index_is_set(&bits, index));
        set_fragment_index(&mut bits, index);
        assert!(fragment_index_is_set(&bits, index));
    }
    assert!(!fragment_index_is_set(&bits, 62));
    assert!(!fragment_index_is_set(&bits, 65));
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
                fragment_index: 0,
                original_offset: 2,
                fragment_length: 2,
                flags: 1,
                data: vec![3, 4],
            })
            .unwrap_err(),
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
fn reordered_fragments_reassemble_by_original_offset() {
    let mut reassembler = MediaReassembler::new();
    reassembler.begin(9, 4, 2).unwrap();
    assert_eq!(
        reassembler
            .add(Fragment {
                frame_id: 9,
                fragment_count: 2,
                fragment_index: 1,
                original_offset: 2,
                fragment_length: 2,
                flags: 0,
                data: vec![3, 4],
            })
            .unwrap(),
        None
    );
    assert_eq!(
        reassembler
            .add(Fragment {
                frame_id: 9,
                fragment_count: 2,
                fragment_index: 0,
                original_offset: 0,
                fragment_length: 2,
                flags: 0,
                data: vec![1, 2],
            })
            .unwrap(),
        Some(vec![1, 2, 3, 4])
    );
}

#[test]
fn representative_fragment_counts_reassemble_deterministically() {
    for count in [1_u32, 2, 64] {
        let mut reassembler = MediaReassembler::new();
        reassembler.begin(count, count as usize, count).unwrap();
        let mut complete = None;
        for index in (0..count).rev() {
            complete = reassembler
                .add(Fragment {
                    frame_id: count,
                    fragment_count: count,
                    fragment_index: index,
                    original_offset: index,
                    fragment_length: 1,
                    flags: u8::from(index + 1 == count),
                    data: vec![index as u8],
                })
                .unwrap();
        }
        let frame = complete.expect("final fragment completes the frame");
        assert_eq!(
            frame,
            (0..count).map(|index| index as u8).collect::<Vec<_>>()
        );
    }
}

#[test]
fn offset_neighbors_allow_adjacency_and_reject_successor_overlap() {
    let mut adjacent = MediaReassembler::new();
    adjacent.begin(10, 6, 3).unwrap();
    for (index, offset, data) in [(0, 2, vec![3, 4]), (1, 0, vec![1, 2]), (2, 4, vec![5, 6])] {
        let complete = adjacent
            .add(Fragment {
                frame_id: 10,
                fragment_count: 3,
                fragment_index: index,
                original_offset: offset,
                fragment_length: data.len() as u32,
                flags: 0,
                data,
            })
            .unwrap();
        if index == 2 {
            assert_eq!(complete, Some(vec![1, 2, 3, 4, 5, 6]));
        }
    }

    let mut overlap = MediaReassembler::new();
    overlap.begin(11, 6, 2).unwrap();
    overlap
        .add(Fragment {
            frame_id: 11,
            fragment_count: 2,
            fragment_index: 0,
            original_offset: 2,
            fragment_length: 2,
            flags: 0,
            data: vec![3, 4],
        })
        .unwrap();
    let error = overlap
        .add(Fragment {
            frame_id: 11,
            fragment_count: 2,
            fragment_index: 1,
            original_offset: 0,
            fragment_length: 3,
            flags: 0,
            data: vec![1, 2, 3],
        })
        .unwrap_err();
    assert_eq!(error, MediaError::FragmentOverlap(0));
}

#[test]
fn maximum_fragment_count_reassembles_in_reverse_offset_order() {
    let count = MAX_MEDIA_FRAGMENT_COUNT;
    let mut reassembler = MediaReassembler::new();
    reassembler.begin(12, count as usize, count).unwrap();
    let mut complete = None;
    for index in (0..count).rev() {
        complete = reassembler
            .add(Fragment {
                frame_id: 12,
                fragment_count: count,
                fragment_index: index,
                original_offset: index,
                fragment_length: 1,
                flags: u8::from(index + 1 == count),
                data: vec![(index % 251) as u8],
            })
            .unwrap();
    }
    let frame = complete.expect("last fragment completes maximum-count frame");
    assert_eq!(frame.len(), count as usize);
    assert_eq!(frame[0], 0);
    assert_eq!(frame[10_000], (10_000 % 251) as u8);
    assert_eq!(frame[count as usize - 1], ((count - 1) % 251) as u8);
}
