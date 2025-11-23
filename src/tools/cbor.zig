const std = @import("std");

pub const Error = error{
    StringTooLong,
    IntegerTooLarge,
    InvalidValue,
    OutOfMemory,
};

/// Represents a CBOR value that can be serialized
pub const CborValue = union(enum) {
    const Self = @This();

    Null,
    Boolean: bool,
    Integer: i64,
    Float: f64,
    String: []const u8,
    Array: []const Self,
    Object: ObjectMap,

    /// Initialize a null CBOR value
    pub fn initNull() Self {
        return .Null;
    }

    /// Initialize a boolean CBOR value
    pub fn initBoolean(value: bool) Self {
        return .{ .Boolean = value };
    }

    /// Initialize an integer CBOR value
    pub fn initInteger(value: i64) Self {
        return .{ .Integer = value };
    }

    /// Initialize a floating point CBOR value
    pub fn initFloat(value: f64) Self {
        return .{ .Float = value };
    }

    /// Initialize a string CBOR value
    pub fn initString(value: []const u8) Self {
        return .{ .String = value };
    }

    /// Initialize an array CBOR value
    pub fn initArray(value: []const Self) Self {
        return .{ .Array = value };
    }

    /// Initialize an object CBOR value
    pub fn initObject(value: ObjectMap) Self {
        return .{ .Object = value };
    }

    /// Serialize this CBOR value to the writer
    pub fn serialize(self: Self, writer: anytype) Error!void {
        switch (self) {
            .Null => try writer.writeByte(0xF6),
            .Boolean => |b| try writer.writeByte(if (b) 0xF5 else 0xF4),
            .Integer => |i| try serializeInteger(i, writer),
            .Float => |f| try serializeFloat(f, writer),
            .String => |s| try serializeString(s, writer),
            .Array => |a| try serializeArray(a, writer),
            .Object => |o| try o.serialize(writer),
        }
    }
};

pub const ObjectMap = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    map: std.StringArrayHashMap(CborValue),

    /// Initialize a new empty object map
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .map = std.StringArrayHashMap(CborValue).init(allocator),
        };
    }

    /// Add a key-value pair to the map
    pub fn put(self: *Self, key: []const u8, value: CborValue) !void {
        // Создаем копию ключа
        const key_owned = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_owned);

        // Проверяем, есть ли уже такой ключ
        if (self.map.getKey(key)) |existing_key| {
            self.allocator.free(existing_key);
        }

        try self.map.put(key_owned, value);
    }

    /// Create a deep clone of this object map
    pub fn clone(self: Self) !Self {
        var new_map = Self.init(self.allocator);
        errdefer new_map.deinit();

        var it = self.map.iterator();
        while (it.next()) |entry| {
            try new_map.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        return new_map;
    }

    /// Serialize this object map to the writer
    pub fn serialize(self: Self, writer: anytype) Error!void {
        const size = @as(u8, @intCast(self.map.count()));
        try writer.writeByte(0xA0 | size);

        var it = self.map.iterator();
        while (it.next()) |entry| {
            try serializeString(entry.key_ptr.*, writer);
            try entry.value_ptr.*.serialize(writer);
        }
    }

    /// Free the memory used by this object map and its contents
    pub fn deinit(self: *Self) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            // Если значение - это объект, нужно освободить его тоже
            switch (entry.value_ptr.*) {
                .Object => |*obj| obj.deinit(),
                else => {},
            }
        }
        self.map.deinit();
    }
};

fn writeU16BigEndian(writer: anytype, value: u16) !void {
    const high_byte: u8 = @truncate(value >> 8);
    const low_byte: u8 = @truncate(value);
    try writer.writeByte(high_byte); // 0x13 for 5000
    try writer.writeByte(low_byte); // 0x88 for 5000
}

