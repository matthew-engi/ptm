const Build = @import("std").Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // zigimg dependency
    const zigimg = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const ptm_module = b.addModule("ptm", .{
        .root_source_file = b.path("ptm.zig"),
        .target = target,
        .optimize = optimize,
    });

    ptm_module.addImport("ptm", ptm_module);
    ptm_module.addImport("zigimg", zigimg.module("zigimg"));
}