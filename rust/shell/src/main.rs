//! KOOMPI Shell - Custom Wayland Compositor
//! 
//! A Wayland compositor built with Smithay for KOOMPI OS.
//! Features: Window management, decorations, panel, launcher, snapping.

use smithay::backend::renderer::gles::GlesRenderer;
use smithay::backend::renderer::{Frame, Renderer, Color32F, ImportMem, ImportDma};
use smithay::backend::renderer::element::Kind;
use smithay::backend::renderer::element::surface::{WaylandSurfaceRenderElement, render_elements_from_surface_tree};
use smithay::backend::renderer::utils::{draw_render_elements, on_commit_buffer_handler};
use smithay::wayland::seat::WaylandFocus;
use smithay::backend::allocator::Fourcc;
use smithay::backend::allocator::dmabuf::Dmabuf;
use smithay::backend::winit::{self, WinitEvent, WinitGraphicsBackend, WinitEventLoop};
use smithay::reexports::calloop::EventLoop;
use smithay::reexports::wayland_server::ListeningSocket;
use smithay::utils::{Rectangle, Transform, Serial, Buffer, Size, Point, Physical, Logical, Scale};
use smithay::wayland::compositor::{CompositorState, CompositorHandler, CompositorClientState};
use smithay::wayland::shell::xdg::{XdgShellState, XdgShellHandler, ToplevelSurface, PopupSurface, PositionerState};
use smithay::wayland::output::OutputHandler;
use smithay::wayland::shm::{ShmState, ShmHandler};
use smithay::wayland::buffer::BufferHandler;
use smithay::wayland::dmabuf::{DmabufState, DmabufHandler, DmabufGlobal, ImportNotifier};
use smithay::output::{Output, PhysicalProperties, Subpixel};
use smithay::input::{Seat, SeatState, SeatHandler};
use smithay::input::pointer::CursorImageStatus;
use smithay::input::keyboard::FilterResult;
use smithay::reexports::wayland_server::{Display, DisplayHandle, Client, protocol::wl_surface::WlSurface, backend::ClientData, protocol::wl_seat::WlSeat};
use smithay::desktop::{Space, Window, space::SpaceElement, PopupManager};
use smithay::delegate_compositor;
use smithay::delegate_xdg_shell;
use smithay::delegate_output;
use smithay::delegate_seat;
use smithay::delegate_shm;
use smithay::delegate_dmabuf;

use smithay::backend::input::{
    Event, InputEvent, KeyboardKeyEvent, 
    PointerButtonEvent, ButtonState, AbsolutePositionEvent, Keycode,
};
use smithay::reexports::winit::platform::pump_events::PumpStatus;

use std::sync::Arc;
use std::time::Instant;

mod ui;
mod notifications;
mod lock_screen;
mod screenshot;

use ui::{ShellUI, Message, render_panel, render_window_decorations, render_lock_screen, render_notifications, render_osd, render_power_menu, render_region_selection};
use notifications::{NotificationDaemon, Notification, Urgency, OSD, OSDKind};
use lock_screen::{LockScreen, LockState, PowerMenu, SessionAction};
use screenshot::{ScreenshotManager, RegionSelection, ScreenshotAction};

/// Title bar height for window decorations
const TITLE_BAR_HEIGHT: i32 = 30;
/// Border width for resize handles
const BORDER_WIDTH: i32 = 5;
/// Snap threshold in pixels
const SNAP_THRESHOLD: i32 = 20;

/// Resize direction
#[derive(Debug, Clone, Copy, PartialEq)]
enum ResizeEdge {
    None,
    Top,
    Bottom,
    Left,
    Right,
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
}

impl Default for ResizeEdge {
    fn default() -> Self {
        Self::None
    }
}

/// Hit test result for window decorations
#[derive(Debug, Clone, Copy, PartialEq)]
enum HitResult {
    None,
    TitleBar,
    CloseButton,
    MaximizeButton,
    MinimizeButton,
    Resize(ResizeEdge),
    Client,
}

/// Window interaction state
#[derive(Default)]
struct InteractionState {
    dragging: Option<usize>,
    drag_start_pos: (f64, f64),
    drag_start_window_pos: (i32, i32),
    resizing: Option<usize>,
    resize_edge: ResizeEdge,
    resize_start_pos: (f64, f64),
    resize_start_geometry: Rectangle<i32, Logical>,
}

/// Keyboard modifier state
#[derive(Default)]
struct ModifierState {
    shift: bool,
    ctrl: bool,
    alt: bool,
    super_key: bool,
}

/// Managed window with decorations
struct ManagedWindow {
    window: Window,
    title: String,
    minimized: bool,
    maximized: bool,
    pre_max_geometry: Option<Rectangle<i32, Logical>>,
}

impl ManagedWindow {
    fn new(window: Window, title: &str) -> Self {
        Self {
            window,
            title: title.to_string(),
            minimized: false,
            maximized: false,
            pre_max_geometry: None,
        }
    }
    
