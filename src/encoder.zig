//! Author: matthew.engi
//! Description: Compression mechanism for PTM files (responsible for data part)

const std = @import("std");
const PTM = @import("./mod.zig");
const Color = @import("./color.zig").Color;
const Image = @import("./image.zig").Image;

/// Encoding modes
pub const Modes = enum {
   /// Default encoding
   default, // (n, i0, i1, ...) 
};

/// Compression mapping (Mode -> Compression algorithm)
/// returns ![]u8, unknown sizes of bytes, depends on algorithm
pub fn encode(
   allocator: std.mem.Allocator, mode: Modes, 
   data: *[]Image, header: *const PTM.Header, writer: *std.Io.Writer
) !void {
   var map = std.AutoHashMap(Color, PTM.COLOR_RANGE_TYPE).init(allocator);
   defer map.deinit(); // Remove the memory allocated to the mapping after encoding

   // Create the color mapping (Color -> Index)
   for (header.colors, 0..) |c, i| {
      try map.put(c, @intCast(i));
   }

   try switch(mode) {
      .default => Algorithms.Default.comp(data, header, writer, &map),
   };
}

/// Decompression mapping (Mode -> Decompression algorithm)
/// returns ![]Image unknown amount of images, derived
pub fn decode(
   allocator: std.mem.Allocator, mode: Modes, 
   header: *const PTM.Header, reader: *std.Io.Reader
) ![]Image {
   var map = std.AutoHashMap(PTM.COLOR_RANGE_TYPE, Color).init(allocator);
   defer map.deinit(); // Remove the memory allocated to the mapping after decoding

   // Create the color mapping (Index -> Color)
   for (header.colors, 0..) |c, i| {
      try map.put(@intCast(i), c);
   }

   const sprite = try switch(mode) {
      .default => Algorithms.Default.decomp(allocator, header, reader, &map),
   };

   return sprite.data.toOwnedSlice(allocator); // Turns ArrayList -> Slice
}

/// Algorithms to decompress rows of sprites
pub const Algorithms = struct {

   /// Data arranged like so: { (Amount of Images), (Mapped Index), (Mapped Index) ... }
   pub const Default = struct {
      const Self = @This();

      /// Amount of images allowed per row
      pub const LENGTH_TYPE = u32;

      /// Compression method for the Default algorithm
      fn comp(
         data: *[]Image, _: *const PTM.Header, 
         writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_RANGE_TYPE)
      ) !void{
         // Write the mode
         try writer.writeInt(Self.LENGTH_TYPE, @intCast(data.len), PTM.ENDIAN_TYPE);

         // Writing the images
         for (data.*) |image| {
            try writer.writeInt(PTM.MODE_TYPE, @intFromEnum(Modes.default), PTM.ENDIAN_TYPE);
            
            for (image.pixels.items) |pixel| {
               const index = map.get(pixel) orelse return error.UnknownIndex; // Turning Color -> Index
               try writer.writeInt(PTM.COLOR_RANGE_TYPE, index, PTM.ENDIAN_TYPE);
            }
         }
      }

      /// Decompression method for the Default algorithm
      fn decomp(
         allocator: std.mem.Allocator, header: *const PTM.Header, 
         reader: *std.Io.Reader, map: *std.AutoHashMap(PTM.COLOR_RANGE_TYPE, Color)
      ) !PTM.Sprite {
         const num = try reader.takeInt(Self.LENGTH_TYPE, PTM.ENDIAN_TYPE);
         const capacity = @as(usize, header.height) * @as(usize, header.width);

         // ALLOC: Allocated memory for storing the images within the sprite + reading buffer (size of img)
         var sprites = try PTM.Sprite(num).init(allocator);
         const buffer = try allocator.alloc(PTM.COLOR_RANGE_TYPE, capacity);

         defer allocator.free(buffer);
         errdefer sprites.deinit(allocator);

         // Enumerate through every image
         for (0..num) |_| {
            try reader.readSliceAll(buffer); // Fill the buffer with image data

            // ALLOC: Allocated memory to store the colors inside of the image
            var pixels = try allocator.alloc(Color, capacity);
            errdefer allocator.free(pixels);

            // Loop through every pixel
            for (buffer, 0..) |c, i| {
               const color = map.get(c) orelse return error.UnknownColor;
               pixels[i] = color;
            }

            sprites.add(
               .{ .pixels = .{ 
                  .columns = header.width, 
                  .rows = header.height, 
                  .items = pixels,
               }}
            );
         }

         return sprites;
      }
   };
};