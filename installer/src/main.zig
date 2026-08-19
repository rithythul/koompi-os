const std = @import("std");

pub const prompt = @import("prompt.zig");
pub const toml = @import("toml.zig");
pub const config = @import("config.zig");
pub const fstab = @import("fstab.zig");
pub const exec = @import("exec.zig");
pub const disk = @import("disk.zig");
pub const system = @import("system.zig");
pub const overlay = @import("overlay.zig");

const editions_root = "/usr/share/koompi-os/editions";
const base_packages_path = "/usr/share/koompi-os/base/packages.list";
const base_overlay_path = "/usr/share/koompi-os/base/overlay";
const target_root = "/mnt";
const debian_suite = "trixie";
const edition_names = [_][]const u8{ "government", "school", "enterprise", "dev", "general" };

pub const Answers = struct {
    keymap: []const u8,
    locale: []const u8,
    timezone: []const u8,
    disk_index: usize,
    hostname: []const u8,
    username: []const u8,
    password: []const u8,
    root_password: ?[]const u8,
    edition_index: usize,
};

/// The account model lives in the edition's policy.toml (EDITIONS.md
/// §1.3), so step 8's prompts can't be built until step 9 is answered --
/// the root-password prompt is asked after edition selection.
pub fn loadAccountModelsFrom(
    allocator: std.mem.Allocator,
    root: []const u8,
    packages_path: []const u8,
) ![edition_names.len]config.AccountModel {
    var models: [edition_names.len]config.AccountModel = undefined;
    for (edition_names, 0..) |name, i| {
        var edition = try config.load(allocator, root, name, packages_path);
        defer edition.deinit();
        models[i] = edition.policy.account_model;
    }
    return models;
}

pub fn loadAccountModels(allocator: std.mem.Allocator) ![edition_names.len]config.AccountModel {
    return loadAccountModelsFrom(allocator, editions_root, base_packages_path);
}

/// Steps 1-9: gather every answer before anything destructive runs.
/// Step 6's typed confirmation phrase names the actual selected disk, so a
/// canned-stdin test exercising this can't accidentally match a wrong disk.
pub fn collectAnswers(
    allocator: std.mem.Allocator,
    reader: anytype,
    writer: anytype,
    disks: []const disk.BlockDevice,
    account_models: []const config.AccountModel,
) !Answers {
    // `prompt.ask*` return a slice into `buf`, valid only until the next
    // call that reuses it -- every answer this function keeps past its
    // next prompt call must be duped out of `buf` immediately.
    var buf: [512]u8 = undefined;

    _ = try prompt.askChoice(reader, writer, &buf, "Language", &.{ "English", "Khmer" });

    const keymap = try allocator.dupe(u8, try prompt.askNonEmpty(reader, writer, &buf, "Keymap (e.g. us)"));
    const locale = try allocator.dupe(u8, try prompt.askNonEmpty(reader, writer, &buf, "Locale (e.g. en_US.UTF-8)"));
    const timezone = try allocator.dupe(u8, try prompt.askNonEmpty(reader, writer, &buf, "Timezone (e.g. Asia/Phnom_Penh)"));

    const disk_labels = try allocator.alloc([]const u8, disks.len);
    for (disks, 0..) |d, i| {
        const model = d.model orelse "";
        disk_labels[i] = try std.fmt.allocPrint(allocator, "{s} ({d} bytes) {s}", .{ d.name, d.size_bytes, model });
    }
    const disk_index = try prompt.askChoice(reader, writer, &buf, "Disk to install to (ALL DATA ON IT WILL BE ERASED)", disk_labels);

    const confirm_phrase = try std.fmt.allocPrint(allocator, "ERASE /dev/{s}", .{disks[disk_index].name});
    const confirmed = try prompt.confirmTyped(reader, writer, &buf, confirm_phrase);
    if (!confirmed) return error.InstallCancelled;

    const hostname = try allocator.dupe(u8, try prompt.askNonEmpty(reader, writer, &buf, "Hostname"));
    const username = try allocator.dupe(u8, try prompt.askNonEmpty(reader, writer, &buf, "Username"));
    const password = try allocator.dupe(u8, try prompt.askNonEmpty(reader, writer, &buf, "Password"));

    const edition_index = try prompt.askChoice(reader, writer, &buf, "Edition", &edition_names);

    const root_password: ?[]const u8 = switch (account_models[edition_index]) {
        .@"sudo-user" => null,
        .@"separate-root" => try allocator.dupe(u8, try prompt.askNonEmpty(reader, writer, &buf, "Root password")),
    };

    return .{
        .keymap = keymap,
        .locale = locale,
        .timezone = timezone,
        .disk_index = disk_index,
        .hostname = hostname,
        .username = username,
        .password = password,
        .root_password = root_password,
        .edition_index = edition_index,
    };
}