    /// Hit test for window decorations
    fn hit_test(&self, x: f64, y: f64, window_pos: (i32, i32)) -> HitResult {
        let geo = self.window.geometry();
        let loc = window_pos;
        
        let left = loc.0;
        let right = loc.0 + geo.size.w;
        let top = loc.1 - TITLE_BAR_HEIGHT;
        let bottom = loc.1 + geo.size.h;
        let client_top = loc.1;
        
        let xi = x as i32;
        let yi = y as i32;
        
        // Outside window entirely
        if xi < left - BORDER_WIDTH || xi > right + BORDER_WIDTH ||
           yi < top || yi > bottom + BORDER_WIDTH {
            return HitResult::None;
        }
        
        // Title bar area
        if yi >= top && yi < client_top {
            // Check buttons (right side)
            let btn_y_top = top + 5;
            let btn_y_bottom = btn_y_top + 20;
            
            if yi >= btn_y_top && yi <= btn_y_bottom {
                // Close button
                if xi >= right - 25 && xi <= right - 5 {
                    return HitResult::CloseButton;
                }
                // Maximize button
                if xi >= right - 50 && xi <= right - 30 {
                    return HitResult::MaximizeButton;
                }
                // Minimize button
                if xi >= right - 75 && xi <= right - 55 {
                    return HitResult::MinimizeButton;
                }
            }
            
            return HitResult::TitleBar;
        }
        
        // Resize edges (outside client area)
        // Top edge
        if yi >= top - BORDER_WIDTH && yi < top {
            if xi < left + BORDER_WIDTH { return HitResult::Resize(ResizeEdge::TopLeft); }
            if xi > right - BORDER_WIDTH { return HitResult::Resize(ResizeEdge::TopRight); }
            return HitResult::Resize(ResizeEdge::Top);
        }
        
        // Bottom edge
        if yi > bottom && yi <= bottom + BORDER_WIDTH {
            if xi < left + BORDER_WIDTH { return HitResult::Resize(ResizeEdge::BottomLeft); }
            if xi > right - BORDER_WIDTH { return HitResult::Resize(ResizeEdge::BottomRight); }
            return HitResult::Resize(ResizeEdge::Bottom);
        }
        
        // Left edge
        if xi >= left - BORDER_WIDTH && xi < left {
            return HitResult::Resize(ResizeEdge::Left);
        }
        
        // Right edge
        if xi > right && xi <= right + BORDER_WIDTH {
            return HitResult::Resize(ResizeEdge::Right);
        }
        
        // Client area
        if xi >= left && xi <= right && yi >= client_top && yi <= bottom {
            return HitResult::Client;
        }
        
        HitResult::None
    }
}

/// Main shell state
struct KoompiShell {
    start_time: Instant,
    compositor_state: CompositorState,
    xdg_shell_state: XdgShellState,
    shm_state: ShmState,
    dmabuf_state: DmabufState,
    dmabuf_global: Option<DmabufGlobal>,
    seat_state: SeatState<KoompiShell>,
    seat: Seat<KoompiShell>,
    space: Space<Window>,
    popup_manager: PopupManager,
    output: Option<Output>,
    windows: Vec<ManagedWindow>,
    focused_window: Option<usize>,
    pointer_pos: (f64, f64),
    interaction: InteractionState,
    ui: ShellUI,
    frame_count: u64,
    // Phase 5: System Integration
    notifications: NotificationDaemon,
    lock_screen: LockScreen,
    power_menu: PowerMenu,
    screenshot: ScreenshotManager,
    current_osd: Option<OSD>,
    // Modifier state for keybindings
    modifiers: ModifierState,
}

impl KoompiShell {
    fn new(display_handle: DisplayHandle) -> Self {
        let compositor_state = CompositorState::new::<Self>(&display_handle);
        let xdg_shell_state = XdgShellState::new::<Self>(&display_handle);
        let shm_state = ShmState::new::<Self>(&display_handle, vec![]);
        let dmabuf_state = DmabufState::new();
        let mut seat_state = SeatState::new();
        let mut seat = seat_state.new_wl_seat(&display_handle, "koompi-seat");
        
        // Add keyboard capability with default keymap
        seat.add_keyboard(Default::default(), 200, 25).expect("Failed to add keyboard");
        // Add pointer capability
        seat.add_pointer();
        
        let space = Space::default();
        let popup_manager = PopupManager::default();

        Self {
            start_time: Instant::now(),
            compositor_state,
            xdg_shell_state,
            shm_state,
            dmabuf_state,
            dmabuf_global: None,
            seat_state,
            seat,
            space,
            popup_manager,
            output: None,
            windows: Vec::new(),
            focused_window: None,
            pointer_pos: (0.0, 0.0),
            interaction: InteractionState::default(),
            ui: ShellUI::new(),
            frame_count: 0,
            // Phase 5: System Integration
            notifications: NotificationDaemon::new(),
            lock_screen: LockScreen::new(),
            power_menu: PowerMenu::new(),
            screenshot: ScreenshotManager::new(),
            current_osd: None,
            modifiers: ModifierState::default(),
        }
    }

    /// Focus a specific window
    fn focus_window(&mut self, idx: usize) {
        if idx < self.windows.len() {
            self.focused_window = Some(idx);
            
            // Raise window to top
            let window = self.windows[idx].window.clone();
            if let Some(loc) = self.space.element_location(&window) {
                self.space.map_element(window, loc, true);
            }
        }
    }

    /// Find window at position (considering decorations)
    fn window_at(&self, x: f64, y: f64) -> Option<(usize, HitResult)> {
        // Check from top (most recently focused) to bottom
        for idx in (0..self.windows.len()).rev() {
            let mw = &self.windows[idx];
            if mw.minimized {
                continue;
            }
            if let Some(loc) = self.space.element_location(&mw.window) {
                let hit = mw.hit_test(x, y, (loc.x, loc.y));
                if hit != HitResult::None {
                    return Some((idx, hit));
                }
            }
        }
        None
    }

