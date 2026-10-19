# Linux V4L2 video capture

The Rust station captures video on Linux through V4L2, using the single-planar
streaming API with memory-mapped buffers. Device inventory also reports
multi-planar devices and their modes, but opening a multi-planar-only device
fails, because the capture pipeline expects one packed image plane.

Capture follows the kernel's
[memory-mapped streaming procedure](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/mmap.html):
request buffers, query and map each one, queue them all, start streaming,
dequeue a filled buffer, queue it again after processing, stop streaming, and
unmap.

## How capture works

`V4l2Camera::open` opens the device read/write with `O_NONBLOCK`, requires
`V4L2_CAP_VIDEO_CAPTURE` and `V4L2_CAP_STREAMING`, and sets the requested mode.
The driver must accept the exact width, height, pixel FourCC, and frame
interval. If the driver substitutes anything, open fails with a negotiation
mismatch instead of changing the session.

The backend requests four MMAP buffers and accepts two to four, with at most
1 GiB mapped in total. Waiting for a frame times out after a period derived
from the frame rate. Polling runs in 25 ms slices, so a cancel from another
thread ends a pending grab quickly. Every dequeued buffer with a valid index is
queued again, even when the driver flags it as erroneous or validation or
conversion fails.

Supported input formats:

| V4L2 FourCC | Station output |
|---|---|
| `RGB3` | packed `RGB24` |
| `BGR3` | channel-swapped packed `RGB24` |
| `YUYV` | converted packed `RGB24` |
| `GREY` | packed `Mono8` |
| `MJPG` | decoded `RGB24` (color and grayscale JPEG) |

For uncompressed frames, row padding is stripped according to the negotiated
`bytesperline`. Capture rejects short rows, truncated frames, empty buffers,
out-of-range buffer indices, and buffers flagged `V4L2_BUF_FLAG_ERROR`.

## Choosing the camera format

The station requests one exact device, size, frame rate and pixel format and
does not fall back to another. The defaults are `/dev/video0` and 1280x720
`GREY` at 60 fps, which most webcams do not offer. List what the camera offers
with `v4l2-ctl --device /dev/video0 --list-formats-ext` or `rusty-lola devices`
(`video.devices[].formats`). Then set `--width`, `--height`, `--fps` and
`--pixel-format` on `connect`/`listen`, or the settings keys `video.width`,
`video.height`, `video.fps`, `video.pixel_format` and `video.device`. When the
driver answers with a different format, the error lists the formats the device
offers.

## Tests without a camera

The repository tests need no camera. From the repository root:

```bash
CARGO_TARGET_DIR="${TMPDIR:-/tmp}/open-lola-rust-build" \
  cargo test --manifest-path runtimes/rust-station/Cargo.toml \
  --no-default-features video::v4l2 --lib
```

They cover format conversion, padded and truncated rows, JPEG dimension checks,
requeueing after processing failures, cancellation timing, exact negotiation
comparisons, capability-mask selection, mode-range parsing, and, on Linux, the
UAPI record sizes and ioctl numbers.

## Virtual-device check

On Linux, install `v4l2loopback`, `v4l-utils`, and FFmpeg, then create a
loopback node and feed it a test source:

```bash
sudo modprobe v4l2loopback devices=1 video_nr=42 \
  card_label="Open LoLa V4L2 test" exclusive_caps=1

ffmpeg -re -f lavfi -i testsrc2=size=640x480:rate=30 \
  -pix_fmt yuyv422 -f v4l2 /dev/video42
```

With FFmpeg still running, list the node:

```bash
CARGO_TARGET_DIR="${TMPDIR:-/tmp}/open-lola-rust-build" \
  cargo run --manifest-path runtimes/rust-station/Cargo.toml \
  --no-default-features -- devices

v4l2-ctl --device /dev/video42 --all
v4l2-ctl --device /dev/video42 --list-formats-ext
```

The Rust inventory should show `/dev/video42` with capture and streaming
capabilities, `YUYV`, the 640x480 mode, and a `1/30` interval. To test capture
itself, run a bounded station session against a controlled LoLa peer with the
V4L2 backend, `/dev/video42`, `YUYV`, 640x480, and 30 fps. Record the session
result separately from the inventory output. Remove the virtual device
afterwards:

```bash
sudo modprobe -r v4l2loopback
```

## Physical-device procedure

On the target Linux host:

1. Run `devices` and `v4l2-ctl --list-formats-ext` for the chosen node. Pick a
   discrete mode and interval exactly as reported.
2. Run a short transmit session against a controlled peer with V4L2 and the
   exact device, format, width, height, and frame rate. Check that the session
   reports captured and sent video frames and that the peer receives frames in
   the expected format.
3. Cancel a longer session while the device is producing frames, then again
   while its source is stalled. Check that shutdown is bounded in both cases.
4. Unplug or suspend the device during a bounded session. Check for a capture
   error and a clean exit with no stuck worker.
5. Repeat start, capture, stop, and restart while watching kernel logs and the
   process's file descriptor and mapping counts for leaks.

Virtual-device and unit-test results say nothing about physical camera
compatibility, field latency, or interoperability with reference peers.

## Resource limits

- Dimensions up to 8192, with at most 16 MiB of normalized pixels.
- Each mapping is capped at 16 MiB and all mappings together at 128 MiB.
- Enumeration shares a budget of two seconds, 16,384 ioctls, and 8,192 records
  across at most 64 device nodes. Running out of budget is an inventory error.

YUYV conversion honors the negotiated BT.601/BT.709 and full/limited range
metadata.
