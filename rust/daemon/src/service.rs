//! KOOMPI service implementation

use anyhow::Result;
use snapshots::{SnapshotConfig, SnapshotManager};
use packages::PackageManager;
use serde::Deserialize;
use std::sync::Arc;
use tokio::sync::RwLock;

/// Daemon configuration
#[derive(Debug, Deserialize)]
pub struct DaemonConfig {
    pub snapshots: SnapshotConfig,
    pub dbus: DbusConfig,
}

#[derive(Debug, Deserialize)]
pub struct DbusConfig {
    pub bus_name: String,
    pub object_path: String,
}

impl Default for DaemonConfig {
    fn default() -> Self {
        Self {
            snapshots: SnapshotConfig::default(),
            dbus: DbusConfig {
                bus_name: "org.koompi.Daemon".to_string(),
                object_path: "/org/koompi/Daemon".to_string(),
            },
        }
    }
}

/// Load configuration from file
pub fn load_config(path: &str) -> Result<DaemonConfig> {
    if std::path::Path::new(path).exists() {
        let content = std::fs::read_to_string(path)?;
        let config: DaemonConfig = toml::from_str(&content)?;
        Ok(config)
    } else {
        tracing::warn!("Config file not found, using defaults");
        Ok(DaemonConfig::default())
    }
}

/// Main KOOMPI service
pub struct KoompiService {
    config: DaemonConfig,
    snapshot_manager: Arc<RwLock<SnapshotManager>>,
    package_manager: Arc<RwLock<PackageManager>>,
}

impl KoompiService {
    pub async fn new(config: DaemonConfig) -> Result<Self> {
        let snapshot_manager = SnapshotManager::new(config.snapshots.clone());
        let package_manager = PackageManager::new();

        Ok(Self {
            config,
            snapshot_manager: Arc::new(RwLock::new(snapshot_manager)),
            package_manager: Arc::new(RwLock::new(package_manager)),
        })
    }

    pub async fn run(&self) -> Result<()> {
        tracing::info!(
            bus_name = %self.config.dbus.bus_name,
            "Starting D-Bus service"
        );

        // Set up D-Bus connection
        let connection = zbus::Connection::session().await?;

        // Create the D-Bus interface
        let interface = crate::dbus::KoompiDbus::new(
            self.snapshot_manager.clone(),
            self.package_manager.clone(),
        );

        connection
            .object_server()
            .at(self.config.dbus.object_path.as_str(), interface)
            .await?;

        connection.request_name(self.config.dbus.bus_name.as_str()).await?;

        tracing::info!("KOOMPI daemon ready");

        // Keep running
        loop {
            tokio::time::sleep(tokio::time::Duration::from_secs(60)).await;
        }
    }
}
