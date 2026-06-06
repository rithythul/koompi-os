//! proc.zig — minimal process-exec helpers shared by the KOOMPI installer tools.
//!
//! Extracted from the `std.process.Child` boilerplate repeated in archinstall.zig
//! so every external command runs the same way: a nonzero exit becomes an error,
//! and stdio is either INHERITED (interactive commands the user should see /
//! that may prompt) or CAPTURED (machine-readable output we parse).
//!
//! ⚠️ SCAFFOLD — targets Zig 0.14 conventions like the rest of installer/src
//! (pre-"Writergate"; see build.zig.zon). Used by koompi-restore today.
//! TODO: migrate archinstall.zig's three inline Child blocks onto run() once a
//! stable zig is pinned and the installer actually compiles again — do NOT churn
//! an unbuildable stub (code-structure: extract → replace one caller → VERIFY).

const std = @import("std");

pub const Error = error{
    CommandFailed,
    CommandTerminatedAbnormally,
};

/// Run `argv` with inherited stdio (the user sees output; the command may
/// prompt). A nonzero exit maps to error.CommandFailed.
pub fn run(alloc: std.mem.Allocator, argv: []const []const u8) !void {
    var child = std.process.Child.init(argv, alloc);
    child.stdin_behavior = .Inherit;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();
    switch (term) {
        .Exited => |code| if (code != 0) return Error.CommandFailed,
        else => return Error.CommandTerminatedAbnormally,
    }
}

/// Run `argv`, capture stdout, and return it (caller owns the returned slice).
/// stderr is inherited so failures stay visible. A nonzero exit maps to
/// error.CommandFailed (the captured stdout is freed before returning the error).
pub fn runCapture(alloc: std.mem.Allocator, argv: []const []const u8) ![]u8 {
    const res = try std.process.Child.run(.{
        .allocator = alloc,
        .argv = argv,
        .max_output_bytes = 1 << 20,
    });
    defer alloc.free(res.stderr);

    switch (res.term) {
        .Exited => |code| if (code != 0) {
            alloc.free(res.stdout);
            return Error.CommandFailed;
        },
        else => {
            alloc.free(res.stdout);
            return Error.CommandTerminatedAbnormally;
        },
    }
    return res.stdout;
}
