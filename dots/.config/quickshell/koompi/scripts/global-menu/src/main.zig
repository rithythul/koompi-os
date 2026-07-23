const std = @import("std");
const linux = std.os.linux;

const STDOUT = std.posix.STDOUT_FILENO;
const STDERR = std.posix.STDERR_FILENO;

const MenuItem = struct {
    label: []const u8,
    enabled: bool,
    sep: bool,
    items: []MenuItem,

    fn deinit(self: *MenuItem, gpa: std.mem.Allocator) void {
        gpa.free(self.label);
        for (self.items) |*child| child.deinit(gpa);
        gpa.free(self.items);
    }
};

const MenuOutput = struct {
    items: []const MenuItem,
};

const ActiveWindow = struct {
    pid: i64 = 0,
    xwayland: bool = false,
};

const X11MenuProps = struct {
    bus: []u8,
    path: []u8,
};

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;

    const sig = init.environ_map.get("HYPRLAND_INSTANCE_SIGNATURE") orelse {
        log("HYPRLAND_INSTANCE_SIGNATURE not set\n");
        return error.NoHyprland;
    };
    const runtime_dir = init.environ_map.get("XDG_RUNTIME_DIR") orelse "/run/user/1000";
    const socket_path = try std.fmt.allocPrint(gpa, "{s}/hypr/{s}/.socket2.sock", .{ runtime_dir, sig });
    defer gpa.free(socket_path);

    const sock = try connectUnixSocket(socket_path);
    defer _ = linux.close(sock);

    emitEmpty();

    var partial: std.ArrayListUnmanaged(u8) = .empty;
    defer partial.deinit(gpa);
    var buf: [4096]u8 = undefined;

    while (true) {
        const rc = linux.read(sock, buf[0..].ptr, buf.len);
        if (rc == 0) break;
        if (@as(isize, @bitCast(rc)) < 0) break;
        const n: usize = @intCast(rc);
        try partial.appendSlice(gpa, buf[0..n]);

        while (std.mem.indexOfScalar(u8, partial.items, '\n')) |nl| {
            const line = partial.items[0..nl];
            if (std.mem.startsWith(u8, line, "activewindow>>")) {
                handleActiveWindow(gpa, io) catch emitEmpty();
            }
            const keep = partial.items[nl + 1 ..];
            std.mem.copyForwards(u8, partial.items[0..keep.len], keep);
            partial.items.len = keep.len;
        }
    }
}

fn handleActiveWindow(gpa: std.mem.Allocator, io: std.Io) !void {
    const r = try std.process.run(gpa, io, .{
        .argv = &.{ "hyprctl", "-j", "activewindow" },
    });
    defer gpa.free(r.stdout);
    defer gpa.free(r.stderr);

    const parsed = std.json.parseFromSlice(ActiveWindow, gpa, r.stdout, .{
        .ignore_unknown_fields = true,
    }) catch {
        emitEmpty();
        return;
    };
    defer parsed.deinit();

    const win = parsed.value;
    if (win.pid == 0 or !win.xwayland) {
        emitEmpty();
        return;
    }

    const x11_id = getX11ActiveWindow(gpa, io) catch {
        emitEmpty();
        return;
    };

    const props = getX11MenuProperties(gpa, io, x11_id) catch {
        emitEmpty();
        return;
    };
    defer gpa.free(props.bus);
    defer gpa.free(props.path);

    const items = fetchGtkMenu(gpa, io, props.bus, props.path) catch {
        emitEmpty();
        return;
    };
    defer {
        for (items) |*it| {
            var item = it.*;
            item.deinit(gpa);
        }
        gpa.free(items);
    }

    if (items.len == 0) {
        emitEmpty();
        return;
    }

    emitItems(gpa, items) catch {};
}

// ── X11 property reading ──────────────────────────────────────────────────────

