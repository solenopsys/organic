const std = @import("std");

pub const Token = struct { access_token: []u8, token_type: []u8, expires_in: u32 };

// Объявляем функцию getToken с правильной сигнатурой
pub fn getRefreshToken(
    allocator: std.mem.Allocator,
    client_id: []const u8,
    client_secret: []const u8,
) ![]u8 {
    // Формируем JSON для тела запроса
    const json_buf = try std.json.Stringify.valueAlloc(allocator, .{
        .client_id = client_id,
        .client_secret = client_secret,
    }, .{});
    defer allocator.free(json_buf);

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("http://auth.solenopsys.org/auth/token/refresh");

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

    var reader = response.reader(&.{});
    return try reader.allocRemaining(allocator, .unlimited);
}

pub fn parseToken(allocator: std.mem.Allocator, tokenJson: []const u8) !Token {
    const parsed = try std.json.parseFromSlice(
        Token,
        allocator,
        tokenJson,
        .{},
    );
    defer parsed.deinit();

    // Создаем копии строк, чтобы их можно было безопасно освободить позже
    const access_token = try allocator.dupe(u8, parsed.value.access_token);
    const token_type = try allocator.dupe(u8, parsed.value.token_type);

    return Token{
        .access_token = access_token,
        .token_type = token_type,
        .expires_in = parsed.value.expires_in,
    };
}
