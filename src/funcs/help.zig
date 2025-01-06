const std = @import("std");

const commands = @import("../commands.zig").commands;

pub fn showHelp(args: []const []const u8) !void {
    _ = args;
    std.debug.print("Commands:\n", .{});

    // Автоматическая генерация списка команд
    for (commands) |cmd| {
        std.debug.print("  {s:<12} - {s}\n", .{ cmd.name, cmd.description });
    }
}
