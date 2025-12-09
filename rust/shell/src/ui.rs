//! KOOMPI Shell UI - Desktop interface rendered with tiny_skia + fontdue
//!
//! Provides: Panel (bottom), Launcher (popup), Window decorations, Text rendering

use chrono::Local;
use fontdue::{Font, FontSettings};
use std::sync::OnceLock;

static FONT: OnceLock<Font> = OnceLock::new();

fn get_font() -> &'static Font {
    FONT.get_or_init(|| {
        // Try multiple system font paths
        let font_paths = [
            "/usr/share/fonts/TTF/Roboto-Regular.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
            "/usr/share/fonts/noto/NotoSans-Regular.ttf",
        ];
        
        for path in font_paths {
            if let Ok(data) = std::fs::read(path) {
                if let Ok(font) = Font::from_bytes(data, FontSettings::default()) {
                    return font;
                }
            }
        }
        
        panic!("No system fonts found! Install dejavu-fonts or similar.");
    })
}

/// System tray icon representation
#[derive(Clone, Debug)]
pub struct TrayIcon {
    pub id: String,
    pub name: String,
    pub icon_type: TrayIconType,
    pub tooltip: String,
}

#[derive(Clone, Debug)]
pub enum TrayIconType {
    Network(NetworkStatus),
    Volume(u8),       // 0-100
    Battery(u8, bool), // level 0-100, charging
    Notification(u32), // count of unread
    Generic,
}

#[derive(Clone, Debug)]
pub enum NetworkStatus {
    Disconnected,
    Wifi(u8),     // signal strength 0-100
    Ethernet,
    Airplane,
}

/// Shell UI state
pub struct ShellUI {
    pub now: chrono::DateTime<Local>,
    pub show_launcher: bool,
    pub pointer_pos: (f64, f64),
    pub screen_size: (u32, u32),
    pub tray_icons: Vec<TrayIcon>,
    pub show_tray_popup: Option<String>, // id of expanded tray icon
}

/// Messages for UI updates
#[derive(Debug, Clone)]
pub enum Message {
    Tick(chrono::DateTime<Local>),
    ToggleLauncher,
    LaunchApp(String),
    PointerMove(f64, f64),
    Click(f64, f64),
    Resize(u32, u32),
    TrayIconClick(String),
    UpdateTrayIcon(TrayIcon),
    CloseTrayPopup,
}

impl ShellUI {
    pub fn new() -> Self {
        // Initialize with default system tray icons
        let tray_icons = vec![
            TrayIcon {
                id: "network".to_string(),
                name: "Network".to_string(),
                icon_type: TrayIconType::Network(NetworkStatus::Wifi(75)),
                tooltip: "Connected to WiFi".to_string(),
            },
            TrayIcon {
                id: "volume".to_string(),
                name: "Volume".to_string(),
                icon_type: TrayIconType::Volume(70),
                tooltip: "Volume: 70%".to_string(),
            },
            TrayIcon {
                id: "battery".to_string(),
                name: "Battery".to_string(),
                icon_type: TrayIconType::Battery(85, false),
                tooltip: "Battery: 85%".to_string(),
            },
            TrayIcon {
                id: "notifications".to_string(),
                name: "Notifications".to_string(),
                icon_type: TrayIconType::Notification(3),
                tooltip: "3 notifications".to_string(),
            },
        ];
        
        Self {
            now: Local::now(),
            show_launcher: false,
            pointer_pos: (0.0, 0.0),
            screen_size: (1280, 800),
            tray_icons,
            show_tray_popup: None,
        }
    }

    pub fn update(&mut self, message: Message) -> Option<String> {
        match message {
            Message::Tick(now) => {
                self.now = now;
                None
            }
            Message::ToggleLauncher => {
                self.show_launcher = !self.show_launcher;
                self.show_tray_popup = None;
                None
            }
            Message::PointerMove(x, y) => {
                self.pointer_pos = (x, y);
                None
            }
            Message::Click(x, y) => {
                self.handle_click(x, y)
            }
            Message::LaunchApp(app) => {
                self.show_launcher = false;
                Some(app)
            }
            Message::Resize(w, h) => {
                self.screen_size = (w, h);
                None
            }
            Message::TrayIconClick(id) => {
                if self.show_tray_popup.as_ref() == Some(&id) {
                    self.show_tray_popup = None;
                } else {
                    self.show_tray_popup = Some(id);
                    self.show_launcher = false;
                }
                None
            }
            Message::UpdateTrayIcon(icon) => {
                if let Some(existing) = self.tray_icons.iter_mut().find(|i| i.id == icon.id) {
                    *existing = icon;
                } else {
                    self.tray_icons.push(icon);
                }
                None
            }
            Message::CloseTrayPopup => {
                self.show_tray_popup = None;
                None
            }
        }
    }

