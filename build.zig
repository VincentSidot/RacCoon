const std = @import("std");

fn load_assembly_file(b: *std.Build, module: *std.Build.Module) !void {
    const arch = module.resolved_target.?.result.cpu.arch;

    const assembly_dir = try std.fmt.allocPrint(
        b.allocator,
        "kernel/arch/{s}/asm/",
        .{@tagName(arch)},
    );

    const cwd = std.Io.Dir.cwd();

    var threaded = std.Io.Threaded.init_single_threaded;
    const io = threaded.io();

    const folders = try std.Io.Dir.openDir(cwd, io, assembly_dir, .{ .iterate = true });
    var folders_iterator = folders.iterate();

    while (try folders_iterator.next(io)) |entry| {
        if (entry.kind == .file) {
            const path = try std.fs.path.join(b.allocator, &[_][]const u8{ assembly_dir, entry.name });
            module.addAssemblyFile(b.path(path));
        } else if (entry.kind == .directory) {
            return error.FolderNotSupported;
        }
    }
}

fn on_error(b: *std.Build, err: anyerror) noreturn {
    const msg = std.fmt.allocPrint(
        b.allocator,
        "Error {any}",
        .{err},
    ) catch unreachable;
    @panic(msg);
}

pub fn build(b: *std.Build) void {

    // Build the 64-bit kernel executable
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .freestanding,
            .ofmt = .elf,
        },
    });

    // ReleaseSafe: keeps bounds/overflow safety checks but avoids ubsan/compiler_rt
    // bloat that Debug mode adds.  The self-hosted linker in Zig 0.16 cannot handle
    // the large Debug binary layout with our custom linker script, and LLD segfaults
    // on this freestanding target.  Pass -Doptimize=Debug only if/when that is fixed.
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });
    _ = optimize;
    // Hardcode ReleaseSafe: avoids ubsan/compiler_rt bloat from Debug mode that
    // breaks the self-hosted linker's section layout in Zig 0.16.
    // Pass -Doptimize=Debug once that is fixed.
    const eff_optimize: std.builtin.OptimizeMode = .ReleaseSafe;

    const root_module: *std.Build.Module = b.createModule(.{
        .root_source_file = b.path("kernel/entrypoint.zig"),

        .target = target,
        .optimize = eff_optimize,
        // .no_builtin = true,
        .stack_protector = false, // --fno-stack-protector
        .stack_check = false, // --fno-stack-check

        .imports = &.{},
    });

    // root_module.addAssemblyFile(b.path("kernel/arch/x86/asm/idt.s"));
    _ = load_assembly_file(b, root_module) catch |err| {
        on_error(b, err);
    };

    const exe = b.addExecutable(.{
        .name = "kernel",
        .root_module = root_module,
    });
    exe.setLinkerScript(b.path("boot/kernel.ld"));

    // Note: do not set use_lld=true — LLD segfaults on this freestanding target in Zig 0.16.

    // Emit the kernel as a flat binary (loaded by the bootloader)
    const kernel_bin = b.addObjCopy(exe.getEmittedBin(), .{
        .format = .bin,
    });

    // Install the kernel ELF to zig-out/kernel.elf for GDB symbol loading
    const kernel_elf_install = b.addInstallFile(exe.getEmittedBin(), "kernel.elf");
    kernel_elf_install.step.dependOn(&exe.step);
    b.getInstallStep().dependOn(&kernel_elf_install.step);

    // Build the bootable disk image:
    //   build.sh assembles stage1.s + stage2.s + stage3.s and concatenates the kernel binary
    const boot_image_builder = b.addSystemCommand(&.{"bash"});
    boot_image_builder.addFileArg(b.path("scripts/build.sh"));
    boot_image_builder.addFileArg(b.path("boot/stage1.s"));
    boot_image_builder.addFileArg(b.path("boot/stage2.s"));
    boot_image_builder.addFileArg(b.path("boot/stage3.s"));
    boot_image_builder.addFileArg(kernel_bin.getOutput());

    const boot_image_path = boot_image_builder.addOutputFileArg("boot.bin");

    const boot_image_install = b.addInstallFile(boot_image_path, "boot.bin");

    b.getInstallStep().dependOn(&boot_image_install.step);

    // ── run ──────────────────────────────────────────────────────────────────
    const run_step = b.step("run", "Run in QEMU");
    const run_cmd = b.addSystemCommand(&.{"bash"});
    run_cmd.addFileArg(b.path("scripts/run.sh"));
    run_cmd.addFileArg(boot_image_path);

    // ── debug  (alias for debug64) ────────────────────────────────────────────
    const debug_step = b.step("debug", "Debug kernel at 0x8200 in GDB (64-bit, alias for debug64)");
    const debug_cmd = b.addSystemCommand(&.{"bash"});
    debug_cmd.addFileArg(b.path("scripts/run.sh"));
    debug_cmd.addArg("--debug64");
    debug_cmd.addFileArg(boot_image_path);

    // ── debug16 ───────────────────────────────────────────────────────────────
    const debug16_step = b.step("debug16", "Debug stage1 at 0x7C00 in GDB (16-bit real mode)");
    const debug16_cmd = b.addSystemCommand(&.{"bash"});
    debug16_cmd.addFileArg(b.path("scripts/run.sh"));
    debug16_cmd.addArg("--debug16");
    debug16_cmd.addFileArg(boot_image_path);

    // ── debug32 ───────────────────────────────────────────────────────────────
    const debug32_step = b.step("debug32", "Debug stage2 at 0x8000 in GDB (32-bit protected mode)");
    const debug32_cmd = b.addSystemCommand(&.{"bash"});
    debug32_cmd.addFileArg(b.path("scripts/run.sh"));
    debug32_cmd.addArg("--debug32");
    debug32_cmd.addFileArg(boot_image_path);

    // ── debug64 ───────────────────────────────────────────────────────────────
    const debug64_step = b.step("debug64", "Debug kernel at 0x8200 in GDB (64-bit long mode)");
    const debug64_cmd = b.addSystemCommand(&.{"bash"});
    debug64_cmd.addFileArg(b.path("scripts/run.sh"));
    debug64_cmd.addArg("--debug64");
    debug64_cmd.addFileArg(boot_image_path);

    // ── dependencies ──────────────────────────────────────────────────────────
    kernel_bin.step.dependOn(&exe.step);
    boot_image_builder.step.dependOn(&kernel_bin.step);
    boot_image_install.step.dependOn(&boot_image_builder.step);

    run_cmd.step.dependOn(&boot_image_install.step);
    run_step.dependOn(&run_cmd.step);

    // debug / debug64 also need kernel.elf for GDB symbols
    debug_cmd.step.dependOn(&boot_image_install.step);
    debug_cmd.step.dependOn(&kernel_elf_install.step);
    debug_step.dependOn(&debug_cmd.step);

    debug16_cmd.step.dependOn(&boot_image_install.step);
    debug16_step.dependOn(&debug16_cmd.step);

    debug32_cmd.step.dependOn(&boot_image_install.step);
    debug32_step.dependOn(&debug32_cmd.step);

    debug64_cmd.step.dependOn(&boot_image_install.step);
    debug64_cmd.step.dependOn(&kernel_elf_install.step);
    debug64_step.dependOn(&debug64_cmd.step);
}
