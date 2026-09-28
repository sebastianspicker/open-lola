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
    // Parse RTT values from common ping formats
    let mut rtts = Vec::new();
    for line in text.lines() {
        // Windows: time=12ms or time<1ms
        if let Some(idx) = line.to_ascii_lowercase().find("time") {
            let rest = &line[idx..];
            if let Some(num) = extract_first_number(rest) {
                rtts.push(num);
            }
        }
        // Unix: time=12.3 ms
        if line.contains("time=") {
            if let Some(num) = extract_first_number_after(line, "time=") {
                rtts.push(num);
            }
        }
    }

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

fn extract_first_number(s: &str) -> Option<f64> {
    let mut num = String::new();
    let mut started = false;
    for c in s.chars() {
        if c.is_ascii_digit() || (c == '.' && started) {
            num.push(c);
            started = true;
        } else if started {
            break;
        }
    }
    if num.is_empty() {
        None
    } else {
        num.parse().ok()
    }
}

fn extract_first_number_after(s: &str, marker: &str) -> Option<f64> {
    let idx = s.find(marker)?;
    extract_first_number(&s[idx + marker.len()..])
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
}
