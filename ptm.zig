//! Author: matthew.engi
//! Description: Allow for internal access to libraries
const ptm = @import("./src/mod.zig");

/// Reader struct to read PTM files
pub const Reader = @import("./src/lib/reader.zig").Reader;
/// Writer struct to write PTM files
pub const Writer = @import("./src/lib/writer.zig").Writer;

/// Struct containing inner-structs not typically needed outside.
pub const Helpers = struct {
   pub const Color = @import("./src/helpers/color.zig").Color;
   pub const Image = @import("./src/helpers/image.zig").Image;
   pub const Matrix = @import("./src/helpers/matrix.zig").Matrix;
};

/// PTM file format types
pub const Wrappers = struct {
   pub const PTM = ptm.PTM;
   pub const Header = ptm.Header;
   pub const Sprite = ptm.Sprite;
};

// Tests to verify validity of the package
test {
    _ = @import("tests/image_test.zig");
}
