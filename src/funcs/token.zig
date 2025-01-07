const std = @import("std");

const upload_service = @import("../service/upload_service.zig");
const TempLoginStorage = @import("../service/config.zig").TempLoginStorage;

pub fn token(args: []const [:0]u8) !void {
    _ = args;

    var storage = try TempLoginStorage.init(std.heap.page_allocator);

    if (!storage.isLoged()) {
        std.debug.print("Not logged need: o login <user> <password>\n", .{});
        return;
    }

    const login_data = try storage.loadLogin();

    if (login_data.expired_date < std.time.timestamp()) {
        std.debug.print("Token expired\n", .{});
        return;
    }

    // print token

    std.debug.print("Token: {s}\n", .{login_data.token});
}
