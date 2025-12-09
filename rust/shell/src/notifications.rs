//! KOOMPI Shell Notification System
//!
//! Provides toast notifications with auto-dismiss, urgency levels, and action buttons.

use std::collections::VecDeque;
use std::time::{Duration, Instant};

/// Notification urgency level
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Urgency {
    Low,
    Normal,
    Critical,
}

impl Default for Urgency {
    fn default() -> Self {
        Self::Normal
    }
}

/// A single notification
#[derive(Debug, Clone)]
pub struct Notification {
    pub id: u32,
    pub app_name: String,
    pub summary: String,
    pub body: String,
    pub icon: Option<String>,
    pub urgency: Urgency,
    pub actions: Vec<(String, String)>, // (action_id, label)
    pub created_at: Instant,
    pub timeout: Duration,
    pub progress: Option<u8>, // 0-100 for progress notifications
}

impl Notification {
    pub fn new(id: u32, app_name: &str, summary: &str, body: &str) -> Self {
        Self {
            id,
            app_name: app_name.to_string(),
            summary: summary.to_string(),
            body: body.to_string(),
            icon: None,
            urgency: Urgency::Normal,
            actions: Vec::new(),
            created_at: Instant::now(),
            timeout: Duration::from_secs(5),
            progress: None,
        }
    }

    pub fn with_urgency(mut self, urgency: Urgency) -> Self {
        self.urgency = urgency;
        if urgency == Urgency::Critical {
            self.timeout = Duration::from_secs(0); // Never auto-dismiss
        }
        self
    }

    pub fn with_timeout(mut self, secs: u64) -> Self {
        self.timeout = Duration::from_secs(secs);
        self
    }

    pub fn with_icon(mut self, icon: &str) -> Self {
        self.icon = Some(icon.to_string());
        self
    }

    pub fn with_action(mut self, action_id: &str, label: &str) -> Self {
        self.actions.push((action_id.to_string(), label.to_string()));
        self
    }

    pub fn with_progress(mut self, progress: u8) -> Self {
        self.progress = Some(progress.min(100));
        self
    }

    pub fn is_expired(&self) -> bool {
        if self.timeout.is_zero() {
            return false; // Critical notifications don't expire
        }
        self.created_at.elapsed() > self.timeout
    }

    /// Get remaining time as a fraction (1.0 = full, 0.0 = expired)
    pub fn remaining_fraction(&self) -> f32 {
        if self.timeout.is_zero() {
            return 1.0;
        }
        let elapsed = self.created_at.elapsed().as_secs_f32();
        let total = self.timeout.as_secs_f32();
        (1.0 - elapsed / total).max(0.0)
    }
}

/// Notification daemon managing all notifications
pub struct NotificationDaemon {
    notifications: VecDeque<Notification>,
    next_id: u32,
    max_visible: usize,
    history: Vec<Notification>, // Dismissed notifications for history
    max_history: usize,
}

impl NotificationDaemon {
    pub fn new() -> Self {
        Self {
            notifications: VecDeque::new(),
            next_id: 1,
            max_visible: 5,
            history: Vec::new(),
            max_history: 50,
        }
    }

    /// Add a new notification, returns its ID
    pub fn notify(&mut self, app_name: &str, summary: &str, body: &str) -> u32 {
        let id = self.next_id;
        self.next_id += 1;

        let notification = Notification::new(id, app_name, summary, body);
        self.notifications.push_back(notification);

        // Limit visible notifications
        while self.notifications.len() > self.max_visible {
            if let Some(old) = self.notifications.pop_front() {
                self.add_to_history(old);
            }
        }

        id
    }

    /// Add a fully configured notification
    pub fn add(&mut self, mut notification: Notification) -> u32 {
        let id = self.next_id;
        self.next_id += 1;
        notification.id = id;

        self.notifications.push_back(notification);

        while self.notifications.len() > self.max_visible {
            if let Some(old) = self.notifications.pop_front() {
                self.add_to_history(old);
            }
        }

        id
    }

    /// Dismiss a notification by ID
    pub fn dismiss(&mut self, id: u32) {
        if let Some(pos) = self.notifications.iter().position(|n| n.id == id) {
            if let Some(notification) = self.notifications.remove(pos) {
                self.add_to_history(notification);
            }
        }
    }

