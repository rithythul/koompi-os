//! reset.zig — koompi-restore orchestration (the "why/when").
//!
//! Restores KOOMPI OS to its factory @baseline snapshot. The mechanics live in
//! snapper.zig / proc.zig / reset_home.sh; this module owns the policy: which
//! mode, the safety guards, the confirmation gate, and the staging order.
//!
//! Two modes:
//!   .system  (DEFAULT, safe)   snapper rollback @ → @baseline; reboot. `@home`
//!                              is a separate subvolume and is NOT touched, so
//!                              all user files in /home survive.
//!   .full    (--full, DESTRUCTIVE)  the above PLUS an OFFLINE wipe + reseed of
//!                              the `@home` subvolume. /home cannot be replaced
//!                              while it is mounted, so we ARM a one-shot boot
//!                              unit (reset_home.sh) and let the next boot do it
//!                              before /home is mounted.
//!
//! ⚠️ THE CENTRAL ORDERING HAZARD (read before touching .full):
//! `snapper rollback` replaces `@` with @baseline on reboot — so ANYTHING we
//! write to `@` here is gone on the next boot. Therefore:
//!   (1) the offline-reset unit + script must live in the BASELINE (installed +
//!       enabled by post_install.sh install_home_reset_unit(), so they're present
//!       AFTER the rollback), and
//!   (2) the "do it now" MARKER is placed on the btrfs TOP-LEVEL subvolume
//!       (subvolid=5), which the root-config rollback never touches — so it
//!       survives to the next boot. reset_home.sh `arm` writes it; the gated boot
//!       unit (reset_home.sh `run`) consumes it.
//!
//! ⚠️ SCAFFOLD — UNTESTED. Needs a pinned zig (targets 0.14) + a real
//! btrfs+snapper install. Every snapper / btrfs / reboot line is a REVIEW point.

const std = @import("std");
const proc = @import("proc.zig");
const snapper = @import("snapper.zig");

pub const Mode = enum { system, full };

pub const Options = struct {
    dry_run: bool = false,
    assume_yes: bool = false,
};

pub const Error = error{
    NotRoot,
    RootSubvolPinned,
    Aborted,
};

// Single source of truth for the offline @home reset (embedded; dropped into the
// live system by armHomeReset()). Same @embedFile discipline archinstall.zig uses
// for POST_INSTALL_HOOK — the shell script and this constant can never drift.
const RESET_HOME_SH: []const u8 = @embedFile("reset_home.sh");
const RESET_HOME_UNIT: []const u8 = @embedFile("koompi-factory-reset-home.service");

const RESET_HOME_SH_PATH = "/usr/local/lib/koompi/reset_home.sh";
const RESET_HOME_UNIT_PATH = "/etc/systemd/system/koompi-factory-reset-home.service";
const RESET_HOME_UNIT_NAME = "koompi-factory-reset-home.service";

pub fn run(alloc: std.mem.Allocator, mode: Mode, opts: Options) !void {
    const out = std.io.getStdOut().writer();

    try ensureRoot();
    try ensureRootUnpinned(alloc);

    const baseline = try snapper.findBaseline(alloc);

    out.print(
        \\
        \\KOOMPI OS — restore to factory baseline
        \\  mode      : {s}
        \\  baseline  : snapshot #{d}  (the un-prunable @baseline)
        \\  /home     : {s}
        \\
        \\
    , .{
        if (mode == .full) "FULL FACTORY RESET" else "System Restore",
        baseline,
        if (mode == .full) "ERASED + reseeded from /etc/skel" else "kept (untouched)",
    }) catch {};

    if (opts.dry_run) {
        out.print(
            "dry-run: would roll @ back to #{d}{s}, then reboot. Nothing changed.\n",
            .{ baseline, if (mode == .full) " and arm the offline /home wipe" else "" },
        ) catch {};
        return;
    }

    if (!opts.assume_yes) try confirm(mode);

    // Roll back FIRST, then (for --full) arm the /home wipe with the rollback's
    // NEW snapshot number. reset_home.sh run() refuses to delete @home unless the
    // next boot is actually running that snapshot — so a no-op boot (the KNOWN-OPEN
    // GRUB rootflags=subvol=@ leg, which can keep us on old @) fails SAFE: /home is
    // kept and the marker is left for a later correct boot. Arming AFTER the
    // rollback is still rollback-proof — the marker lands on the btrfs top-level
    // subvol (subvolid=5), which the root-config rollback never touches.
    // ⚠️ The subvol-identity check is IMPLEMENTED but VM-UNVERIFIED, and the GRUB
    // leg is still OPEN, so `--full` MUST NOT run on real hardware until both are
    // settled (roadmap B4). The guard makes a no-op boot non-destructive; it does
    // not make the rollback succeed.
    const new_snap = try snapper.rollback(alloc, baseline);
    if (mode == .full) try armHomeReset(alloc, new_snap);

    out.print("rolled @ back → new root snapshot #{d}. Rebooting…\n", .{new_snap}) catch {};

    try proc.run(alloc, &.{ "systemctl", "reboot" });
}

fn ensureRoot() Error!void {
    if (std.os.linux.geteuid() != 0) return Error.NotRoot;
}

