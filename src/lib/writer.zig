//! Author: matthew.engi
//! Description: Writing section for the ptm file format

const std = @import("std");
const Color = @import("../helpers/color.zig").Color;
const Image = @import("../helpers/image.zig").Image;
const Encoder = @import("./encoder.zig");

// General structs for the format
const PTM = @import("../mod.zig");

pub const Writer = struct {
    const Self = @This();

    /// Gets the format of the header for the Writer
    pub fn getHeader(
        height: u8,
        width: u8,
        rate: u8,
        colors: []Color, // Unique colors list (color mapping)
    ) PTM.Header {
        return PTM.Header{ .height = height, .width = width, .rate = rate, .colors = colors };
    }

    /// Writes the information about the PTM into the file
    pub fn writeWithHeader(header: PTM.Header, writer: *std.Io.Writer, allocator: std.mem.Allocator, modes: []const Encoder.Modes, sprites: []const []const Image) !void {
        // Write the header first
        try writer.writeInt(PTM.DIM_TYPE, header.height, PTM.ENDIANESS);
        try writer.writeInt(PTM.DIM_TYPE, header.width, PTM.ENDIANESS);
        try writer.writeInt(PTM.RATE_TYPE, header.rate, PTM.ENDIANESS);

        // Write sprites data
        var color_map = std.AutoHashMap(Color, PTM.COLOR_RANGE_TYPE).init(allocator);
        defer color_map.deinit();

        try writer.writeInt(PTM.COLOR_RANGE_TYPE, @intCast(header.colors.len), PTM.ENDIANESS);

        for (header.colors, 0..) |color, i| {
            try color_map.put(color, @intCast(i)); // May fail if too many colors
            try writer.writeStruct(color, PTM.ENDIANESS);
        }

        for (sprites, 0..) |sprite, i| {
            try Encoder.encode(allocator, modes[i], sprite, &header, writer);
        }
    }
};
