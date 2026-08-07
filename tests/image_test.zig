const std = @import("std");
const ptm = @import("ptm");

test "Read Image: 2x2 RGCB Image" {
    const file = try std.Io.Dir.cwd().openFile(
        std.testing.io,
        "./tests/images/2x2RGCB.png",
        .{},
    );
    defer file.close(std.testing.io);

    const image = try ptm.Helpers.Image.fromFile(
        std.testing.io,
        file,
        std.testing.allocator,
    );
    defer image.deinit(std.testing.allocator);

    const expected = [_]ptm.Helpers.Color{
        .{ .r = 255, .g = 0, .b = 0 },
        .{ .r = 0, .g = 255, .b = 0 },
        .{ .r = 0, .g = 255, .b = 255 },
        .{ .r = 0, .g = 0, .b = 255 },
    };

    try std.testing.expectEqualDeep(expected[0..], image.pixels.items);
}

test "Image to PTM: DEFAULT 2x2 RGCB Image" {
    const file = try std.Io.Dir.cwd().openFile(
        std.testing.io,
        "./tests/images/2x2RGCB.png",
        .{},
    );
    defer file.close(std.testing.io);

    const image = try ptm.Helpers.Image.fromFile(
        std.testing.io,
        file,
        std.testing.allocator,
    );
    defer image.deinit(std.testing.allocator);

    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    const uniques = try image.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    const header = ptm.Writer.getHeader(2, 2, 30, uniques);
    try ptm.Writer.writeWithHeader(
        header,
        &writer,
        std.testing.allocator,
        &.{.default},
        &.{
            &.{image},
        },
    );

    const resp: [23]u8 = .{
        2, 2, 30, 4, 255, 0, 0, 0, 255, 0, 0, 255, 
        255, 0, 0, 255, 0, 0, 1, 0, 1, 2, 3
    };

    try std.testing.expectEqualDeep(resp[0..], buffer[0..writer.end]);
}

test "Image to PTM: DEFAULT 2x2 BLACK" {
    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    const header = ptm.Writer.getHeader(2, 2, 15, uniques);
    try ptm.Writer.writeWithHeader(
        header,
        &writer,
        std.testing.allocator,
        &.{.default},
        &.{
            &.{img},
        },
    );

    const resp: [14]u8 = .{2, 2, 15, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0};
    try std.testing.expectEqualDeep(resp[0..], buffer[0..writer.end]);
}

test "Image to PTM: RLE 2x 2x2 BLACK" {
    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    const header = ptm.Writer.getHeader(2, 2, 15, uniques);
    try ptm.Writer.writeWithHeader(
        header,
        &writer,
        std.testing.allocator,
        &.{.rle},
        &.{
            &.{img, img},
        },
    );

    const resp: [14]u8 = .{2, 2, 15, 1, 0, 0, 0, 1, 0, 2, 0, 4, 0, 4};
    try std.testing.expectEqualDeep(resp[0..], buffer[0..writer.end]);
}

test "Image to PTM: RLE x2 2x2 BLACK" {
    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var buffer: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    const header = ptm.Writer.getHeader(2, 2, 15, uniques);
    try ptm.Writer.writeWithHeader(
        header,
        &writer,
        std.testing.allocator,
        &.{.rle, .rle},
        &.{
            &.{img},
            &.{img},
        },
    );

    const resp: [17]u8 = .{2, 2, 15, 1, 0, 0, 0, 1, 0, 1, 0, 4, 1, 0, 1, 0, 4};
    try std.testing.expectEqualDeep(resp[0..], buffer[0..writer.end]);
}