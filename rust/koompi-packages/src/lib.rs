//! KOOMPI Package Management
//!
//! Unified package management across multiple backends:
//! - Pacman (official Arch packages)
//! - AUR (community packages)
//! - Flatpak (sandboxed applications)

mod pacman;
mod aur;
mod flatpak;

use serde::{Deserialize, Serialize};
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PackageError {
    #[error("Package not found: {0}")]
    NotFound(String),

    #[error("Installation failed: {0}")]
    InstallFailed(String),

    #[error("Backend error: {0}")]
    BackendError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),
}

/// Package information
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Package {
    pub name: String,
    pub version: String,
    pub description: String,
    pub backend: Backend,
    pub installed: bool,
    pub size_bytes: u64,
}

/// Package backend type
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub enum Backend {
    Pacman,
    Aur,
    Flatpak,
}

/// Unified package manager
pub struct PackageManager {
    pacman: pacman::PacmanBackend,
    aur: aur::AurBackend,
    flatpak: flatpak::FlatpakBackend,
}

impl PackageManager {
    pub fn new() -> Self {
        Self {
            pacman: pacman::PacmanBackend::new(),
            aur: aur::AurBackend::new(),
            flatpak: flatpak::FlatpakBackend::new(),
        }
    }

    /// Search for packages across all backends
    pub async fn search(&self, query: &str) -> Result<Vec<Package>, PackageError> {
        let mut results = Vec::new();

        // Search pacman
        results.extend(self.pacman.search(query).await?);

        // Search AUR
        results.extend(self.aur.search(query).await?);

        // Search Flatpak
        results.extend(self.flatpak.search(query).await?);

        Ok(results)
    }

    /// Install a package
    pub async fn install(&self, name: &str, backend: Option<Backend>) -> Result<(), PackageError> {
        let backend = match backend {
            Some(b) => b,
            None => self.detect_backend(name).await?,
        };

        match backend {
            Backend::Pacman => self.pacman.install(name).await,
            Backend::Aur => self.aur.install(name).await,
            Backend::Flatpak => self.flatpak.install(name).await,
        }
    }

    /// Remove a package
    pub async fn remove(&self, name: &str) -> Result<(), PackageError> {
        // Try each backend
        if self.pacman.is_installed(name).await? {
            return self.pacman.remove(name).await;
        }
        if self.flatpak.is_installed(name).await? {
            return self.flatpak.remove(name).await;
        }

        Err(PackageError::NotFound(name.to_string()))
    }

    /// Update all packages
    pub async fn update(&self) -> Result<UpdateResult, PackageError> {
        let pacman_result = self.pacman.update().await?;
        let flatpak_result = self.flatpak.update().await?;

        Ok(UpdateResult {
            packages_updated: pacman_result + flatpak_result,
        })
    }

    /// Detect the best backend for a package
    async fn detect_backend(&self, name: &str) -> Result<Backend, PackageError> {
        // Check pacman first
        if self.pacman.exists(name).await? {
            return Ok(Backend::Pacman);
        }

        // Then Flatpak
        if self.flatpak.exists(name).await? {
            return Ok(Backend::Flatpak);
        }

        // Finally AUR
        if self.aur.exists(name).await? {
            return Ok(Backend::Aur);
        }

        Err(PackageError::NotFound(name.to_string()))
    }
}

impl Default for PackageManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Result of an update operation
#[derive(Debug, Serialize)]
pub struct UpdateResult {
    pub packages_updated: usize,
}
