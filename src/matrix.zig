//! Author: matthew.engi
//! Description: A 2-dimensional array type

const std = @import("std");

pub fn Matrix (
    comptime T: type,
    comptime default: ?T,
) type {

    return struct {
        const Self = @This();

        rows: usize,
        columns: usize,
        items: []T,

        /// Initializes the Matrix
        pub fn init(allocator: std.mem.Allocator, rows: usize, cols: usize) !Self {
            const items = try allocator.alloc(T, rows * cols);
            if (default) |val| {
                @memset(items, val);
            }
            return .{ .columns = cols, .rows = rows, .items = items }; 
        }

        /// Frees up memory taken by the Matrix
        pub fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.items);
        }

        /// Import data directly from a reader object and transforms into a Matrix
        pub fn fromReader(
            allocator: std.mem.Allocator,
            rows: usize, columns: usize,
            reader: *std.Io.Reader,
        ) !Self {
            var self = try Self.init(allocator, rows, columns);
            errdefer self.deinit(allocator);
            try reader.readSliceAll(std.mem.sliceAsBytes(self.items));
            return self;
        }

        /// Transforms an array into a Matrix, assuming T is of the same size as data in the slice
        pub fn fromSlice(
            allocator: std.mem.Allocator, 
            rows: usize, columns: usize, 
            slice: []const u8
        ) !Self {
            if (slice.len != rows * columns * @sizeOf(T)) {
                std.debug.panic("Expected {d} bytes, got {d}", .{rows * columns * @sizeOf(T), slice.len});
            }
            var self = try Self.init(allocator, rows, columns);

            for (0..rows * columns) |i| {
                const start = i * @sizeOf(T);
                self.items[i] = std.mem.bytesToValue(T, slice[start..][0..@sizeOf(T)]);
            }

            return self;
        }

        /// Gets the index in the array of the position for a certain row and column
        pub fn index(self: *const Self, row: usize, col: usize) usize {
            return row * self.columns + col;
        }

        /// Gets an item in the matrix at a specific row and column
        pub fn get(self: *const Self, row: usize, col: usize) T {
            return self.items[self.index(row, col)];
        }

        /// Gets an entire row from the Matrix
        pub fn getRow(self: *const Self, row: usize) []T {
            const start = row * self.columns;
            return self.items[start .. start + self.columns];
        }

        /// Gets an array of unique items in the Matrix
        pub fn getUniques(self: *const Self, allocator: std.mem.Allocator) ![]T {
            var seen = std.AutoHashMap(T, void).init(allocator);
            defer seen.deinit();

            var uniques: std.ArrayList(T) = .empty;
            errdefer uniques.deinit(allocator);

            for (self.items) |item| {
                if (!seen.contains(item)) {
                    try seen.put(item, {});
                    try uniques.append(allocator, item);
                }
            }

            return uniques.toOwnedSlice(allocator);
        }

        /// Sets an item in the matrix at a specific row and column
        pub fn set(self: *Self, row: usize, col: usize, item: T) void {
            self.items[self.index(row, col)] = item;
        }

        /// Sets an entire row with specific items
        pub fn setRow(self: *Self, row: usize, items: []T) void {
            std.debug.assert(items.len == self.columns);
            const start = row * self.columns;
            @memcpy(self.items[start .. start + self.columns], items);
        }
    };
}
