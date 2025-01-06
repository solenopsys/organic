const Command = struct {
    name: []const u8,

    description: []const u8,
};

pub const commands = [_]Command{
    .{
        .name = "upload",
        .description = "Upload file to server [file] [description]",
    },
    .{
        .name = "help",
        .description = "Shows this help message",
    },
    .{
        .name = "login",
        .description = "Login to server [username] [password]",
    },
};
