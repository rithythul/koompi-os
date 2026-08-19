const std = @import("std");
const cli = @import("cli.zig");
const ledger = @import("ledger.zig");
const exec = @import("exec.zig");
const apt = @import("apt.zig");
const flatpak = @import("flatpak.zig");
const snapshot = @import("snapshot.zig");
const output = @import("output.zig");

pub const default_ledger_path = "/var/lib/vita/state.json";
pub const default_grubenv_path = "/boot/grub/grubenv";

pub const Ctx = struct {
    allocator: std.mem.Allocator,
    env_map: ?*const std.process.EnvMap = null,
    ledger_path: []const u8 = default_ledger_path,
    grubenv_path: []const u8 = default_grubenv_path,
    // Zig 0.14.1's execvpeZ_expandArg0 resolves a bare argv[0] against the
    // calling process's real PATH, not env_map -- so tests point backend
    // commands at fake binaries by absolute path via this field instead.
    bin_dir: ?[]const u8 = null,
};

fn resolveArgv(ctx: Ctx, argv: []const []const u8) ![]const []const u8 {
    const bin_dir = ctx.bin_dir orelse return argv;
    const resolved = try ctx.allocator.dupe([]const u8, argv);
    resolved[0] = try std.fs.path.join(ctx.allocator, &.{ bin_dir, argv[0] });
    return resolved;
}

pub const RemoveSource = enum { ledger, dpkg, flatpak, not_found };

pub fn decideRemoveSource(entry: ?ledger.Entry, dpkg_installed: bool, flatpak_installed: bool) RemoveSource {
    if (entry != null) return .ledger;
    if (dpkg_installed) return .dpkg;
    if (flatpak_installed) return .flatpak;
    return .not_found;
}

pub const InstallTarget = struct { backend: ledger.Backend, version: []const u8 };

pub const InstallDecision = union(enum) {
    resolved: InstallTarget,
    distrobox_offer,
};

pub fn decideInstallSource(apt_resolution: ?apt.Resolution, flatpak_hit: ?flatpak.SearchResult) InstallDecision {
    if (apt_resolution) |r| return .{ .resolved = .{ .backend = r.backend, .version = r.candidate.version } };
    if (flatpak_hit) |f| return .{ .resolved = .{ .backend = .flatpak, .version = f.version } };
    return .distrobox_offer;
}

fn nowRfc3339(buf: []u8) ![]const u8 {
    const epoch_seconds: std.time.epoch.EpochSeconds = .{ .secs = @intCast(std.time.timestamp()) };
    const year_day = epoch_seconds.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const day_seconds = epoch_seconds.getDaySeconds();
    return std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        year_day.year,
        month_day.month.numeric(),
        month_day.day_index + 1,
        day_seconds.getHoursIntoDay(),
        day_seconds.getMinutesIntoHour(),
        day_seconds.getSecondsIntoMinute(),
    });
}

fn resolveApt(ctx: Ctx, pkg: []const u8) !?apt.Resolution {
    var diag: exec.Diagnostic = undefined;
    const res = exec.runExpectOkEnv(ctx.allocator, "apt-cache", &apt.policyArgv(pkg), &diag, ctx.env_map) catch return null;
    const candidates = try apt.parseAptCachePolicy(ctx.allocator, res.stdout);
    return apt.resolve(candidates);
}

fn searchFlatpakExact(ctx: Ctx, pkg: []const u8) !?flatpak.SearchResult {
    var diag: exec.Diagnostic = undefined;
    const res = exec.runExpectOkEnv(ctx.allocator, "flatpak", &flatpak.searchArgv(pkg), &diag, ctx.env_map) catch return null;
    const hits = try flatpak.parseSearch(ctx.allocator, res.stdout);
    for (hits) |h| {
        if (std.mem.eql(u8, h.app_id, pkg)) return h;
    }
    return null;
}

fn dpkgVersion(ctx: Ctx, pkg: []const u8) !?[]const u8 {
    var diag: exec.Diagnostic = undefined;
    const res = exec.runExpectOkEnv(ctx.allocator, "dpkg-query", &apt.dpkgQueryStatusArgv(pkg), &diag, ctx.env_map) catch return null;
    const dpkg_info = apt.parseDpkgQueryStatus(res.stdout);
    return if (dpkg_info.installed) dpkg_info.version else null;
}

