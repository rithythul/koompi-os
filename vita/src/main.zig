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

/// VITA_SPEC §7: exit 5 and 6 must name the failing backend and its exit
/// status, in --json output and on stderr alike.
fn backendMessage(allocator: std.mem.Allocator, what: []const u8, diag: exec.Diagnostic) ![]const u8 {
    if (diag.backend.len == 0) return what;
    const detail = std.mem.trim(u8, diag.stderr, " \t\r\n");
    if (detail.len == 0) {
        return std.fmt.allocPrint(allocator, "{s}: {s} exited {d}", .{ what, diag.backend, diag.exit_code });
    }
    return std.fmt.allocPrint(allocator, "{s}: {s} exited {d}: {s}", .{ what, diag.backend, diag.exit_code, detail });
}

fn errorMessage(allocator: std.mem.Allocator, err: anyerror, diag: exec.Diagnostic) ![]const u8 {
    return switch (err) {
        error.MissingCommand => "missing command",
        error.UnknownCommand => "unknown command",
        error.MissingArgument => "missing required argument",
        error.InvalidArgument => "invalid argument",
        error.PackageNotFound => "package not found",
        error.ConfirmationRequired => "confirmation required: pass --allow-distrobox to install from distrobox",
        error.BackendFailed => try backendMessage(allocator, "backend command failed", diag),
        error.SnapshotFailed => try backendMessage(allocator, "snapshot operation failed", diag),
        else => try std.fmt.allocPrint(allocator, "unexpected error: {s}", .{@errorName(err)}),
    };
}

fn confirmStdin(question: []const u8) bool {
    const err_writer = std.io.getStdErr().writer();
    err_writer.print("{s} [y/N] ", .{question}) catch return false;
    var buf: [16]u8 = undefined;
    const line = std.io.getStdIn().reader().readUntilDelimiterOrEof(&buf, '\n') catch return false;
    const answer = std.mem.trim(u8, line orelse return false, " \t\r");
    return answer.len == 1 and (answer[0] == 'y' or answer[0] == 'Y');
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

    var diag: exec.Diagnostic = .{};

    const parsed = cli.parse(allocator, argv[1..]) catch |err| {
        emitFailure(want_json, exitCodeFor(err), try errorMessage(allocator, err, diag));
        std.process.exit(exitCodeFor(err));
    };

    const ctx = commands.Ctx{
        .allocator = allocator,
        .diag = &diag,
        .confirm = if (parsed.flags.yes) null else confirmStdin,
    };
    const json = parsed.flags.json;

    switch (parsed.command) {
        .install => |pkgs| {
            const result = commands.install(ctx, pkgs, parsed.flags) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err, diag));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "installed {d} package(s)", .{result.installed.len});
        },
        .remove => |pkgs| {
            const result = commands.remove(ctx, pkgs) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err, diag));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "removed {d} package(s)", .{result.removed.len});
        },
        .search => |query| {
            const result = commands.search(ctx, query) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err, diag));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "found {d} result(s)", .{result.results.len});
        },
        .update => {
            const result = commands.update(ctx) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err, diag));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "update complete: snapshot {d} -> {d}", .{ result.pre_snapshot, result.post_snapshot });
        },
        .rollback => |num| {
            const result = commands.rollback(ctx, num) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err, diag));
                std.process.exit(exitCodeFor(err));
            };
            const err_writer = std.io.getStdErr().writer();
            try err_writer.print("{s}\n", .{commands.rollback_limitation_notice});
            const confirmed = !parsed.flags.yes and confirmStdin("Reboot now to boot the rolled-back snapshot?");
            try err_writer.print("{s}\n", .{commands.rebootMessage(parsed.flags.yes, confirmed)});
            try emitSuccess(json, result, "rolled back to snapshot {d}", .{result.rolled_back_to});
        },
        .info => |pkg| {
            const result = commands.info(ctx, pkg) catch |err| {
                emitFailure(json, exitCodeFor(err), try errorMessage(allocator, err, diag));
                std.process.exit(exitCodeFor(err));
            };
            try emitSuccess(json, result, "{s}: installed={}", .{ result.package, result.installed });
        },
    }
}

test "backend failures name the backend and its exit status" {
    const allocator = std.testing.allocator;
    const diag = exec.Diagnostic{ .backend = "apt-get", .exit_code = 100, .stderr = "E: broken packages\n" };
    const message = try errorMessage(allocator, error.BackendFailed, diag);
    defer allocator.free(message);
    try std.testing.expectEqualStrings("backend command failed: apt-get exited 100: E: broken packages", message);
}

test "a failure with no diagnostic still yields a plain message" {
    const allocator = std.testing.allocator;
    const message = try errorMessage(allocator, error.BackendFailed, .{});
    try std.testing.expectEqualStrings("backend command failed", message);
}

test "snapshot failures carry the snapper exit status" {
    const allocator = std.testing.allocator;
    const diag = exec.Diagnostic{ .backend = "snapper", .exit_code = 1, .stderr = "" };
    const message = try errorMessage(allocator, error.SnapshotFailed, diag);
    defer allocator.free(message);
    try std.testing.expectEqualStrings("snapshot operation failed: snapper exited 1", message);
}

test {
    std.testing.refAllDecls(@This());
}
