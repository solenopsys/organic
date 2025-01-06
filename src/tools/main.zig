const std = @import("std");

const upload_service = @import("upload_service.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    upload_service.setHost("http://4ir.club");

    if (try upload_service.uploadFile(allocator, "test.txt", "Test file")) |hash| {
        defer allocator.free(hash); // Добавляем освобождение хеша
        std.debug.print("File uploaded with hash: {s}\n", .{hash});
    }
}
