//! Software audio capture, PortAudio probe, and WAV utilities.

pub mod alsa;
pub mod portaudio;
pub mod software;
pub mod wav;
pub mod wavsplit;

pub use portaudio::*;
pub use software::{
    generate_pcm_tone, test_tone_frequency, SoftwareAudio, TEST_TONE_AMPLITUDE,
    TEST_TONE_HZ_PRIMARY, TEST_TONE_HZ_SECONDARY,
};
pub use wav::*;
pub use wavsplit::*;
