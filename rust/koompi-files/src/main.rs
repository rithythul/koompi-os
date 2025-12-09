//! KOOMPI Files - File Manager for KOOMPI OS
//!
//! A simple, fast file manager built with Iced.

mod app;
mod file_item;
mod icons;

use app::FilesApp;
use iced::{Application, Settings};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn main() -> iced::Result {
    // Initialize logging
    tracing_subscriber::registry()
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_subscriber::EnvFilter::from_default_env())
        .init();

    tracing::info!("Starting KOOMPI Files");

    FilesApp::run(Settings {
        window: iced::window::Settings {
            size: iced::Size::new(900.0, 600.0),
            min_size: Some(iced::Size::new(400.0, 300.0)),
            ..Default::default()
        },
        ..Default::default()
    })
}
