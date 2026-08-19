const std = @import("std");

pub const Command = union(enum) {
    install: []const []const u8,
    remove: []const []const u8,
    search: []const u8,
    update,
    rollback: ?u32,
    info: []const u8,
};

pub const Flags = struct {
    yes: bool = false,
    json: bool = false,
    allow_distrobox: bool = false,
};

pub const Parsed = struct {
    command: Command,
    flags: Flags,
};

pub const ParseError = error{
    MissingCommand,
    UnknownCommand,
    MissingArgument,
    InvalidArgument,
} || std.mem.Allocator.Error;

pub fn parse(allocator: std.mem.Allocator, argv: []const []const u8) ParseError!Parsed {
    var positional = std.ArrayList([]const u8).init(allocator);
    defer positional.deinit();
    var flags: Flags = .{};

    for (argv) |arg| {
        if (std.mem.eql(u8, arg, "--yes")) {
            flags.yes = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            flags.json = true;
        } else if (std.mem.eql(u8, arg, "--allow-distrobox")) {
            flags.allow_distrobox = true;
        } else {
            try positional.append(arg);
        }
    }

    if (positional.items.len == 0) return error.MissingCommand;
    const name = positional.items[0];
    const rest = positional.items[1..];

    const command: Command = if (std.mem.eql(u8, name, "install")) cmd: {
        if (rest.len == 0) return error.MissingArgument;
        break :cmd .{ .install = try allocator.dupe([]const u8, rest) };
    } else if (std.mem.eql(u8, name, "remove")) cmd: {
        if (rest.len == 0) return error.MissingArgument;
        break :cmd .{ .remove = try allocator.dupe([]const u8, rest) };
    } else if (std.mem.eql(u8, name, "search")) cmd: {
        if (rest.len != 1) return error.MissingArgument;
        break :cmd .{ .search = rest[0] };
    } else if (std.mem.eql(u8, name, "update")) cmd: {
        if (rest.len != 0) return error.InvalidArgument;
        break :cmd .update;
    } else if (std.mem.eql(u8, name, "rollback")) cmd: {
        if (rest.len > 1) return error.InvalidArgument;
        const n: ?u32 = if (rest.len == 1)
            std.fmt.parseInt(u32, rest[0], 10) catch return error.InvalidArgument
        else
            null;
        break :cmd .{ .rollback = n };
    } else if (std.mem.eql(u8, name, "info")) cmd: {
        if (rest.len != 1) return error.MissingArgument;
        break :cmd .{ .info = rest[0] };
    } else {
        return error.UnknownCommand;
    };

    return .{ .command = command, .flags = flags };
}

test "install collects package list" {
    const allocator = std.testing.allocator;
    const parsed = try parse(allocator, &.{ "install", "khmer-fonts", "gimp" });
    defer allocator.free(parsed.command.install);
    try std.testing.expectEqual(@as(usize, 2), parsed.command.install.len);
    try std.testing.expectEqualStrings("khmer-fonts", parsed.command.install[0]);
}

test "flags parse anywhere in argv" {
    const allocator = std.testing.allocator;
    const parsed = try parse(allocator, &.{ "--yes", "install", "vim", "--json" });
    defer allocator.free(parsed.command.install);
    try std.testing.expect(parsed.flags.yes);
    try std.testing.expect(parsed.flags.json);
    try std.testing.expectEqual(@as(usize, 1), parsed.command.install.len);
}

test "rollback accepts an optional snapshot number" {
    const allocator = std.testing.allocator;
    const none = try parse(allocator, &.{"rollback"});
    try std.testing.expectEqual(@as(?u32, null), none.command.rollback);

    const with_num = try parse(allocator, &.{ "rollback", "42" });
    try std.testing.expectEqual(@as(?u32, 42), with_num.command.rollback);
}

test "rollback rejects a non-numeric snapshot argument" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidArgument, parse(allocator, &.{ "rollback", "abc" }));
}

test "update takes no arguments" {
    const allocator = std.testing.allocator;
    _ = try parse(allocator, &.{"update"});
    try std.testing.expectError(error.InvalidArgument, parse(allocator, &.{ "update", "extra" }));
}

test "install without packages is a missing argument" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.MissingArgument, parse(allocator, &.{"install"}));
}

test "empty argv is a missing command" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.MissingCommand, parse(allocator, &.{}));
}

test "unrecognized command name" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.UnknownCommand, parse(allocator, &.{"frobnicate"}));
}

test "allow-distrobox flag" {
    const allocator = std.testing.allocator;
    const parsed = try parse(allocator, &.{ "install", "--allow-distrobox", "some-pkg" });
    defer allocator.free(parsed.command.install);
    try std.testing.expect(parsed.flags.allow_distrobox);
}
