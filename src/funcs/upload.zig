const std = @import("std");

const upload_service = @import("../service/upload_service.zig");

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    upload_service.setHost("http://4ir.club");

    if (try upload_service.uploadFile(allocator, file, description)) |hash| {
        defer allocator.free(hash); // Добавляем освобождение хеша
        std.debug.print("File uploaded with hash: {s}\n", .{hash});
    }
}