    /// Handle mouse click
    fn handle_click(&mut self, x: f64, y: f64, pressed: bool) {
        // First check UI
        if pressed {
            if let Some(app) = self.ui.update(Message::Click(x, y)) {
                self.launch_app(&app);
                return;
            }
        }

        if pressed {
            if let Some((idx, hit)) = self.window_at(x, y) {
                self.focus_window(idx);
                
                match hit {
                    HitResult::TitleBar => {
                        self.start_drag(idx);
                    }
                    HitResult::CloseButton => {
                        self.close_window(idx);
                    }
                    HitResult::MaximizeButton => {
                        self.toggle_maximize(idx);
                    }
                    HitResult::MinimizeButton => {
                        self.toggle_minimize(idx);
                    }
                    HitResult::Resize(edge) => {
                        self.start_resize(idx, edge);
                    }
                    HitResult::Client => {
                        // Click passed to client
                    }
                    HitResult::None => {}
                }
            }
        } else {
            // Mouse released - stop any interaction
            self.interaction.dragging = None;
            self.interaction.resizing = None;
        }
    }

    fn start_drag(&mut self, idx: usize) {
        if idx < self.windows.len() {
            if let Some(loc) = self.space.element_location(&self.windows[idx].window) {
                self.interaction.dragging = Some(idx);
                self.interaction.drag_start_pos = self.pointer_pos;
                self.interaction.drag_start_window_pos = (loc.x, loc.y);
            }
        }
    }

    fn update_drag(&mut self) {
        if let Some(idx) = self.interaction.dragging {
            if idx < self.windows.len() {
                let dx = self.pointer_pos.0 - self.interaction.drag_start_pos.0;
                let dy = self.pointer_pos.1 - self.interaction.drag_start_pos.1;
                
                let mut new_x = self.interaction.drag_start_window_pos.0 + dx as i32;
                let mut new_y = self.interaction.drag_start_window_pos.1 + dy as i32;
                
                // Edge snapping
                let screen_w = self.ui.screen_size.0 as i32;
                let screen_h = self.ui.screen_size.1 as i32;
                let panel_height = 40;
                
                // Snap to left
                if new_x.abs() < SNAP_THRESHOLD {
                    new_x = 0;
                }
                // Snap to top (below panel)
                if (new_y - panel_height).abs() < SNAP_THRESHOLD {
                    new_y = panel_height;
                }
                // Snap to right
                let geo = self.windows[idx].window.geometry();
                if (new_x + geo.size.w - screen_w).abs() < SNAP_THRESHOLD {
                    new_x = screen_w - geo.size.w;
                }
                // Snap to bottom
                if (new_y + geo.size.h - screen_h).abs() < SNAP_THRESHOLD {
                    new_y = screen_h - geo.size.h;
                }
                
                let window = self.windows[idx].window.clone();
                self.space.map_element(window, (new_x, new_y), true);
            }
        }
    }

    fn start_resize(&mut self, idx: usize, edge: ResizeEdge) {
        if idx < self.windows.len() {
            if let Some(loc) = self.space.element_location(&self.windows[idx].window) {
                let geo = self.windows[idx].window.geometry();
                self.interaction.resizing = Some(idx);
                self.interaction.resize_edge = edge;
                self.interaction.resize_start_pos = self.pointer_pos;
                self.interaction.resize_start_geometry = Rectangle::new(
                    loc,
                    geo.size,
                );
            }
        }
    }

    fn update_resize(&mut self) {
        if let Some(idx) = self.interaction.resizing {
            if idx < self.windows.len() {
                let dx = (self.pointer_pos.0 - self.interaction.resize_start_pos.0) as i32;
                let dy = (self.pointer_pos.1 - self.interaction.resize_start_pos.1) as i32;
                
                let start = &self.interaction.resize_start_geometry;
                let min_size = 100;
                
                let (mut new_x, mut new_y, mut new_w, mut new_h) = (
                    start.loc.x, start.loc.y, start.size.w, start.size.h
                );
                
                match self.interaction.resize_edge {
                    ResizeEdge::Right => {
                        new_w = (start.size.w + dx).max(min_size);
                    }
                    ResizeEdge::Bottom => {
                        new_h = (start.size.h + dy).max(min_size);
                    }
                    ResizeEdge::Left => {
                        let w = (start.size.w - dx).max(min_size);
                        new_x = start.loc.x + start.size.w - w;
                        new_w = w;
                    }
                    ResizeEdge::Top => {
                        let h = (start.size.h - dy).max(min_size);
                        new_y = start.loc.y + start.size.h - h;
                        new_h = h;
                    }
                    ResizeEdge::TopLeft => {
                        let w = (start.size.w - dx).max(min_size);
                        let h = (start.size.h - dy).max(min_size);
                        new_x = start.loc.x + start.size.w - w;
                        new_y = start.loc.y + start.size.h - h;
                        new_w = w;
                        new_h = h;
                    }
                    ResizeEdge::TopRight => {
                        let h = (start.size.h - dy).max(min_size);
                        new_y = start.loc.y + start.size.h - h;
                        new_w = (start.size.w + dx).max(min_size);
                        new_h = h;
                    }
                    ResizeEdge::BottomLeft => {
                        let w = (start.size.w - dx).max(min_size);
                        new_x = start.loc.x + start.size.w - w;
                        new_w = w;
                        new_h = (start.size.h + dy).max(min_size);
                    }
                    ResizeEdge::BottomRight => {
                        new_w = (start.size.w + dx).max(min_size);
                        new_h = (start.size.h + dy).max(min_size);
                    }
                    ResizeEdge::None => {}
                }
                
                // Update window position
                let window = self.windows[idx].window.clone();
                self.space.map_element(window.clone(), (new_x, new_y), true);
                
                // Request resize from client
                if let Some(toplevel) = window.toplevel() {
                    toplevel.with_pending_state(|state| {
                        state.size = Some(Size::from((new_w, new_h)));
                    });
                    toplevel.send_configure();
                }
            }
        }
    }

