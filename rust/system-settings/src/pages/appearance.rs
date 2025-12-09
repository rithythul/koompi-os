//! Appearance settings page

use iced::widget::{column, container, pick_list, row, text, toggler, button};
use iced::{Element, Length};

/// Available themes
const THEMES: &[&str] = &["Dark", "Light", "System"];

/// Available accent colors
const ACCENT_COLORS: &[&str] = &["Blue", "Green", "Purple", "Orange", "Red", "Pink", "Teal"];

/// Available fonts
const FONTS: &[&str] = &["Roboto", "Noto Sans", "Inter", "Ubuntu", "Open Sans"];

/// Appearance settings state
#[derive(Debug, Clone)]
pub struct AppearanceSettings {
    pub theme: String,
    pub accent_color: String,
    pub font: String,
    pub font_size: i32,
    pub animations: bool,
    pub transparency: bool,
    pub wallpaper_path: Option<String>,
}

impl Default for AppearanceSettings {
    fn default() -> Self {
        Self {
            theme: "Dark".to_string(),
            accent_color: "Blue".to_string(),
            font: "Roboto".to_string(),
            font_size: 12,
            animations: true,
            transparency: true,
            wallpaper_path: None,
        }
    }
}

/// Appearance page messages
#[derive(Debug, Clone)]
pub enum AppearanceMessage {
    ThemeChanged(String),
    AccentColorChanged(String),
    FontChanged(String),
    FontSizeIncreased,
    FontSizeDecreased,
    AnimationsToggled(bool),
    TransparencyToggled(bool),
    ChooseWallpaper,
}

impl AppearanceSettings {
    pub fn update(&mut self, message: AppearanceMessage) {
        match message {
            AppearanceMessage::ThemeChanged(theme) => self.theme = theme,
            AppearanceMessage::AccentColorChanged(color) => self.accent_color = color,
            AppearanceMessage::FontChanged(font) => self.font = font,
            AppearanceMessage::FontSizeIncreased => {
                if self.font_size < 24 {
                    self.font_size += 1;
                }
            }
            AppearanceMessage::FontSizeDecreased => {
                if self.font_size > 8 {
                    self.font_size -= 1;
                }
            }
            AppearanceMessage::AnimationsToggled(enabled) => self.animations = enabled,
            AppearanceMessage::TransparencyToggled(enabled) => self.transparency = enabled,
            AppearanceMessage::ChooseWallpaper => {
                // TODO: Open file picker
            }
        }
    }

    pub fn view(&self) -> Element<AppearanceMessage> {
        let title = text("Appearance").size(24);

        // Theme picker
        let theme_row = row![
            text("Theme").width(Length::FillPortion(1)),
            pick_list(
                THEMES.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
                Some(self.theme.clone()),
                AppearanceMessage::ThemeChanged,
            )
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Accent color picker
        let accent_row = row![
            text("Accent Color").width(Length::FillPortion(1)),
            pick_list(
                ACCENT_COLORS.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
                Some(self.accent_color.clone()),
                AppearanceMessage::AccentColorChanged,
            )
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Font picker
        let font_row = row![
            text("Font").width(Length::FillPortion(1)),
            pick_list(
                FONTS.iter().map(|s| s.to_string()).collect::<Vec<_>>(),
                Some(self.font.clone()),
                AppearanceMessage::FontChanged,
            )
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Font size
        let font_size_row = row![
            text("Font Size").width(Length::FillPortion(1)),
            row![
                button(text("-")).on_press(AppearanceMessage::FontSizeDecreased).padding(8),
                text(format!("{}", self.font_size)).width(Length::Fixed(40.0)),
                button(text("+")).on_press(AppearanceMessage::FontSizeIncreased).padding(8),
            ]
            .spacing(8)
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Animations toggle
        let animations_row = row![
            text("Animations").width(Length::FillPortion(1)),
            toggler(None::<String>, self.animations, AppearanceMessage::AnimationsToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Transparency toggle
        let transparency_row = row![
            text("Transparency").width(Length::FillPortion(1)),
            toggler(None::<String>, self.transparency, AppearanceMessage::TransparencyToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Wallpaper button
        let wallpaper_text = self
            .wallpaper_path
            .as_ref()
            .map(|p| p.clone())
            .unwrap_or_else(|| "No wallpaper selected".to_string());
        let wallpaper_row = row![
            text("Wallpaper").width(Length::FillPortion(1)),
            row![
                text(wallpaper_text).size(12),
                button(text("Choose..."))
                    .on_press(AppearanceMessage::ChooseWallpaper)
                    .padding(8),
            ]
            .spacing(8)
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        let content = column![
            title,
            theme_row,
            accent_row,
            font_row,
            font_size_row,
            animations_row,
            transparency_row,
            wallpaper_row,
        ]
        .spacing(8)
        .padding(16);

        container(content)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }
}
