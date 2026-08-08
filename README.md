# "Protomap" Sprite Library

This is a library to read and write .ptm files containing sprites for byter-zig

## Install & Build

This library currently uses zig [0.16.0](https://ziglang.org/download/)
Via the terminal, run the following command:
```sh
zig fetch --save git+https://github.com/matthew-engi/ptm
```
Inside of your  `build.zig` file, add the following:
```zig
const ptm_dep = b.dependency("ptm", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("ptm", ptm_dep.module("ptm"));
```
