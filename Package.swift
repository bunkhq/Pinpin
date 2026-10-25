// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pinpin",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pinpin",
            path: "Sources/Pinpin",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
    ]
)
