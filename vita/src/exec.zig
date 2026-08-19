const std = @import("std");

pub const Result = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: u8,

    pub fn deinit(self: Result, allocator: std.mem.Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

pub const Diagnostic = struct {
    backend: []const u8 = "",
    argv: []const []const u8 = &.{},
    exit_code: u8 = 0,
    stderr: []const u8 = "",

    pub fn deinit(self: Diagnostic, allocator: std.mem.Allocator) void {
        allocator.free(self.stderr);
    }
};

pub const RunError = error{BackendFailed} || std.process.Child.RunError;

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .Exited => |code| code,
        .Signal, .Stopped, .Unknown => 255,
    };
}

pub fn run(allocator: std.mem.Allocator, argv: []const []const u8) !Result {
    return runEnv(allocator, argv, null);
}

pub fn runEnv(allocator: std.mem.Allocator, argv: []const []const u8, env_map: ?*const std.process.EnvMap) !Result {
    const res = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .env_map = env_map,
        .max_output_bytes = 1024 * 1024,
    });
    return .{ .stdout = res.stdout, .stderr = res.stderr, .exit_code = exitCode(res.term) };
}

pub fn runExpectOk(
    allocator: std.mem.Allocator,
    backend: []const u8,
    argv: []const []const u8,
    diag: *Diagnostic,
) RunError!Result {
    return runExpectOkEnv(allocator, backend, argv, diag, null);
}

pub fn runExpectOkEnv(
    allocator: std.mem.Allocator,
    backend: []const u8,
    argv: []const []const u8,
    diag: *Diagnostic,
    env_map: ?*const std.process.EnvMap,
) (error{BackendFailed} || std.mem.Allocator.Error)!Result {
    const res = runEnv(allocator, argv, env_map) catch |err| {
        diag.* = .{ .backend = backend, .argv = argv, .exit_code = 255, .stderr = try allocator.dupe(u8, @errorName(err)) };
        return error.BackendFailed;
    };
    if (res.exit_code != 0) {
        allocator.free(res.stdout);
        diag.* = .{ .backend = backend, .argv = argv, .exit_code = res.exit_code, .stderr = res.stderr };
        return error.BackendFailed;
    }
    return res;
}

test "run captures stdout and exit code" {
    const allocator = std.testing.allocator;
    var res = try run(allocator, &.{ "sh", "-c", "printf hello" });
    defer res.deinit(allocator);
    try std.testing.expectEqualStrings("hello", res.stdout);
    try std.testing.expectEqual(@as(u8, 0), res.exit_code);
}

test "runExpectOk surfaces backend failure" {
    const allocator = std.testing.allocator;
    var diag: Diagnostic = .{};
    const result = runExpectOk(allocator, "test-backend", &.{ "sh", "-c", "echo boom >&2; exit 7" }, &diag);
    try std.testing.expectError(error.BackendFailed, result);
    defer diag.deinit(allocator);
    try std.testing.expectEqualStrings("test-backend", diag.backend);
    try std.testing.expectEqual(@as(u8, 7), diag.exit_code);
    try std.testing.expectEqualStrings("boom\n", diag.stderr);
}
