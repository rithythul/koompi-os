//! proc.zig — minimal process-exec helpers shared by the KOOMPI installer tools.
//!
//! Extracted from the `std.process` boilerplate repeated in archinstall.zig so
//! every external command runs the same way: a nonzero exit becomes an error,
//! and stdio is either INHERITED (interactive commands the user should see /
//! that may prompt) or CAPTURED (machine-readable output we parse).
//!
//! Zig 0.16 conventions: every operation threads an explicit `io: std.Io`
//! handle (the runtime hands one to `main` via `std.process.Init.io`). Process
//! spawning moved out of `std.process.Child` and onto `std.process.{spawn,run}`;
//! `Child` now only exposes `wait`/`kill`.

const std = @import("std");
const Io = std.Io;

pub const Error = error{
    CommandFailed,
    CommandTerminatedAbnormally,
};

/// Run `argv` with inherited stdio (the user sees output; the command may
/// prompt). A nonzero exit maps to error.CommandFailed.
///
/// `spawn` defaults all three std streams to `.inherit`, exactly what we want;
/// it carries its own allocator inside `io`, so there is no `gpa` parameter.
pub fn run(io: Io, argv: []const []const u8) !void {
    var child = try std.process.spawn(io, .{ .argv = argv });
    const term = try child.wait(io);
    switch (term) {
        .exited => |code| if (code != 0) return Error.CommandFailed,
        else => return Error.CommandTerminatedAbnormally,
    }
}

/// Run `argv`, capture stdout, and return it (caller owns the returned slice).
/// On a nonzero/abnormal exit the captured stderr is echoed to our own stderr so
/// the failure stays visible (0.16's `std.process.run` pipes stderr rather than
/// inheriting it; without this echo a snapper/btrfs failure would be silent),
/// then the captured stdout is freed and the call maps to error.CommandFailed.
pub fn runCapture(io: Io, alloc: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    const res = try std.process.run(alloc, io, .{
        .argv = argv,
        .stdout_limit = .limited(1 << 20),
    });
    defer alloc.free(res.stderr);

    switch (res.term) {
        .exited => |code| if (code != 0) {
            echoStderr(io, res.stderr);
            alloc.free(res.stdout);
            return Error.CommandFailed;
        },
        else => {
            echoStderr(io, res.stderr);
            alloc.free(res.stdout);
            return Error.CommandTerminatedAbnormally;
        },
    }
    return res.stdout;
}

/// Best-effort: forward a failed command's captured stderr to our own stderr.
fn echoStderr(io: Io, bytes: []const u8) void {
    if (bytes.len == 0) return;
    var buf: [256]u8 = undefined;
    var fw = std.Io.File.stderr().writerStreaming(io, &buf);
    fw.interface.writeAll(bytes) catch {};
    fw.interface.flush() catch {};
}
