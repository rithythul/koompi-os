const std = @import("std");

pub const Value = union(enum) {
    string: []const u8,
    boolean: bool,
    integer: i64,
    string_array: []const []const u8,
};

pub const Table = std.StringHashMap(Value);
pub const Doc = std.StringHashMap(Table);

pub const ParseError = error{
    UnexpectedToken,
    UnterminatedArray,
    UnterminatedString,
} || std.mem.Allocator.Error;

pub fn deinitDoc(doc: *Doc) void {
    var table_it = doc.valueIterator();
    while (table_it.next()) |table| {
        var value_it = table.valueIterator();
        while (value_it.next()) |value| {
            if (value.* == .string_array) doc.allocator.free(value.string_array);
        }
        table.deinit();
    }
    doc.deinit();
}

fn parseQuotedString(raw: []const u8) ParseError![]const u8 {
    var s = std.mem.trimRight(u8, raw, " \t");
    if (std.mem.endsWith(u8, s, ",")) s = std.mem.trimRight(u8, s[0 .. s.len - 1], " \t");
    if (s.len < 2 or s[0] != '"' or s[s.len - 1] != '"') return error.UnterminatedString;
    return s[1 .. s.len - 1];
}

fn parseInlineArray(allocator: std.mem.Allocator, inner: []const u8) ParseError![]const []const u8 {
    var items = std.ArrayList([]const u8).init(allocator);
    errdefer items.deinit();
    var it = std.mem.splitScalar(u8, inner, ',');
    while (it.next()) |piece| {
        const p = std.mem.trim(u8, piece, " \t");
        if (p.len == 0) continue;
        try items.append(try parseQuotedString(p));
    }
    return items.toOwnedSlice();
}

/// `text` must outlive the returned `Doc`: string values and section/key
/// names are slices into `text`, never copied.
pub fn parse(allocator: std.mem.Allocator, text: []const u8) ParseError!Doc {
    var doc = Doc.init(allocator);
    errdefer deinitDoc(&doc);

    const top_gop = try doc.getOrPut("");
    if (!top_gop.found_existing) top_gop.value_ptr.* = Table.init(allocator);
    var current_table: *Table = top_gop.value_ptr;

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (line.len == 0 or line[0] == '#') continue;

        if (line[0] == '[') {
            const end = std.mem.indexOfScalar(u8, line, ']') orelse return error.UnexpectedToken;
            const gop = try doc.getOrPut(line[1..end]);
            if (!gop.found_existing) gop.value_ptr.* = Table.init(allocator);
            current_table = gop.value_ptr;
            continue;
        }

        const eq = std.mem.indexOfScalar(u8, line, '=') orelse return error.UnexpectedToken;
        const key = std.mem.trim(u8, line[0..eq], " \t");
        const rest = std.mem.trim(u8, line[eq + 1 ..], " \t");

        if (rest.len == 0) return error.UnexpectedToken;

        if (rest[0] == '[' and std.mem.endsWith(u8, rest, "]")) {
            const value = try parseInlineArray(allocator, rest[1 .. rest.len - 1]);
            try current_table.put(key, .{ .string_array = value });
        } else if (rest[0] == '[') {
            var items = std.ArrayList([]const u8).init(allocator);
            errdefer items.deinit();
            const closed = while (lines.next()) |item_raw| {
                const item_line = std.mem.trim(u8, item_raw, " \t\r");
                if (item_line.len == 0 or item_line[0] == '#') continue;
                if (item_line[0] == ']') break true;
                try items.append(try parseQuotedString(item_line));
            } else false;
            if (!closed) return error.UnterminatedArray;
            try current_table.put(key, .{ .string_array = try items.toOwnedSlice() });
        } else if (std.mem.eql(u8, rest, "true")) {
            try current_table.put(key, .{ .boolean = true });
        } else if (std.mem.eql(u8, rest, "false")) {
            try current_table.put(key, .{ .boolean = false });
        } else if (rest[0] == '"') {
            try current_table.put(key, .{ .string = try parseQuotedString(rest) });
        } else {
            const n = std.fmt.parseInt(i64, rest, 10) catch return error.UnexpectedToken;
            try current_table.put(key, .{ .integer = n });
        }
    }

    return doc;
}

test "parses sections, strings, booleans, integers, and multi-line arrays" {
    const allocator = std.testing.allocator;
    const text =
        \\# a comment
        \\[apt]
        \\backports = true
        \\
        \\[snapper]
        \\timeline_limit_daily = 10
        \\
        \\[koompi-repo]
        \\packages = [
        \\    "khmer-fonts",
        \\    "khmer-input-method",
        \\]
        \\
        \\[account]
        \\model = "sudo-user"
        \\
    ;
    var doc = try parse(allocator, text);
    defer deinitDoc(&doc);

    try std.testing.expect(doc.get("apt").?.get("backports").?.boolean);
    try std.testing.expectEqual(@as(i64, 10), doc.get("snapper").?.get("timeline_limit_daily").?.integer);
    try std.testing.expectEqualStrings("sudo-user", doc.get("account").?.get("model").?.string);

    const packages = doc.get("koompi-repo").?.get("packages").?.string_array;
    try std.testing.expectEqual(@as(usize, 2), packages.len);
    try std.testing.expectEqualStrings("khmer-fonts", packages[0]);
    try std.testing.expectEqualStrings("khmer-input-method", packages[1]);
}

test "parses an inline single-line array" {
    const allocator = std.testing.allocator;
    var doc = try parse(allocator, "[x]\npackages = [\"a\", \"b\"]\n");
    defer deinitDoc(&doc);
    const packages = doc.get("x").?.get("packages").?.string_array;
    try std.testing.expectEqual(@as(usize, 2), packages.len);
    try std.testing.expectEqualStrings("b", packages[1]);
}

test "unterminated multi-line array is an error" {
    const allocator = std.testing.allocator;
    const result = parse(allocator, "[x]\npackages = [\n    \"a\",\n");
    try std.testing.expectError(error.UnterminatedArray, result);
}

test "a line without '=' or a section header is an error" {
    const allocator = std.testing.allocator;
    const result = parse(allocator, "not valid toml");
    try std.testing.expectError(error.UnexpectedToken, result);
}
