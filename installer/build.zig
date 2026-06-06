// KOOMPI installer — build script (Zig 0.14.x).
//
// SCAFFOLD: declares the `koompi-installer` TUI (wires in libvaxis) and the
// `koompi-restore` factory-reset CLI (no libvaxis). Idiomatic, minimal. See
// build.zig.zon for the dependency + placeholder hash.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Pull in the libvaxis dependency declared in build.zig.zon.
    // `.module("vaxis")` is the module name libvaxis exposes (verified against
    // its build.zig: `b.addModule("vaxis", ...)`).
    const vaxis = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "koompi-installer",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Downstream code does `@import("vaxis")`.
    exe.root_module.addImport("vaxis", vaxis.module("vaxis"));

    b.installArtifact(exe);

    // `zig build run` → launch the (skeleton) TUI.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the KOOMPI installer (SCAFFOLD)");
    run_step.dependOn(&run_cmd.step);

    // ── koompi-restore — factory-reset / restore-to-@baseline CLI ──────────────
    // Deliberately does NOT import libvaxis: a plain stdin/stdout confirmation
    // CLI, so it is decoupled from the TUI installer's libvaxis dependency. It is
    // still SCAFFOLD and targets the same 0.14 conventions, so it builds under the
    // SAME prerequisite as the installer — a pinned stable zig (see build.zig.zon's
    // Writergate note); it does not build on a 0.16-dev toolchain.
    const restore = b.addExecutable(.{
        .name = "koompi-restore",
        .root_source_file = b.path("src/restore_main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(restore);

    const run_restore = b.addRunArtifact(restore);
    run_restore.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_restore.addArgs(args);

    const restore_step = b.step("restore", "Run koompi-restore (SCAFFOLD)");
    restore_step.dependOn(&run_restore.step);
}