fn getX11ActiveWindow(gpa: std.mem.Allocator, io: std.Io) !u32 {
    const r = try std.process.run(gpa, io, .{
        .argv = &.{ "xprop", "-root", "_NET_ACTIVE_WINDOW" },
        .stdout_limit = std.Io.Limit.limited(256),
    });
    defer gpa.free(r.stdout);
    defer gpa.free(r.stderr);

    const marker = "window id # ";
    const idx = std.mem.indexOf(u8, r.stdout, marker) orelse return error.NotFound;
    const hex = std.mem.trimEnd(u8, r.stdout[idx + marker.len ..], " \n\r\t");
    return std.fmt.parseInt(u32, hex, 0) catch error.NotFound;
}

fn getX11MenuProperties(gpa: std.mem.Allocator, io: std.Io, xid: u32) !X11MenuProps {
    const xid_str = try std.fmt.allocPrint(gpa, "0x{x}", .{xid});
    defer gpa.free(xid_str);

    const r = try std.process.run(gpa, io, .{
        .argv = &.{ "xprop", "-id", xid_str, "_GTK_UNIQUE_BUS_NAME", "_GTK_MENUBAR_OBJECT_PATH" },
        .stdout_limit = std.Io.Limit.limited(512),
    });
    defer gpa.free(r.stdout);
    defer gpa.free(r.stderr);

    var bus: ?[]u8 = null;
    var path: ?[]u8 = null;
    errdefer {
        if (bus) |b| gpa.free(b);
        if (path) |p| gpa.free(p);
    }

    var lines = std.mem.splitScalar(u8, r.stdout, '\n');
    while (lines.next()) |line| {
        if (quotedValue(line, "_GTK_UNIQUE_BUS_NAME")) |v| {
            if (bus) |old| gpa.free(old);
            bus = try gpa.dupe(u8, v);
        } else if (quotedValue(line, "_GTK_MENUBAR_OBJECT_PATH")) |v| {
            if (path) |old| gpa.free(old);
            path = try gpa.dupe(u8, v);
        }
    }

    return X11MenuProps{
        .bus = bus orelse return error.NoMenuBus,
        .path = path orelse return error.NoMenuPath,
    };
}

fn quotedValue(line: []const u8, prop: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, line, prop)) return null;
    const q1 = std.mem.indexOfScalar(u8, line, '"') orelse return null;
    const q2 = std.mem.lastIndexOfScalar(u8, line, '"') orelse return null;
    if (q1 >= q2) return null;
    return line[q1 + 1 .. q2];
}

// ── org.gtk.Menus fetching ────────────────────────────────────────────────────

const RawItem = struct {
    label: []u8,
    submenu: u32, // subscription handle (0 = no submenu)
    enabled: bool,
    sep: bool,
};

