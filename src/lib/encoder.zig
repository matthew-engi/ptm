//! Author: matthew.engi
//! Description: Compression mechanism for PTM files (responsible for data part)

const std = @import("std");
const PTM = @import("../mod.zig");
const Color = @import("../helpers/color.zig").Color;
const Image = @import("../helpers/image.zig").Image;

/// Encoding modes
pub const Modes = enum(u8) {
    /// Default encoding
    /// Best use: Varied colors in no pattern
    default,

    /// Run-length encoding
    /// Best use: Repeating colors in long chains
    /// https://en.wikipedia.org/wiki/Run-length_encoding
    rle,
};

pub fn Encoding(
    comptime depth: ?PTM.COLOR_DEPTH,
) type {
    return struct {
        /// Compression mapping (Mode -> Compression algorithm)
        /// returns ![]u8, unknown sizes of bytes, depends on algorithm
        pub fn encode(allocator: std.mem.Allocator, mode: Modes, data: []const Image, header: *const PTM.Header, writer: *std.Io.Writer) !void {
            var map = std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(depth)).init(allocator);
            defer map.deinit(); // Remove the memory allocated to the mapping after encoding

            // Create the color mapping (Color -> Index)
            for (header.colors, 0..) |c, i| {
                try map.put(c, @intCast(i));
            }

            try writer.writeInt(PTM.MODE_TYPE, @intFromEnum(mode), PTM.ENDIANNESS);
            try writer.writeInt(PTM.LENGTH_TYPE, @intCast(data.len), PTM.ENDIANNESS);

            try switch (mode) {
                .default => Algorithms(depth).Default.comp(data, header, writer, &map),
                .rle => Algorithms(depth).RLE.comp(data, header, writer, &map),
            };
        }

        /// Decompression mapping (Mode -> Decompression algorithm)
        /// returns ![]Image unknown amount of images, derived
        pub fn decode(allocator: std.mem.Allocator, mode: Modes, header: *const PTM.Header, reader: *std.Io.Reader) ![]Image {
            var map = std.AutoHashMap(PTM.COLOR_DEPTH.Type(depth), Color).init(allocator);
            defer map.deinit(); // Remove the memory allocated to the mapping after decoding

            // Create the color mapping (Index -> Color)
            for (header.colors, 0..) |c, i| {
                try map.put(@intCast(i), c);
            }

            const sprite = try switch (mode) {
                .default => Algorithms(depth).Default.decomp(allocator, header, reader, &map),
                .rle => Algorithms(depth).RLE.decomp(allocator, header, reader, &map),
            };

            return sprite;
        }
    };
}

