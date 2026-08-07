//! Author: matthew.engi
//! Description: Access point for the ptm file format

const std = @import("std");
const Color = @import("./helpers/color.zig").Color;
const Image = @import("./helpers/image.zig").Image;

// -------------------------------------------------------------------------------- //
// Header encoding
pub const DIM_TYPE = u8; // Limit of dimensions (height, width)
pub const RATE_TYPE = u8; // Limit of framerate
pub const MODE_TYPE = u8; // Different compression modes
pub const LENGTH_TYPE = u16; // How many pictures a sprite can have
pub const COLOR_RANGE_TYPE = u8; // Limit of differently encoded colors (colors)

// ENDIANNESS
pub const ENDIANNESS = std.builtin.Endian.big;
// -------------------------------------------------------------------------------- //

// Data encodings are found in compression.zig

/// Data included in the header of the PTM file
pub const Header = struct {
    height: DIM_TYPE, // Height of each image
    width: DIM_TYPE, // Width of each image
    rate: RATE_TYPE, // Rate at which the sprites play
    colors: []Color, // Unique colors found in the image
};

/// Complete struct with header and data
pub const PTM = struct {
    header: Header,
    data: [][]Image,
};

/// Image array wrapper
pub fn Sprite(n: usize) type {
    return struct {
        const Self = @This();

        len: usize,
        data: []Image,

        /// Initializes the struct
        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{ .len = 0, .data = try allocator.alloc(Image, n) };
        }

        /// De-allocates the ArrayList and items inside of it.
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            for (0..self.len) |i| {
                self.data[i].deinit(allocator);
            }
            allocator.free(self.data);
        }

        /// Adds an entry and raises the inner counter.
        pub fn add(self: *Self, image: Image) void {
            self.data[self.i] = image;
            self.len += 1;
        }
    };
}
