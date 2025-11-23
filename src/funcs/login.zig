const std = @import("std");

const TempLoginStorage = @import("../service/config.zig").TempLoginStorage;
const LoginData = @import("../service/config.zig").LoginData;
const gt = @import("../service/gen_token.zig");

pub fn login(args: []const []const u8) !void {
    const allocator = std.heap.page_allocator;

    const user_id = args[0];

    // Запрашиваем пароль через stdin
    std.debug.print("Enter password: ", .{});

    var password_buf: [256]u8 = undefined;
    var password_len: usize = 0;

    while (password_len < password_buf.len) {
        var byte_buf: [1]u8 = undefined;
        const n = std.posix.read(std.posix.STDIN_FILENO, &byte_buf) catch break;
        if (n == 0) break;
        if (byte_buf[0] == '\n') break;
        password_buf[password_len] = byte_buf[0];
        password_len += 1;
    }
    if (password_len == 0) return error.EmptyPassword;
    const password = password_buf[0..password_len];

    var storage = try TempLoginStorage.init(std.heap.page_allocator);

    if (storage.isLoged()) {
        std.debug.print("Already logged\n", .{});
        return;
    }

    const tokenRaw = try gt.getRefreshToken(std.heap.page_allocator, user_id, password);

    const token = gt.parseToken(std.heap.page_allocator, tokenRaw) catch |err| {
        std.debug.print("Error parsing token: {}\n", .{err});
        return err;
    };

    const current_time = std.time.timestamp();

    const exp_timestamp = current_time + @as(i64, token.expires_in * 1000); // время в милисекндах

    var login_data = try LoginData.init(allocator, token.access_token, user_id, exp_timestamp);
    try storage.saveLogin(login_data);

    std.debug.print("Login: {s}\n", .{login_data.login});

    defer login_data.deinit(allocator);
}
