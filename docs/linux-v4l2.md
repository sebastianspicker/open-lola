# Linux V4L2 video capture

The Rust station has a native Linux V4L2 capture backend. It uses the single-
planar streaming API with memory-mapped buffers. Device inventory also reports
multi-planar capture capability and modes, but opening a multi-planar-only device
fails explicitly, because the capture pipeline consumes one packed image plane.

The implementation follows the Linux kernel's
[memory-mapped streaming contract](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/mmap.html):
request buffers, query and map each buffer, queue all buffers, start streaming,
dequeue a completed buffer, return it to the driver after processing, stop the
stream, and unmap the buffers.

## Capture contract

`V4l2Camera::open` opens the selected character device for read/write with
`O_NONBLOCK`, requires `V4L2_CAP_VIDEO_CAPTURE` and `V4L2_CAP_STREAMING`, and
negotiates the requested mode. The driver must return the exact width, height,
pixel FourCC, and rational frame interval. Driver substitutions fail with a
negotiation mismatch instead of silently changing the active session.

The backend requests four MMAP buffers and accepts two to four allocated buffers,
whose aggregate mapped length is limited to 1 GiB. A frame wait has a finite
timeout derived from the configured frame rate, and polling is divided into 25 ms
slices so a cancellation handle from another thread ends a pending grab
promptly. Every successfully dequeued, valid-index buffer is queued again even
when the driver marks it erroneous or frame validation or conversion fails.

Supported input formats are:

| V4L2 FourCC | Station output |
|---|---|
| `RGB3` | packed `RGB24` |
| `BGR3` | channel-swapped packed `RGB24` |
| `YUYV` | converted packed `RGB24` |
| `GREY` | packed `Mono8` |
| `MJPG` | decoded `RGB24` or `Mono8`, according to the JPEG image |

For uncompressed frames, driver row padding is removed according to the
negotiated `bytesperline`. Short rows, truncated frames, zero-byte buffers,
out-of-range buffer indices, and buffers carrying `V4L2_BUF_FLAG_ERROR` are all
rejected.

## Deterministic and virtual-device checks

The source does not require a camera for a normal build.

The adapter covers format conversion, padded and truncated rows, JPEG dimension
validation, requeue behavior after processing failures, cancellation timing,
exact negotiation comparisons, capability-mask selection, mode-range parsing,
and the UAPI record sizes and ioctl numbers on Linux.

For a controlled virtual-device exercise on Linux, install `v4l2loopback`,
`v4l-utils`, and FFmpeg, then create a loopback node and feed it a bounded test
source:

```bash
sudo modprobe v4l2loopback devices=1 video_nr=42 \
  card_label="Open LoLa V4L2 test" exclusive_caps=1

ffmpeg -re -f lavfi -i testsrc2=size=640x480:rate=30 \
  -pix_fmt yuyv422 -f v4l2 /dev/video42
```

With FFmpeg still running, inventory the node:

```bash
CARGO_TARGET_DIR=/private/tmp/open-lola-rust-build \
  cargo run --manifest-path runtimes/rust-station/Cargo.toml \
  --no-default-features -- devices

v4l2-ctl --device /dev/video42 --all
v4l2-ctl --device /dev/video42 --list-formats-ext
```

The Rust inventory should report `/dev/video42`, capture and streaming
capabilities, `YUYV`, the 640x480 mode, and a `1/30` interval. Exercise actual
capture through a bounded station session against a controlled LoLa peer with
the V4L2 backend, `/dev/video42`, `YUYV`, 640x480, and 30 fps selected. Record
the station result separately from the inventory output, then remove the virtual
device after the test:

```bash
sudo modprobe -r v4l2loopback
```

## Physical-device procedure

On the target Linux host:

1. Run the `devices` command and `v4l2-ctl --list-formats-ext` for the selected
   node. Choose a discrete mode and interval exactly as reported.
2. Run a short transmit session against a controlled peer, selecting V4L2 and
   the exact device, format, width, height, and frame rate. Confirm that the
   session reports captured and sent video frames and that the peer reports
   received frames in the expected station format.
3. Cancel a longer session while the device is producing frames, then repeat
   while its source is stalled. Confirm bounded shutdown in both cases.
4. Disconnect or suspend the device during a bounded session. Confirm an
   explicit capture error and a clean process exit without a stuck worker.
5. Repeat start, capture, stop, and restart while watching kernel logs and the
   process descriptor/map counts for leaks.

Virtual-device, local test, and source-level results do not establish physical
camera compatibility, field latency, or reference-peer interoperability.

## Software resource limits

Capture accepts dimensions up to 8192 with at most 16 MiB of normalized pixels.
Each mapping is capped at 16 MiB and the mapping set at 128 MiB. Enumeration
shares a two-second, 16,384-ioctl, 8,192-record budget across at most 64 device
nodes, and an exhausted budget is an explicit inventory error. YUYV honors
negotiated BT.601/BT.709 and full/limited range metadata. MJPG normalizes both
color and grayscale JPEG inputs to RGB24.
