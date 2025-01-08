const std = @import("std");
const upload_service = @import("../service/upload_service.zig");
const getTokenFromStorage = @import("../service/gen_berrer.zig").getTokenFromStorage;
const Token = @import("../service/gen_token.zig").Token;

pub fn token(args: []const [:0]u8) !void {
    _ = args;

    // defer bearerToken.deinit(&bearerToken, allocator); // Используем метод deinit из структуры Token
    const t = try getTokenFromStorage();

    std.debug.print("Bearer token: {s}\n", .{t});
}