fn flatpakVersion(ctx: Ctx, pkg: []const u8) !?[]const u8 {
    var diag: exec.Diagnostic = undefined;
    const res = exec.runExpectOkEnv(ctx.allocator, "flatpak", &flatpak.listArgv(), &diag, ctx.env_map) catch return null;
    const entries = try flatpak.parseList(ctx.allocator, res.stdout);
    if (flatpak.findInstalled(entries, pkg)) |e| return e.version;
    return null;
}

pub fn install(ctx: Ctx, pkgs: []const []const u8, flags: cli.Flags) !output.InstallResult {
    var installed = std.ArrayList(output.InstalledPkg).init(ctx.allocator);
    var state = try ledger.load(ctx.allocator, ctx.ledger_path);
    var diag: exec.Diagnostic = undefined;
    var ts_buf: [32]u8 = undefined;

    for (pkgs) |pkg| {
        const apt_res = try resolveApt(ctx, pkg);
        const flatpak_hit = if (apt_res == null) try searchFlatpakExact(ctx, pkg) else null;
        const decision = decideInstallSource(apt_res, flatpak_hit);

        const resolved: InstallTarget = switch (decision) {
            .resolved => |r| r,
            .distrobox_offer => blk: {
                if (!flags.allow_distrobox) return error.ConfirmationRequired;
                break :blk .{ .backend = .distrobox, .version = "unknown" };
            },
        };

        switch (resolved.backend) {
            .@"koompi-repo", .debian => {
                const install_argv = try apt.installArgv(ctx.allocator, &.{pkg});
                _ = try exec.runExpectOkEnv(ctx.allocator, "apt-get", install_argv, &diag, ctx.env_map);
            },
            .flatpak => {
                _ = try exec.runExpectOkEnv(ctx.allocator, "flatpak", &flatpak.installArgv(pkg), &diag, ctx.env_map);
            },
            .distrobox => {},
        }

        try state.put(pkg, .{
            .backend = resolved.backend,
            .version = resolved.version,
            .installed_at = try nowRfc3339(&ts_buf),
            .requested = true,
        });
        try installed.append(.{ .package = pkg, .backend = resolved.backend, .version = resolved.version });
    }

    try ledger.save(&state, ctx.allocator, ctx.ledger_path);
    return .{ .installed = try installed.toOwnedSlice() };
}

pub fn remove(ctx: Ctx, pkgs: []const []const u8) !output.RemoveResult {
    var removed = std.ArrayList([]const u8).init(ctx.allocator);
    var state = try ledger.load(ctx.allocator, ctx.ledger_path);
    var diag: exec.Diagnostic = undefined;

    for (pkgs) |pkg| {
        const entry = state.get(pkg);
        const dpkg_installed = entry == null and (try dpkgVersion(ctx, pkg)) != null;
        const flatpak_installed = entry == null and !dpkg_installed and (try flatpakVersion(ctx, pkg)) != null;

        switch (decideRemoveSource(entry, dpkg_installed, flatpak_installed)) {
            .ledger => {
                switch (entry.?.backend) {
                    .@"koompi-repo", .debian => _ = try exec.runExpectOkEnv(ctx.allocator, "apt-get", &apt.removeArgv(pkg), &diag, ctx.env_map),
                    .flatpak => _ = try exec.runExpectOkEnv(ctx.allocator, "flatpak", &flatpak.removeArgv(pkg), &diag, ctx.env_map),
                    .distrobox => {},
                }
                _ = state.remove(pkg);
            },
            .dpkg => _ = try exec.runExpectOkEnv(ctx.allocator, "apt-get", &apt.removeArgv(pkg), &diag, ctx.env_map),
            .flatpak => _ = try exec.runExpectOkEnv(ctx.allocator, "flatpak", &flatpak.removeArgv(pkg), &diag, ctx.env_map),
            .not_found => return error.PackageNotFound,
        }
        try removed.append(pkg);
    }

    try ledger.save(&state, ctx.allocator, ctx.ledger_path);
    return .{ .removed = try removed.toOwnedSlice() };
}