    fn handle_click(&mut self, x: f64, y: f64) -> Option<String> {
        let panel_height = 40.0;
        let panel_y = 0.0; // Top of screen, macOS style
        
        // Check KOOMPI button (left side of panel)
        if y <= panel_height && x >= 10.0 && x <= 90.0 {
            self.show_launcher = !self.show_launcher;
            self.show_tray_popup = None;
            return None;
        }
        
        // Check system tray icons (right side of panel, before clock)
        let tray_start_x = self.screen_size.0 as f64 - 180.0;
        let icon_width = 28.0;
        if y <= panel_height {
            for (i, icon) in self.tray_icons.iter().enumerate() {
                let icon_x = tray_start_x + (i as f64 * icon_width);
                if x >= icon_x && x <= icon_x + icon_width {
                    let id = icon.id.clone();
                    if self.show_tray_popup.as_ref() == Some(&id) {
                        self.show_tray_popup = None;
                    } else {
                        self.show_tray_popup = Some(id);
                        self.show_launcher = false;
                    }
                    return None;
                }
            }
        }

        // Check launcher buttons if open
        if self.show_launcher {
            let launcher_width = 300.0;
            let launcher_x = (self.screen_size.0 as f64 - launcher_width) / 2.0;
            let launcher_y = panel_height + 10.0; // Below the top panel
            let launcher_height = 280.0;
            let apps = ["Terminal", "Browser", "Files", "Settings"];
            
            for (i, app) in apps.iter().enumerate() {
                let btn_y = launcher_y + 50.0 + (i as f64 * 55.0);
                if x >= launcher_x + 20.0 && x <= launcher_x + launcher_width - 20.0 &&
                   y >= btn_y && y <= btn_y + 45.0 {
                    self.show_launcher = false;
                    return Some(app.to_string());
                }
            }
            
            // Click outside launcher closes it
            if x < launcher_x || x > launcher_x + launcher_width ||
               y < launcher_y || y > launcher_y + launcher_height {
                self.show_launcher = false;
            }
        }
        
        // Close tray popup if clicking elsewhere
        if self.show_tray_popup.is_some() {
            self.show_tray_popup = None;
        }
        
        None
    }
}

impl Default for ShellUI {
    fn default() -> Self {
        Self::new()
    }
}

/// Draw text at position
fn draw_text(pixmap: &mut tiny_skia::Pixmap, text: &str, x: f32, y: f32, size: f32, color: [u8; 4]) {
    let font = get_font();
    let mut cursor_x = x;
    
    for ch in text.chars() {
        let (metrics, bitmap) = font.rasterize(ch, size);
        
        if bitmap.is_empty() {
            cursor_x += metrics.advance_width;
            continue;
        }
        
        let glyph_x = cursor_x + metrics.xmin as f32;
        let glyph_y = y - metrics.ymin as f32 - metrics.height as f32;
        
        for gy in 0..metrics.height {
            for gx in 0..metrics.width {
                let alpha = bitmap[gy * metrics.width + gx];
                if alpha > 0 {
                    let px = (glyph_x + gx as f32) as u32;
                    let py = (glyph_y + gy as f32) as u32;
                    
                    if px < pixmap.width() && py < pixmap.height() {
                        let idx = (py * pixmap.width() + px) as usize * 4;
                        if let Some(data) = pixmap.data_mut().get_mut(idx..idx+4) {
                            let a = alpha as u32;
                            data[0] = ((data[0] as u32 * (255 - a) + color[0] as u32 * a) / 255) as u8;
                            data[1] = ((data[1] as u32 * (255 - a) + color[1] as u32 * a) / 255) as u8;
                            data[2] = ((data[2] as u32 * (255 - a) + color[2] as u32 * a) / 255) as u8;
                            data[3] = 255;
                        }
                    }
                }
            }
        }
        
        cursor_x += metrics.advance_width;
    }
}

