//! System rollback management

use crate::{BtrfsOperations, SnapshotError};
use std::process::Command;

/// Manages system rollback operations
pub struct RollbackManager<'a> {
    btrfs: &'a BtrfsOperations,
}

impl<'a> RollbackManager<'a> {
    pub fn new(btrfs: &'a BtrfsOperations) -> Self {
        Self { btrfs }
    }

    /// Rollback the system to a specific snapshot
    ///
    /// This operation:
    /// 1. Verifies the target snapshot exists
    /// 2. Updates the boot configuration to use the snapshot
    /// 3. Requires a reboot to complete
    pub async fn rollback_to(&self, snapshot_id: &str) -> Result<(), SnapshotError> {
        // Verify snapshot exists
        let snapshot = self.btrfs.get_snapshot(snapshot_id).await?;
        if snapshot.is_none() {
            return Err(SnapshotError::NotFound(snapshot_id.to_string()));
        }

        // Update the default subvolume for next boot
        // This uses btrfs subvolume set-default
        let snapshot_path = format!("/.snapshots/{}", snapshot_id);
        
        // Get the subvolume ID
        let output = Command::new("btrfs")
            .args(["subvolume", "show", &snapshot_path])
            .output()?;

        if !output.status.success() {
            return Err(SnapshotError::RollbackFailed(
                "Could not find snapshot subvolume".to_string(),
            ));
        }

        let stdout = String::from_utf8_lossy(&output.stdout);
        let subvol_id = Self::parse_subvolume_id(&stdout)?;

        // Set as default for next boot
        let output = Command::new("btrfs")
            .args(["subvolume", "set-default", &subvol_id.to_string(), "/"])
            .output()?;

        if !output.status.success() {
            return Err(SnapshotError::RollbackFailed(
                String::from_utf8_lossy(&output.stderr).to_string(),
            ));
        }

        // Update bootloader configuration
        self.update_bootloader(snapshot_id)?;

        tracing::info!(
            snapshot_id = %snapshot_id,
            subvol_id = %subvol_id,
            "Rollback configured - reboot required"
        );

        Ok(())
    }

    /// Parse subvolume ID from btrfs subvolume show output
    fn parse_subvolume_id(output: &str) -> Result<u64, SnapshotError> {
        for line in output.lines() {
            if line.trim().starts_with("Subvolume ID:") {
                if let Some(id_str) = line.split(':').nth(1) {
                    if let Ok(id) = id_str.trim().parse::<u64>() {
                        return Ok(id);
                    }
                }
            }
        }
        Err(SnapshotError::RollbackFailed(
            "Could not parse subvolume ID".to_string(),
        ))
    }

    /// Update bootloader to reference the snapshot
    fn update_bootloader(&self, snapshot_id: &str) -> Result<(), SnapshotError> {
        // Update systemd-boot or GRUB configuration
        // For systemd-boot, we update the loader entry
        let entry_content = format!(
            r#"title   KOOMPI OS (Rollback to {})
linux   /vmlinuz-linux-lts
initrd  /initramfs-linux-lts.img
options root=LABEL=koompi rootflags=subvol=/.snapshots/{} rw quiet
"#,
            snapshot_id, snapshot_id
        );

        let entry_path = format!("/boot/loader/entries/koompi-rollback.conf");
        std::fs::write(&entry_path, entry_content)?;

        // Set as default entry
        let loader_conf = "default koompi-rollback.conf\ntimeout 5\n";
        std::fs::write("/boot/loader/loader.conf", loader_conf)?;

        Ok(())
    }

    /// Check if automatic rollback should trigger (3 failed boots)
    pub fn check_auto_rollback() -> Result<bool, SnapshotError> {
        // Read boot counter from /var/lib/koompi/boot-counter
        let counter_path = "/var/lib/koompi/boot-counter";
        
        if let Ok(content) = std::fs::read_to_string(counter_path) {
            if let Ok(count) = content.trim().parse::<u32>() {
                return Ok(count >= 3);
            }
        }

        Ok(false)
    }

    /// Increment boot failure counter
    pub fn increment_boot_counter() -> Result<(), SnapshotError> {
        let counter_path = "/var/lib/koompi/boot-counter";
        let count = std::fs::read_to_string(counter_path)
            .ok()
            .and_then(|s| s.trim().parse::<u32>().ok())
            .unwrap_or(0);

        std::fs::create_dir_all("/var/lib/koompi")?;
        std::fs::write(counter_path, (count + 1).to_string())?;

        Ok(())
    }

    /// Reset boot counter (called on successful boot)
    pub fn reset_boot_counter() -> Result<(), SnapshotError> {
        let counter_path = "/var/lib/koompi/boot-counter";
        std::fs::write(counter_path, "0")?;
        Ok(())
    }
}