/// `snapper rollback` only changes the boot target by flipping the btrfs DEFAULT
/// subvolume. TWO things can override that flip and make the rollback a silent
/// no-op:
///   (a) fstab — `/` pinned with `subvol=`/`subvolid=`. THIS is what we check
///       here. post_install.sh's fix_root_subvol_mount() strips the pin, so on a
///       correct KOOMPI install this guard passes; it exists to fail LOUDLY
///       rather than silently do nothing.
///   (b) GRUB — grub-mkconfig's 10_linux usually writes `rootflags=subvol=@` on
///       the kernel cmdline, which boots @ explicitly regardless of the default
///       subvolume. This guard does NOT catch leg (b) — there is no reliable way
///       to read the *baked* grub.cfg cmdline from here, and the post_install
///       fixup for it is still OPEN (see fix_root_subvol_mount's REVIEW). So a
///       passing check here is necessary but NOT sufficient; the rollback can
///       still no-op at the GRUB layer until leg (b) is closed + VM-verified.
///
/// We read the fstab entry (not `findmnt`, which reports the RESOLVED subvol even
/// when nothing was pinned). Best-effort: an unreadable / non-btrfs `/` passes.
fn ensureRootUnpinned(alloc: std.mem.Allocator) !void {
    const fstab = std.fs.cwd().readFileAlloc(alloc, "/etc/fstab", 1 << 20) catch return;
    defer alloc.free(fstab);

    var lines = std.mem.tokenizeScalar(u8, fstab, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        // fields: <spec> <mountpoint> <fstype> <options> <dump> <pass>
        var it = std.mem.tokenizeAny(u8, line, " \t");
        _ = it.next() orelse continue; // spec
        const mnt = it.next() orelse continue;
        const fstype = it.next() orelse continue;
        const fopts = it.next() orelse continue;
        if (!std.mem.eql(u8, mnt, "/")) continue;
        if (!std.mem.eql(u8, fstype, "btrfs")) return; // not our layout — let it pass
        if (std.mem.indexOf(u8, fopts, "subvol=") != null or
            std.mem.indexOf(u8, fopts, "subvolid=") != null)
        {
            return Error.RootSubvolPinned;
        }
        return;
    }
}

fn confirm(mode: Mode) !void {
    const out = std.io.getStdOut().writer();
    const in = std.io.getStdIn().reader();
    var buf: [64]u8 = undefined;

    switch (mode) {
        .system => {
            out.print("Proceed with System Restore? Files in /home are kept. [y/N] ", .{}) catch {};
            const line = (in.readUntilDelimiterOrEof(&buf, '\n') catch null) orelse return Error.Aborted;
            const a = std.mem.trim(u8, line, " \t\r");
            if (!std.mem.eql(u8, a, "y") and !std.mem.eql(u8, a, "Y")) return Error.Aborted;
        },
        .full => {
            // Type-to-confirm: this erases every user's files. A bare [y/N] is too
            // easy to fat-finger on a fleet of student laptops.
            out.print("FULL FACTORY RESET erases ALL files in /home. Type RESET to confirm: ", .{}) catch {};
            const line = (in.readUntilDelimiterOrEof(&buf, '\n') catch null) orelse return Error.Aborted;
            const a = std.mem.trim(u8, line, " \t\r");
            if (!std.mem.eql(u8, a, "RESET")) return Error.Aborted;
        },
    }
}

/// Arm the offline /home wipe for the next boot, bound to snapshot `new_snap`.
///
/// The ONLY load-bearing line for the real .full flow is the final `arm <N>` call:
/// it writes the rollback-proof MARKER (containing N = the rollback's new snapshot
/// number) on the btrfs top-level subvol (subvolid=5), which `snapper rollback`
/// (root config, @ only) never touches — so it survives to the next boot, where
/// the baseline's gated unit consumes it AND verifies the running subvol is N
/// before wiping (the asymmetric-reset guard). The payload that actually runs at
/// that boot is the script+unit baked into @baseline by the koompi-restore PACKAGE
/// (post_install enables it) — NOT anything we write here.
///
/// The two createFile writes + the `systemctl enable` below are NON-load-bearing:
/// they target the live `@`, which the rollback discards on reboot, and they
/// duplicate what the package already ships. They exist ONLY so the offline-wipe
/// path can be exercised on an UNPACKAGED dev box (run the unit manually, no
/// rollback). On a real install they are redundant; on a dev box they're a
/// convenience. Best-effort — failures here must not block the marker.
fn armHomeReset(alloc: std.mem.Allocator, new_snap: u32) !void {
    // -- non-load-bearing (manual-test convenience on an unpackaged dev box) --
    blk: {
        std.fs.cwd().makePath(std.fs.path.dirname(RESET_HOME_SH_PATH).?) catch break :blk;
        {
            const f = std.fs.cwd().createFile(RESET_HOME_SH_PATH, .{ .truncate = true, .mode = 0o755 }) catch break :blk;
            defer f.close();
            f.writeAll(RESET_HOME_SH) catch break :blk;
        }
        {
            const f = std.fs.cwd().createFile(RESET_HOME_UNIT_PATH, .{ .truncate = true, .mode = 0o644 }) catch break :blk;
            defer f.close();
            f.writeAll(RESET_HOME_UNIT) catch break :blk;
        }
        proc.run(alloc, &.{ "systemctl", "enable", RESET_HOME_UNIT_NAME }) catch {};
    }

    // -- load-bearing: arm the rollback-proof marker WITH the snapshot number, so
    //    the boot-time guard only wipes /home if we actually booted snapshot N --
    var buf: [16]u8 = undefined;
    const n = std.fmt.bufPrint(&buf, "{d}", .{new_snap}) catch unreachable; // u32 ≤ 10 digits
    try proc.run(alloc, &.{ RESET_HOME_SH_PATH, "arm", n });
}