fn fetchGtkMenu(gpa: std.mem.Allocator, io: std.Io, bus: []const u8, menu_path: []const u8) ![]MenuItem {
    // Step 1: get root menu bar (subscription 0)
    const root_json = try callGtkMenusStart(gpa, io, bus, menu_path, &[_]u32{0});
    defer gpa.free(root_json);

    const root_raw = try parseGtkMenusJson(gpa, root_json, 0);
    defer {
        for (root_raw) |*r| gpa.free(r.label);
        gpa.free(root_raw);
    }

    if (root_raw.len == 0) return &.{};

    // Step 2: collect unique submenu handles
    var handles: std.ArrayListUnmanaged(u32) = .empty;
    defer handles.deinit(gpa);
    for (root_raw) |r| {
        if (r.submenu > 0) {
            var dup = false;
            for (handles.items) |h| {
                if (h == r.submenu) { dup = true; break; }
            }
            if (!dup) try handles.append(gpa, r.submenu);
        }
    }

    // Step 3: fetch submenus; sub_map owns the []MenuItem slices
    var sub_map: std.AutoHashMapUnmanaged(u32, []MenuItem) = .{};
    defer {
        var it = sub_map.iterator();
        while (it.next()) |kv| {
            for (kv.value_ptr.*) |*item| item.deinit(gpa);
            gpa.free(kv.value_ptr.*);
        }
        sub_map.deinit(gpa);
    }

    if (handles.items.len > 0) {
        const sub_json = try callGtkMenusStart(gpa, io, bus, menu_path, handles.items);
        defer gpa.free(sub_json);

        for (handles.items) |h| {
            const raw = try parseGtkMenusJson(gpa, sub_json, h);
            defer {
                for (raw) |*r| gpa.free(r.label);
                gpa.free(raw);
            }

            var children: std.ArrayListUnmanaged(MenuItem) = .empty;
            errdefer {
                for (children.items) |*c| c.deinit(gpa);
                children.deinit(gpa);
            }
            for (raw) |r| {
                try children.append(gpa, .{
                    .label = try gpa.dupe(u8, r.label),
                    .enabled = r.enabled,
                    .sep = r.sep,
                    .items = &.{},
                });
            }
            try sub_map.put(gpa, h, try children.toOwnedSlice(gpa));
        }
    }

    // Step 4: build result, pulling children from sub_map
    var result: std.ArrayListUnmanaged(MenuItem) = .empty;
    errdefer {
        for (result.items) |*item| item.deinit(gpa);
        result.deinit(gpa);
    }

    for (root_raw) |r| {
        const children: []MenuItem = if (r.submenu > 0)
            if (sub_map.fetchRemove(r.submenu)) |kv| kv.value else &.{}
        else
            &.{};

        try result.append(gpa, .{
            .label = try gpa.dupe(u8, r.label),
            .enabled = r.enabled,
            .sep = r.sep,
            .items = children,
        });
    }

    return result.toOwnedSlice(gpa);
}

// Runs busctl --user --json=short call <bus> <path> org.gtk.Menus Start au N [handles...]
// Returns allocated stdout (caller owns).
fn callGtkMenusStart(
    gpa: std.mem.Allocator,
    io: std.Io,
    bus: []const u8,
    path: []const u8,
    handles: []const u32,
) ![]u8 {
    var argv: std.ArrayListUnmanaged([]const u8) = .empty;
    defer argv.deinit(gpa);

    try argv.appendSlice(gpa, &.{
        "busctl", "--user", "--json=short", "call",
        bus, path, "org.gtk.Menus", "Start", "au",
    });

    const count_str = try std.fmt.allocPrint(gpa, "{d}", .{handles.len});
    defer gpa.free(count_str);
    try argv.append(gpa, count_str);

    var handle_strs: std.ArrayListUnmanaged([]u8) = .empty;
    defer {
        for (handle_strs.items) |s| gpa.free(s);
        handle_strs.deinit(gpa);
    }
    for (handles) |h| {
        const s = try std.fmt.allocPrint(gpa, "{d}", .{h});
        try handle_strs.append(gpa, s);
        try argv.append(gpa, s);
    }

    const r = try std.process.run(gpa, io, .{
        .argv = argv.items,
        .stdout_limit = std.Io.Limit.limited(256 * 1024),
    });
    defer gpa.free(r.stderr);
    return r.stdout; // caller owns
}

