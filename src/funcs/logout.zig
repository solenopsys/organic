const std = @import("std");
const TempLoginStorage = @import("../service/config.zig").TempLoginStorage;

pub fn logout(args: []const []const u8) !void {
    _ = args;
    var storage = try TempLoginStorage.init(std.heap.page_allocator);
    try storage.clear();

    std.debug.print("Logout is done\n", .{});
}
