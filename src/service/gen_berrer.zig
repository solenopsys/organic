const std = @import("std");
const upload_service = @import("./upload_service.zig");
const TempLoginStorage = @import("./config.zig").TempLoginStorage;
const Token = @import("./gen_token.zig").Token;
pub const BerrerToken = struct { access_token: []u8, token_type: []u8 };

pub fn getBearerToken(
    allocator: std.mem.Allocator,
    refresh: []const u8,
) ![]u8 { //todo
    // Формируем JSON для тела запроса
    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();

    try std.json.stringify(.{
        .refresh_token = refresh,
    }, .{}, json_buf.writer());

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var response = std.ArrayList(u8).init(allocator);

    const res = try client.fetch(
        .{
            .location = .{
                .url = "http://auth.solenopsys.org/auth/token/bearer",
            },
            .method = .POST,
            .payload = json_buf.items,
            .headers = .{
                .content_type = .{ .override = "application/json" },
            },
            .response_storage = .{ .dynamic = &response },
        },
    );

    // Выводим ответ
    std.debug.print("Status: {d}\n", .{res.status});

    const result = try allocator.dupe(u8, response.items);
    response.deinit();
    return result;
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
