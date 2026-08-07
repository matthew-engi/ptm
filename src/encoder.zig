//! Author: matthew.engi
//! Description: Compression mechanism for PTM files (responsible for data part)

const std = @import("std");
const PTM = @import("./mod.zig");
const Color = @import("./color.zig").Color;
const Image = @import("./image.zig").Image;

/// Encoding modes
pub const Modes = enum(u8) {
   /// Default encoding
   default, // (n, i0, i1, ...) 
   rle,     // Run-length encoding
};

/// Compression mapping (Mode -> Compression algorithm)
/// returns ![]u8, unknown sizes of bytes, depends on algorithm
pub fn encode(
   allocator: std.mem.Allocator, mode: Modes, 
   data: []const Image, header: *const PTM.Header, writer: *std.Io.Writer
) !void {
   var map = std.AutoHashMap(Color, PTM.COLOR_RANGE_TYPE).init(allocator);
   defer map.deinit(); // Remove the memory allocated to the mapping after encoding

   // Create the color mapping (Color -> Index)
   for (header.colors, 0..) |c, i| {
      try map.put(c, @intCast(i));
   }

   try writer.writeInt(PTM.MODE_TYPE, @intFromEnum(mode), PTM.ENDIAN_TYPE);
   try writer.writeInt(PTM.LENGTH_TYPE, @intCast(data.len), PTM.ENDIAN_TYPE);         

   try switch(mode) {
      .default => Algorithms.Default.comp(data, header, writer, &map),
      .rle => Algorithms.RLE.comp(data, header, writer, &map),
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
      .rle => Algorithms.RLE.decomp(allocator, header, reader, &map),
   };

   return sprite;
}

/// Algorithms to decompress rows of sprites
pub const Algorithms = struct {
   // CHECKPOINT: DEFAULT ALGORITHM
   /// Encodes each individual pixel as an index
   pub const Default = struct {
      const Self = @This();

      /// Amount of images allowed per row
      pub const LENGTH_TYPE = u16;

      /// Compression method for the Default algorithm
      fn comp(
         data: []const Image, _: *const PTM.Header, 
         writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_RANGE_TYPE)
      ) !void{
         // Writing the images
         for (data) |image| {            
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
      ) ![]Image {
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

         return sprites.data.toOwnedSlice();
      }
   };

   // CHECKPOINT: RLE ALGORITHM
   /// Encodes the pixel index with the repeated amount after
   pub const RLE = struct {
      const Self = @This();

      /// Amount of similar pixels encoded
      pub const AMOUNT_TYPE = u8;

      /// RLE Entry struct
      const Entry = struct {
         idx: PTM.COLOR_RANGE_TYPE,
         len: AMOUNT_TYPE
      };

      fn nextEntry(reader: *std.Io.Reader) !Entry {
         const idx = try reader.takeInt(PTM.COLOR_RANGE_TYPE, PTM.ENDIAN_TYPE);
         const len = try reader.takeInt(AMOUNT_TYPE, PTM.ENDIAN_TYPE);

         return .{
            .idx = idx,
            .len = len,
         };
      }

      /// Compression method for the RLE algorithm
      fn comp(
         data: []const Image, _: *const PTM.Header, 
         writer: *std.Io.Writer, map: *std.AutoHashMap(Color, PTM.COLOR_RANGE_TYPE)
      ) !void{         
         // Writing the images
         for (data, 0..) |image, i| {
            var since: AMOUNT_TYPE = 0;
            var previous_i = map.get(image.pixels.items[0]) orelse return error.UnknownColor;

            for (image.pixels.items) |pixel| {
               const new_i = map.get(pixel) orelse return error.UnknownColor;
               if (new_i != previous_i or since == std.math.maxInt(AMOUNT_TYPE)) {
                  try writer.writeInt(PTM.COLOR_RANGE_TYPE, previous_i, PTM.ENDIAN_TYPE);
                  try writer.writeInt(AMOUNT_TYPE, since, PTM.ENDIAN_TYPE);
                  previous_i = new_i;
                  since = 1;
               } else {
                  since += 1;
               }
            }

            try writer.writeInt(PTM.COLOR_RANGE_TYPE, previous_i, PTM.ENDIAN_TYPE);
            try writer.writeInt(AMOUNT_TYPE, since, PTM.ENDIAN_TYPE);

            // Write the delimiter for the image (max, max) 
            if (i + 1 < data.len) {
               try writer.writeInt(PTM.COLOR_RANGE_TYPE, std.math.minInt(PTM.COLOR_RANGE_TYPE), PTM.ENDIAN_TYPE);
               try writer.writeInt(AMOUNT_TYPE, std.math.minInt(AMOUNT_TYPE), PTM.ENDIAN_TYPE);
            }
         }
      }

      /// Decompression method for the Default algorithm
      fn decomp(
         allocator: std.mem.Allocator, header: *const PTM.Header, 
         reader: *std.Io.Reader, map: *std.AutoHashMap(PTM.COLOR_RANGE_TYPE, Color)
      ) ![]Image {
         const num = try reader.takeInt(Self.LENGTH_TYPE, PTM.ENDIAN_TYPE);

         // ALLOC: Allocate memory for the images and the color streams
         var imgs = std.ArrayList(Image).empty;
         var colors = try std.ArrayList(Color).initCapacity(allocator, header.width * header.height);

         while (imgs.items.len < num) {
            const entry = try nextEntry(reader);

            // Check image delimiter
            if (entry.idx == std.math.minInt(PTM.COLOR_RANGE_TYPE) and entry.len == std.math.minInt(AMOUNT_TYPE)) {
               try imgs.append(allocator, .{
                     .pixels = .{
                        .columns = header.height,
                        .rows = header.width,
                        .items = try colors.toOwnedSlice(allocator),
                     },
               });

               colors = try std.ArrayList(Color).initCapacity(
                     allocator,
                     header.width * header.height,
               );
               continue;
            }

            const color = map.get(entry.idx) orelse return error.UnknownIndex;
            for (0..entry.len) |_| {
               try colors.append(allocator, color);
            }
         }

         if (colors.items.len > 0) {
            try imgs.append(allocator, .{
               .pixels = .{
                     .columns = header.height,
                     .rows = header.width,
                     .items = try colors.toOwnedSlice(allocator),
               },
            });
         }

         return try imgs.toOwnedSlice(allocator);
      }
   };
};