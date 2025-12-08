//! D-Bus interface for KOOMPI daemon

use koompi_snapshots::{SnapshotManager, SnapshotType};
use std::sync::Arc;
use tokio::sync::RwLock;
use zbus::interface;

/// D-Bus interface for KOOMPI OS
pub struct KoompiDbus {
    snapshot_manager: Arc<RwLock<SnapshotManager>>,
}

impl KoompiDbus {
    pub fn new(snapshot_manager: Arc<RwLock<SnapshotManager>>) -> Self {
        Self { snapshot_manager }
    }
}

#[interface(name = "org.koompi.Daemon")]
impl KoompiDbus {
    /// Get daemon version
    async fn version(&self) -> String {
        env!("CARGO_PKG_VERSION").to_string()
    }

    /// Create a snapshot
    async fn create_snapshot(&self, name: &str, description: &str) -> Result<String, zbus::fdo::Error> {
        let manager = self.snapshot_manager.read().await;
        let desc = if description.is_empty() {
            None
        } else {
            Some(description.to_string())
        };

        match manager.create(name, SnapshotType::Manual, desc).await {
            Ok(snapshot) => Ok(snapshot.id),
            Err(e) => Err(zbus::fdo::Error::Failed(e.to_string())),
        }
    }

    /// List all snapshots
    async fn list_snapshots(&self) -> Result<String, zbus::fdo::Error> {
        let manager = self.snapshot_manager.read().await;
        match manager.list().await {
            Ok(snapshots) => {
                let json = serde_json::to_string(&snapshots)
                    .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
                Ok(json)
            }
            Err(e) => Err(zbus::fdo::Error::Failed(e.to_string())),
        }
    }

    /// Rollback to a snapshot
    async fn rollback(&self, snapshot_id: &str) -> Result<bool, zbus::fdo::Error> {
        let manager = self.snapshot_manager.read().await;
        match manager.rollback(snapshot_id).await {
            Ok(()) => Ok(true),
            Err(e) => Err(zbus::fdo::Error::Failed(e.to_string())),
        }
    }

    /// Delete a snapshot
    async fn delete_snapshot(&self, snapshot_id: &str) -> Result<bool, zbus::fdo::Error> {
        let manager = self.snapshot_manager.read().await;
        match manager.delete(snapshot_id).await {
            Ok(()) => Ok(true),
            Err(e) => Err(zbus::fdo::Error::Failed(e.to_string())),
        }
    }

    /// Get snapshot statistics
    async fn snapshot_stats(&self) -> Result<String, zbus::fdo::Error> {
        let manager = self.snapshot_manager.read().await;
        match manager.stats().await {
            Ok(stats) => {
                let json = serde_json::to_string(&stats)
                    .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
                Ok(json)
            }
            Err(e) => Err(zbus::fdo::Error::Failed(e.to_string())),
        }
    }
}
