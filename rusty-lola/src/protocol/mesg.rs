//! LoLa 2.0 control-plane codec: padded ASCII and legacy OSC15.

mod ascii;
mod encode;
mod model;
mod osc15;

pub use ascii::{build_control_datagram, build_control_text, escape_txt_field, unescape_txt_field};
pub use encode::*;
pub use model::*;
pub use osc15::{build_osc15_control_datagram, parse_osc15_control_datagram};

pub fn parse_control_datagram(data: &[u8]) -> Option<ControlMessage> {
    if data.len() > CONTROL_DATAGRAM_SIZE {
        return None;
    }
    parse_osc15_control_datagram(data).or_else(|| ascii::parse_control_datagram(data))
}
