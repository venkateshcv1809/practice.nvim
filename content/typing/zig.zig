const std = @import("std");

pub const User = struct {
    id: u64,
    name: []const u8,
    email: ?[]const u8 = null,

    pub fn greet(self: User) void {
        const host = self.email orelse "local";
        std.debug.print("hello {s} @ {s}\n", .{ self.name, host });
    }
};

pub fn first(comptime T: type, items: []const T) !T {
    if (items.len == 0) return error.Empty;
    return items[0];
}

pub fn total(values: []const u32) u32 {
    var sum: u32 = 0;
    for (values) |n| {
        sum += n;
    }
    return sum;
}

pub fn load(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    try list.appendSlice("hello ");
    try list.appendSlice(name);
    return list.toOwnedSlice();
}

pub fn demo() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const user = User{ .id = 7, .name = "ada", .email = "ada@ex.com" };
    user.greet();

    const names = [_][]const u8{ "ada", "grace" };
    const head = try first([]const u8, &names);
    const text = try load(allocator, head);
    defer allocator.free(text);
}
