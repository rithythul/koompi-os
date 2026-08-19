const std = @import("std");
const config = @import("config.zig");

/// Never invoked for real by any test -- see the safety boundary in the
/// Phase 3 plan: every command this module builds mutates real host or
/// target-root state (bootstrap, bootloader, systemd, accounts).
pub fn mmdebstrapArgv(allocator: std.mem.Allocator, packages: []const []const u8, suite: []const u8, target_root: []const u8) ![]const []const u8 {
    var argv = std.ArrayList([]const u8).init(allocator);
    errdefer argv.deinit();
    try argv.appendSlice(&.{ "mmdebstrap", "--variant=minbase" });
    if (packages.len > 0) {
        try argv.append("--include");
        try argv.append(try std.mem.join(allocator, ",", packages));
    }
    try argv.append(suite);
    try argv.append(target_root);
    return argv.toOwnedSlice();
}

pub fn chrootArgv(allocator: std.mem.Allocator, target_root: []const u8, cmd: []const []const u8) ![]const []const u8 {
    var argv = std.ArrayList([]const u8).init(allocator);
    errdefer argv.deinit();
    try argv.appendSlice(&.{ "chroot", target_root });
    try argv.appendSlice(cmd);
    return argv.toOwnedSlice();
}

pub fn grubInstallArgv() [4][]const u8 {
    return .{ "grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--bootloader-id=KOOMPI" };
}

pub fn grubMkconfigArgv() [3][]const u8 {
    return .{ "grub-mkconfig", "-o", "/boot/grub/grub.cfg" };
}

pub const systemd_units = [_][]const u8{
    "grub-btrfsd",
    "snapper-timeline.timer",
    "snapper-cleanup.timer",
    "systemd-zram-setup@zram0.service",
    "NetworkManager",
};

pub fn systemctlEnableArgv(unit: []const u8) [3][]const u8 {
    return .{ "systemctl", "enable", unit };
}

/// account.model (docs/EDITIONS.md §1.3) decides whether
/// `useraddSudoGroupArgv` and `passwdLockRootArgv` run afterward:
/// "sudo-user" gets full sudo and a locked root account; "separate-root"
/// gets its own root password and no sudo group membership.
pub fn useraddArgv(username: []const u8) [5][]const u8 {
    return .{ "useradd", "-m", "-s", "/bin/bash", username };
}

pub fn useraddSudoGroupArgv(username: []const u8) [5][]const u8 {
    return .{ "usermod", "-a", "-G", "sudo", username };
}

pub fn passwdLockRootArgv() [3][]const u8 {
    return .{ "passwd", "-l", "root" };
}

/// `chpasswd` reads `username:password\n` from stdin rather than argv, so
/// a password is never visible in a process listing.
pub fn chpasswdArgv() [1][]const u8 {
    return .{"chpasswd"};
}

pub fn chpasswdStdin(allocator: std.mem.Allocator, username: []const u8, password: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}:{s}\n", .{ username, password });
}

pub fn hostsFile(allocator: std.mem.Allocator, hostname: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\127.0.0.1 localhost
        \\127.0.1.1 {s}
        \\::1 localhost ip6-localhost ip6-loopback
        \\
    , .{hostname});
}

pub fn keyboardFile(allocator: std.mem.Allocator, keymap: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\XKBMODEL="pc105"
        \\XKBLAYOUT="{s}"
        \\XKBVARIANT=""
        \\XKBOPTIONS=""
        \\
    , .{keymap});
}

/// `locale-gen` reads `/etc/locale.gen`; `/etc/default/locale` is what
/// Debian's PAM stack sources at login.
pub fn localeGenFile(allocator: std.mem.Allocator, locale: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s} UTF-8\n", .{locale});
}

pub fn defaultLocaleFile(allocator: std.mem.Allocator, locale: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "LANG={s}\n", .{locale});
}

pub fn localeGenArgv() [1][]const u8 {
    return .{"locale-gen"};
}

pub fn localtimeLinkArgv(allocator: std.mem.Allocator, timezone: []const u8) ![4][]const u8 {
    const zone_path = try std.fmt.allocPrint(allocator, "/usr/share/zoneinfo/{s}", .{timezone});
    return .{ "ln", "-sf", zone_path, "/etc/localtime" };
}

pub fn flatpakRemoteAddArgv() [5][]const u8 {
    return .{ "flatpak", "remote-add", "--if-not-exists", "flathub", "https://dl.flathub.org/repo/flathub.flatpakrepo" };
}

pub fn flatpakInstallArgv(allocator: std.mem.Allocator, app_ids: []const []const u8) ![]const []const u8 {
    var argv = std.ArrayList([]const u8).init(allocator);
    errdefer argv.deinit();
    try argv.appendSlice(&.{ "flatpak", "install", "-y", "--noninteractive", "flathub" });
    try argv.appendSlice(app_ids);
    return argv.toOwnedSlice();
}

/// grub-install and apt maintainer scripts need the real /dev, /proc and
/// /sys inside the chroot.
pub const bind_mounts = [_][]const u8{ "/dev", "/dev/pts", "/proc", "/sys" };

pub fn bindMountArgv(source: []const u8, target: []const u8) [4][]const u8 {
    return .{ "mount", "--bind", source, target };
}

