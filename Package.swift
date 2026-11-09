// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Jata",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PasswordCore"),
        .executableTarget(name: "Jata", dependencies: ["PasswordCore"]),
        .testTarget(name: "PasswordCoreTests", dependencies: ["PasswordCore"]),
    ]
)