fn serializeInteger(value: i64, writer: anytype) Error!void {
    if (value >= 0) {
        // Положительные числа
        if (value <= 23) {
            try writer.writeByte(@intCast(value));
        } else if (value <= std.math.maxInt(u8)) {
            try writer.writeByte(0x18);
            try writer.writeByte(@intCast(value));
        } else if (value <= std.math.maxInt(u16)) {
            try writer.writeByte(0x19);
            try writeU16BigEndian(writer, @intCast(value));
        } else if (value <= std.math.maxInt(u32)) {
            try writer.writeByte(0x1A);
            const bytes = std.mem.toBytes(@as(u32, @intCast(value)));
            for (bytes) |byte| {
                try writer.writeByte(byte);
            }
        } else {
            try writer.writeByte(0x1B);
            const bytes = std.mem.toBytes(@as(u64, @intCast(value)));
            for (bytes) |byte| {
                try writer.writeByte(byte);
            }
        }
    } else {
        // Отрицательные числа
        const abs = if (value == std.math.minInt(i64))
            @as(u64, std.math.maxInt(i64)) + 1
        else
            @as(u64, @intCast(-value - 1));

        if (abs <= 23) {
            try writer.writeByte(@as(u8, @intCast(0x20 | abs)));
        } else if (abs <= std.math.maxInt(u8)) {
            try writer.writeByte(0x38);
            try writer.writeByte(@as(u8, @intCast(abs)));
        } else if (abs <= std.math.maxInt(u16)) {
            try writer.writeByte(0x39);
            const be_value = std.mem.nativeToBig(u16, @intCast(abs));
            try writer.writeAll(std.mem.asBytes(&be_value));
        } else if (abs <= std.math.maxInt(u32)) {
            try writer.writeByte(0x3A);
            const be_value = std.mem.nativeToBig(u32, @intCast(abs));
            try writer.writeAll(std.mem.asBytes(&be_value));
        } else {
            try writer.writeByte(0x3B);
            const be_value = std.mem.nativeToBig(u64, @intCast(abs));
            try writer.writeAll(std.mem.asBytes(&be_value));
        }
    }
}
fn serializeFloat(value: f64, writer: anytype) Error!void {
    try writer.writeByte(0xFB);

    const be_value = std.mem.nativeToBig(u64, @as(u64, @bitCast(value)));
    const be_bytes = std.mem.asBytes(&be_value);

    try writer.writeAll(be_bytes);
}

fn serializeString(value: []const u8, writer: anytype) Error!void {
    const len = value.len;
    if (len < 24) {
        try writer.writeByte(@as(u8, @intCast(0x60 | len)));
    } else if (len <= std.math.maxInt(u8)) {
        try writer.writeByte(0x78);
        try writer.writeByte(@as(u8, @intCast(len)));
    } else if (len <= std.math.maxInt(u16)) {
        try writer.writeByte(0x79);
        const bytes = std.mem.toBytes(@as(u16, @intCast(len)));
        try writer.writeAll(&bytes);
    } else {
        return Error.StringTooLong;
    }
    try writer.writeAll(value);
}

fn serializeArray(value: []const CborValue, writer: anytype) Error!void {
    const len = value.len;
    if (len < 24) {
        try writer.writeByte(@as(u8, @intCast(0x80 | len)));
    } else if (len <= std.math.maxInt(u8)) {
        try writer.writeByte(0x98);
        try writer.writeByte(@as(u8, @intCast(len)));
    } else if (len <= std.math.maxInt(u16)) {
        try writer.writeByte(0x99);
        const bytes = std.mem.toBytes(@as(u16, @intCast(len)));
        try writer.writeAll(&bytes);
    } else {
        return Error.StringTooLong;
    }

    for (value) |item| {
        try item.serialize(writer);
    }
}

test "CBOR float serialization" {
    const allocator = std.testing.allocator;

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    const pi: f64 = 3.14159;
    try CborValue.initFloat(pi).serialize(buf.writer());

    // Проверяем первый байт - маркер double
    try std.testing.expectEqual(@as(u8, 0xFB), buf.items[0]);

    // Преобразуем байты обратно в число
    const number_bytes = buf.items[1..9];
    const stored_bits = std.mem.bigToNative(u64, std.mem.bytesToValue(u64, number_bytes));
    const stored_value = @as(f64, @bitCast(stored_bits));

    // Проверяем с допустимой погрешностью
    try std.testing.expectApproxEqAbs(pi, stored_value, 0.00001);
}

