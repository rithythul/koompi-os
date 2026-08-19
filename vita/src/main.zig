const std = @import("std");

pub const exec = @import("exec.zig");
pub const ledger = @import("ledger.zig");
pub const cli = @import("cli.zig");
pub const apt = @import("apt.zig");
pub const flatpak = @import("flatpak.zig");
pub const snapshot = @import("snapshot.zig");
pub const output = @import("output.zig");
pub const commands = @import("commands.zig");

fn exitCodeFor(err: anyerror) u8 {
    return switch (err) {
        error.MissingCommand, error.UnknownCommand, error.MissingArgument, error.InvalidArgument => 2,
        error.PackageNotFound => 3,
        error.ConfirmationRequired => 4,
        error.BackendFailed => 5,
        error.SnapshotFailed => 6,
        else => 1,
    };
}

fn errorMessage(allocator: std.mem.Allocator, err: anyerror) ![]const u8 {
    return switch (err) {
        error.MissingCommand => "missing command",
        error.UnknownCommand => "unknown command",
        error.MissingArgument => "missing required argument",
        error.InvalidArgument => "invalid argument",
        error.PackageNotFound => "package not found",
        error.ConfirmationRequired => "confirmation required: pass --allow-distrobox to install from distrobox",
        error.BackendFailed => "backend command failed",
        error.SnapshotFailed => "snapshot operation failed",
        else => try std.fmt.allocPrint(allocator, "unexpected error: {s}", .{@errorName(err)}),
    };
}

fn emitSuccess(json: bool, value: anytype, comptime human_fmt: []const u8, args: anytype) !void {
    if (json) {
        try output.writeJson(std.io.getStdOut().writer(), value);
    } else {
        try std.io.getStdOut().writer().print(human_fmt ++ "\n", args);
    }
}

fn emitFailure(json: bool, exit_code: u8, message: []const u8) void {
    if (json) {
        output.writeJson(std.io.getStdOut().writer(), output.ErrorResult{ .exit_code = exit_code, .@"error" = message }) catch {};
    } else {
        std.io.getStdErr().writer().print("vita: {s}\n", .{message}) catch {};
    }
}

pub fn main() !void {
    // Command orchestration deliberately doesn't free per-call subprocess
    // buffers -- this is a short-lived CLI process, so an arena (bulk-freed
    // once, no leak tracking) is the right allocator, not a checked GPA.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);

    const want_json = for (argv[1..]) |a| {
        if (std.mem.eql(u8, a, "--json")) break true;
    } else false;

    const parsed = cli.parse(allocator, argv[1..]) catch |err| {
        emitFailure(want_json, exitCodeFor(err), try errorMessage(allocator, err));
        std.process.exit(exitCodeFor(err));
    };

    const ctx = commands.Ctx{ .allocator = allocator };
    const json = parsed.flags.json;

    switch (parsed.command) {
        .install => |pkgs| {
            const result = commands.install(ctx, pkgs, parsed.flags) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "installed {d} package(s)", .{result.installed.len});
        },
        .remove => |pkgs| {
            const result = commands.remove(ctx, pkgs) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "removed {d} package(s)", .{result.removed.len});
        },
        .search => |query| {
            const result = commands.search(ctx, query) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "found {d} result(s)", .{result.results.len});
        },
        .update => {
            const result = commands.update(ctx) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "update complete: snapshot {d} -> {d}", .{ result.pre_snapshot, result.post_snapshot });
        },
        .rollback => |num| {
            const result = commands.rollback(ctx, num) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "rolled back to snapshot {d}; reboot required", .{result.rolled_back_to});
        },
        .info => |pkg| {
            const result = commands.info(ctx, pkg) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "{s}: installed={}", .{ result.package, result.installed });
        },
    }
}

test {
    std.testing.refAllDecls(@This());
}
