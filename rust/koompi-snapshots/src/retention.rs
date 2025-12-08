//! Snapshot retention policy management

use crate::{BtrfsOperations, SnapshotError, SnapshotType};

/// Manages snapshot retention policy
pub struct RetentionPolicy {
    max_snapshots: usize,
}

impl RetentionPolicy {
    pub fn new(max_snapshots: usize) -> Self {
        Self { max_snapshots }
    }

    /// Apply retention policy - delete old snapshots if over limit
    pub async fn apply(&self, btrfs: &BtrfsOperations) -> Result<(), SnapshotError> {
        let mut snapshots = btrfs.list_snapshots().await?;

        // Sort by creation time (oldest first)
        snapshots.sort_by(|a, b| a.created_at.cmp(&b.created_at));

        // Keep manual and pre-rollback snapshots longer
        let (protected, deletable): (Vec<_>, Vec<_>) = snapshots
            .into_iter()
            .partition(|s| {
                matches!(s.snapshot_type, SnapshotType::Manual | SnapshotType::PreRollback)
            });

        // Calculate how many we need to delete
        let total = protected.len() + deletable.len();
        if total <= self.max_snapshots {
            return Ok(());
        }

        let to_delete = total - self.max_snapshots;

        // Delete oldest deletable snapshots first
        for snapshot in deletable.iter().take(to_delete) {
            tracing::info!(
                snapshot_id = %snapshot.id,
                "Deleting snapshot due to retention policy"
            );
            btrfs.delete_snapshot(&snapshot.id).await?;
        }

        Ok(())
    }
}
