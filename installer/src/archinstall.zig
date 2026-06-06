//! archinstall.zig — the orchestration layer (the "engine" adapter).
//!
//! ⚠️ SCAFFOLD — no real disk ops. This module's whole job:
//!   (a) serialize InstallConfig -> user_configuration.json + user_credentials.json
//!   (b) exec `archinstall --config … --creds … --silent`
//!   (c) run the post-install chroot hook (src/post_install.sh)
//!
//! archinstall owns the dangerous 20% (partition/LUKS/pacstrap/GRUB/btrfs).
//! We only hand it answers and run a finishing hook. Every step that touches a
//! disk or a secret is marked TODO/REVIEW.

const std = @import("std");
const config = @import("config.zig");
const InstallConfig = config.InstallConfig;
const Edition = config.Edition;

// ─────────────────────────────────────────────────────────────────────────────
// SCHEMA PINNING (the documented risk).
// archinstall's JSON schema drifts between releases. The ISO MUST pin exactly
// this version. If you bump it, re-check the serializers below against the new
// schema and bump together — never one without the other.
// ─────────────────────────────────────────────────────────────────────────────
pub const ARCHINSTALL_VERSION = "2.8.x"; // TODO: pin the exact release on the ISO

/// The post-install chroot hook, kept as ONE source of truth via @embedFile so
/// the shell script and this "string constant" can never drift apart.
pub const POST_INSTALL_HOOK: []const u8 = @embedFile("post_install.sh");

/// Edition -> target metapackage. A `switch` so the mapping is impossible to get
/// wrong (verified against sdata/dist-arch/koompi-desktop-*).
pub fn targetPackage(edition: Edition) []const u8 {
    return switch (edition) {
        .hyprland => "koompi-desktop-hyprland",
        .kde => "koompi-desktop-kde",
    };
}

// Where the two files land on the live ISO. Credentials go on tmpfs (RAM only).
const CONFIG_PATH = "/tmp/koompi/user_configuration.json";
const CREDS_PATH = "/dev/shm/koompi_user_credentials.json"; // tmpfs/RAM — secret
const HOOK_PATH = "/tmp/koompi/post_install.sh";

// ─────────────────────────────────────────────────────────────────────────────
// (a) SERIALIZE
// ─────────────────────────────────────────────────────────────────────────────

/// Emit user_configuration.json (disk layout + bootloader + the KOOMPI edition
/// package). NON-SECRET — passwords are NOT in this file.
///
/// REVIEW: this hand-rolls the JSON shape against ARCHINSTALL_VERSION. The btrfs
/// subvolume list, the `disk_config`/`disk_layouts` key, and the package field
/// name are exactly the parts that drift. Treat the literal below as a template
/// to diff against the pinned archinstall's own example config.
pub fn writeUserConfiguration(alloc: std.mem.Allocator, cfg: InstallConfig) !void {
    try std.fs.cwd().makePath(std.fs.path.dirname(CONFIG_PATH).?);
    const file = try std.fs.cwd().createFile(CONFIG_PATH, .{ .truncate = true });
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();

    // TODO: replace this hand-written blob with archinstall's real schema for the
    // pinned version. The structure below is illustrative, not verified.
    const pkg = targetPackage(cfg.edition);
    _ = alloc;

    try w.print(
        \\{{
        \\  "_meta": {{
        \\    "generated_by": "koompi-installer (SCAFFOLD)",
        \\    "archinstall_version": "{s}"
        \\  }},
        \\
        \\  "bootloader": "Grub",
        \\  "kernels": ["linux"],
        \\
        \\  "locale_config": {{
        \\    "sys_lang": "{s}",
        \\    "sys_enc": "UTF-8",
        \\    "kb_layout": "{s}"
        \\  }},
        \\  "timezone": "{s}",
        \\
        \\  "hostname": "{s}",
        \\
        \\  "// disk_config": "REVIEW: archinstall owns partition+LUKS+btrfs. Below is the INTENT.",
        \\  "disk_config": {{
        \\    "config_type": "default_layout",
        \\    "device": "{s}",
        \\    "filesystem": "{s}",
        \\    "encrypt": {s},
        \\    "// subvolumes": "btrfs @ layout — exact names must match the pinned archinstall.",
        \\    "btrfs_subvolumes": [
        \\      {{ "name": "@",          "mountpoint": "/" }},
        \\      {{ "name": "@home",      "mountpoint": "/home" }},
        \\      {{ "name": "@var_log",   "mountpoint": "/var/log" }},
        \\      {{ "name": "@var_cache", "mountpoint": "/var/cache" }},
        \\      {{ "name": "@snapshots", "mountpoint": "/.snapshots" }}
        \\    ]
        \\  }},
        \\
        \\  "// packages": "the chosen KOOMPI edition metapackage drives everything else",
        \\  "packages": ["{s}"],
        \\
        \\  "// custom_commands": "post-install runs separately via runPostInstallHook()"
        \\}}
        \\
    , .{
        ARCHINSTALL_VERSION,
        cfg.locale,
        cfg.keymap,
        cfg.timezone,
        cfg.hostname,
        cfg.disk_path,
        if (cfg.btrfs) "btrfs" else "ext4",
        if (cfg.encrypt) "true" else "false",
        pkg,
    });

    try bw.flush();
}

