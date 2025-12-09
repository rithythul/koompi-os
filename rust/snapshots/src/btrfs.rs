//! Btrfs filesystem operations

use crate::{Snapshot, SnapshotError, SnapshotType};
use chrono::Utc;
use std::path::PathBuf;
use std::process::Command;

/// Low-level Btrfs operations
pub struct BtrfsOperations {
    root_subvol: PathBuf,
    snapshots_dir: PathBuf,
}

impl BtrfsOperations {
    pub fn new(root_subvol: &str, snapshots_dir: &str) -> Self {
        Self {
            root_subvol: PathBuf::from(root_subvol),
            snapshots_dir: PathBuf::from(snapshots_dir),
        }
    }

    /// Check if there's sufficient space for a new snapshot
    pub fn has_sufficient_space(&self, min_bytes: u64) -> Result<bool, SnapshotError> {
        let output = Command::new("btrfs")
            .args(["filesystem", "usage", "-b", self.root_subvol.to_str().unwrap()])
            .output()?;

        if !output.status.success() {
            return Err(SnapshotError::BtrfsError(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        // Parse available space from output
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            if line.contains("Free (estimated):") {
                if let Some(bytes_str) = line.split_whitespace().nth(2) {
                    if let Ok(bytes) = bytes_str.parse::<u64>() {
                        return Ok(bytes >= min_bytes);
                    }
                }
            }
        }

        // If we can't determine, assume we have space
        Ok(true)
    }

    /// Create a new snapshot
    pub async fn create_snapshot(
        &self,
        name: &str,
        snapshot_type: SnapshotType,
        description: Option<String>,
    ) -> Result<Snapshot, SnapshotError> {
        let now = Utc::now();
        let id = now.format("%Y%m%d-%H%M%S").to_string();
        let snapshot_path = self.snapshots_dir.join(&id);

        // Create snapshot using btrfs command (RW first to write metadata)
        let output = Command::new("btrfs")
            .args([
                "subvolume",
                "snapshot",
                self.root_subvol.to_str().unwrap(),
                snapshot_path.to_str().unwrap(),
            ])
            .output()?;

        if !output.status.success() {
            return Err(SnapshotError::CreateFailed(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        // Get snapshot size (estimated)
        let size_bytes = self.get_subvolume_size(&snapshot_path)?;

        let snapshot = Snapshot {
            id,
            name: name.to_string(),
            created_at: now,
            size_bytes,
            snapshot_type,
            description,
        };

        // Save metadata
        self.save_metadata(&snapshot)?;

        // Make read-only
        let output = Command::new("btrfs")
            .args([
                "property",
                "set",
                snapshot_path.to_str().unwrap(),
                "ro",
                "true",
            ])
            .output()?;

        if !output.status.success() {
            // Try to cleanup if setting RO fails
            let _ = std::fs::remove_dir_all(&snapshot_path);
            return Err(SnapshotError::BtrfsError(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        Ok(snapshot)
    }

    /// List all snapshots
    pub async fn list_snapshots(&self) -> Result<Vec<Snapshot>, SnapshotError> {
        let mut snapshots = Vec::new();

        if !self.snapshots_dir.exists() {
            return Ok(snapshots);
        }

        for entry in std::fs::read_dir(&self.snapshots_dir)? {
            let entry = entry?;
            let path = entry.path();

            if path.is_dir() {
                if let Some(snapshot) = self.load_metadata(&path)? {
                    snapshots.push(snapshot);
                }
            }
        }

        // Sort by creation time
        snapshots.sort_by(|a, b| a.created_at.cmp(&b.created_at));

        Ok(snapshots)
    }

    /// Get a specific snapshot
    pub async fn get_snapshot(&self, id: &str) -> Result<Option<Snapshot>, SnapshotError> {
        let path = self.snapshots_dir.join(id);
        if path.exists() {
            self.load_metadata(&path)
        } else {
            Ok(None)
        }
    }

    /// Delete a snapshot
    pub async fn delete_snapshot(&self, id: &str) -> Result<(), SnapshotError> {
        let snapshot_path = self.snapshots_dir.join(id);

        if !snapshot_path.exists() {
            return Err(SnapshotError::NotFound(id.to_string()));
        }

        let output = Command::new("btrfs")
            .args([
                "subvolume",
                "delete",
                snapshot_path.to_str().unwrap(),
            ])
            .output()?;

        if !output.status.success() {
            return Err(SnapshotError::BtrfsError(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        Ok(())
    }

    /// Get the size of a subvolume
    fn get_subvolume_size(&self, path: &PathBuf) -> Result<u64, SnapshotError> {
        let output = Command::new("btrfs")
            .args(["subvolume", "show", path.to_str().unwrap()])
            .output()?;

        if !output.status.success() {
            return Ok(0); // Return 0 if we can't determine size
        }

        // Parse size from output (this is a rough estimate)
        // In production, we'd use qgroups for accurate sizing
        Ok(0)
    }

    /// Save snapshot metadata to a JSON file
    fn save_metadata(&self, snapshot: &Snapshot) -> Result<(), SnapshotError> {
        let metadata_path = self.snapshots_dir.join(&snapshot.id).join("metadata.json");
        let json = serde_json::to_string_pretty(snapshot)
            .map_err(|e| SnapshotError::BtrfsError(e.to_string()))?;
        std::fs::write(metadata_path, json)?;
        Ok(())
    }

    /// Load snapshot metadata from JSON file
    fn load_metadata(&self, path: &PathBuf) -> Result<Option<Snapshot>, SnapshotError> {
        let metadata_path = path.join("metadata.json");
        if !metadata_path.exists() {
            return Ok(None);
        }

        let json = std::fs::read_to_string(metadata_path)?;
        let snapshot: Snapshot = serde_json::from_str(&json)
            .map_err(|e| SnapshotError::BtrfsError(e.to_string()))?;

        Ok(Some(snapshot))
    }
}
