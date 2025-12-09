//! KOOMPI Mesh - Classroom P2P Networking
//!
//! Provides offline-capable peer-to-peer networking for classroom use:
//! - Device discovery via mDNS/Avahi
//! - File synchronization via Syncthing
//! - Teacher-student communication

use serde::{Deserialize, Serialize};
use thiserror::Error;
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

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
    devices: Arc<Mutex<HashMap<String, Device>>>,
    mdns: ServiceDaemon,
}

impl MeshManager {
    pub fn new(device_id: String, role: DeviceRole) -> Result<Self, MeshError> {
        let mdns = ServiceDaemon::new().map_err(|e| MeshError::DiscoveryFailed(e.to_string()))?;
        
        Ok(Self {
            device_id,
            role,
            devices: Arc::new(Mutex::new(HashMap::new())),
            mdns,
        })
    }

    /// Start device discovery
    pub fn start_discovery(&self) -> Result<(), MeshError> {
        tracing::info!("Starting mesh discovery");
        
        // Register self
        let service_type = "_koompi._tcp.local.";
        let instance_name = &self.device_id;
        let host_name = format!("{}.local.", self.device_id);
        let port = 8080; // Placeholder port
        let role_str = format!("{:?}", self.role);
        let properties = [("role", role_str.as_str())];

        let my_service = ServiceInfo::new(
            service_type,
            instance_name,
            &host_name,
            "",
            port,
            &properties[..],
        ).map_err(|e| MeshError::DiscoveryFailed(e.to_string()))?;

        self.mdns.register(my_service)
            .map_err(|e| MeshError::DiscoveryFailed(e.to_string()))?;

        // Browse for others
        let receiver = self.mdns.browse(service_type)
            .map_err(|e| MeshError::DiscoveryFailed(e.to_string()))?;

        let devices = self.devices.clone();
        
        // Spawn a thread to handle discovery events
        std::thread::spawn(move || {
            while let Ok(event) = receiver.recv() {
                match event {
                    ServiceEvent::ServiceResolved(info) => {
                        let id = info.get_fullname().to_string();
                        let ip = info.get_addresses().iter().next().map(|ip| ip.to_string()).unwrap_or_default();
                        let role_str = info.get_property_val_str("role").unwrap_or("Student");
                        let role = if role_str == "Teacher" { DeviceRole::Teacher } else { DeviceRole::Student };
                        
                        let device = Device {
                            id: id.clone(),
                            name: info.get_hostname().to_string(),
                            role,
                            ip_address: ip,
                            last_seen: chrono::Utc::now(),
                            online: true,
                        };
                        
                        if let Ok(mut map) = devices.lock() {
                            map.insert(id, device);
                        }
                    }
                    ServiceEvent::ServiceRemoved(_service_type, fullname) => {
                         if let Ok(mut map) = devices.lock() {
                            if let Some(device) = map.get_mut(&fullname) {
                                device.online = false;
                            }
                        }
                    }
                    _ => {}
                }
            }
        });

        Ok(())
    }

    /// Get all discovered devices
    pub fn get_devices(&self) -> Vec<Device> {
        if let Ok(map) = self.devices.lock() {
            map.values().cloned().collect()
        } else {
            Vec::new()
        }
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
        // For now, just log it
        Ok(())
    }

    /// Broadcast files to all students (teacher only)
    pub async fn broadcast(&self, files: &[String]) -> Result<(), MeshError> {
        if self.role != DeviceRole::Teacher {
            return Err(MeshError::SyncFailed(
                "Only teachers can broadcast".to_string(),
            ));
        }

        let student_ids: Vec<String> = self.get_devices()
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