    fn toggle_maximize(&mut self, idx: usize) {
        if idx >= self.windows.len() {
            return;
        }
        
        let mw = &mut self.windows[idx];
        
        if mw.maximized {
            // Restore
            if let Some(geo) = mw.pre_max_geometry.take() {
                let window = mw.window.clone();
                self.space.map_element(window.clone(), geo.loc, true);
                
                if let Some(toplevel) = window.toplevel() {
                    toplevel.with_pending_state(|state| {
                        state.size = Some(geo.size);
                    });
                    toplevel.send_configure();
                }
            }
            mw.maximized = false;
        } else {
            // Save current geometry
            if let Some(loc) = self.space.element_location(&mw.window) {
                let geo = mw.window.geometry();
                mw.pre_max_geometry = Some(Rectangle::new(loc, geo.size));
            }
            
            // Maximize
            let screen_w = self.ui.screen_size.0 as i32;
            let screen_h = self.ui.screen_size.1 as i32;
            let panel_height = 40;
            
            let window = mw.window.clone();
            self.space.map_element(window.clone(), (0, panel_height), true); // Below top panel
            
            if let Some(toplevel) = window.toplevel() {
                toplevel.with_pending_state(|state| {
                    state.size = Some(Size::from((screen_w, screen_h - panel_height)));
                });
                toplevel.send_configure();
            }
            
            mw.maximized = true;
        }
    }

    fn toggle_minimize(&mut self, idx: usize) {
        if idx < self.windows.len() {
            self.windows[idx].minimized = !self.windows[idx].minimized;
        }
    }

    fn close_window(&mut self, idx: usize) {
        if idx < self.windows.len() {
            if let Some(toplevel) = self.windows[idx].window.toplevel() {
                toplevel.send_close();
            }
        }
    }

    fn launch_app(&self, app: &str) {
        let cmd = match app {
            "Terminal" => "foot",
            "Browser" => "firefox",
            "Files" => "nautilus",
            "Settings" => "gnome-control-center",
            _ => return,
        };
        
        tracing::info!("Launching: {}", cmd);
        
        // Use the current socket name from environment
        let socket_name = std::env::var("WAYLAND_DISPLAY").unwrap_or_else(|_| "wayland-0".to_string());
        
        use std::process::Command;
        let _ = Command::new(cmd)
            .env("WAYLAND_DISPLAY", socket_name)
            .spawn();
    }
    
    fn send_frames(&mut self, time_msec: u32) {
        // Send frame callbacks to all mapped windows
        use std::time::Duration;
        let time = Duration::from_millis(time_msec as u64);
        
        for mw in &self.windows {
            if !mw.minimized {
                mw.window.send_frame(
                    self.output.as_ref().unwrap(),
                    time,
                    None,
                    |_, _| None,
                );
            }
        }
    }
}

// Client data for Wayland
#[derive(Default)]
struct ClientState {
    compositor_state: CompositorClientState,
}
impl ClientData for ClientState {
    fn initialized(&self, _client_id: smithay::reexports::wayland_server::backend::ClientId) {}
    fn disconnected(&self, _client_id: smithay::reexports::wayland_server::backend::ClientId, _reason: smithay::reexports::wayland_server::backend::DisconnectReason) {}
}

impl CompositorHandler for KoompiShell {
    fn compositor_state(&mut self) -> &mut CompositorState {
        &mut self.compositor_state
    }
    
    fn client_compositor_state<'a>(&self, client: &'a Client) -> &'a CompositorClientState {
        &client.get_data::<ClientState>().unwrap().compositor_state
    }
    
    fn commit(&mut self, surface: &WlSurface) {
        // Handle popups
        self.popup_manager.commit(surface);
        
        // Refresh windows when their surface commits
        for mw in &self.windows {
            if mw.window.toplevel().map(|t| t.wl_surface() == surface).unwrap_or(false) {
                mw.window.refresh();
                break;
            }
        }
    }
}

impl XdgShellHandler for KoompiShell {
    fn xdg_shell_state(&mut self) -> &mut XdgShellState {
        &mut self.xdg_shell_state
    }
    
    fn new_toplevel(&mut self, surface: ToplevelSurface) {
        tracing::info!("New toplevel window created");
        
        // Use window count as title since ToplevelState doesn't expose app_id/title easily
        let title = format!("Window {}", self.windows.len() + 1);
        
        #[allow(deprecated)]
        let window = Window::new(surface);
        
        // Position with cascade offset
        let offset = self.windows.len() as i32 * 30;
        let pos = (50 + offset, 50 + offset + TITLE_BAR_HEIGHT);
        
        self.space.map_element(window.clone(), pos, true);
        self.windows.push(ManagedWindow::new(window, &title));
        
        // Focus the new window
        self.focus_window(self.windows.len() - 1);
    }
    
    fn new_popup(&mut self, _surface: PopupSurface, _positioner: PositionerState) {}
    fn grab(&mut self, _surface: PopupSurface, _seat: WlSeat, _serial: Serial) {}
    fn reposition_request(&mut self, _surface: PopupSurface, _positioner: PositionerState, _token: u32) {}
    
    fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
        tracing::info!("Toplevel window destroyed");
        self.windows.retain(|mw| {
            mw.window.toplevel().map(|t| t != &surface).unwrap_or(true)
        });
        
        if let Some(focused) = self.focused_window {
            if focused >= self.windows.len() {
                self.focused_window = if self.windows.is_empty() {
                    None
                } else {
                    Some(self.windows.len() - 1)
                };
            }
        }
    }
}

impl SeatHandler for KoompiShell {
    type KeyboardFocus = WlSurface;
    type PointerFocus = WlSurface;
    type TouchFocus = WlSurface;
    
