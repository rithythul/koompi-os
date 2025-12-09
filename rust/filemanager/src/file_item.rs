//! File item representation

use chrono::{DateTime, Local};
use std::path::PathBuf;

/// Represents a file or directory entry
#[derive(Debug, Clone)]
pub struct FileItem {
    pub name: String,
    pub path: PathBuf,
    pub is_dir: bool,
    pub is_hidden: bool,
    pub size: u64,
    pub modified: Option<DateTime<Local>>,
    pub mime_type: String,
}

impl FileItem {
    /// Create a FileItem from a directory entry
    pub fn from_path(path: PathBuf) -> Option<Self> {
        let metadata = path.metadata().ok()?;
        let name = path.file_name()?.to_string_lossy().to_string();
        let is_hidden = name.starts_with('.');
        
        let modified = metadata.modified().ok().map(|t| {
            DateTime::<Local>::from(t)
        });

        let mime_type = if metadata.is_dir() {
            "inode/directory".to_string()
        } else {
            mime_guess::from_path(&path)
                .first()
                .map(|m| m.to_string())
                .unwrap_or_else(|| "application/octet-stream".to_string())
        };

        Some(Self {
            name,
            path,
            is_dir: metadata.is_dir(),
            is_hidden,
            size: metadata.len(),
            modified,
            mime_type,
        })
    }

    /// Get human-readable size
    pub fn size_string(&self) -> String {
        if self.is_dir {
            "—".to_string()
        } else {
            humansize::format_size(self.size, humansize::BINARY)
        }
    }

    /// Get formatted modification date
    pub fn date_string(&self) -> String {
        self.modified
            .map(|d| d.format("%Y-%m-%d %H:%M").to_string())
            .unwrap_or_else(|| "—".to_string())
    }

    /// Get icon character based on file type
    pub fn icon(&self) -> &'static str {
        if self.is_dir {
            "📁"
        } else {
            match self.mime_type.split('/').next() {
                Some("image") => "🖼️",
                Some("video") => "🎬",
                Some("audio") => "🎵",
                Some("text") => "📄",
                Some("application") => {
                    if self.mime_type.contains("pdf") {
                        "📕"
                    } else if self.mime_type.contains("zip") || self.mime_type.contains("archive") {
                        "📦"
                    } else if self.mime_type.contains("executable") {
                        "⚙️"
                    } else {
                        "📄"
                    }
                }
                _ => "📄",
            }
        }
    }
}

impl PartialEq for FileItem {
    fn eq(&self, other: &Self) -> bool {
        self.path == other.path
    }
}

impl Eq for FileItem {}

impl PartialOrd for FileItem {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for FileItem {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        // Directories first, then by name
        match (self.is_dir, other.is_dir) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => self.name.to_lowercase().cmp(&other.name.to_lowercase()),
        }
    }
}
