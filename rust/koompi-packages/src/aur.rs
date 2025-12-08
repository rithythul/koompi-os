//! AUR backend for community packages

use crate::{Backend, Package, PackageError};

pub struct AurBackend;

impl AurBackend {
    pub fn new() -> Self {
        Self
    }

    pub async fn search(&self, _query: &str) -> Result<Vec<Package>, PackageError> {
        // TODO: Implement AUR search via aurweb RPC
        Ok(Vec::new())
    }

    pub async fn install(&self, name: &str) -> Result<(), PackageError> {
        // TODO: Implement AUR installation (via paru or yay)
        Err(PackageError::BackendError(format!(
            "AUR installation not yet implemented for {}",
            name
        )))
    }

    pub async fn exists(&self, _name: &str) -> Result<bool, PackageError> {
        // TODO: Check AUR
        Ok(false)
    }
}