test "CBOR serialization" {
    const allocator = std.testing.allocator;

    // Создаем объект
    var obj = ObjectMap.init(allocator);
    defer obj.deinit();

    // Добавляем различные типы данных
    try obj.put("null", CborValue.initNull());
    try obj.put("bool", CborValue.initBoolean(true));
    try obj.put("int", CborValue.initInteger(42));
    try obj.put("float", CborValue.initFloat(3.14));
    try obj.put("string", CborValue.initString("test"));

    // Сериализуем в буфер
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    try CborValue.initObject(obj).serialize(buf.writer());

    // Проверяем результат (шестнадцатеричные значения)
    const expected = [_]u8{
        0xa5, // map(5)
        0x64, 'n', 'u', 'l', 'l', // text(4)
        0xf6, // null
        0x64, 'b', 'o', 'o', 'l', // text(4)
        0xf5, // true
        0x63, 'i', 'n', 't', // text(3)
        0x18, 42, // unsigned(42)
        0x65, 'f', 'l', 'o', 'a', 't', // text(5)
        0xfb, 0x40, 0x09, 0x1e, 0xb8, 0x51, 0xeb, 0x85, 0x1f, // double(3.14)
        0x66, 's', 't', 'r', 'i', 'n', 'g', // text(6)
        0x64, 't', 'e', 's', 't', // text(4)
    };

    try std.testing.expectEqualSlices(u8, &expected, buf.items);
}

test "CBOR negative integers" {
    const allocator = std.testing.allocator;
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    try CborValue.initInteger(-42).serialize(buf.writer());

    const expected = [_]u8{
        0x38, 41, // negative(41)
    };

    try std.testing.expectEqualSlices(u8, &expected, buf.items);
}

test "CBOR array" {
    const allocator = std.testing.allocator;
    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    const arr = [_]CborValue{
        CborValue.initInteger(1),
        CborValue.initString("test"),
        CborValue.initBoolean(true),
    };

    try CborValue.initArray(&arr).serialize(buf.writer());

    const expected = [_]u8{
        0x83, // array(3)
        0x01, // unsigned(1)
        0x64, 't', 'e', 's', 't', // text(4)
        0xf5, // true
    };

    try std.testing.expectEqualSlices(u8, &expected, buf.items);
}

