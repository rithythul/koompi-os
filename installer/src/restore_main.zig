//! restore_main.zig — entry point for `koompi-restore`.
//!
//! A plain stdin/stdout CLI (NO libvaxis) so it is decoupled from the TUI
//! installer. The substance is in reset.zig; this file is only arg parsing +
//! error presentation.
//!
//! ⚠️ SCAFFOLD — UNTESTED on a real btrfs+snapper system. Zig 0.16 conventions:
//! the runtime hands us `std.process.Init` (io, gpa, command-line args); we
//! thread `io` into reset.run.

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

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = init.gpa;

    var mode: reset.Mode = .system;
    var opts = reset.Options{};

    var ebuf: [512]u8 = undefined;
    var efw = std.Io.File.stderr().writerStreaming(io, &ebuf);
    const err = &efw.interface;

    var it = init.minimal.args.iterate();
    _ = it.next(); // argv[0]
    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "--full")) {
            mode = .full;
        } else if (std.mem.eql(u8, arg, "--dry-run")) {
            opts.dry_run = true;
        } else if (std.mem.eql(u8, arg, "--yes")) {
            opts.assume_yes = true;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            var obuf: [1024]u8 = undefined;
            var ofw = std.Io.File.stdout().writerStreaming(io, &obuf);
            ofw.interface.writeAll(usage) catch {};
            ofw.interface.flush() catch {};
            return;
        } else {
            err.print("unknown argument: {s}\n\n", .{arg}) catch {};
            err.writeAll(usage) catch {};
            err.flush() catch {};
            std.process.exit(2);
        }
    }

    reset.run(io, gpa, mode, opts) catch |e| {
        switch (e) {
            error.NotRoot => err.writeAll("error: koompi-restore must be run as root.\n") catch {},
            error.RootSubvolPinned => err.writeAll(
                \\error: / is mounted with an explicit subvol=/subvolid= in /etc/fstab.
                \\       `snapper rollback` cannot change the boot target in that state,
                \\       so a restore would silently do nothing. KOOMPI's post-install
                \\       fix_root_subvol_mount() removes that pin; on a correctly
                \\       installed system this error should never appear.
                \\
            ) catch {},
            error.Aborted => err.writeAll("aborted. Nothing changed.\n") catch {},
            error.BaselineNotFound => err.writeAll(
                "error: no @baseline snapshot found (userdata baseline=yes). Was the install completed?\n",
            ) catch {},
            else => err.print("error: {s}\n", .{@errorName(e)}) catch {},
        }
        err.flush() catch {};
        std.process.exit(1);
    };
}
