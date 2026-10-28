// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "UVCMirror",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CUVCControl",
            path: "Sources/CUVCControl",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fno-objc-arc"])
            ]
        ),
        .executableTarget(
            name: "UVCMirror",
            dependencies: ["CUVCControl"],
            path: "Sources/UVCMirror",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
