use super::*;

#[test]
fn advertised_geometry_and_bpp_match_wire_output() {
    let mut settings = crate::config::default_settings();
    settings.video.width = 640;
    settings.video.height = 480;
    settings.video.bpp = 8;
    settings.video.bayer = 1;
    let mut options = SessionOptions::demo();
    options.max_stream_width = 320;
    options.max_stream_height = 180;
    options.auto_bayer = true;
    let media = requested_client_media(&settings, &options);
    assert_eq!((media.width, media.height), (240, 180));
    assert_eq!((media.bits_per_pixel, media.bayer), (24, 0));
}

#[test]
fn incompatible_ack_video_tuple_is_rejected() {
    let settings = crate::config::default_settings();
    let options = SessionOptions::demo();
    let requested = requested_client_media(&settings, &options);
    assert!(verify_quickconn_ack_video(&requested, &requested).is_ok());
    for acknowledged in [
        ProtocolMediaSettings {
            width: requested.width + 1,
            ..requested.clone()
        },
        ProtocolMediaSettings {
            height: requested.height + 1,
            ..requested.clone()
        },
        ProtocolMediaSettings {
            fps: requested.fps + 1,
            ..requested.clone()
        },
        ProtocolMediaSettings {
            bits_per_pixel: if requested.bits_per_pixel == 24 {
                8
            } else {
                24
            },
            ..requested.clone()
        },
        ProtocolMediaSettings {
            compression: u32::from(requested.compression == 0),
            ..requested.clone()
        },
        ProtocolMediaSettings {
            bayer: u32::from(requested.bayer == 0),
            ..requested.clone()
        },
    ] {
        assert!(matches!(
            verify_quickconn_ack_video(&requested, &acknowledged),
            Err(SessionError::ControlHandshake(_))
        ));
    }
}

#[test]
fn test_signal_advertises_its_generated_pixel_format() {
    let mut settings = crate::config::default_settings();
    let mut options = SessionOptions::demo();
    options.test_signal_mode = "send".into();
    settings.video.bpp = 32;
    settings.video.bayer = 1;
    let mono = requested_client_media(&settings, &options);
    assert_eq!((mono.bits_per_pixel, mono.bayer), (8, 1));
    settings.video.bayer = 0;
    let rgb = requested_client_media(&settings, &options);
    assert_eq!((rgb.bits_per_pixel, rgb.bayer), (24, 0));
}

#[test]
fn jpeg_advertises_the_rgb_decoded_representation() {
    let mut settings = crate::config::default_settings();
    settings.video.compression = true;
    settings.video.bpp = 8;
    settings.video.bayer = 1;
    let media = requested_client_media(&settings, &SessionOptions::demo());
    assert_eq!((media.bits_per_pixel, media.bayer), (24, 0));
}