/// Emit user_credentials.json. **SECRET.** Root + user passwords.
///   - written to tmpfs (RAM), never to the spinning disk we're installing onto
///   - chmod 600
///   - DELETED by `cleanupCredentials()` immediately after archinstall exits
///   - NEVER logged (do not print cfg.password anywhere)
///
/// TODO(security): the password currently rides on InstallConfig as a plain
/// slice. Replace with a locked/zeroed secret buffer and pass it directly here.
pub fn writeUserCredentials(alloc: std.mem.Allocator, cfg: InstallConfig) !void {
    _ = alloc;
    const file = try std.fs.cwd().createFile(CREDS_PATH, .{
        .truncate = true,
        .mode = 0o600, // owner read/write only
    });
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();

    // REVIEW: confirm the exact credential keys for the pinned archinstall
    // (root password vs. !users list etc.). DO NOT log this writer's input.
    try w.print(
        \\{{
        \\  "root_enc_password": null,
        \\  "// note": "scaffold emits plaintext fields; archinstall expects these keys",
        \\  "root_password": "{s}",
        \\  "users": [
        \\    {{
        \\      "username": "{s}",
        \\      "password": "{s}",
        \\      "sudo": true
        \\    }}
        \\  ]
        \\}}
        \\
    , .{ cfg.password, cfg.username, cfg.password });

    try bw.flush();
}

/// Shred the credentials file. Call in a `defer` right after the archinstall
/// exec so a secret never survives the process — even on an error path.
/// TODO: overwrite-then-unlink (or rely on tmpfs being RAM-only) before delete.
pub fn cleanupCredentials() void {
    std.fs.cwd().deleteFile(CREDS_PATH) catch {};
}

// ─────────────────────────────────────────────────────────────────────────────
// (b) EXEC archinstall
// ─────────────────────────────────────────────────────────────────────────────

/// Run `archinstall --config … --creds … --silent`. This is the call that does
/// the destructive install. ⚠️ TODO/REVIEW: guarded behind the Review screen in
/// main.zig; must not be reachable without an explicit confirmation.
pub fn runArchinstall(alloc: std.mem.Allocator) !void {
    var child = std.process.Child.init(&.{
        "archinstall",
        "--config",
        CONFIG_PATH,
        "--creds",
        CREDS_PATH,
        "--silent",
    }, alloc);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) return error.ArchinstallFailed,
        else => return error.ArchinstallTerminatedAbnormally,
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// (c) POST-INSTALL CHROOT HOOK
// ─────────────────────────────────────────────────────────────────────────────

/// Drop the embedded post_install.sh onto the live ISO and run it inside the
/// freshly installed target via `arch-chroot`. Pins @baseline, installs
/// snap-pac + grub-btrfs, enables sddm, writes /etc/os-release.
///
/// ⚠️ TODO/REVIEW: hard-codes the target mount at /mnt (archinstall's default).
/// Confirm the actual mountpoint for the pinned archinstall before trusting it.
pub fn runPostInstallHook(alloc: std.mem.Allocator) !void {
    try std.fs.cwd().makePath(std.fs.path.dirname(HOOK_PATH).?);
    {
        const f = try std.fs.cwd().createFile(HOOK_PATH, .{
            .truncate = true,
            .mode = 0o755,
        });
        defer f.close();
        try f.writeAll(POST_INSTALL_HOOK); // single source of truth (@embedFile)
    }

    // Copy the script into the target and run it under chroot.
    // REVIEW: target root assumed at /mnt; script path inside target is /root/.
    const target_root = "/mnt";
    {
        var cp = std.process.Child.init(
            &.{ "cp", HOOK_PATH, target_root ++ "/root/post_install.sh" },
            alloc,
        );
        if (try cp.spawnAndWait() != .Exited) return error.CopyHookFailed;
    }

    var chroot = std.process.Child.init(
        &.{ "arch-chroot", target_root, "/bin/bash", "/root/post_install.sh" },
        alloc,
    );
    chroot.stdin_behavior = .Inherit;
    chroot.stdout_behavior = .Inherit;
    chroot.stderr_behavior = .Inherit;

    const term = try chroot.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) return error.PostInstallFailed,
        else => return error.PostInstallTerminatedAbnormally,
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level orchestration: the full sequence Review->Run calls.
// ─────────────────────────────────────────────────────────────────────────────

/// The whole destructive sequence, in order, with the credential file shredded
/// no matter how we leave. ⚠️ Only call after an explicit Review confirmation.
pub fn run(alloc: std.mem.Allocator, cfg: InstallConfig) !void {
    try writeUserConfiguration(alloc, cfg);
    try writeUserCredentials(alloc, cfg);
    defer cleanupCredentials(); // secret never survives this function

    try runArchinstall(alloc); // ⚠️ destructive — archinstall owns it
    try runPostInstallHook(alloc); // finishing touches in the chroot
}