test "Complex CBOR serialization" {
    const allocator = std.testing.allocator;
    var root = ObjectMap.init(allocator);
    defer root.deinit();

    // Наполняем metadata
    {
        var metadata = ObjectMap.init(allocator);
        try metadata.put("version", CborValue.initInteger(2));
        try metadata.put("created_at", CborValue.initString("2024-01-07T12:00:00Z"));
        try metadata.put("is_valid", CborValue.initBoolean(true));
        try root.put("metadata", CborValue.initObject(metadata));
    }

    // Создаем mixed_array
    const mixed_array = [_]CborValue{
        CborValue.initNull(),
        CborValue.initInteger(-123),
        CborValue.initFloat(2.718281828),
        CborValue.initString("hello"),
        CborValue.initBoolean(false),
    };
    try root.put("mixed_array", CborValue.initArray(&mixed_array));

    // Наполняем settings
    {
        var settings = ObjectMap.init(allocator);
        try settings.put("debug_mode", CborValue.initBoolean(true));
        try settings.put("max_retries", CborValue.initInteger(3));
        try settings.put("timeout_ms", CborValue.initInteger(5000));

        const log_levels = [_]CborValue{
            CborValue.initString("error"),
            CborValue.initString("warning"),
            CborValue.initString("info"),
        };
        try settings.put("log_levels", CborValue.initArray(&log_levels));
        try root.put("settings", CborValue.initObject(settings));
    }

    try root.put("app_name", CborValue.initString("test_app"));
    try root.put("port", CborValue.initInteger(8080));
    try root.put("enabled", CborValue.initBoolean(true));

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();
    try CborValue.initObject(root).serialize(buf.writer());

    // fmt: off
    const expected = [_]u8{
        0xA6,
        // "metadata"
        0x68,
        'm',
        'e',
        't',
        'a',
        'd',
        'a',
        't',
        'a',
        0xA3,
        // "version"
        0x67,
        'v',
        'e',
        'r',
        's',
        'i',
        'o',
        'n',
        0x02,
        // "created_at"
        0x6A,
        'c',
        'r',
        'e',
        'a',
        't',
        'e',
        'd',
        '_',
        'a',
        't',
        0x74,
        '2',
        '0',
        '2',
        '4',
        '-',
        '0',
        '1',
        '-',
        '0',
        '7',
        'T',
        '1',
        '2',
        ':',
        '0',
        '0',
        ':',
        '0',
        '0',
        'Z',
        // "is_valid"
        0x68,
        'i',
        's',
        '_',
        'v',
        'a',
        'l',
        'i',
        'd',
        0xF5,

        // "mixed_array"
        0x6B,
        'm',
        'i',
        'x',
        'e',
        'd',
        '_',
        'a',
        'r',
        'r',
        'a',
        'y',
        0x85,
        0xF6, // null
        0x38, 0x7A, // -123
        0xFB, 0x40, 0x05, 0xBF, 0x0A, 0x8B, 0x04, 0x91, 0x9B, // float(2.718281828)
        0x65, 'h', 'e', 'l', 'l', 'o', // "hello"
        0xF4, // false

        // "settings"
        0x68,
        's',
        'e',
        't',
        't',
        'i',
        'n',
        'g',
        's',
        0xA4,
        // "debug_mode"
        0x6A,
        'd',
        'e',
        'b',
        'u',
        'g',
        '_',
        'm',
        'o',
        'd',
        'e',
        0xF5, // true
        // "max_retries"
        0x6B,
        'm',
        'a',
        'x',
        '_',
        'r',
        'e',
        't',
        'r',
        'i',
        'e',
        's',
        0x03, // 3
        // "timeout_ms"
        0x6A,
        't',
        'i',
        'm',
        'e',
        'o',
        'u',
        't',
        '_',
        'm',
        's',
        0x19, 0x13, 0x88, // 5000 -> big-endian 0x13, 0x88

        // "log_levels"
        0x6A, 'l',  'o',
        'g',  '_',  'l',
        'e',  'v',  'e',
        'l',  's',  0x83,
        0x65, 'e',  'r',
        'r',  'o',  'r',
        0x67, 'w',  'a',
        'r',  'n',  'i',
        'n',  'g',  0x64,
        'i',  'n',  'f',
        'o',

        // "app_name"
         0x68, 'a',
        'p',  'p',  '_',
        'n',  'a',  'm',
        'e',  0x68, 't',
        'e',  's',  't',
        '_',  'a',  'p',
        'p',

        // "port"
         0x64, 'p',
        'o',  'r',  't',
        0x19, 0x1F, 0x90, // 8080 -> big-endian 0x1F, 0x90

        // "enabled"
        0x67, 'e',  'n',
        'a',  'b',  'l',
        'e',  'd',
        0xF5, // true
    };
    // fmt: on

    try std.testing.expectEqualSlices(u8, &expected, buf.items);
}