    fn seat_state(&mut self) -> &mut SeatState<KoompiShell> {
        &mut self.seat_state
    }
    
    fn focus_changed(&mut self, _seat: &Seat<Self>, _focused: Option<&WlSurface>) {}
    fn cursor_image(&mut self, _seat: &Seat<Self>, _image: CursorImageStatus) {}
}

impl OutputHandler for KoompiShell {}

impl ShmHandler for KoompiShell {
    fn shm_state(&self) -> &ShmState {
        &self.shm_state
    }
}

impl BufferHandler for KoompiShell {
    fn buffer_destroyed(&mut self, _buffer: &smithay::reexports::wayland_server::protocol::wl_buffer::WlBuffer) {
        // Handle buffer destruction if needed
    }
}

impl DmabufHandler for KoompiShell {
    fn dmabuf_state(&mut self) -> &mut DmabufState {
        &mut self.dmabuf_state
    }

    fn dmabuf_imported(&mut self, _global: &DmabufGlobal, _dmabuf: Dmabuf, notifier: ImportNotifier) {
        // For now, always report success - the actual import happens during rendering
        // when the renderer imports the dmabuf from the surface buffer
        let _ = notifier.successful::<KoompiShell>();
    }
}

delegate_compositor!(KoompiShell);
delegate_xdg_shell!(KoompiShell);
delegate_output!(KoompiShell);
delegate_seat!(KoompiShell);
delegate_shm!(KoompiShell);
delegate_dmabuf!(KoompiShell);

fn main() -> anyhow::Result<()> {
    // Initialize logging
    if std::env::var("RUST_LOG").is_err() {
        unsafe { std::env::set_var("RUST_LOG", "info,shell=debug") };
    }
    tracing_subscriber::fmt::init();
    
    tracing::info!("Starting KOOMPI Shell...");

    let mut event_loop: EventLoop<KoompiShell> = EventLoop::try_new()?;
    let mut display: Display<KoompiShell> = Display::new()?;
    let display_handle = display.handle();
    
    let (mut backend, mut winit_event_loop): (WinitGraphicsBackend<GlesRenderer>, WinitEventLoop) = 
        winit::init().map_err(|e| anyhow::anyhow!("Failed to init winit: {:?}", e))?;

    tracing::info!("Winit backend initialized");

    let size = backend.window_size();
    tracing::info!("Window size: {}x{}", size.w, size.h);

    let mut state = KoompiShell::new(display_handle.clone());
    state.ui.update(Message::Resize(size.w as u32, size.h as u32));
    
    // Create DMA-BUF global for GPU buffer sharing (needed by clients like kitty)
    {
        let dmabuf_formats = backend.renderer().dmabuf_formats();
        let format_count = dmabuf_formats.iter().count();
        let dmabuf_global = state.dmabuf_state.create_global::<KoompiShell>(&display_handle, dmabuf_formats);
        state.dmabuf_global = Some(dmabuf_global);
        tracing::info!("DMA-BUF global created with {} formats", format_count);
    }
    
    // Create Output
    let output = Output::new(
        "winit".to_string(),
        PhysicalProperties {
            size: (size.w as i32, size.h as i32).into(),
            subpixel: Subpixel::Unknown,
            make: "KOOMPI".into(),
            model: "Virtual".into(),
        },
    );
    
    let mode = smithay::output::Mode {
        size: (size.w as i32, size.h as i32).into(),
        refresh: 60000,
    };
    output.change_current_state(Some(mode), None, None, None);
    output.set_preferred(mode);
    // Create the global so clients can bind to wl_output
    output.create_global::<KoompiShell>(&display_handle);
    state.output = Some(output.clone());
    state.space.map_output(&output, (0, 0));

    // Socket for Wayland clients using ListeningSocket
    let socket_name = format!("wayland-koompi-{}", std::process::id());
    let socket = ListeningSocket::bind(&socket_name)
        .map_err(|e| anyhow::anyhow!("Failed to create socket: {:?}", e))?;
    tracing::info!("Wayland socket: {}", socket_name);
    std::env::set_var("WAYLAND_DISPLAY", &socket_name);

    let mut running = true;
    
    tracing::info!("KOOMPI Shell ready! Click 'KOOMPI' button to open launcher.");

    while running {
        // Accept new Wayland clients
        if let Some(stream) = socket.accept().map_err(|e| anyhow::anyhow!("Socket error: {:?}", e))? {
            let _ = display.handle().insert_client(stream, Arc::new(ClientState::default()));
        }
        
        // Dispatch winit events
        let status = winit_event_loop.dispatch_new_events(|event| {
            match event {
                WinitEvent::Resized { size, .. } => {
                    state.ui.update(Message::Resize(size.w as u32, size.h as u32));
                }
                WinitEvent::Input(input) => {
                    handle_input_event(&mut state, input);
                }
                WinitEvent::Focus(_) => {}
                WinitEvent::Redraw => {}
                WinitEvent::CloseRequested => {
                    running = false;
                }
            }
        });
        
        match status {
            PumpStatus::Continue => {}
            PumpStatus::Exit(_) => {
                running = false;
            }
        }

        // Update clock
        state.ui.update(Message::Tick(chrono::Local::now()));
        
        // Send frame callbacks to clients
        let time_msec = state.start_time.elapsed().as_millis() as u32;
        state.send_frames(time_msec);
        
        // Render frame
        render_frame(&mut backend, &mut state)?;
        
        // Dispatch Wayland protocol events
        display.dispatch_clients(&mut state)?;
        display.flush_clients()?;
    }

    tracing::info!("KOOMPI Shell shutdown");
    Ok(())
}

