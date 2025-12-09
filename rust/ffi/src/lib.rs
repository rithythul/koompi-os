//! Python bindings for KOOMPI OS core functionality

use pyo3::prelude::*;
use pyo3::exceptions::PyRuntimeError;

/// Create a snapshot
#[pyfunction]
#[pyo3(signature = (name, description=None))]
fn create_snapshot(name: &str, description: Option<&str>) -> PyResult<String> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

    let config = snapshots::SnapshotConfig::default();
    let manager = snapshots::SnapshotManager::new(config);

    rt.block_on(async {
        manager
            .create(
                name,
                snapshots::SnapshotType::Manual,
                description.map(String::from),
            )
            .await
            .map(|s| s.id)
            .map_err(|e| PyRuntimeError::new_err(e.to_string()))
    })
}

/// List all snapshots
#[pyfunction]
fn list_snapshots() -> PyResult<String> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

    let config = snapshots::SnapshotConfig::default();
    let manager = snapshots::SnapshotManager::new(config);

    rt.block_on(async {
        manager
            .list()
            .await
            .map(|snapshots| serde_json::to_string(&snapshots).unwrap_or_default())
            .map_err(|e| PyRuntimeError::new_err(e.to_string()))
    })
}

/// Rollback to a snapshot
#[pyfunction]
fn rollback(snapshot_id: &str) -> PyResult<bool> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

    let config = snapshots::SnapshotConfig::default();
    let manager = snapshots::SnapshotManager::new(config);

    rt.block_on(async {
        manager
            .rollback(snapshot_id)
            .await
            .map(|_| true)
            .map_err(|e| PyRuntimeError::new_err(e.to_string()))
    })
}

/// Delete a snapshot
#[pyfunction]
fn delete_snapshot(snapshot_id: &str) -> PyResult<bool> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

    let config = snapshots::SnapshotConfig::default();
    let manager = snapshots::SnapshotManager::new(config);

    rt.block_on(async {
        manager
            .delete(snapshot_id)
            .await
            .map(|_| true)
            .map_err(|e| PyRuntimeError::new_err(e.to_string()))
    })
}

/// Search for packages
#[pyfunction]
fn search_packages(query: &str) -> PyResult<String> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

    let manager = packages::PackageManager::new();

    rt.block_on(async {
        manager
            .search(query)
            .await
            .map(|packages| serde_json::to_string(&packages).unwrap_or_default())
            .map_err(|e| PyRuntimeError::new_err(e.to_string()))
    })
}

/// Install a package
#[pyfunction]
fn install_package(name: &str) -> PyResult<bool> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

    let pkg_manager = packages::PackageManager::new();
    let snap_config = snapshots::SnapshotConfig::default();
    let snap_manager = snapshots::SnapshotManager::new(snap_config);

    rt.block_on(async {
        // Create snapshot
        snap_manager.create(
            &format!("pre-install-{}", name),
            snapshots::SnapshotType::PreInstall,
            Some(format!("Before installing {}", name))
        ).await.map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

        // Install package
        pkg_manager
            .install(name, None)
            .await
            .map(|_| true)
            .map_err(|e| PyRuntimeError::new_err(e.to_string()))
    })
}

/// Remove a package
#[pyfunction]
fn remove_package(name: &str) -> PyResult<bool> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| PyRuntimeError::new_err(e.to_string()))?;

    let manager = packages::PackageManager::new();

    rt.block_on(async {
        manager
            .remove(name)
            .await
            .map(|_| true)
            .map_err(|e| PyRuntimeError::new_err(e.to_string()))
    })
}

/// Python module definition
#[pymodule]
fn koompi_core(m: &Bound<'_, PyModule>) -> PyResult<()> {
    // Snapshots
    m.add_function(wrap_pyfunction!(create_snapshot, m)?)?;
    m.add_function(wrap_pyfunction!(list_snapshots, m)?)?;
    m.add_function(wrap_pyfunction!(rollback, m)?)?;
    m.add_function(wrap_pyfunction!(delete_snapshot, m)?)?;

    // Packages
    m.add_function(wrap_pyfunction!(search_packages, m)?)?;
    m.add_function(wrap_pyfunction!(install_package, m)?)?;
    m.add_function(wrap_pyfunction!(remove_package, m)?)?;

    Ok(())
}