fn targetPath(allocator: std.mem.Allocator, rel_path: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ target_root, rel_path });
}

fn writeTargetFile(allocator: std.mem.Allocator, rel_path: []const u8, data: []const u8) !void {
    const path = try targetPath(allocator, rel_path);
    if (std.fs.path.dirname(path)) |dir| try std.fs.cwd().makePath(dir);
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
}

fn blkidUuid(allocator: std.mem.Allocator, part_path: []const u8) ![]const u8 {
    const res = try exec.runExpectOk(allocator, &disk.blkidUuidArgv(part_path));
    const uuid = std.mem.trim(u8, res.stdout, " \t\r\n");
    if (uuid.len == 0) return error.MissingUuid;
    return uuid;
}

fn runInTarget(allocator: std.mem.Allocator, cmd: []const []const u8) !void {
    _ = try exec.runExpectOk(allocator, try system.chrootArgv(allocator, target_root, cmd));
}

/// Steps 10-15: bootstrap, configure, and apply the edition. Every command
/// here mutates real disk/system state -- see the Phase 3 plan's safety
/// boundary. Never exercised by a test; only Phase 4's QEMU target runs it.
pub fn runInstall(allocator: std.mem.Allocator, answers: Answers, disks: []const disk.BlockDevice) !void {
    const selected = disks[answers.disk_index];
    const disk_path = try std.fmt.allocPrint(allocator, "/dev/{s}", .{selected.name});
    const esp_part = try disk.partitionDevicePath(allocator, selected.name, 1);
    const root_part = try disk.partitionDevicePath(allocator, selected.name, 2);

    _ = try exec.runExpectOkInput(allocator, &disk.sfdiskArgv(disk_path), try disk.sfdiskScript(allocator));
    _ = try exec.runExpectOk(allocator, &.{ "partprobe", disk_path });

    _ = try exec.runExpectOk(allocator, &disk.mkfsEspArgv(esp_part));
    _ = try exec.runExpectOk(allocator, &disk.mkfsBtrfsArgv(root_part));

    const root_uuid = try blkidUuid(allocator, root_part);
    const esp_uuid = try blkidUuid(allocator, esp_part);

    try std.fs.cwd().makePath(target_root);
    _ = try exec.runExpectOk(allocator, &system.mountArgv(root_part, target_root, null));
    for (fstab.subvols) |sv| {
        _ = try exec.runExpectOk(allocator, &(try disk.btrfsSubvolumeCreateArgv(allocator, target_root, sv.name)));
    }
    _ = try exec.runExpectOk(allocator, &system.umountArgv(target_root));

    for (fstab.subvols) |sv| {
        const mount_point = try targetPath(allocator, sv.mount_point);
        try std.fs.cwd().makePath(mount_point);
        const opts = try std.fmt.allocPrint(allocator, "subvol={s}", .{sv.name});
        _ = try exec.runExpectOk(allocator, &system.mountArgv(root_part, mount_point, opts));
    }
    const esp_mount = try targetPath(allocator, "boot/efi");
    try std.fs.cwd().makePath(esp_mount);
    _ = try exec.runExpectOk(allocator, &system.mountArgv(esp_part, esp_mount, null));

    const edition_name = edition_names[answers.edition_index];
    var edition = try config.load(allocator, editions_root, edition_name, base_packages_path);
    defer edition.deinit();

    // koompi-repo packages are apt packages too (EDITIONS.md §1.1); only
    // flatpak needs a separate backend pass.
    var apt_packages = std.ArrayList([]const u8).init(allocator);
    try apt_packages.appendSlice(edition.base_packages);
    try apt_packages.appendSlice(edition.manifest.koompi_repo);
    try apt_packages.appendSlice(edition.manifest.debian);
    const bootstrap_argv = try system.mmdebstrapArgv(allocator, apt_packages.items, debian_suite, target_root);
    _ = try exec.runExpectOk(allocator, bootstrap_argv);

    const fstab_text = try fstab.generate(allocator, .{ .root_uuid = root_uuid, .esp_uuid = esp_uuid });
    try writeTargetFile(allocator, "etc/fstab", fstab_text);

    try writeTargetFile(allocator, "etc/hostname", try std.fmt.allocPrint(allocator, "{s}\n", .{answers.hostname}));
    try writeTargetFile(allocator, "etc/hosts", try system.hostsFile(allocator, answers.hostname));
    try writeTargetFile(allocator, "etc/default/keyboard", try system.keyboardFile(allocator, answers.keymap));
    try writeTargetFile(allocator, "etc/locale.gen", try system.localeGenFile(allocator, answers.locale));
    try writeTargetFile(allocator, "etc/default/locale", try system.defaultLocaleFile(allocator, answers.locale));
    try writeTargetFile(allocator, "etc/timezone", try std.fmt.allocPrint(allocator, "{s}\n", .{answers.timezone}));

    for (system.bind_mounts) |src| {
        const dst = try targetPath(allocator, src[1..]);
        try std.fs.cwd().makePath(dst);
        _ = try exec.runExpectOk(allocator, &system.bindMountArgv(src, dst));
    }
    defer for (0..system.bind_mounts.len) |i| {
        const src = system.bind_mounts[system.bind_mounts.len - 1 - i];
        const dst = targetPath(allocator, src[1..]) catch continue;
        _ = exec.run(allocator, &system.umountArgv(dst)) catch continue;
    };

    try runInTarget(allocator, &system.localeGenArgv());
    try runInTarget(allocator, &(try system.localtimeLinkArgv(allocator, answers.timezone)));

    try runInTarget(allocator, &system.grubInstallArgv());
    try runInTarget(allocator, &system.grubMkconfigArgv());

    for (system.systemd_units) |unit| {
        try runInTarget(allocator, &system.systemctlEnableArgv(unit));
    }

    try runInTarget(allocator, &system.useraddArgv(answers.username));
    _ = try exec.runExpectOkInput(
        allocator,
        try system.chrootArgv(allocator, target_root, &system.chpasswdArgv()),
        try system.chpasswdStdin(allocator, answers.username, answers.password),
    );
    switch (edition.policy.account_model) {
        .@"sudo-user" => {
            try runInTarget(allocator, &system.useraddSudoGroupArgv(answers.username));
            try runInTarget(allocator, &system.passwdLockRootArgv());
        },
        .@"separate-root" => {
            const root_password = answers.root_password orelse return error.MissingRootPassword;
            _ = try exec.runExpectOkInput(
                allocator,
                try system.chrootArgv(allocator, target_root, &system.chpasswdArgv()),
                try system.chpasswdStdin(allocator, "root", root_password),
            );
        },
    }

    if (edition.manifest.flatpak.len > 0) {
        try runInTarget(allocator, &system.flatpakRemoteAddArgv());
        try runInTarget(allocator, try system.flatpakInstallArgv(allocator, edition.manifest.flatpak));
    }

    const edition_overlay_src = try std.fs.path.join(allocator, &.{ editions_root, edition_name, "overlay" });
    try overlay.applyOverlays(allocator, base_overlay_path, edition_overlay_src, target_root);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("KOOMPI OS installer\n\n", .{});

    const disks = try disk.listDisks(allocator);
    if (disks.len == 0) return error.NoInstallTargetFound;
    const account_models = try loadAccountModels(allocator);
    const answers = try collectAnswers(allocator, stdin, stdout, disks, &account_models);
    try runInstall(allocator, answers, disks);

    try stdout.print("\nInstall complete. Reboot when ready.\n", .{});
}

