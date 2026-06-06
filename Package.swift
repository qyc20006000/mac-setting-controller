// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacSettingsController",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacSettingsController", targets: ["MacSettingsController"]),
        .executable(name: "SettingsTests", targets: ["SettingsTests"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SettingsCore",
            dependencies: [],
            path: "Sources/SettingsCore"
        ),
        .executableTarget(
            name: "MacSettingsController",
            dependencies: ["SettingsCore"],
            path: "Sources/MacSettingsController"
        ),
        .executableTarget(
            name: "SettingsTests",
            dependencies: ["SettingsCore"],
            path: "Tests/MacSettingsControllerTests"
        ),
    ]
)
