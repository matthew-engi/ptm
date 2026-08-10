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

test "Read Image -> PTM: PTM Image" {
    const file = try std.Io.Dir.cwd().openFile(
        std.testing.io,
        "./tests/images/ptm.png",
        .{},
    );
    defer file.close(std.testing.io);

    const image = try ptm.Helpers.Image.fromFile(
        std.testing.io,
        file,
        std.testing.allocator,
    );
    defer image.deinit(std.testing.allocator);

    var buffer: [400000]u8 = undefined;
    const uniques = try image.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    var writer = ptm.Writer(.u8, .u24).init(std.testing.allocator);
    const header = writer.getHeader(255, 255, 1, uniques);
    var io_writer = std.Io.Writer.fixed(&buffer);

    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.rle},
        &.{
            &.{image},
        },
    );
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

    const uniques = try image.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    var writer = ptm.Writer(.u8, .u8).init(std.testing.allocator);
    const header = writer.getHeader(2, 2, 30, uniques);
    var io_writer = std.Io.Writer.fixed(&buffer);
    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.default},
        &.{
            &.{image},
        },
    );

    const resp: [23]u8 = .{
        2, 2, 30, 4, 255, 0, 0, 0, 255, 0, 0, 255, 
        255, 0, 0, 255, 0, 0, 1, 0, 1, 2, 3
    };

    try std.testing.expectEqualDeep(resp[0..], buffer[0..io_writer.end]);
}

test "Image to PTM: DEFAULT 2x2 BLACK" {
    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var buffer: [1024]u8 = undefined;
    var writer = ptm.Writer(.u8, .u8).init(std.testing.allocator);
    var io_writer = std.Io.Writer.fixed(&buffer);
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    const header = writer.getHeader(2, 2, 15, uniques);
    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.default},
        &.{
            &.{img},
        },
    );

    const resp: [14]u8 = .{2, 2, 15, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0};
    try std.testing.expectEqualDeep(resp[0..], buffer[0..io_writer.end]);
}

test "Image to PTM: RLE 2x 2x2 BLACK" {
    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var buffer: [1024]u8 = undefined;
    var writer = ptm.Writer(.u8, .u8).init(std.testing.allocator);
    var io_writer = std.Io.Writer.fixed(&buffer);
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    const header = writer.getHeader(2, 2, 15, uniques);
    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.rle},
        &.{
            &.{img, img},
        },
    );

    const resp: [14]u8 = .{2, 2, 15, 1, 0, 0, 0, 1, 0, 2, 0, 4, 0, 4};
    try std.testing.expectEqualDeep(resp[0..], buffer[0..io_writer.end]);
}

test "Image to PTM: RLE x2 2x2 BLACK" {
    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var buffer: [1024]u8 = undefined;
    var writer = ptm.Writer(.u8, .u8).init(std.testing.allocator);
    var io_writer = std.Io.Writer.fixed(&buffer);
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    const header = writer.getHeader(2, 2, 15, uniques);
    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.rle, .rle},
        &.{
            &.{img},
            &.{img},
        },
    );

    const resp: [17]u8 = .{2, 2, 15, 1, 0, 0, 0, 1, 0, 1, 0, 4, 1, 0, 1, 0, 4};
    try std.testing.expectEqualDeep(resp[0..], buffer[0..io_writer.end]);
}

test "Back to Back: RLE 2x 2x2 BLACK" {
    var buffer: [14]u8 = undefined;

    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var writer = ptm.Writer(.u8, .u8).init(std.testing.allocator);
    var io_writer = std.Io.Writer.fixed(&buffer);
    
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    var header = writer.getHeader(2, 2, 15, uniques);
    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.rle},
        &.{
            &.{img, img},
        },
    );

    var io_reader = std.Io.Reader.fixed(&buffer);
    const reader = ptm.Reader(.u8, .u8).init(std.testing.allocator);
    header = try reader.getHeader(&io_reader);

    var ptmimg = try reader.loadWithHeader(
        header, 
        &io_reader
    );
    defer ptmimg.deinit(std.testing.allocator);

    try std.testing.expectEqual(ptmimg.header.width, 2);
}

test "Back to Back: DIFF 2x 2x2 BLACK" {
    var buffer: [30]u8 = undefined;

    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var writer = ptm.Writer(.u8, .u8).init(std.testing.allocator);
    var io_writer = std.Io.Writer.fixed(&buffer);
    
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    var header = writer.getHeader(2, 2, 15, uniques);
    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.diff},
        &.{
            &.{img, img},
        },
    );

    var io_reader = std.Io.Reader.fixed(&buffer);
    const reader = ptm.Reader(.u8, .u8).init(std.testing.allocator);
    header = try reader.getHeader(&io_reader);

    var ptmimg = try reader.loadWithHeader(
        header, 
        &io_reader
    );
    defer ptmimg.deinit(std.testing.allocator);

    try std.testing.expectEqual(2, ptmimg.header.height);
}

test "Back to Back: DEFAULT 2x 2x2 BLACK" {
    var buffer: [18]u8 = undefined;

    const img: ptm.Helpers.Image = .{
        .pixels = try ptm.Helpers.Matrix(ptm.Helpers.Color, ptm.Helpers.Color.BLACK).init(
            std.testing.allocator, 2, 2
        )
    };
    defer img.deinit(std.testing.allocator);

    var writer = ptm.Writer(.u8, .u8).init(std.testing.allocator);
    var io_writer = std.Io.Writer.fixed(&buffer);
    
    const uniques = try img.pixels.getUniques(std.testing.allocator);
    defer std.testing.allocator.free(uniques);

    var header = writer.getHeader(2, 2, 15, uniques);
    try writer.writeWithHeader(
        header,
        &io_writer,
        &.{.default},
        &.{
            &.{img, img},
        },
    );

    var io_reader = std.Io.Reader.fixed(&buffer);
    const reader = ptm.Reader(.u8, .u8).init(std.testing.allocator);
    header = try reader.getHeader(&io_reader);

    var ptmimg = try reader.loadWithHeader(
        header, 
        &io_reader
    );
    defer ptmimg.deinit(std.testing.allocator);

    try std.testing.expectEqual(ptmimg.header.width, 2);
}