/// Algorithms to decompress rows of sprites
pub fn Algorithms(comptime depth: ?PTM.COLOR_DEPTH) type {
    return struct {
        // CHECKPOINT: DEFAULT ALGORITHM
        /// Encodes each individual pixel as an index
        pub const Default = struct {
            const Self = @This();

            /// Compression method for the Default algorithm
            fn comp(data: []const Image, _: *const PTM.Header, writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(depth))) !void {

                // Writing the images
                for (data) |image| {
                    for (image.pixels.items) |pixel| {
                        const index = map.get(pixel) orelse return error.UnknownIndex; // Turning Color -> Index
                        try writer.writeInt(PTM.COLOR_DEPTH.Type(depth), index, PTM.ENDIANNESS);
                    }
                }
            }

            /// Decompression method for the Default algorithm
            fn decomp(allocator: std.mem.Allocator, header: *const PTM.Header, reader: *std.Io.Reader, map: *std.AutoHashMap(PTM.COLOR_DEPTH.Type(depth), Color)) ![]Image {

                // Find amount of images
                const num = try reader.takeInt(PTM.LENGTH_TYPE, PTM.ENDIANNESS);
                const capacity = @as(usize, header.height) * @as(usize, header.width);

                // ALLOC: Allocated memory for storing the images within the sprite + reading buffer (size of img)
                var sprites = try PTM.Sprite.init(allocator, num);
                errdefer sprites.deinit(allocator);
                const buffer = try allocator.alloc(PTM.COLOR_DEPTH.Type(depth), capacity);
                defer allocator.free(buffer);

                // Enumerate through every image
                for (0..num) |_| {
                    try reader.readSliceEndian(PTM.COLOR_DEPTH.Type(depth), buffer, PTM.ENDIANNESS);

                    // ALLOC: Allocated memory to store the colors inside of the image
                    var pixels = try allocator.alloc(Color, capacity);
                    errdefer allocator.free(pixels);

                    // Loop through every pixel
                    for (buffer, 0..) |c, i| {
                        const color = map.get(c) orelse return error.UnknownColor;
                        pixels[i] = color;
                    }

                    sprites.add(.{ .pixels = .{
                        .columns = header.width,
                        .rows = header.height,
                        .items = pixels,
                    } });
                }

                return sprites.data;
            }
        };

        // CHECKPOINT: RLE ALGORITHM
        /// Encodes the pixel index with the repeated amount after
        pub const RLE = struct {
            const Self = @This();

            /// Amount of similar pixels encoded
            pub const AMOUNT_TYPE = u8;

            /// RLE Entry struct
            const Entry = struct { idx: PTM.COLOR_DEPTH.Type(depth), len: AMOUNT_TYPE };

            /// Reads the next color entry
            fn nextEntry(reader: *std.Io.Reader) !Entry {
                const idx = try reader.takeInt(PTM.COLOR_DEPTH.Type(depth), PTM.ENDIANNESS);
                const len = try reader.takeInt(AMOUNT_TYPE, PTM.ENDIANNESS);
                return .{ .idx = idx, .len = len };
            }

            /// Writes a color entry
            fn writeEntry(writer: *std.Io.Writer, color_index: PTM.COLOR_DEPTH.Type(depth), amount: AMOUNT_TYPE) !void {
                try writer.writeInt(PTM.COLOR_DEPTH.Type(depth), color_index, PTM.ENDIANNESS);
                try writer.writeInt(AMOUNT_TYPE, amount, PTM.ENDIANNESS);
            }

            /// Compression method for the RLE algorithm
            fn comp(data: []const Image, _: *const PTM.Header, writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(depth))) !void {

                // Writing the images
                for (data) |image| {
                    var since: AMOUNT_TYPE = 1;
                    var previous_i = map.get(image.pixels.items[0]) orelse return error.UnknownColor;

                    for (image.pixels.items[1..]) |pixel| {
                        const new_i = map.get(pixel) orelse return error.UnknownColor;
                        if (new_i != previous_i or since == std.math.maxInt(AMOUNT_TYPE)) {
                            try writeEntry(writer, previous_i, since);
                            previous_i = new_i;
                            since = 1;
                        } else {
                            since += 1;
                        }
                    }
                    try writeEntry(writer, previous_i, since);
                }
            }

            /// Decompression method for the Default algorithm
            fn decomp(allocator: std.mem.Allocator, header: *const PTM.Header, reader: *std.Io.Reader, map: *std.AutoHashMap(PTM.COLOR_DEPTH.Type(depth), Color)) ![]Image {

                // Find amount of images
                const num = try reader.takeInt(PTM.LENGTH_TYPE, PTM.ENDIANNESS);
                const capacity = @as(usize, header.width) * @as(usize, header.height);

                // ALLOC: Allocate memory for the images
                var imgs = try std.ArrayList(Image).initCapacity(allocator, num);
                errdefer {
                    for (imgs.items) |img| img.deinit(allocator);
                    imgs.deinit(allocator);
                }

                while (imgs.items.len < num) {
                    // ALLOC: Allocate memory for the color streams
                    var colors = try allocator.alloc(Color, capacity);
                    errdefer allocator.free(colors);

                    var index: usize = 0;
                    while (index < capacity) {
                        const entry = try nextEntry(reader);
                        const color = map.get(entry.idx) orelse return error.UnknownIndex;

                        for (0..entry.len) |_| {
                            colors[index] = color;
                            index += 1;
                        }
                    }

                    try imgs.append(allocator, .{
                        .pixels = .{
                            .columns = header.width,
                            .rows = header.height,
                            .items = colors,
                        },
                    });
                }

                return try imgs.toOwnedSlice(allocator);
            }
        };
    };
}
