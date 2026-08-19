const std = @import("std");
const ledger = @import("ledger.zig");

// TODO(koompi-repo): not decided anywhere in docs/ yet -- placeholder until
// the real koompi-repo hostname exists.
pub const koompi_repo_host = "repo.koompi.org";

pub const Candidate = struct {
    version: []const u8,
    priority: i32,
    url: []const u8,
};

pub fn classifyOrigin(url: []const u8) ledger.Backend {
    if (std.mem.indexOf(u8, url, koompi_repo_host) != null) return .@"koompi-repo";
    return .debian;
}

pub fn parseAptCachePolicy(allocator: std.mem.Allocator, text: []const u8) ![]Candidate {
    var candidates = std.ArrayList(Candidate).init(allocator);
    errdefer candidates.deinit();

    var pending_version: ?[]const u8 = null;
    var pending_priority: i32 = 0;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;

        var tok = std.mem.tokenizeScalar(u8, line, ' ');
        const first = tok.next() orelse continue;

        if (pending_version == null) {
            const second = tok.next() orelse continue;
            const priority = std.fmt.parseInt(i32, second, 10) catch continue;
            pending_version = first;
            pending_priority = priority;
        } else {
            _ = std.fmt.parseInt(i32, first, 10) catch continue;
            const url = tok.next() orelse continue;
            try candidates.append(.{ .version = pending_version.?, .priority = pending_priority, .url = url });
            pending_version = null;
        }
    }

    return candidates.toOwnedSlice();
}

pub const Resolution = struct { backend: ledger.Backend, candidate: Candidate };

pub const OriginBest = struct { koompi_repo: ?Candidate = null, debian: ?Candidate = null };

pub fn bestPerOrigin(candidates: []const Candidate) OriginBest {
    var result: OriginBest = .{};
    for (candidates) |c| {
        if (classifyOrigin(c.url) == .@"koompi-repo") {
            if (result.koompi_repo == null or c.priority > result.koompi_repo.?.priority) result.koompi_repo = c;
        } else {
            if (result.debian == null or c.priority > result.debian.?.priority) result.debian = c;
        }
    }
    return result;
}

pub fn resolve(candidates: []const Candidate) ?Resolution {
    const best = bestPerOrigin(candidates);
    if (best.koompi_repo) |k| return .{ .backend = .@"koompi-repo", .candidate = k };
    if (best.debian) |d| return .{ .backend = .debian, .candidate = d };
    return null;
}

pub fn parseUpgradedCount(text: []const u8) u32 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (std.mem.indexOf(u8, line, " upgraded,") == null) continue;
        var tok = std.mem.tokenizeScalar(u8, line, ' ');
        const first = tok.next() orelse continue;
        return std.fmt.parseInt(u32, first, 10) catch continue;
    }
    return 0;
}

pub const InstalledInfo = struct { installed: bool, version: ?[]const u8 };

pub fn parseDpkgQueryStatus(text: []const u8) InstalledInfo {
    var installed = false;
    var version: ?[]const u8 = null;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (std.mem.startsWith(u8, line, "Status:")) {
            installed = std.mem.indexOf(u8, line, "not-installed") == null and
                std.mem.indexOf(u8, line, "installed") != null;
        } else if (std.mem.startsWith(u8, line, "Version:")) {
            version = std.mem.trim(u8, line["Version:".len..], " \t");
        }
    }
    return .{ .installed = installed, .version = version };
}

pub fn searchArgv(query: []const u8) [3][]const u8 {
    return .{ "apt-cache", "search", query };
}

pub fn parseSearchNames(allocator: std.mem.Allocator, text: []const u8) ![][]const u8 {
    var names = std.ArrayList([]const u8).init(allocator);
    errdefer names.deinit();
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0) continue;
        const sep = std.mem.indexOf(u8, line, " - ") orelse continue;
        try names.append(line[0..sep]);
    }
    return names.toOwnedSlice();
}

pub fn policyArgv(pkg: []const u8) [3][]const u8 {
    return .{ "apt-cache", "policy", pkg };
}

pub fn dpkgQueryStatusArgv(pkg: []const u8) [3][]const u8 {
    return .{ "dpkg-query", "-s", pkg };
}

pub fn updateIndexArgv() [2][]const u8 {
    return .{ "apt-get", "update" };
}

pub fn fullUpgradeArgv() [3][]const u8 {
    return .{ "apt-get", "full-upgrade", "-y" };
}

