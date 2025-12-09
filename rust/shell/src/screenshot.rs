//! KOOMPI Shell Screenshot Utility
//!
//! Provides screenshot capture with region selection and various output options.

use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

/// Screenshot capture mode
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum CaptureMode {
    FullScreen,
    ActiveWindow,
    Region,
}

/// Screenshot result
#[derive(Debug, Clone)]
pub struct Screenshot {
    pub data: Vec<u8>,
    pub width: u32,
    pub height: u32,
    pub path: Option<PathBuf>,
    pub timestamp: u64,
}

/// Region selection state
#[derive(Debug, Clone, Default)]
pub struct RegionSelection {
    pub active: bool,
    pub start: Option<(i32, i32)>,
    pub end: Option<(i32, i32)>,
}

impl RegionSelection {
    pub fn start_selection(&mut self, x: i32, y: i32) {
        self.active = true;
        self.start = Some((x, y));
        self.end = None;
    }

    pub fn update(&mut self, x: i32, y: i32) {
        if self.active {
            self.end = Some((x, y));
        }
    }

    pub fn finish(&mut self) -> Option<(i32, i32, u32, u32)> {
        if let (Some((x1, y1)), Some((x2, y2))) = (self.start, self.end) {
            self.active = false;
            let (left, right) = if x1 < x2 { (x1, x2) } else { (x2, x1) };
            let (top, bottom) = if y1 < y2 { (y1, y2) } else { (y2, y1) };
            let width = (right - left) as u32;
            let height = (bottom - top) as u32;
            
            if width > 0 && height > 0 {
                return Some((left, top, width, height));
            }
        }
        None
    }

    pub fn cancel(&mut self) {
        self.active = false;
        self.start = None;
        self.end = None;
    }

    pub fn get_rect(&self) -> Option<(i32, i32, i32, i32)> {
        if let (Some((x1, y1)), Some((x2, y2))) = (self.start, self.end) {
            let (left, right) = if x1 < x2 { (x1, x2) } else { (x2, x1) };
            let (top, bottom) = if y1 < y2 { (y1, y2) } else { (y2, y1) };
            Some((left, top, right, bottom))
        } else {
            None
        }
    }
}

/// Screenshot manager
pub struct ScreenshotManager {
    pub save_directory: PathBuf,
    pub filename_format: String,
    pub region_selection: RegionSelection,
    pub copy_to_clipboard: bool,
    pub save_to_file: bool,
    pub show_notification: bool,
}

impl ScreenshotManager {
    pub fn new() -> Self {
        // Default to Pictures/Screenshots
        let save_directory = dirs::picture_dir()
            .unwrap_or_else(|| PathBuf::from("/tmp"))
            .join("Screenshots");
        
        Self {
            save_directory,
            filename_format: "screenshot_%Y%m%d_%H%M%S.png".to_string(),
            region_selection: RegionSelection::default(),
            copy_to_clipboard: true,
            save_to_file: true,
            show_notification: true,
        }
    }

    /// Generate filename with timestamp
    pub fn generate_filename(&self) -> PathBuf {
        let now = chrono::Local::now();
        let filename = now.format(&self.filename_format).to_string();
        self.save_directory.join(filename)
    }

    /// Capture the screen (called from renderer)
    pub fn capture_framebuffer(&self, data: &[u8], width: u32, height: u32) -> Screenshot {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        Screenshot {
            data: data.to_vec(),
            width,
            height,
            path: None,
            timestamp,
        }
    }

