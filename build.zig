const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the user to override the target, etc.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allows the user to override optimization mode.
    // For this project, let's default to Debug mode for easier debugging if issues arise.
    const optimize = b.standardOptimizeOption(.{.default_mode = .Debug});

    const exe = b.addExecutable(.{
        .name = "zig-tower-defense",
        // b.path() resolves paths relative to the build.zig file's directory (project root)
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the executable to be installed.
    // When the user runs `zig build install` (or `zig build` without a step),
    // this executable will be copied to the installation prefix (e.g., zig-out/bin).
    b.installArtifact(exe);

    // This creates a RunStep that will execute the compiled executable.
    // It's what `zig build run` uses.
    const run_cmd = b.addRunArtifact(exe);

    // Make the run command depend on the installation of the executable.
    // This ensures the executable is built before trying to run it.
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow passing arguments to the application when running it with `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates a top-level step "run" that prints "Run the app"
    // and executes the run_cmd.
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // It's also good practice to add a test step, though not explicitly requested for this subtask.
    // If tests were added to the project files (e.g. in a `test "..." {}` block),
    // a test step could be configured like this:
    // const test_filter = b.option([]const u8, "test-filter", "Filter for tests to run");
    // const main_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"), // Or specific test files
    //     .target = target,
    //     .optimize = optimize,
    //     .filter = test_filter,
    // });
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&main_tests.step);
}
