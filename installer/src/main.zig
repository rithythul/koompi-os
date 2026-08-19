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

pub const Run = *const fn (allocator: std.mem.Allocator, argv: []const []const u8, input: ?[]const u8) anyerror!exec.Result;

fn realRun(allocator: std.mem.Allocator, argv: []const []const u8, input: ?[]const u8) anyerror!exec.Result {
    if (input) |data| return exec.runExpectOkInput(allocator, argv, data);
    return exec.runExpectOk(allocator, argv);
}

/// Every path and command `runInstall` touches, so a test can point the
/// whole sequence at a temp directory and a recording runner instead of
/// this machine's disks.
pub const Env = struct {
    editions_root: []const u8 = editions_root,
    base_packages_path: []const u8 = base_packages_path,
    base_overlay_path: []const u8 = base_overlay_path,
    target_root: []const u8 = target_root,
    run: Run = realRun,
};
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

fn targetPath(allocator: std.mem.Allocator, env: Env, rel_path: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ env.target_root, rel_path });
}

fn writeTargetFile(allocator: std.mem.Allocator, env: Env, rel_path: []const u8, data: []const u8) !void {
    const path = try targetPath(allocator, env, rel_path);
    if (std.fs.path.dirname(path)) |dir| try std.fs.cwd().makePath(dir);
    try std.fs.cwd().writeFile(.{ .sub_path = path, .data = data });
}

fn blkidUuid(allocator: std.mem.Allocator, env: Env, part_path: []const u8) ![]const u8 {
    const res = try env.run(allocator, &disk.blkidUuidArgv(part_path), null);
    const uuid = std.mem.trim(u8, res.stdout, " \t\r\n");
    if (uuid.len == 0) return error.MissingUuid;
    return uuid;
}

fn runInTarget(allocator: std.mem.Allocator, env: Env, cmd: []const []const u8) !void {
    _ = try env.run(allocator, try system.chrootArgv(allocator, env.target_root, cmd), null);
}

