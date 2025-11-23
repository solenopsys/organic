const std = @import("std");
const upload_service = @import("./upload_service.zig");
const TempLoginStorage = @import("./config.zig").TempLoginStorage;
const Token = @import("./gen_token.zig").Token;
pub const BerrerToken = struct { access_token: []u8, token_type: []u8 };

pub fn getBearerToken(
    allocator: std.mem.Allocator,
    refresh: []const u8,
) ![]u8 {
    // Формируем JSON для тела запроса
    const json_buf = try std.json.Stringify.valueAlloc(allocator, .{
        .refresh_token = refresh,
    }, .{});
    defer allocator.free(json_buf);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("http://auth.solenopsys.org/auth/token/bearer");

    var req = try client.request(.POST, uri, .{
        .headers = .{
            .content_type = .{ .override = "application/json" },
        },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = json_buf.len };
    var body_writer = try req.sendBodyUnflushed(&.{});
    try body_writer.writer.writeAll(json_buf);
    try body_writer.end();
    try req.connection.?.flush();

    var redirect_buffer: [8192]u8 = undefined;
    var response = try req.receiveHead(&redirect_buffer);

    std.debug.print("Status: {d}\n", .{@intFromEnum(response.head.status)});

    // Читаем тело ответа
    var reader = response.reader(&.{});
    return try reader.allocRemaining(allocator, .unlimited);
}

pub fn parseBerrerToken(allocator: std.mem.Allocator, tokenJson: []const u8) !BerrerToken {
    const parsed = try std.json.parseFromSlice(
        BerrerToken,
        allocator,
        tokenJson,
        .{},
    );
    defer parsed.deinit();

    // Создаем копии строк, чтобы их можно было безопасно освободить позже
    const access_token = try allocator.dupe(u8, parsed.value.access_token);
    const token_type = try allocator.dupe(u8, parsed.value.token_type);

    return BerrerToken{ .access_token = access_token, .token_type = token_type };
}

pub fn getTokenFromStorage() ![]u8 {
    const allocator = std.heap.page_allocator;
    var storage = try TempLoginStorage.init(allocator);
    // defer storage.deinit(); // Added defer to clean up storage

    if (!storage.isLoged()) {
        std.debug.print("Not logged, need: o login <user> <password>\n", .{});
        return error.NotLoggedIn;
    }

    const login_data = try storage.loadLogin();
    // If login_data requires freeing, add defer for it

    if (login_data.expired_date < std.time.timestamp()) {
        std.debug.print("Token expired\n", .{});
        return error.TokenExpired;
    }

    const bearerBinary = try getBearerToken(allocator, login_data.token);
    defer allocator.free(bearerBinary);

    const bearerToken = try parseBerrerToken(allocator, bearerBinary);
    // defer bearerToken.deinit(allocator); // Assuming Token has a deinit method

    // Return a copy of the access token that the caller is responsible for freeing
    return try allocator.dupe(u8, bearerToken.access_token);
}
