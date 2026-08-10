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

    /// Difference encoding
    /// Best use: Similar sprites (minor changes)
    diff,
};

pub fn Encoding(
    comptime color_depth: ?PTM.COLOR_DEPTH,
    comptime dim_depth: ?PTM.DIM_DEPTH,
) type {
    return struct {
        const algo = Algorithms(color_depth, dim_depth);

        /// Compression mapping (Mode -> Compression algorithm)
        /// returns ![]u8, unknown sizes of bytes, depends on algorithm
        pub fn encode(allocator: std.mem.Allocator, mode: Modes, data: []const Image, header: *const PTM.Header(dim_depth), writer: *std.Io.Writer) !void {
            var map = std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(color_depth)).init(allocator);
            defer map.deinit(); // Remove the memory allocated to the mapping after encoding

            // Create the color mapping (Color -> Index)
            for (header.colors, 0..) |c, i| {
                try map.put(c, @intCast(i));
            }

            try writer.writeInt(PTM.MODE_TYPE, @intFromEnum(mode), PTM.ENDIANNESS);
            try writer.writeInt(PTM.LENGTH_TYPE, @intCast(data.len), PTM.ENDIANNESS);

            try switch (mode) {
                .default => algo.Default.comp(allocator, data, header, writer, &map),
                .rle => algo.RLE.comp(allocator, data, header, writer, &map),
                .diff => algo.DIFF.comp(allocator, data, header, writer, &map),
            };
        }

        /// Decompression mapping (Mode -> Decompression algorithm)
        /// returns ![]Image unknown amount of images, derived
        pub fn decode(allocator: std.mem.Allocator, mode: Modes, header: *const PTM.Header(dim_depth), reader: *std.Io.Reader) ![]Image {
            var map = std.AutoHashMap(PTM.COLOR_DEPTH.Type(color_depth), Color).init(allocator);
            defer map.deinit(); // Remove the memory allocated to the mapping after decoding

            // Create the color mapping (Index -> Color)
            for (header.colors, 0..) |c, i| {
                try map.put(@intCast(i), c);
            }

            const sprite = try switch (mode) {
                .default => algo.Default.decomp(allocator, header, reader, &map),
                .rle => algo.RLE.decomp(allocator, header, reader, &map),
                .diff => algo.DIFF.decomp(allocator, header, reader, &map),
            };

            return sprite;
        }
    };
}

