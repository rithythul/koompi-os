// KOOMPI installer — build script (Zig 0.16.x).
//
// SCAFFOLD: builds the `koompi-installer` TUI skeleton and the `koompi-restore`
// factory-reset CLI. libvaxis was DROPPED while the TUI event loop is stubbed —
// it was an unused import (`_ = vaxis`), and pinning a 0.16-compatible revision
// + hash for a dependency nothing references yet is wasted churn. Re-add it to
// build.zig.zon when the real event loop is wired (see main.zig's TODO sketch).

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // 0.16: addExecutable takes a `root_module` (created via b.createModule)
    // rather than a bare root_source_file/target/optimize triple.
    const exe = b.addExecutable(.{
        .name = "koompi-installer",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    // `zig build run` → launch the (skeleton) TUI.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the KOOMPI installer (SCAFFOLD)");
    run_step.dependOn(&run_cmd.step);

    // ── koompi-restore — factory-reset / restore-to-@baseline CLI ──────────────
    // A plain stdin/stdout confirmation CLI (no libvaxis), so it is independent of
    // the TUI installer.
    const restore = b.addExecutable(.{
        .name = "koompi-restore",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/restore_main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(restore);

    const run_restore = b.addRunArtifact(restore);
    run_restore.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_restore.addArgs(args);

    const restore_step = b.step("restore", "Run koompi-restore (SCAFFOLD)");
    restore_step.dependOn(&run_restore.step);
}