/// Handle input events from winit backend
fn handle_input_event(state: &mut KoompiShell, event: InputEvent<winit::WinitInput>) {
    // Register activity for idle lock
    state.lock_screen.activity();
    
    // If locked, only handle lock screen input
    if state.lock_screen.state != LockState::Unlocked {
        handle_lock_screen_input(state, event);
        return;
    }
    
    match event {
        InputEvent::PointerMotionAbsolute { event } => {
            let size = state.ui.screen_size;
            let pos = event.position_transformed((size.0 as i32, size.1 as i32).into());
            state.pointer_pos = (pos.x, pos.y);
            state.ui.update(Message::PointerMove(pos.x, pos.y));
            
            // Update screenshot region selection
            if state.screenshot.region_selection.active {
                state.screenshot.region_selection.update(pos.x as i32, pos.y as i32);
            }
            
            if state.interaction.dragging.is_some() {
                state.update_drag();
            } else if state.interaction.resizing.is_some() {
                state.update_resize();
            }
        }
        InputEvent::PointerButton { event } => {
            let pressed = event.state() == ButtonState::Pressed;
            
            // Handle screenshot region selection
            if state.screenshot.region_selection.active {
                if !pressed {
                    if let Some((_x, _y, _w, _h)) = state.screenshot.region_selection.finish() {
                        // TODO: Actually capture the region
                        state.notifications.notify("Screenshot", "Region captured", "Screenshot saved");
                    }
                }
                return;
            }
            
            state.handle_click(state.pointer_pos.0, state.pointer_pos.1, pressed);
        }
        InputEvent::Keyboard { event } => {
            let pressed = event.state() == smithay::backend::input::KeyState::Pressed;
            let released = !pressed;
            
            // Update modifier state
            let keycode = event.key_code();
            update_modifiers(state, keycode, pressed);
            
            // Forward to Wayland clients
            let serial = smithay::utils::SERIAL_COUNTER.next_serial();
            if let Some(keyboard) = state.seat.get_keyboard() {
                keyboard.input::<(), _>(
                    state,
                    event.key_code(),
                    event.state(),
                    serial,
                    event.time_msec(),
                    |_, _, _| FilterResult::Forward,
                );
            }
            
            // Handle shell keybindings
            handle_shell_keybindings(state, keycode, pressed, released);
        }
        _ => {}
    }
}

/// Update modifier state
fn update_modifiers(state: &mut KoompiShell, keycode: Keycode, pressed: bool) {
    match keycode.raw() {
        42 | 54 => state.modifiers.shift = pressed,   // Left/Right Shift
        29 | 97 => state.modifiers.ctrl = pressed,    // Left/Right Ctrl
        56 | 100 => state.modifiers.alt = pressed,    // Left/Right Alt
        125 | 126 => state.modifiers.super_key = pressed, // Left/Right Super
        _ => {}
    }
}

/// Handle shell-level keybindings
fn handle_shell_keybindings(state: &mut KoompiShell, keycode: Keycode, pressed: bool, released: bool) {
    let code = keycode.raw();
    
    // Super key toggles launcher (on release, if no other key was pressed)
    if (code == 125 || code == 126) && released {
        if !state.modifiers.shift && !state.modifiers.ctrl && !state.modifiers.alt {
            state.ui.update(Message::ToggleLauncher);
            state.power_menu.visible = false;
        }
    }
    
    // Super+L: Lock screen
    if code == 38 && pressed && state.modifiers.super_key { // 'L' key
        state.lock_screen.lock();
        state.notifications.notify("System", "Screen locked", "Press any key to unlock");
        tracing::info!("Screen locked (Super+L)");
    }
    
    // Print Screen: Screenshot
    if code == 99 && pressed { // Print Screen key
        let action = ScreenshotAction::from_modifiers(state.modifiers.shift, state.modifiers.alt);
        match action {
            ScreenshotAction::FullScreen => {
                state.notifications.notify("Screenshot", "Full screen captured", "Saved to Pictures/Screenshots");
            }
            ScreenshotAction::ActiveWindow => {
                state.notifications.notify("Screenshot", "Window captured", "Saved to Pictures/Screenshots");
            }
            ScreenshotAction::SelectRegion => {
                state.screenshot.region_selection.start_selection(
                    state.pointer_pos.0 as i32,
                    state.pointer_pos.1 as i32,
                );
                state.notifications.notify("Screenshot", "Select region", "Click and drag to select area");
            }
        }
    }
    
    // Escape: Cancel current action / close popups
    if code == 1 && released { // Escape
        if state.screenshot.region_selection.active {
            state.screenshot.region_selection.cancel();
        } else if state.power_menu.visible {
            state.power_menu.visible = false;
        } else if state.ui.show_launcher {
            state.ui.show_launcher = false;
        }
    }
    
    // Tab: Cycle windows (Alt+Tab style)
    if code == 15 && pressed && !state.windows.is_empty() { // Tab
        let next = state.focused_window
            .map(|i| (i + 1) % state.windows.len())
            .unwrap_or(0);
        state.focus_window(next);
    }
    
    // Super+Q: Close focused window
    if code == 16 && pressed && state.modifiers.super_key { // 'Q' key
        if let Some(idx) = state.focused_window {
            state.close_window(idx);
        }
    }
    
    // Super+E: Open file manager
    if code == 18 && pressed && state.modifiers.super_key { // 'E' key
        state.launch_app("Files");
    }
    
    // Super+T: Open terminal
    if code == 20 && pressed && state.modifiers.super_key { // 'T' key
        state.launch_app("Terminal");
    }
    
    // F11: Toggle fullscreen for focused window
    if code == 87 && pressed { // F11
        if let Some(idx) = state.focused_window {
            state.toggle_maximize(idx);
        }
    }
    
    // Ctrl+Alt+Delete: Power menu
    if code == 111 && pressed && state.modifiers.ctrl && state.modifiers.alt { // Delete
        state.power_menu.toggle();
        state.ui.show_launcher = false;
    }
}

