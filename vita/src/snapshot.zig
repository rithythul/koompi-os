const std = @import("std");
const exec = @import("exec.zig");

pub fn preCreateArgv(description: []const u8) [9][]const u8 {
    return .{ "snapper", "-c", "root", "create", "--type", "pre", "--print-number", "--description", description };
}

pub fn postCreateArgv(pre_number_str: []const u8, description: []const u8) [11][]const u8 {
    return .{ "snapper", "-c", "root", "create", "--type", "post", "--pre-number", pre_number_str, "--print-number", "--description", description };
}

pub fn parseSnapshotNumber(text: []const u8) !u32 {
    const trimmed = std.mem.trim(u8, text, " \t\r\n");
    return std.fmt.parseInt(u32, trimmed, 10);
}

/// `snapper rollback` prints a backup-snapshot line before the
/// rollback-target line ("Setting default subvolume to snapshot N."), so
/// the target number is the *last* one in the output, not the first.
pub fn parseLastInteger(text: []const u8) ?u32 {
    var i: usize = 0;
    var result: ?u32 = null;
    while (i < text.len) : (i += 1) {
        if (!std.ascii.isDigit(text[i])) continue;
        var j = i;
        while (j < text.len and std.ascii.isDigit(text[j])) : (j += 1) {}
        if (std.fmt.parseInt(u32, text[i..j], 10)) |n| result = n else |_| {}
        i = j;
    }
    return result;
}

pub fn rollbackArgv(snapshot: ?u32, num_buf: []u8, argv_buf: *[3][]const u8) ![]const []const u8 {
    argv_buf[0] = "snapper";
    argv_buf[1] = "rollback";
    if (snapshot) |n| {
        argv_buf[2] = try std.fmt.bufPrint(num_buf, "{d}", .{n});
        return argv_buf[0..3];
    }
    return argv_buf[0..2];
}

pub fn grubEditenvSetArgv(env_path: []const u8, kv: []const u8) [4][]const u8 {
    return .{ "grub-editenv", env_path, "set", kv };
}

pub fn grubEditenvUnsetArgv(env_path: []const u8, key: []const u8) [4][]const u8 {
    return .{ "grub-editenv", env_path, "unset", key };
}

pub fn grubEditenvListArgv(env_path: []const u8) [3][]const u8 {
    return .{ "grub-editenv", env_path, "list" };
}

pub fn parseGrubEditenvList(allocator: std.mem.Allocator, text: []const u8) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(allocator);
    errdefer map.deinit();
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        try map.put(line[0..eq], line[eq + 1 ..]);
    }
    return map;
}

test "preCreateArgv matches the spec'd snapper invocation" {
    const argv = preCreateArgv("vita update");
    try std.testing.expectEqualSlices([]const u8, &.{
        "snapper", "-c", "root", "create", "--type", "pre", "--print-number", "--description", "vita update",
    }, &argv);
}

test "postCreateArgv threads the pre snapshot number through" {
    const argv = postCreateArgv("42", "vita update");
    try std.testing.expectEqualSlices([]const u8, &.{
        "snapper", "-c", "root", "create", "--type", "post", "--pre-number", "42", "--print-number", "--description", "vita update",
    }, &argv);
}

test "parseSnapshotNumber reads the printed integer" {
    try std.testing.expectEqual(@as(u32, 42), try parseSnapshotNumber("42\n"));
}

test "parseSnapshotNumber rejects non-numeric output" {
    try std.testing.expectError(error.InvalidCharacter, parseSnapshotNumber("not a number"));
}

test "parseLastInteger finds the only run of digits" {
    try std.testing.expectEqual(@as(?u32, 45), parseLastInteger("Creating read-only snapshot of default subvolume (Snapshot 45)."));
}

test "parseLastInteger returns null when there are no digits" {
    try std.testing.expectEqual(@as(?u32, null), parseLastInteger("no numbers here"));
}

test "parseLastInteger picks the rollback target, not the backup snapshot that precedes it" {
    const stdout =
        \\Creating read-only snapshot of current system. (Snapshot 34.)
        \\Creating read-write snapshot of snapshot 33. (Snapshot 35.)
        \\Setting default subvolume to snapshot 35.
        \\
    ;
    try std.testing.expectEqual(@as(?u32, 35), parseLastInteger(stdout));
}

test "grub-editenv set/unset/list round-trip against the real binary" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const env_path = try std.fs.path.join(allocator, &.{ dir_path, "test.grubenv" });
    defer allocator.free(env_path);

    var create_res = try exec.run(allocator, &.{ "grub-editenv", env_path, "create" });
    defer create_res.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 0), create_res.exit_code);

    var set_res = try exec.run(allocator, &grubEditenvSetArgv(env_path, "koompi_boot_pending=1"));
    defer set_res.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 0), set_res.exit_code);

    var list_res = try exec.run(allocator, &grubEditenvListArgv(env_path));
    defer list_res.deinit(allocator);
    var vars = try parseGrubEditenvList(allocator, list_res.stdout);
    defer vars.deinit();
    try std.testing.expectEqualStrings("1", vars.get("koompi_boot_pending").?);

    var unset_res = try exec.run(allocator, &grubEditenvUnsetArgv(env_path, "koompi_boot_pending"));
    defer unset_res.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 0), unset_res.exit_code);

    var list_res2 = try exec.run(allocator, &grubEditenvListArgv(env_path));
    defer list_res2.deinit(allocator);
    var vars2 = try parseGrubEditenvList(allocator, list_res2.stdout);
    defer vars2.deinit();
    try std.testing.expectEqual(@as(?[]const u8, null), vars2.get("koompi_boot_pending"));
}

fn expectArgvEqual(expected: []const []const u8, actual: []const []const u8) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |e, a| try std.testing.expectEqualStrings(e, a);
}

test "rollbackArgv includes the snapshot number when given" {
    var buf: [16]u8 = undefined;
    var argv_buf: [3][]const u8 = undefined;
    const argv = try rollbackArgv(42, &buf, &argv_buf);
    try expectArgvEqual(&.{ "snapper", "rollback", "42" }, argv);
}

test "rollbackArgv omits the number when absent" {
    var buf: [16]u8 = undefined;
    var argv_buf: [3][]const u8 = undefined;
    const argv = try rollbackArgv(null, &buf, &argv_buf);
    try expectArgvEqual(&.{ "snapper", "rollback" }, argv);
}