pub fn search(ctx: Ctx, query: []const u8) !output.SearchResult {
    var hits = std.ArrayList(output.SearchHit).init(ctx.allocator);
    var diag: exec.Diagnostic = undefined;

    apt_names: {
        const res = exec.runExpectOkEnv(ctx.allocator, "apt-cache", &apt.searchArgv(query), &diag, ctx.env_map) catch break :apt_names;
        const names = try apt.parseSearchNames(ctx.allocator, res.stdout);
        for (names) |name| {
            const resolved = (try resolveApt(ctx, name)) orelse continue;
            const installed = (try dpkgVersion(ctx, name)) != null;
            try hits.append(.{ .package = name, .backend = resolved.backend, .version = resolved.candidate.version, .installed = installed });
        }
    }

    flatpak_hits: {
        const res = exec.runExpectOkEnv(ctx.allocator, "flatpak", &flatpak.searchArgv(query), &diag, ctx.env_map) catch break :flatpak_hits;
        const results = try flatpak.parseSearch(ctx.allocator, res.stdout);
        const installed = try isFlatpakInstalledList(ctx, results);
        for (results, 0..) |r, i| {
            try hits.append(.{ .package = r.app_id, .backend = .flatpak, .version = r.version, .installed = installed[i] });
        }
    }

    return .{ .results = try hits.toOwnedSlice() };
}

fn isFlatpakInstalledList(ctx: Ctx, results: []const flatpak.SearchResult) ![]bool {
    var installed = try ctx.allocator.alloc(bool, results.len);
    var diag: exec.Diagnostic = undefined;
    const res = exec.runExpectOkEnv(ctx.allocator, "flatpak", &flatpak.listArgv(), &diag, ctx.env_map) catch {
        @memset(installed, false);
        return installed;
    };
    const entries = try flatpak.parseList(ctx.allocator, res.stdout);
    for (results, 0..) |r, i| installed[i] = flatpak.findInstalled(entries, r.app_id) != null;
    return installed;
}

pub fn update(ctx: Ctx) !output.UpdateResult {
    var diag: exec.Diagnostic = undefined;

    const pre_res = exec.runExpectOkEnv(ctx.allocator, "snapper", try resolveArgv(ctx, &snapshot.preCreateArgv("vita update")), &diag, ctx.env_map) catch |err| switch (err) {
        error.BackendFailed => return error.SnapshotFailed,
        else => return err,
    };
    const pre_number = try snapshot.parseSnapshotNumber(pre_res.stdout);
    const pre_str = try std.fmt.allocPrint(ctx.allocator, "{d}", .{pre_number});

    const pending_kv = try std.fmt.allocPrint(ctx.allocator, "koompi_pending_snapshot={s}", .{pre_str});
    _ = exec.runExpectOkEnv(ctx.allocator, "grub-editenv", try resolveArgv(ctx, &snapshot.grubEditenvSetArgv(ctx.grubenv_path, pending_kv)), &diag, ctx.env_map) catch |err| switch (err) {
        error.BackendFailed => return error.SnapshotFailed,
        else => return err,
    };
    _ = exec.runExpectOkEnv(ctx.allocator, "grub-editenv", try resolveArgv(ctx, &snapshot.grubEditenvSetArgv(ctx.grubenv_path, "koompi_boot_pending=1")), &diag, ctx.env_map) catch |err| switch (err) {
        error.BackendFailed => return error.SnapshotFailed,
        else => return err,
    };

    _ = try exec.runExpectOkEnv(ctx.allocator, "apt-get", try resolveArgv(ctx, &apt.updateIndexArgv()), &diag, ctx.env_map);
    const upgrade_res = try exec.runExpectOkEnv(ctx.allocator, "apt-get", try resolveArgv(ctx, &apt.fullUpgradeArgv()), &diag, ctx.env_map);
    const apt_upgraded = apt.parseUpgradedCount(upgrade_res.stdout);

    const flatpak_res = try exec.runExpectOkEnv(ctx.allocator, "flatpak", try resolveArgv(ctx, &flatpak.updateArgv()), &diag, ctx.env_map);
    const flatpak_upgraded = flatpak.parseUpdatedCount(flatpak_res.stdout);

    const post_res = exec.runExpectOkEnv(ctx.allocator, "snapper", try resolveArgv(ctx, &snapshot.postCreateArgv(pre_str, "vita update")), &diag, ctx.env_map) catch |err| switch (err) {
        error.BackendFailed => return error.SnapshotFailed,
        else => return err,
    };
    const post_number = try snapshot.parseSnapshotNumber(post_res.stdout);

    return .{
        .pre_snapshot = pre_number,
        .post_snapshot = post_number,
        .apt_upgraded = apt_upgraded,
        .flatpak_upgraded = flatpak_upgraded,
    };
}

