const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get libusb dependency
    const libusb_dep = b.dependency("libusb", .{
        .target = target,
        .optimize = optimize,
    });

    const libusb_art = libusb_dep.artifact("usb");

    // Create the WiFiDriver library
    const wifi_driver = b.addStaticLibrary(.{
        .name = "WiFiDriver",
        .target = target,
        .optimize = optimize,
        .pic = true,
    });

    // Add C++ standard version (C++20 equivalent)
    wifi_driver.linkLibCpp();

    // Add source files
    wifi_driver.addCSourceFiles(.{
        .files = &[_][]const u8{

            // Source files (C++)
            "src/EepromManager.cpp",
            "src/FirmwareManager.cpp",
            "src/FrameParser.cpp",
            "src/HalModule.cpp",
            "src/ParsedRadioPacket.cpp",
            "src/RadioManagementModule.cpp",
            "src/Rtl8812aDevice.cpp",
            "src/RtlUsbAdapter.cpp",
            "src/WiFiDriver.cpp",
        },
        .flags = &[_][]const u8{
            "-Wno-error=format-security", // Treat as warning, not error
            "-Wno-format-security",
            "-std=c++20",
        },
        .language = .cpp,
    });
    wifi_driver.addCSourceFiles(.{
        .files = &[_][]const u8{
            // HAL files
            "hal/Hal8812PwrSeq.c",
            "hal/hal8812a_fw.c",

            "src/Radiotap.c",
        },
        .flags = &[_][]const u8{
            "-Wno-error=format-security", // Treat as warning, not error
            "-Wno-format-security",
        },
        .language = .c,
    });

    // Add include directories
    wifi_driver.addIncludePath(b.path("hal"));
    wifi_driver.addIncludePath(b.path("src"));
    wifi_driver.installHeadersDirectory(b.path("src"), "", .{ .include_extensions = &.{".h"} });
    wifi_driver.installHeadersDirectory(b.path("hal"), "", .{ .include_extensions = &.{".h"} });

    // Link with libusb dependency
    wifi_driver.linkLibrary(libusb_art);
    wifi_driver.linkLibC();

    // Install the library
    b.installArtifact(wifi_driver);

    // Create WiFiDriverDemo executable
    const wifi_driver_demo = b.addExecutable(.{
        .name = "WiFiDriverDemo",
        .root_source_file = null, // No Zig source file
        .target = target,
        .optimize = optimize,
    });

    wifi_driver_demo.addCSourceFile(.{
        .file = b.path("demo/main.cpp"),
        .flags = &[_][]const u8{
            "-Wno-error=format-security", // Treat as warning, not error
            "-Wno-format-security",
            "-std=c++20",
        },
        .language = .cpp,
    });

    wifi_driver_demo.linkLibrary(wifi_driver);
    wifi_driver_demo.linkLibrary(libusb_art);
    wifi_driver_demo.linkLibCpp();
    wifi_driver_demo.linkLibC();

    // Install the demo executable
    b.installArtifact(wifi_driver_demo);

    // Create WiFiDriverTxDemo executable
    const wifi_driver_tx_demo = b.addExecutable(.{
        .name = "WiFiDriverTxDemo",
        .target = target,
        .optimize = optimize,
    });

    wifi_driver_tx_demo.addCSourceFile(.{
        .file = b.path("txdemo/main.cpp"),
        .flags = &[_][]const u8{
            "-Wno-error=format-security", // Treat as warning, not error
            "-Wno-format-security",
            "-std=c++20",
        },
        .language = .cpp,
    });

    wifi_driver_tx_demo.linkLibrary(wifi_driver);
    wifi_driver_tx_demo.linkLibrary(libusb_art);
    wifi_driver_tx_demo.linkLibCpp();
    wifi_driver_tx_demo.linkLibC();

    // Install the tx demo executable
    b.installArtifact(wifi_driver_tx_demo);
    if (target.result.os.tag == .windows and target.result.abi.isGnu()) {
        wifi_driver.root_module.addCMacro("WIN_GNU", "");
        wifi_driver_demo.root_module.addCMacro("WIN_GNU", "");
        wifi_driver_tx_demo.root_module.addCMacro("WIN_GNU", "");
    } else if (target.result.os.tag == .linux) {
        libusb_art.linkSystemLibrary("libudev");
    }
    // Create run steps for execliutables
    const run_demo_cmd = b.addRunArtifact(wifi_driver_demo);
    run_demo_cmd.step.dependOn(b.getInstallStep());

    const run_tx_demo_cmd = b.addRunArtifact(wifi_driver_tx_demo);
    run_tx_demo_cmd.step.dependOn(b.getInstallStep());

    // Add run steps
    const run_demo_step = b.step("run-demo", "Run the WiFiDriverDemo");
    run_demo_step.dependOn(&run_demo_cmd.step);

    const run_tx_demo_step = b.step("run-tx-demo", "Run the WiFiDriverTxDemo");
    run_tx_demo_step.dependOn(&run_tx_demo_cmd.step);

    // Add test step (if you have tests)
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&wifi_driver.step);
}
