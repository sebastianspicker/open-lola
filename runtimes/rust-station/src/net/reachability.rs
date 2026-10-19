//! Host reachability probing (ICMP via system ping / TCP fallback).

use serde_json::{json, Value};
use std::net::{SocketAddr, TcpStream, ToSocketAddrs};
use std::process::Command;
use std::time::{Duration, Instant};

#[derive(Debug, Clone)]
pub struct ReachabilityResult {
    pub ok: bool,
    pub host: String,
    pub rtt_ms: Option<f64>,
    pub rtt_avg_ms: Option<f64>,
    pub sent: u32,
    pub received: u32,
    pub reason: String,
    pub resolved_ip: String,
}

impl ReachabilityResult {
    pub fn to_json(&self) -> Value {
        json!({
            "ok": self.ok,
            "host": self.host,
            "rtt_ms": self.rtt_ms,
            "rtt_avg_ms": self.rtt_avg_ms,
            "sent": self.sent,
            "received": self.received,
            "reason": self.reason,
            "resolved_ip": self.resolved_ip,
        })
    }
}

fn is_ipv4(text: &str) -> bool {
    text.parse::<std::net::Ipv4Addr>().is_ok()
}

fn resolve(host: &str) -> Result<(String, String), String> {
    let stripped = host.trim();
    if is_ipv4(stripped) {
        return Ok((stripped.to_string(), String::new()));
    }
    match format!("{stripped}:0").to_socket_addrs() {
        Ok(mut it) => {
            if let Some(addr) = it.next() {
                let ip = match addr {
                    SocketAddr::V4(v) => v.ip().to_string(),
                    SocketAddr::V6(v) => v.ip().to_string(),
                };
                Ok((ip.clone(), ip))
            } else {
                Err("dns resolution failed".into())
            }
        }
        Err(_) => Err("dns resolution failed".into()),
    }
}

/// Probe host with system `ping` when available; TCP connect fallback to :7 or ephemeral.
pub fn check_reachable(host: &str, timeout_ms: u32, count: u32) -> ReachabilityResult {
    let count = count.max(1);
    let timeout_ms = timeout_ms.max(50);
    let host = host.trim().to_string();
    let (ip, resolved) = match resolve(&host) {
        Ok(v) => v,
        Err(reason) => return unreachable_result(host, count, reason),
    };

    // Prefer OS ping (no admin for Windows icmp via ping.exe).
    let ping_failure = match try_ping(&host, &ip, timeout_ms, count, &resolved) {
        Some(result) if result.ok => return result,
        Some(result) => Some(result.reason),
        None => None,
    };

    // TCP connect probe to common control port 7000 then 80 as soft reachability.
    let rtts = tcp_probe(&ip, timeout_ms, count);
    reachability_from_rtts(host, resolved, count, rtts, ping_failure)
}

fn unreachable_result(host: String, count: u32, reason: String) -> ReachabilityResult {
    ReachabilityResult {
        ok: false,
        host,
        rtt_ms: None,
        rtt_avg_ms: None,
        sent: count,
        received: 0,
        reason,
        resolved_ip: String::new(),
    }
}

fn tcp_probe(ip: &str, timeout_ms: u32, count: u32) -> Vec<f64> {
    let mut rtts = Vec::new();
    let ports = [7000u16, 80, 443];
    for _ in 0..count {
        for port in ports {
            if let Some(rtt) = tcp_port_rtt(ip, port, timeout_ms) {
                rtts.push(rtt);
                break;
            }
        }
    }
    rtts
}

fn tcp_port_rtt(ip: &str, port: u16, timeout_ms: u32) -> Option<f64> {
    let addr = format!("{ip}:{port}")
        .parse()
        .unwrap_or_else(|_| SocketAddr::from(([127, 0, 0, 1], port)));
    let start = Instant::now();
    let outcome = TcpStream::connect_timeout(&addr, Duration::from_millis(timeout_ms as u64));
    // Connection refused still proves host reachability on many stacks.
    match outcome {
        Ok(_) => Some(start.elapsed().as_secs_f64() * 1000.0),
        Err(error) if error.kind() == std::io::ErrorKind::ConnectionRefused => {
            Some(start.elapsed().as_secs_f64() * 1000.0)
        }
        Err(_) => None,
    }
}