test "CBOR serialization with nested object 2" {
    const allocator = std.testing.allocator;

    // Создаем корневой объект
    var root = ObjectMap.init(allocator);
    defer root.deinit(); // root.deinit() очистит все вложенные объекты

    { // Создаем scope для nested
        var nested = ObjectMap.init(allocator);
        try nested.put("flag_true", CborValue.initBoolean(true));
        try nested.put("flag_false", CborValue.initBoolean(false));
        try nested.put("empty_str", CborValue.initString(""));

        // После этой строки nested становится частью root
        try root.put("nested", CborValue.initObject(nested));
    } // nested уничтожится здесь, но это OK, так как содержимое уже передано root

    try root.put("answer", CborValue.initInteger(42));
    try root.put("pi_approx", CborValue.initFloat(3.14159));

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    try CborValue.initObject(root).serialize(buf.writer());

    // fmt: off
    const expected = [_]u8{
        0xa3, // map(3)
        0x66, 'n', 'e', 's', 't', 'e', 'd', // text(6) "nested"
        0xa3, // map(3)
        0x69, 'f', 'l', 'a', 'g', '_', 't', 'r', 'u', 'e', // text(9) "flag_true"
        0xf5, // true
        0x6a, 'f', 'l', 'a', 'g', '_', 'f', 'a', 'l', 's', 'e', // text(10) "flag_false"
        0xf4, // false
        0x69, 'e', 'm', 'p', 't', 'y', '_', 's', 't', 'r', // text(9) "empty_str"
        0x60, // text(0) ""
        0x66, 'a', 'n', 's', 'w', 'e', 'r', // text(6) "answer"
        0x18, 0x2a, // unsigned(42)
        0x69, 'p', 'i', '_', 'a', 'p', 'p', 'r', 'o', 'x', // text(9) "pi_approx"
        0xfb, 0x40, 0x09, 0x21, 0xf9, 0xf0, 0x1b, 0x86, 0x6e, // double(3.14159)
    };
    // fmt: on

    try std.testing.expectEqualSlices(u8, &expected, buf.items);
}

test "Мetadata CBOR serialization" {
    const allocator = std.testing.allocator;

    var meta_obj = ObjectMap.init(allocator);
    defer meta_obj.deinit();

    // Моделируем метаданные файла
    try meta_obj.put("name", CborValue.initString("test.txt"));
    try meta_obj.put("description", CborValue.initString("Test file"));
    try meta_obj.put("size", CborValue.initInteger(451));
    try meta_obj.put("contentType", CborValue.initString("text/plain"));

    var buf = std.array_list.Managed(u8).init(allocator);
    defer buf.deinit();

    try CborValue.initObject(meta_obj).serialize(buf.writer());

    // fmt: off
    const expected = [_]u8{
        0xA4, // map(4)
        0x64, 'n', 'a', 'm', 'e', // text(4) "name"
        0x68, 't', 'e', 's', 't', '.', 't', 'x', 't', // text(8) "test.txt"
        0x6b, 'd', 'e', 's', 'c', 'r', 'i', 'p', 't', 'i', 'o', 'n', // text(11) "description"
        0x69, 'T', 'e', 's', 't', ' ', 'f', 'i', 'l', 'e', // text(9) "Test file"
        0x64, 's', 'i', 'z', 'e', // text(4) "size"
        0x19, 0x01, 0xc3, // unsigned(451)
        0x6b, 'c', 'o', 'n', 't', 'e', 'n', 't', 'T', 'y', 'p', 'e', // text(11) "contentType"
        0x6a, 't', 'e', 'x', 't', '/', 'p', 'l', 'a', 'i', 'n', // text(10) "text/plain"
    };
    // fmt: on

    try std.testing.expectEqualSlices(u8, &expected, buf.items);

    // Дополнительная проверка размера
    if (meta_obj.map.get("size")) |size| {
        switch (size) {
            .Integer => |value| try std.testing.expectEqual(@as(i64, 451), value),
            else => try std.testing.expect(false),
        }
    } else {
        try std.testing.expect(false);
    }

    // Проверяем каждое поле отдельно чтобы легче найти где ошибка
    for (buf.items, 0..) |byte, i| {
        if (byte != expected[i]) {
            std.debug.print("Mismatch at position {}: expected 0x{X:0>2}, got 0x{X:0>2}\n", .{ i, expected[i], byte });
            break;
        }
    }
}