pub fn mountArgv(device: []const u8, target: []const u8, opts: ?[]const u8) [5][]const u8 {
    return .{ "mount", "-o", opts orelse "defaults", device, target };
}

pub fn umountArgv(target: []const u8) [2][]const u8 {
    return .{ "umount", target };
}

test "mountArgv places device before target, options after -o" {
    const argv = mountArgv("/dev/sda2", "/mnt", "subvol=@");
    try std.testing.expectEqualStrings("subvol=@", argv[2]);
    try std.testing.expectEqualStrings("/dev/sda2", argv[3]);
    try std.testing.expectEqualStrings("/mnt", argv[4]);
}

test "mmdebstrapArgv joins packages with commas and ends with suite, target" {
    const allocator = std.testing.allocator;
    const argv = try mmdebstrapArgv(allocator, &.{ "snapper", "grub-btrfs" }, "trixie", "/mnt");
    defer {
        allocator.free(argv[3]);
        allocator.free(argv);
    }
    try std.testing.expectEqualStrings("--include", argv[2]);
    try std.testing.expectEqualStrings("snapper,grub-btrfs", argv[3]);
    try std.testing.expectEqualStrings("trixie", argv[4]);
    try std.testing.expectEqualStrings("/mnt", argv[5]);
}

test "mmdebstrapArgv omits --include when there are no extra packages" {
    const allocator = std.testing.allocator;
    const argv = try mmdebstrapArgv(allocator, &.{}, "trixie", "/mnt");
    defer allocator.free(argv);
    try std.testing.expectEqual(@as(usize, 4), argv.len);
    try std.testing.expectEqualStrings("trixie", argv[2]);
}

test "chrootArgv prefixes the command with chroot and the target root" {
    const allocator = std.testing.allocator;
    const argv = try chrootArgv(allocator, "/mnt", &.{ "grub-install", "--target=x86_64-efi" });
    defer allocator.free(argv);
    try std.testing.expectEqualStrings("chroot", argv[0]);
    try std.testing.expectEqualStrings("/mnt", argv[1]);
    try std.testing.expectEqualStrings("grub-install", argv[2]);
}

test "useraddArgv creates the home dir and bash shell for the given username" {
    const argv = useraddArgv("koompi");
    try std.testing.expectEqualStrings("-m", argv[1]);
    try std.testing.expectEqualStrings("koompi", argv[4]);
}

test "useraddSudoGroupArgv adds the sudo group via usermod" {
    const argv = useraddSudoGroupArgv("koompi");
    try std.testing.expectEqualStrings("sudo", argv[3]);
    try std.testing.expectEqualStrings("koompi", argv[4]);
}

test "chpasswdStdin formats the username:password line chpasswd expects" {
    const allocator = std.testing.allocator;
    const stdin = try chpasswdStdin(allocator, "koompi", "hunter2");
    defer allocator.free(stdin);
    try std.testing.expectEqualStrings("koompi:hunter2\n", stdin);
}

test "hostsFile maps 127.0.1.1 to the chosen hostname" {
    const allocator = std.testing.allocator;
    const text = try hostsFile(allocator, "koompi-pc");
    defer allocator.free(text);
    try std.testing.expectEqualStrings(
        \\127.0.0.1 localhost
        \\127.0.1.1 koompi-pc
        \\::1 localhost ip6-localhost ip6-loopback
        \\
    , text);
}

test "keyboardFile sets XKBLAYOUT to the chosen keymap" {
    const allocator = std.testing.allocator;
    const text = try keyboardFile(allocator, "us");
    defer allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "XKBLAYOUT=\"us\"") != null);
}

test "locale files carry the chosen locale in both formats" {
    const allocator = std.testing.allocator;
    const gen = try localeGenFile(allocator, "en_US.UTF-8");
    defer allocator.free(gen);
    const default = try defaultLocaleFile(allocator, "en_US.UTF-8");
    defer allocator.free(default);
    try std.testing.expectEqualStrings("en_US.UTF-8 UTF-8\n", gen);
    try std.testing.expectEqualStrings("LANG=en_US.UTF-8\n", default);
}

test "localtimeLinkArgv points /etc/localtime at the zoneinfo file" {
    const allocator = std.testing.allocator;
    const argv = try localtimeLinkArgv(allocator, "Asia/Phnom_Penh");
    defer allocator.free(argv[2]);
    try std.testing.expectEqualStrings("/usr/share/zoneinfo/Asia/Phnom_Penh", argv[2]);
    try std.testing.expectEqualStrings("/etc/localtime", argv[3]);
}

test "flatpakInstallArgv appends every app id after the flathub remote" {
    const allocator = std.testing.allocator;
    const argv = try flatpakInstallArgv(allocator, &.{ "org.gimp.GIMP", "org.videolan.VLC" });
    defer allocator.free(argv);
    try std.testing.expectEqual(@as(usize, 7), argv.len);
    try std.testing.expectEqualStrings("flathub", argv[4]);
    try std.testing.expectEqualStrings("org.videolan.VLC", argv[6]);
}

test "systemd_units matches the fixed unit list from docs/ARCHITECTURE.md §6" {
    try std.testing.expectEqual(@as(usize, 5), systemd_units.len);
}
