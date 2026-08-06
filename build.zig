const Build = @import("std").Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("ptm", .{
        .root_source_file = b.path("ptm.zig"),
        .target = target,
        .optimize = optimize,
    });
}