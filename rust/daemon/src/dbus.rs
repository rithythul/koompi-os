//! D-Bus interface for KOOMPI daemon

use snapshots::{SnapshotManager, SnapshotType};
use packages::PackageManager;
use std::sync::Arc;
use tokio::sync::RwLock;
use zbus::interface;
use sysinfo::System;
use serde::Serialize;

#[derive(Serialize)]
struct SystemStats {
    cpu_usage: f32,
    memory_used: u64,
    memory_total: u64,
    uptime: u64,
}

/// D-Bus interface for KOOMPI OS
pub struct KoompiDbus {
    snapshot_manager: Arc<RwLock<SnapshotManager>>,
    package_manager: Arc<RwLock<PackageManager>>,
    system: Arc<RwLock<System>>,
}

impl KoompiDbus {
    pub fn new(
        snapshot_manager: Arc<RwLock<SnapshotManager>>,
        package_manager: Arc<RwLock<PackageManager>>,
    ) -> Self {
        Self { 
            snapshot_manager,
            package_manager,
            system: Arc::new(RwLock::new(System::new_all())),
        }
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

    /// Get system statistics
    async fn get_system_stats(&self) -> Result<String, zbus::fdo::Error> {
        let mut sys = self.system.write().await;
        sys.refresh_all();
        
        let stats = SystemStats {
            cpu_usage: sys.global_cpu_info().cpu_usage(),
            memory_used: sys.used_memory(),
            memory_total: sys.total_memory(),
            uptime: System::uptime(),
        };

        serde_json::to_string(&stats)
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
    }

    /// Install a package with automatic snapshot
    async fn install_package(&self, name: &str) -> Result<bool, zbus::fdo::Error> {
        // 1. Create snapshot
        {
            let snap_mgr = self.snapshot_manager.read().await;
            snap_mgr.create(
                &format!("pre-install-{}", name),
                SnapshotType::PreInstall,
                Some(format!("Before installing {}", name))
            ).await.map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        }
        
        // 2. Install package
        {
            let pkg_mgr = self.package_manager.read().await;
            pkg_mgr.install(name, None).await
                .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;
        }
            
        Ok(true)
    }

    /// Install Windows application support (WinApps)
    async fn install_windows_support(&self) -> Result<bool, zbus::fdo::Error> {
        self.install_package("winapps").await
    }
}
