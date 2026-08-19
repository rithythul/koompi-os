const std = @import("std");

pub const Backend = enum {
    @"koompi-repo",
    debian,
    flatpak,
    distrobox,
};

pub const Entry = struct {
    backend: Backend,
    version: []const u8,
    installed_at: []const u8,
    requested: bool,
};

pub const Data = struct {
    version: u32 = 1,
    packages: std.json.ArrayHashMap(Entry) = .{},
};

pub const Ledger = struct {
    arena: std.heap.ArenaAllocator,
    data: Data,

    pub fn deinit(self: *Ledger) void {
        self.arena.deinit();
    }

    pub fn get(self: *const Ledger, name: []const u8) ?Entry {
        return self.data.packages.map.get(name);
    }

    pub fn put(self: *Ledger, name: []const u8, entry: Entry) !void {
        const a = self.arena.allocator();
        try self.data.packages.map.put(a, try a.dupe(u8, name), .{
            .backend = entry.backend,
            .version = try a.dupe(u8, entry.version),
            .installed_at = try a.dupe(u8, entry.installed_at),
            .requested = entry.requested,
        });
    }

    pub fn remove(self: *Ledger, name: []const u8) bool {
        return self.data.packages.map.swapRemove(name);
    }
};

fn empty(gpa: std.mem.Allocator) Ledger {
    return .{ .arena = std.heap.ArenaAllocator.init(gpa), .data = .{} };
}

pub fn load(gpa: std.mem.Allocator, path: []const u8) !Ledger {
    var arena = std.heap.ArenaAllocator.init(gpa);
    errdefer arena.deinit();
    const a = arena.allocator();

    const bytes = std.fs.cwd().readFileAlloc(a, path, 16 * 1024 * 1024) catch |err| switch (err) {
        error.FileNotFound => return .{ .arena = arena, .data = .{} },
        else => return err,
    };

    const data = std.json.parseFromSliceLeaky(Data, a, bytes, .{}) catch {
        return .{ .arena = arena, .data = .{} };
    };
    return .{ .arena = arena, .data = data };
}

pub fn save(self: *const Ledger, gpa: std.mem.Allocator, path: []const u8) !void {
    const tmp_path = try std.fmt.allocPrint(gpa, "{s}.tmp", .{path});
    defer gpa.free(tmp_path);

    if (std.fs.path.dirname(path)) |dir| {
        std.fs.cwd().makePath(dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    {
        const file = try std.fs.cwd().createFile(tmp_path, .{ .truncate = true });
        defer file.close();
        var buffered = std.io.bufferedWriter(file.writer());
        try std.json.stringify(self.data, .{ .whitespace = .indent_2 }, buffered.writer());
        try buffered.flush();
        try file.sync();
    }
    try std.fs.cwd().rename(tmp_path, path);
}

test "load missing ledger returns empty, not an error" {
    var ledger = try load(std.testing.allocator, "/nonexistent/does-not-exist/state.json");
    defer ledger.deinit();
    try std.testing.expectEqual(@as(u32, 1), ledger.data.version);
    try std.testing.expectEqual(@as(usize, 0), ledger.data.packages.map.count());
}

test "load corrupt ledger returns empty, not an error" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(.{ .sub_path = "state.json", .data = "not json{{{" });
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, "state.json");
    defer std.testing.allocator.free(path);

    var ledger = try load(std.testing.allocator, path);
    defer ledger.deinit();
    try std.testing.expectEqual(@as(usize, 0), ledger.data.packages.map.count());
}

test "save then load round-trips an entry" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);
    const state_path = try std.fs.path.join(std.testing.allocator, &.{ path, "state.json" });
    defer std.testing.allocator.free(state_path);

    var ledger = empty(std.testing.allocator);
    defer ledger.deinit();
    try ledger.put("khmer-fonts", .{
        .backend = .@"koompi-repo",
        .version = "1.2-1",
        .installed_at = "2026-08-19T12:00:00Z",
        .requested = true,
    });
    try save(&ledger, std.testing.allocator, state_path);

    var reloaded = try load(std.testing.allocator, state_path);
    defer reloaded.deinit();
    const entry = reloaded.get("khmer-fonts").?;
    try std.testing.expectEqual(Backend.@"koompi-repo", entry.backend);
    try std.testing.expectEqualStrings("1.2-1", entry.version);
    try std.testing.expect(entry.requested);
}

test "save is atomic: a crash before rename leaves the real path untouched" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir_path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(dir_path);
    const state_path = try std.fs.path.join(std.testing.allocator, &.{ dir_path, "state.json" });
    defer std.testing.allocator.free(state_path);

    var ledger = empty(std.testing.allocator);
    defer ledger.deinit();
    try ledger.put("vita", .{ .backend = .@"koompi-repo", .version = "0.1.0-1", .installed_at = "2026-08-19T12:00:00Z", .requested = true });
    try save(&ledger, std.testing.allocator, state_path);

    const tmp_path = try std.fmt.allocPrint(std.testing.allocator, "{s}.tmp", .{state_path});
    defer std.testing.allocator.free(tmp_path);
    try tmp.dir.writeFile(.{ .sub_path = "state.json.tmp", .data = "truncated garbage" });

    var reloaded = try load(std.testing.allocator, state_path);
    defer reloaded.deinit();
    try std.testing.expect(reloaded.get("vita") != null);
}

test "backend enum matches spec strings" {
    const allocator = std.testing.allocator;
    const s = try std.json.stringifyAlloc(allocator, Backend.@"koompi-repo", .{});
    defer allocator.free(s);
    try std.testing.expectEqualStrings("\"koompi-repo\"", s);

    const parsed = try std.json.parseFromSlice(Backend, allocator, "\"distrobox\"", .{});
    defer parsed.deinit();
    try std.testing.expectEqual(Backend.distrobox, parsed.value);
}
