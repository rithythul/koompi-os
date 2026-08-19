const std = @import("std");
const exec = @import("exec.zig");

pub const ListEntry = struct { app_id: []const u8, version: []const u8 };
pub const SearchResult = struct { app_id: []const u8, version: []const u8, name: []const u8 };

pub fn listArgv() [3][]const u8 {
    return .{ "flatpak", "list", "--columns=application,version" };
}

pub fn searchArgv(query: []const u8) [4][]const u8 {
    return .{ "flatpak", "search", "--columns=application,version,name", query };
}

pub fn installArgv(app_id: []const u8) [5][]const u8 {
    return .{ "flatpak", "install", "-y", "flathub", app_id };
}

pub fn removeArgv(app_id: []const u8) [4][]const u8 {
    return .{ "flatpak", "uninstall", "-y", app_id };
}

pub fn updateArgv() [3][]const u8 {
    return .{ "flatpak", "update", "-y" };
}

pub fn parseList(allocator: std.mem.Allocator, text: []const u8) ![]ListEntry {
    var out = std.ArrayList(ListEntry).init(allocator);
    errdefer out.deinit();
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const app_id = fields.next() orelse continue;
        const version = fields.next() orelse "";
        try out.append(.{ .app_id = app_id, .version = version });
    }
    return out.toOwnedSlice();
}

pub fn parseSearch(allocator: std.mem.Allocator, text: []const u8) ![]SearchResult {
    var out = std.ArrayList(SearchResult).init(allocator);
    errdefer out.deinit();
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or std.mem.eql(u8, line, "No matches found")) continue;
        var fields = std.mem.splitScalar(u8, line, '\t');
        const app_id = fields.next() orelse continue;
        const version = fields.next() orelse "";
        const name = fields.next() orelse "";
        try out.append(.{ .app_id = app_id, .version = version, .name = name });
    }
    return out.toOwnedSlice();
}

pub fn parseUpdatedCount(text: []const u8) u32 {
    var count: u32 = 0;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        const dot = std.mem.indexOfScalar(u8, line, '.') orelse continue;
        _ = std.fmt.parseInt(u32, line[0..dot], 10) catch continue;
        count += 1;
    }
    return count;
}

pub fn findInstalled(entries: []const ListEntry, app_id: []const u8) ?ListEntry {
    for (entries) |e| {
        if (std.mem.eql(u8, e.app_id, app_id)) return e;
    }
    return null;
}

test "parseList reads tab-separated application/version pairs" {
    const allocator = std.testing.allocator;
    const fixture = "org.gimp.GIMP\t2.10.36\norg.videolan.VLC\t3.0.20\n";
    const entries = try parseList(allocator, fixture);
    defer allocator.free(entries);
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("org.gimp.GIMP", entries[0].app_id);
    try std.testing.expectEqualStrings("2.10.36", entries[0].version);
}

test "parseSearch skips the no-matches sentinel line" {
    const allocator = std.testing.allocator;
    const fixture = "No matches found\n";
    const results = try parseSearch(allocator, fixture);
    defer allocator.free(results);
    try std.testing.expectEqual(@as(usize, 0), results.len);
}

test "parseUpdatedCount counts numbered transaction lines" {
    const fixture = "Looking for updates...\n\n1. [-] org.gimp.GIMP           3.2.4 -> 3.2.5     Flathub\n2. [-] org.videolan.VLC        3.0.20 -> 3.0.21   Flathub\n\nUpdates complete.\n";
    try std.testing.expectEqual(@as(u32, 2), parseUpdatedCount(fixture));
}

test "findInstalled matches by application id" {
    const entries = [_]ListEntry{.{ .app_id = "org.gimp.GIMP", .version = "2.10.36" }};
    try std.testing.expect(findInstalled(&entries, "org.gimp.GIMP") != null);
    try std.testing.expect(findInstalled(&entries, "org.videolan.VLC") == null);
}

test "installArgv and removeArgv shell out to the real flatpak binary" {
    const allocator = std.testing.allocator;
    var install_res = try exec.run(allocator, &installArgv("org.this.does.not.exist"));
    defer install_res.deinit(allocator);
    try std.testing.expect(install_res.exit_code != 0);

    var version_res = try exec.run(allocator, &.{ "flatpak", "--version" });
    defer version_res.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 0), version_res.exit_code);
    try std.testing.expect(std.mem.startsWith(u8, version_res.stdout, "Flatpak"));
}

test "parseList against the real flatpak list output on this host" {
    const allocator = std.testing.allocator;
    var res = try exec.run(allocator, &listArgv());
    defer res.deinit(allocator);
    try std.testing.expectEqual(@as(u8, 0), res.exit_code);
    const entries = try parseList(allocator, res.stdout);
    defer allocator.free(entries);
    for (entries) |e| {
        try std.testing.expect(e.app_id.len > 0);
    }
}