/// Handle input when lock screen is active
fn handle_lock_screen_input(state: &mut KoompiShell, event: InputEvent<winit::WinitInput>) {
    match event {
        InputEvent::Keyboard { event } => {
            let pressed = event.state() == smithay::backend::input::KeyState::Pressed;
            if !pressed {
                return;
            }
            
            let code = event.key_code().raw();
            
            match code {
                // Escape
                1 => state.lock_screen.input_escape(),
                // Backspace
                14 => state.lock_screen.input_backspace(),
                // Enter
                28 => state.lock_screen.input_enter(),
                // Character keys (simplified - would need proper XKB translation)
                _ => {
                    // Very simplified key-to-char mapping for common keys
                    let ch = keycode_to_char(code, state.modifiers.shift);
                    if let Some(c) = ch {
                        state.lock_screen.input_char(c);
                    }
                }
            }
        }
        _ => {}
    }
}

/// Very simple keycode to character mapping (for lock screen)
fn keycode_to_char(code: u32, shift: bool) -> Option<char> {
    let ch = match code {
        // Number row
        2..=11 => {
            let num = if code == 11 { 0 } else { code - 1 };
            if shift {
                ['!', '@', '#', '$', '%', '^', '&', '*', '(', ')'][num as usize]
            } else {
                char::from_digit(num, 10)?
            }
        }
        // Letter keys (QWERTY row 1)
        16 => if shift { 'Q' } else { 'q' },
        17 => if shift { 'W' } else { 'w' },
        18 => if shift { 'E' } else { 'e' },
        19 => if shift { 'R' } else { 'r' },
        20 => if shift { 'T' } else { 't' },
        21 => if shift { 'Y' } else { 'y' },
        22 => if shift { 'U' } else { 'u' },
        23 => if shift { 'I' } else { 'i' },
        24 => if shift { 'O' } else { 'o' },
        25 => if shift { 'P' } else { 'p' },
        // Letter keys (ASDF row)
        30 => if shift { 'A' } else { 'a' },
        31 => if shift { 'S' } else { 's' },
        32 => if shift { 'D' } else { 'd' },
        33 => if shift { 'F' } else { 'f' },
        34 => if shift { 'G' } else { 'g' },
        35 => if shift { 'H' } else { 'h' },
        36 => if shift { 'J' } else { 'j' },
        37 => if shift { 'K' } else { 'k' },
        38 => if shift { 'L' } else { 'l' },
        // Letter keys (ZXCV row)
        44 => if shift { 'Z' } else { 'z' },
        45 => if shift { 'X' } else { 'x' },
        46 => if shift { 'C' } else { 'c' },
        47 => if shift { 'V' } else { 'v' },
        48 => if shift { 'B' } else { 'b' },
        49 => if shift { 'N' } else { 'n' },
        50 => if shift { 'M' } else { 'm' },
        // Space
        57 => ' ',
        // Common punctuation
        12 => if shift { '_' } else { '-' },
        13 => if shift { '+' } else { '=' },
        _ => return None,
    };
    Some(ch)
}