// Parse busctl --json=short a(uuaa{sv}) output, return items for given subscription.
fn parseGtkMenusJson(
    gpa: std.mem.Allocator,
    json_bytes: []const u8,
    subscription: u32,
) ![]RawItem {
    const parsed = std.json.parseFromSlice(std.json.Value, gpa, json_bytes, .{
        .ignore_unknown_fields = true,
    }) catch return gpa.dupe(RawItem, &.{});
    defer parsed.deinit();

    // {"type":"a(uuaa{sv})","data":[[  [sub,sec,items], ...  ]]}
    const data_val = switch (parsed.value) {
        .object => |o| o.get("data") orelse return gpa.dupe(RawItem, &.{}),
        else => return gpa.dupe(RawItem, &.{}),
    };
    const outer_arr = switch (data_val) {
        .array => |a| a.items,
        else => return gpa.dupe(RawItem, &.{}),
    };
    if (outer_arr.len == 0) return gpa.dupe(RawItem, &.{});

    const structs = switch (outer_arr[0]) {
        .array => |a| a.items,
        else => return gpa.dupe(RawItem, &.{}),
    };

    var items: std.ArrayListUnmanaged(RawItem) = .empty;
    errdefer {
        for (items.items) |*r| gpa.free(r.label);
        items.deinit(gpa);
    }

    for (structs) |entry| {
        const tup = switch (entry) {
            .array => |a| a.items,
            else => continue,
        };
        if (tup.len < 3) continue;

        const sub_id: u32 = switch (tup[0]) {
            .integer => |n| @intCast(n),
            else => continue,
        };
        if (sub_id != subscription) continue;

        const menu_items = switch (tup[2]) {
            .array => |a| a.items,
            else => continue,
        };

        for (menu_items) |item_val| {
            const item_obj = switch (item_val) {
                .object => |o| o,
                else => continue,
            };

            // Skip section links (they just chain sections together)
            if (item_obj.get(":section") != null) continue;

            // Extract label
            const is_sep = item_obj.get("label") == null;
            const label_str: []const u8 = blk: {
                const lv = item_obj.get("label") orelse break :blk "";
                const lv_obj = switch (lv) {
                    .object => |o| o,
                    else => break :blk "",
                };
                const dv = lv_obj.get("data") orelse break :blk "";
                break :blk switch (dv) {
                    .string => |s| s,
                    else => "",
                };
            };

            // Extract submenu handle
            var submenu_handle: u32 = 0;
            if (item_obj.get(":submenu")) |sv| {
                const sv_obj = switch (sv) {
                    .object => |o| o,
                    else => null,
                };
                if (sv_obj) |obj| {
                    if (obj.get("data")) |dv| {
                        switch (dv) {
                            .array => |arr| {
                                if (arr.items.len >= 1) {
                                    submenu_handle = switch (arr.items[0]) {
                                        .integer => |n| @intCast(n),
                                        else => 0,
                                    };
                                }
                            },
                            else => {},
                        }
                    }
                }
            }

            try items.append(gpa, .{
                .label = try gpa.dupe(u8, label_str),
                .submenu = submenu_handle,
                .enabled = true,
                .sep = is_sep,
            });
        }
    }

    return items.toOwnedSlice(gpa);
}

// ── Output ────────────────────────────────────────────────────────────────────

fn emitEmpty() void {
    const msg = "{\"items\":[]}\n";
    _ = linux.write(STDOUT, msg.ptr, msg.len);
}

fn emitItems(gpa: std.mem.Allocator, items: []MenuItem) !void {
    const out = MenuOutput{ .items = items };
    const json = try std.json.Stringify.valueAlloc(gpa, out, .{});
    defer gpa.free(json);
    _ = linux.write(STDOUT, json.ptr, json.len);
    _ = linux.write(STDOUT, "\n", 1);
}

// ── Utilities ─────────────────────────────────────────────────────────────────

fn connectUnixSocket(path: []const u8) !linux.fd_t {
    if (path.len >= 108) return error.PathTooLong;
    const rc = linux.socket(linux.AF.UNIX, linux.SOCK.STREAM, 0);
    if (linux.errno(rc) != .SUCCESS) return error.SocketCreate;
    const fd: linux.fd_t = @intCast(rc);

    var addr: linux.sockaddr.un = .{ .path = undefined };
    addr.family = linux.AF.UNIX;
    @memcpy(addr.path[0..path.len], path);
    addr.path[path.len] = 0;

    if (linux.errno(linux.connect(fd, @ptrCast(&addr), @sizeOf(linux.sockaddr.un))) != .SUCCESS) {
        _ = linux.close(fd);
        return error.SocketConnect;
    }
    return fd;
}

fn log(msg: []const u8) void {
    _ = linux.write(STDERR, msg.ptr, msg.len);
}
