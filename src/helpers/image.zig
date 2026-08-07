//! Author: matthew.engi
//! Description: An image struct containing data of an image (Stack)

const std = @import("std");
const zigimg = @import("zigimg");

const Png = zigimg.formats.png.PNG;
const Color = @import("color.zig").Color;
const Matrix = @import("./matrix.zig").Matrix;

pub const Image = struct {
    const Self = @This();

    // Pixel data of the image
    pub const Canvas = Matrix(Color, Color.BLACK);
    pixels: Canvas,

    /// Initializes memory on the heap for an Image
    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) Self {
        const matrix = try Canvas.init(allocator, height, width);
        return .{ .pixels = matrix };
    }

    /// Frees up memory allocated for an image
    pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
        self.pixels.deinit(allocator);
    }

    /// Returns the signed difference between two images of same size
    pub fn diff(allocator: std.mem.Allocator, lhs: *const Self, rhs: *const Self) Self {
        var diffarray = allocator.alloc(Color, lhs.pixels.items.len);
        for (lhs.pixels.items, 0..) |pixel, i| {
            diffarray[i] = Color.diff(pixel, rhs.pixels.items[i]);
        }

        return .{ .pixels = Canvas {
            .columns = lhs.pixels.columns,
            .rows = lhs.pixels.rows,
            .items = diffarray
        }};
    }

    /// Imports data from png files into an Image struct
    pub fn fromFile(io: std.Io, file: std.Io.File, allocator: std.mem.Allocator) !Self {
        var buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
        var stream = zigimg.io.ReadStream.initFile(io, file, &buffer);
        
        // Start reading the file
        var image = try Png.readImage(allocator, &stream);
        defer image.deinit(allocator);
        try image.convert(allocator, .rgb24);

        // Convert into Self (take ownership of data)
        const pixels = try Canvas.fromSlice(
            allocator, image.width, image.height, image.pixels.asBytes(),
        );

        return .{ .pixels = pixels };
    }
};