pub fn rollback(ctx: Ctx, snapshot_num: ?u32) !output.RollbackResult {
    var diag: exec.Diagnostic = undefined;
    var num_buf: [16]u8 = undefined;
    var argv_buf: [3][]const u8 = undefined;
    const argv = try snapshot.rollbackArgv(snapshot_num, &num_buf, &argv_buf);

    const res = exec.runExpectOkEnv(ctx.allocator, "snapper", argv, &diag, ctx.env_map) catch |err| switch (err) {
        error.BackendFailed => return error.SnapshotFailed,
        else => return err,
    };

    const rolled_back_to = snapshot_num orelse (snapshot.parseFirstInteger(res.stdout) orelse 0);
    return .{ .rolled_back_to = rolled_back_to, .reboot_required = true };
}

pub fn info(ctx: Ctx, pkg: []const u8) !output.InfoResult {
    var state = try ledger.load(ctx.allocator, ctx.ledger_path);
    const entry = state.get(pkg);
    var diag: exec.Diagnostic = undefined;

    var available: output.AvailableVersions = .{};
    policy: {
        const res = exec.runExpectOkEnv(ctx.allocator, "apt-cache", &apt.policyArgv(pkg), &diag, ctx.env_map) catch break :policy;
        const candidates = try apt.parseAptCachePolicy(ctx.allocator, res.stdout);
        const best = apt.bestPerOrigin(candidates);
        if (best.koompi_repo) |k| available.@"koompi-repo" = k.version;
        if (best.debian) |d| available.debian = d.version;
    }
    flatpak_avail: {
        const hit = (try searchFlatpakExact(ctx, pkg)) orelse break :flatpak_avail;
        available.flatpak = hit.version;
    }

    var installed = entry != null;
    var backend: ?ledger.Backend = if (entry) |e| e.backend else null;
    var version: ?[]const u8 = if (entry) |e| e.version else null;

    if (entry == null) {
        if (try dpkgVersion(ctx, pkg)) |v| {
            installed = true;
            backend = .debian;
            version = v;
        } else if (try flatpakVersion(ctx, pkg)) |v| {
            installed = true;
            backend = .flatpak;
            version = v;
        }
    }

    const found_anywhere = installed or available.@"koompi-repo" != null or available.debian != null or available.flatpak != null;
    if (!found_anywhere) return error.PackageNotFound;

    return .{
        .package = pkg,
        .installed = installed,
        .backend = backend,
        .version = version,
        .available = available,
    };
}

fn writeFakeBin(dir: std.fs.Dir, name: []const u8, script: []const u8) !void {
    try dir.writeFile(.{ .sub_path = name, .data = script });
    var file = try dir.openFile(name, .{});
    defer file.close();
    try file.chmod(0o755);
}

const FakeUpdateFixture = struct {
    grubenv_path: []const u8,

    fn init(allocator: std.mem.Allocator, dir: std.fs.Dir, bin_dir: []const u8, apt_get_script: []const u8) !FakeUpdateFixture {
        try writeFakeBin(dir, "snapper", "#!/bin/sh\necho 99\n");
        try writeFakeBin(dir, "apt-get", apt_get_script);
        try writeFakeBin(dir, "flatpak", "#!/bin/sh\nexit 0\n");
        try dir.symLink("/usr/bin/grub-editenv", "grub-editenv", .{});

        const grubenv_path = try std.fs.path.join(allocator, &.{ bin_dir, "test.grubenv" });
        var create_res = try exec.run(allocator, &.{ try std.fs.path.join(allocator, &.{ bin_dir, "grub-editenv" }), grubenv_path, "create" });
        create_res.deinit(allocator);

        return .{ .grubenv_path = grubenv_path };
    }

    fn ctx(self: *const FakeUpdateFixture, allocator: std.mem.Allocator, bin_dir: []const u8) Ctx {
        return .{ .allocator = allocator, .grubenv_path = self.grubenv_path, .bin_dir = bin_dir };
    }
};

