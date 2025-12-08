//! KOOMPI Shell - Custom Wayland Compositor
//! 
//! A minimal Wayland compositor built with Smithay for KOOMPI OS.

use smithay::backend::renderer::gles::GlesRenderer;
use smithay::backend::renderer::{Frame, Renderer, Color32F};
use smithay::backend::winit::{self, WinitEvent, WinitGraphicsBackend, WinitEventLoop};
use smithay::reexports::calloop::EventLoop;
use smithay::utils::{Rectangle, Transform};

use std::time::Instant;

/// Main state for the KOOMPI Shell compositor
struct KoompiShell {
    start_time: Instant,
    running: bool,
    frame_count: u64,
}

impl KoompiShell {
    fn new() -> Self {
        Self {
            start_time: Instant::now(),
            running: true,
            frame_count: 0,
        }
    }
}

fn main() -> anyhow::Result<()> {
    // Initialize logging
    if std::env::var("RUST_LOG").is_err() {
        unsafe { std::env::set_var("RUST_LOG", "info,koompi_shell=debug") };
    }
    tracing_subscriber::fmt::init();
    
    tracing::info!("Starting KOOMPI Shell...");

    // Create the calloop event loop
    let mut event_loop: EventLoop<KoompiShell> = EventLoop::try_new()?;
    
    // Initialize Winit backend with GlesRenderer
    let (mut backend, mut winit_event_loop): (WinitGraphicsBackend<GlesRenderer>, WinitEventLoop) = 
        winit::init()
            .map_err(|e| anyhow::anyhow!("Failed to initialize winit backend: {:?}", e))?;

    tracing::info!("Winit backend initialized successfully");

    // Get window size
    let size = backend.window_size();
    tracing::info!("Window size: {:?}", size);

    // Create our shell state
    let mut state = KoompiShell::new();

    tracing::info!("Entering main event loop...");

    // Main event loop
    loop {
        // Dispatch winit events - check if exit was requested
        let exit_requested = std::cell::Cell::new(false);
        let needs_redraw = std::cell::Cell::new(false);
        
        winit_event_loop.dispatch_new_events(|event| {
            match event {
                WinitEvent::Resized { size, .. } => {
                    tracing::debug!("Window resized to {:?}", size);
                    needs_redraw.set(true);
                }
                WinitEvent::Input(input_event) => {
                    tracing::debug!("Input: {:?}", input_event);
                }
                WinitEvent::Focus(focused) => {
                    tracing::debug!("Focus changed: {}", focused);
                }
                WinitEvent::Redraw => {
                    needs_redraw.set(true);
                }
                WinitEvent::CloseRequested => {
                    tracing::info!("Close requested, shutting down...");
                    exit_requested.set(true);
                }
            }
        });

        if exit_requested.get() || !state.running {
            break;
        }

        // Render a frame
        if needs_redraw.get() {
            render_frame(&mut backend, &mut state)?;
        }

        // Dispatch calloop events (with a small timeout)
        event_loop
            .dispatch(Some(std::time::Duration::from_millis(16)), &mut state)
            .map_err(|e| anyhow::anyhow!("Event loop error: {:?}", e))?;
    }

    tracing::info!("KOOMPI Shell shutdown complete");
    Ok(())
}

/// Render a single frame
fn render_frame(
    backend: &mut WinitGraphicsBackend<GlesRenderer>,
    state: &mut KoompiShell,
) -> anyhow::Result<()> {
    let size = backend.window_size();
    
    // Create a damage rectangle covering the whole screen
    let damage = Rectangle::from_size(size);
    
    {
        // Get a render target from the backend
        let (renderer, mut target) = backend.bind()
            .map_err(|e| anyhow::anyhow!("Failed to bind backend: {:?}", e))?;
        
        // Begin rendering
        let mut frame = renderer
            .render(&mut target, size, Transform::Normal)
            .map_err(|e| anyhow::anyhow!("Failed to start render: {:?}", e))?;
        
        // Clear to a nice blue color (KOOMPI brand-ish)
        // Animate the color slightly based on time
        let elapsed = state.start_time.elapsed().as_secs_f32();
        let r = 0.05 + 0.02 * (elapsed * 0.5).sin();
        let g = 0.10 + 0.02 * (elapsed * 0.7).sin();
        let b = 0.20 + 0.05 * (elapsed * 0.3).sin();
        
        let color = Color32F::new(r, g, b, 1.0);
        frame.clear(color, &[damage])
            .map_err(|e| anyhow::anyhow!("Failed to clear frame: {:?}", e))?;
        
        // Finish rendering
        let _ = frame.finish()
            .map_err(|e| anyhow::anyhow!("Failed to finish frame: {:?}", e))?;
    }
    
    // Submit the frame
    backend.submit(Some(&[damage]))
        .map_err(|e| anyhow::anyhow!("Failed to submit frame: {:?}", e))?;
    
    state.frame_count += 1;
    if state.frame_count % 60 == 0 {
        let elapsed = state.start_time.elapsed().as_secs_f32();
        let fps = state.frame_count as f32 / elapsed;
        tracing::debug!("Frame {}, ~{:.1} FPS", state.frame_count, fps);
    }
    
    Ok(())
}
