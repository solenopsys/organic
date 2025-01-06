const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const json = std.json;
const process = std.process;

pub const LoginData = struct {
    version: u8,
    token: []const u8,
    login: []const u8,
    expired_date: i64,

    pub fn init(alloc: std.mem.Allocator, login: []const u8) !LoginData {
        return LoginData{
            .login = try alloc.dupe(u8, login),
        };
    }

    pub fn deinit(self: *LoginData, alloc: std.mem.Allocator) void {
        alloc.free(self.login);
    }
};

pub const TempLoginStorage = struct {
    allocator: std.mem.Allocator,
    temp_path: []const u8,

    pub fn init(allocator: std.mem.Allocator) !TempLoginStorage {
        // Получаем путь к временной директории используя новый API
        var arena = heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        const tmp_dir_path = process.getEnvVarOwned(arena.allocator(), "TMPDIR") catch "/tmp";

        // Создаём уникальное имя файла
        var path_buffer: [fs.MAX_PATH_BYTES]u8 = undefined;
        const temp_path = try std.fmt.bufPrint(&path_buffer, "{s}/organic_config.json", .{tmp_dir_path});

        return TempLoginStorage{
            .allocator = allocator,
            .temp_path = try allocator.dupe(u8, temp_path),
        };
    }

    pub fn clear(self: *TempLoginStorage) void {
        try fs.deleteFileAbsolute(self.temp_path);
    }

    pub fn saveLogin(self: *TempLoginStorage, login_data: LoginData) !void {
        const file = try fs.createFileAbsolute(self.temp_path, .{
            .read = true,
            .truncate = true,
        });
        defer file.close();

        // Создаём JSON строку
        const json_string = try json.stringifyAlloc(self.allocator, login_data, .{});
        defer self.allocator.free(json_string);

        // Записываем в файл
        try file.writeAll(json_string);
    }

    pub fn loadLogin(self: *TempLoginStorage) !LoginData {
        const file = try fs.openFileAbsolute(self.temp_path, .{});
        defer file.close();

        // Читаем весь файл
        const content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(content);

        // Парсим JSON используя новый API
        var parsed = try json.parseFromSlice(LoginData, self.allocator, content, .{});
        defer parsed.deinit();

        // Создаём копию данных, так как parsed.value будет освобождена при parsed.deinit()
        return try LoginData.init(self.allocator, parsed.value.login);
    }
};

// Пример использования:
pub fn main() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Создаём хранилище
    var storage = try TempLoginStorage.init(allocator);
    defer storage.deinit();

    // Создаём данные для сохранения
    var login_data = try LoginData.init(allocator, "testuser");
    defer login_data.deinit(allocator);

    // Сохраняем в JSON
    try storage.saveLogin(login_data);

    // Загружаем из JSON
    var loaded_data = try storage.loadLogin();
    defer loaded_data.deinit(allocator);

    // Проверяем
    std.debug.print("Loaded login: {s}\n", .{loaded_data.login});
}
