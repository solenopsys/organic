const std = @import("std");
const upload_service = @import("../service/upload_service.zig");
const TempLoginStorage = @import("../service/config.zig").TempLoginStorage;

const UploadMessage = @import("../jobs/upload.zig").UploadMessage;
const UploadJob = @import("../jobs/upload.zig").UploadJob;

pub fn upload(args: []const [:0]u8) !void {
    if (args.len < 2) {
        std.debug.print("Usage: upload <file> <description>\n", .{});
        return;
    }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Получаем абсолютный путь
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.process.getCwd(&buf);
    const file = try std.fs.path.join(allocator, &[_][]const u8{ cwd, args[0] });
    defer allocator.free(file);

    const msg = UploadMessage.init(allocator, file, args[1]);

    var result = try UploadJob.execute(msg);
    defer result.deinit(allocator);
    std.debug.print("File uploaded with hash: {s}\n", .{result.hash});
}
