//! KOOMPI Mesh - Classroom P2P Networking
//!
//! Provides offline-capable peer-to-peer networking for classroom use:
//! - Device discovery via mDNS/Avahi
//! - File synchronization via Syncthing
//! - Teacher-student communication

use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum MeshError {
    #[error("Discovery failed: {0}")]
    DiscoveryFailed(String),

    #[error("Sync failed: {0}")]
    SyncFailed(String),

    #[error("Device not found: {0}")]
    DeviceNotFound(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

/// A device on the mesh network
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Device {
    pub id: String,
    pub name: String,
    pub role: DeviceRole,
    pub ip_address: String,
    pub last_seen: chrono::DateTime<chrono::Utc>,
    pub online: bool,
}

/// Role of a device in the classroom
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum DeviceRole {
    Teacher,
    Student,
}

/// Mesh network manager
pub struct MeshManager {
    device_id: String,
    role: DeviceRole,
    devices: Vec<Device>,
}

impl MeshManager {
    pub fn new(device_id: String, role: DeviceRole) -> Self {
        Self {
            device_id,
            role,
            devices: Vec::new(),
        }
    }

    /// Start device discovery
    pub async fn start_discovery(&mut self) -> Result<(), MeshError> {
        tracing::info!("Starting mesh discovery");
        // TODO: Implement mDNS discovery via Avahi
        Ok(())
    }

    /// Get all discovered devices
    pub fn get_devices(&self) -> &[Device] {
        &self.devices
    }

    /// Share files with specific devices
    pub async fn share_files(
        &self,
        files: &[String],
        targets: &[String],
    ) -> Result<(), MeshError> {
        tracing::info!(
            files = ?files,
            targets = ?targets,
            "Sharing files"
        );
        // TODO: Implement via Syncthing API
        Ok(())
    }

    /// Broadcast files to all students (teacher only)
    pub async fn broadcast(&self, files: &[String]) -> Result<(), MeshError> {
        if self.role != DeviceRole::Teacher {
            return Err(MeshError::SyncFailed(
                "Only teachers can broadcast".to_string(),
            ));
        }

        let student_ids: Vec<String> = self
            .devices
            .iter()
            .filter(|d| d.role == DeviceRole::Student && d.online)
            .map(|d| d.id.clone())
            .collect();

        self.share_files(files, &student_ids).await
    }

    /// Collect submissions from all students (teacher only)
    pub async fn collect_submissions(
        &self,
        assignment_id: &str,
    ) -> Result<Vec<Submission>, MeshError> {
        if self.role != DeviceRole::Teacher {
            return Err(MeshError::SyncFailed(
                "Only teachers can collect".to_string(),
            ));
        }

        tracing::info!(assignment_id = %assignment_id, "Collecting submissions");
        // TODO: Implement collection logic
        Ok(Vec::new())
    }
}

/// A student submission
#[derive(Debug, Serialize, Deserialize)]
pub struct Submission {
    pub student_id: String,
    pub student_name: String,
    pub assignment_id: String,
    pub files: Vec<String>,
    pub submitted_at: chrono::DateTime<chrono::Utc>,
}
