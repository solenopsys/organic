const std = @import("std");

const TempLoginStorage = @import("../service/config.zig").TempLoginStorage;
const LoginData = @import("../service/config.zig").LoginData;
const gt = @import("../service/gen_token.zig");

pub fn login(args: []const []const u8) !void {
    const allocator = std.heap.page_allocator;

    const user_id = args[0];

    // Запрашиваем пароль через stdin
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Enter password: ", .{});

    var password_buf: [256]u8 = undefined;
    var password_size: usize = undefined;

    if (stdin.reader().readUntilDelimiterOrEof(&password_buf, '\n')) |maybe_password| {
        if (maybe_password) |pw| {
            password_size = pw.len;
        } else {
            return error.EmptyPassword;
        }
    } else |err| {
        return err;
    }

    const password = password_buf[0..password_size];

    var storage = try TempLoginStorage.init(std.heap.page_allocator);

    if (storage.isLoged()) {
        std.debug.print("Already logged\n", .{});
        return;
    }

    const tokenRaw = try gt.getToken(std.heap.page_allocator, user_id, password);

    const token = gt.parseToken(std.heap.page_allocator, tokenRaw) catch |err| {
        std.debug.print("Error parsing token: {}\n", .{err});
        return err;
    };

    const current_time = std.time.timestamp();

    const exp_timestamp = current_time + @as(i64, token.expires_in);

    var login_data = try LoginData.init(allocator, token.access_token, user_id, exp_timestamp);
    try storage.saveLogin(login_data);

    std.debug.print("Login: {s}\n", .{login_data.login});

    defer login_data.deinit(allocator);
}
