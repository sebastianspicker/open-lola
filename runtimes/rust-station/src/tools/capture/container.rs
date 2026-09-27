//! Capture container parsing; all offsets are checked before use.
use super::invalid;
#[derive(Clone, Copy)]
struct Endian(bool);
impl Endian {
    fn u32(self, bytes: &[u8], at: usize) -> Result<u32, String> {
        let value = bytes
            .get(at..at + 4)
            .ok_or_else(|| invalid("truncated capture integer"))?
            .try_into()
            .unwrap();
        Ok(if self.0 {
            u32::from_le_bytes(value)
        } else {
            u32::from_be_bytes(value)
        })
    }
    fn u16(self, bytes: &[u8], at: usize) -> Result<u16, String> {
        let value = bytes
            .get(at..at + 2)
            .ok_or_else(|| invalid("truncated capture integer"))?
            .try_into()
            .unwrap();
        Ok(if self.0 {
            u16::from_le_bytes(value)
        } else {
            u16::from_be_bytes(value)
        })
    }
}
pub(super) fn packets(
    bytes: &[u8],
    mut visit: impl FnMut(u32, &[u8]) -> Result<(), String>,
) -> Result<(), String> {
    let magic = bytes
        .get(..4)
        .ok_or_else(|| invalid("missing capture header"))?;
    match magic {
        [0xd4, 0xc3, 0xb2, 0xa1] | [0x4d, 0x3c, 0xb2, 0xa1] => {
            pcap(bytes, Endian(true), &mut visit)
        }
        [0xa1, 0xb2, 0xc3, 0xd4] | [0xa1, 0xb2, 0x3c, 0x4d] => {
            pcap(bytes, Endian(false), &mut visit)
        }
        [0x0a, 0x0d, 0x0d, 0x0a] => pcapng(bytes, &mut visit),
        _ => Err(invalid("unsupported capture magic")),
    }
}
fn pcap(
    bytes: &[u8],
    endian: Endian,
    visit: &mut impl FnMut(u32, &[u8]) -> Result<(), String>,
) -> Result<(), String> {
    if endian.u16(bytes, 4)? != 2 || endian.u16(bytes, 6)? != 4 {
        return Err(invalid("unsupported PCAP version"));
    }
    let snaplen = endian.u32(bytes, 16)? as usize;
    let linktype = endian.u32(bytes, 20)? & 0xffff;
    let mut at = 24;
    while at < bytes.len() {
        let caplen = endian.u32(bytes, at + 8)? as usize;
        let original = endian.u32(bytes, at + 12)? as usize;
        if caplen > snaplen || caplen > original {
            return Err(invalid("invalid captured packet length"));
        }
        at += 16;
        let packet = bytes
            .get(at..at + caplen)
            .ok_or_else(|| invalid("truncated PCAP packet"))?;
        visit(linktype, packet)?;
        at += caplen;
    }
    Ok(())
}
fn pcapng(
    bytes: &[u8],
    visit: &mut impl FnMut(u32, &[u8]) -> Result<(), String>,
) -> Result<(), String> {
    let mut at = 0;
    let mut endian = Endian(true);
    let mut interfaces: Vec<(u32, u32)> = Vec::new();
    while at < bytes.len() {
        let section = bytes.get(at..at + 4) == Some(&[0x0a, 0x0d, 0x0d, 0x0a]);
        if section {
            endian = pcapng_section_endian(bytes, at)?;
        }
        let (kind, body, length) = pcapng_block(bytes, at, endian)?;
        handle_pcapng_block(kind, body, endian, &mut interfaces, visit)?;
        at += length;
    }
    Ok(())
}

fn pcapng_section_endian(bytes: &[u8], at: usize) -> Result<Endian, String> {
    match bytes.get(at + 8..at + 12) {
        Some([0x4d, 0x3c, 0x2b, 0x1a]) => Ok(Endian(true)),
        Some([0x1a, 0x2b, 0x3c, 0x4d]) => Ok(Endian(false)),
        _ => Err(invalid("invalid PCAPNG byte order")),
    }
}

fn pcapng_block(bytes: &[u8], at: usize, endian: Endian) -> Result<(u32, &[u8], usize), String> {
    let kind = endian.u32(bytes, at)?;
    let length = endian.u32(bytes, at + 4)? as usize;
    if length < 12 || !length.is_multiple_of(4) {
        return Err(invalid("invalid PCAPNG block length"));
    }
    let block = bytes
        .get(at..at + length)
        .ok_or_else(|| invalid("truncated PCAPNG block"))?;
    if endian.u32(block, length - 4)? as usize != length {
        return Err(invalid("PCAPNG trailer mismatch"));
    }
    Ok((kind, &block[8..length - 4], length))
}

fn handle_pcapng_block(
    kind: u32,
    body: &[u8],
    endian: Endian,
    interfaces: &mut Vec<(u32, u32)>,
    visit: &mut impl FnMut(u32, &[u8]) -> Result<(), String>,
) -> Result<(), String> {
    match kind {
        0x0a0d0d0a => {
            if body.len() < 16 || endian.u16(body, 4)? != 1 {
                return Err(invalid("unsupported PCAPNG section"));
            }
            interfaces.clear();
        }
        1 => add_pcapng_interface(body, endian, interfaces)?,
        2 | 3 | 6 => packet_block(kind, body, endian, interfaces, visit)?,
        _ => {}
    }
    Ok(())
}

fn add_pcapng_interface(
    body: &[u8],
    endian: Endian,
    interfaces: &mut Vec<(u32, u32)>,
) -> Result<(), String> {
    if interfaces.len() >= 256 {
        return Err(invalid("too many capture interfaces"));
    }
    interfaces.push((u32::from(endian.u16(body, 0)?), endian.u32(body, 4)?));
    Ok(())
}
fn packet_block(
    kind: u32,
    body: &[u8],
    endian: Endian,
    interfaces: &[(u32, u32)],
    visit: &mut impl FnMut(u32, &[u8]) -> Result<(), String>,
) -> Result<(), String> {
    let index = match kind {
        3 => 0,
        2 => u32::from(endian.u16(body, 0)?),
        _ => endian.u32(body, 0)?,
    } as usize;
    let &(link, snaplen) = interfaces
        .get(index)
        .ok_or_else(|| invalid("unknown capture interface"))?;
    let (offset, caplen, original) = if kind == 3 {
        let original = endian.u32(body, 0)?;
        (
            4,
            if snaplen == 0 {
                original
            } else {
                original.min(snaplen)
            },
            original,
        )
    } else {
        (20, endian.u32(body, 12)?, endian.u32(body, 16)?)
    };
    if caplen > original || (snaplen != 0 && caplen > snaplen) {
        return Err(invalid("invalid captured packet length"));
    }
    let packet = body
        .get(offset..offset + caplen as usize)
        .ok_or_else(|| invalid("truncated PCAPNG packet"))?;
    visit(link, packet)
}
