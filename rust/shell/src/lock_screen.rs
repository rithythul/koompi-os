//! KOOMPI Shell Lock Screen
//!
//! Provides a secure lock screen with password entry and session management.

use std::time::{Duration, Instant};

/// Lock screen state
#[derive(Debug, Clone, PartialEq)]
pub enum LockState {
    Unlocked,
    Locked,
    Authenticating,
    AuthFailed,
}

/// Lock screen manager
pub struct LockScreen {
    pub state: LockState,
    pub password_input: String,
    pub error_message: Option<String>,
    pub failed_attempts: u32,
    pub lockout_until: Option<Instant>,
    pub locked_at: Option<Instant>,
    pub idle_timeout: Duration,
    pub last_activity: Instant,
    pub show_password: bool,
    pub user_name: String,
    pub user_avatar: Option<String>, // Path to avatar image
}

impl LockScreen {
    pub fn new() -> Self {
        Self {
            state: LockState::Unlocked,
            password_input: String::new(),
            error_message: None,
            failed_attempts: 0,
            lockout_until: None,
            locked_at: None,
            idle_timeout: Duration::from_secs(300), // 5 minutes default
            last_activity: Instant::now(),
            show_password: false,
            user_name: whoami::username(),
            user_avatar: None,
        }
    }

    /// Lock the screen
    pub fn lock(&mut self) {
        self.state = LockState::Locked;
        self.password_input.clear();
        self.error_message = None;
        self.locked_at = Some(Instant::now());
        self.show_password = false;
    }

    /// Attempt to unlock with password
    pub fn try_unlock(&mut self, password: &str) -> bool {
        // Check for lockout
        if let Some(lockout) = self.lockout_until {
            if Instant::now() < lockout {
                let remaining = (lockout - Instant::now()).as_secs();
                self.error_message = Some(format!("Too many attempts. Try again in {}s", remaining));
                return false;
            } else {
                self.lockout_until = None;
                self.failed_attempts = 0;
            }
        }

        self.state = LockState::Authenticating;

        // Verify password using PAM or system auth
        if self.verify_password(password) {
            self.state = LockState::Unlocked;
            self.password_input.clear();
            self.error_message = None;
            self.failed_attempts = 0;
            self.locked_at = None;
            true
        } else {
            self.failed_attempts += 1;
            self.state = LockState::AuthFailed;
            
            // Progressive lockout
            if self.failed_attempts >= 5 {
                let lockout_secs = 30 * (self.failed_attempts - 4) as u64;
                self.lockout_until = Some(Instant::now() + Duration::from_secs(lockout_secs.min(300)));
                self.error_message = Some(format!(
                    "Too many failed attempts. Locked for {}s",
                    lockout_secs.min(300)
                ));
            } else {
                self.error_message = Some(format!(
                    "Incorrect password ({}/5 attempts)",
                    self.failed_attempts
                ));
            }
            
            self.password_input.clear();
            false
        }
    }

    /// Verify password (placeholder - real implementation would use PAM)
    fn verify_password(&self, password: &str) -> bool {
        // TODO: Implement actual PAM authentication
        // For now, use a simple check (NEVER use this in production!)
        // This should be replaced with pam_authenticate()
        
        // In development mode, accept "koompi" as password
        #[cfg(debug_assertions)]
        {
            if password == "koompi" {
                return true;
            }
        }
        
        // Try PAM authentication
        self.pam_authenticate(password)
    }

    /// PAM authentication (real implementation)
    fn pam_authenticate(&self, password: &str) -> bool {
        // This would use the `pam` crate in production
        // For now, return false (always fail) in release builds
        #[cfg(not(debug_assertions))]
        {
            tracing::warn!("PAM authentication not yet implemented");
            // TODO: Implement real PAM auth:
            // let mut auth = pam::Authenticator::with_password("koompi-shell").unwrap();
            // auth.get_handler().set_credentials(&self.user_name, password);
            // auth.authenticate().is_ok()
            let _ = password; // Suppress unused warning
            false
        }
        
        #[cfg(debug_assertions)]
        {
            let _ = password;
            false
        }
    }

    /// Handle character input
    pub fn input_char(&mut self, ch: char) {
        if self.state == LockState::Locked || self.state == LockState::AuthFailed {
            // Clear error on new input
            if self.state == LockState::AuthFailed {
                self.state = LockState::Locked;
                self.error_message = None;
            }
            
            self.password_input.push(ch);
        }
    }

    /// Handle backspace
    pub fn input_backspace(&mut self) {
        if self.state == LockState::Locked || self.state == LockState::AuthFailed {
            self.password_input.pop();
            if self.state == LockState::AuthFailed {
                self.state = LockState::Locked;
                self.error_message = None;
            }
        }
    }