    /// Dismiss all notifications
    pub fn dismiss_all(&mut self) {
        while let Some(notification) = self.notifications.pop_front() {
            self.add_to_history(notification);
        }
    }

    /// Update notification (for progress updates)
    pub fn update(&mut self, id: u32, summary: Option<&str>, body: Option<&str>, progress: Option<u8>) {
        if let Some(notification) = self.notifications.iter_mut().find(|n| n.id == id) {
            if let Some(s) = summary {
                notification.summary = s.to_string();
            }
            if let Some(b) = body {
                notification.body = b.to_string();
            }
            if let Some(p) = progress {
                notification.progress = Some(p.min(100));
            }
        }
    }

    /// Remove expired notifications
    pub fn cleanup(&mut self) {
        let expired: Vec<u32> = self.notifications
            .iter()
            .filter(|n| n.is_expired())
            .map(|n| n.id)
            .collect();

        for id in expired {
            self.dismiss(id);
        }
    }

    /// Get visible notifications
    pub fn visible(&self) -> impl Iterator<Item = &Notification> {
        self.notifications.iter()
    }

    /// Get notification count
    pub fn count(&self) -> usize {
        self.notifications.len()
    }

    /// Get history
    pub fn history(&self) -> &[Notification] {
        &self.history
    }

    fn add_to_history(&mut self, notification: Notification) {
        self.history.push(notification);
        while self.history.len() > self.max_history {
            self.history.remove(0);
        }
    }
}

impl Default for NotificationDaemon {
    fn default() -> Self {
        Self::new()
    }
}

/// OSD (On-Screen Display) for volume/brightness feedback
#[derive(Debug, Clone)]
pub struct OSD {
    pub kind: OSDKind,
    pub value: u8, // 0-100
    pub created_at: Instant,
    pub timeout: Duration,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum OSDKind {
    Volume,
    Brightness,
    Mute,
}

impl OSD {
    pub fn volume(value: u8) -> Self {
        Self {
            kind: OSDKind::Volume,
            value: value.min(100),
            created_at: Instant::now(),
            timeout: Duration::from_millis(1500),
        }
    }

    pub fn brightness(value: u8) -> Self {
        Self {
            kind: OSDKind::Brightness,
            value: value.min(100),
            created_at: Instant::now(),
            timeout: Duration::from_millis(1500),
        }
    }

    pub fn mute() -> Self {
        Self {
            kind: OSDKind::Mute,
            value: 0,
            created_at: Instant::now(),
            timeout: Duration::from_millis(1500),
        }
    }

    pub fn is_expired(&self) -> bool {
        self.created_at.elapsed() > self.timeout
    }

    /// Get opacity based on remaining time (fade out effect)
    pub fn opacity(&self) -> f32 {
        let elapsed = self.created_at.elapsed().as_secs_f32();
        let total = self.timeout.as_secs_f32();
        let remaining = 1.0 - elapsed / total;

        // Start fading out in the last 0.3 seconds
        if remaining < 0.2 {
            remaining / 0.2
        } else {
            1.0
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_notification_creation() {
        let n = Notification::new(1, "Test App", "Test Title", "Test Body");
        assert_eq!(n.id, 1);
        assert_eq!(n.app_name, "Test App");
        assert!(!n.is_expired());
    }

    #[test]
    fn test_daemon_notify() {
        let mut daemon = NotificationDaemon::new();
        let id1 = daemon.notify("App1", "Title1", "Body1");
        let id2 = daemon.notify("App2", "Title2", "Body2");
        
        assert_eq!(id1, 1);
        assert_eq!(id2, 2);
        assert_eq!(daemon.count(), 2);
    }

    #[test]
    fn test_daemon_dismiss() {
        let mut daemon = NotificationDaemon::new();
        let id = daemon.notify("App", "Title", "Body");
        assert_eq!(daemon.count(), 1);
        
        daemon.dismiss(id);
        assert_eq!(daemon.count(), 0);
        assert_eq!(daemon.history().len(), 1);
    }
}
