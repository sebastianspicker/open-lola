//! Multi-session tab board with LED state machine (LoLa 2.0 tabs 1/2).

use serde_json::{json, Value};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionLed {
    Red,
    Yellow,
    Green,
}

impl SessionLed {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Red => "red",
            Self::Yellow => "yellow",
            Self::Green => "green",
        }
    }
}

#[derive(Debug, Clone)]
pub struct SessionTab {
    pub tab_id: i32,
    pub session_id: i64,
    pub remote_ip: String,
    pub bind_ip: String,
    pub nic_name: String,
    pub enabled: bool,
    pub remote_audio_channel_offset: i32,
    pub audio_receive_queue_depth: u32,
    pub audio_receive_prefill: u32,
    pub video_receive_queue_depth: u32,
    pub video_receive_prefill: u32,
    pub status: String, // idle|ready|connecting|connected|error
}

impl SessionTab {
    pub fn to_json(&self) -> Value {
        json!({
            "tab_id": self.tab_id,
            "session_id": self.session_id,
            "remote_ip": self.remote_ip,
            "bind_ip": self.bind_ip,
            "nic_name": self.nic_name,
            "enabled": self.enabled,
            "remote_audio_channel_offset": self.remote_audio_channel_offset,
            "audio_receive_queue_depth": self.audio_receive_queue_depth,
            "audio_receive_prefill": self.audio_receive_prefill,
            "video_receive_queue_depth": self.video_receive_queue_depth,
            "video_receive_prefill": self.video_receive_prefill,
            "status": self.status,
        })
    }
}

/// Up to two remote tabs (3 sites with local).
#[derive(Debug, Clone)]
pub struct SessionTabBoard {
    tabs: [SessionTab; 2],
    active_tab: i32,
}

impl Default for SessionTabBoard {
    fn default() -> Self {
        Self::new()
    }
}

impl SessionTabBoard {
    pub fn new() -> Self {
        Self {
            tabs: [
                SessionTab {
                    tab_id: 1,
                    session_id: 1,
                    remote_ip: "127.0.0.1".into(),
                    bind_ip: "0.0.0.0".into(),
                    nic_name: "default".into(),
                    enabled: true,
                    remote_audio_channel_offset: 0,
                    audio_receive_queue_depth: 1,
                    audio_receive_prefill: 0,
                    video_receive_queue_depth: 1,
                    video_receive_prefill: 0,
                    status: "idle".into(),
                },
                SessionTab {
                    tab_id: 2,
                    session_id: 2,
                    remote_ip: "127.0.0.1".into(),
                    bind_ip: String::new(),
                    nic_name: "(DISABLED)".into(),
                    enabled: false,
                    remote_audio_channel_offset: 0,
                    audio_receive_queue_depth: 1,
                    audio_receive_prefill: 0,
                    video_receive_queue_depth: 1,
                    video_receive_prefill: 0,
                    status: "idle".into(),
                },
            ],
            active_tab: 1,
        }
    }

    pub fn tabs(&self) -> &[SessionTab; 2] {
        &self.tabs
    }

    pub fn get(&self, tab_id: i32) -> Result<&SessionTab, String> {
        self.tabs
            .iter()
            .find(|t| t.tab_id == tab_id)
            .ok_or_else(|| format!("unknown tab_id {tab_id}"))
    }

    pub fn get_mut(&mut self, tab_id: i32) -> Result<&mut SessionTab, String> {
        self.tabs
            .iter_mut()
            .find(|t| t.tab_id == tab_id)
            .ok_or_else(|| format!("unknown tab_id {tab_id}"))
    }

    pub fn active_tab_id(&self) -> i32 {
        self.active_tab
    }

    pub fn select(&mut self, tab_id: i32) -> Result<&SessionTab, String> {
        let _ = self.get(tab_id)?;
        self.active_tab = tab_id;
        self.get(tab_id)
    }

    pub fn led(&self, tab_id: i32) -> Result<SessionLed, String> {
        let tab = self.get(tab_id)?;
        if tab.status == "connected" {
            return Ok(SessionLed::Green);
        }
        if !tab.enabled {
            return Ok(SessionLed::Red);
        }
        let nic = tab.nic_name.trim().to_ascii_uppercase();
        if nic.is_empty() || nic == "(DISABLED)" || nic == "DISABLED" {
            return Ok(SessionLed::Red);
        }
        if tab.bind_ip.trim().is_empty() {
            return Ok(SessionLed::Red);
        }
        Ok(SessionLed::Yellow)
    }

    pub fn set_connected(&mut self, tab_id: i32, connected: bool) -> Result<(), String> {
        let tab = self.get_mut(tab_id)?;
        tab.status = if connected {
            "connected".into()
        } else {
            "idle".into()
        };
        Ok(())
    }

    pub fn set_enabled(&mut self, tab_id: i32, enabled: bool) -> Result<(), String> {
        let tab = self.get_mut(tab_id)?;
        tab.enabled = enabled;
        if enabled {
            if tab.nic_name.to_ascii_uppercase().contains("DISABLED") {
                tab.nic_name = "default".into();
            }
            if tab.bind_ip.is_empty() {
                tab.bind_ip = "0.0.0.0".into();
            }
        } else {
            tab.nic_name = "(DISABLED)".into();
            tab.status = "idle".into();
        }
        Ok(())
    }

    pub fn set_remote_ip(&mut self, tab_id: i32, ip: &str) -> Result<(), String> {
        let tab = self.get_mut(tab_id)?;
        tab.remote_ip = ip.trim().to_string();
        if tab.remote_ip.is_empty() {
            tab.remote_ip = "127.0.0.1".into();
        }
        Ok(())
    }

    pub fn sid_for_tab(&self, tab_id: i32) -> Result<i64, String> {
        Ok(self.get(tab_id)?.session_id)
    }

    pub fn to_dict(&self) -> Value {
        json!({
            "active_tab_id": self.active_tab,
            "tabs": self.tabs.iter().map(|t| t.to_json()).collect::<Vec<_>>(),
            "leds": {
                "1": self.led(1).map(|l| l.as_str()).unwrap_or("red"),
                "2": self.led(2).map(|l| l.as_str()).unwrap_or("red"),
            }
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn led_state_machine() {
        let mut board = SessionTabBoard::new();
        assert_eq!(board.led(1).unwrap(), SessionLed::Yellow);
        assert_eq!(board.led(2).unwrap(), SessionLed::Red);
        board.set_connected(1, true).unwrap();
        assert_eq!(board.led(1).unwrap(), SessionLed::Green);
        board.set_enabled(2, true).unwrap();
        assert_eq!(board.led(2).unwrap(), SessionLed::Yellow);
    }

    #[test]
    fn tab_sid_mapping() {
        let board = SessionTabBoard::new();
        assert_eq!(board.sid_for_tab(1).unwrap(), 1);
        assert_eq!(board.sid_for_tab(2).unwrap(), 2);
    }
}
