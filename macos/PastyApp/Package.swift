// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PastyApp",
    targets: [
        .executableTarget(
            name: "PastyApp",
            cSettings: [
                .headerSearchPath("../../../build/core/include"),
            ],
            linkerSettings: [
                // Link against system frameworks
                .linkedFramework("Cocoa"),
                .linkedFramework("AppKit"),
                // Link against the Rust static library
                .unsafeFlags(["-L../../../target/universal/release"]),
                .unsafeFlags(["-lpasty_core"]),
            ]
        ),
    ]
)