/// Steps 10-16: bootstrap, configure, and apply the edition. Against the
/// default Env every command here partitions, formats or bootstraps for
/// real -- only Phase 4's QEMU target runs it that way. The ordering and
/// the files it writes are covered by a test that swaps in a recording
/// runner and a temp target root.
pub fn runInstall(allocator: std.mem.Allocator, answers: Answers, disks: []const disk.BlockDevice, env: Env) !void {
    const selected = disks[answers.disk_index];
    const disk_path = try std.fmt.allocPrint(allocator, "/dev/{s}", .{selected.name});
    const esp_part = try disk.partitionDevicePath(allocator, selected.name, 1);
    const root_part = try disk.partitionDevicePath(allocator, selected.name, 2);

    _ = try env.run(allocator, &disk.sfdiskArgv(disk_path), try disk.sfdiskScript(allocator));
    _ = try env.run(allocator, &.{ "partprobe", disk_path }, null);

    _ = try env.run(allocator, &disk.mkfsEspArgv(esp_part), null);
    _ = try env.run(allocator, &disk.mkfsBtrfsArgv(root_part), null);

    const root_uuid = try blkidUuid(allocator, env, root_part);
    const esp_uuid = try blkidUuid(allocator, env, esp_part);

    try std.fs.cwd().makePath(env.target_root);
    _ = try env.run(allocator, &system.mountArgv(root_part, env.target_root, null), null);
    for (fstab.subvols) |sv| {
        _ = try env.run(allocator, &(try disk.btrfsSubvolumeCreateArgv(allocator, env.target_root, sv.name)), null);
    }
    _ = try env.run(allocator, &system.umountArgv(env.target_root), null);

    for (fstab.subvols) |sv| {
        const mount_point = try targetPath(allocator, env, sv.mount_point);
        try std.fs.cwd().makePath(mount_point);
        const opts = try std.fmt.allocPrint(allocator, "subvol={s}", .{sv.name});
        _ = try env.run(allocator, &system.mountArgv(root_part, mount_point, opts), null);
    }
    const esp_mount = try targetPath(allocator, env, "boot/efi");
    try std.fs.cwd().makePath(esp_mount);
    _ = try env.run(allocator, &system.mountArgv(esp_part, esp_mount, null), null);

    const edition_name = edition_names[answers.edition_index];
    var edition = try config.load(allocator, env.editions_root, edition_name, env.base_packages_path);
    defer edition.deinit();

    // koompi-repo packages are apt packages too (EDITIONS.md §1.1); only
    // flatpak needs a separate backend pass.
    var apt_packages = std.ArrayList([]const u8).init(allocator);
    try apt_packages.appendSlice(edition.base_packages);
    try apt_packages.appendSlice(edition.manifest.koompi_repo);
    try apt_packages.appendSlice(edition.manifest.debian);
    const bootstrap_argv = try system.mmdebstrapArgv(allocator, apt_packages.items, debian_suite, env.target_root);
    _ = try env.run(allocator, bootstrap_argv, null);

    // overlay before useradd, so /etc/skel is populated when `useradd -m`
    // copies it into the new home directory (docs/ARCHITECTURE.md §6 step 11)
    const edition_overlay_src = try std.fs.path.join(allocator, &.{ env.editions_root, edition_name, "overlay" });
    try overlay.applyOverlays(allocator, env.base_overlay_path, edition_overlay_src, env.target_root);

    const fstab_text = try fstab.generate(allocator, .{ .root_uuid = root_uuid, .esp_uuid = esp_uuid });
    try writeTargetFile(allocator, env, "etc/fstab", fstab_text);

    try writeTargetFile(allocator, env, "etc/hostname", try std.fmt.allocPrint(allocator, "{s}\n", .{answers.hostname}));
    try writeTargetFile(allocator, env, "etc/hosts", try system.hostsFile(allocator, answers.hostname));
    try writeTargetFile(allocator, env, "etc/default/keyboard", try system.keyboardFile(allocator, answers.keymap));
    try writeTargetFile(allocator, env, "etc/locale.gen", try system.localeGenFile(allocator, answers.locale));
    try writeTargetFile(allocator, env, "etc/default/locale", try system.defaultLocaleFile(allocator, answers.locale));
    try writeTargetFile(allocator, env, "etc/timezone", try std.fmt.allocPrint(allocator, "{s}\n", .{answers.timezone}));

    for (system.bind_mounts) |src| {
        const dst = try targetPath(allocator, env, src[1..]);
        try std.fs.cwd().makePath(dst);
        _ = try env.run(allocator, &system.bindMountArgv(src, dst), null);
    }
    defer for (0..system.bind_mounts.len) |i| {
        const src = system.bind_mounts[system.bind_mounts.len - 1 - i];
        const dst = targetPath(allocator, env, src[1..]) catch continue;
        _ = env.run(allocator, &system.umountArgv(dst), null) catch continue;
    };

    try runInTarget(allocator, env, &system.localeGenArgv());
    try runInTarget(allocator, env, &(try system.localtimeLinkArgv(allocator, answers.timezone)));

    try runInTarget(allocator, env, &system.grubInstallArgv());
    try runInTarget(allocator, env, &system.grubMkconfigArgv());

    try runInTarget(allocator, env, &system.snapperCreateConfigArgv());

    for (system.systemd_units) |unit| {
        try runInTarget(allocator, env, &system.systemctlEnableArgv(unit));
    }

    try runInTarget(allocator, env, &system.useraddArgv(answers.username));
    _ = try env.run(
        allocator,
        try system.chrootArgv(allocator, env.target_root, &system.chpasswdArgv()),
        try system.chpasswdStdin(allocator, answers.username, answers.password),
    );
    switch (edition.policy.account_model) {
        .@"sudo-user" => {
            try runInTarget(allocator, env, &system.useraddSudoGroupArgv(answers.username));
            try runInTarget(allocator, env, &system.passwdLockRootArgv());
        },
        .@"separate-root" => {
            const root_password = answers.root_password orelse return error.MissingRootPassword;
            _ = try env.run(
                allocator,
                try system.chrootArgv(allocator, env.target_root, &system.chpasswdArgv()),
                try system.chpasswdStdin(allocator, "root", root_password),
            );
        },
    }

    if (edition.manifest.flatpak.len > 0) {
        try runInTarget(allocator, env, &system.flatpakRemoteAddArgv());
        try runInTarget(allocator, env, try system.flatpakInstallArgv(allocator, edition.manifest.flatpak));
    }
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
    try runInstall(allocator, answers, disks, .{});

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

/// Records what runInstall would have executed, and whether the overlay
/// had already landed in the target root at that point. A function
/// pointer can't close over state, so the recording lives here.
const RecordingRun = struct {
    const Call = struct { command: []const u8, input: ?[]const u8, skel_present: bool };

    var allocator: std.mem.Allocator = undefined;
    var root: []const u8 = "";
    var calls: std.ArrayList(Call) = undefined;

    fn reset(a: std.mem.Allocator, target: []const u8) void {
        allocator = a;
        root = target;
        calls = std.ArrayList(Call).init(a);
    }

    fn run(a: std.mem.Allocator, argv: []const []const u8, input: ?[]const u8) anyerror!exec.Result {
        try calls.append(.{
            .command = try std.mem.join(a, " ", argv),
            .input = input,
            .skel_present = skelPresent(),
        });
        const stdout = if (std.mem.eql(u8, argv[0], "blkid")) "abcd-1234\n" else "";
        return .{ .stdout = try a.dupe(u8, stdout), .stderr = try a.dupe(u8, ""), .exit_code = 0 };
    }

    fn skelPresent() bool {
        const path = std.fs.path.join(allocator, &.{ root, "etc/skel/.config/koompi-edition" }) catch return false;
        std.fs.cwd().access(path, .{}) catch return false;
        return true;
    }

    fn find(needle: []const u8) ?usize {
        for (calls.items, 0..) |call, i| {
            if (std.mem.indexOf(u8, call.command, needle) != null) return i;
        }
        return null;
    }
};

test "runInstall populates /etc/skel before it creates the account" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const target = try tmp.dir.realpathAlloc(allocator, ".");
    RecordingRun.reset(allocator, target);

    const disks = [_]disk.BlockDevice{
        .{ .name = "sda", .size_bytes = 256000000000, .kind = "disk", .model = null },
    };
    const answers = Answers{
        .keymap = "us",
        .locale = "en_US.UTF-8",
        .timezone = "Asia/Phnom_Penh",
        .disk_index = 0,
        .hostname = "koompi-pc",
        .username = "user",
        .password = "hunter2",
        .root_password = null,
        .edition_index = 4,
    };

    try runInstall(allocator, answers, &disks, .{
        .editions_root = "../editions",
        .base_packages_path = "../base/packages.list",
        .base_overlay_path = "../base/overlay",
        .target_root = target,
        .run = RecordingRun.run,
    });

    const bootstrap = RecordingRun.find("mmdebstrap").?;
    const useradd = RecordingRun.find("useradd").?;
    try std.testing.expect(bootstrap < useradd);
    try std.testing.expect(!RecordingRun.calls.items[bootstrap].skel_present);
    try std.testing.expect(RecordingRun.calls.items[useradd].skel_present);
}

