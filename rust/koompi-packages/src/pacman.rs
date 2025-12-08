//! Pacman backend for official Arch packages

use crate::{Backend, Package, PackageError};
use std::process::Command;

pub struct PacmanBackend;

impl PacmanBackend {
    pub fn new() -> Self {
        Self
    }

    pub async fn search(&self, query: &str) -> Result<Vec<Package>, PackageError> {
        let output = Command::new("pacman")
            .args(["-Ss", query])
            .output()?;

        let stdout = String::from_utf8_lossy(&output.stdout);
        Ok(self.parse_search_output(&stdout))
    }

    pub async fn install(&self, name: &str) -> Result<(), PackageError> {
        let status = Command::new("pacman")
            .args(["-S", "--noconfirm", name])
            .status()?;

        if status.success() {
            Ok(())
        } else {
            Err(PackageError::InstallFailed(name.to_string()))
        }
    }

    pub async fn remove(&self, name: &str) -> Result<(), PackageError> {
        let status = Command::new("pacman")
            .args(["-R", "--noconfirm", name])
            .status()?;

        if status.success() {
            Ok(())
        } else {
            Err(PackageError::BackendError(format!("Failed to remove {}", name)))
        }
    }

    pub async fn update(&self) -> Result<usize, PackageError> {
        let status = Command::new("pacman")
            .args(["-Syu", "--noconfirm"])
            .status()?;

        if status.success() {
            Ok(0) // TODO: parse actual count
        } else {
            Err(PackageError::BackendError("Update failed".to_string()))
        }
    }

    pub async fn exists(&self, name: &str) -> Result<bool, PackageError> {
        let output = Command::new("pacman")
            .args(["-Si", name])
            .output()?;

        Ok(output.status.success())
    }

    pub async fn is_installed(&self, name: &str) -> Result<bool, PackageError> {
        let output = Command::new("pacman")
            .args(["-Q", name])
            .output()?;

        Ok(output.status.success())
    }

    fn parse_search_output(&self, output: &str) -> Vec<Package> {
        let mut packages = Vec::new();
        let mut lines = output.lines().peekable();

        while let Some(line) = lines.next() {
            if line.starts_with("    ") {
                continue; // Description line
            }

            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                let name_repo = parts[0];
                let version = parts[1];

                if let Some(name) = name_repo.split('/').nth(1) {
                    let description = lines
                        .peek()
                        .map(|l| l.trim().to_string())
                        .unwrap_or_default();

                    packages.push(Package {
                        name: name.to_string(),
                        version: version.to_string(),
                        description,
                        backend: Backend::Pacman,
                        installed: false,
                        size_bytes: 0,
                    });
                }
            }
        }

        packages
    }
}