pub fn installArgv(allocator: std.mem.Allocator, pkgs: []const []const u8) ![][]const u8 {
    var argv = try allocator.alloc([]const u8, pkgs.len + 3);
    argv[0] = "apt-get";
    argv[1] = "install";
    argv[2] = "-y";
    for (pkgs, 0..) |pkg, i| argv[3 + i] = pkg;
    return argv;
}

pub fn removeArgv(pkg: []const u8) [4][]const u8 {
    return .{ "apt-get", "remove", "-y", pkg };
}

test "parseAptCachePolicy extracts each source's version, priority, and url" {
    const allocator = std.testing.allocator;
    const fixture =
        \\vita:
        \\  Installed: (none)
        \\  Candidate: 1.2-1
        \\  Version table:
        \\     1.2-1 500
        \\        500 https://repo.koompi.org/debian trixie/main amd64 Packages
        \\     1.1-1 500
        \\        500 http://deb.debian.org/debian trixie/main amd64 Packages
        \\
    ;
    const candidates = try parseAptCachePolicy(allocator, fixture);
    defer allocator.free(candidates);

    try std.testing.expectEqual(@as(usize, 2), candidates.len);
    try std.testing.expectEqualStrings("1.2-1", candidates[0].version);
    try std.testing.expectEqual(@as(i32, 500), candidates[0].priority);
    try std.testing.expectEqualStrings("https://repo.koompi.org/debian", candidates[0].url);
    try std.testing.expectEqualStrings("1.1-1", candidates[1].version);
}

test "resolve prefers koompi-repo regardless of listed order" {
    const candidates = [_]Candidate{
        .{ .version = "1.1-1", .priority = 900, .url = "http://deb.debian.org/debian" },
        .{ .version = "1.0-1", .priority = 500, .url = "https://repo.koompi.org/debian" },
    };
    const picked = resolve(&candidates).?;
    try std.testing.expectEqual(ledger.Backend.@"koompi-repo", picked.backend);
    try std.testing.expectEqualStrings("1.0-1", picked.candidate.version);
}

test "resolve falls back to the highest-priority Debian candidate" {
    const candidates = [_]Candidate{
        .{ .version = "1.0-1", .priority = 500, .url = "http://deb.debian.org/debian" },
        .{ .version = "1.1-1", .priority = 900, .url = "http://deb.debian.org/debian-security" },
    };
    const picked = resolve(&candidates).?;
    try std.testing.expectEqual(ledger.Backend.debian, picked.backend);
    try std.testing.expectEqualStrings("1.1-1", picked.candidate.version);
}

test "resolve on no candidates returns null" {
    try std.testing.expectEqual(@as(?Resolution, null), resolve(&.{}));
}

test "parseDpkgQueryStatus reads installed version" {
    const fixture =
        \\Package: vita
        \\Status: install ok installed
        \\Version: 0.1.0-1
        \\
    ;
    const info = parseDpkgQueryStatus(fixture);
    try std.testing.expect(info.installed);
    try std.testing.expectEqualStrings("0.1.0-1", info.version.?);
}

test "parseDpkgQueryStatus reports not installed" {
    const fixture =
        \\Package: vita
        \\Status: deinstall ok config-files
        \\
    ;
    const info = parseDpkgQueryStatus(fixture);
    try std.testing.expect(!info.installed);
}

test "parseSearchNames extracts the package name before the dash" {
    const allocator = std.testing.allocator;
    const fixture = "vita - unified package interface\nkoompi-install - installer\n";
    const names = try parseSearchNames(allocator, fixture);
    defer allocator.free(names);
    try std.testing.expectEqual(@as(usize, 2), names.len);
    try std.testing.expectEqualStrings("vita", names[0]);
    try std.testing.expectEqualStrings("koompi-install", names[1]);
}

test "parseUpgradedCount reads the transaction summary line" {
    const fixture = "Reading package lists...\n12 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.\n";
    try std.testing.expectEqual(@as(u32, 12), parseUpgradedCount(fixture));
}

test "parseUpgradedCount defaults to zero when no summary line is found" {
    try std.testing.expectEqual(@as(u32, 0), parseUpgradedCount("nothing here"));
}

test "installArgv places every package after the flags" {
    const allocator = std.testing.allocator;
    const argv = try installArgv(allocator, &.{ "khmer-fonts", "gimp" });
    defer allocator.free(argv);
    try std.testing.expectEqualSlices([]const u8, &.{ "apt-get", "install", "-y", "khmer-fonts", "gimp" }, argv);
}
