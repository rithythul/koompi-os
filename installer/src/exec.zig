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

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .Exited => |code| code,
        .Signal, .Stopped, .Unknown => 255,
    };
}

pub fn run(allocator: std.mem.Allocator, argv: []const []const u8) !Result {
    const res = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = argv,
        .max_output_bytes = 1024 * 1024,
    });
    return .{ .stdout = res.stdout, .stderr = res.stderr, .exit_code = exitCode(res.term) };
}

pub fn runInput(allocator: std.mem.Allocator, argv: []const []const u8, input: []const u8) !Result {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    try child.spawn();

    try child.stdin.?.writeAll(input);
    child.stdin.?.close();
    child.stdin = null;

    var stdout: std.ArrayListUnmanaged(u8) = .{};
    errdefer stdout.deinit(allocator);
    var stderr: std.ArrayListUnmanaged(u8) = .{};
    errdefer stderr.deinit(allocator);
    try child.collectOutput(allocator, &stdout, &stderr, 1024 * 1024);
    const term = try child.wait();

    return .{
        .stdout = try stdout.toOwnedSlice(allocator),
        .stderr = try stderr.toOwnedSlice(allocator),
        .exit_code = exitCode(term),
    };
}

fn expectOk(argv: []const []const u8, res: Result) error{CommandFailed}!Result {
    if (res.exit_code == 0) return res;
    const w = std.io.getStdErr().writer();
    w.print("\ncommand failed (exit {d}):", .{res.exit_code}) catch {};
    for (argv) |arg| w.print(" {s}", .{arg}) catch {};
    w.print("\n{s}\n", .{res.stderr}) catch {};
    return error.CommandFailed;
}

pub fn runExpectOk(allocator: std.mem.Allocator, argv: []const []const u8) !Result {
    return expectOk(argv, try run(allocator, argv));
}

pub fn runExpectOkInput(allocator: std.mem.Allocator, argv: []const []const u8, input: []const u8) !Result {
    return expectOk(argv, try runInput(allocator, argv, input));
}

test "runInput feeds stdin and captures what the command echoes back" {
    const allocator = std.testing.allocator;
    const res = try runInput(allocator, &.{"cat"}, "koompi:hunter2\n");
    defer res.deinit(allocator);
    try std.testing.expectEqualStrings("koompi:hunter2\n", res.stdout);
    try std.testing.expectEqual(@as(u8, 0), res.exit_code);
}

test "runExpectOk turns a nonzero exit into an error instead of a Result" {
    const allocator = std.testing.allocator;
    const res = runExpectOk(allocator, &.{ "sh", "-c", "exit 3" });
    try std.testing.expectError(error.CommandFailed, res);
}

test "runExpectOk passes a successful command through" {
    const allocator = std.testing.allocator;
    const res = try runExpectOk(allocator, &.{ "sh", "-c", "printf ok" });
    defer res.deinit(allocator);
    try std.testing.expectEqualStrings("ok", res.stdout);
}

test "run captures stdout and exit code" {
    const allocator = std.testing.allocator;
    var res = try run(allocator, &.{ "sh", "-c", "printf hello" });
    defer res.deinit(allocator);
    try std.testing.expectEqualStrings("hello", res.stdout);
    try std.testing.expectEqual(@as(u8, 0), res.exit_code);
}
