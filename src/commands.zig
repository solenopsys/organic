const Command = struct {
    name: []const u8,

    description: []const u8,
};

pub const commands = [_]Command{
    .{
        .name = "help",
        .description = "Shows this help message",
    },
    .{
        .name = "login",
        .description = "Login to server [username]",
    },

    .{
        .name = "logout",
        .description = "Logout (forget token)",
    },
    .{
        .name = "token",
        .description = "Show token",
    },
    .{
        .name = "upload",
        .description = "Upload file to server [file] [description]",
    },
    .{
        .name = "container",
        .description = "Build container [tag] [dockerfile]",
    },
};
