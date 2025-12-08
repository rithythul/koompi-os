//! KOOMPI OS System Daemon
//!
//! The main system service that provides:
//! - D-Bus API for system operations
//! - Snapshot management
//! - Package management
//! - Classroom mesh networking

use clap::Parser;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod dbus;
mod service;

#[derive(Parser)]
#[command(name = "koompid")]
#[command(about = "KOOMPI OS System Daemon")]
struct Cli {
    /// Run in foreground (don't daemonize)
    #[arg(short, long)]
    foreground: bool,

    /// Configuration file path
    #[arg(short, long, default_value = "/etc/koompi/daemon.toml")]
    config: String,

    /// Log level
    #[arg(short, long, default_value = "info")]
    log_level: String,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();

    // Initialize logging
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(&cli.log_level))
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Starting KOOMPI OS daemon");

    // Reset boot counter on successful start
    if let Err(e) = koompi_snapshots::rollback::RollbackManager::reset_boot_counter() {
        tracing::warn!("Failed to reset boot counter: {}", e);
    }

    // Load configuration
    let config = service::load_config(&cli.config)?;

    // Start the D-Bus service
    let service = service::KoompiService::new(config).await?;
    
    // Run the service
    service.run().await?;

    Ok(())
}