    /// Capture a region from full screenshot
    pub fn capture_region(
        &self,
        full_data: &[u8],
        full_width: u32,
        full_height: u32,
        x: i32,
        y: i32,
        width: u32,
        height: u32,
    ) -> Screenshot {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        // Extract region from full image (assuming RGBA)
        let mut region_data = Vec::with_capacity((width * height * 4) as usize);
        
        for row in 0..height {
            let src_y = (y as u32 + row).min(full_height - 1);
            for col in 0..width {
                let src_x = (x as u32 + col).min(full_width - 1);
                let src_idx = ((src_y * full_width + src_x) * 4) as usize;
                
                if src_idx + 3 < full_data.len() {
                    region_data.push(full_data[src_idx]);
                    region_data.push(full_data[src_idx + 1]);
                    region_data.push(full_data[src_idx + 2]);
                    region_data.push(full_data[src_idx + 3]);
                }
            }
        }

        Screenshot {
            data: region_data,
            width,
            height,
            path: None,
            timestamp,
        }
    }

    /// Save screenshot to file
    pub fn save(&self, screenshot: &mut Screenshot) -> Result<PathBuf, String> {
        // Ensure directory exists
        std::fs::create_dir_all(&self.save_directory)
            .map_err(|e| format!("Failed to create directory: {}", e))?;

        let path = self.generate_filename();
        
        // Convert RGBA to PNG using image crate would be ideal
        // For now, save as raw PPM (simple format)
        let ppm_path = path.with_extension("ppm");
        
        let mut file_content = format!(
            "P6\n{} {}\n255\n",
            screenshot.width, screenshot.height
        ).into_bytes();

        // Convert RGBA to RGB
        for chunk in screenshot.data.chunks(4) {
            if chunk.len() >= 3 {
                file_content.push(chunk[0]); // R
                file_content.push(chunk[1]); // G
                file_content.push(chunk[2]); // B
            }
        }

        std::fs::write(&ppm_path, file_content)
            .map_err(|e| format!("Failed to save screenshot: {}", e))?;

        screenshot.path = Some(ppm_path.clone());
        Ok(ppm_path)
    }

    /// Copy screenshot to clipboard using wl-copy
    pub fn copy_to_clipboard(&self, screenshot: &Screenshot) -> Result<(), String> {
        use std::process::{Command, Stdio};
        use std::io::Write;

        // Create PNG data (simplified - just PPM for now)
        let mut ppm_data = format!(
            "P6\n{} {}\n255\n",
            screenshot.width, screenshot.height
        ).into_bytes();

        for chunk in screenshot.data.chunks(4) {
            if chunk.len() >= 3 {
                ppm_data.push(chunk[0]);
                ppm_data.push(chunk[1]);
                ppm_data.push(chunk[2]);
            }
        }

        // Try wl-copy
        let mut child = Command::new("wl-copy")
            .arg("--type")
            .arg("image/x-portable-pixmap")
            .stdin(Stdio::piped())
            .spawn()
            .map_err(|e| format!("Failed to run wl-copy: {}", e))?;

        if let Some(mut stdin) = child.stdin.take() {
            stdin.write_all(&ppm_data)
                .map_err(|e| format!("Failed to write to wl-copy: {}", e))?;
        }

        child.wait()
            .map_err(|e| format!("wl-copy failed: {}", e))?;

        Ok(())
    }
}

impl Default for ScreenshotManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Key bindings for screenshot
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ScreenshotAction {
    FullScreen,      // PrtSc
    ActiveWindow,    // Alt+PrtSc
    SelectRegion,    // Shift+PrtSc
}

impl ScreenshotAction {
    pub fn from_modifiers(shift: bool, alt: bool) -> Self {
        match (shift, alt) {
            (true, _) => Self::SelectRegion,
            (_, true) => Self::ActiveWindow,
            _ => Self::FullScreen,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_region_selection() {
        let mut region = RegionSelection::default();
        region.start_selection(10, 20);
        region.update(100, 150);
        
        let rect = region.finish();
        assert!(rect.is_some());
        
        let (x, y, w, h) = rect.unwrap();
        assert_eq!(x, 10);
        assert_eq!(y, 20);
        assert_eq!(w, 90);
        assert_eq!(h, 130);
    }

    #[test]
    fn test_region_cancel() {
        let mut region = RegionSelection::default();
        region.start_selection(0, 0);
        region.cancel();
        
        assert!(!region.active);
        assert!(region.start.is_none());
    }
}
