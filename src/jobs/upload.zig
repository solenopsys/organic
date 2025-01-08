const std = @import("std");
const upload_service = @import("../service/upload_service.zig");
const TempLoginStorage = @import("../service/config.zig").TempLoginStorage;
const getTokenFromStorage = @import("../service/gen_berrer.zig").getTokenFromStorage;

pub const UploadResult = struct {
    hash: []const u8,

    pub fn deinit(self: *UploadResult, allocator: std.mem.Allocator) void {
        allocator.free(self.hash);
    }
};

// Сообщение для загрузки
pub const UploadMessage = struct {
    allocator: std.mem.Allocator,
    file_path: []const u8,
    description: []const u8,

    pub fn init(allocator: std.mem.Allocator, file: []const u8, desc: []const u8) UploadMessage {
        return UploadMessage{
            .allocator = allocator,
            .file_path = file,
            .description = desc,
        };
    }
};

// Обработчик загрузки
pub const UploadJob = struct {
    pub fn execute(msg: UploadMessage) !UploadResult {
        var storage = try TempLoginStorage.init(msg.allocator);
        // defer storage.deinit();

        if (!storage.isLoged()) {
            return error.NotLoggedIn;
        }

        const t = try getTokenFromStorage();

        // Проверяем существование файла
        std.fs.cwd().access(msg.file_path, .{}) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.debug.print("File not found: {s}\n", .{msg.file_path});
                    return err;
                },
                else => return err,
            }
        };

        upload_service.setHost("http://4ir.club");

        const allocator = std.heap.page_allocator;

        const berrer = try std.fmt.allocPrint(allocator, "Bearer {s}", .{t});

        if (try upload_service.uploadFile(msg.allocator, msg.file_path, msg.description, berrer)) |hash| {
            return UploadResult{ .hash = hash };
        }

        return error.UploadFailed;
    }
};
