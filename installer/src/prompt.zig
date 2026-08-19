const std = @import("std");

pub fn ask(reader: anytype, writer: anytype, buf: []u8, comptime question: []const u8) ![]const u8 {
    try writer.print(question ++ ": ", .{});
    const line = (try reader.readUntilDelimiterOrEof(buf, '\n')) orelse return error.EndOfInput;
    return std.mem.trim(u8, line, " \t\r");
}

pub fn askNonEmpty(reader: anytype, writer: anytype, buf: []u8, comptime question: []const u8) ![]const u8 {
    while (true) {
        const answer = try ask(reader, writer, buf, question);
        if (answer.len > 0) return answer;
        try writer.print("(required)\n", .{});
    }
}

pub fn askChoice(reader: anytype, writer: anytype, buf: []u8, comptime question: []const u8, options: []const []const u8) !usize {
    while (true) {
        try writer.print(question ++ ":\n", .{});
        for (options, 0..) |opt, i| {
            try writer.print("  {d}) {s}\n", .{ i + 1, opt });
        }
        const answer = try ask(reader, writer, buf, "choice");
        const n = std.fmt.parseInt(usize, answer, 10) catch continue;
        if (n >= 1 and n <= options.len) return n - 1;
        try writer.print("(pick 1-{d})\n", .{options.len});
    }
}

pub fn askYesNo(reader: anytype, writer: anytype, buf: []u8, comptime question: []const u8) !bool {
    while (true) {
        const answer = try ask(reader, writer, buf, question ++ " [y/n]");
        if (answer.len == 1 and (answer[0] == 'y' or answer[0] == 'Y')) return true;
        if (answer.len == 1 and (answer[0] == 'n' or answer[0] == 'N')) return false;
        try writer.print("(answer y or n)\n", .{});
    }
}

pub fn confirmTyped(reader: anytype, writer: anytype, buf: []u8, expected: []const u8) !bool {
    try writer.print("Type \"{s}\" to confirm, anything else cancels: ", .{expected});
    const line = (try reader.readUntilDelimiterOrEof(buf, '\n')) orelse return error.EndOfInput;
    return std.mem.eql(u8, std.mem.trim(u8, line, " \t\r"), expected);
}

test "ask returns a trimmed line and prints the prompt" {
    var input = std.io.fixedBufferStream("  hello world  \n");
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var buf: [256]u8 = undefined;

    const answer = try ask(input.reader(), output.writer(), &buf, "greeting");
    try std.testing.expectEqualStrings("hello world", answer);
    try std.testing.expectEqualStrings("greeting: ", output.items);
}

test "askNonEmpty reprompts on a blank line" {
    var input = std.io.fixedBufferStream("\nkhmer\n");
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var buf: [256]u8 = undefined;

    const answer = try askNonEmpty(input.reader(), output.writer(), &buf, "language");
    try std.testing.expectEqualStrings("khmer", answer);
    try std.testing.expect(std.mem.indexOf(u8, output.items, "(required)") != null);
}

test "askChoice validates the number is in range" {
    var input = std.io.fixedBufferStream("9\n2\n");
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var buf: [256]u8 = undefined;

    const idx = try askChoice(input.reader(), output.writer(), &buf, "edition", &.{ "general", "dev" });
    try std.testing.expectEqual(@as(usize, 1), idx);
}

test "askYesNo accepts y/n and rejects anything else" {
    var input = std.io.fixedBufferStream("maybe\nn\n");
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var buf: [256]u8 = undefined;

    const answer = try askYesNo(input.reader(), output.writer(), &buf, "proceed");
    try std.testing.expect(!answer);
}

test "confirmTyped requires an exact phrase match" {
    var input = std.io.fixedBufferStream("erase\n");
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var buf: [256]u8 = undefined;

    const confirmed = try confirmTyped(input.reader(), output.writer(), &buf, "ERASE /dev/sda");
    try std.testing.expect(!confirmed);
}

test "confirmTyped accepts the exact phrase" {
    var input = std.io.fixedBufferStream("ERASE /dev/sda\n");
    var output = std.ArrayList(u8).init(std.testing.allocator);
    defer output.deinit();
    var buf: [256]u8 = undefined;

    const confirmed = try confirmTyped(input.reader(), output.writer(), &buf, "ERASE /dev/sda");
    try std.testing.expect(confirmed);
}
