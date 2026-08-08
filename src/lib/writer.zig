//! Author: matthew.engi
//! Description: Writing section for the ptm file format

const std = @import("std");
const Color = @import("../helpers/color.zig").Color;
const Image = @import("../helpers/image.zig").Image;
const Encoder = @import("./encoder.zig");

// General structs for the format
const PTM = @import("../mod.zig");

pub fn Writer(comptime depth: ?PTM.COLOR_DEPTH) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        /// Gets the format of the header for the Writer
        pub fn getHeader(
            _: *const Self,
            height: PTM.DIM_TYPE,
            width: PTM.DIM_TYPE,
            rate: PTM.RATE_TYPE,
            colors: []Color, // Unique colors list (color mapping)
        ) PTM.Header {
            return PTM.Header{ .height = height, .width = width, .rate = rate, .colors = colors };
        }

        /// Writes the information about the PTM into the file
        pub fn writeWithHeader(self: *const Self, header: PTM.Header, writer: *std.Io.Writer, modes: []const Encoder.Modes, sprites: []const []const Image) !void {

            // Write the header first
            try writer.writeInt(PTM.DIM_TYPE, header.height, PTM.ENDIANNESS);
            try writer.writeInt(PTM.DIM_TYPE, header.width, PTM.ENDIANNESS);
            try writer.writeInt(PTM.RATE_TYPE, header.rate, PTM.ENDIANNESS);

            // Write sprites data
            var color_map = std.AutoHashMap(Color, PTM.COLOR_DEPTH.Type(depth)).init(self.allocator);
            defer color_map.deinit();

            try writer.writeInt(PTM.COLOR_DEPTH.Type(depth), @intCast(header.colors.len), PTM.ENDIANNESS);

            for (header.colors, 0..) |color, i| {
                try color_map.put(color, @intCast(i)); // May fail if too many colors
                try writer.writeStruct(color, PTM.ENDIANNESS);
            }

            for (sprites, 0..) |sprite, i| {
                try Encoder.Encoding(depth).encode(self.allocator, modes[i], sprite, &header, writer);
            }
        }
    };
}