fn reachability_from_rtts(
    host: String,
    resolved: String,
    count: u32,
    rtts: Vec<f64>,
    ping_failure: Option<String>,
) -> ReachabilityResult {
    let received = rtts.len() as u32;
    let ok = received > 0;
    let rtt_ms = rtts.iter().cloned().fold(None, |acc: Option<f64>, v| {
        Some(acc.map(|a| a.min(v)).unwrap_or(v))
    });
    let rtt_avg_ms = if rtts.is_empty() {
        None
    } else {
        Some(rtts.iter().sum::<f64>() / rtts.len() as f64)
    };
    ReachabilityResult {
        ok,
        host,
        rtt_ms,
        rtt_avg_ms,
        sent: count,
        received,
        reason: if ok {
            String::new()
        } else {
            ping_failure.unwrap_or_else(|| "host unreachable".into())
        },
        resolved_ip: resolved,
    }
}

fn ping_executable() -> Option<&'static str> {
    let paths: &[&str] = if cfg!(windows) {
        &[r"C:\Windows\System32\PING.EXE"]
    } else {
        &["/sbin/ping", "/usr/bin/ping", "/bin/ping"]
    };
    paths
        .iter()
        .copied()
        .find(|path| std::path::Path::new(path).is_file())
}

fn try_ping(
    host: &str,
    ip: &str,
    timeout_ms: u32,
    count: u32,
    resolved: &str,
) -> Option<ReachabilityResult> {
    #[cfg(windows)]
    let output = {
        let timeout_s = ((timeout_ms as f64) / 1000.0).ceil().max(1.0) as u32;
        Command::new(ping_executable()?)
            .args(["-n", &count.to_string(), "-w", &timeout_ms.to_string(), ip])
            .output()
            .ok()
            .or_else(|| {
                let _ = timeout_s;
                None
            })
    };
    #[cfg(not(windows))]
    let output = {
        let timeout_s = ((timeout_ms as f64) / 1000.0).ceil().max(1.0) as u32;
        Command::new(ping_executable()?)
            .args(["-c", &count.to_string(), "-W", &timeout_s.to_string(), ip])
            .output()
            .ok()
    };

    let output = output?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    Some(ping_result(
        host,
        resolved,
        count,
        output.status.success(),
        &format!("{stdout}\n{stderr}"),
    ))
}

fn ping_result(
    host: &str,
    resolved: &str,
    count: u32,
    command_succeeded: bool,
    text: &str,
) -> ReachabilityResult {
    let rtts: Vec<f64> = text.lines().filter_map(reply_rtt_ms).collect();

    let received = if !rtts.is_empty() {
        rtts.len() as u32
    } else if command_succeeded {
        count
    } else {
        0
    };
    let ok = received > 0 || command_succeeded;
    let rtt_ms = rtts.iter().cloned().fold(None, |acc: Option<f64>, v| {
        Some(acc.map(|a| a.min(v)).unwrap_or(v))
    });
    let rtt_avg_ms = if rtts.is_empty() {
        if ok {
            Some(0.0)
        } else {
            None
        }
    } else {
        Some(rtts.iter().sum::<f64>() / rtts.len() as f64)
    };
    ReachabilityResult {
        ok,
        host: host.to_string(),
        rtt_ms,
        rtt_avg_ms,
        sent: count,
        received: if ok { received.max(1) } else { 0 },
        reason: if ok {
            String::new()
        } else {
            "ping failed".into()
        },
        resolved_ip: resolved.to_string(),
    }
}

/// RTT of one echo-reply line, independent of the ping tool's language: a reply carries a
/// TTL field (every locale keeps `TTL`/`ttl`), and its time is a number followed by `ms`
/// after `=` or `<` (`time=12.3 ms`, `Zeit<1ms`, `temps=12 ms`). Statistics lines
/// (`Minimum = 12ms`, `time 3003ms`) have no TTL and are skipped, so each reply counts once.
fn reply_rtt_ms(line: &str) -> Option<f64> {
    if !line.to_ascii_lowercase().contains("ttl") {
        return None;
    }
    let bytes = line.as_bytes();
    for (index, byte) in bytes.iter().enumerate() {
        if *byte == b'=' || *byte == b'<' {
            if let Some(value) = number_before_ms(&line[index + 1..]) {
                return Some(value);
            }
        }
    }
    None
}

