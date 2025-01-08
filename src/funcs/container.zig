const std = @import("std");

pub fn container(args: []const [:0]u8) !void {
    if (args.len < 1) {
        std.debug.print("Usage: upload [tag] [dockerfile]\n", .{});
        return;
    }

    const tag = args[0];

    // Получаем текущую директорию
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.process.getCwd(&buf);

    // Use var instead of const since we may modify it
    var dockerfile: []const u8 = undefined;
    if (args.len > 1) {
        dockerfile = args[1];
    } else {
        // default dockerfile
        dockerfile = try std.fs.path.join(std.heap.page_allocator, &[_][]const u8{ cwd, "Dockerfile" });
        defer std.heap.page_allocator.free(dockerfile);
    }

    // Проверяем существование файла
    const file_exists = std.fs.cwd().access(dockerfile, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{dockerfile});
            return err;
        },
        else => return err,
    };
    _ = file_exists;

    var child = std.process.Child.init(&[_][]const u8{
        "buildah",
        "bud",
        "-t",
        tag,
        "-f",
        dockerfile,
    }, std.heap.page_allocator);

    try child.spawn();
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code == 0) {
                std.debug.print("\nBuild successful\n", .{});
            } else {
                std.debug.print("\nBuild failed with code: {d}\n", .{code});
            }
        },
        else => {
            std.debug.print("Process terminated abnormally\n", .{});
        },
    }
}
