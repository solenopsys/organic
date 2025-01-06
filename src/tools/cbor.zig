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

/// Represents a key-value map in CBOR
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
        try self.map.put(key, value);
    }

    /// Serialize this object map to the writer
    pub fn serialize(self: Self, writer: anytype) Error!void {
        const size = @as(u8, @intCast(self.map.count()));
        if (size < 24) {
            try writer.writeByte(0xA0 | size);
        } else {
            try writer.writeByte(0xB8);
            try writer.writeByte(size);
        }

        var it = self.map.iterator();
        while (it.next()) |entry| {
            try serializeString(entry.key_ptr.*, writer);
            try entry.value_ptr.*.serialize(writer);
        }
    }

    /// Free the memory used by this object map
    pub fn deinit(self: *Self) void {
        self.map.deinit();
    }
};
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
            const bytes = std.mem.toBytes(@as(u16, @intCast(value)));
            try writer.writeAll(&bytes);
        } else if (value <= std.math.maxInt(u32)) {
            try writer.writeByte(0x1A);
            const bytes = std.mem.toBytes(@as(u32, @intCast(value)));
            try writer.writeAll(&bytes);
        } else {
            try writer.writeByte(0x1B);
            const bytes = std.mem.toBytes(@as(u64, @intCast(value)));
            try writer.writeAll(&bytes);
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
            const bytes = std.mem.toBytes(@as(u16, @intCast(abs)));
            try writer.writeAll(&bytes);
        } else if (abs <= std.math.maxInt(u32)) {
            try writer.writeByte(0x3A);
            const bytes = std.mem.toBytes(@as(u32, @intCast(abs)));
            try writer.writeAll(&bytes);
        } else {
            try writer.writeByte(0x3B);
            const bytes = std.mem.toBytes(@as(u64, @intCast(abs)));
            try writer.writeAll(&bytes);
        }
    }
}

fn serializeFloat(value: f64, writer: anytype) Error!void {
    try writer.writeByte(0xFB);

    // Преобразуем в сетевой порядок байт (big-endian)
    const raw_bytes = @as(u64, @bitCast(value));
    const be_bytes = std.mem.nativeToBig(u64, raw_bytes);
    const bytes = std.mem.asBytes(&be_bytes);

    try writer.writeAll(bytes);
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
    var buf = std.ArrayList(u8).init(allocator);
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
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try CborValue.initInteger(-42).serialize(buf.writer());

    const expected = [_]u8{
        0x38, 41, // negative(41)
    };

    try std.testing.expectEqualSlices(u8, &expected, buf.items);
}

test "CBOR array" {
    const allocator = std.testing.allocator;
    var buf = std.ArrayList(u8).init(allocator);
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
