const std = @import("std");

const help = @import("funcs/help.zig").showHelp;

const mapping = @import("mapping.zig").mapping;

// Список всех доступных команд

pub fn main() !void {
    // Проверяем наличие команды
    if (mapping.len == 0) {
        std.debug.print("No commands found\n", .{});
        return;
    }

    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    if (args.len < 2) {
        try help(&[_][]const u8{});
        return;
    }

    const command = args[1];

    // Поиск команды в списке
    for (mapping) |cmd| {
        if (std.mem.eql(u8, command, cmd.name)) {
            try cmd.func(args[2..]);
            return;
        }
    }

    std.debug.print("Unknown command: {s}\n", .{command});
    try help(&[_][]const u8{});
}
