//! Sound settings page

use iced::widget::{column, container, pick_list, row, slider, text, toggler};
use iced::{Element, Length};

/// Sound settings state
#[derive(Debug, Clone)]
pub struct SoundSettings {
    pub master_volume: f32,
    pub output_device: String,
    pub input_device: String,
    pub input_volume: f32,
    pub muted: bool,
    pub input_muted: bool,
    pub system_sounds: bool,
    pub available_outputs: Vec<String>,
    pub available_inputs: Vec<String>,
}

impl Default for SoundSettings {
    fn default() -> Self {
        Self {
            master_volume: 0.7,
            output_device: "Built-in Audio".to_string(),
            input_device: "Built-in Microphone".to_string(),
            input_volume: 0.8,
            muted: false,
            input_muted: false,
            system_sounds: true,
            available_outputs: vec![
                "Built-in Audio".to_string(),
                "HDMI Audio".to_string(),
            ],
            available_inputs: vec![
                "Built-in Microphone".to_string(),
            ],
        }
    }
}

/// Sound page messages
#[derive(Debug, Clone)]
pub enum SoundMessage {
    MasterVolumeChanged(f32),
    OutputDeviceChanged(String),
    InputDeviceChanged(String),
    InputVolumeChanged(f32),
    MutedToggled(bool),
    InputMutedToggled(bool),
    SystemSoundsToggled(bool),
}

impl SoundSettings {
    pub fn update(&mut self, message: SoundMessage) {
        match message {
            SoundMessage::MasterVolumeChanged(vol) => self.master_volume = vol,
            SoundMessage::OutputDeviceChanged(device) => self.output_device = device,
            SoundMessage::InputDeviceChanged(device) => self.input_device = device,
            SoundMessage::InputVolumeChanged(vol) => self.input_volume = vol,
            SoundMessage::MutedToggled(muted) => self.muted = muted,
            SoundMessage::InputMutedToggled(muted) => self.input_muted = muted,
            SoundMessage::SystemSoundsToggled(enabled) => self.system_sounds = enabled,
        }
    }

    pub fn view(&self) -> Element<SoundMessage> {
        let title = text("Sound").size(24);

        // Output section
        let output_title = text("Output").size(18);

        // Output device picker
        let output_device_row = row![
            text("Output Device").width(Length::FillPortion(1)),
            pick_list(
                self.available_outputs.clone(),
                Some(self.output_device.clone()),
                SoundMessage::OutputDeviceChanged,
            )
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Master volume
        let volume_icon = if self.muted {
            "🔇"
        } else if self.master_volume > 0.5 {
            "🔊"
        } else if self.master_volume > 0.0 {
            "🔉"
        } else {
            "🔈"
        };
        let volume_label = format!("{}%", (self.master_volume * 100.0) as i32);
        let volume_row = row![
            text(format!("{} Volume", volume_icon)).width(Length::FillPortion(1)),
            slider(0.0..=1.0, self.master_volume, SoundMessage::MasterVolumeChanged)
                .step(0.01)
                .width(Length::FillPortion(2)),
            text(volume_label).width(Length::Fixed(50.0)),
        ]
        .spacing(16)
        .padding(8);

        // Mute toggle
        let mute_row = row![
            text("Mute").width(Length::FillPortion(1)),
            toggler(None::<String>, self.muted, SoundMessage::MutedToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Input section
        let input_title = text("Input").size(18);

        // Input device picker
        let input_device_row = row![
            text("Input Device").width(Length::FillPortion(1)),
            pick_list(
                self.available_inputs.clone(),
                Some(self.input_device.clone()),
                SoundMessage::InputDeviceChanged,
            )
            .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Input volume
        let input_volume_label = format!("{}%", (self.input_volume * 100.0) as i32);
        let input_volume_row = row![
            text("🎤 Input Level").width(Length::FillPortion(1)),
            slider(0.0..=1.0, self.input_volume, SoundMessage::InputVolumeChanged)
                .step(0.01)
                .width(Length::FillPortion(2)),
            text(input_volume_label).width(Length::Fixed(50.0)),
        ]
        .spacing(16)
        .padding(8);

        // Input mute toggle
        let input_mute_row = row![
            text("Mute Microphone").width(Length::FillPortion(1)),
            toggler(None::<String>, self.input_muted, SoundMessage::InputMutedToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // System sounds
        let system_title = text("System").size(18);
        let system_sounds_row = row![
            text("System Sounds").width(Length::FillPortion(1)),
            toggler(None::<String>, self.system_sounds, SoundMessage::SystemSoundsToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        let content = column![
            title,
            output_title,
            output_device_row,
            volume_row,
            mute_row,
            input_title,
            input_device_row,
            input_volume_row,
            input_mute_row,
            system_title,
            system_sounds_row,
        ]
        .spacing(8)
        .padding(16);

        container(content)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }
}