test "collectAnswers walks steps 1-9 from canned stdin" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const disks = [_]disk.BlockDevice{
        .{ .name = "sda", .size_bytes = 256000000000, .kind = "disk", .model = null },
    };

    var input = std.io.fixedBufferStream(
        "1\n" ++ // language
            "us\n" ++ // keymap
            "en_US.UTF-8\n" ++ // locale
            "Asia/Phnom_Penh\n" ++ // timezone
            "1\n" ++ // disk choice
            "ERASE /dev/sda\n" ++ // typed confirmation
            "koompi-pc\n" ++ // hostname
            "user\n" ++ // username
            "hunter2\n" ++ // password
            "5\n" // edition choice (general)
    );
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const models = [_]config.AccountModel{.@"sudo-user"} ** edition_names.len;
    const answers = try collectAnswers(allocator, input.reader(), output.writer(), &disks, &models);

    try std.testing.expectEqualStrings("us", answers.keymap);
    try std.testing.expectEqualStrings("koompi-pc", answers.hostname);
    try std.testing.expectEqualStrings("user", answers.username);
    try std.testing.expectEqualStrings("hunter2", answers.password);
    try std.testing.expectEqual(@as(?[]const u8, null), answers.root_password);
    try std.testing.expectEqual(@as(usize, 0), answers.disk_index);
    try std.testing.expectEqual(@as(usize, 4), answers.edition_index);
}

