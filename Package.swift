// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PasswordGenerator",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PasswordCore"),
        .executableTarget(name: "PasswordGenerator", dependencies: ["PasswordCore"]),
        .testTarget(name: "PasswordCoreTests", dependencies: ["PasswordCore"]),
    ]
)
