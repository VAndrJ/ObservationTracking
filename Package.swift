// swift-tools-version: 6.0

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "ObservationTracking",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .tvOS(.v17),
        .watchOS(.v10),
        .macCatalyst(.v17),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "ObservationTracking",
            targets: ["ObservationTracking"]
        ),
        .executable(
            name: "ObservationTrackingClient",
            targets: ["ObservationTrackingClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .macro(
            name: "ObservationTrackingMacros",
            dependencies: [
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            swiftSettings: [
                .define("SWIFT_UPCOMING_FEATURE_BARE_SLASH_REGEX_LITERALS")
            ]
        ),
        .target(name: "ObservationTracking", dependencies: ["ObservationTrackingMacros"]),
        .executableTarget(name: "ObservationTrackingClient", dependencies: ["ObservationTracking"]),
        .testTarget(
            name: "ObservationTrackingTests",
            dependencies: [
                "ObservationTracking",
                "ObservationTrackingMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