test "a separate-root edition asks for a distinct root password" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const disks = [_]disk.BlockDevice{
        .{ .name = "sda", .size_bytes = 256000000000, .kind = "disk", .model = null },
    };

    var input = std.io.fixedBufferStream(
        "1\nus\nen_US.UTF-8\nAsia/Phnom_Penh\n1\nERASE /dev/sda\nkoompi-pc\nuser\nhunter2\n1\ntoor\n",
    );
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    var models = [_]config.AccountModel{.@"sudo-user"} ** edition_names.len;
    models[0] = .@"separate-root";
    const answers = try collectAnswers(allocator, input.reader(), output.writer(), &disks, &models);

    try std.testing.expectEqualStrings("hunter2", answers.password);
    try std.testing.expectEqualStrings("toor", answers.root_password.?);
}

test "loadAccountModels reads the real editions in this repo" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const models = try loadAccountModelsFrom(arena.allocator(), "../editions", "../base/packages.list");
    try std.testing.expectEqual(config.AccountModel.@"sudo-user", models[edition_names.len - 1]);
}

test "collectAnswers cancels when the typed confirmation doesn't match" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const disks = [_]disk.BlockDevice{
        .{ .name = "sda", .size_bytes = 256000000000, .kind = "disk", .model = null },
    };

    var input = std.io.fixedBufferStream(
        "1\nus\nen_US.UTF-8\nAsia/Phnom_Penh\n1\nyes please\n",
    );
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const models = [_]config.AccountModel{.@"sudo-user"} ** edition_names.len;
    const result = collectAnswers(allocator, input.reader(), output.writer(), &disks, &models);
    try std.testing.expectError(error.InstallCancelled, result);
}

test {
    std.testing.refAllDecls(@This());
}
