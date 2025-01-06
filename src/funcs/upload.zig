const std = @import("std");

pub fn upload(args: []const [:0]u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: upload <file> <description>\n", .{});
        return;
    }

    const file_relative = args[0];

    // Получаем текущую директорию
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.process.getCwd(&buf);

    // Получаем абсолютный путь к файлу
    const file = try std.fs.path.join(std.heap.page_allocator, &[_][]const u8{ cwd, file_relative });
    defer std.heap.page_allocator.free(file);

    const description = args[1];

    // Проверяем существование файла
    const file_exists = std.fs.cwd().access(file_relative, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{file_relative});
            return err;
        },
        else => return err,
    };
    _ = file_exists;

    var child = std.process.Child.init(&[_][]const u8{
        "bun",
        "index.ts",
        file,
        description,
    }, std.heap.page_allocator);

    child.cwd = "/home/alexstorm/evolve/experiments/kvio";

    try child.spawn();
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code == 0) {
                std.debug.print("\nUpload successful\n", .{});
            } else {
                std.debug.print("\nUpload failed with code: {d}\n", .{code});
            }
        },
        else => {
            std.debug.print("Process terminated abnormally\n", .{});
        },
    }
}
