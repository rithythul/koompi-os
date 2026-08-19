const std = @import("std");
const toml = @import("toml.zig");

pub const Manifest = struct {
    koompi_repo: []const []const u8 = &.{},
    debian: []const []const u8 = &.{},
    flatpak: []const []const u8 = &.{},
};

pub const AccountModel = enum { @"sudo-user", @"separate-root" };

pub const Policy = struct {
    apt_backports: bool = false,
    vita_allow_distrobox_offer: bool = false,
    snapper_timeline_limit_daily: u32 = 10,
    account_model: AccountModel = .@"sudo-user",
};

pub const Edition = struct {
    arena: std.heap.ArenaAllocator,
    manifest: Manifest,
    policy: Policy,
    base_packages: []const []const u8,

    pub fn deinit(self: *Edition) void {
        self.arena.deinit();
    }
};

fn stringArray(table: ?toml.Table, key: []const u8) []const []const u8 {
    const t = table orelse return &.{};
    const v = t.get(key) orelse return &.{};
    return switch (v) {
        .string_array => |arr| arr,
        else => &.{},
    };
}

fn boolValue(table: ?toml.Table, key: []const u8, default: bool) bool {
    const t = table orelse return default;
    const v = t.get(key) orelse return default;
    return switch (v) {
        .boolean => |b| b,
        else => default,
    };
}

fn intValue(table: ?toml.Table, key: []const u8, default: u32) u32 {
    const t = table orelse return default;
    const v = t.get(key) orelse return default;
    return switch (v) {
        .integer => |n| if (n >= 0 and n <= std.math.maxInt(u32)) @intCast(n) else default,
        else => default,
    };
}

fn stringValue(table: ?toml.Table, key: []const u8, default: []const u8) []const u8 {
    const t = table orelse return default;
    const v = t.get(key) orelse return default;
    return switch (v) {
        .string => |s| s,
        else => default,
    };
}

fn accountModel(s: []const u8) !AccountModel {
    if (std.mem.eql(u8, s, "sudo-user")) return .@"sudo-user";
    if (std.mem.eql(u8, s, "separate-root")) return .@"separate-root";
    return error.UnknownAccountModel;
}

fn parseManifest(doc: toml.Doc) Manifest {
    return .{
        .koompi_repo = stringArray(doc.get("koompi-repo"), "packages"),
        .debian = stringArray(doc.get("debian"), "packages"),
        .flatpak = stringArray(doc.get("flatpak"), "packages"),
    };
}

fn parsePolicy(doc: toml.Doc) !Policy {
    return .{
        .apt_backports = boolValue(doc.get("apt"), "backports", false),
        .vita_allow_distrobox_offer = boolValue(doc.get("vita"), "allow_distrobox_offer", false),
        .snapper_timeline_limit_daily = intValue(doc.get("snapper"), "timeline_limit_daily", 10),
        .account_model = try accountModel(stringValue(doc.get("account"), "model", "sudo-user")),
    };
}

fn parsePackagesList(allocator: std.mem.Allocator, text: []const u8) ![]const []const u8 {
    var items = std.ArrayList([]const u8).init(allocator);
    errdefer items.deinit();
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;
        try items.append(line);
    }
    return items.toOwnedSlice();
}

fn readFileOrEmpty(allocator: std.mem.Allocator, path: []const u8) []const u8 {
    return std.fs.cwd().readFileAlloc(allocator, path, 4 * 1024 * 1024) catch "";
}

/// Missing `manifest.toml`/`policy.toml` (the four not-yet-populated
/// editions -- see docs/EDITIONS.md §3) fall back to defaults, matching
/// "any key not present falls back to a base default."
pub fn load(gpa: std.mem.Allocator, editions_root: []const u8, edition_name: []const u8, base_packages_path: []const u8) !Edition {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();

    const manifest_path = try std.fs.path.join(a, &.{ editions_root, edition_name, "manifest.toml" });
    const policy_path = try std.fs.path.join(a, &.{ editions_root, edition_name, "policy.toml" });

    const manifest_doc = try toml.parse(a, readFileOrEmpty(a, manifest_path));
    const policy_doc = try toml.parse(a, readFileOrEmpty(a, policy_path));
    const base_packages = try parsePackagesList(a, readFileOrEmpty(a, base_packages_path));

    return .{
        .arena = arena,
        .manifest = parseManifest(manifest_doc),
        .policy = try parsePolicy(policy_doc),
        .base_packages = base_packages,
    };
}

test "loads the real general edition from this repo" {
    var edition = try load(std.testing.allocator, "../editions", "general", "../base/packages.list");
    defer edition.deinit();

    try std.testing.expect(edition.manifest.koompi_repo.len > 0);
    try std.testing.expect(edition.manifest.debian.len > 0);
    try std.testing.expect(edition.manifest.flatpak.len > 0);

    var found_khmer_fonts = false;
    for (edition.manifest.koompi_repo) |pkg| {
        if (std.mem.eql(u8, pkg, "khmer-fonts")) found_khmer_fonts = true;
    }
    try std.testing.expect(found_khmer_fonts);

    try std.testing.expect(edition.policy.apt_backports);
    try std.testing.expectEqual(AccountModel.@"sudo-user", edition.policy.account_model);
    try std.testing.expectEqual(@as(u32, 10), edition.policy.snapper_timeline_limit_daily);

    try std.testing.expect(edition.base_packages.len > 0);
    var found_snapper = false;
    for (edition.base_packages) |pkg| {
        if (std.mem.eql(u8, pkg, "snapper")) found_snapper = true;
    }
    try std.testing.expect(found_snapper);
}

test "a stub edition with no manifest/policy files falls back to defaults" {
    var edition = try load(std.testing.allocator, "../editions", "dev", "../base/packages.list");
    defer edition.deinit();

    try std.testing.expectEqual(@as(usize, 0), edition.manifest.koompi_repo.len);
    try std.testing.expectEqual(AccountModel.@"sudo-user", edition.policy.account_model);
    try std.testing.expect(!edition.policy.apt_backports);
}

test "an unrecognized account.model is an error, not a silent sudo-user downgrade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const doc = try toml.parse(arena.allocator(), "[account]\nmodel = \"seperate-root\"\n");
    try std.testing.expectError(error.UnknownAccountModel, parsePolicy(doc));
}

test "an out-of-range policy.toml integer falls back to the default instead of panicking" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const doc = try toml.parse(arena.allocator(), "[snapper]\ntimeline_limit_daily = 99999999999\n");
    const policy = try parsePolicy(doc);
    try std.testing.expectEqual(@as(u32, 10), policy.snapper_timeline_limit_daily);
}
