const std = @import("std");

pub fn copyTree(allocator: std.mem.Allocator, src_dir: std.fs.Dir, dst_dir: std.fs.Dir) !void {
    var walker = try src_dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .directory => try dst_dir.makePath(entry.path),
            .file => {
                if (std.fs.path.dirname(entry.path)) |dir| try dst_dir.makePath(dir);
                try src_dir.copyFile(entry.path, dst_dir, entry.path, .{});
            },
            .sym_link => {
                if (std.fs.path.dirname(entry.path)) |dir| try dst_dir.makePath(dir);
                var link_buf: [std.fs.max_path_bytes]u8 = undefined;
                const link_target = try src_dir.readLink(entry.path, &link_buf);
                dst_dir.deleteFile(entry.path) catch |err| switch (err) {
                    error.FileNotFound => {},
                    else => return err,
                };
                try dst_dir.symLink(link_target, entry.path, .{});
            },
            else => {},
        }
    }
}

/// `base/overlay` first, then the edition's `overlay/` on top -- the
/// edition wins on any path both provide, per docs/EDITIONS.md §2.
pub fn applyOverlays(allocator: std.mem.Allocator, base_overlay: []const u8, edition_overlay: []const u8, target_root: []const u8) !void {
    try std.fs.cwd().makePath(target_root);
    var target_dir = try std.fs.cwd().openDir(target_root, .{});
    defer target_dir.close();

    try copyTreeIfExists(allocator, base_overlay, target_dir);
    try copyTreeIfExists(allocator, edition_overlay, target_dir);
}

fn copyTreeIfExists(allocator: std.mem.Allocator, overlay_path: []const u8, target_dir: std.fs.Dir) !void {
    var src_dir = std.fs.cwd().openDir(overlay_path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer src_dir.close();
    try copyTree(allocator, src_dir, target_dir);
}

test "edition overlay wins over base overlay on a conflicting path" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("base_overlay/etc/skel/.config");
    try tmp.dir.writeFile(.{ .sub_path = "base_overlay/etc/skel/.config/koompi-edition", .data = "unset\n" });
    try tmp.dir.writeFile(.{ .sub_path = "base_overlay/etc/only-in-base", .data = "base\n" });

    try tmp.dir.makePath("edition_overlay/etc/skel/.config");
    try tmp.dir.writeFile(.{ .sub_path = "edition_overlay/etc/skel/.config/koompi-edition", .data = "general\n" });

    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const base_path = try std.fs.path.join(allocator, &.{ dir_path, "base_overlay" });
    defer allocator.free(base_path);
    const edition_path = try std.fs.path.join(allocator, &.{ dir_path, "edition_overlay" });
    defer allocator.free(edition_path);
    const target_path = try std.fs.path.join(allocator, &.{ dir_path, "target" });
    defer allocator.free(target_path);

    try applyOverlays(allocator, base_path, edition_path, target_path);

    const marker = try tmp.dir.readFileAlloc(allocator, "target/etc/skel/.config/koompi-edition", 1024);
    defer allocator.free(marker);
    try std.testing.expectEqualStrings("general\n", marker);

    const base_only = try tmp.dir.readFileAlloc(allocator, "target/etc/only-in-base", 1024);
    defer allocator.free(base_only);
    try std.testing.expectEqualStrings("base\n", base_only);
}

test "copyTree preserves symlinks instead of dropping them" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("src/etc");
    try tmp.dir.writeFile(.{ .sub_path = "src/etc/real-target", .data = "x" });
    try tmp.dir.symLink("real-target", "src/etc/link-name", .{});
    try tmp.dir.makePath("dst");

    var src_dir = try tmp.dir.openDir("src", .{ .iterate = true });
    defer src_dir.close();
    var dst_dir = try tmp.dir.openDir("dst", .{});
    defer dst_dir.close();

    try copyTree(allocator, src_dir, dst_dir);

    var link_buf: [std.fs.max_path_bytes]u8 = undefined;
    const link_target = try dst_dir.readLink("etc/link-name", &link_buf);
    try std.testing.expectEqualStrings("real-target", link_target);
}

test "a missing edition overlay directory is not an error" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    try tmp.dir.makePath("base_overlay");
    try tmp.dir.writeFile(.{ .sub_path = "base_overlay/marker", .data = "x" });

    const dir_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(dir_path);
    const base_path = try std.fs.path.join(allocator, &.{ dir_path, "base_overlay" });
    defer allocator.free(base_path);
    const edition_path = try std.fs.path.join(allocator, &.{ dir_path, "no_such_dir" });
    defer allocator.free(edition_path);
    const target_path = try std.fs.path.join(allocator, &.{ dir_path, "target" });
    defer allocator.free(target_path);

    try applyOverlays(allocator, base_path, edition_path, target_path);

    const marker = try tmp.dir.readFileAlloc(allocator, "target/marker", 1024);
    defer allocator.free(marker);
    try std.testing.expectEqualStrings("x", marker);
}
