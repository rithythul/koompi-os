const std = @import("std");
const ledger = @import("ledger.zig");

pub const InstalledPkg = struct { package: []const u8, backend: ledger.Backend, version: []const u8 };
pub const InstallResult = struct {
    ok: bool = true,
    exit_code: u8 = 0,
    installed: []const InstalledPkg,
};

pub const RemoveResult = struct {
    ok: bool = true,
    exit_code: u8 = 0,
    removed: []const []const u8,
};

pub const SearchHit = struct { package: []const u8, backend: ledger.Backend, version: []const u8, installed: bool };
pub const SearchResult = struct {
    ok: bool = true,
    exit_code: u8 = 0,
    results: []const SearchHit,
};

pub const UpdateResult = struct {
    ok: bool = true,
    exit_code: u8 = 0,
    pre_snapshot: u32,
    post_snapshot: u32,
    apt_upgraded: u32,
    flatpak_upgraded: u32,
};

pub const RollbackResult = struct {
    ok: bool = true,
    exit_code: u8 = 0,
    rolled_back_to: u32,
    reboot_required: bool,
};

pub const AvailableVersions = struct {
    @"koompi-repo": ?[]const u8 = null,
    debian: ?[]const u8 = null,
    flatpak: ?[]const u8 = null,
};

pub const InfoResult = struct {
    ok: bool = true,
    exit_code: u8 = 0,
    package: []const u8,
    installed: bool,
    backend: ?ledger.Backend,
    version: ?[]const u8,
    available: AvailableVersions,
};

pub const ErrorResult = struct {
    ok: bool = false,
    exit_code: u8,
    @"error": []const u8,
};

pub fn writeJson(writer: anytype, value: anytype) !void {
    try std.json.stringify(value, .{}, writer);
    try writer.writeByte('\n');
}

test "install shape matches the spec example" {
    const allocator = std.testing.allocator;
    const result = InstallResult{ .installed = &.{
        .{ .package = "khmer-fonts", .backend = .@"koompi-repo", .version = "1.2-1" },
    } };
    const s = try std.json.stringifyAlloc(allocator, result, .{});
    defer allocator.free(s);
    try std.testing.expectEqualStrings(
        "{\"ok\":true,\"exit_code\":0,\"installed\":[{\"package\":\"khmer-fonts\",\"backend\":\"koompi-repo\",\"version\":\"1.2-1\"}]}",
        s,
    );
}

test "info shape renders null availability per backend" {
    const allocator = std.testing.allocator;
    const result = InfoResult{
        .package = "vita",
        .installed = true,
        .backend = .@"koompi-repo",
        .version = "0.1.0-1",
        .available = .{ .@"koompi-repo" = "0.1.0-1" },
    };
    const s = try std.json.stringifyAlloc(allocator, result, .{});
    defer allocator.free(s);
    try std.testing.expectEqualStrings(
        "{\"ok\":true,\"exit_code\":0,\"package\":\"vita\",\"installed\":true,\"backend\":\"koompi-repo\",\"version\":\"0.1.0-1\",\"available\":{\"koompi-repo\":\"0.1.0-1\",\"debian\":null,\"flatpak\":null}}",
        s,
    );
}

test "error shape" {
    const allocator = std.testing.allocator;
    const result = ErrorResult{ .exit_code = 3, .@"error" = "package not found: foo" };
    const s = try std.json.stringifyAlloc(allocator, result, .{});
    defer allocator.free(s);
    try std.testing.expectEqualStrings(
        "{\"ok\":false,\"exit_code\":3,\"error\":\"package not found: foo\"}",
        s,
    );
}
