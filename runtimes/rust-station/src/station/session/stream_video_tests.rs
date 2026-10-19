use super::*;
use crate::protocol::StreamingVideoFragments;
use crate::station::session::scheduler::{PreparedVideoFrame, VideoTxCursor};

fn cursor(started: bool) -> VideoTxCursor {
    let fragments = StreamingVideoFragments::new(1, &[0; 1000], None, 128);
    let mut cursor = VideoTxCursor::new(PreparedVideoFrame::new(1, fragments));
    if started {
        assert!(!cursor.sent_one(), "the frame must stay partly sent");
    }
    cursor
}

/// A fragmented frame already on the wire is finished however long it takes;
/// dropping it for age left a 1280x720 stream with no complete frame at all.
#[test]
fn only_a_frame_with_nothing_sent_expires_for_age() {
    for (started, dropped) in [(false, 1), (true, 0)] {
        let mut phase =
            StreamPhase::new(Duration::from_millis(3), Duration::from_millis(16), None, 3);
        phase.cursor = Some(cursor(started));
        phase.expire_stale_video(Instant::now() + Duration::from_secs(5));
        assert_eq!(phase.cursor.is_none(), dropped == 1, "started {started}");
        assert_eq!(phase.scheduler.counters.video_deadline_drops, dropped);
    }
}
