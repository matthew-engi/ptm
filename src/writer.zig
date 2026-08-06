//! Author: matthew.engi
//! Description: Writing section for the ptm file format

const std = @import("std");
const Color = @import("./color.zig");
const Image = @import("./image.zig").Image;

// General structs for the format
const PTM = @import("./mod.zig");

pub const Writer = struct {
   const Self = @This();

   /// Gets the format of the header for the Writer
   pub fn getHeader(
      height: u8, width: u8, rate: u8,
      colors: []Color // Unique colors list (color mapping)
   ) PTM.Header {
      return PTM.Header{
         .height = height,
         .width = width,
         .rate = rate,
         .colors = colors
      };
   }

   /// Writes the information about the PTM into the file
   pub fn writeWithHeader(
      header: PTM.Header, 
      writer: *std.Io.Writer, 
      allocator: std.mem.Allocator,
      sprites: [][]Image
   ) !void {
      // Write the header first
      try writer.writeInt(PTM.DIM_TYPE, header.height, PTM.ENDIAN_TYPE);
      try writer.writeInt(PTM.DIM_TYPE, header.width, PTM.ENDIAN_TYPE);
      try writer.writeInt(PTM.RATE_TYPE, header.rate, PTM.ENDIAN_TYPE);

      // Write sprites data
      var color_map = std.AutoHashMap(
         Color, PTM.COLOR_RANGE_TYPE
      ).init(allocator);
      defer color_map.deinit();

      try writer.writeInt(
         PTM.COLOR_RANGE_TYPE, 
         @intCast(header.colors.len), 
         PTM.ENDIAN_TYPE
      );

      for (header.colors, 0..) |color, i| {
         try color_map.put(color, @intCast(i)); // May fail if too many colors
         try writer.writeStruct(color, PTM.ENDIAN_TYPE);
      }

      for (sprites) |sprite| {
         // Write length of sprite
         try writer.writeInt(
            PTM.IMAGE_RANGE_TYPE, 
            @intCast(sprite.len), 
            PTM.ENDIAN_TYPE
         );

         for (sprite) |image| {
            for (image.pixels) |pixel| {
               const value = color_map.get(pixel) orelse return error.UnknownColor;
               try writer.writeInt(
                  PTM.COLOR_RANGE_TYPE, 
                  value, 
                  PTM.ENDIAN_TYPE
               );
            }
         }
      }
      
      try writer.flush();
   }
};