// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Cr4sh0ut",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "Cr4sh0ut", targets: ["Cr4sh0ut"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Cr4sh0ut",
            dependencies: [],
            path: "cr4sh0ut/Sources",
            swiftSettings: [
                .unsafeFlags(["-framework", "AppKit"])
            ]
        )
    ]
) 