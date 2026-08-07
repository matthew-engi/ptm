//! Author: matthew.engi
//! Description: Reading section for the ptm file format

const std = @import("std");
const Encoder = @import("./encoder.zig");
const Color = @import("../helpers/color.zig").Color;
const Image = @import("../helpers/image.zig").Image;

// General structs for the format
const PTM = @import("../mod.zig");

pub const Reader = struct {
    const Self = @This();

    allocator: std.mem.Allocator,

    /// Attributed an allocator for the Reader
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// Gets the header for the Reader
    pub fn getHeader(
        self: *const Self, 
        reader: *std.Io.Reader
    ) !PTM.Header {
    
        // General data
        const height = try reader.takeInt(PTM.DIM_TYPE, PTM.ENDIANNESS);
        const width = try reader.takeInt(PTM.DIM_TYPE, PTM.ENDIANNESS);
        const rate = try reader.takeInt(PTM.RATE_TYPE, PTM.ENDIANNESS);

        // Colors
        const count = try reader.takeInt(PTM.COLOR_RANGE_TYPE, PTM.ENDIANNESS);

        // ALLOC: Allocate memory for the list of colors
        const colors = try self.allocator.alloc(Color, @intCast(count));
        errdefer self.allocator.free(colors);

        try reader.readSliceAll(std.mem.sliceAsBytes(colors));

        return .{ .height = height, .width = width, .rate = rate, .colors = colors };
    }

    /// Returns an array of sprites
    pub fn loadWithHeader(
        self: *const Self, 
        header: PTM.Header, 
        reader: *std.Io.Reader
    ) !PTM.PTM {
        var sprites: std.ArrayList([]Image) = .empty;
        errdefer {
            for (sprites.items) |sprite| {
                for (sprite) |*img| { img.deinit(self.allocator); }
            }
            sprites.deinit(self.allocator);
        }

        while (true) {
            // Read the mode of the sprite row, then feed it in the decoder
            const mode = reader.takeEnum(Encoder.Modes, PTM.ENDIANNESS) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            };

            // ALLOC: Allocated memory to []Image
            const sprite = try Encoder.decode(self.allocator, mode, &header, reader);
            try sprites.append(self.allocator, sprite);
        }

        return .{ .header = header, .data = try sprites.toOwnedSlice(self.allocator) };
    }
};