    /// Handle Enter key
    pub fn input_enter(&mut self) {
        if self.state == LockState::Locked || self.state == LockState::AuthFailed {
            let password = self.password_input.clone();
            self.try_unlock(&password);
        }
    }

    /// Handle Escape key
    pub fn input_escape(&mut self) {
        self.password_input.clear();
        self.error_message = None;
        if self.state == LockState::AuthFailed {
            self.state = LockState::Locked;
        }
    }

    /// Toggle password visibility
    pub fn toggle_password_visibility(&mut self) {
        self.show_password = !self.show_password;
    }

    /// Register activity (for idle lock)
    pub fn activity(&mut self) {
        self.last_activity = Instant::now();
    }

    /// Check if should auto-lock due to inactivity
    pub fn should_idle_lock(&self) -> bool {
        self.state == LockState::Unlocked && 
        self.last_activity.elapsed() > self.idle_timeout
    }

    /// Get masked password for display
    pub fn display_password(&self) -> String {
        if self.show_password {
            self.password_input.clone()
        } else {
            "●".repeat(self.password_input.len())
        }
    }

    /// Get time locked (for display)
    pub fn time_locked(&self) -> Option<Duration> {
        self.locked_at.map(|t| t.elapsed())
    }

    /// Check if currently locked out
    pub fn is_locked_out(&self) -> bool {
        self.lockout_until.map(|t| Instant::now() < t).unwrap_or(false)
    }
}

impl Default for LockScreen {
    fn default() -> Self {
        Self::new()
    }
}

/// Session actions from lock screen
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SessionAction {
    Lock,
    Logout,
    Suspend,
    Hibernate,
    Reboot,
    Shutdown,
}

impl SessionAction {
    pub fn label(&self) -> &'static str {
        match self {
            Self::Lock => "Lock",
            Self::Logout => "Log Out",
            Self::Suspend => "Suspend",
            Self::Hibernate => "Hibernate",
            Self::Reboot => "Reboot",
            Self::Shutdown => "Shut Down",
        }
    }

    pub fn icon(&self) -> &'static str {
        match self {
            Self::Lock => "🔒",
            Self::Logout => "🚪",
            Self::Suspend => "💤",
            Self::Hibernate => "🌙",
            Self::Reboot => "🔄",
            Self::Shutdown => "⏻",
        }
    }
    
    /// Execute the session action
    pub fn execute(&self) {
        use std::process::Command;
        
        match self {
            Self::Lock => {
                // Handled internally by shell
            }
            Self::Logout => {
                // Signal shell to exit
                tracing::info!("Logout requested");
            }
            Self::Suspend => {
                let _ = Command::new("systemctl").arg("suspend").spawn();
            }
            Self::Hibernate => {
                let _ = Command::new("systemctl").arg("hibernate").spawn();
            }
            Self::Reboot => {
                let _ = Command::new("systemctl").arg("reboot").spawn();
            }
            Self::Shutdown => {
                let _ = Command::new("systemctl").arg("poweroff").spawn();
            }
        }
    }
}

/// Power menu state
pub struct PowerMenu {
    pub visible: bool,
    pub selected: usize,
    pub actions: Vec<SessionAction>,
}

impl PowerMenu {
    pub fn new() -> Self {
        Self {
            visible: false,
            selected: 0,
            actions: vec![
                SessionAction::Lock,
                SessionAction::Logout,
                SessionAction::Suspend,
                SessionAction::Reboot,
                SessionAction::Shutdown,
            ],
        }
    }

    pub fn toggle(&mut self) {
        self.visible = !self.visible;
        self.selected = 0;
    }

    pub fn select_next(&mut self) {
        self.selected = (self.selected + 1) % self.actions.len();
    }

    pub fn select_prev(&mut self) {
        if self.selected == 0 {
            self.selected = self.actions.len() - 1;
        } else {
            self.selected -= 1;
        }
    }

    pub fn confirm(&mut self) -> Option<SessionAction> {
        if self.visible {
            let action = self.actions[self.selected];
            self.visible = false;
            Some(action)
        } else {
            None
        }
    }
}

impl Default for PowerMenu {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_lock_unlock() {
        let mut screen = LockScreen::new();
        assert_eq!(screen.state, LockState::Unlocked);
        
        screen.lock();
        assert_eq!(screen.state, LockState::Locked);
    }

    #[test]
    fn test_password_masking() {
        let mut screen = LockScreen::new();
        screen.lock();
        screen.input_char('t');
        screen.input_char('e');
        screen.input_char('s');
        screen.input_char('t');
        
        assert_eq!(screen.display_password(), "●●●●");
        screen.toggle_password_visibility();
        assert_eq!(screen.display_password(), "test");
    }

    #[test]
    fn test_failed_attempts() {
        let mut screen = LockScreen::new();
        screen.lock();
        
        for _ in 0..5 {
            screen.try_unlock("wrong");
        }
        
        assert!(screen.is_locked_out());
    }
}