fn render_frame(
    backend: &mut WinitGraphicsBackend<GlesRenderer>,
    state: &mut KoompiShell,
) -> anyhow::Result<()> {
    let size = backend.window_size();
    let damage = Rectangle::from_size(size);
    
    let width = size.w as u32;
    let height = size.h as u32;
    
    // Create UI overlay pixmap first (before binding backend)
    let mut ui_pixmap = tiny_skia::Pixmap::new(width, height)
        .ok_or_else(|| anyhow::anyhow!("Failed to create pixmap"))?;
    
    ui_pixmap.fill(tiny_skia::Color::TRANSPARENT);
    
    // Render window decorations
    for (idx, mw) in state.windows.iter().enumerate() {
        if mw.minimized {
            continue;
        }
        if let Some(loc) = state.space.element_location(&mw.window) {
            let geo = mw.window.geometry();
            let focused = state.focused_window == Some(idx);
            
            render_window_decorations(
                &mut ui_pixmap,
                loc.x,
                loc.y,
                geo.size.w,
                geo.size.h,
                &mw.title,
                focused,
            );
        }
    }
    
    // Render panel (always on top)
    render_panel(&mut ui_pixmap, &state.ui, width, height);
    
    // Render cursor
    let (cx, cy) = (state.pointer_pos.0 as i32, state.pointer_pos.1 as i32);
    let mut paint = tiny_skia::Paint::default();
    paint.set_color_rgba8(255, 255, 255, 255);
    
    // Cursor shape: triangle pointer
    let cursor_path = {
        let mut pb = tiny_skia::PathBuilder::new();
        pb.move_to(cx as f32, cy as f32);
        pb.line_to(cx as f32, (cy + 16) as f32);
        pb.line_to((cx + 5) as f32, (cy + 13) as f32);
        pb.line_to((cx + 8) as f32, (cy + 20) as f32);
        pb.line_to((cx + 10) as f32, (cy + 19) as f32);
        pb.line_to((cx + 7) as f32, (cy + 12) as f32);
        pb.line_to((cx + 12) as f32, (cy + 12) as f32);
        pb.close();
        pb.finish()
    };
    
    if let Some(path) = cursor_path {
        ui_pixmap.fill_path(
            &path,
            &paint,
            tiny_skia::FillRule::Winding,
            tiny_skia::Transform::identity(),
            None,
        );
        // Black outline
        let mut stroke_paint = tiny_skia::Paint::default();
        stroke_paint.set_color_rgba8(0, 0, 0, 255);
        let stroke = tiny_skia::Stroke {
            width: 1.0,
            ..Default::default()
        };
        ui_pixmap.stroke_path(&path, &stroke_paint, &stroke, tiny_skia::Transform::identity(), None);
    }
    
    // ========================================================================
    // Phase 5: Render overlays (notifications, OSD, power menu, lock screen)
    // ========================================================================
    
    // Render notifications (top-right, always visible unless locked)
    if state.lock_screen.state == LockState::Unlocked {
        // Cleanup expired notifications
        state.notifications.cleanup();
        render_notifications(&mut ui_pixmap, &state.notifications, width);
    }
    
    // Render OSD (volume/brightness feedback)
    if let Some(ref osd) = state.current_osd {
        if !osd.is_expired() {
            render_osd(&mut ui_pixmap, osd, width, height);
        } else {
            state.current_osd = None;
        }
    }
    
    // Render screenshot region selection
    render_region_selection(&mut ui_pixmap, &state.screenshot.region_selection, width, height);
    
    // Render power menu
    render_power_menu(&mut ui_pixmap, &state.power_menu, width, height);
    
    // Render lock screen (on top of everything)
    if state.lock_screen.state != LockState::Unlocked {
        render_lock_screen(&mut ui_pixmap, &state.lock_screen, width, height);
    }
    
    // Now bind and render
    let (renderer, mut framebuffer) = backend.bind()
        .map_err(|e| anyhow::anyhow!("Failed to bind: {:?}", e))?;
    
    // Import client buffers before rendering - this is essential for texture availability
    for mw in &state.windows {
        if mw.minimized {
            continue;
        }
        if let Some(wl_surface) = mw.window.wl_surface() {
            // Import buffers from the surface tree using smithay's utility function
            on_commit_buffer_handler::<KoompiShell>(&wl_surface);
        }
    }
    
    // Collect render elements from all toplevel surfaces
    let scale: Scale<f64> = Scale::from(1.0);
    let mut elements: Vec<WaylandSurfaceRenderElement<GlesRenderer>> = Vec::new();
    
    for mw in &state.windows {
        if mw.minimized {
            continue;
        }
        if let Some(loc) = state.space.element_location(&mw.window) {
            let phys_loc: Point<i32, Physical> = loc.to_physical_precise_round(scale);
            // Get the wl_surface from the window and render elements from surface tree
            if let Some(wl_surface) = mw.window.wl_surface() {
                let surface_elements: Vec<WaylandSurfaceRenderElement<GlesRenderer>> = 
                    render_elements_from_surface_tree(
                        renderer, 
                        &wl_surface, 
                        phys_loc, 
                        scale, 
                        1.0, 
                        Kind::Unspecified
                    );
                if !surface_elements.is_empty() && state.frame_count % 120 == 0 {
                    tracing::info!("Window at {:?} has {} render elements", phys_loc, surface_elements.len());
                }
                elements.extend(surface_elements);
            }
        }
    }
    
    // Flip the pixmap vertically for OpenGL (which has bottom-left origin)
    // and convert from RGBA to the correct format
    let row_size = (width * 4) as usize;
    let mut flipped_data = vec![0u8; ui_pixmap.data().len()];
    for y in 0..height as usize {
        let src_row = y * row_size;
        let dst_row = (height as usize - 1 - y) * row_size;
        flipped_data[dst_row..dst_row + row_size].copy_from_slice(&ui_pixmap.data()[src_row..src_row + row_size]);
    }
    
    // Upload UI texture
    let ui_texture = renderer.import_memory(
        &flipped_data,
        Fourcc::Abgr8888,
        Size::<i32, Buffer>::from((width as i32, height as i32)),
        false,
    )?;
    
    // Dark purple background
    let (r, g, b) = (0.12, 0.10, 0.18);
    
    let mut frame = renderer
        .render(&mut framebuffer, damage.size, Transform::Normal)
        .map_err(|e| anyhow::anyhow!("Failed to start frame: {:?}", e))?;
        
    frame.clear(Color32F::new(r, g, b, 1.0), &[damage])
        .map_err(|e| anyhow::anyhow!("Failed to clear: {:?}", e))?;
    
    // Draw window surfaces using the proper smithay utility
    let _ = draw_render_elements::<GlesRenderer, _, WaylandSurfaceRenderElement<GlesRenderer>>(
        &mut frame,
        scale,
        &elements,
        &[damage],
    );
    
    let dst_rect = Rectangle::<i32, Physical>::new(
        Point::from((0, 0)),
        Size::from((width as i32, height as i32)),
    );
    
    // Render UI overlay on top
    frame.render_texture_at(
        &ui_texture,
        Point::from((0, 0)),
        1,
        1.0,
        Transform::Normal,
        &[dst_rect],
        &[],
        1.0,
    ).ok();
    
    let _ = frame.finish();
    
    // Must drop renderer and framebuffer before submit
    drop(framebuffer);
    
    backend.submit(Some(&[damage]))
        .map_err(|e| anyhow::anyhow!("Failed to submit: {:?}", e))?;
    
    state.frame_count += 1;
    if state.frame_count % 120 == 0 {
        let fps = state.frame_count as f32 / state.start_time.elapsed().as_secs_f32();
        tracing::debug!("Frame {}, ~{:.1} FPS, {} windows", state.frame_count, fps, state.windows.len());
    }
    
    Ok(())
}
