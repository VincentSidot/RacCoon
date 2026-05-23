const std = @import("std");

pub fn build(b: *std.Build) void {

    // Build stage2 executable
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86,
            .os_tag = .freestanding,
            .ofmt = .elf,
        },
    });

    const optimize: std.builtin.OptimizeMode = .ReleaseSmall; // Target small binary size.

    const exe = b.addExecutable(.{
        .name = "stage2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),

            .target = target,
            .optimize = optimize,
            // .no_builtin = true,
            .stack_protector = false, // --fno-stack-protector
            .stack_check = false, // --fno-stack-check

            .imports = &.{},
        }),
    });
    exe.setLinkerScript(b.path("linker/stage2.ld"));

    // Emit the executable as a flat binary
    const stage2_bin = b.addObjCopy(exe.getEmittedBin(), .{
        .format = .bin,
    });

    // Build the bootable binary
    const boot_image_builder = b.addSystemCommand(&.{"bash"});
    boot_image_builder.addFileArg(b.path("scripts/build.sh"));
    boot_image_builder.addFileArg(b.path("asm/stage1.s"));
    boot_image_builder.addFileArg(stage2_bin.getOutput());

    const boot_image_path = boot_image_builder.addOutputFileArg("boot.bin");

    const boot_image_install = b.addInstallFile(boot_image_path, "boot.bin");

    b.getInstallStep().dependOn(&boot_image_install.step);

    // Make "run" step that runs the boot image in QEMU
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addSystemCommand(&.{
        "bash",
    });
    run_cmd.addFileArg(b.path("scripts/run.sh"));
    run_cmd.addFileArg(boot_image_path);

    // Make "debug" step that runs the app in QEMU with GDB
    const debug_step = b.step("debug", "Debug the app with GDB");
    const debug_cmd = b.addSystemCommand(&.{
        "bash",
    });
    debug_cmd.addFileArg(b.path("scripts/run.sh"));
    debug_cmd.addArg("--debug");
    debug_cmd.addFileArg(boot_image_path);

    // Define dependencies
    stage2_bin.step.dependOn(&exe.step);
    boot_image_builder.step.dependOn(&stage2_bin.step);
    boot_image_install.step.dependOn(&boot_image_builder.step);
    run_cmd.step.dependOn(&boot_image_install.step);
    run_step.dependOn(&run_cmd.step);
    debug_cmd.step.dependOn(&boot_image_install.step);
    debug_step.dependOn(&debug_cmd.step);
}
