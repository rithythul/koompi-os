//! About page - system information

use iced::widget::{column, container, row, text, button};
use iced::{Element, Length};
use sysinfo::System;

/// About page state
#[derive(Debug, Clone)]
pub struct AboutSettings {
    pub os_name: String,
    pub os_version: String,
    pub kernel_version: String,
    pub hostname: String,
    pub cpu_name: String,
    pub memory_total: u64,
    pub disk_total: u64,
}

impl Default for AboutSettings {
    fn default() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();

        let cpu_name = sys
            .cpus()
            .first()
            .map(|cpu| cpu.brand().to_string())
            .unwrap_or_else(|| "Unknown CPU".to_string());

        Self {
            os_name: "KOOMPI OS".to_string(),
            os_version: "1.0.0".to_string(),
            kernel_version: System::kernel_version().unwrap_or_else(|| "Unknown".to_string()),
            hostname: System::host_name().unwrap_or_else(|| "koompi".to_string()),
            cpu_name,
            memory_total: sys.total_memory(),
            disk_total: 0, // TODO: Get from disk info
        }
    }
}

/// About page messages
#[derive(Debug, Clone)]
pub enum AboutMessage {
    CopySystemInfo,
    CheckForUpdates,
}

impl AboutSettings {
    pub fn update(&mut self, message: AboutMessage) {
        match message {
            AboutMessage::CopySystemInfo => {
                // TODO: Copy to clipboard
            }
            AboutMessage::CheckForUpdates => {
                // TODO: Check for updates
            }
        }
    }

    pub fn view(&self) -> Element<AboutMessage> {
        let title = text("About").size(24);

        // Logo/branding
        let logo = text("KOOMPI OS").size(48);
        let tagline = text("AI-Powered Education OS").size(14);

        // System info
        let version_row = row![
            text("Version").width(Length::FillPortion(1)),
            text(&self.os_version).width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        let kernel_row = row![
            text("Kernel").width(Length::FillPortion(1)),
            text(&self.kernel_version).width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        let hostname_row = row![
            text("Hostname").width(Length::FillPortion(1)),
            text(&self.hostname).width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Hardware info
        let hardware_title = text("Hardware").size(18);

        let cpu_row = row![
            text("Processor").width(Length::FillPortion(1)),
            text(&self.cpu_name).width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        let memory_gb = self.memory_total as f64 / 1024.0 / 1024.0 / 1024.0;
        let memory_row = row![
            text("Memory").width(Length::FillPortion(1)),
            text(format!("{:.1} GB", memory_gb)).width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Buttons
        let buttons_row = row![
            button(text("Copy System Info"))
                .on_press(AboutMessage::CopySystemInfo)
                .padding(8),
            button(text("Check for Updates"))
                .on_press(AboutMessage::CheckForUpdates)
                .padding(8),
        ]
        .spacing(16)
        .padding(16);

        // Credits
        let credits = column![
            text("Built with ❤️ by KOOMPI Team").size(12),
            text("Based on Arch Linux").size(12),
            text("© 2024 KOOMPI").size(12),
        ]
        .spacing(4);

        let content = column![
            title,
            logo,
            tagline,
            text(""),  // Spacer
            text("System").size(18),
            version_row,
            kernel_row,
            hostname_row,
            text(""),  // Spacer
            hardware_title,
            cpu_row,
            memory_row,
            buttons_row,
            credits,
        ]
        .spacing(4)
        .padding(16);

        container(content)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }
}
