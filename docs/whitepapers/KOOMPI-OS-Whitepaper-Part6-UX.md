# KOOMPI OS Development Whitepaper
## Part 6: Hybrid UI/UX Design System

**Version:** 1.0  
**Date:** December 2024  
**Organization:** SmallWorld

---

## 1. Design Philosophy

### 1.1 The "Hybrid" Approach

KOOMPI OS adopts a **"Best of Both Worlds"** strategy, synthesizing the most effective interaction models from major operating systems to create an interface that is intuitive for beginners yet powerful for professionals.

| Inspiration Source | Element Adopted | Rationale |
|-------------------|-----------------|-----------|
| **Windows** | Bottom Panel & System Tray | Dense information density, familiar navigation anchor |
| **macOS** | Centered Dock & Spotlight Search | Visual balance, focus, quick access |
| **Mobile (Android/iOS)** | App Drawer & Squircle Icons | Discoverability, touch-friendly, modern aesthetic |
| **Tiling WMs** | Window Snapping | Productivity, classroom multitasking |

### 1.2 Core Principles

1.  **Discoverability**: Interface elements must be obvious. A student should never have to guess how to launch an app.
2.  **Focus**: Minimize visual clutter. The OS frame should recede, letting the content shine.
3.  **Identity**: A distinct "KOOMPI Look" that feels friendly, educational, and Khmer-native.
4.  **Consistency**: One unified interface for all roles (Student, Teacher, Developer), differentiated only by permissions.

---

## 2. Desktop Layout

### 2.1 The Smart Panel (Bottom)

The desktop features a single, permanent bottom panel divided into three distinct zones:

**Zone A: The Anchor (Left)**
- **Start Button**: A dedicated "KOOMPI" logo button.
- **Behavior**: Opens the full-screen App Drawer.
- **Why**: Provides a clear, consistent starting point for all interactions.

**Zone B: The Dock (Center)**
- **Content**: Pinned and running applications.
- **Style**: Floating appearance (visually distinct from the panel background), centered alignment.
- **Behavior**: macOS-style magnification (optional), indicators for running apps.
- **Why**: Centers the user's vision and balances the screen.

**Zone C: The Tray (Right)**
- **Content**: System indicators (Wi-Fi, Battery, Volume, Input Method, Notifications).
- **Style**: Windows 11-style grouped flyouts.
- **Why**: High information density is critical for troubleshooting connectivity in schools.

### 2.2 The Launcher (App Drawer)

Instead of a hierarchical menu, KOOMPI uses a **rich grid of icons**, similar to a tablet or phone.

- **Layout**: Full-screen overlay with a translucent background.
- **Organization**: Alphabetical grid, searchable.
- **Folders**: Support for grouping apps (e.g., "Math Tools", "Office").
- **Why**: Students are already familiar with this paradigm from smartphones.

### 2.3 Global Search ("Spotlight")

- **Trigger**: `Super` (Command/Windows) key.
- **Appearance**: A floating search bar in the center of the screen.
- **Capabilities**: Launch apps, find files, calculate math, search the web, ask AI.
- **Why**: The fastest way for power users and teachers to navigate.

---

## 3. Visual Identity

### 3.1 Iconography

- **Shape**: **Uniform Squircle** (Rounded Square).
- **Rationale**:
    - **Consistency**: Forces all third-party app icons into a uniform shape, reducing visual chaos.
    - **Aesthetic**: Feels friendly and modern (like iOS/OneUI) rather than rigid (Windows) or inconsistent (Linux).

### 3.2 Typography

- **English**: **Roboto** (Clean, geometric, highly legible).
- **Khmer**: **Noto Sans Khmer** (Google's standard for Khmer, ensuring perfect rendering of complex scripts).
- **Sizing**: Slightly larger base font size (11pt) to accommodate projector visibility.

### 3.3 Color & Theme

- **Default**: **Auto-Switching** (Light Mode during day, Dark Mode at night).
- **Palette**:
    - **Primary**: KOOMPI Blue (Trust, Education).
    - **Accent**: Vibrant Orange (Creativity, Energy).
    - **Backgrounds**: **Abstract/Geometric** art. Avoid distracting photography.

### 3.4 Motion & Feedback

- **Boot Animation**: The KOOMPI logo "assembles" itself from geometric parts, symbolizing construction and learning.
- **Cursor**: **High-Visibility Black Arrow** with a white border.
    - **Why**: Essential for visibility on low-contrast classroom projectors.
- **Sound Design**:
    - **Startup**: A short, 3-note "digital chime" (Bright, Optimistic).
    - **Notifications**: Soft "plucks" (Non-intrusive).
    - **Errors**: Low-pitched "hum" (Informative, not punishing).

---

## 4. Window Management

### 4.1 Snapping & Tiling

KOOMPI OS enforces strong window snapping to support education workflows (e.g., "Watch video on left, take notes on right").

- **Snap Assist**: Dragging a window to an edge shows a "snap preview".
- **Tiling**: Support for Quarter Tiling (4 corners).
- **Touch Gestures**: 3-finger swipe to switch workspaces.

### 4.2 Kiosk Mode (Student View)

While the visual design remains consistent, the **Student Role** runs in a restricted "Kiosk" state:

- **Locked Settings**: Wallpaper, panel layout, and system settings are read-only.
- **App Allowlist**: Only approved educational apps can launch.
- **Visuals**: The interface looks identical to the Teacher view, but "dangerous" options are greyed out or hidden.

---

## 5. Implementation Strategy

### 5.1 Technology Stack

- **Compositor**: **Smithay** (Rust) - Handles Wayland protocol, input, and rendering.
- **UI Toolkit**: **Iced** (Rust) - Renders the Panel, Dock, Launcher, and HUD.
- **Window Decorations**: Server-side decorations (SSD) drawn by Smithay.
- **IPC**: D-Bus for communicating with `koompi-daemon` (battery, network, volume).

### 5.2 Architecture

The shell is a single Rust binary (`koompi-shell`) that manages the entire session:

```rust
// Conceptual Structure
struct KoompiShell {
    compositor: SmithayCompositor,
    ui: IcedRuntime,
    state: ShellState,
}
```

This monolithic approach ensures:
1.  **Performance**: Zero IPC overhead between the window manager and the panel.
2.  **Stability**: If the UI crashes, the compositor can restart it instantly without losing open windows.
3.  **Security**: The "Kiosk Mode" is hardcoded into the compositor logic, making it impossible to bypass via config files.

---

*End of Part 6*

**Previous:** [Part 5: Success Metrics, Risks & Appendices](./KOOMPI-OS-Whitepaper-Part5-Metrics.md)
