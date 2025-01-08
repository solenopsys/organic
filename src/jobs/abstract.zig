const std = @import("std");

// Базовый тип сообщения
pub const JobMessage = struct {
    allocator: std.mem.Allocator,
};

pub const JobResult = struct {
    allocator: std.mem.Allocator,
};