test "runInstall registers the snapper root config before enabling the snapper timers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const target = try tmp.dir.realpathAlloc(allocator, ".");
    RecordingRun.reset(allocator, target);

    const disks = [_]disk.BlockDevice{
        .{ .name = "sda", .size_bytes = 256000000000, .kind = "disk", .model = null },
    };
    const answers = Answers{
        .keymap = "us",
        .locale = "en_US.UTF-8",
        .timezone = "Asia/Phnom_Penh",
        .disk_index = 0,
        .hostname = "koompi-pc",
        .username = "user",
        .password = "hunter2",
        .root_password = null,
        .edition_index = 4,
    };

    try runInstall(allocator, answers, &disks, .{
        .editions_root = "../editions",
        .base_packages_path = "../base/packages.list",
        .base_overlay_path = "../base/overlay",
        .target_root = target,
        .run = RecordingRun.run,
    });

    const create_config = RecordingRun.find("create-config").?;
    const timeline_timer = RecordingRun.find("snapper-timeline.timer").?;
    try std.testing.expect(create_config < timeline_timer);
}

test "runInstall writes the real blkid UUID into fstab and feeds chpasswd the password" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const target = try tmp.dir.realpathAlloc(allocator, ".");
    RecordingRun.reset(allocator, target);

    const disks = [_]disk.BlockDevice{
        .{ .name = "nvme0n1", .size_bytes = 512000000000, .kind = "disk", .model = null },
    };
    const answers = Answers{
        .keymap = "us",
        .locale = "km_KH.UTF-8",
        .timezone = "Asia/Phnom_Penh",
        .disk_index = 0,
        .hostname = "koompi-pc",
        .username = "user",
        .password = "hunter2",
        .root_password = null,
        .edition_index = 4,
    };

    try runInstall(allocator, answers, &disks, .{
        .editions_root = "../editions",
        .base_packages_path = "../base/packages.list",
        .base_overlay_path = "../base/overlay",
        .target_root = target,
        .run = RecordingRun.run,
    });

    const fstab_text = try tmp.dir.readFileAlloc(allocator, "etc/fstab", 4096);
    try std.testing.expect(std.mem.indexOf(u8, fstab_text, "UUID=abcd-1234 / btrfs subvol=@") != null);

    const hostname = try tmp.dir.readFileAlloc(allocator, "etc/hostname", 256);
    try std.testing.expectEqualStrings("koompi-pc\n", hostname);

    const locale = try tmp.dir.readFileAlloc(allocator, "etc/locale.gen", 256);
    try std.testing.expectEqualStrings("km_KH.UTF-8 UTF-8\n", locale);

    const chpasswd = RecordingRun.find("chpasswd").?;
    try std.testing.expectEqualStrings("user:hunter2\n", RecordingRun.calls.items[chpasswd].input.?);

    try std.testing.expect(RecordingRun.find("/dev/nvme0n1p2") != null);
}

test {
    std.testing.refAllDecls(@This());
}
