// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cr4sh0ut",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "Cr4sh0ut",
            targets: ["Cr4sh0ut"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/AudioKit/AudioKit.git", from: "5.6.1"),
        .package(url: "https://github.com/AudioKit/AudioKitUI.git", from: "0.3.5")
    ],
    targets: [
        .executableTarget(
            name: "Cr4sh0ut",
            dependencies: [
                "Cr4sh0utUI",
                "Cr4sh0utViews",
                "Cr4sh0utManagers"
            ],
            path: "src",
            exclude: ["Components", "Managers", "Views"],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .define("PREVIEW", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "Cr4sh0utUI",
            dependencies: [
                .product(name: "AudioKitUI", package: "AudioKitUI")
            ],
            path: "src/Components",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .define("PREVIEW", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "Cr4sh0utManagers",
            dependencies: [
                .product(name: "AudioKit", package: "AudioKit")
            ],
            path: "src/Managers",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .define("PREVIEW", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "Cr4sh0utViews",
            dependencies: [
                "Cr4sh0utUI",
                "Cr4sh0utManagers",
                .product(name: "AudioKit", package: "AudioKit"),
                .product(name: "AudioKitUI", package: "AudioKitUI")
            ],
            path: "src/Views",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .define("PREVIEW", .when(configuration: .debug))
            ]
        )
    ]
)