const std = @import("std");
const ptm = @import("ptm");

test "Read Image: 2x2 RGCB Image" {
    const file = try std.Io.Dir.cwd().openFile(
        std.testing.io,
        "./tests/images/2x2RGCB.png",
        .{},
    );
    defer file.close(std.testing.io);

    const image = try ptm.Utilities.Image.fromFile(
        std.testing.io,
        file,
        std.testing.allocator,
    );
    defer image.deinit(std.testing.allocator);

    const expected = [_]ptm.Utilities.Color{
        .{ .r = 255, .g = 0, .b = 0 },
        .{ .r = 0, .g = 255, .b = 0 },
        .{ .r = 0, .g = 255, .b = 255 },
        .{ .r = 0, .g = 0, .b = 255 },
    };

    try std.testing.expectEqualDeep(expected[0..], image.pixels.items);
}