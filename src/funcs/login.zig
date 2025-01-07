const std = @import("std");

// const fetch = @import("../tools/http.zig").fetch;

pub fn login(args: []const []const u8) !void {
    _ = args;
    // const url = args[0];

    // //print url
    // std.debug.print("URL: {s}\n", .{url});
    // const response = fetch(url) catch |err| {
    //     // Получаем и выводим информацию о стеке
    //     if (@errorReturnTrace()) |trace| {
    //         std.debug.dumpStackTrace(trace.*);
    //     }

    //     // Дополнительно можно вывести базовую информацию об ошибке
    //     std.debug.print("Ошибка1: {s}\n", .{@errorName(err)});
    //     return error.FetchFailed;
    // };
    // std.debug.print("Response: {s}\n", .{response});
}

pub fn main() void {}
