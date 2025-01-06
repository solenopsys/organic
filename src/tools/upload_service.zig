const std = @import("std");

const builtin = @import("builtin");

const cbor = @import("cbor.zig");

// Global variable for host
var HOST: []const u8 = "http://localhost";

pub fn setHost(host: []const u8) void {
    HOST = host;
}

fn doHttpRequest(allocator: std.mem.Allocator, method: std.http.Method, path: []const u8, body: ?[]const u8) ![]u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    const url = try std.fmt.allocPrint(allocator, "{s}{s}", .{ HOST, path });
    defer allocator.free(url);

    const res = try client.fetch(.{
        .location = .{ .url = url },
        .method = method,
        .payload = body,
        .headers = .{
            .content_type = .{ .override = "application/octet-stream" },
        },
        .response_storage = .{ .dynamic = &response },
    });

    if (res.status != .ok) {
        return error.HttpError;
    }

    return try response.toOwnedSlice();
}

pub fn generateHash(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var hash_buf: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash_buf, .{});

    var hex_hash: [64]u8 = undefined;
    for (hash_buf, 0..) |byte, i| {
        _ = try std.fmt.bufPrint(hex_hash[i * 2 .. i * 2 + 2], "{x:0>2}", .{byte});
    }

    return try allocator.dupe(u8, &hex_hash);
}

pub fn contentTypeFromExtension(extension: ?[]const u8) []const u8 {
    if (extension) |ext| {
        if (std.mem.eql(u8, ext, "js")) return "application/javascript";
        if (std.mem.eql(u8, ext, "ts")) return "application/typescript";
        if (std.mem.eql(u8, ext, "html")) return "text/html";
        if (std.mem.eql(u8, ext, "css")) return "text/css";
        if (std.mem.eql(u8, ext, "json")) return "application/json";
        if (std.mem.eql(u8, ext, "xml")) return "application/xml";
        if (std.mem.eql(u8, ext, "py")) return "text/x-python";
        if (std.mem.eql(u8, ext, "java")) return "text/x-java";
        if (std.mem.eql(u8, ext, "c")) return "text/x-c";
        if (std.mem.eql(u8, ext, "h")) return "text/x-c";
        if (std.mem.eql(u8, ext, "cpp")) return "text/x-c++";
        if (std.mem.eql(u8, ext, "hpp")) return "text/x-c++";
        if (std.mem.eql(u8, ext, "cs")) return "text/x-csharp";
        if (std.mem.eql(u8, ext, "php")) return "text/x-php";
        if (std.mem.eql(u8, ext, "rb")) return "text/x-ruby";
        if (std.mem.eql(u8, ext, "go")) return "text/x-go";
        if (std.mem.eql(u8, ext, "svg")) return "image/svg+xml";
        if (std.mem.eql(u8, ext, "rs")) return "text/x-rust";
        if (std.mem.eql(u8, ext, "md")) return "text/markdown";
        if (std.mem.eql(u8, ext, "txt")) return "text/plain";
    }
    return "text/plain";
}

pub fn uploadBlob(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const hash = try generateHash(allocator, data);
    defer allocator.free(hash); // Освобождаем hash в конце функции

    std.debug.print("DATA : {s}\n", .{data});

    const key = try std.fmt.allocPrint(allocator, "blob.{s}", .{hash});
    defer allocator.free(key);

    const save_result = try save(allocator, key, data);
    allocator.free(save_result);

    return try allocator.dupe(u8, hash); // Создаем новую копию для возврата
}

pub fn setMeta(allocator: std.mem.Allocator, hash: []const u8, meta: cbor.CborValue) ![]u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try meta.serialize(buf.writer());

    const key = try std.fmt.allocPrint(allocator, "meta.{s}", .{hash});
    defer allocator.free(key);

    // print items

    std.debug.print("key: {s}\n", .{key});
    std.debug.print("content: {s}\n", .{buf.items});

    const result = try save(allocator, key, buf.items);
    defer allocator.free(result);

    return try allocator.dupe(u8, key);
}

// Save function
pub fn save(allocator: std.mem.Allocator, key: []const u8, content: []const u8) ![]u8 {
    const path = try std.fmt.allocPrint(allocator, "/kvs/io/{s}", .{key});
    defer allocator.free(path);

    return try doHttpRequest(allocator, .PUT, path, content);
}

pub fn uploadFile(allocator: std.mem.Allocator, file_path: []const u8, description: []const u8) !?[]u8 {
    const file_content = try std.fs.cwd().readFileAlloc(allocator, file_path, std.math.maxInt(usize));
    defer allocator.free(file_content);

    const hash = try uploadBlob(allocator, file_content);
    defer allocator.free(hash); // Освобождаем исходный hash перед возвратом

    const file_name = std.fs.path.basename(file_path);
    const extension = std.fs.path.extension(file_path);

    var meta_obj = cbor.ObjectMap.init(allocator);
    try meta_obj.put("name", cbor.CborValue.initString(file_name));
    try meta_obj.put("description", cbor.CborValue.initString(description));
    try meta_obj.put("size", cbor.CborValue.initInteger(@intCast(file_content.len)));
    try meta_obj.put("contentType", cbor.CborValue.initString(contentTypeFromExtension(extension)));
    defer meta_obj.deinit();

    const meta_result = try setMeta(allocator, hash, cbor.CborValue.initObject(meta_obj));
    allocator.free(meta_result);

    return try allocator.dupe(u8, hash); // Создаем финальную копию для возврата
}
