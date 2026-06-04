// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "com.awareframework.ios.sensor.pedometer",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "com.awareframework.ios.sensor.pedometer",
            targets: [
                "com.awareframework.ios.sensor.pedometer"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/awareframework/com.awareframework.ios.core.git", from: "1.1.0")
    ],
    targets: [
        .target(
            name: "com.awareframework.ios.sensor.pedometer",
            dependencies: [
                .product(name: "com.awareframework.ios.core", package: "com.awareframework.ios.core", condition: .when(platforms: [.iOS]))
            ],
            path: "Sources/com.awareframework.ios.sensor.pedometer"
        ),
        .testTarget(
            name: "com.awareframework.ios.sensor.pedometerTests",
            dependencies: ["com.awareframework.ios.core", "com.awareframework.ios.sensor.pedometer"]
        )
    ],
    swiftLanguageModes: [.v5]
)
