# "Protomap" Sprite Library

![Static Badge](https://img.shields.io/badge/Zig-0.16.0-2?style=flat&color=orange&link=https%3A%2F%2Fziglang.org%2Fdownload%2F0.16.0%2Frelease-notes.html)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

This is a library to read and write .ptm files containing sprites for byter-zig

## Install & Build

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
