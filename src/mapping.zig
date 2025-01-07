const upload = @import("funcs/upload.zig").upload;
const help = @import("funcs/help.zig").showHelp;
const login = @import("funcs/login.zig").login;
const logout = @import("funcs/logout.zig").logout;
const token = @import("funcs/token.zig").token;

const std = @import("std");

pub const Command = struct {
    name: []const u8,
    func: *const fn ([]const [:0]u8) anyerror!void, // изменил тип здесь
};

pub const mapping = [_]Command{
    .{ .name = "upload", .func = upload },
    .{ .name = "help", .func = help },
    .{ .name = "login", .func = login },
    .{ .name = "logout", .func = logout },
    .{ .name = "token", .func = token },
};
