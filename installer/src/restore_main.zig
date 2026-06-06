//! restore_main.zig — entry point for `koompi-restore`.
//!
//! A plain stdin/stdout CLI (NO libvaxis) so it is decoupled from the TUI
//! installer's libvaxis/zig-0.16 block — see build.zig. The substance is in
//! reset.zig; this file is only arg parsing + error presentation.
//!
//! ⚠️ SCAFFOLD — UNTESTED. Targets Zig 0.14 conventions.

const std = @import("std");
const reset = @import("reset.zig");

const usage =
    \\koompi-restore — restore KOOMPI OS to its factory @baseline snapshot.
    \\
    \\  koompi-restore           System Restore: roll the OS back to baseline and
    \\                           KEEP all files in /home. (default)
    \\  koompi-restore --full    Full Factory Reset: the above PLUS erase and
    \\                           reseed /home. DESTROYS all user files.
    \\
    \\  --dry-run                Show the plan; change nothing.
    \\  --yes                    Skip the interactive confirmation.
    \\  -h, --help               Show this help.
    \\
    \\Must be run as root.
    \\
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var mode: reset.Mode = .system;
    var opts = reset.Options{};

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.next(); // argv[0]
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--full")) {
            mode = .full;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            opts.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--yes")) {
            opts.assume_yes = true;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            std.io.getStdOut().writeAll(usage) catch {};
            return;
        } else {
            const e = std.io.getStdErr().writer();
            e.print("unknown argument: {s}\n\n", .{arg}) catch {};
            e.writeAll(usage) catch {};
            std.process.exit(2);
        }
    }

    reset.run(alloc, mode, opts) catch |err| {
        const e = std.io.getStdErr().writer();
        switch (err) {
            error.NotRoot => e.writeAll("error: koompi-restore must be run as root.\n") catch {},
            error.RootSubvolPinned => e.writeAll(
                \\error: / is mounted with an explicit subvol=/subvolid= in /etc/fstab.
                \\       `snapper rollback` cannot change the boot target in that state,
                \\       so a restore would silently do nothing. KOOMPI's post-install
                \\       fix_root_subvol_mount() removes that pin; on a correctly
                \\       installed system this error should never appear.
                \\
            ) catch {},
            error.Aborted => e.writeAll("aborted. Nothing changed.\n") catch {},
            error.BaselineNotFound => e.writeAll(
                "error: no @baseline snapshot found (userdata baseline=yes). Was the install completed?\n",
            ) catch {},
            else => e.print("error: {s}\n", .{@errorName(err)}) catch {},
        }
        std.process.exit(1);
    };
}
