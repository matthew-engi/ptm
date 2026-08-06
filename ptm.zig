// Allow for internal access to libraries

/// Struct containing inner-structs not typically needed outside.
pub const Utilities = struct {
   pub const Color = @import("./src/color.zig").Color;
   pub const Image = @import("./src/image.zig").Image;
   pub const Matrix = @import("./src/matrix.zig").Matrix;
};

// Access to PTM file structs
const ptm = @import("./src/mod.zig");

/// PTM file format types
pub const File = struct {
   pub const PTM = ptm.PTM;
   pub const Header = ptm.Header;
   pub const Sprite = ptm.Sprite;
};

/// Reader struct to read PTM files
pub const Reader = @import("./src/reader.zig").Reader;
/// Writer struct to write PTM files
pub const Writer = @import("./src/writer.zig").Writer;

// Tests to verify validity of the package
test {
    _ = @import("tests/image_test.zig");
}