test "update leaves koompi_boot_pending set when apt full-upgrade fails" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const bin_dir = try tmp.dir.realpathAlloc(allocator, ".");

    const fixture = try FakeUpdateFixture.init(allocator, tmp.dir, bin_dir,
        \\#!/bin/sh
        \\if [ "$1" = "full-upgrade" ]; then echo boom >&2; exit 1; fi
        \\exit 0
        \\
    );

    const result = update(fixture.ctx(allocator, bin_dir));
    try std.testing.expectError(error.BackendFailed, result);

    const list_res = try exec.run(allocator, &.{ try std.fs.path.join(allocator, &.{ bin_dir, "grub-editenv" }), fixture.grubenv_path, "list" });
    const vars = try snapshot.parseGrubEditenvList(allocator, list_res.stdout);
    try std.testing.expectEqualStrings("1", vars.get("koompi_boot_pending").?);
    try std.testing.expectEqualStrings("99", vars.get("koompi_pending_snapshot").?);
}

test "update succeeds end-to-end against fake backends" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const bin_dir = try tmp.dir.realpathAlloc(allocator, ".");

    const fixture = try FakeUpdateFixture.init(allocator, tmp.dir, bin_dir,
        \\#!/bin/sh
        \\if [ "$1" = "full-upgrade" ]; then echo "3 upgraded, 0 newly installed, 0 to remove and 0 not upgraded."; fi
        \\exit 0
        \\
    );

    const result = try update(fixture.ctx(allocator, bin_dir));
    try std.testing.expectEqual(@as(u32, 99), result.pre_snapshot);
    try std.testing.expectEqual(@as(u32, 99), result.post_snapshot);
    try std.testing.expectEqual(@as(u32, 3), result.apt_upgraded);
}

test "decideInstallSource prefers apt over flatpak" {
    const candidate = apt.Candidate{ .version = "1.0-1", .priority = 500, .url = "http://deb.debian.org/debian" };
    const resolution = apt.Resolution{ .backend = .debian, .candidate = candidate };
    const flatpak_hit = flatpak.SearchResult{ .app_id = "org.gimp.GIMP", .version = "2.10", .name = "GIMP" };
    const decision = decideInstallSource(resolution, flatpak_hit);
    try std.testing.expectEqual(ledger.Backend.debian, decision.resolved.backend);
}

test "decideInstallSource falls back to flatpak when apt has no candidate" {
    const flatpak_hit = flatpak.SearchResult{ .app_id = "org.gimp.GIMP", .version = "2.10", .name = "GIMP" };
    const decision = decideInstallSource(null, flatpak_hit);
    try std.testing.expectEqual(ledger.Backend.flatpak, decision.resolved.backend);
}

test "decideInstallSource offers distrobox when nothing else resolves" {
    const decision = decideInstallSource(null, null);
    try std.testing.expectEqual(InstallDecision.distrobox_offer, decision);
}

test "decideRemoveSource prefers the ledger" {
    const entry = ledger.Entry{ .backend = .flatpak, .version = "1.0", .installed_at = "now", .requested = true };
    try std.testing.expectEqual(RemoveSource.ledger, decideRemoveSource(entry, true, true));
}

test "decideRemoveSource falls back to dpkg then flatpak then not-found" {
    try std.testing.expectEqual(RemoveSource.dpkg, decideRemoveSource(null, true, true));
    try std.testing.expectEqual(RemoveSource.flatpak, decideRemoveSource(null, false, true));
    try std.testing.expectEqual(RemoveSource.not_found, decideRemoveSource(null, false, false));
}
