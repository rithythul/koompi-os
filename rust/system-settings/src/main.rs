//! System Settings Application
//!
//! A comprehensive settings application built with Iced.

mod app;
mod pages;

use app::SettingsApp;
use iced::{Application, Settings};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn main() -> iced::Result {
    // Initialize logging
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    tracing::info!("Starting System Settings");

    SettingsApp::run(Settings {
        window: iced::window::Settings {
            size: iced::Size::new(800.0, 600.0),
            min_size: Some(iced::Size::new(600.0, 400.0)),
            ..Default::default()
        },
        ..Default::default()
    })
}
