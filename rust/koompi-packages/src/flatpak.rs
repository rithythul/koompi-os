//! Flatpak backend for sandboxed applications

use crate::{Backend, Package, PackageError};
use std::process::Command;

pub struct FlatpakBackend;

impl FlatpakBackend {
    pub fn new() -> Self {
        Self
    }

    pub async fn search(&self, query: &str) -> Result<Vec<Package>, PackageError> {
        let output = Command::new("flatpak")
            .args(["search", query])
            .output()?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        Ok(self.parse_search_output(&stdout))
    }

    pub async fn install(&self, name: &str) -> Result<(), PackageError> {
        let status = Command::new("flatpak")
            .args(["install", "-y", "flathub", name])
            .status()?;

        if status.success() {
            Ok(())
        } else {
            Err(PackageError::InstallFailed(name.to_string()))
        }
    }

    pub async fn remove(&self, name: &str) -> Result<(), PackageError> {
        let status = Command::new("flatpak")
            .args(["uninstall", "-y", name])
            .status()?;

        if status.success() {
            Ok(())
        } else {
            Err(PackageError::BackendError(format!("Failed to remove {}", name)))
        }
    }

    pub async fn update(&self) -> Result<usize, PackageError> {
        let status = Command::new("flatpak")
            .args(["update", "-y"])
            .status()?;

        if status.success() {
            Ok(0)
        } else {
            Err(PackageError::BackendError("Flatpak update failed".to_string()))
        }
    }

    pub async fn exists(&self, name: &str) -> Result<bool, PackageError> {
        let output = Command::new("flatpak")
            .args(["search", name])
            .output()?;

        Ok(output.status.success() && !output.stdout.is_empty())
    }

    pub async fn is_installed(&self, name: &str) -> Result<bool, PackageError> {
        let output = Command::new("flatpak")
            .args(["list", "--app"])
            .output()?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        Ok(stdout.contains(name))
    }

    fn parse_search_output(&self, output: &str) -> Vec<Package> {
        let mut packages = Vec::new();

        for line in output.lines().skip(1) {
            // Skip header
            let parts: Vec<&str> = line.split('\t').collect();
            if parts.len() >= 3 {
                packages.push(Package {
                    name: parts[0].to_string(),
                    version: parts.get(2).unwrap_or(&"").to_string(),
                    description: parts.get(1).unwrap_or(&"").to_string(),
                    backend: Backend::Flatpak,
                    installed: false,
                    size_bytes: 0,
                });
            }
        }

        packages
    }
}