/// Algorithms to decompress rows of sprites
pub fn Algorithms(
    comptime color_depth: ?PTM.COLOR_DEPTH,
    comptime dim_depth: ?PTM.DIM_DEPTH,
) type {

    return struct {
        fn indexToColors(
            allocator: std.mem.Allocator, 
            map: *std.AutoHashMap(PTM.COLOR_DEPTH.Type(color_depth), Color), 
            data: []PTM.COLOR_DEPTH.Type(color_depth)
        ) ![]Color {
            var colors = try allocator.alloc(Color, data.len);
            errdefer allocator.free(colors);

            for (data, 0..) |idx, i| {
                colors[i] = map.get(idx) orelse {
                    std.debug.print("{any}", .{idx});
                    return error.UnknownIndex;
                };
            } 
            return colors;
        }

        // CHECKPOINT: DEFAULT ALGORITHM
        /// Encodes each individual pixel as an index
        pub const Default = struct {
            const Self = @This();

            /// Compression method for the Default algorithm
            fn comp(_: std.mem.Allocator, data: []const Image, _: *const PTM.Header(dim_depth), writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(color_depth))) !void {

                // Writing the images
                for (data) |image| {
                    for (image.pixels.items) |pixel| {
                        const index = map.get(pixel) orelse return error.UnknownIndex; // Turning Color -> Index
                        try writer.writeInt(PTM.COLOR_DEPTH.Type(color_depth), index, PTM.ENDIANNESS);
                    }
                }
            }

            /// Decompression method for the Default algorithm
            fn decomp(allocator: std.mem.Allocator, header: *const PTM.Header(dim_depth), reader: *std.Io.Reader, map: *std.AutoHashMap(PTM.COLOR_DEPTH.Type(color_depth), Color)) ![]Image {

                // Find amount of images
                const num = try reader.takeInt(PTM.LENGTH_TYPE, PTM.ENDIANNESS);
                const capacity = @as(usize, header.height) * @as(usize, header.width);

                // ALLOC: Allocated memory for storing the images within the sprite + reading buffer (size of img)
                var sprites = try PTM.Sprite.init(allocator, num);
                errdefer sprites.deinit(allocator);
                const buffer = try allocator.alloc(PTM.COLOR_DEPTH.Type(color_depth), capacity);
                defer allocator.free(buffer);

                // Enumerate through every image
                for (0..num) |_| {
                    try reader.readSliceAll(buffer);

                    // ALLOC: Allocated memory to store the colors inside of the image
                    const colors = try indexToColors(allocator, map, buffer);
                    errdefer allocator.free(colors);

                    sprites.add(.{ .pixels = .{
                        .columns = header.width,
                        .rows = header.height,
                        .items = colors,
                    }});
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
            const Entry = struct { idx: PTM.COLOR_DEPTH.Type(color_depth), len: AMOUNT_TYPE };

            /// Reads the next color entry
            fn nextEntry(reader: *std.Io.Reader) !Entry {
                const idx = try reader.takeInt(PTM.COLOR_DEPTH.Type(color_depth), PTM.ENDIANNESS);
                const len = try reader.takeInt(AMOUNT_TYPE, PTM.ENDIANNESS);
                return .{ .idx = idx, .len = len };
            }

            /// Writes a color entry
            fn writeEntry(writer: *std.Io.Writer, color_index: PTM.COLOR_DEPTH.Type(color_depth), amount: AMOUNT_TYPE) !void {
                try writer.writeInt(PTM.COLOR_DEPTH.Type(color_depth), color_index, PTM.ENDIANNESS);
                try writer.writeInt(AMOUNT_TYPE, amount, PTM.ENDIANNESS);
            }

            /// Compression method for the RLE algorithm
            fn comp(_: std.mem.Allocator, data: []const Image, _: *const PTM.Header(dim_depth), writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(color_depth))) !void {

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
            fn decomp(allocator: std.mem.Allocator, header: *const PTM.Header(dim_depth), reader: *std.Io.Reader, map: *std.AutoHashMap(PTM.COLOR_DEPTH.Type(color_depth), Color)) ![]Image {

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

        // CHECKPOINT: DIFF ALGORITHM
        /// Encodes the first image, and each data computes the difference between the previous frame
        pub const DIFF = struct {
            const Self = @This();

            const DISTANCE_TYPE = u8;

            const Entry = struct { idx: PTM.COLOR_DEPTH.Type(color_depth), dist: DISTANCE_TYPE };

            /// Reads the next color entry
            fn nextEntry(reader: *std.Io.Reader) !Entry {
                const idx = try reader.takeInt(PTM.COLOR_DEPTH.Type(color_depth), PTM.ENDIANNESS);
                const dist = try reader.takeInt(DISTANCE_TYPE, PTM.ENDIANNESS);
                return .{ .idx = idx, .dist = dist };
            }

            /// Compression method for the difference algorithm
            fn comp(allocator: std.mem.Allocator, data: []const Image, header: *const PTM.Header(dim_depth), writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(color_depth))) !void {
                const capacity = @as(usize, header.height) * @as(usize, header.width);

                // ALLOC: Store the previous frames in memory to compare.
                var diff = try allocator.alloc(PTM.COLOR_DEPTH.Type(color_depth), capacity);
                defer allocator.free(diff);
                
                // Write first image as reference
                for (data[0].pixels.items, 0..) |px, i| {
                    const idx = map.get(px) orelse return error.UnknownColor;
                    try writer.writeInt(PTM.COLOR_DEPTH.Type(color_depth), idx, PTM.ENDIANNESS);
                    diff[i] = idx;
                }
                
                for (data[1..]) |image| {
                    var last: usize = 0;
                    for (image.pixels.items, 0..) |px, i| {
                        const idx = map.get(px) orelse return error.UnknownColor;
                        const dist = i - last;

                        if (diff[i] != idx or dist >= std.math.maxInt(DISTANCE_TYPE)) {
                            try writer.writeInt(PTM.COLOR_DEPTH.Type(color_depth), idx, PTM.ENDIANNESS);
                            try writer.writeInt(DISTANCE_TYPE, @intCast(dist), PTM.ENDIANNESS);
                            last = i;
                            diff[i] = idx;
                        }
                    }

                    // Write divider
                    try writer.writeInt(
                        PTM.COLOR_DEPTH.Type(color_depth), 
                        std.math.maxInt(PTM.COLOR_DEPTH.Type(color_depth)), 
                        PTM.ENDIANNESS
                    );
                }
            }

            /// Decompression method for the Default algorithm
            fn decomp(allocator: std.mem.Allocator, header: *const PTM.Header(dim_depth), reader: *std.Io.Reader, map: *std.AutoHashMap(PTM.COLOR_DEPTH.Type(color_depth), Color)) ![]Image {
                const num = try reader.takeInt(PTM.LENGTH_TYPE, PTM.ENDIANNESS);
                const capacity = @as(usize, header.height) * @as(usize, header.width);

                var images = try std.ArrayList(Image).initCapacity(allocator, num);

                var diff = try allocator.alloc(PTM.COLOR_DEPTH.Type(color_depth), capacity);
                defer allocator.free(diff);

                try reader.readSliceAll(diff); // Read first image
                var colors = try indexToColors(allocator, map, diff);
                errdefer allocator.free(colors);

                try images.append(allocator, .{ .pixels = .{
                    .columns = header.width,
                    .rows = header.height,
                    .items = colors,
                }});

                var last: usize = 0;
                while (images.items.len != num) {
                    const entry = nextEntry(reader) catch { break; };

                    if (entry.idx == std.math.maxInt(PTM.COLOR_DEPTH.Type(color_depth))) {
                        colors = try indexToColors(allocator, map, diff);
                        errdefer allocator.free(colors);
                        
                        try images.append(allocator, .{ .pixels = .{
                            .columns = header.width,
                            .rows = header.height,
                            .items = colors,
                        }});

                        last = 0;
                        continue;
                    }

                    last += entry.dist;
                    diff[last] = entry.idx;
                }

                return try images.toOwnedSlice(allocator);
            }
        };
    };
}