/// `12.3 ms`, `1ms` or `0,5 ms` at the start of `text` (after optional spaces).
fn number_before_ms(text: &str) -> Option<f64> {
    let text = text.trim_start();
    let end = text
        .find(|c: char| !(c.is_ascii_digit() || c == '.' || c == ','))
        .unwrap_or(text.len());
    let (number, rest) = text.split_at(end);
    if !rest.trim_start().to_ascii_lowercase().starts_with("ms") {
        return None;
    }
    number.replace(',', ".").parse().ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tcp_fallback_result_uses_the_fastest_and_average_rtt() {
        let report = reachability_from_rtts(
            "peer".into(),
            "203.0.113.4".into(),
            3,
            vec![7.0, 3.0, 5.0],
            Some("ping failed".into()),
        );

        assert!(report.ok);
        assert_eq!(report.received, 3);
        assert_eq!(report.rtt_ms, Some(3.0));
        assert_eq!(report.rtt_avg_ms, Some(5.0));
        assert!(report.reason.is_empty());
    }

    fn rtts(text: &str) -> Vec<f64> {
        text.lines().filter_map(reply_rtt_ms).collect()
    }

    #[test]
    fn unix_replies_are_counted_once_and_the_statistics_line_is_ignored() {
        let linux = "PING 192.0.2.1 (192.0.2.1) 56(84) bytes of data.\n\
64 bytes from 192.0.2.1: icmp_seq=1 ttl=64 time=0.412 ms\n\
64 bytes from 192.0.2.1: icmp_seq=2 ttl=64 time=0.380 ms\n\n\
--- 192.0.2.1 ping statistics ---\n\
2 packets transmitted, 2 received, 0% packet loss, time 1001ms\n\
rtt min/avg/max/mdev = 0.380/0.396/0.412/0.016 ms\n";
        assert_eq!(rtts(linux), vec![0.412, 0.380]);
        let result = ping_result("h", "192.0.2.1", 2, true, linux);
        assert_eq!(result.received, 2);
        let macos = "64 bytes from 192.0.2.1: icmp_seq=0 ttl=64 time=1.5 ms\n";
        assert_eq!(rtts(macos), vec![1.5]);
    }

    #[test]
    fn windows_rtts_parse_in_english_german_and_french() {
        let english = "Reply from 192.0.2.1: bytes=32 time=12ms TTL=57\n\
Reply from 192.0.2.1: bytes=32 time<1ms TTL=57\n\
    Minimum = 1ms, Maximum = 12ms, Average = 6ms\n";
        assert_eq!(rtts(english), vec![12.0, 1.0]);
        let german = "Antwort von 192.0.2.1: Bytes=32 Zeit=14ms TTL=57\n\
Antwort von 192.0.2.1: Bytes=32 Zeit<1ms TTL=57\n\
    Minimum = 1ms, Maximum = 14ms, Mittelwert = 7ms\n";
        assert_eq!(rtts(german), vec![14.0, 1.0]);
        let french = "R\u{e9}ponse de 192.0.2.1 : octets=32 temps=15 ms TTL=57\n\
R\u{e9}ponse de 192.0.2.1 : octets=32 temps<1 ms TTL=57\n\
    Minimum = 1 ms, Maximum = 15 ms, Moyenne = 8 ms\n";
        assert_eq!(rtts(french), vec![15.0, 1.0]);
        let result = ping_result("h", "192.0.2.1", 2, true, german);
        assert_eq!(result.received, 2);
        assert_eq!(result.rtt_ms, Some(1.0));
        assert_eq!(result.rtt_avg_ms, Some(7.5));
    }

    #[test]
    fn lines_without_a_ttl_or_an_ms_time_are_not_rtts() {
        assert_eq!(reply_rtt_ms("Request timed out."), None);
        assert_eq!(reply_rtt_ms("Reply from 192.0.2.1: bytes=32 TTL=57"), None);
        assert_eq!(reply_rtt_ms("time=5 ms without the reply marker"), None);
    }
}
