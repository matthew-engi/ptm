// Allow for internal access to libraries
pub const Color = @import("./src/color.zig").Color;
pub const Image = @import("./src/image.zig").Image;
pub const Matrix = @import("./src/matrix.zig").Matrix;

// Access to PTM file structs
const ptm = @import("./src/mod.zig");

pub const PTM = ptm.PTM;
pub const Header = ptm.Header;
pub const Sprite = ptm.Sprite;
pub const Reader = @import("./src/reader.zig").Reader;
pub const Writer = @import("./src/writer.zig").Writer;