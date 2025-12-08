//! KOOMPI Snapshots - Btrfs snapshot management
//!
//! This crate provides the core immutability features of KOOMPI OS through
//! Btrfs snapshot management, including creation, rollback, and retention.

mod btrfs;
mod retention;
mod rollback;

pub use btrfs::BtrfsOperations;
pub use retention::RetentionPolicy;
pub use rollback::RollbackManager;

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Errors that can occur during snapshot operations
#[derive(Error, Debug)]
pub enum SnapshotError {
    #[error("Failed to create snapshot: {0}")]
    CreateFailed(String),

    #[error("Snapshot not found: {0}")]
    NotFound(String),

    #[error("Rollback failed: {0}")]
    RollbackFailed(String),

    #[error("Invalid snapshot name: {0}")]
    InvalidName(String),

    #[error("Btrfs operation failed: {0}")]
    BtrfsError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Insufficient space for snapshot")]
    InsufficientSpace,
}

/// Represents a system snapshot
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    /// Unique identifier (timestamp-based)
    pub id: String,
    /// Human-readable name
    pub name: String,
    /// Creation timestamp
    pub created_at: DateTime<Utc>,
    /// Size in bytes (estimated)
    pub size_bytes: u64,
    /// Snapshot type
    pub snapshot_type: SnapshotType,
    /// Description or reason for snapshot
    pub description: Option<String>,
}

/// Type of snapshot
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum SnapshotType {
    /// Created before system update
    PreUpdate,
    /// Created before package installation
    PreInstall,
    /// Manual user-created snapshot
    Manual,
    /// Scheduled automatic snapshot
    Scheduled,
    /// Created before rollback
    PreRollback,
}

/// Configuration for the snapshot manager
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnapshotConfig {
    /// Root subvolume path
    pub root_subvol: String,
    /// Snapshots directory
    pub snapshots_dir: String,
    /// Maximum number of snapshots to keep
    pub max_snapshots: usize,
    /// Minimum free space (bytes) required for new snapshot
    pub min_free_space: u64,
}

impl Default for SnapshotConfig {
    fn default() -> Self {
        Self {
            root_subvol: "/@".to_string(),
            snapshots_dir: "/.snapshots".to_string(),
            max_snapshots: 10,
            min_free_space: 5 * 1024 * 1024 * 1024, // 5 GB
        }
    }
}

/// Main snapshot manager
pub struct SnapshotManager {
    config: SnapshotConfig,
    btrfs: BtrfsOperations,
    retention: RetentionPolicy,
}

impl SnapshotManager {
    /// Create a new snapshot manager with the given configuration
    pub fn new(config: SnapshotConfig) -> Self {
        let btrfs = BtrfsOperations::new(&config.root_subvol, &config.snapshots_dir);
        let retention = RetentionPolicy::new(config.max_snapshots);

        Self {
            config,
            btrfs,
            retention,
        }
    }

    /// Create a new snapshot
    pub async fn create(
        &self,
        name: &str,
        snapshot_type: SnapshotType,
        description: Option<String>,
    ) -> Result<Snapshot, SnapshotError> {
        // Validate name
        if name.is_empty() || name.len() > 64 {
            return Err(SnapshotError::InvalidName(
                "Name must be 1-64 characters".to_string(),
            ));
        }

        // Check available space
        if !self.btrfs.has_sufficient_space(self.config.min_free_space)? {
            return Err(SnapshotError::InsufficientSpace);
        }

        // Apply retention policy before creating new snapshot
        self.retention.apply(&self.btrfs).await?;

        // Create the snapshot
        let snapshot = self.btrfs.create_snapshot(name, snapshot_type, description).await?;

        tracing::info!(
            snapshot_id = %snapshot.id,
            name = %snapshot.name,
            "Created snapshot"
        );

        Ok(snapshot)
    }

    /// List all snapshots
    pub async fn list(&self) -> Result<Vec<Snapshot>, SnapshotError> {
        self.btrfs.list_snapshots().await
    }

    /// Get a specific snapshot by ID
    pub async fn get(&self, id: &str) -> Result<Snapshot, SnapshotError> {
        self.btrfs
            .get_snapshot(id)
            .await?
            .ok_or_else(|| SnapshotError::NotFound(id.to_string()))
    }

    /// Delete a snapshot
    pub async fn delete(&self, id: &str) -> Result<(), SnapshotError> {
        self.btrfs.delete_snapshot(id).await?;
        tracing::info!(snapshot_id = %id, "Deleted snapshot");
        Ok(())
    }

    /// Rollback to a specific snapshot
    pub async fn rollback(&self, id: &str) -> Result<(), SnapshotError> {
        // Create a pre-rollback snapshot first
        self.create(
            &format!("pre-rollback-{}", id),
            SnapshotType::PreRollback,
            Some(format!("Before rollback to {}", id)),
        )
        .await?;

        // Perform the rollback
        let rollback_manager = RollbackManager::new(&self.btrfs);
        rollback_manager.rollback_to(id).await?;

        tracing::info!(snapshot_id = %id, "Rollback completed - reboot required");

        Ok(())
    }

    /// Get snapshot statistics
    pub async fn stats(&self) -> Result<SnapshotStats, SnapshotError> {
        let snapshots = self.list().await?;
        let total_size: u64 = snapshots.iter().map(|s| s.size_bytes).sum();

        Ok(SnapshotStats {
            count: snapshots.len(),
            total_size_bytes: total_size,
            oldest: snapshots.first().map(|s| s.created_at),
            newest: snapshots.last().map(|s| s.created_at),
        })
    }
}

/// Snapshot statistics
#[derive(Debug, Serialize)]
pub struct SnapshotStats {
    pub count: usize,
    pub total_size_bytes: u64,
    pub oldest: Option<DateTime<Utc>>,
    pub newest: Option<DateTime<Utc>>,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = SnapshotConfig::default();
        assert_eq!(config.max_snapshots, 10);
        assert_eq!(config.min_free_space, 5 * 1024 * 1024 * 1024);
    }

    #[test]
    fn test_snapshot_type_serialize() {
        let st = SnapshotType::PreUpdate;
        let json = serde_json::to_string(&st).unwrap();
        assert_eq!(json, "\"PreUpdate\"");
    }
}
