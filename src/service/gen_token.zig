const std = @import("std");

const Token = struct { access_token: []u8, token_type: []u8, expires_in: u32 };

// Объявляем функцию getToken с правильной сигнатурой
pub fn getToken(
    allocator: std.mem.Allocator,
    client_id: []const u8,
    client_secret: []const u8,
) ![]u8 {
    // Формируем JSON для тела запроса
    var json_buf = std.ArrayList(u8).init(allocator);
    defer json_buf.deinit();

    try std.json.stringify(.{
        .client_id = client_id,
        .client_secret = client_secret,
    }, .{}, json_buf.writer());

    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var response = std.ArrayList(u8).init(allocator);

    const res = try client.fetch(
        .{
            .location = .{
                .url = "http://auth.solenopsys.org/auth/token",
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
