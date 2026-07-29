// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "IsolationConsumer",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "IsolationConsumer",
            dependencies: [
                .product(name: "ObservationTracking", package: "observationtracking")
            ]
        )
    ]
)
