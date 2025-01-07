const std = @import("std");

const heap = std.heap;

const commands = @import("../commands.zig").commands;

const TempLoginStorage = @import("../service/config.zig").TempLoginStorage;

pub fn showHelp(args: []const []const u8) !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var storage = try TempLoginStorage.init(allocator);
    // defer storage.deinit();

    if (storage.isLoged()) {
        var loaded_data = try storage.loadLogin();
        defer loaded_data.deinit(allocator);
        std.debug.print("Autorization: {s}\n", .{loaded_data.login});
    } else {
        std.debug.print("Autorization: not logged\n", .{});
    }

    // autorisation

    _ = args;
    std.debug.print("Commands:\n", .{});

    // Автоматическая генерация списка команд
    for (commands) |cmd| {
        std.debug.print("  {s:<12} - {s}\n", .{ cmd.name, cmd.description });
    }
}