/// Render window decorations (title bar, borders, buttons)
pub fn render_window_decorations(
    pixmap: &mut tiny_skia::Pixmap,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    title: &str,
    focused: bool,
) {
    let title_bar_height = 30;
    let border_width = 1;
    
    let mut paint = tiny_skia::Paint::default();
    
    // Title bar background
    if focused {
        paint.set_color_rgba8(60, 60, 70, 255);
    } else {
        paint.set_color_rgba8(45, 45, 50, 255);
    }
    
    let title_rect = tiny_skia::Rect::from_xywh(
        (x - border_width) as f32,
        (y - title_bar_height) as f32,
        (width + border_width * 2) as f32,
        title_bar_height as f32,
    );
    if let Some(rect) = title_rect {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Window title text
    let title_color = if focused { [255, 255, 255, 255] } else { [180, 180, 180, 255] };
    let truncated_title: String = title.chars().take(30).collect();
    draw_text(pixmap, &truncated_title, (x + 10) as f32, (y - 8) as f32, 14.0, title_color);
    
    // Window control buttons (right side of title bar)
    let btn_y = y - title_bar_height + 5;
    let btn_size = 20;
    
    // Close button (red)
    paint.set_color_rgba8(200, 70, 70, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(
        (x + width - 25) as f32,
        btn_y as f32,
        btn_size as f32,
        btn_size as f32,
    ) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    draw_text(pixmap, "×", (x + width - 21) as f32, (btn_y + 16) as f32, 16.0, [255, 255, 255, 255]);
    
    // Maximize button (green)
    paint.set_color_rgba8(70, 150, 70, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(
        (x + width - 50) as f32,
        btn_y as f32,
        btn_size as f32,
        btn_size as f32,
    ) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    draw_text(pixmap, "□", (x + width - 46) as f32, (btn_y + 15) as f32, 14.0, [255, 255, 255, 255]);
    
    // Minimize button (yellow)
    paint.set_color_rgba8(180, 150, 50, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(
        (x + width - 75) as f32,
        btn_y as f32,
        btn_size as f32,
        btn_size as f32,
    ) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    draw_text(pixmap, "−", (x + width - 71) as f32, (btn_y + 15) as f32, 14.0, [255, 255, 255, 255]);
    
    // Window border
    if focused {
        paint.set_color_rgba8(80, 140, 200, 255);
    } else {
        paint.set_color_rgba8(60, 60, 65, 255);
    }
    
    // Left border
    if let Some(rect) = tiny_skia::Rect::from_xywh(
        (x - border_width) as f32,
        y as f32,
        border_width as f32,
        height as f32,
    ) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Right border
    if let Some(rect) = tiny_skia::Rect::from_xywh(
        (x + width) as f32,
        y as f32,
        border_width as f32,
        height as f32,
    ) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Bottom border
    if let Some(rect) = tiny_skia::Rect::from_xywh(
        (x - border_width) as f32,
        (y + height) as f32,
        (width + border_width * 2) as f32,
        border_width as f32,
    ) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
}

/// Render the panel to a pixmap
pub fn render_panel(
    pixmap: &mut tiny_skia::Pixmap,
    ui: &ShellUI,
    width: u32,
    _height: u32,
) {
    let panel_height = 40.0;
    let panel_y = 0.0; // Top of screen, macOS style
    
    // Panel background
    let mut paint = tiny_skia::Paint::default();
    paint.set_color_rgba8(25, 25, 30, 245);
    
    if let Some(rect) = tiny_skia::Rect::from_xywh(0.0, panel_y, width as f32, panel_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // KOOMPI button
    paint.set_color_rgba8(50, 120, 200, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(10.0, panel_y + 8.0, 80.0, 24.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    draw_text(pixmap, "KOOMPI", 18.0, panel_y + 26.0, 14.0, [255, 255, 255, 255]);
    
    // System tray icons (right side, before clock)
    let tray_start_x = width as f32 - 180.0;
    render_system_tray(pixmap, ui, tray_start_x, panel_y);
    
    // Clock
    let time_str = ui.now.format("%H:%M:%S").to_string();
    draw_text(pixmap, &time_str, width as f32 - 75.0, panel_y + 26.0, 14.0, [200, 200, 200, 255]);
    
    // Date
    let date_str = ui.now.format("%b %d").to_string();
    draw_text(pixmap, &date_str, width as f32 - 150.0, panel_y + 26.0, 12.0, [150, 150, 150, 255]);
    
    // Launcher overlay
    if ui.show_launcher {
        render_launcher(pixmap, width);
    }
    
    // Tray popup overlay
    if let Some(ref icon_id) = ui.show_tray_popup {
        if let Some(icon) = ui.tray_icons.iter().find(|i| &i.id == icon_id) {
            let idx = ui.tray_icons.iter().position(|i| &i.id == icon_id).unwrap_or(0);
            let popup_x = tray_start_x + (idx as f32 * 28.0) - 50.0;
            render_tray_popup(pixmap, icon, popup_x, panel_y + panel_height + 5.0); // Below the panel
        }
    }
}

/// Render the app launcher popup
fn render_launcher(pixmap: &mut tiny_skia::Pixmap, width: u32) {
    let launcher_width = 300.0;
    let launcher_height = 280.0;
    let launcher_x = (width as f32 - launcher_width) / 2.0;
    let launcher_y = 50.0; // Below the top panel
    
    let mut paint = tiny_skia::Paint::default();
    paint.set_color_rgba8(35, 35, 40, 250);
    
    if let Some(rect) = tiny_skia::Rect::from_xywh(launcher_x, launcher_y, launcher_width, launcher_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Title
    draw_text(pixmap, "Applications", launcher_x + 90.0, launcher_y + 30.0, 16.0, [255, 255, 255, 255]);
    
    // App buttons
    let apps = [
        ("Terminal", [80, 80, 80]),
        ("Browser", [60, 100, 160]),
        ("Files", [100, 140, 80]),
        ("Settings", [120, 100, 80]),
    ];
    
    for (i, (app, color)) in apps.iter().enumerate() {
        let btn_y = launcher_y + 50.0 + (i as f32 * 55.0);
        
        paint.set_color_rgba8(color[0], color[1], color[2], 255);
        if let Some(rect) = tiny_skia::Rect::from_xywh(launcher_x + 20.0, btn_y, launcher_width - 40.0, 45.0) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        
        draw_text(pixmap, app, launcher_x + 30.0, btn_y + 30.0, 16.0, [255, 255, 255, 255]);
    }
}

/// Render system tray icons in the panel
fn render_system_tray(pixmap: &mut tiny_skia::Pixmap, ui: &ShellUI, start_x: f32, panel_y: f32) {
    let mut paint = tiny_skia::Paint::default();
    let icon_size = 24.0;
    let icon_spacing = 28.0;
    
    for (i, icon) in ui.tray_icons.iter().enumerate() {
        let x = start_x + (i as f32 * icon_spacing);
        let y = panel_y + 8.0;
        
        // Highlight if this icon's popup is open
        if ui.show_tray_popup.as_ref() == Some(&icon.id) {
            paint.set_color_rgba8(60, 60, 70, 255);
            if let Some(rect) = tiny_skia::Rect::from_xywh(x - 2.0, y - 2.0, icon_size + 4.0, icon_size + 4.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
        }
        
        // Draw icon based on type
        match &icon.icon_type {
            TrayIconType::Network(status) => {
                draw_network_icon(pixmap, x, y, icon_size, status);
            }
            TrayIconType::Volume(level) => {
                draw_volume_icon(pixmap, x, y, icon_size, *level);
            }
            TrayIconType::Battery(level, charging) => {
                draw_battery_icon(pixmap, x, y, icon_size, *level, *charging);
            }
            TrayIconType::Notification(count) => {
                draw_notification_icon(pixmap, x, y, icon_size, *count);
            }
            TrayIconType::Generic => {
                paint.set_color_rgba8(120, 120, 130, 255);
                if let Some(rect) = tiny_skia::Rect::from_xywh(x + 4.0, y + 4.0, icon_size - 8.0, icon_size - 8.0) {
                    pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
                }
            }
        }
    }
}

fn draw_network_icon(pixmap: &mut tiny_skia::Pixmap, x: f32, y: f32, size: f32, status: &NetworkStatus) {
    let mut paint = tiny_skia::Paint::default();
    
    match status {
        NetworkStatus::Wifi(strength) => {
            // Draw WiFi arcs (simplified as bars)
            let color = if *strength > 60 {
                [100, 180, 100, 255]
            } else if *strength > 30 {
                [180, 180, 80, 255]
            } else {
                [180, 100, 80, 255]
            };
            paint.set_color_rgba8(color[0], color[1], color[2], 255);
            
            // Draw signal bars
            let bars = (*strength / 25).min(4) as i32;
            for i in 0..4 {
                let bar_height = 4.0 + (i as f32 * 4.0);
                let bar_x = x + 3.0 + (i as f32 * 5.0);
                let bar_y = y + size - bar_height - 2.0;
                
                if i < bars {
                    paint.set_color_rgba8(color[0], color[1], color[2], 255);
                } else {
                    paint.set_color_rgba8(60, 60, 65, 255);
                }
                
                if let Some(rect) = tiny_skia::Rect::from_xywh(bar_x, bar_y, 3.0, bar_height) {
                    pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
                }
            }
        }
        NetworkStatus::Ethernet => {
            paint.set_color_rgba8(100, 180, 100, 255);
            // Draw ethernet symbol (simplified)
            if let Some(rect) = tiny_skia::Rect::from_xywh(x + 6.0, y + 4.0, 12.0, 16.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
            paint.set_color_rgba8(25, 25, 30, 255);
            if let Some(rect) = tiny_skia::Rect::from_xywh(x + 8.0, y + 6.0, 8.0, 12.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
        }
        NetworkStatus::Disconnected => {
            paint.set_color_rgba8(150, 80, 80, 255);
            draw_text(pixmap, "×", x + 5.0, y + 18.0, 18.0, [150, 80, 80, 255]);
        }
        NetworkStatus::Airplane => {
            paint.set_color_rgba8(180, 140, 80, 255);
            draw_text(pixmap, "✈", x + 3.0, y + 18.0, 16.0, [180, 140, 80, 255]);
        }
    }
}

fn draw_volume_icon(pixmap: &mut tiny_skia::Pixmap, x: f32, y: f32, size: f32, level: u8) {
    let mut paint = tiny_skia::Paint::default();
    
    let color = if level > 0 {
        [150, 150, 160, 255]
    } else {
        [100, 80, 80, 255]
    };
    
    paint.set_color_rgba8(color[0], color[1], color[2], 255);
    
    // Speaker body
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 3.0, y + 8.0, 6.0, 8.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    // Speaker cone
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 9.0, y + 5.0, 4.0, 14.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Volume waves based on level
    if level > 30 {
        if let Some(rect) = tiny_skia::Rect::from_xywh(x + 15.0, y + 8.0, 2.0, 8.0) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
    }
    if level > 60 {
        if let Some(rect) = tiny_skia::Rect::from_xywh(x + 19.0, y + 5.0, 2.0, 14.0) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
    }
    
    // Mute X
    if level == 0 {
        draw_text(pixmap, "×", x + 14.0, y + 18.0, 14.0, [150, 80, 80, 255]);
    }
}

fn draw_battery_icon(pixmap: &mut tiny_skia::Pixmap, x: f32, y: f32, _size: f32, level: u8, charging: bool) {
    let mut paint = tiny_skia::Paint::default();
    
    let color = if level > 20 {
        [100, 180, 100, 255]
    } else {
        [200, 80, 80, 255]
    };
    
    // Battery outline
    paint.set_color_rgba8(120, 120, 130, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 2.0, y + 6.0, 18.0, 12.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    // Battery tip
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 20.0, y + 9.0, 2.0, 6.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Battery inner
    paint.set_color_rgba8(30, 30, 35, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 4.0, y + 8.0, 14.0, 8.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Battery level fill
    paint.set_color_rgba8(color[0], color[1], color[2], 255);
    let fill_width = (14.0 * level as f32 / 100.0).max(0.0);
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 4.0, y + 8.0, fill_width, 8.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Charging indicator
    if charging {
        draw_text(pixmap, "⚡", x + 6.0, y + 16.0, 10.0, [255, 220, 100, 255]);
    }
}

fn draw_notification_icon(pixmap: &mut tiny_skia::Pixmap, x: f32, y: f32, _size: f32, count: u32) {
    let mut paint = tiny_skia::Paint::default();
    
    // Bell shape (simplified)
    paint.set_color_rgba8(150, 150, 160, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 6.0, y + 4.0, 12.0, 14.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    // Bell bottom
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 4.0, y + 16.0, 16.0, 3.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    // Bell ringer
    if let Some(rect) = tiny_skia::Rect::from_xywh(x + 10.0, y + 19.0, 4.0, 3.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Notification badge
    if count > 0 {
        paint.set_color_rgba8(200, 70, 70, 255);
        if let Some(rect) = tiny_skia::Rect::from_xywh(x + 14.0, y + 2.0, 10.0, 10.0) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        let count_str = if count > 9 { "9+".to_string() } else { count.to_string() };
        draw_text(pixmap, &count_str, x + 16.0, y + 10.0, 8.0, [255, 255, 255, 255]);
    }
}

/// Render tray icon popup with details
fn render_tray_popup(pixmap: &mut tiny_skia::Pixmap, icon: &TrayIcon, x: f32, y: f32) {
    let mut paint = tiny_skia::Paint::default();
    let popup_width = 150.0;
    let popup_height = 100.0;
    
    // Popup background
    paint.set_color_rgba8(40, 40, 45, 250);
    if let Some(rect) = tiny_skia::Rect::from_xywh(x, y, popup_width, popup_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Border
    paint.set_color_rgba8(70, 70, 80, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(x, y, popup_width, 2.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Title
    draw_text(pixmap, &icon.name, x + 10.0, y + 25.0, 14.0, [255, 255, 255, 255]);
    
    // Status based on type
    match &icon.icon_type {
        TrayIconType::Network(status) => {
            let status_text = match status {
                NetworkStatus::Wifi(s) => format!("WiFi: {}%", s),
                NetworkStatus::Ethernet => "Ethernet Connected".to_string(),
                NetworkStatus::Disconnected => "Disconnected".to_string(),
                NetworkStatus::Airplane => "Airplane Mode".to_string(),
            };
            draw_text(pixmap, &status_text, x + 10.0, y + 50.0, 12.0, [180, 180, 180, 255]);
            draw_text(pixmap, "Click to configure", x + 10.0, y + 75.0, 10.0, [120, 120, 130, 255]);
        }
        TrayIconType::Volume(level) => {
            let status_text = if *level == 0 {
                "Muted".to_string()
            } else {
                format!("Volume: {}%", level)
            };
            draw_text(pixmap, &status_text, x + 10.0, y + 50.0, 12.0, [180, 180, 180, 255]);
            
            // Volume bar
            paint.set_color_rgba8(60, 60, 65, 255);
            if let Some(rect) = tiny_skia::Rect::from_xywh(x + 10.0, y + 65.0, 130.0, 8.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
            paint.set_color_rgba8(80, 140, 200, 255);
            let bar_width = 130.0 * *level as f32 / 100.0;
            if let Some(rect) = tiny_skia::Rect::from_xywh(x + 10.0, y + 65.0, bar_width, 8.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
        }
        TrayIconType::Battery(level, charging) => {
            let status_text = if *charging {
                format!("Charging: {}%", level)
            } else {
                format!("Battery: {}%", level)
            };
            draw_text(pixmap, &status_text, x + 10.0, y + 50.0, 12.0, [180, 180, 180, 255]);
            
            // Battery bar
            paint.set_color_rgba8(60, 60, 65, 255);
            if let Some(rect) = tiny_skia::Rect::from_xywh(x + 10.0, y + 65.0, 130.0, 8.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
            let bar_color = if *level > 20 { [100, 180, 100, 255] } else { [200, 80, 80, 255] };
            paint.set_color_rgba8(bar_color[0], bar_color[1], bar_color[2], 255);
            let bar_width = 130.0 * *level as f32 / 100.0;
            if let Some(rect) = tiny_skia::Rect::from_xywh(x + 10.0, y + 65.0, bar_width, 8.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
        }
        TrayIconType::Notification(count) => {
            let status_text = if *count == 0 {
                "No notifications".to_string()
            } else if *count == 1 {
                "1 notification".to_string()
            } else {
                format!("{} notifications", count)
            };
            draw_text(pixmap, &status_text, x + 10.0, y + 50.0, 12.0, [180, 180, 180, 255]);
            draw_text(pixmap, "Click to view all", x + 10.0, y + 75.0, 10.0, [120, 120, 130, 255]);
        }
        TrayIconType::Generic => {
            draw_text(pixmap, &icon.tooltip, x + 10.0, y + 50.0, 12.0, [180, 180, 180, 255]);
        }
    }
}

// ============================================================================
// Phase 5: Lock Screen, Notifications, OSD Rendering
// ============================================================================

use crate::lock_screen::{LockScreen, LockState, PowerMenu, SessionAction};
use crate::notifications::{NotificationDaemon, Notification, Urgency, OSD, OSDKind};

/// Render lock screen overlay
pub fn render_lock_screen(
    pixmap: &mut tiny_skia::Pixmap,
    lock_screen: &LockScreen,
    width: u32,
    height: u32,
) {
    let mut paint = tiny_skia::Paint::default();
    
    // Semi-transparent dark overlay
    paint.set_color_rgba8(15, 15, 20, 240);
    if let Some(rect) = tiny_skia::Rect::from_xywh(0.0, 0.0, width as f32, height as f32) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    let center_x = width as f32 / 2.0;
    let center_y = height as f32 / 2.0;
    
    // Lock card background
    let card_width = 350.0;
    let card_height = 280.0;
    let card_x = center_x - card_width / 2.0;
    let card_y = center_y - card_height / 2.0;
    
    paint.set_color_rgba8(30, 30, 35, 250);
    if let Some(rect) = tiny_skia::Rect::from_xywh(card_x, card_y, card_width, card_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Card border
    paint.set_color_rgba8(60, 60, 70, 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(card_x, card_y, card_width, 3.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // User avatar placeholder (circle)
    let avatar_size = 80.0;
    let avatar_x = center_x - avatar_size / 2.0;
    let avatar_y = card_y + 30.0;
    
    paint.set_color_rgba8(60, 80, 120, 255);
    // Draw circle as rounded rect approximation
    if let Some(rect) = tiny_skia::Rect::from_xywh(avatar_x, avatar_y, avatar_size, avatar_size) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    // User icon (simplified)
    draw_text(pixmap, "👤", avatar_x + 25.0, avatar_y + 55.0, 36.0, [200, 200, 220, 255]);
    
    // Username
    draw_text(
        pixmap,
        &lock_screen.user_name,
        center_x - (lock_screen.user_name.len() as f32 * 5.5),
        avatar_y + avatar_size + 35.0,
        18.0,
        [255, 255, 255, 255],
    );
    
    // Password input field
    let input_width = 280.0;
    let input_height = 40.0;
    let input_x = center_x - input_width / 2.0;
    let input_y = avatar_y + avatar_size + 55.0;
    
    // Input background
    let input_color = match lock_screen.state {
        LockState::AuthFailed => [80, 40, 40, 255],
        LockState::Authenticating => [40, 60, 80, 255],
        _ => [40, 40, 45, 255],
    };
    paint.set_color_rgba8(input_color[0], input_color[1], input_color[2], 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(input_x, input_y, input_width, input_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Input border
    let border_color = match lock_screen.state {
        LockState::AuthFailed => [200, 80, 80, 255],
        LockState::Authenticating => [80, 140, 200, 255],
        _ => [80, 80, 90, 255],
    };
    paint.set_color_rgba8(border_color[0], border_color[1], border_color[2], 255);
    if let Some(rect) = tiny_skia::Rect::from_xywh(input_x, input_y + input_height - 2.0, input_width, 2.0) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Password text or placeholder
    if lock_screen.password_input.is_empty() {
        draw_text(pixmap, "Enter password...", input_x + 15.0, input_y + 26.0, 14.0, [120, 120, 130, 255]);
    } else {
        let display = lock_screen.display_password();
        draw_text(pixmap, &display, input_x + 15.0, input_y + 26.0, 16.0, [255, 255, 255, 255]);
    }
    
    // Error message
    if let Some(ref error) = lock_screen.error_message {
        draw_text(
            pixmap,
            error,
            center_x - (error.len() as f32 * 3.5),
            input_y + input_height + 25.0,
            12.0,
            [220, 100, 100, 255],
        );
    }
    
    // Time display
    if let Some(locked_duration) = lock_screen.time_locked() {
        let mins = locked_duration.as_secs() / 60;
        let secs = locked_duration.as_secs() % 60;
        let time_str = format!("Locked for {:02}:{:02}", mins, secs);
        draw_text(
            pixmap,
            &time_str,
            center_x - 45.0,
            card_y + card_height - 20.0,
            11.0,
            [100, 100, 110, 255],
        );
    }
    
    // Current time at bottom
    let now = chrono::Local::now();
    let time_str = now.format("%H:%M").to_string();
    draw_text(pixmap, &time_str, center_x - 35.0, height as f32 - 60.0, 48.0, [255, 255, 255, 255]);
    
    let date_str = now.format("%A, %B %d").to_string();
    draw_text(pixmap, &date_str, center_x - (date_str.len() as f32 * 4.0), height as f32 - 25.0, 14.0, [180, 180, 180, 255]);
}

/// Render notifications (toast style, top-right)
pub fn render_notifications(
    pixmap: &mut tiny_skia::Pixmap,
    daemon: &NotificationDaemon,
    width: u32,
) {
    let mut paint = tiny_skia::Paint::default();
    
    let notif_width = 320.0;
    let notif_height = 80.0;
    let padding = 10.0;
    let start_x = width as f32 - notif_width - 20.0;
    let start_y = 50.0; // Below panel
    
    for (i, notification) in daemon.visible().enumerate() {
        let y = start_y + (i as f32 * (notif_height + padding));
        let opacity = notification.remaining_fraction();
        
        // Background with urgency color
        let bg_color = match notification.urgency {
            Urgency::Critical => [80, 30, 30, (230.0 * opacity) as u8],
            Urgency::Low => [30, 35, 40, (220.0 * opacity) as u8],
            Urgency::Normal => [35, 35, 40, (230.0 * opacity) as u8],
        };
        paint.set_color_rgba8(bg_color[0], bg_color[1], bg_color[2], bg_color[3]);
        if let Some(rect) = tiny_skia::Rect::from_xywh(start_x, y, notif_width, notif_height) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        
        // Left accent bar
        let accent_color = match notification.urgency {
            Urgency::Critical => [200, 80, 80, 255],
            Urgency::Low => [80, 120, 160, 255],
            Urgency::Normal => [80, 140, 200, 255],
        };
        paint.set_color_rgba8(accent_color[0], accent_color[1], accent_color[2], (255.0 * opacity) as u8);
        if let Some(rect) = tiny_skia::Rect::from_xywh(start_x, y, 4.0, notif_height) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        
        // App name
        let text_alpha = (255.0 * opacity) as u8;
        draw_text(
            pixmap,
            &notification.app_name,
            start_x + 15.0,
            y + 20.0,
            11.0,
            [150, 150, 160, text_alpha],
        );
        
        // Summary (title)
        let summary: String = notification.summary.chars().take(35).collect();
        draw_text(
            pixmap,
            &summary,
            start_x + 15.0,
            y + 40.0,
            14.0,
            [255, 255, 255, text_alpha],
        );
        
        // Body (truncated)
        let body: String = notification.body.chars().take(45).collect();
        draw_text(
            pixmap,
            &body,
            start_x + 15.0,
            y + 60.0,
            12.0,
            [180, 180, 180, text_alpha],
        );
        
        // Progress bar if present
        if let Some(progress) = notification.progress {
            paint.set_color_rgba8(50, 50, 55, text_alpha);
            if let Some(rect) = tiny_skia::Rect::from_xywh(start_x + 15.0, y + 68.0, notif_width - 30.0, 4.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
            paint.set_color_rgba8(80, 160, 80, text_alpha);
            let bar_width = (notif_width - 30.0) * progress as f32 / 100.0;
            if let Some(rect) = tiny_skia::Rect::from_xywh(start_x + 15.0, y + 68.0, bar_width, 4.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
        }
        
        // Close button
        draw_text(pixmap, "×", start_x + notif_width - 20.0, y + 20.0, 16.0, [150, 150, 160, text_alpha]);
    }
}

/// Render OSD (volume/brightness overlay)
pub fn render_osd(
    pixmap: &mut tiny_skia::Pixmap,
    osd: &OSD,
    width: u32,
    height: u32,
) {
    let mut paint = tiny_skia::Paint::default();
    let opacity = osd.opacity();
    
    let osd_width = 200.0;
    let osd_height = 100.0;
    let osd_x = (width as f32 - osd_width) / 2.0;
    let osd_y = height as f32 - 150.0;
    
    // Background
    paint.set_color_rgba8(25, 25, 30, (220.0 * opacity) as u8);
    if let Some(rect) = tiny_skia::Rect::from_xywh(osd_x, osd_y, osd_width, osd_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Icon and label
    let (icon, label) = match osd.kind {
        OSDKind::Volume => ("🔊", "Volume"),
        OSDKind::Brightness => ("☀", "Brightness"),
        OSDKind::Mute => ("🔇", "Muted"),
    };
    
    let text_alpha = (255.0 * opacity) as u8;
    draw_text(pixmap, icon, osd_x + osd_width / 2.0 - 15.0, osd_y + 35.0, 28.0, [255, 255, 255, text_alpha]);
    draw_text(pixmap, label, osd_x + osd_width / 2.0 - 30.0, osd_y + 55.0, 12.0, [180, 180, 180, text_alpha]);
    
    // Value bar
    let bar_width = osd_width - 40.0;
    let bar_height = 8.0;
    let bar_x = osd_x + 20.0;
    let bar_y = osd_y + 70.0;
    
    // Bar background
    paint.set_color_rgba8(50, 50, 55, text_alpha);
    if let Some(rect) = tiny_skia::Rect::from_xywh(bar_x, bar_y, bar_width, bar_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Bar fill
    if osd.kind != OSDKind::Mute {
        paint.set_color_rgba8(80, 140, 200, text_alpha);
        let fill_width = bar_width * osd.value as f32 / 100.0;
        if let Some(rect) = tiny_skia::Rect::from_xywh(bar_x, bar_y, fill_width, bar_height) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
    }
    
    // Value percentage
    let value_str = format!("{}%", osd.value);
    draw_text(pixmap, &value_str, osd_x + osd_width / 2.0 - 15.0, osd_y + 95.0, 14.0, [255, 255, 255, text_alpha]);
}

/// Render power menu
pub fn render_power_menu(
    pixmap: &mut tiny_skia::Pixmap,
    power_menu: &PowerMenu,
    width: u32,
    height: u32,
) {
    if !power_menu.visible {
        return;
    }
    
    let mut paint = tiny_skia::Paint::default();
    
    // Semi-transparent overlay
    paint.set_color_rgba8(0, 0, 0, 150);
    if let Some(rect) = tiny_skia::Rect::from_xywh(0.0, 0.0, width as f32, height as f32) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    let menu_width = 300.0;
    let item_height = 50.0;
    let menu_height = power_menu.actions.len() as f32 * item_height + 40.0;
    let menu_x = (width as f32 - menu_width) / 2.0;
    let menu_y = (height as f32 - menu_height) / 2.0;
    
    // Menu background
    paint.set_color_rgba8(35, 35, 40, 250);
    if let Some(rect) = tiny_skia::Rect::from_xywh(menu_x, menu_y, menu_width, menu_height) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // Title
    draw_text(pixmap, "Power Options", menu_x + 90.0, menu_y + 28.0, 16.0, [255, 255, 255, 255]);
    
    // Menu items
    for (i, action) in power_menu.actions.iter().enumerate() {
        let item_y = menu_y + 40.0 + (i as f32 * item_height);
        
        // Highlight selected
        if i == power_menu.selected {
            paint.set_color_rgba8(60, 100, 160, 255);
            if let Some(rect) = tiny_skia::Rect::from_xywh(menu_x + 10.0, item_y, menu_width - 20.0, item_height - 5.0) {
                pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
            }
        }
        
        // Icon
        draw_text(pixmap, action.icon(), menu_x + 25.0, item_y + 32.0, 20.0, [255, 255, 255, 255]);
        
        // Label
        let text_color = if i == power_menu.selected {
            [255, 255, 255, 255]
        } else {
            [200, 200, 200, 255]
        };
        draw_text(pixmap, action.label(), menu_x + 60.0, item_y + 30.0, 15.0, text_color);
    }
}

/// Render screenshot region selection overlay
pub fn render_region_selection(
    pixmap: &mut tiny_skia::Pixmap,
    region: &crate::screenshot::RegionSelection,
    width: u32,
    height: u32,
) {
    if !region.active {
        return;
    }
    
    let mut paint = tiny_skia::Paint::default();
    
    // Dim entire screen
    paint.set_color_rgba8(0, 0, 0, 100);
    if let Some(rect) = tiny_skia::Rect::from_xywh(0.0, 0.0, width as f32, height as f32) {
        pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
    }
    
    // If we have a selection, clear that area and draw border
    if let Some((left, top, right, bottom)) = region.get_rect() {
        // Clear selection area (show through)
        paint.set_color_rgba8(0, 0, 0, 0);
        paint.anti_alias = false;
        let sel_width = (right - left) as f32;
        let sel_height = (bottom - top) as f32;
        
        // Draw selection border
        paint.set_color_rgba8(80, 140, 200, 255);
        
        // Top border
        if let Some(rect) = tiny_skia::Rect::from_xywh(left as f32, top as f32, sel_width, 2.0) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        // Bottom border
        if let Some(rect) = tiny_skia::Rect::from_xywh(left as f32, (bottom - 2) as f32, sel_width, 2.0) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        // Left border
        if let Some(rect) = tiny_skia::Rect::from_xywh(left as f32, top as f32, 2.0, sel_height) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        // Right border
        if let Some(rect) = tiny_skia::Rect::from_xywh((right - 2) as f32, top as f32, 2.0, sel_height) {
            pixmap.fill_rect(rect, &paint, tiny_skia::Transform::identity(), None);
        }
        
        // Dimensions label
        let dims = format!("{}×{}", sel_width as i32, sel_height as i32);
        draw_text(pixmap, &dims, left as f32 + 5.0, top as f32 - 5.0, 12.0, [255, 255, 255, 255]);
    }
    
    // Instructions
    draw_text(
        pixmap,
        "Click and drag to select region • ESC to cancel",
        width as f32 / 2.0 - 150.0,
        height as f32 - 30.0,
        14.0,
        [255, 255, 255, 200],
    );
}
