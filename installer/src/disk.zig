const std = @import("std");
const exec = @import("exec.zig");
const fstab = @import("fstab.zig");

pub const BlockDevice = struct {
    name: []const u8,
    size_bytes: u64,
    kind: []const u8,
    model: ?[]const u8,
};

const RawDevice = struct {
    name: []const u8,
    size: u64,
    @"type": []const u8,
    model: ?[]const u8 = null,
};

const RawList = struct { blockdevices: []RawDevice };

/// Real disks only (`type == "disk"`) -- excludes partitions, loop
/// devices, and zram.
pub fn listDisks(allocator: std.mem.Allocator) ![]BlockDevice {
    const res = try exec.run(allocator, &.{ "lsblk", "-J", "-b", "-o", "NAME,SIZE,TYPE,MODEL" });
    defer allocator.free(res.stderr);
    defer allocator.free(res.stdout);

    const parsed = try std.json.parseFromSlice(RawList, allocator, res.stdout, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    var out = std.ArrayList(BlockDevice).init(allocator);
    errdefer out.deinit();
    for (parsed.value.blockdevices) |d| {
        if (!std.mem.eql(u8, d.@"type", "disk")) continue;
        // zram reports TYPE=disk; it is swap (ARCHITECTURE.md §2), never a target
        if (std.mem.startsWith(u8, d.name, "zram")) continue;
        try out.append(.{
            .name = try allocator.dupe(u8, d.name),
            .size_bytes = d.size,
            .kind = try allocator.dupe(u8, d.@"type"),
            .model = if (d.model) |m| try allocator.dupe(u8, m) else null,
        });
    }
    return out.toOwnedSlice();
}

/// `nvme0n1`/`mmcblk0`-style devices need a `p` before the partition
/// number (`nvme0n1p1`); `sda`/`vda`-style devices don't (`sda1`).
pub fn partitionDevicePath(allocator: std.mem.Allocator, disk: []const u8, index: u8) ![]const u8 {
    const needs_p = disk.len > 0 and std.ascii.isDigit(disk[disk.len - 1]);
    const sep: []const u8 = if (needs_p) "p" else "";
    return std.fmt.allocPrint(allocator, "/dev/{s}{s}{d}", .{ disk, sep, index });
}

pub const esp_size_mib: u32 = 512;

pub fn sfdiskScript(allocator: std.mem.Allocator) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\label: gpt
        \\size={d}MiB, type=uefi
        \\type=linux
        \\
    , .{esp_size_mib});
}

pub fn sfdiskArgv(disk_path: []const u8) [2][]const u8 {
    return .{ "sfdisk", disk_path };
}

pub fn mkfsEspArgv(esp_part_path: []const u8) [5][]const u8 {
    return .{ "mkfs.vfat", "-F32", "-n", "ESP", esp_part_path };
}

pub fn mkfsBtrfsArgv(root_part_path: []const u8) [4][]const u8 {
    return .{ "mkfs.btrfs", "-L", "koompi", root_part_path };
}

pub fn blkidUuidArgv(part_path: []const u8) [6][]const u8 {
    return .{ "blkid", "-s", "UUID", "-o", "value", part_path };
}

pub fn btrfsSubvolumeCreateArgv(allocator: std.mem.Allocator, mount_path: []const u8, subvol_name: []const u8) ![4][]const u8 {
    const full_path = try std.fs.path.join(allocator, &.{ mount_path, subvol_name });
    return .{ "btrfs", "subvolume", "create", full_path };
}

test "partitionDevicePath appends p before the number for nvme-style disks" {
    const allocator = std.testing.allocator;
    const path = try partitionDevicePath(allocator, "nvme0n1", 1);
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/dev/nvme0n1p1", path);
}

test "partitionDevicePath appends the number directly for sd-style disks" {
    const allocator = std.testing.allocator;
    const path = try partitionDevicePath(allocator, "sda", 2);
    defer allocator.free(path);
    try std.testing.expectEqualStrings("/dev/sda2", path);
}

test "sfdiskScript describes a GPT ESP + one Btrfs partition, no swap" {
    const allocator = std.testing.allocator;
    const script = try sfdiskScript(allocator);
    defer allocator.free(script);
    try std.testing.expectEqualStrings(
        \\label: gpt
        \\size=512MiB, type=uefi
        \\type=linux
        \\
    , script);
}

test "btrfsSubvolumeCreateArgv builds one create per docs/ARCHITECTURE.md's subvolume list" {
    const allocator = std.testing.allocator;
    for (fstab.subvols) |sv| {
        const argv = try btrfsSubvolumeCreateArgv(allocator, "/mnt", sv.name);
        defer allocator.free(argv[3]);
        try std.testing.expectEqualStrings("btrfs", argv[0]);
        try std.testing.expect(std.mem.endsWith(u8, argv[3], sv.name));
    }
}

test "listDisks parses this host's real lsblk output" {
    const allocator = std.testing.allocator;
    const disks = try listDisks(allocator);
    defer {
        for (disks) |d| {
            allocator.free(d.name);
            allocator.free(d.kind);
            if (d.model) |m| allocator.free(m);
        }
        allocator.free(disks);
    }
    for (disks) |d| {
        try std.testing.expectEqualStrings("disk", d.kind);
        try std.testing.expect(d.size_bytes > 0);
        try std.testing.expect(!std.mem.startsWith(u8, d.name, "zram"));
    }
}

test "blkidUuidArgv asks for just the UUID value of one partition" {
    const argv = blkidUuidArgv("/dev/sda2");
    try std.testing.expectEqualStrings("UUID", argv[2]);
    try std.testing.expectEqualStrings("value", argv[4]);
    try std.testing.expectEqualStrings("/dev/sda2", argv[5]);
}
