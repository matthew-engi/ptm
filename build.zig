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

    // testing zone 
    const ptm_test = b.addTest(.{.root_module = ptm_module});
    const run = b.addRunArtifact(ptm_test);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run.step);

    // add dependencies
    ptm_module.addImport("ptm", ptm_module);
    ptm_module.addImport("zigimg", zigimg.module("zigimg"));
}