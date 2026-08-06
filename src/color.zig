//! Author: matthew.engi
//! Description: A 3-dimensional color object

const math = @import("std").math;

pub const Color = struct {
    const Self = @This();

    pub const RED   = Self { .r = 255, .g = 0, .b = 0 };
    pub const GREEN = Self { .r = 0, .g = 255, .b = 0 };
    pub const BLUE  = Self { .r = 0, .g = 0, .b = 255 };
    pub const WHITE = Self { .r = 255, .g = 255, .b = 255 };
    pub const BLACK = Self { .r = 0, .g = 0, .b = 0 };

    // Color RGB (red, green, blue) components
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,

    /// Returns a Color struct from an RGB value
    pub fn init(r: u8, g: u8, b: u8) Self {
        return Self { .r = r, .g = g, .b = b };
    }

    /// The signed difference between two colors (rhs - lhs)
    pub fn diff(lhs: *const Self, rhs: *const Self) .{i16, i16, i16} {
        return .{
            @as(i16, rhs.r) - @as(i16, lhs.r),
            @as(i16, rhs.g) - @as(i16, lhs.g),
            @as(i16, rhs.b) - @as(i16, lhs.b),
        };
    }

    /// The absolute difference between two colors
    pub fn absDiff(lhs: *const Self, rhs: *const Self) Self {
        return .{
            .r = @max(lhs.r, rhs.r) - @min(lhs.r, rhs.r),
            .g = @max(lhs.g, rhs.g) - @min(lhs.g, rhs.g),
            .b = @max(lhs.b, rhs.b) - @min(lhs.b, rhs.b),
        };
    }

    /// Lerps a Color with another Color at a percentage alpha
    pub fn lerp(self: Self, rhs: Self, delta: f32) Self {
        return .{
            .r = lerp_u8(self.r, rhs.r, delta),
            .g = lerp_u8(self.g, rhs.g, delta),
            .b = lerp_u8(self.b, rhs.b, delta),
        };
    }

    /// Multiplies Color with a multiplier, saturating behavior
    pub fn alpha(self: *const Self, mult: f32) Self {
        return Self { 
            .r = mult_u8(self.r, mult),
            .g = mult_u8(self.g, mult),
            .b = mult_u8(self.b, mult)
        };
    }
};

/// Multiplies u8 with a float, saturating behavior
fn mult_u8(integer: u8, float: f32) u8 {
    const intf: f32 = @floatFromInt(integer);
    return @intFromFloat(math.clamp(intf * float, 0, 255));
}

/// Lerps a u8 with another u8 at a percentage alpha
fn lerp_u8(lhs: u8, rhs: u8, delta: f32) u8 {
    const t = math.clamp(delta, 0.0, 1.0);
    const lf = @as(f32, lhs);
    const rf = @as(f32, rhs);
    const result = lf + (rf - lf) * t;
    return @intFromFloat(math.clamp(result, 0, 255));
}