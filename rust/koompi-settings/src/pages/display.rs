//! Display settings page

use iced::widget::{column, container, pick_list, row, slider, text, toggler};
use iced::{Element, Length};

/// Available resolutions
const RESOLUTIONS: &[&str] = &[
    "3840x2160",
    "2560x1440",
    "1920x1080",
    "1680x1050",
    "1440x900",
    "1366x768",
    "1280x720",
];

/// Refresh rates
const REFRESH_RATES: &[&str] = &["60 Hz", "75 Hz", "120 Hz", "144 Hz", "165 Hz", "240 Hz"];

/// Display settings state
#[derive(Debug, Clone)]
pub struct DisplaySettings {
    pub resolution: String,
    pub refresh_rate: String,
    pub scale: f32,
    pub night_light: bool,
    pub night_light_strength: f32,
}

impl Default for DisplaySettings {
    fn default() -> Self {
        Self {
            resolution: "1920x1080".to_string(),
            refresh_rate: "60 Hz".to_string(),
            scale: 1.0,
            night_light: false,
            night_light_strength: 0.5,
        }
    }
}

/// Display page messages
#[derive(Debug, Clone)]
pub enum DisplayMessage {
    ResolutionChanged(String),
    RefreshRateChanged(String),
    ScaleChanged(f32),
    NightLightToggled(bool),
    NightLightStrengthChanged(f32),
}

impl DisplaySettings {
    pub fn update(&mut self, message: DisplayMessage) {
        match message {
            DisplayMessage::ResolutionChanged(res) => self.resolution = res,
            DisplayMessage::RefreshRateChanged(rate) => self.refresh_rate = rate,
            DisplayMessage::ScaleChanged(scale) => self.scale = scale,
            DisplayMessage::NightLightToggled(enabled) => self.night_light = enabled,
            DisplayMessage::NightLightStrengthChanged(strength) => {
                self.night_light_strength = strength
            }
        }
    }

    pub fn view(&self) -> Element<DisplayMessage> {
        let title = text("Display").size(24);

        // Resolution picker
        let resolution_row = row![
            text("Resolution").width(Length::FillPortion(1)),
            pick_list(
                RESOLUTIONS.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
                Some(self.resolution.clone()),
                DisplayMessage::ResolutionChanged,
            )
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Refresh rate picker
        let refresh_row = row![
            text("Refresh Rate").width(Length::FillPortion(1)),
            pick_list(
                REFRESH_RATES.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
                Some(self.refresh_rate.clone()),
                DisplayMessage::RefreshRateChanged,
            )
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Scale slider
        let scale_label = format!("{}%", (self.scale * 100.0) as i32);
        let scale_row = row![
            text("Scale").width(Length::FillPortion(1)),
            slider(0.5..=2.0, self.scale, DisplayMessage::ScaleChanged)
                .step(0.25)
                .width(Length::FillPortion(2)),
            text(scale_label).width(Length::Fixed(60.0)),
        ]
        .spacing(16)
        .padding(8);

        // Night light toggle
        let night_light_row = row![
            text("Night Light").width(Length::FillPortion(1)),
            toggler(None::<String>, self.night_light, DisplayMessage::NightLightToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Night light strength (only if enabled)
        let content = if self.night_light {
            let strength_row = row![
                text("Warmth").width(Length::FillPortion(1)),
                slider(
                    0.0..=1.0,
                    self.night_light_strength,
                    DisplayMessage::NightLightStrengthChanged
                )
                .step(0.1)
                .width(Length::FillPortion(2)),
            ]
            .spacing(16)
            .padding(8);

            column![
                title,
                resolution_row,
                refresh_row,
                scale_row,
                night_light_row,
                strength_row,
            ]
        } else {
            column![title, resolution_row, refresh_row, scale_row, night_light_row,]
        };

        container(content.spacing(8).padding(16))
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }
}
